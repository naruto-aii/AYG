/// App Store Connect のアプリ本体 SKU。Parent Identifier と比較する。秘密ではない。
/// リポジトリに SKU そのものは無く、公開の識別子はバンドル ID `com.narutoaii.ayg` だけなのでそれを初期値にする。
/// 売上ファイルのアプリ行で別の SKU を見たら表に残し、アプリ行が無い日も両方で突き合わせる。
export const configuredParentSkus = ["com.narutoaii.ayg"];

export function parentSkusToUse(configured: readonly string[], stored: readonly string[]): string[] {
  const skus = new Set<string>();
  for (const sku of [...configured, ...stored]) {
    const trimmed = sku.trim();
    if (trimmed) skus.add(trimmed);
  }
  return [...skus];
}
