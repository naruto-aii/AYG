import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";

function readRepo(path: string): string {
  return Deno.readTextFileSync(new URL(`../../${path}`, import.meta.url));
}

Deno.test("the collection migration is collect-only and the cache is per user", () => {
  const sql = readRepo("supabase/migrations/20261008190000_ai_food_result_collections.sql");
  assertEquals(sql.includes("source_path in ('ai_search', 'photo')"), true);
  assertEquals(sql.includes("grant insert on table public.ai_food_result_collections to authenticated"), true);
  assertEquals(sql.includes("grant select on table public.ai_food_result_collections"), false);
  assertEquals(sql.includes("for select"), false);
  assertEquals(sql.includes("revoke all on table public.ai_food_result_collections"), true);
  assertEquals(sql.includes("delete from public.ai_food_estimate_cache"), true);
  assertEquals(sql.includes("add primary key (user_id, query_key)"), true);
  assertEquals(sql.includes("kpi.excluded_user_ids"), true);
  assertEquals(sql.includes("insert into public.saved_foods"), false);
  assertEquals(sql.includes("search_public_foods"), false);
  assertEquals(sql.includes("returns void"), true);

  const searchFiles = [
    "lib/repositories/supabase/supabase_saved_food_repository.dart",
    "supabase/migrations/20261008003832_search_public_foods_voice.sql",
    "supabase/migrations/20261006200000_food_search_quality.sql",
  ];
  for (const path of searchFiles) {
    assertEquals(readRepo(path).includes("ai_food_result_collections"), false, path);
  }
});
