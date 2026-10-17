import { spawn } from "node:child_process";
import fs from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { nodeRepo, startServer } from "../relay/server.mjs";

const outDir = "/opt/cursor/artifacts/vp-voice/blink";

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function cdp(wsUrl) {
  const ws = new WebSocket(wsUrl);
  await new Promise((resolve, reject) => {
    ws.addEventListener("open", resolve);
    ws.addEventListener("error", reject);
  });
  let id = 0;
  const pending = new Map();
  ws.addEventListener("message", (event) => {
    const message = JSON.parse(event.data);
    if (message.id && pending.has(message.id)) {
      const { resolve, reject } = pending.get(message.id);
      pending.delete(message.id);
      if (message.error) reject(new Error(JSON.stringify(message.error)));
      else resolve(message.result);
    }
  });
  return {
    send(method, params = {}) {
      const next = ++id;
      ws.send(JSON.stringify({ id: next, method, params }));
      return new Promise((resolve, reject) => pending.set(next, { resolve, reject }));
    },
    close() {
      ws.close();
    },
  };
}

async function main() {
  await fs.rm(outDir, { recursive: true, force: true });
  await fs.mkdir(outDir, { recursive: true });
  const framesDir = path.join(outDir, "frames");
  await fs.mkdir(framesDir, { recursive: true });
  const root = await fs.mkdtemp(path.join(os.tmpdir(), "vp-blink-"));
  const app = await startServer({
    apiKey: "test-anthropic-key",
    cursorKey: "test-cursor-key",
    repo: nodeRepo(root),
    port: 0,
  });
  const chrome = spawn(
    "google-chrome",
    [
      "--headless=new",
      "--disable-gpu",
      "--use-gl=angle",
      "--use-angle=swiftshader",
      "--enable-unsafe-swiftshader",
      "--no-sandbox",
      "--user-data-dir=/tmp/vp-chrome-blink",
      "--window-size=1280,900",
      "--remote-debugging-address=127.0.0.1",
      "--remote-debugging-port=9224",
      "about:blank",
    ],
    { stdio: "ignore" },
  );

  try {
    let version;
    for (let attempt = 0; attempt < 40; attempt += 1) {
      try {
        version = await fetch("http://127.0.0.1:9224/json/version").then((res) => res.json());
        break;
      } catch {
        await sleep(150);
      }
    }
    if (!version) throw new Error("Chrome のデバッグポートが開きません");
    const browser = await cdp(version.webSocketDebuggerUrl);
    const { targetId } = await browser.send("Target.createTarget", { url: app.url });
    const { webSocketDebuggerUrl } = (await fetch("http://127.0.0.1:9224/json/list").then((res) => res.json())).find(
      (target) => target.id === targetId,
    );
    const page = await cdp(webSocketDebuggerUrl);
    await page.send("Page.enable");
    await page.send("Runtime.enable");
    await page.send("Emulation.setDeviceMetricsOverride", {
      width: 1280,
      height: 900,
      deviceScaleFactor: 1,
      mobile: false,
    });
    for (let attempt = 0; attempt < 50; attempt += 1) {
      const result = await page.send("Runtime.evaluate", {
        expression: "document.querySelector('#avatar')?.dataset.ready === '1'",
        returnByValue: true,
      });
      if (result.result?.value) break;
      await sleep(200);
      if (attempt === 49) throw new Error("絵が準備できません");
    }
    await page.send("Runtime.evaluate", {
      expression: "document.querySelector('#avatar').dataset.manual='1'; document.querySelector('#avatar').dataset.pose='idle'; document.querySelector('#avatar').dataset.blink=''; document.querySelector('#avatar').dataset.mouth='0'",
    });

    const seconds = Number(process.env.BLINK_SECONDS || 4.2);
    const total = Math.round(seconds * 60);
    const trace = [];
    for (let index = 0; index < total; index += 1) {
      const result = await page.send("Runtime.evaluate", {
        expression: `(() => {
          const canvas = document.querySelector('#avatar');
          const sample = window.__vp.renderAt(${index} / 60);
          const url = canvas.toDataURL('image/jpeg', 0.9);
          return { blink: sample.blink, w: canvas.width, h: canvas.height, url };
        })()`,
        returnByValue: true,
      });
      const value = result.result?.value;
      if (!value?.url) throw new Error(`フレームを取れません: ${JSON.stringify(result).slice(0, 300)}`);
      const jpeg = value.url.slice(value.url.indexOf(",") + 1);
      await fs.writeFile(path.join(framesDir, `f${String(index).padStart(4, "0")}.jpg`), Buffer.from(jpeg, "base64"));
      if (index % 10 === 0) trace.push(`${index}:${value.blink.toFixed(2)}`);
    }
    console.log("trace", trace.join(" "), "size", total);
    const videoPath = path.join("/opt/cursor/artifacts/vp-voice", "blink-motion.mp4");
    const ffmpegLog = [];
    await new Promise((resolve, reject) => {
      const encoder = spawn("ffmpeg", [
        "-y",
        "-framerate", "60",
        "-i", path.join(framesDir, "f%04d.jpg"),
        "-frames:v", String(total),
        "-c:v", "libx264",
        "-pix_fmt", "yuv420p",
        "-crf", "18",
        "-movflags", "+faststart",
        videoPath,
      ], { stdio: ["ignore", "pipe", "pipe"] });
      encoder.stderr.on("data", (chunk) => ffmpegLog.push(chunk.toString()));
      encoder.on("error", reject);
      encoder.on("exit", (code) => (code === 0 ? resolve() : reject(new Error(`ffmpeg ${code}\n${ffmpegLog.join("").slice(-500)}`))));
    });
    const video = await fs.stat(videoPath);
    console.log("video", video.size);
    const eyesDir = path.join(outDir, "eyes");
    await fs.mkdir(eyesDir, { recursive: true });
    await new Promise((resolve, reject) => {
      const crop = spawn("python3", ["-"], { stdio: ["pipe", "inherit", "inherit"] });
      crop.stdin.write(`
from PIL import Image
import os
src = "${framesDir}"
dst = "${eyesDir}"
box = (118, 188, 470, 360)
names = sorted(n for n in os.listdir(src) if n.endswith(".jpg"))
# one blink starts at frame 30 (t=0.5s) and is done by frame 54
picked = [n for n in names if 28 <= int(n[1:5]) <= 54]
tiles = []
for name in picked:
    im = Image.open(os.path.join(src, name)).convert("RGB").crop(box)
    z = im.resize((im.width * 2, im.height * 2), Image.Resampling.LANCZOS)
    z.save(os.path.join(dst, name.replace(".jpg", ".png")))
    tiles.append(z)
if tiles:
    cols = 7
    rows = (len(tiles) + cols - 1) // cols
    sheet = Image.new("RGB", (tiles[0].width * cols, tiles[0].height * rows), (15, 27, 51))
    for i, tile in enumerate(tiles):
        sheet.paste(tile, ((i % cols) * tile.width, (i // cols) * tile.height))
    sheet.save(os.path.join(dst, "contact.png"))
    print("eyes", len(tiles), sheet.size)
`);
      crop.stdin.end();
      crop.on("error", reject);
      crop.on("exit", (code) => (code === 0 ? resolve() : reject(new Error(`crop ${code}`))));
    });
    page.close();
    browser.close();
  } finally {
    chrome.kill("SIGKILL");
    app.server.close();
  }
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
