// レビュー用の再現。本番の論理は変えていない。マージしない。
//
// 返金した transactionId を残すマイグレーションは、空でない本番では
// 045607 → 143000 → 190000 のあとに当てる。ファイル名の時刻が
// 143000 より前だと、その順にならない。
import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";

Deno.test("the revoked transaction migration sorts after 045607, 143000, and 190000", () => {
  const names = [...Deno.readDirSync(new URL("../migrations/", import.meta.url))]
    .map((entry) => entry.name)
    .filter((name) => name.endsWith(".sql"))
    .sort();
  const chain = names.filter((name) =>
    name.startsWith("20261010045607") ||
    name.startsWith("20261010143000") ||
    name.startsWith("20261010190000") ||
    name.includes("revoked_store_transactions")
  );
  const revoked = chain.filter((name) => name.includes("revoked_store_transactions"));
  assertEquals(revoked.length, 1);
  const expected = [
    chain.find((name) => name.startsWith("20261010045607")),
    chain.find((name) => name.startsWith("20261010143000")),
    chain.find((name) => name.startsWith("20261010190000")),
    revoked[0],
  ];
  assertEquals(chain, expected);
});
