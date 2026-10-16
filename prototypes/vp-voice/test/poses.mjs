import { spawn } from "node:child_process";
import fs from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { nodeRepo, startServer } from "../relay/server.mjs";

const outDir = "/opt/cursor/artifacts/vp-voice";

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
  await fs.mkdir(outDir, { recursive: true });
  await fs.mkdir(path.join(outDir, "frames"), { recursive: true });
  const root = await fs.mkdtemp(path.join(os.tmpdir(), "vp-pose-"));
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
      "--user-data-dir=/tmp/vp-chrome-pose",
      "--window-size=1280,900",
      "--remote-debugging-address=127.0.0.1",
      "--remote-debugging-port=9223",
      "about:blank",
    ],
    { stdio: "ignore" },
  );

  try {
    let version;
    for (let attempt = 0; attempt < 40; attempt += 1) {
      try {
        version = await fetch("http://127.0.0.1:9223/json/version").then((res) => res.json());
        break;
      } catch {
        await sleep(150);
      }
    }
    if (!version) throw new Error("Chrome のデバッグポートが開きません");
    const browser = await cdp(version.webSocketDebuggerUrl);
    const { targetId } = await browser.send("Target.createTarget", { url: app.url });
    const { webSocketDebuggerUrl } = (await fetch("http://127.0.0.1:9223/json/list").then((res) => res.json())).find(
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

    async function waitFor(expression) {
      for (let attempt = 0; attempt < 50; attempt += 1) {
        const result = await page.send("Runtime.evaluate", { expression, returnByValue: true });
        if (result.result?.value) return;
        await sleep(200);
      }
      throw new Error(`待てませんでした: ${expression}`);
    }

    async function shot(name) {
      const result = await page.send("Page.captureScreenshot", { format: "png" });
      const file = path.join(outDir, name);
      await fs.writeFile(file, Buffer.from(result.data, "base64"));
      return file;
    }

    async function pose(expression) {
      await page.send("Runtime.evaluate", { expression });
      await sleep(350);
    }

    await waitFor("document.querySelector('#avatar')?.dataset.ready === '1'");
    const errors = await page.send("Runtime.evaluate", {
      expression: "document.querySelector('#avatar').dataset.ready",
      returnByValue: true,
    });
    console.log("ready", errors.result?.value);
    await pose("document.querySelector('#avatar').dataset.pose='idle'; document.querySelector('#avatar').dataset.blink='0'; document.querySelector('#avatar').dataset.mouth='0'");
    await shot("pose-idle.png");
    await pose("document.querySelector('#avatar').dataset.pose='listening'; document.querySelector('#avatar').dataset.blink='0'; document.querySelector('#avatar').dataset.mouth='0'");
    await shot("pose-listening.png");
    await pose("document.querySelector('#avatar').dataset.pose='speaking'; document.querySelector('#avatar').dataset.blink='0'; document.querySelector('#avatar').dataset.mouth='1'");
    await shot("pose-speaking.png");
    await pose("document.querySelector('#avatar').dataset.pose='idle'; document.querySelector('#avatar').dataset.blink='1'; document.querySelector('#avatar').dataset.mouth='0'");
    await shot("pose-blink.png");

    await pose("document.querySelector('#avatar').dataset.pose='idle'; document.querySelector('#avatar').dataset.blink=''; document.querySelector('#avatar').dataset.mouth=''");
    for (let index = 0; index < 36; index += 1) {
      if (index === 12) await pose("document.querySelector('#avatar').dataset.pose='speaking'; document.querySelector('#avatar').dataset.mouth=''");
      if (index === 24) await pose("document.querySelector('#avatar').dataset.pose='listening'");
      const result = await page.send("Page.captureScreenshot", { format: "jpeg", quality: 70 });
      await fs.writeFile(path.join(outDir, "frames", `f${String(index).padStart(2, "0")}.jpg`), Buffer.from(result.data, "base64"));
      await sleep(90);
    }
    page.close();
    browser.close();
    console.log("shots ok", app.url);
  } finally {
    chrome.kill("SIGKILL");
    app.server.close();
  }
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
