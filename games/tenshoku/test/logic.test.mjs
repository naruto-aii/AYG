import assert from "node:assert/strict";
import test from "node:test";
import {
  acknowledge,
  actionBlock,
  answerInterview,
  applyEventById,
  chooseOffer,
  createRun,
  eligibleEvents,
  generateOffers,
  judgeEnding,
  offerFit,
  pickQuestions,
  questionById,
  questsComplete,
  remain,
  resolveDrill,
  startSelection,
  takeAction,
} from "../js/engine.js";

function run(seed = 1, extra = {}) {
  return {
    ...createRun({
      name: "青葉",
      role: "engineer",
      aim: "deepen",
      priorities: ["growth", "pay"],
      seed,
    }),
    ...extra,
  };
}

function bestChoice(question) {
  return [...question.choices].sort((a, b) => b.score - a.score)[0];
}

function act(state, actionId, choice = "best") {
  let result = takeAction(state, actionId);
  assert.equal(result.error, null, result.error ?? "");
  state = result.state;
  if (state.drill) {
    const question = questionById(state.drill.questionId);
    const picked = choice === "best" ? bestChoice(question) : question.choices.find((item) => item.score === 0);
    result = resolveDrill(state, picked.id);
    assert.equal(result.error, null);
    state = result.state;
  }
  if (state.hold) state = acknowledge(state).state;
  return state;
}

test("createRun applies the role bonus and rejects a bad setup", () => {
  const state = run();
  assert.equal(state.skill, 16 + 8 + 4);
  assert.equal(state.portfolio, 12 + 4);
  assert.equal(state.day, 1);
  assert.throws(() => createRun({ name: " ", role: "engineer", aim: "deepen", priorities: ["pay", "time"], seed: 1 }), /name/);
  assert.throws(() => createRun({ name: "青", role: "engineer", aim: "deepen", priorities: ["pay", "pay"], seed: 1 }), /priorities/);
});

test("a resume line advances the day and the portfolio", () => {
  const state = act(run(), "resume");
  assert.equal(state.day, 2);
  assert.equal(state.counts.resume, 1);
  assert.ok(state.portfolio > 16);
  assert.ok(state.tips.some((tip) => tip.includes("期間・役割・数字")));
});

test("empty stamina blocks work, and rest clears the penalty", () => {
  let state = run(1, { suppressEvents: true });
  state = act(state, "study");
  state = act(state, "study");
  state = act(state, "study");
  state = act(state, "study");
  assert.equal(state.stamina, 0);
  assert.equal(state.burnoutDays, 1);
  assert.equal(state.exhausted, true);
  const blocked = takeAction(state, "study");
  assert.match(blocked.error, /体力/);
  state = act(state, "rest");
  assert.ok(state.stamina >= 30);
  assert.equal(state.exhausted, false);
});

test("exhaustion halves the next gain", () => {
  let spent = run(1, { suppressEvents: true });
  spent = act(spent, "study");
  spent = act(spent, "study");
  spent = act(spent, "study");
  spent = act(spent, "study");
  const ready = { ...spent, stamina: 40, exhausted: true, deadline: false, phase: "plan", drill: null, hold: null };
  const halved = act(structuredClone(ready), "resume");
  const full = act(structuredClone({ ...ready, exhausted: false }), "resume");
  assert.ok(full.portfolio > halved.portfolio);
});

test("applying needs a line of evidence, then records one company", () => {
  const blocked = takeAction(run(1, { suppressEvents: true }), "apply");
  assert.match(blocked.error, /経歴|求人/);
  let state = act(run(1, { suppressEvents: true }), "research");
  state = act(state, "apply");
  assert.equal(state.applications, 1);
  assert.equal(state.counts.apply, 1);
});

test("a strong drill answer builds more confidence than a trap", () => {
  const opened = takeAction(run(4), "drill").state;
  const question = questionById(opened.drill.questionId);
  const good = resolveDrill(opened, bestChoice(question).id).state;
  const bad = resolveDrill(opened, question.choices.find((choice) => choice.score === 0).id).state;
  assert.ok(good.confidence > bad.confidence);
  assert.equal(acknowledge(good).state.hold, null);
});

test("question draws are stable", () => {
  const first = pickQuestions([{ id: "a" }, { id: "b" }, { id: "c" }, { id: "d" }], 9, 3).map((item) => item.id);
  const second = pickQuestions([{ id: "a" }, { id: "b" }, { id: "c" }, { id: "d" }], 9, 3).map((item) => item.id);
  assert.deepEqual(first, second);
  assert.equal(first.length, 3);
});

test("stated priorities change which offer fits", () => {
  const low = { pay: 20, time: 80, growth: 50, people: 50, stability: 50, meaning: 50 };
  const high = { ...low, pay: 90 };
  const payGap = offerFit(high, ["pay", "time"]) - offerFit(low, ["pay", "time"]);
  const otherGap = offerFit(high, ["meaning", "people"]) - offerFit(low, ["meaning", "people"]);
  assert.ok(payGap > otherGap);
});

test("the three fictional offers keep their shapes", () => {
  let state = run(2);
  state = act(state, "resume");
  state = act(state, "meet");
  state = act(state, "study");
  const offers = generateOffers({ ...state, interviewScore: 4, applications: 1 });
  assert.deepEqual(offers.map((offer) => offer.id), ["aoba", "lamp", "midori"]);
  assert.ok(offers[0].stability > offers[1].stability);
  assert.ok(offers[1].growth > offers[0].growth);
  assert.ok(offers[2].meaning > offers[0].meaning);
  assert.match(offers[1].payLabel, /万円/);
  assert.deepEqual(generateOffers(state), generateOffers(state));
});

test("ending rules follow preparation, money, referral, and fatigue", () => {
  assert.equal(judgeEnding({ burnoutDays: 0, applications: 0, portfolio: 10, market: 10 }, "stay"), "no-apply");
  assert.equal(judgeEnding({ burnoutDays: 2, applications: 0, portfolio: 10, market: 10 }, "stay"), "rest");
  assert.equal(judgeEnding({ burnoutDays: 0, applications: 2, portfolio: 50, market: 40 }, "stay"), "stay-strong");
  assert.equal(judgeEnding({ burnoutDays: 0, applications: 1, portfolio: 20, market: 20 }, "stay"), "prepare");
  const base = { burnoutDays: 0, network: 20, interviewScore: 6, portfolio: 40, skill: 40 };
  assert.equal(judgeEnding({ ...base, offers: [{ id: "lamp", pay: 60, fit: 75 }] }, "lamp"), "fit");
  assert.equal(judgeEnding({ ...base, interviewScore: 1, portfolio: 10, skill: 10, network: 10, offers: [{ id: "lamp", pay: 50, fit: 80 }] }, "lamp"), "stretch");
  assert.equal(judgeEnding({ ...base, offers: [{ id: "lamp", pay: 80, fit: 50 }] }, "lamp"), "money");
  assert.equal(judgeEnding({ ...base, network: 60, offers: [{ id: "midori", pay: 50, fit: 66 }] }, "midori"), "referral");
  assert.equal(judgeEnding({ ...base, burnoutDays: 2, offers: [{ id: "lamp", pay: 60, fit: 90 }] }, "lamp"), "tired-start");
});

test("events stay inside their conditions", () => {
  const fresh = run();
  assert.deepEqual(eligibleEvents(fresh), ["overtime"]);
  const met = act(fresh, "meet");
  assert.ok(eligibleEvents(met).includes("rumor"));
  const rumor = applyEventById(met, "rumor");
  assert.ok(rumor.confidence < met.confidence);
  const referred = applyEventById(met, "referral");
  assert.equal(referred.applications, met.applications + 1);
});

test("a prepared month can reach an offer and an ending", () => {
  let state = run(11, { suppressEvents: true });
  for (const id of ["resume", "resume", "research", "research", "rest", "meet", "meet", "study", "drill", "rest", "apply"]) {
    state = act(state, id);
  }
  assert.equal(questsComplete(state), true);
  assert.equal(selectionBlockSafe(state), null);
  state = startSelection(state).state;
  assert.equal(state.questBonus, true);
  while (state.phase === "interview") {
    const question = questionById(state.interviewIds[state.interviewIndex]);
    state = answerInterview(state, bestChoice(question).id).state;
    state = acknowledge(state).state;
  }
  assert.equal(state.phase, "offers");
  assert.equal(state.offers.length, 3);
  const picked = [...state.offers].sort((a, b) => b.fit - a.fit)[0];
  state = chooseOffer(state, picked.id).state;
  assert.equal(state.phase, "ending");
  assert.ok(state.endingId);
});

function selectionBlockSafe(state) {
  const result = startSelection(state);
  if (result.error) return result.error;
  return null;
}

test("thirty days close the planner", () => {
  let state = run(5);
  for (let i = 0; i < 30; i += 1) state = act(state, "rest");
  assert.equal(state.day, 30);
  assert.equal(state.deadline, true);
  assert.match(actionBlock(state, "rest"), /30日/);
});

test("staying without an application is its own ending", () => {
  let state = run(6);
  for (let i = 0; i < 14; i += 1) state = act(state, "rest");
  assert.equal(state.day, 15);
  state = remain(state).state;
  assert.equal(state.endingId, "no-apply");
});
