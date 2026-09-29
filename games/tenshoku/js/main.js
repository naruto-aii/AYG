import { ACTIONS, AIMS, PRIORITIES, ROLES, STATS, scoreWord } from "./content.js";
import {
  DAY_MAX,
  acknowledge,
  actionBlock,
  aimById,
  answerInterview,
  chooseOffer,
  createRun,
  endingById,
  priorityById,
  questProgress,
  questionById,
  remain,
  remainBlock,
  resolveDrill,
  roleById,
  selectionBlock,
  startSelection,
  takeAction,
  weekOf,
} from "./engine.js";

const KEY = "tenshoku-quest-v1";
const HELP = [
  "30日ある。1日に1つだけ動く。",
  "体力が尽きると、次の行動の伸びが半分になる。休むと戻る。",
  "応募の前に、経歴を1行にするか、求人を1件分解する。",
  "8日目以降、応募が1件あれば選考に進める。質問は3つ。",
  "答えのあと、なぜそれが通りやすいかを手帳に残す。",
  "最後の席は架空。一致の点数は、最初に選んだ2つを重く見る。",
  "15日目以降は、現職に残ることもできる。",
  "記録はこのブラウザに残る。診断でも、職業紹介でもない。",
];

const app = document.querySelector("#app");
let run = load();
let mode = "title";
let notice = "";
let pendingOffer = null;
let overlay = null;
let draft = { name: "", role: "", aim: "", priorities: [] };
let lastScreen = "";

document.addEventListener("keydown", onKey);
app.addEventListener("click", onClick);
app.addEventListener("input", onInput);
render();

function load() {
  try {
    const raw = localStorage.getItem(KEY);
    if (!raw) return null;
    const data = JSON.parse(raw);
    if (!data || data.version !== 1 || !data.phase || !data.counts) return null;
    return data;
  } catch {
    return null;
  }
}

function persist() {
  try {
    if (!run) localStorage.removeItem(KEY);
    else localStorage.setItem(KEY, JSON.stringify(run));
  } catch {
    notice = "このブラウザには記録を残せなかった。プレイはそのまま続く。";
  }
}

function esc(value) {
  return String(value ?? "").replace(/[&<>"']/g, (char) => ({
    "&": "&amp;",
    "<": "&lt;",
    ">": "&gt;",
    '"': "&quot;",
    "'": "&#39;",
  }[char]));
}

function screenOf() {
  if (mode === "title") return "title";
  if (mode === "create") return "create";
  if (!run) return "title";
  if (run.hold) return "hold";
  if (run.drill) return "drill";
  return run.phase;
}

function render() {
  const screen = screenOf();
  if (screen !== "offers") pendingOffer = null;
  document.title = screen === "title" || screen === "create" ? "転職クエスト" : `${run.day}日目 · 転職クエスト`;
  const pages = {
    title: renderTitle,
    create: renderCreate,
    plan: renderPlan,
    drill: renderDrill,
    hold: renderHold,
    interview: renderInterview,
    offers: renderOffers,
    ending: renderEnding,
  };
  app.innerHTML = `${pages[screen]()}${overlay ? renderOverlay() : ""}`;
  if (overlay) {
    app.querySelector("[data-act=close]")?.focus();
    return;
  }
  if (screen !== lastScreen) {
    const heading = app.querySelector("h1");
    if (heading) {
      heading.tabIndex = -1;
      heading.focus();
    }
    lastScreen = screen;
  }
}

function renderTitle() {
  return `<main class="shell">
    <div class="ticket">
      <p class="kicker">次の席までの30日</p>
      <h1>転職クエスト</h1>
      <p class="lede">経歴、人、面接、条件。出す前の30日を、架空の会社だけで練習する。</p>
      <div class="row">
        <button class="primary" type="button" data-act="start">はじめる</button>
        ${run ? `<button class="ghost" type="button" data-act="continue">つづきから</button>` : ""}
        <button class="ghost" type="button" data-act="how">遊び方</button>
      </div>
    </div>
    <p class="disclaimer">職業紹介でも、キャリア相談のサービスでもありません。会社、役職、金額はすべて架空です。現実の応募や年収の根拠には使わないでください。</p>
  </main>`;
}

function renderCreate() {
  return `<main class="shell">
    <p class="kicker">条件</p>
    <h1>30日の材料を決める</h1>
    <p>診断ではない。この2つを、最後の席の一致に重く使う。</p>
    ${notice ? `<p class="notice" role="alert">${esc(notice)}</p>` : ""}
    <label class="field">なまえ
      <input id="player-name" maxlength="12" autocomplete="nickname" placeholder="あなた" value="${esc(draft.name)}">
    </label>
    <h2>いまの仕事</h2>
    <div class="picks three">${ROLES.map((role) => pick("role", role.id, role.label, "", draft.role === role.id)).join("")}</div>
    <h2>向かう先</h2>
    <div class="picks two">${AIMS.map((aim) => pick("aim", aim.id, aim.label, aim.hint, draft.aim === aim.id)).join("")}</div>
    <h2>大切にすること、2つ</h2>
    <div class="picks three">${PRIORITIES.map((item) => pick("priority", item.id, item.label, "", draft.priorities.includes(item.id))).join("")}</div>
    <div class="row">
      <button class="primary" type="button" data-act="begin">この条件ではじめる</button>
      <button class="ghost" type="button" data-act="back-title">戻る</button>
    </div>
  </main>`;
}

function pick(act, id, label, hint, pressed) {
  return `<button class="pick" type="button" data-act="${act}" data-id="${esc(id)}" aria-pressed="${pressed ? "true" : "false"}">
    <strong>${esc(label)}</strong>${hint ? `<small>${esc(hint)}</small>` : ""}
  </button>`;
}

function renderPlan() {
  const quests = questProgress(run);
  const logs = run.log.slice(-6).reverse();
  const selectReason = selectionBlock(run);
  const showStay = run.day >= 15 || run.deadline;
  const stayReason = showStay ? remainBlock(run) : "15日目までは材料を集める";
  return `<main class="shell">
    <header class="top">
      <p class="brand">転職クエスト</p>
      <p class="dayline"><span>第${weekOf(run.day)}週</span> <strong>${run.day}</strong> 日目 / ${DAY_MAX}</p>
    </header>
    <p class="who">${esc(run.name)} · ${esc(roleById(run.role).label)} → ${esc(aimById(run.aim).label)} · 大切にするのは${run.priorities.map((id) => esc(priorityById(id).label)).join("と")}</p>
    <div class="rail" aria-hidden="true">${rail()}</div>
    ${notice ? `<p class="notice" role="alert">${esc(notice)}</p>` : ""}
    <div class="layout">
      <section class="panel" aria-label="状態">
        ${STATS.map((stat) => statRow(stat)).join("")}
        <p class="money">余力 ${run.money}</p>
      </section>
      <section>
        <h2>今日の行動</h2>
        <div class="actions">
          ${ACTIONS.map((action) => actionButton(action)).join("")}
        </div>
      </section>
    </div>
    <div class="quests" aria-label="準備">
      ${quests.map((quest) => `<span class="quest${quest.done ? " done" : ""}">${quest.done ? "済" : `${quest.current}/${quest.need}`} ${esc(quest.label)}</span>`).join("")}
    </div>
    <section class="panel" aria-live="polite">
      <h2>日誌</h2>
      <ul class="log">${logs.map((entry) => `<li><span class="when">${entry.day}日目</span>${esc(entry.text)}</li>`).join("")}</ul>
    </section>
    <div class="bar">
      <button class="primary" type="button" data-act="select" ${selectReason ? "disabled" : ""}>選考に進む</button>
      ${showStay ? `<button class="ghost" type="button" data-act="stay" ${stayReason ? "disabled" : ""}>現職に残る</button>` : ""}
      <button class="ghost" type="button" data-act="notebook">手帳 ${run.tips.length}</button>
      <button class="ghost" type="button" data-act="how">遊び方</button>
      <button class="texty" type="button" data-act="reset">はじめから</button>
    </div>
    <p class="hint">${esc(selectReason || (showStay && stayReason) || "会社も金額も架空です。")}</p>
  </main>`;
}

function rail() {
  return Array.from({ length: DAY_MAX }, (_, index) => {
    const day = index + 1;
    const cls = day < run.day ? "on" : day === run.day ? "now" : "";
    return `<i class="${cls}"></i>`;
  }).join("");
}

function statRow(stat) {
  const value = run[stat.key];
  const low = stat.key === "stamina" && value < 30;
  return `<div class="stat ${stat.key}${low ? " low" : ""}">
    <span>${esc(stat.label)}</span>
    <span class="track"><span class="fill" style="width:${Math.max(0, Math.min(100, value))}%"></span></span>
    <b>${value}</b>
  </div>`;
}

function actionButton(action) {
  const block = actionBlock(run, action.id);
  let detail = action.detail;
  if (!block && action.id === "study" && run.money < 2) detail = "余力がないので独学。伸びは小さい";
  if (!block && action.id !== "rest") detail = `${detail} · 体力 -${action.cost}`;
  return `<button class="action" type="button" data-act="action" data-id="${action.id}" ${block ? "disabled" : ""}>
    <span class="mark">${esc(action.mark)}</span>
    <span><strong>${esc(action.label)}</strong><small>${esc(block || detail)}</small></span>
  </button>`;
}

function renderDrill() {
  const question = questionById(run.drill.questionId);
  return `<main class="shell hold">
    <p class="kicker">${run.day}日目 · 模擬面接</p>
    <h1>${esc(question.prompt)}</h1>
    <p class="hint">番号キー 1–4 でも選べる。通りやすい答えは、性格の正しさではなく材料の出し方。</p>
    <div class="choices">${question.choices.map((choice, index) => choiceButton(choice, index)).join("")}</div>
  </main>`;
}

function renderInterview() {
  const question = questionById(run.interviewIds[run.interviewIndex]);
  return `<main class="shell hold">
    <p class="kicker">選考 ${run.interviewIndex + 1} / ${run.interviewIds.length}</p>
    <h1>${esc(question.prompt)}</h1>
    <p class="hint">架空の面接です。番号キー 1–4 でも選べる。</p>
    <div class="choices">${question.choices.map((choice, index) => choiceButton(choice, index)).join("")}</div>
  </main>`;
}

function choiceButton(choice, index) {
  return `<button class="choice" type="button" data-act="choice" data-id="${esc(choice.id)}">
    <span class="index">${index + 1}</span>
    <span>${esc(choice.text)}</span>
  </button>`;
}

function renderHold() {
  const word = scoreWord(run.hold.score);
  const tone = run.hold.score >= 2 ? "" : run.hold.score === 1 ? " mid" : " bad";
  return `<main class="shell hold">
    <p class="stamp${tone}">${esc(word)}</p>
    <h1>${esc(run.hold.prompt)}</h1>
    <p class="fine">選んだ答え</p>
    <blockquote>${esc(run.hold.choice)}</blockquote>
    <p>${esc(run.hold.note)}</p>
    <button class="primary" type="button" data-act="ack">手帳に残して次へ</button>
  </main>`;
}

function renderOffers() {
  const cards = run.offers.map((offer) => offerCard(offer)).join("");
  const picked = pendingOffer ? (pendingOffer === "stay" ? "現職に残る" : run.offers.find((offer) => offer.id === pendingOffer)?.company) : "";
  return `<main class="shell">
    <p class="kicker">条件 · 面接 ${run.interviewScore} / 6 · 応募 ${run.applications}社</p>
    <h1>どの席にするか</h1>
    <p>並びはおすすめ順ではない。太字は、最初に大切にした2つ。金額は架空の目安で、現実の相場ではない。</p>
    <div class="offers">
      ${cards}
      <button class="offer stay" type="button" data-act="offer" data-id="stay" aria-pressed="${pendingOffer === "stay" ? "true" : "false"}">
        <header><span class="co">残</span><span><strong class="company">現職に残る</strong><small>新しい席を取らない、も判断のうち</small></span></header>
        <p>比較の外に置く。材料が薄いときの残留は、次の30日の宿題になる。</p>
      </button>
    </div>
    ${picked ? `<div class="confirm"><p>${esc(picked)}で決める。</p><button class="primary" type="button" data-act="confirm-offer">これにする</button> <button class="ghost" type="button" data-act="clear-offer">戻る</button></div>` : ""}
  </main>`;
}

function offerCard(offer) {
  const minis = PRIORITIES.map((item) => {
    const hot = run.priorities.includes(item.id);
    return `<span class="mini${hot ? " hot" : ""}">${esc(item.label)} ${offer[item.id]}</span>`;
  }).join("");
  return `<button class="offer ${offer.id}" type="button" data-act="offer" data-id="${offer.id}" aria-pressed="${pendingOffer === offer.id ? "true" : "false"}">
    <header>
      <span class="co">${esc(offer.mark)}</span>
      <span><strong class="company">${esc(offer.company)}</strong><small>${esc(offer.role)} · 年収の目安 ${esc(offer.payLabel)}（架空）</small></span>
      <span class="fit"><b>${offer.fit}</b><small>一致</small></span>
    </header>
    <p>${esc(offer.blurb)}</p>
    <div class="minis">${minis}</div>
  </button>`;
}

function renderEnding() {
  const ending = endingById(run.endingId);
  const picked = run.choice === "stay" ? "現職に残る" : (run.offers?.find((offer) => offer.id === run.choice)?.company ?? "");
  return `<main class="shell ending">
    <p class="kicker">${esc(picked)}</p>
    <h1>${esc(ending.title)}</h1>
    <p class="lede">${esc(ending.lead)}</p>
    <p>${esc(ending.body)}</p>
    <div class="next"><p class="kicker">次の一手</p><p>${esc(ending.next)}</p></div>
    <ul class="recap">${STATS.map((stat) => `<li>${esc(stat.label)} ${run[stat.key]}</li>`).join("")}<li>応募 ${run.applications}</li><li>面接 ${run.interviewScore}/6</li><li>手帳 ${run.tips.length}</li></ul>
    <div class="row">
      <button class="primary" type="button" data-act="again">もう一度</button>
      <button class="ghost" type="button" data-act="notebook">手帳を見る</button>
    </div>
    <p class="disclaimer">この結末はゲーム内の点数です。現実の転職の成否や、年収の妥当さは示しません。</p>
  </main>`;
}

function renderOverlay() {
  if (overlay === "help") {
    return `<div class="overlay"><div class="sheet" role="dialog" aria-modal="true" aria-labelledby="help-title">
      <h2 id="help-title">遊び方</h2>
      <ol>${HELP.map((line) => `<li>${esc(line)}</li>`).join("")}</ol>
      <button class="primary" type="button" data-act="close">閉じる</button>
    </div></div>`;
  }
  const tips = [...(run?.tips ?? [])].reverse();
  return `<div class="overlay"><div class="sheet" role="dialog" aria-modal="true" aria-labelledby="book-title">
    <h2 id="book-title">手帳</h2>
    ${tips.length ? `<ol>${tips.map((tip) => `<li>${esc(tip)}</li>`).join("")}</ol>` : `<p>まだメモはない。</p>`}
    <button class="primary" type="button" data-act="close">閉じる</button>
  </div></div>`;
}

function onInput(event) {
  if (event.target.id === "player-name") draft.name = event.target.value;
}

function onKey(event) {
  if (event.target.closest("input, textarea")) return;
  if (event.key === "Escape" && overlay) {
    overlay = null;
    render();
    return;
  }
  const number = Number(event.key);
  if (number >= 1 && number <= 4 && !overlay) {
    const button = app.querySelectorAll("[data-act=choice]")[number - 1];
    button?.click();
  }
}

function onClick(event) {
  const button = event.target.closest("[data-act]");
  if (!button || button.disabled) return;
  const act = button.dataset.act;
  const id = button.dataset.id;
  if (act === "how") { overlay = "help"; render(); return; }
  if (act === "notebook") { overlay = "notebook"; render(); return; }
  if (act === "close") { overlay = null; render(); return; }
  if (act === "start") { mode = "create"; notice = ""; overlay = null; render(); return; }
  if (act === "back-title") { mode = "title"; notice = ""; render(); return; }
  if (act === "continue") { mode = "game"; notice = ""; render(); return; }
  if (act === "role") { draft.role = id; notice = ""; render(); return; }
  if (act === "aim") { draft.aim = id; notice = ""; render(); return; }
  if (act === "priority") { togglePriority(id); return; }
  if (act === "begin") { begin(); return; }
  if (act === "action") { commit(takeAction(run, id)); return; }
  if (act === "choice") { answer(id); return; }
  if (act === "ack") { commit(acknowledge(run)); return; }
  if (act === "select") { commit(startSelection(run)); return; }
  if (act === "stay") { commit(remain(run)); return; }
  if (act === "offer") { pendingOffer = id; render(); return; }
  if (act === "clear-offer") { pendingOffer = null; render(); return; }
  if (act === "confirm-offer") { const choice = pendingOffer; pendingOffer = null; commit(chooseOffer(run, choice)); return; }
  if (act === "reset" || act === "again") { reset(); return; }
}

function togglePriority(id) {
  if (draft.priorities.includes(id)) draft.priorities = draft.priorities.filter((item) => item !== id);
  else if (draft.priorities.length >= 2) notice = "大切にするのは2つまで。選んであるものを一度外す。";
  else draft.priorities = [...draft.priorities, id];
  if (draft.priorities.includes(id) || draft.priorities.length < 2) notice = "";
  render();
}

function begin() {
  if (!draft.role) { notice = "いまの仕事を選ぶ"; render(); return; }
  if (!draft.aim) { notice = "向かう先を選ぶ"; render(); return; }
  if (draft.priorities.length !== 2) { notice = "大切にすることを2つ選ぶ"; render(); return; }
  try {
    run = createRun({
      name: draft.name.trim() || "あなた",
      role: draft.role,
      aim: draft.aim,
      priorities: draft.priorities,
    });
    mode = "game";
    notice = "";
    overlay = null;
    persist();
    render();
  } catch {
    notice = "条件をもう一度選ぶ";
    render();
  }
}

function answer(id) {
  if (run.drill) commit(resolveDrill(run, id));
  else commit(answerInterview(run, id));
}

function commit(result) {
  if (result.error) {
    notice = result.error;
    render();
    return;
  }
  run = result.state;
  notice = "";
  persist();
  render();
}

function reset() {
  if (actNeedsConfirm() && !window.confirm("この30日を消して、最初からにしますか。")) return;
  run = null;
  mode = "title";
  notice = "";
  overlay = null;
  pendingOffer = null;
  draft = { name: "", role: "", aim: "", priorities: [] };
  persist();
  render();
}

function actNeedsConfirm() {
  return mode === "game" && run && run.phase !== "ending";
}
