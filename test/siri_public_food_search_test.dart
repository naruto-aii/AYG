import 'dart:convert';
import 'dart:io';

import 'package:ayg/repositories/authentication_repository.dart';
import 'package:ayg/repositories/contracts/blocked_food_creator_repository_base.dart';
import 'package:ayg/services/siri_voice_log.dart';
import 'package:ayg/state/app_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import 'mocks/mock_authentication_repository.dart';

void main() {
  Map<String, dynamic> catalog({
    required bool official,
    List<String>? blocked,
  }) {
    final raw = SiriVoiceCodec.encodeCatalog(
      ownerUserId: 'user-1',
      weightKg: 60,
      officialFoodsEnabled: official,
      supabaseUrl: 'https://example.supabase.co',
      supabaseAnonKey: 'anon-key',
      blockedFoodCreatorIds: blocked,
      foods: const [],
    );
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  group('Siri catalog for public foods', () {
    test('never writes a login token to the App Group', () {
      final json = catalog(official: true, blocked: const []);
      expect(json.containsKey('supabaseAccessToken'), isFalse);
      expect(json['supabaseAnonKey'], 'anon-key');
    });

    test('writes the blocked creators, trimmed and without blanks', () {
      final json = catalog(
        official: true,
        blocked: const [' creator-a ', '', 'creator-b'],
      );
      expect(json['blockedFoodCreatorIds'], ['creator-a', 'creator-b']);
    });

    test('an empty block list is still written so Siri can search', () {
      final json = catalog(official: true, blocked: const []);
      expect(json['blockedFoodCreatorIds'], isEmpty);
      expect(json.containsKey('blockedFoodCreatorIds'), isTrue);
    });

    test('no list when it could not be read or online search is off', () {
      expect(
        catalog(official: true).containsKey('blockedFoodCreatorIds'),
        isFalse,
      );
      expect(
        catalog(
          official: false,
          blocked: const ['creator-a'],
        ).containsKey('blockedFoodCreatorIds'),
        isFalse,
      );
    });
  });

  group('AppController.siriBlockedFoodCreatorIds', () {
    late MockAuthenticationRepository auth;

    setUp(() {
      auth = MockAuthenticationRepository(
        currentUser: const AuthUser(id: 'user-1', email: 'a@example.com'),
      );
    });

    tearDown(() async {
      await auth.dispose();
    });

    test('returns the creators the user blocked', () async {
      final repo = _BlockedRepo(['creator-a', 'creator-b']);
      final controller = AppController(
        authenticationRepository: auth,
        blockedCreatorRepository: repo,
      );
      expect(await controller.siriBlockedFoodCreatorIds(), [
        'creator-a',
        'creator-b',
      ]);
      expect(repo.askedFor, ['user-1']);
    });

    test(
      'null when the list cannot be read (Siri skips public foods)',
      () async {
        final controller = AppController(
          authenticationRepository: auth,
          blockedCreatorRepository: _BlockedRepo(const [], fails: true),
        );
        expect(await controller.siriBlockedFoodCreatorIds(), isNull);
      },
    );

    test('null when signed out', () async {
      final signedOut = MockAuthenticationRepository();
      final controller = AppController(
        authenticationRepository: signedOut,
        blockedCreatorRepository: _BlockedRepo(const ['creator-a']),
      );
      expect(await controller.siriBlockedFoodCreatorIds(), isNull);
      await signedOut.dispose();
    });

    test('empty without a block repository', () async {
      final controller = AppController(authenticationRepository: auth);
      expect(await controller.siriBlockedFoodCreatorIds(), isEmpty);
    });
  });

  group('Siri source and the database function', () {
    test('Siri calls the anon search and filters blocked creators', () {
      final swift = File('ios/Runner/SiriVoiceLog.swift').readAsStringSync();
      expect(swift, contains('"search_public_foods_voice"'));
      expect(swift, isNot(contains('supabaseAccessToken')));
      expect(swift, isNot(contains('rpcURL("search_public_foods")')));
      expect(swift, contains('SiriPublicFoodFilter.removingBlocked'));
    });

    test('the function returns only public rows and needs no login', () {
      final sql = File(
        'supabase/migrations/20261008003832_search_public_foods_voice.sql',
      ).readAsStringSync();
      final code = sql
          .split('\n')
          .where((line) => !line.trimLeft().startsWith('--'))
          .join('\n')
          .split('comment on function')
          .first;
      expect(
        code,
        contains('create function public.search_public_foods_voice'),
      );
      expect(code, isNot(contains('auth.uid()')));
      expect(RegExp(r'from public\.saved_foods sf').allMatches(code).length, 3);
      expect(
        RegExp(
          r'is_saved_food_publicly_visible\(\s*sf\.visibility, sf\.status, sf\.deleted_at, sf\.moderation_status\s*\)',
        ).allMatches(code).length,
        3,
      );
      expect(code, contains('least(greatest(coalesce(p_limit, 50), 0), 100)'));
      expect(
        code,
        contains(
          'grant execute on function public.search_public_foods_voice(text, integer) to anon, authenticated;',
        ),
      );
      for (final column in [
        'barcode text',
        'copied_from_owner_user_id',
        'report_count',
        'moderation_status text',
      ]) {
        final returns = code.substring(
          code.indexOf('returns table('),
          code.indexOf(')\nlanguage'),
        );
        expect(returns, isNot(contains(column)));
      }
    });
  });
}

class _BlockedRepo implements BlockedFoodCreatorRepositoryBase {
  _BlockedRepo(this.ids, {this.fails = false});

  final List<String> ids;
  final bool fails;
  final askedFor = <String>[];

  @override
  Future<List<String>> getBlockedUserIds(String blockerUserId) async {
    askedFor.add(blockerUserId);
    if (fails) {
      throw StateError('offline');
    }
    return ids;
  }

  @override
  Future<void> block({
    required String blockerUserId,
    required String blockedUserId,
  }) async {}

  @override
  Future<void> unblock({
    required String blockerUserId,
    required String blockedUserId,
  }) async {}

  @override
  Future<bool> isBlocked({
    required String blockerUserId,
    required String blockedUserId,
  }) async => false;
}
