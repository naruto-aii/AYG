import { mouthOpenness } from "./speech.js";

const BLINK_CLOSE = 0.16;
const BLINK_OPEN = 0.2;

export function smootherstep(amount) {
  const t = Math.min(1, Math.max(0, amount));
  return t * t * t * (t * (t * 6 - 15) + 10);
}

export function stepSpring(state, target, dt, omega) {
  const step = Math.min(Math.max(dt, 0), 0.05);
  const accel = omega * omega * (target - state.value) - 2 * omega * state.velocity;
  state.velocity += accel * step;
  state.value += state.velocity * step;
  if (Math.abs(state.value - target) < 0.0004 && Math.abs(state.velocity) < 0.0004) {
    state.value = target;
    state.velocity = 0;
  }
  return state;
}

export function createMotion(random = Math.random) {
  return {
    random,
    blinkPhase: "wait",
    blinkFrom: 0,
    nextBlink: 0.5,
    blinkSpring: { value: 0, velocity: 0 },
    mouth: { value: 0, velocity: 0 },
    listen: { value: 0, velocity: 0 },
  };
}

function clamp01(value) {
  if (!Number.isFinite(value)) return 0;
  return Math.min(1, Math.max(0, value));
}

function advanceBlink(state, time, manual) {
  if (state.blinkPhase === "wait" && time >= state.nextBlink) {
    state.blinkPhase = "close";
    state.blinkFrom = state.nextBlink;
  }
  if (state.blinkPhase === "close") {
    const along = (time - state.blinkFrom) / BLINK_CLOSE;
    if (along >= 1) {
      state.blinkPhase = "open";
      state.blinkFrom += BLINK_CLOSE;
    } else {
      return smootherstep(along);
    }
  }
  if (state.blinkPhase === "open") {
    const along = (time - state.blinkFrom) / BLINK_OPEN;
    if (along >= 1) {
      state.blinkPhase = "wait";
      state.nextBlink = time + (manual ? 2.15 : 2.2 + state.random() * 2);
      return 0;
    }
    return 1 - smootherstep(along);
  }
  return 0;
}

export function speechMouth(speech, nowMs) {
  const elapsed = Math.max(0, (nowMs - speech.at) / 1000);
  const mora = 0.12 / (speech.rate || 1);
  const pos = elapsed / mora;
  const index = Math.floor(pos);
  const text = speech.text || "";
  if (index >= text.length) return 0.05;
  const fraction = pos - index;
  const from = mouthOpenness(text, index);
  const to = mouthOpenness(text, index + 1);
  const blend = fraction * fraction * (3 - 2 * fraction);
  const shape = 0.4 + 0.6 * Math.sin(Math.PI * Math.min(1, Math.max(0, fraction)));
  return clamp01((from + (to - from) * blend) * shape);
}

export function speechEnvelope(time) {
  const slow = 0.5 + 0.5 * Math.sin(time * Math.PI * 2 * 3.1);
  const fast = 0.5 + 0.5 * Math.sin(time * Math.PI * 2 * 4.7 + 0.8);
  return 0.05 + 0.55 * slow ** 1.25 * (0.5 + 0.5 * fast);
}

export function stepMotion(state, input, out) {
  const dt = Math.min(Math.max(input.dt || 0, 0), 0.05);
  const time = input.time || 0;
  const mode = input.mode || "idle";
  const autoBlink = advanceBlink(state, time, Boolean(input.manual));
  const forcedBlink = input.forcedBlink;
  if (forcedBlink != null && forcedBlink !== "") {
    stepSpring(state.blinkSpring, clamp01(Number(forcedBlink)), dt, 12);
    out.blink = clamp01(state.blinkSpring.value);
  } else {
    out.blink = autoBlink;
    state.blinkSpring.value = autoBlink;
    state.blinkSpring.velocity = 0;
  }

  stepSpring(state.listen, mode === "listening" ? 1 : 0, dt, 3.2);
  const listen = clamp01(state.listen.value);
  const forcedMouth = input.forcedMouth;
  let mouthGoal = 0;
  if (forcedMouth != null && forcedMouth !== "") mouthGoal = clamp01(Number(forcedMouth));
  else if (input.speech?.text) mouthGoal = speechMouth(input.speech, input.now);
  else if (mode === "speaking") mouthGoal = speechEnvelope(time);
  stepSpring(state.mouth, mouthGoal, dt, 16);
  out.mouth = clamp01(state.mouth.value);

  let nod = Math.sin(time * 0.45) * 0.04;
  const age = time - (input.nodAt ?? -10);
  if (age >= 0 && age < 0.78) {
    const along = age / 0.78;
    nod += Math.sin(Math.PI * along) ** 2 * 0.28;
  }
  nod += Math.sin(time * 1.5) ** 2 * 0.26 * listen;
  if (mode === "thinking") nod -= 0.06;
  out.nod = nod;
  out.turn = Math.sin(time * 0.33) * (0.28 + 0.22 * listen);
  out.gazeX = Math.sin(time * 0.21) * 0.004;
  out.gazeY = Math.sin(time * 0.17 + 1.2) * 0.0025;
  return out;
}
