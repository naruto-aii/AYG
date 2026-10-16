/** 短い相槌や修正ではなく、承認の一言だけを通す。 */
export function isApprovalPhrase(text) {
  const normalized = String(text || "")
    .trim()
    .replace(/\s+/g, "")
    .replace(/[。！？!?、.,]/g, "");
  if (!normalized || normalized.length > 20) return false;
  return (
    normalized === "それでいい" ||
    normalized === "それでいいよ" ||
    normalized === "それでいいです" ||
    normalized === "それでお願い" ||
    normalized === "それでお願いします" ||
    normalized === "その内容でいい" ||
    normalized === "その内容でいいよ" ||
    normalized === "承認"
  );
}
