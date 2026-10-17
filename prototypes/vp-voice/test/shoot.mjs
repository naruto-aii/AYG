import { spawn } from "node:child_process";
import fs from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { resetSessions } from "../relay/handler.mjs";
import { nodeRepo, startServer } from "../relay/server.mjs";
import { startAnthropic, startCursor } from "./upstream.mjs";

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
  resetSessions();
  const root = await fs.mkdtemp(path.join(os.tmpdir(), "vp-shot-"));
  await fs.writeFile(path.join(root, "README.md"), "カロナビは食事、運動、体重を記録するアプリ");
  const anthropic = await startAnthropic();
  const cursor = await startCursor();
  const app = await startServer({
    apiKey: "test-anthropic-key",
    cursorKey: "test-cursor-key",
    anthropicBase: anthropic.url,
    cursorBase: cursor.url,
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
      "--user-data-dir=/tmp/vp-chrome-profile",
      "--window-size=1280,900",
      "--remote-debugging-address=127.0.0.1",
      "--remote-debugging-port=9222",
      "--use-fake-ui-for-media-stream",
      "--use-fake-device-for-media-stream",
      "--autoplay-policy=no-user-gesture-required",
      "about:blank",
    ],
    { stdio: "ignore" },
  );

  try {
    let version;
    for (let attempt = 0; attempt < 40; attempt += 1) {
      try {
        version = await fetch("http://127.0.0.1:9222/json/version").then((res) => res.json());
        break;
      } catch {
        await sleep(150);
      }
    }
    if (!version) throw new Error("Chrome のデバッグポートが開きません");
    const browser = await cdp(version.webSocketDebuggerUrl);
    const { targetId } = await browser.send("Target.createTarget", { url: app.url });
    const { webSocketDebuggerUrl } = (await fetch("http://127.0.0.1:9222/json/list").then((res) => res.json())).find(
      (target) => target.id === targetId,
    );
    const page = await cdp(webSocketDebuggerUrl);
    await page.send("Page.enable");
    await page.send("Runtime.enable");
    await sleep(800);
    await page.send("Emulation.setDeviceMetricsOverride", {
      width: 1280,
      height: 900,
      deviceScaleFactor: 1,
      mobile: false,
    });

    async function shot(name) {
      const result = await page.send("Page.captureScreenshot", { format: "png" });
      const file = path.join(outDir, name);
      await fs.writeFile(file, Buffer.from(result.data, "base64"));
      return file;
    }

    async function waitFor(expression) {
      for (let attempt = 0; attempt < 40; attempt += 1) {
        const result = await page.send("Runtime.evaluate", { expression, returnByValue: true });
        if (result.result?.value) return;
        await sleep(200);
      }
      throw new Error(`待てませんでした: ${expression}`);
    }

    async function click(selector) {
      await page.send("Runtime.evaluate", {
        expression: `document.querySelector(${JSON.stringify(selector)}).click()`,
      });
    }

    await waitFor("document.querySelector('#avatar')?.dataset.ready === '1'");
    await shot("01-before.png");
    await click("#start");
    await sleep(600);
    await shot("02-listening.png");
    await page.send("Runtime.evaluate", {
      expression: `document.querySelector('#composer').value = 'このリポジトリは何をしてる？'; document.querySelector('#send').click();`,
    });
    await waitFor("document.querySelector('#caption')?.textContent?.includes('カロナビ')");
    await sleep(400);
    await shot("03-speaking.png");
    await page.send("Runtime.evaluate", {
      expression: `document.querySelector('#composer').value = 'ホームの文言を直して。Cursorに頼んで'; document.querySelector('#send').click();`,
    });
    await waitFor("document.querySelector('#draft') && !document.querySelector('#draft').hidden");
    await sleep(300);
    await shot("04-approval.png");
    const before = cursor.calls.length;
    await click("#approve");
    await sleep(200);
    if (cursor.calls.length !== before) throw new Error("声の確認の前に Cursor を呼んだ");
    await page.send("Runtime.evaluate", {
      expression: `document.querySelector('#composer').value = 'それでいい'; document.querySelector('#send').click();`,
    });
    await waitFor("document.querySelector('#phrase-state')?.textContent?.includes('ボタン')");
    if (cursor.calls.length !== before) throw new Error("ボタンの前に Cursor を呼んだ");
    await click("#approve");
    await waitFor("document.querySelector('#agents a')");
    await shot("05-sent.png");
    await click("#end");
    await waitFor("document.querySelector('#minutes') && !document.querySelector('#minutes').hidden");
    await page.send("Runtime.evaluate", {
      expression: "document.querySelector('#minutes').scrollIntoView({block:'end'})",
    });
    await sleep(200);
    await shot("06-minutes.png");
    const check = await page.send("Runtime.evaluate", {
      expression: `({
        mode: document.querySelector('#stage').dataset.state,
        yen: document.querySelector('#yen').textContent,
        url: document.querySelector('#agents a')?.textContent || '',
        minutes: document.querySelector('#minutes-body')?.innerText || '',
        canvas: document.querySelector('#avatar').width
      })`,
      returnByValue: true,
    });
    console.log(JSON.stringify({ cursorCalls: cursor.calls.length, ...check.result.value }, null, 2));
    page.close();
    browser.close();
  } finally {
    chrome.kill("SIGKILL");
    app.server.close();
    anthropic.server.close();
    cursor.server.close();
  }
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
