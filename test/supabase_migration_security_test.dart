import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Supabase migration security', () {
    late String workoutTemplatesSql;
    late String exerciseCalcSql;
    late String baseSchemaSql;

    setUpAll(() {
      workoutTemplatesSql = File(
        'supabase/migrations/20260728120000_add_workout_templates_v1.sql',
      ).readAsStringSync();
      exerciseCalcSql = File(
        'supabase/migrations/20260801180000_add_exercise_entry_calculation_columns.sql',
      ).readAsStringSync();
      baseSchemaSql = File(
        'supabase/migrations/20260722130000_create_v1_1_schema.sql',
      ).readAsStringSync();
    });

    test('workout_templates migration enables RLS and revokes anon', () {
      expect(workoutTemplatesSql, contains('enable row level security'));
      expect(
        workoutTemplatesSql,
        contains('revoke all on public.workout_templates from anon'),
      );
      expect(
        workoutTemplatesSql,
        contains('revoke all on public.workout_template_items from anon'),
      );
      expect(
        workoutTemplatesSql,
        contains('grant select, insert, update, delete'),
      );
      expect(workoutTemplatesSql, contains('auth.uid() = user_id'));
      expect(
        'create policy'.allMatches(workoutTemplatesSql).length,
        greaterThanOrEqualTo(2),
      );
    });

    test('workout_templates migration is idempotent', () {
      expect(workoutTemplatesSql, contains('create table if not exists'));
      expect(workoutTemplatesSql, contains('create index if not exists'));
      expect(workoutTemplatesSql, contains('drop policy if exists'));
    });

    test('exercise calculation columns migration is nullable-safe', () {
      expect(exerciseCalcSql, contains('add column if not exists'));
      expect(exerciseCalcSql, contains('gross_kcal'));
      expect(exerciseCalcSql, contains('net_kcal'));
      expect(exerciseCalcSql, contains('weight_kg_snapshot'));
      expect(exerciseCalcSql, contains('calculation_source'));
      expect(exerciseCalcSql, contains('create index if not exists'));
    });

    test('exercise_entries base schema already has RLS policies', () {
      expect(
        baseSchemaSql,
        contains(
          'alter table public.exercise_entries enable row level security',
        ),
      );
      expect(baseSchemaSql, contains('exercise_entries_select_own'));
      expect(baseSchemaSql, contains('exercise_entries_insert_own'));
      expect(baseSchemaSql, contains('exercise_entries_update_own'));
      expect(baseSchemaSql, contains('exercise_entries_delete_own'));
    });

    group('hardening migration', () {
      late String hardeningSql;

      setUpAll(() {
        hardeningSql = File(
          'supabase/migrations/20260801200000_tighten_public_grants_v1.sql',
        ).readAsStringSync();
      });

      test(
        'revokes anon on personal tables and grants minimal authenticated CRUD',
        () {
          expect(
            hardeningSql,
            contains('revoke all on table public.%I from anon'),
          );
          expect(
            hardeningSql,
            contains('grant select, insert on table public.users'),
          );
          expect(
            hardeningSql,
            contains('grant select on table public.saved_foods to anon'),
          );
          expect(
            hardeningSql,
            contains('grant select on table public.food_rating_stats to anon'),
          );
          expect(
            hardeningSql,
            contains('revoke all on table public.rate_limit_buckets'),
          );
        },
      );

      test(
        'revokes function EXECUTE from anon and grants publish_saved_food only',
        () {
          expect(hardeningSql, contains('revoke all on function %s from anon'));
          expect(
            hardeningSql,
            contains(
              'grant execute on function public.publish_saved_food(text)',
            ),
          );
          expect(
            hardeningSql,
            contains(
              'grant execute on function public.is_saved_food_publicly_visible',
            ),
          );
        },
      );

      test(
        'replaces is_saved_food_visible_to_viewer to avoid anon table access',
        () {
          expect(
            hardeningSql,
            contains(
              'create or replace function public.is_saved_food_visible_to_viewer',
            ),
          );
          expect(hardeningSql, contains('if auth.uid() is null then'));
          expect(
            hardeningSql,
            isNot(
              contains(
                'grant select on table public.blocked_food_creators to anon',
              ),
            ),
          );
        },
      );

      test('fixes default privileges for postgres and supabase_admin', () {
        expect(
          hardeningSql,
          contains(
            'alter default privileges for role postgres in schema public',
          ),
        );
        expect(
          hardeningSql,
          contains(
            'alter default privileges for role supabase_admin in schema public',
          ),
        );
      });
    });

    test('seed.sql contains no privilege or schema DDL', () {
      final seedSql = File(
        'supabase/seed.sql',
      ).readAsStringSync().toLowerCase();
      expect(seedSql, isNot(contains('grant ')));
      expect(seedSql, isNot(contains('revoke ')));
      expect(seedSql, isNot(contains('alter default privileges')));
      expect(seedSql, isNot(contains('create policy')));
      expect(seedSql, isNot(contains('create or replace function')));
    });
  });
}
