import { isApprovalPhrase } from "./approve.js";
import { createAvatar } from "./avatar3d.js";
import {
  BUDGET_JPY,
  DEFAULT_MODEL,
  cappedMeetingYen,
  designedMeetingYen,
  formatYen,
} from "./cost.js";
import { createSpeech, pullSentences } from "./speech.js";

const session = {
  id: crypto.randomUUID(),
  started: false,
  startedAt: 0,
  mic: false,
  history: [],
  transcript: [],
  yen: 0,
  saving: false,
  model: DEFAULT_MODEL,
  draft: null,
  phraseOk: false,
  phraseText: "",
  agents: [],
  mode: "idle",
  busy: false,
  abort: null,
};

const els = {
  stage: document.querySelector("#stage"),
  canvas: document.querySelector("#avatar"),
  aizuchi: document.querySelector("#aizuchi"),
  status: document.querySelector("#status"),
  caption: document.querySelector("#caption"),
  log: document.querySelector("#log"),
  clock: document.querySelector("#clock"),
  yen: document.querySelector("#yen"),
  tokens: document.querySelector("#tokens"),
  meter: document.querySelector("#meter-fill"),
  saving: document.querySelector("#saving"),
  model: document.querySelector("#model"),
  estimate: document.querySelector("#estimate"),
  start: document.querySelector("#start"),
  end: document.querySelector("#end"),
  mic: document.querySelector("#mic"),
  composer: document.querySelector("#composer"),
  send: document.querySelector("#send"),
  draft: document.querySelector("#draft"),
  draftText: document.querySelector("#draft-text"),
  phraseState: document.querySelector("#phrase-state"),
  approve: document.querySelector("#approve"),
  agents: document.querySelector("#agents"),
  minutes: document.querySelector("#minutes"),
  minutesBody: document.querySelector("#minutes-body"),
  download: document.querySelector("#download"),
  banner: document.querySelector("#banner"),
  voiceName: document.querySelector("#voice-name"),
};

const avatar = createAvatar(els.canvas);
const speech = createSpeech({
  onSpeaking(active) {
    if (active) {
      session.speakUntil = Math.max(session.speakUntil || 0, Date.now() + 900);
      setMode("speaking");
      return;
    }
    const wait = (session.speakUntil || 0) - Date.now();
    if (wait > 0) {
      setTimeout(() => {
        if (Date.now() >= (session.speakUntil || 0) && session.mode === "speaking") {
          setMode(session.started && session.mic && !session.busy ? "listening" : "idle");
        }
      }, wait);
      return;
    }
    if (!session.busy) setMode(session.started && session.mic ? "listening" : "idle");
  },
});

let recognition = null;
let audioContext = null;
let analyser = null;
let loudFrames = 0;
let lastAizuchi = 0;
let minutesMarkdown = "";
const AIZUCHI = ["うん", "へえ", "なるほど"];

function setMode(mode) {
  session.mode = mode;
  avatar.setMode(mode);
  els.stage.dataset.state = mode;
  const labels = {
    idle: session.started ? "待機" : "打ち合わせの前",
    listening: "聞いています",
    thinking: "考えています",
    speaking: "話しています",
  };
  if (!session.busy || mode === "thinking" || mode === "speaking") {
    els.status.textContent = labels[mode] || mode;
  }
}

function setCaption(text) {
  els.caption.textContent = text || "";
}

function addLine(role, text) {
  const item = { role, text, at: Date.now() };
  session.transcript.push(item);
  const row = document.createElement("p");
  row.className = role === "assistant" ? "line vp" : "line you";
  const who = document.createElement("span");
  who.textContent = role === "assistant" ? "VP" : "社長";
  const body = document.createElement("span");
  body.textContent = text;
  row.append(who, body);
  els.log.append(row);
  els.log.scrollTop = els.log.scrollHeight;
  setCaption(text);
}

function renderCost(usage) {
  els.yen.textContent = `${formatYen(session.yen)}円`;
  const ratio = Math.min(100, (session.yen / BUDGET_JPY) * 100);
  els.meter.style.width = `${ratio}%`;
  els.saving.hidden = !session.saving;
  els.meter.parentElement.classList.toggle("over", session.yen >= BUDGET_JPY);
  els.meter.parentElement.classList.toggle("saving", session.saving);
  if (usage) {
    const input = (usage.input || 0) + (usage.cacheRead || 0) + (usage.cacheWrite || 0);
    els.tokens.textContent = `入力 ${input.toLocaleString("ja-JP")}（キャッシュ読 ${(usage.cacheRead || 0).toLocaleString("ja-JP")}） / 出力 ${(usage.output || 0).toLocaleString("ja-JP")}`;
  }
}

function renderEstimate() {
  const model = els.model.value;
  const designed = designedMeetingYen(model);
  const capped = cappedMeetingYen(model);
  const over = designed > BUDGET_JPY;
  els.estimate.textContent = over
    ? `30分の想定 ${formatYen(designed)}円。上限まで使うと ${formatYen(capped)}円。予算の10円を超えます。`
    : `30分の想定 ${formatYen(designed)}円。上限まで使っても ${formatYen(capped)}円。`;
}

function showDraft(instruction) {
  session.draft = instruction;
  session.phraseOk = false;
  session.phraseText = "";
  els.draft.hidden = false;
  els.draftText.value = instruction;
  els.phraseState.textContent = "声で「それでいい」を確認するまで送れません";
  els.approve.disabled = false;
}

function hideDraft() {
  session.draft = null;
  session.phraseOk = false;
  els.draft.hidden = true;
}

function addAgent(agent) {
  session.agents.push(agent);
  const item = document.createElement("li");
  const link = document.createElement("a");
  link.href = agent.url;
  link.target = "_blank";
  link.rel = "noreferrer";
  link.textContent = agent.url;
  item.append(link);
  els.agents.append(item);
}

async function syncDraft() {
  const text = els.draftText.value.trim();
  if (!text || text === session.draft) return;
  session.draft = text;
  await fetch("/api/cursor/draft", {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ sessionId: session.id, text }),
  });
}

function consumeSse(buffer) {
  const chunks = buffer.split("\n\n");
  const rest = chunks.pop() || "";
  const events = [];
  for (const chunk of chunks) {
    const line = chunk.split("\n").find((item) => item.startsWith("data:"));
    if (!line) continue;
    try {
      events.push(JSON.parse(line.slice(5).trim()));
    } catch {
      /* 途中の断片は捨てる */
    }
  }
  return { events, rest };
}

async function ask(text) {
  const clean = text.trim();
  if (!clean) return;
  if (session.draft && isApprovalPhrase(clean)) {
    session.phraseOk = true;
    session.phraseText = clean;
    els.phraseState.textContent = "「それでいい」を確認しました。ボタンを押すと送ります";
    addLine("user", clean);
    speech.enqueue("ボタンでも承認してね。");
    return;
  }
  if (session.busy) return;
  if (session.draft && !isApprovalPhrase(clean)) {
    session.phraseOk = false;
    session.phraseText = "";
    els.phraseState.textContent = "文面を直します。まだ送っていません";
  }
  session.history.push({ role: "user", content: clean });
  addLine("user", clean);
  session.busy = true;
  setMode("thinking");
  stopRecognition();
  const controller = new AbortController();
  session.abort = controller;
  let spoken = "";
  let pending = "";
  let askedConfirm = false;
  try {
    const response = await fetch("/api/chat", {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({
        sessionId: session.id,
        model: session.model,
        messages: session.history,
      }),
      signal: controller.signal,
    });
    if (!response.ok || !response.body) {
      const error = await response.json().catch(() => ({ message: "返事が来ませんでした" }));
      addLine("assistant", error.message || "返事が来ませんでした");
      return;
    }
    const reader = response.body.getReader();
    const decoder = new TextDecoder();
    let carry = "";
    while (true) {
      const { done, value } = await reader.read();
      if (done) break;
      carry += decoder.decode(value, { stream: true });
      const parsed = consumeSse(carry);
      carry = parsed.rest;
      for (const event of parsed.events) {
        if (event.type === "text") {
          pending += event.text;
          const pulled = pullSentences(pending, false);
          pending = pulled.rest;
          for (const sentence of pulled.sentences) {
            spoken += sentence;
            session.speakUntil = Date.now() + Math.max(900, sentence.length * 90);
            speech.enqueue(sentence);
          }
          setCaption(spoken + pending);
        } else if (event.type === "status" && event.status === "looking") {
          els.status.textContent = "リポジトリを見ています";
          setMode("thinking");
        } else if (event.type === "usage") {
          session.yen = event.yen;
          session.saving = event.saving;
          renderCost(event.usage);
        } else if (event.type === "approval") {
          showDraft(event.instruction);
          askedConfirm = true;
        } else if (event.type === "error") {
          addLine("assistant", event.message);
        }
      }
    }
    const tail = pullSentences(pending, true);
    for (const sentence of tail.sentences) {
      spoken += sentence;
      speech.enqueue(sentence);
    }
    if (askedConfirm && !spoken.includes("この内容でいい")) {
      speech.enqueue("依頼はこの内容でいい？");
      spoken += "依頼はこの内容でいい？";
    }
    if (spoken.trim()) {
      session.history.push({ role: "assistant", content: spoken.trim() });
      addLine("assistant", spoken.trim());
    }
  } catch (error) {
    if (error?.name !== "AbortError") addLine("assistant", "つなぎが切れました");
  } finally {
    session.busy = false;
    session.abort = null;
    const remain = (session.speakUntil || 0) - Date.now();
    if (remain > 0) {
      setMode("speaking");
      setTimeout(() => {
        if (session.busy || Date.now() < (session.speakUntil || 0)) return;
        if (session.started && session.mic) {
          setMode("listening");
          startRecognition();
        }
      }, remain);
    } else if (session.started && session.mic) {
      setMode("listening");
      startRecognition();
    } else if (!session.started) {
      setMode("idle");
    }
  }
}

function maybeAizuchi(interim) {
  avatar.nod();
  const now = Date.now();
  if (now - lastAizuchi < 2600) return;
  lastAizuchi = now;
  const phrase = AIZUCHI[Math.floor(now / 2600) % AIZUCHI.length];
  els.aizuchi.textContent = phrase;
  els.aizuchi.hidden = false;
  clearTimeout(maybeAizuchi.timer);
  maybeAizuchi.timer = setTimeout(() => {
    els.aizuchi.hidden = true;
  }, 900);
  if (interim.length > 8 && now - (maybeAizuchi.spokenAt || 0) > 6000) {
    maybeAizuchi.spokenAt = now;
    speech.aizuchi(phrase);
  }
}

function onFinal(text) {
  const clean = text.trim();
  if (!clean) return;
  if (Date.now() < speech.ignoreUntil && /^(うん|へえ|なるほど|ええ)$/.test(clean)) return;
  if (speech.speaking) speech.cancel();
  ask(clean);
}

function startRecognition() {
  const Recognition = window.SpeechRecognition || window.webkitSpeechRecognition;
  if (!Recognition || !session.mic) return;
  stopRecognition();
  const rec = new Recognition();
  rec.lang = "ja-JP";
  rec.interimResults = true;
  rec.continuous = false;
  rec.onresult = (event) => {
    let interim = "";
    let finalText = "";
    for (let index = event.resultIndex; index < event.results.length; index += 1) {
      const piece = event.results[index][0].transcript;
      if (event.results[index].isFinal) finalText += piece;
      else interim += piece;
    }
    if (interim) {
      setCaption(interim);
      setMode("listening");
      maybeAizuchi(interim);
      if (session.mode === "speaking" || speech.speaking) speech.cancel();
    }
    if (finalText) onFinal(finalText);
  };
  rec.onerror = (event) => {
    if (event.error === "not-allowed" || event.error === "service-not-allowed") {
      els.status.textContent = "音声認識が使えません。文字で送れます";
    }
  };
  rec.onend = () => {
    if (session.mic && session.started && !session.busy && recognition === rec) {
      try {
        rec.start();
      } catch {
        /* すでに起動中 */
      }
    }
  };
  recognition = rec;
  try {
    rec.start();
  } catch {
    els.status.textContent = "音声認識を始められません。文字で送れます";
  }
}

function stopRecognition() {
  const rec = recognition;
  recognition = null;
  try {
    rec?.abort();
  } catch {
    /* 停止済み */
  }
}

async function openAnalyser() {
  if (analyser || !navigator.mediaDevices?.getUserMedia) return;
  try {
    const stream = await navigator.mediaDevices.getUserMedia({
      audio: { echoCancellation: true, noiseSuppression: true, autoGainControl: true },
    });
    audioContext = new AudioContext();
    const source = audioContext.createMediaStreamSource(stream);
    analyser = audioContext.createAnalyser();
    analyser.fftSize = 512;
    source.connect(analyser);
    const data = new Uint8Array(analyser.fftSize);
    const tick = () => {
      if (!analyser) return;
      analyser.getByteTimeDomainData(data);
      let sum = 0;
      for (const value of data) {
        const sample = (value - 128) / 128;
        sum += sample * sample;
      }
      const rms = Math.sqrt(sum / data.length);
      if ((session.mode === "speaking" || speech.speaking) && rms > 0.18 && Date.now() > speech.ignoreUntil) {
        loudFrames += 1;
        if (loudFrames > 6) {
          speech.cancel();
          session.abort?.abort();
          loudFrames = 0;
          if (session.mic) startRecognition();
        }
      } else {
        loudFrames = 0;
      }
      requestAnimationFrame(tick);
    };
    tick();
  } catch {
    els.banner.hidden = false;
    els.banner.textContent = "マイクが使えません。文字でも送れます。";
  }
}

function tickClock() {
  if (!session.startedAt) {
    els.clock.textContent = "00:00";
    return;
  }
  const end = session.started ? Date.now() : session.endedAt || session.startedAt;
  const seconds = Math.floor((end - session.startedAt) / 1000);
  const mm = String(Math.floor(seconds / 60)).padStart(2, "0");
  const ss = String(seconds % 60).padStart(2, "0");
  els.clock.textContent = `${mm}:${ss}`;
}

function startMeeting() {
  if (session.started) return;
  speech.unlock();
  session.id = crypto.randomUUID();
  session.started = true;
  session.startedAt = Date.now();
  session.history = [];
  session.transcript = [];
  session.yen = 0;
  session.saving = false;
  session.agents = [];
  session.mic = true;
  els.log.replaceChildren();
  els.agents.replaceChildren();
  els.minutes.hidden = true;
  hideDraft();
  renderCost(null);
  els.tokens.textContent = "入力 0 / 出力 0";
  els.start.disabled = true;
  els.end.disabled = false;
  els.mic.disabled = false;
  els.mic.textContent = "マイクを切る";
  els.mic.setAttribute("aria-pressed", "true");
  setMode("speaking");
  speech.enqueue("打ち合わせを始めるね。話したいことがあれば、そのまま話して。");
  openAnalyser();
  setTimeout(() => {
    if (session.mic) startRecognition();
  }, 400);
  els.voiceName.textContent = speech.describeVoice();
}

function toggleMic() {
  if (!session.started) return;
  session.mic = !session.mic;
  els.mic.textContent = session.mic ? "マイクを切る" : "話す";
  els.mic.setAttribute("aria-pressed", session.mic ? "true" : "false");
  if (session.mic) {
    setMode("listening");
    startRecognition();
  } else {
    stopRecognition();
    if (!speech.speaking) setMode("idle");
  }
}

async function endMeeting() {
  if (!session.started) return;
  session.endedAt = Date.now();
  session.started = false;
  session.mic = false;
  stopRecognition();
  speech.cancel();
  session.abort?.abort();
  els.start.disabled = false;
  els.end.disabled = true;
  els.mic.disabled = true;
  els.mic.textContent = "話す";
  setMode("idle");
  const elapsedSec = Math.floor((Date.now() - session.startedAt) / 1000);
  const response = await fetch("/api/minutes", {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({
      sessionId: session.id,
      transcript: session.transcript,
      elapsedSec,
    }),
  });
  const data = await response.json();
  if (typeof data.yen === "number") {
    session.yen = data.yen;
    session.saving = Boolean(data.saving);
    renderCost(null);
  }
  minutesMarkdown = data.markdown || "";
  renderMinutes(data);
  els.minutes.hidden = false;
}

function renderMinutes(data) {
  els.minutesBody.replaceChildren();
  const blocks = [
    ["要点", data.points],
    ["決まったこと", data.decisions],
    ["宿題", data.todos],
  ];
  for (const [title, items] of blocks) {
    const heading = document.createElement("h3");
    heading.textContent = title;
    const list = document.createElement("ul");
    const values = items?.length ? items : ["なし"];
    for (const value of values) {
      const li = document.createElement("li");
      li.textContent = value;
      list.append(li);
    }
    els.minutesBody.append(heading, list);
  }
  const heading = document.createElement("h3");
  heading.textContent = "Cursorに出した依頼";
  const list = document.createElement("ul");
  if (!data.requests?.length) {
    const li = document.createElement("li");
    li.textContent = "なし";
    list.append(li);
  } else {
    for (const request of data.requests) {
      const li = document.createElement("li");
      li.textContent = request.instruction;
      if (request.url) {
        const link = document.createElement("a");
        link.href = request.url;
        link.target = "_blank";
        link.rel = "noreferrer";
        link.textContent = request.url;
        li.append(document.createElement("br"), link);
      }
      list.append(li);
    }
  }
  els.minutesBody.append(heading, list);
}

document.querySelector("#composer-form").addEventListener("submit", (event) => {
  event.preventDefault();
});
els.start.addEventListener("click", startMeeting);
els.end.addEventListener("click", endMeeting);
els.mic.addEventListener("click", toggleMic);
els.send.addEventListener("click", () => {
  const text = els.composer.value;
  els.composer.value = "";
  if (!session.started) startMeeting();
  ask(text);
});
els.composer.addEventListener("keydown", (event) => {
  if (event.key === "Enter" && !event.shiftKey) {
    event.preventDefault();
    els.send.click();
  }
});
els.model.addEventListener("change", () => {
  session.model = els.model.value;
  renderEstimate();
});
els.draftText.addEventListener("input", () => {
  if (els.draftText.value.trim() !== session.draft) {
    session.phraseOk = false;
    session.phraseText = "";
    els.phraseState.textContent = "文面が変わったので、もう一度「それでいい」が必要です";
  }
});
els.approve.addEventListener("click", async () => {
  if (!session.draft) return;
  if (!session.phraseOk) {
    speech.say("先に、それでいい、と言ってね。", { pitch: 1.34, rate: 1.06 });
    els.phraseState.textContent = "まだ声の確認がありません";
    return;
  }
  await syncDraft();
  const response = await fetch("/api/cursor/launch", {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({
      sessionId: session.id,
      buttonApproved: true,
      phrase: session.phraseText,
    }),
  });
  const data = await response.json();
  if (!response.ok) {
    els.phraseState.textContent = data.message || "送れませんでした";
    return;
  }
  addAgent({ instruction: data.instruction, url: data.url, id: data.id });
  hideDraft();
  addLine("assistant", "送ったよ。");
  speech.enqueue("送ったよ。");
});
els.download.addEventListener("click", () => {
  if (!minutesMarkdown) return;
  const blob = new Blob([minutesMarkdown], { type: "text/markdown;charset=utf-8" });
  const link = document.createElement("a");
  link.href = URL.createObjectURL(blob);
  link.download = "vp-minutes.md";
  link.click();
  URL.revokeObjectURL(link.href);
});

setInterval(tickClock, 250);
renderEstimate();
renderCost(null);
setMode("idle");

fetch("/api/health")
  .then((response) => response.json())
  .then((health) => {
    if (!health.hasAnthropicKey) {
      els.banner.hidden = false;
      els.banner.textContent = "中継に ANTHROPIC_API_KEY がありません。会話の返事は返せません。";
    }
  })
  .catch(() => {});

window.__vp = {
  get mode() {
    return session.mode;
  },
  get yen() {
    return session.yen;
  },
  session,
};
