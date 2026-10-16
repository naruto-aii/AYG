export function asList(value) {
  if (!Array.isArray(value)) return [];
  return value
    .map((item) => String(item).replace(/\s+/g, " ").trim().slice(0, 160))
    .filter(Boolean)
    .slice(0, 6);
}

export function parseMinutes(text) {
  const start = String(text || "").indexOf("{");
  const end = String(text || "").lastIndexOf("}");
  if (start < 0 || end <= start) return null;
  try {
    const json = JSON.parse(text.slice(start, end + 1));
    return {
      points: asList(json.points),
      decisions: asList(json.decisions),
      todos: asList(json.todos),
    };
  } catch {
    return null;
  }
}

export function localMinutes(transcript) {
  const lines = Array.isArray(transcript) ? transcript : [];
  const textOf = (item) => String(item?.text || item?.content || "");
  const points = lines
    .filter((item) => item.role === "user")
    .map((item) => textOf(item).slice(0, 80))
    .filter(Boolean)
    .slice(0, 4);
  const decisions = lines
    .map(textOf)
    .filter((line) => /決め|でいこう|そうする|採用|揃える/.test(line))
    .slice(0, 4);
  const todos = lines
    .map(textOf)
    .filter((line) => /宿題|あとで|お願い|直して|追加|頼ん/.test(line))
    .slice(0, 4);
  return { points, decisions, todos };
}

export function renderMinutes({ points, decisions, todos, requests, yen, elapsedSec, saving }) {
  const minutes = Math.floor((elapsedSec || 0) / 60);
  const seconds = Math.floor((elapsedSec || 0) % 60);
  const section = (title, items) => {
    const body = items.length ? items.map((item) => `- ${item}`).join("\n") : "- なし";
    return `## ${title}\n${body}`;
  };
  const requestLines = (requests || []).length
    ? requests
        .map((item) => `- ${item.instruction}\n  - ${item.url || "URLなし"}`)
        .join("\n")
    : "- なし";
  return [
    "# 打ち合わせ議事録",
    "",
    `- 時間: ${minutes}分${seconds}秒`,
    `- 概算費用: ${Number(yen || 0).toFixed(2)}円（予算10円、1ドル150円の概算）`,
    saving ? "- 途中から節約モード" : "- 節約モードには入っていない",
    "",
    section("要点", points),
    "",
    section("決まったこと", decisions),
    "",
    section("宿題", todos),
    "",
    "## Cursorに出した依頼",
    requestLines,
    "",
  ].join("\n");
}
