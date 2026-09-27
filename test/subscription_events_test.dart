import 'dart:async';

import 'package:ayg/models/meal_template.dart';
import 'package:ayg/repositories/authentication_repository.dart';
import 'package:ayg/repositories/contracts/meal_template_repository_base.dart';
import 'package:ayg/repositories/subscription_exceptions.dart';
import 'package:ayg/services/subscription_event_reporter.dart';
import 'package:ayg/state/app_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import 'mocks/mock_authentication_repository.dart';
import 'mocks/mock_subscription_repository.dart';

void main() {
  test('event rows are only user id and event type', () {
    expect(
      subscriptionEventInsert(
        userId: '  ',
        eventType: SubscriptionEventTypes.freeLimitHit,
      ),
      isNull,
    );
    expect(
      subscriptionEventInsert(userId: 'user-1', eventType: 'note'),
      isNull,
    );

    final row = subscriptionEventInsert(
      userId: ' user-1 ',
      eventType: SubscriptionEventTypes.convertedToPaid,
    );
    expect(row, {'user_id': 'user-1', 'event_type': 'converted_to_paid'});
    expect(row!.keys, ['user_id', 'event_type']);
  });

  test(
    'insert failures, including a duplicate first event, are ignored',
    () async {
      final rows = <Map<String, String>>[];
      final reporter = InsertingSubscriptionEventReporter(
        insert: (row) async {
          rows.add(Map<String, String>.from(row));
          if (rows.length > 1 &&
              row['event_type'] == SubscriptionEventTypes.freeLimitHit) {
            throw StateError('duplicate');
          }
        },
      );

      await reporter.recordFreeLimitHit('user-1');
      await reporter.recordFreeLimitHit('');
      await reporter.recordConvertedToPaid('user-1');
      await reporter.recordFreeLimitHit('user-1');

      expect(rows, [
        {'user_id': 'user-1', 'event_type': 'free_limit_hit'},
        {'user_id': 'user-1', 'event_type': 'converted_to_paid'},
        {'user_id': 'user-1', 'event_type': 'free_limit_hit'},
      ]);
    },
  );

  test(
    'hitting the free meal-template limit records the signed-in user',
    () async {
      final reporter = _RecordingReporter();
      final auth = MockAuthenticationRepository(
        currentUser: const AuthUser(id: 'user-1', email: 'a@example.com'),
      );
      final controller = AppController(
        authenticationRepository: auth,
        mealTemplateRepository: _FixedMealTemplates(3),
        subscriptionEventReporter: reporter,
      );

      await expectLater(
        controller.ensureCanCreateMealTemplate(),
        throwsA(isA<SubscriptionLimitExceededException>()),
      );
      await expectLater(
        controller.ensureCanCreateMealTemplate(),
        throwsA(isA<SubscriptionLimitExceededException>()),
      );
      expect(reporter.freeLimit, ['user-1', 'user-1']);

      await auth.dispose();
    },
  );

  test('a plus user does not record a free-limit hit', () async {
    final reporter = _RecordingReporter();
    final auth = MockAuthenticationRepository(
      currentUser: const AuthUser(id: 'user-1', email: 'a@example.com'),
    );
    final controller = AppController(
      authenticationRepository: auth,
      mealTemplateRepository: _FixedMealTemplates(3),
      subscriptionRepository: MockSubscriptionRepository()..plus = true,
      subscriptionEventReporter: reporter,
    );

    await controller.ensureCanCreateMealTemplate();
    expect(reporter.freeLimit, isEmpty);

    await auth.dispose();
  });

  test('the limit exception does not wait for the event write', () async {
    final release = Completer<void>();
    final reporter = _GatedReporter(release);
    final auth = MockAuthenticationRepository(
      currentUser: const AuthUser(id: 'user-1', email: 'a@example.com'),
    );
    final controller = AppController(
      authenticationRepository: auth,
      mealTemplateRepository: _FixedMealTemplates(3),
      subscriptionEventReporter: reporter,
    );

    final started = DateTime.now();
    await expectLater(
      controller.ensureCanCreateMealTemplate(),
      throwsA(isA<SubscriptionLimitExceededException>()),
    );
    expect(DateTime.now().difference(started).inMilliseconds, lessThan(500));
    expect(reporter.started, isTrue);

    release.complete();
    await Future<void>.delayed(const Duration(milliseconds: 20));

    await auth.dispose();
  });

  test('conversion is recorded once the signed-in user is known', () async {
    final reporter = _RecordingReporter();
    final auth = MockAuthenticationRepository();
    final controller = AppController(
      authenticationRepository: auth,
      subscriptionRepository: MockSubscriptionRepository()..plus = true,
      subscriptionEventReporter: reporter,
    );

    await controller.initialize();
    expect(reporter.converted, [null]);

    auth.setCurrentUser(const AuthUser(id: 'user-1', email: 'a@example.com'));
    await _waitUntil(() => reporter.converted.length == 2);
    expect(reporter.converted, [null, 'user-1']);

    await auth.dispose();
  });

  test('an already signed-in plus user is recorded on startup', () async {
    final reporter = _RecordingReporter();
    final auth = MockAuthenticationRepository(
      currentUser: const AuthUser(id: 'user-9', email: 'a@example.com'),
    );
    final controller = AppController(
      authenticationRepository: auth,
      subscriptionRepository: MockSubscriptionRepository()..plus = true,
      subscriptionEventReporter: reporter,
    );

    await controller.initialize();
    expect(reporter.converted, ['user-9']);

    await auth.dispose();
  });
}

class _GatedReporter extends SubscriptionEventReporter {
  _GatedReporter(this.release);

  final Completer<void> release;
  bool started = false;

  @override
  Future<void> recordFreeLimitHit(String? userId) {
    started = true;
    return release.future;
  }

  @override
  Future<void> recordConvertedToPaid(String? userId) async {}
}

class _RecordingReporter extends SubscriptionEventReporter {
  final freeLimit = <String?>[];
  final converted = <String?>[];

  @override
  Future<void> recordFreeLimitHit(String? userId) async {
    freeLimit.add(userId);
  }

  @override
  Future<void> recordConvertedToPaid(String? userId) async {
    converted.add(userId);
  }
}

class _FixedMealTemplates implements MealTemplateRepositoryBase {
  _FixedMealTemplates(int count)
    : _templates = List.generate(count, (index) {
        final created = DateTime.utc(2026, 9, 1, index);
        return MealTemplate(
          templateId: 'template-$index',
          ownerUserId: 'user-1',
          name: 'template $index',
          normalizedName: 'template $index',
          totalKcal: 100,
          totalProteinG: 10,
          totalFatG: 5,
          totalCarbG: 8,
          createdAt: created,
          updatedAt: created,
        );
      });

  final List<MealTemplate> _templates;

  @override
  Future<void> clearAll() async {}

  @override
  Future<void> clearForOwner(String ownerUserId) async {}

  @override
  Future<List<MealTemplate>> getAll(String ownerUserId) async => _templates;

  @override
  Future<MealTemplate?> getById({
    required String ownerUserId,
    required String templateId,
  }) async => null;

  @override
  Future<List<MealTemplateItem>> getItems({
    required String ownerUserId,
    required String templateId,
  }) async => const [];

  @override
  Future<List<MealTemplate>> loadAllOwnIncludingDeleted(
    String ownerUserId,
  ) async => _templates;

  @override
  Future<void> reassignOwnerUserId({
    required String fromOwnerUserId,
    required String toOwnerUserId,
  }) async {}

  @override
  Future<void> replaceItems({
    required String ownerUserId,
    required String templateId,
    required List<MealTemplateItem> items,
  }) async {}

  @override
  Future<void> save(MealTemplate template) async {}

  @override
  Future<void> saveAll(List<MealTemplate> templates) async {}

  @override
  Future<void> saveWithItems({
    required MealTemplate template,
    required List<MealTemplateItem> items,
  }) async {}

  @override
  Future<List<MealTemplate>> search({
    required String ownerUserId,
    required String query,
  }) async => _templates;

  @override
  Future<void> softDelete({
    required String ownerUserId,
    required String templateId,
    required DateTime deletedAt,
  }) async {}

  @override
  Future<void> update(MealTemplate template) async {}
}

Future<void> _waitUntil(bool Function() ready) async {
  for (var attempt = 0; attempt < 20; attempt++) {
    if (ready()) {
      return;
    }
    await Future<void>.delayed(Duration.zero);
  }
  fail('timed out waiting for subscription event');
}
