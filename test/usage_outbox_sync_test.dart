import 'package:ayg/config/subscription_catalog.dart';
import 'package:ayg/repositories/coach_proposal_log.dart';
import 'package:ayg/repositories/persistent_event_outbox.dart';
import 'package:ayg/repositories/plus_funnel_repository.dart';
import 'package:ayg/repositories/usage_record_repository.dart';
import 'package:ayg/services/subscription_entitlement.dart';
import 'package:ayg/services/usage_record.dart';
import 'package:ayg/state/app_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('search, screen, coach, and funnel survive offline then send', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final sent = <Map<String, dynamic>>[];
    var online = false;
    final user = '11111111-1111-4111-8111-111111111111';

    Future<void> insert(String table, Map<String, dynamic> row) async {
      if (!online) {
        throw const PostgrestException(message: 'offline', code: '08006');
      }
      sent.add({'table': table, ...row});
    }

    final usage = SupabaseUsageRecordRepository(
      preferences: preferences,
      settle: const Duration(days: 1),
      currentUserId: () => user,
      insertRow: insert,
      upsertRow: (table, row) async {
        if (!online) {
          throw const PostgrestException(
            message:
                "Could not find the 'memo' column of 'calonavi_plus_entitlements' in the schema cache",
            code: 'PGRST204',
          );
        }
        sent.add({'table': table, ...row});
      },
    );
    final coach = SupabaseCoachProposalLog(
      preferences: preferences,
      currentUserId: () => user,
      insertRow: (row) => insert('coach_proposal_logs', row),
      updateRow: (id, owner) async {
        if (!online) {
          throw Exception('offline');
        }
        sent.add({
          'table': 'coach_proposal_logs',
          'id': id,
          'user_id': owner,
          'registered': true,
        });
      },
    );
    String? funnelUser;
    final funnel = SupabasePlusFunnelRepository(
      preferences: preferences,
      currentUserId: () => funnelUser,
      insertRow: (row) => insert('plus_funnel_events', row),
      newId: () => 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
      clock: () => DateTime.utc(2026, 10, 7, 3),
    );

    await usage.recordFoodSearch(
      source: FoodSearchSources.savedFood,
      query: 'ご飯',
      eventId: 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
    );
    await usage.recordScreenAction(
      screen: UsageScreen.home,
      action: UsageScreenAction.shareMeal,
      eventId: 'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
    );
    await coach.recordShown([
      CoachProposalRecord(
        id: 'dddddddd-dddd-4ddd-8ddd-dddddddddddd',
        proposal: 'ごはんと魚',
        recordedAt: DateTime.utc(2026, 10, 7, 4),
      ),
    ]);
    await funnel.record(
      event: PlusFunnelEvent.planSelect,
      productId: SubscriptionCatalog.yearlyProductId,
    );
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(sent, isEmpty);

    online = true;
    funnelUser = user;
    await usage.flushPending();
    await coach.flushPending();
    await funnel.flushPending();

    Map<String, dynamic> row(String table) {
      return sent.singleWhere((item) => item['table'] == table);
    }

    final search = row('food_search_queries');
    expect(search['user_id'], user);
    expect(search['source'], 'saved_food');
    expect(search['query_text'], 'ご飯');
    expect(search['advertising_use'], isFalse);
    expect(search['id'], 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb');

    final screen = row('app_screen_actions');
    expect(screen['screen'], 'home');
    expect(screen['action'], 'share_meal');
    expect(screen['advertising_use'], isFalse);

    final proposal = row('coach_proposal_logs');
    expect(proposal['proposal'], 'ごはんと魚');
    expect(proposal['registered'], isFalse);
    expect(proposal['user_id'], user);

    final plan = row('plus_funnel_events');
    expect(plan['event'], 'plan_select');
    expect(plan['product_id'], 'yearly');
    expect(plan['user_id'], user);
    expect(plan['advertising_use'], isFalse);

    await usage.flushPending();
    await coach.flushPending();
    await funnel.flushPending();
    expect(sent, hasLength(4));
  });

  test('another user and a 4xx row stay queued', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final other = '22222222-2222-4222-8222-222222222222';
    final user = '11111111-1111-4111-8111-111111111111';
    String? signedIn = other;
    var reject = true;
    var sends = 0;
    final usage = SupabaseUsageRecordRepository(
      preferences: preferences,
      settle: const Duration(days: 1),
      currentUserId: () => signedIn,
      insertRow: (table, row) async {
        sends += 1;
        if (reject) {
          throw const PostgrestException(message: 'no', code: '42501');
        }
      },
    );
    await usage.recordScreenAction(
      screen: UsageScreen.home,
      action: UsageScreenAction.open,
      eventId: 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee',
    );
    expect(sends, 1);
    signedIn = user;
    await usage.flushPending();
    expect(sends, 1);
    final held = preferences.getString(usageEventOutboxKey);
    expect(held, contains(other));
    expect(held, contains('eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee'));
    signedIn = other;
    await usage.flushPending();
    expect(sends, 2);
    expect(preferences.getString(usageEventOutboxKey), contains(other));
    reject = false;
    await usage.flushPending();
    expect(preferences.getString(usageEventOutboxKey), isNull);
    await usage.flushPending();
    expect(sends, 3);
  });

  test('resume asks every behavior queue to flush', () async {
    final usage = _CountingUsage();
    final coach = _CountingCoach();
    final funnel = _CountingFunnel();
    final controller = AppController(
      usageRecordRepository: usage,
      coachProposalLog: coach,
      plusFunnelRepository: funnel,
    );
    addTearDown(controller.dispose);
    await controller.flushUnsentRecords();
    expect(usage.flushes, 1);
    expect(coach.flushes, 1);
    expect(funnel.flushes, 1);
  });

  test('unknown column is stripped and the row is saved', () async {
    var calls = 0;
    final saved = await deliverPersistentRow(
      table: 'plus_funnel_events',
      payload: {
        'id': 'ffffffff-ffff-4fff-8fff-ffffffffffff',
        'user_id': '11111111-1111-4111-8111-111111111111',
        'event': 'paywall_open',
        'occurred_at': '2026-10-07T00:00:00.000Z',
        'memo': 'drop me',
      },
      requiredColumns: const {'id', 'user_id', 'event', 'occurred_at'},
      send: (row) async {
        calls += 1;
        if (row.containsKey('memo')) {
          throw const PostgrestException(
            message: "Could not find the 'memo' column of 'plus_funnel_events'",
            code: 'PGRST204',
          );
        }
      },
    );
    expect(saved, isTrue);
    expect(calls, 2);
  });

  test('duplicate insert is success', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final coach = SupabaseCoachProposalLog(
      preferences: preferences,
      currentUserId: () => '11111111-1111-4111-8111-111111111111',
      insertRow: (row) async {
        throw const PostgrestException(message: 'dup', code: '23505');
      },
    );
    await coach.recordShown([
      CoachProposalRecord(
        id: 'abababab-abab-4bab-8bab-abababababab',
        proposal: 'サラダ',
        recordedAt: DateTime.utc(2026, 10, 7),
      ),
    ]);
    expect(preferences.getString('coach_proposal_outbox'), isNull);
  });

  test('entitlement payload is ready for the table', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    Map<String, dynamic>? saved;
    final usage = SupabaseUsageRecordRepository(
      preferences: preferences,
      currentUserId: () => '11111111-1111-4111-8111-111111111111',
      upsertRow: (table, row) async {
        saved = {'table': table, ...row};
      },
    );
    await usage.syncPlusEntitlements(
      confirmed: [
        SubscriptionEntitlementRecord(
          productId: SubscriptionCatalog.monthlyProductId,
          expiresAt: DateTime.utc(2027, 1, 1),
        ),
      ],
      inactive: const [],
      authoritative: false,
    );
    expect(saved?['table'], 'calonavi_plus_entitlements');
    expect(saved?['product_id'], SubscriptionCatalog.monthlyProductId);
    expect(saved?['status'], 'active');
    expect(saved?['advertising_use'], isFalse);
    expect(saved?.containsKey('memo'), isFalse);
  });
}

class _CountingUsage implements UsageRecordRepository {
  var flushes = 0;

  @override
  Future<void> flushPending() async {
    flushes += 1;
  }

  @override
  Future<void> recordExerciseSearch({
    required String source,
    required String query,
    String? eventId,
    void Function(String query, String eventId)? onSettled,
  }) async {}

  @override
  Future<void> recordFoodSearch({
    required String source,
    required String query,
    String? eventId,
    void Function(String query, String eventId)? onSettled,
  }) async {}

  @override
  Future<void> recordScreenAction({
    required String screen,
    required String action,
    String? eventId,
  }) async {}

  @override
  Future<void> syncPlusEntitlements({
    required List<SubscriptionEntitlementRecord> confirmed,
    required List<SubscriptionEntitlementRecord> inactive,
    required bool authoritative,
    DateTime? now,
  }) async {}
}

class _CountingCoach implements CoachProposalLog {
  var flushes = 0;

  @override
  Future<void> flushPending() async {
    flushes += 1;
  }

  @override
  Future<void> markRegistered({required String id}) async {}

  @override
  Future<void> recordShown(List<CoachProposalRecord> records) async {}
}

class _CountingFunnel implements PlusFunnelRepository {
  var flushes = 0;

  @override
  Future<void> flushPending() async {
    flushes += 1;
  }

  @override
  Future<void> record({
    required PlusFunnelEvent event,
    PlusFunnelFeature? feature,
    String? productId,
  }) async {}
}
