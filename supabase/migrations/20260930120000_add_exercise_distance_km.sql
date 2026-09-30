-- 運動記録に距離（km）を足す。既存の列は変えない。
-- 戻し方: alter table public.exercise_entries drop column if exists distance_km;

alter table public.exercise_entries
  add column if not exists distance_km double precision
    check (distance_km is null or distance_km >= 0);
