-- Local Supabase seed: table privileges for integration tests.
-- RLS policies (defined in migrations) restrict rows; GRANT enables role access.
-- This file is applied by `supabase db reset` only — not deployed to production.

grant select, insert, update, delete on public.users to authenticated;
grant select, insert, update, delete on public.profiles to authenticated;
grant select, insert, update, delete on public.goals to authenticated;
grant select, insert, update, delete on public.nutrition_settings to authenticated;
grant select, insert, update, delete on public.health_snapshots to authenticated;
grant select, insert, update, delete on public.app_settings to authenticated;
grant select, insert, update, delete on public.food_entries to authenticated;
grant select, insert, update, delete on public.exercise_entries to authenticated;
grant select, insert, update, delete on public.weight_entries to authenticated;
