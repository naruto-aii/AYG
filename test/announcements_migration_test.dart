import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final sql = File(
    'supabase/migrations/20261004130000_announcements.sql',
  ).readAsStringSync();
  final rollback = File(
    'supabase/rollback/20261004130000_announcements_down.sql',
  ).readAsStringSync();

  test('logged-in users can only read published announcements', () {
    expect(sql, contains('enable row level security'));
    expect(sql, contains('for select'));
    expect(sql, contains('to authenticated'));
    expect(sql, contains('published_at <= now()'));
    expect(sql, contains('title text not null'));
    expect(sql, contains('body text not null'));
    expect(sql, contains('published_at timestamptz not null'));
    expect(
      sql,
      contains(
        'revoke all on table public.announcements from public, anon, authenticated',
      ),
    );
    expect(
      sql,
      contains('grant select on table public.announcements to authenticated'),
    );
    expect(sql, isNot(contains('to anon')));
    expect(
      sql,
      isNot(
        contains(
          'grant insert, update, delete on table public.announcements to authenticated',
        ),
      ),
    );
    expect(sql, contains('to service_role'));
    expect(sql, contains('grant select, insert, update, delete'));
  });

  test('rollback drops only announcements', () {
    expect(rollback, contains('drop table if exists public.announcements'));
    expect(rollback, isNot(contains('official_foods')));
    expect(rollback, isNot(contains('food_entries')));
  });
}
