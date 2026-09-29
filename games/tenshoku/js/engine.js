import {
  ACTIONS,
  AIMS,
  DRILLS,
  ENDINGS,
  EVENTS,
  FINALS,
  PRIORITIES,
  QUESTS,
  ROLES,
  scoreWord,
} from "./content.js";

export const STAT_MAX = 100;
export const DAY_MAX = 30;
const CAREER_KEYS = ["confidence", "skill", "portfolio", "network", "market"];

export function clamp(n) {
  return Math.max(0, Math.min(STAT_MAX, Math.round(n)));
}

export function nextRand(rngState) {
  let a = rngState | 0;
  a = (a + 0x6d2b79f5) | 0;
  let t = Math.imul(a ^ (a >>> 15), 1 | a);
  t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
  const value = ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  return { rngState: a >>> 0, value };
}

function clone(state) {
  return structuredClone(state);
}

function addStat(state, key, amount) {
  if (key === "money") {
    state.money = Math.max(0, Math.min(99, state.money + amount));
    return;
  }
  state[key] = clamp((state[key] ?? 0) + amount);
}

function gain(state, key, amount, exhausted) {
  const next = amount > 0 && exhausted ? Math.max(1, Math.round(amount * 0.5)) : amount;
  addStat(state, key, next);
}

export function roleById(id) {
  return ROLES.find((role) => role.id === id) ?? null;
}

export function aimById(id) {
  return AIMS.find((aim) => aim.id === id) ?? null;
}

export function priorityById(id) {
  return PRIORITIES.find((item) => item.id === id) ?? null;
}

export function questionById(id) {
  return [...DRILLS, ...FINALS].find((question) => question.id === id) ?? null;
}

export function endingById(id) {
  return ENDINGS[id] ?? null;
}

export function weekOf(day) {
  return Math.min(5, Math.ceil(day / 7));
}

export function weakestLabel(state) {
  const labels = {
    confidence: "自信",
    skill: "スキル",
    portfolio: "作品",
    network: "人脈",
    market: "市場理解",
  };
  let key = CAREER_KEYS[0];
  for (const candidate of CAREER_KEYS) {
    if (state[candidate] < state[key]) key = candidate;
  }
  return labels[key];
}

function pushLog(state, text, tip) {
  state.log.push({ day: state.day, text, tip: tip || "" });
  if (state.log.length > 40) state.log.splice(0, state.log.length - 40);
  if (tip && !state.tips.includes(tip)) state.tips.push(tip);
}

function advanceDay(state) {
  if (state.day >= DAY_MAX) {
    state.deadline = true;
    pushLog(state, "30日が終わった。出すか、残るかを決める日。", "期限の日に新しい準備は足さない。持っている材料で判断する。");
    return;
  }
  state.day += 1;
  if (state.day === 8 || state.day === 15 || state.day === 22) {
    pushLog(
      state,
      `第${weekOf(state.day)}週に入った。いちばん薄いのは${weakestLabel(state)}。次の数日はそこだけ。`,
      "同時に全部は伸ばさない。いちばん薄いものを1つだけ、次の週の対象にする。",
    );
    if (state.stamina < 36) {
      pushLog(state, "体力が薄い。この週は休む日を先に1つ入れる。", "応募が続いている週こそ、予定を1つ空ける。判断が荒くなる。");
    }
  }
}

function eventOk(state, event) {
  const when = event.when ?? {};
  if (when.minNetwork != null && state.network < when.minNetwork) return false;
  if (when.maxNetwork != null && state.network >= when.maxNetwork) return false;
  if (when.minPortfolio != null && state.portfolio < when.minPortfolio) return false;
  if (when.minMarket != null && state.market < when.minMarket) return false;
  if (when.needsOutreach && state.counts.meet + state.counts.apply < 1) return false;
  return true;
}

export function eligibleEvents(state) {
  return EVENTS.filter((event) => eventOk(state, event)).map((event) => event.id);
}

function applyEvent(state, event) {
  for (const [key, amount] of Object.entries(event.delta ?? {})) addStat(state, key, amount);
  if (event.grantApplication && state.applications < 4) state.applications += 1;
  state.lastEvent = event.id;
  pushLog(state, event.text, event.tip);
}

export function applyEventById(state, id) {
  const event = EVENTS.find((item) => item.id === id);
  if (!event) return clone(state);
  const next = clone(state);
  applyEvent(next, event);
  return next;
}

function applyMaybeEvent(state) {
  const before = state.stamina;
  maybeEvent(state);
  if (before > 0 && state.stamina === 0) {
    state.burnoutDays += 1;
    state.exhausted = true;
  }
}

function maybeEvent(state) {
  if (state.suppressEvents) return;
  const roll = nextRand(state.rngState);
  state.rngState = roll.rngState;
  if (roll.value > 0.34) return;
  const pool = EVENTS.filter((event) => eventOk(state, event));
  if (!pool.length) return;
  const second = nextRand(state.rngState);
  state.rngState = second.rngState;
  const total = pool.reduce((sum, event) => sum + event.weight, 0);
  let cursor = second.value * total;
  let chosen = pool[pool.length - 1];
  for (const event of pool) {
    cursor -= event.weight;
    if (cursor <= 0) {
      chosen = event;
      break;
    }
  }
  applyEvent(state, chosen);
}

function aimBonus(state, actionId, exhausted) {
  if (actionId === "resume" && state.aim === "pivot") gain(state, "market", 2, exhausted);
  if (actionId === "meet" && (state.aim === "lead" || state.aim === "independent")) {
    gain(state, "confidence", 2, exhausted);
  }
  if (actionId === "study" && state.aim === "deepen") gain(state, "skill", 2, exhausted);
  if (actionId === "research" && state.aim === "pivot") gain(state, "portfolio", 2, exhausted);
}

function settleStrain(state, actionId) {
  if (actionId === "rest") {
    state.exhausted = false;
    return;
  }
  if (state.stamina === 0) {
    state.burnoutDays += 1;
    state.exhausted = true;
    return;
  }
  state.exhausted = false;
}

export function pickQuestions(pool, seed, count) {
  const list = [...pool];
  let rngState = seed >>> 0;
  for (let i = list.length - 1; i > 0; i -= 1) {
    const roll = nextRand(rngState);
    rngState = roll.rngState;
    const j = Math.floor(roll.value * (i + 1));
    [list[i], list[j]] = [list[j], list[i]];
  }
  return list.slice(0, count);
}

export function createRun(input) {
  const name = String(input.name ?? "").replace(/\s+/g, " ").trim();
  if (name.length < 1 || name.length > 12) throw new Error("name");
  const role = roleById(input.role);
  const aim = aimById(input.aim);
  if (!role || !aim) throw new Error("path");
  const priorities = Array.isArray(input.priorities) ? [...input.priorities] : [];
  if (priorities.length !== 2 || new Set(priorities).size !== 2 || priorities.some((id) => !priorityById(id))) {
    throw new Error("priorities");
  }
  const seed = (input.seed ?? Math.floor(Math.random() * 0x7fffffff)) >>> 0;
  const state = {
    version: 1,
    seed,
    rngState: seed,
    name,
    role: role.id,
    aim: aim.id,
    priorities,
    day: 1,
    stamina: 64,
    confidence: 18,
    skill: 16,
    portfolio: 12,
    network: 14,
    market: 12,
    money: 18,
    applications: 0,
    interviewScore: 0,
    interviewIndex: 0,
    interviewIds: [],
    burnoutDays: 0,
    exhausted: false,
    counts: { resume: 0, study: 0, meet: 0, research: 0, drill: 0, rest: 0, apply: 0 },
    log: [],
    tips: [],
    drill: null,
    hold: null,
    phase: "plan",
    deadline: false,
    offers: null,
    choice: null,
    endingId: null,
    questBonus: false,
    lastEvent: null,
  };
  for (const [key, amount] of Object.entries(role.bonus)) addStat(state, key, amount);
  if (aim.id === "pivot") addStat(state, "market", 4);
  if (aim.id === "independent") addStat(state, "portfolio", 4);
  if (aim.id === "lead") addStat(state, "confidence", 4);
  if (aim.id === "deepen") addStat(state, "skill", 4);
  pushLog(state, "30日ある。今日は、応募文ではなく材料を集める日にする。", "最初の1週間は、応募文より先に材料を揃える。");
  return state;
}

function applyBlock(state) {
  if (state.counts.resume < 1 && state.counts.research < 1) {
    return "応募の前に、経歴を1行にするか、求人を1件分解する";
  }
  if (state.applications >= 4) return "同時に進めるのは4社まで";
  return null;
}

export function actionBlock(state, actionId) {
  if (!state || state.phase !== "plan") return "いまは動けない";
  if (state.hold) return "メモを先に読む";
  if (state.drill) return "模擬面接の答えを先に選ぶ";
  if (state.deadline) return "30日が終わった。選考か、現職に残るかを決める";
  const action = ACTIONS.find((item) => item.id === actionId);
  if (!action) return "その行動はない";
  if (actionId === "apply") {
    const reason = applyBlock(state);
    if (reason) return reason;
  }
  if (action.cost > 0 && state.stamina < action.cost) return "体力が足りない。休んでからにする";
  return null;
}

export function selectionBlock(state) {
  if (!state || state.phase !== "plan") return "いまは進めない";
  if (state.hold || state.drill) return "開いている確認を先に閉じる";
  if (state.applications < 1) return "応募が1件もない";
  if (state.day < 8 && !state.deadline) return "8日目以降に進める";
  return null;
}

export function remainBlock(state) {
  if (!state || state.phase !== "plan") return "いまは選べない";
  if (state.hold || state.drill) return "開いている確認を先に閉じる";
  if (!state.deadline && state.day < 15) return "15日目までは材料を集める";
  return null;
}

export function questProgress(state) {
  return QUESTS.map((quest) => ({
    id: quest.id,
    label: quest.label,
    need: quest.need,
    current: state.counts[quest.countKey],
    done: state.counts[quest.countKey] >= quest.need,
  }));
}

export function questsComplete(state) {
  return questProgress(state).every((quest) => quest.done);
}

export function takeAction(state, actionId) {
  const error = actionBlock(state, actionId);
  if (error) return { state, error };
  const action = ACTIONS.find((item) => item.id === actionId);
  const next = clone(state);
  const exhausted = next.exhausted;

  if (actionId === "rest") {
    const low = next.stamina < 30;
    next.stamina = clamp(next.stamina + 30 + (low ? 8 : 0));
    gain(next, "confidence", 1, false);
    next.counts.rest += 1;
    pushLog(next, action.log, action.tip);
    settleStrain(next, actionId);
    advanceDay(next);
    return { state: next, error: null };
  }

  if (actionId === "drill") {
    const question = pickQuestions(DRILLS, (next.seed + next.day * 17 + next.counts.drill * 31) >>> 0, 1)[0];
    next.stamina = clamp(next.stamina - action.cost);
    next.drill = { questionId: question.id };
    if (next.stamina === 0) {
      next.burnoutDays += 1;
      next.exhausted = true;
    }
    return { state: next, error: null };
  }

  next.stamina = clamp(next.stamina - action.cost);
  if (actionId === "study") {
    const poor = next.money < 2;
    if (!poor) next.money -= 2;
    const gains = poor ? action.poorGains : action.gains;
    for (const [key, amount] of Object.entries(gains)) gain(next, key, amount, exhausted);
    next.counts.study += 1;
    pushLog(next, poor ? action.poorLog : action.log, action.tip);
  } else if (actionId === "apply") {
    next.applications += 1;
    next.counts.apply += 1;
    if (next.portfolio >= 40) gain(next, "confidence", 4, exhausted);
    else addStat(next, "confidence", -1);
    gain(next, "market", 2, exhausted);
    pushLog(next, action.log, action.tip);
  } else {
    for (const [key, amount] of Object.entries(action.gains)) gain(next, key, amount, exhausted);
    next.counts[actionId] += 1;
    pushLog(next, action.log, action.tip);
  }
  aimBonus(next, actionId, exhausted);
  settleStrain(next, actionId);
  if (actionId !== "rest") applyMaybeEvent(next);
  advanceDay(next);
  return { state: next, error: null };
}

export function resolveDrill(state, choiceId) {
  if (!state.drill) return { state, error: "模擬面接は開いていない" };
  if (state.hold) return { state, error: "メモを先に読む" };
  const question = questionById(state.drill.questionId);
  const choice = question?.choices.find((item) => item.id === choiceId);
  if (!choice) return { state, error: "その答えはない" };
  const next = clone(state);
  const exhausted = next.exhausted;
  if (choice.score >= 2) {
    gain(next, "confidence", 8, exhausted);
    gain(next, "skill", 2, exhausted);
  } else if (choice.score === 1) {
    gain(next, "confidence", 4, exhausted);
    gain(next, "market", 2, exhausted);
  } else {
    addStat(next, "confidence", -3);
    gain(next, "market", 3, false);
  }
  next.counts.drill += 1;
  next.drill = null;
  next.exhausted = next.stamina === 0;
  next.hold = {
    kind: "drill",
    prompt: question.prompt,
    choice: choice.text,
    note: choice.note,
    score: choice.score,
  };
  pushLog(next, `模擬面接の答えは「${scoreWord(choice.score)}」だった。`, choice.note);
  applyMaybeEvent(next);
  advanceDay(next);
  return { state: next, error: null };
}

export function acknowledge(state) {
  if (!state.hold) return { state, error: "確認するものがない" };
  const next = clone(state);
  next.hold = null;
  return { state: next, error: null };
}

export function startSelection(state) {
  const error = selectionBlock(state);
  if (error) return { state, error };
  const next = clone(state);
  if (questsComplete(next) && !next.questBonus) {
    next.confidence = clamp(next.confidence + 8);
    next.questBonus = true;
    pushLog(next, "4つの準備が揃った。面接の前に、自信が一段上がった。", "揃える対象は4つで足りる。増やすより、薄いものを埋める。");
  }
  next.interviewIds = pickQuestions(FINALS, (next.seed ^ 0x9e3779b9) >>> 0, 3).map((question) => question.id);
  next.interviewIndex = 0;
  next.interviewScore = 0;
  next.phase = "interview";
  pushLog(next, "選考に進む。質問は3つ。性格のテストではなく、材料が相手の仕事に合うかの確認。", "面接の答えは、相手の仕事の単位に自分の材料を結びつけて短くする。");
  return { state: next, error: null };
}

export function answerInterview(state, choiceId) {
  if (state.phase !== "interview") return { state, error: "面接中ではない" };
  if (state.hold) return { state, error: "メモを先に読む" };
  const question = questionById(state.interviewIds[state.interviewIndex]);
  const choice = question?.choices.find((item) => item.id === choiceId);
  if (!choice) return { state, error: "その答えはない" };
  const next = clone(state);
  next.interviewScore += choice.score;
  next.interviewIndex += 1;
  next.hold = {
    kind: "interview",
    prompt: question.prompt,
    choice: choice.text,
    note: choice.note,
    score: choice.score,
  };
  pushLog(next, `面接${next.interviewIndex}問目は「${scoreWord(choice.score)}」。`, choice.note);
  if (next.interviewIndex >= next.interviewIds.length) {
    next.offers = generateOffers(next);
    next.phase = "offers";
  }
  return { state: next, error: null };
}

const FIT_KEYS = ["pay", "time", "growth", "people", "stability", "meaning"];

export function offerFit(offer, priorities) {
  let weighted = 0;
  let weight = 0;
  for (const key of FIT_KEYS) {
    const scale = priorities.includes(key) ? 3 : 1;
    weighted += offer[key] * scale;
    weight += scale;
  }
  return clamp(Math.round(weighted / weight));
}

function payLabel(score) {
  return `${360 + score * 3}万円`;
}

function roleTitle(state, companyId) {
  const map = {
    engineer: { aoba: "開発", lamp: "プロダクト開発", midori: "店の開発" },
    sales: { aoba: "法人営業", lamp: "導入の担当", midori: "店と客の間" },
    corporate: { aoba: "管理", lamp: "オペレーション", midori: "数字と段取り" },
    design: { aoba: "デザイン", lamp: "プロダクトの見た目", midori: "売り場の見た目" },
    field: { aoba: "専門職", lamp: "現場の設計", midori: "店の専門" },
  };
  const base = map[state.role][companyId];
  if (state.aim === "lead") return `${base}のリード`;
  if (state.aim === "pivot") return `${base}（越境）`;
  if (state.aim === "independent") return `${base} / 個人の型`;
  return base;
}

export function generateOffers(state) {
  const tries = Math.min(state.applications, 4);
  const iv = state.interviewScore;
  const drafts = [
    {
      id: "aoba",
      company: "青葉製作所",
      mark: "青",
      blurb: "決まった仕事の型がある。変化は遅い。評価は年に一度、役割は明確。",
      pay: clamp(36 + state.skill * 0.18 + iv * 2 + tries),
      time: 84,
      growth: clamp(34 + state.skill * 0.12),
      people: 74,
      stability: 92,
      meaning: clamp(44 + (state.aim === "deepen" ? 16 : 0)),
    },
    {
      id: "lamp",
      company: "灯台ラボ",
      mark: "灯",
      blurb: "仕事の境界が薄い。伸びる余地は大きい。休む設計は、自分で持っていく。",
      pay: clamp(44 + state.skill * 0.26 + state.portfolio * 0.1 + iv * 3 + tries),
      time: clamp(26 + state.confidence * 0.12),
      growth: clamp(72 + state.skill * 0.18),
      people: 56,
      stability: 32,
      meaning: clamp(50 + (state.aim === "pivot" ? 14 : 0) + (state.aim === "independent" ? 10 : 0)),
    },
    {
      id: "midori",
      company: "みどり商店",
      mark: "緑",
      blurb: "小さいチーム。紹介だと話が早い。役割は広く、給与の天井は近くにある。",
      pay: clamp(38 + state.network * 0.22 + state.portfolio * 0.12 + iv * 2),
      time: 72,
      growth: clamp(46 + (state.aim === "lead" ? 18 : 8)),
      people: clamp(78 + state.network * 0.1),
      stability: 62,
      meaning: clamp(74 + (state.aim === "independent" ? 12 : 0)),
    },
  ];
  return drafts.map((draft) => ({
    ...draft,
    role: roleTitle(state, draft.id),
    payLabel: payLabel(draft.pay),
    fit: offerFit(draft, state.priorities),
  }));
}

export function judgeEnding(state, choiceId) {
  if (choiceId === "stay") {
    if (state.burnoutDays >= 2) return "rest";
    if (state.applications === 0) return "no-apply";
    if (state.portfolio >= 40 && state.market >= 35) return "stay-strong";
    return "prepare";
  }
  const offer = state.offers.find((item) => item.id === choiceId);
  const fit = offer.fit;
  const ready = state.interviewScore >= 4 && (state.portfolio >= 28 || state.skill >= 36 || state.network >= 42);
  if (state.burnoutDays >= 2) return "tired-start";
  if (choiceId === "midori" && state.network >= 55 && fit >= 60) return "referral";
  if (offer.pay >= 68 && fit < 64) return "money";
  if (fit >= 70 && ready) return "fit";
  if (!ready) return "stretch";
  return "step";
}

function closeWith(state, choiceId) {
  const next = clone(state);
  next.choice = choiceId;
  next.endingId = judgeEnding(next, choiceId);
  next.phase = "ending";
  next.hold = null;
  next.drill = null;
  const ending = ENDINGS[next.endingId];
  pushLog(next, ending.title, ending.next);
  return { state: next, error: null };
}

export function chooseOffer(state, offerId) {
  if (state.phase !== "offers") return { state, error: "まだ条件の画面ではない" };
  if (state.hold) return { state, error: "メモを先に読む" };
  if (offerId !== "stay" && !state.offers.some((offer) => offer.id === offerId)) {
    return { state, error: "その席はない" };
  }
  return closeWith(state, offerId);
}

export function remain(state) {
  const error = remainBlock(state);
  if (error) return { state, error };
  return closeWith(state, "stay");
}
