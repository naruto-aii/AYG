export function sanitizeMessages(raw) {
  if (!Array.isArray(raw)) {
    throw new Error("messages が不正です");
  }
  const out = [];
  for (const message of raw.slice(-20)) {
    if (!message || (message.role !== "user" && message.role !== "assistant")) continue;
    if (typeof message.content !== "string") continue;
    const content = message.content.trim().slice(0, 1500);
    if (!content) continue;
    const prev = out[out.length - 1];
    if (prev && prev.role === message.role) {
      prev.content = `${prev.content}\n${content}`.slice(0, 1500);
    } else {
      out.push({ role: message.role, content });
    }
  }
  if (!out.length || out.at(-1).role !== "user") {
    throw new Error("最後は相手の発話にしてください");
  }
  return out;
}

/** 古い往復は短い要約にし、直近だけ原文を残す。 */
export function compressMessages(messages) {
  const cleaned = sanitizeMessages(messages);
  if (cleaned.length <= 5) return cleaned;
  const recent = cleaned.slice(-4);
  const older = cleaned.slice(0, -4);
  const summary = older
    .map((message) => {
      const who = message.role === "user" ? "相手" : "VP";
      const line = message.content.replace(/\s+/g, " ").slice(0, 36);
      return `${who}:${line}`;
    })
    .join(" / ")
    .slice(0, 240);
  const head = [
    { role: "user", content: `これまでの要約。${summary}` },
    { role: "assistant", content: "了解。" },
  ];
  if (recent[0].role === "assistant") {
    return [...head, { role: "user", content: "続けて。" }, ...recent];
  }
  return [...head, ...recent];
}
