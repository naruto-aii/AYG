// 同期の往復で、記録の日時・中身・件数が1件も変わらないことを確かめる。
//
// 実機と同じ条件にするため:
// - 端末のタイムゾーンは Asia/Tokyo（CI も TZ=Asia/Tokyo で動かす）。
// - 本物の AppController / SupabaseDataSyncRepository / Isar / PendingRecordStore を使う。
// - サーバは本番 PostgREST の振る舞い（timestamptz は UTC セッション、
//   `+00:00` 付きで返す、本番に無い列は拒否）を再現した FakePostgrest。
// - ウィジェットと Siri の取り込みは、Swift が書く形の JSON を
//   本物のゲートウェイ（MethodChannel）経由で渡す。
//
// 3つの場面それぞれで 3 回以上往復する:
// 1. 端末内だけ（アプリの再起動で読み直す）
// 2. 送信→取得（同じ端末で強制同期を繰り返す）
// 3. 新規インストール（サーバに既にある行を、空の端末が取得する）。
//    本番で 2026-10-09 に戻した行と同じ形の行を含む。

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:ayg/models/activity_level.dart';
import 'package:ayg/models/alcohol_entry.dart';
import 'package:ayg/models/exercise_entry.dart';
import 'package:ayg/models/food_entry.dart';
import 'package:ayg/models/goal.dart';
import 'package:ayg/models/nutrition_settings.dart';
import 'package:ayg/models/user_profile.dart';
import 'package:ayg/repositories/authentication_repository.dart';
import 'package:ayg/repositories/data_sync_repository.dart';
import 'package:ayg/repositories/local_session_store.dart';
import 'package:ayg/repositories/pending_record_store.dart';
import 'package:ayg/repositories/supabase/exercise_entry_row_mapper.dart';
import 'package:ayg/repositories/supabase/food_master_row_mapper.dart';
import 'package:ayg/services/lock_screen_meal.dart';
import 'package:ayg/services/lock_screen_meal_gateway.dart';
import 'package:ayg/services/photo_meal.dart';
import 'package:ayg/services/photo_meal_client.dart';
import 'package:ayg/services/siri_voice_gateway.dart';
import 'package:ayg/services/siri_voice_log.dart';
import 'package:ayg/state/app_controller.dart';
import 'package:ayg/utils/local_date.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthUser;

import 'helpers/fake_postgrest.dart';
import 'helpers/isar_test_helper.dart';
import 'mocks/mock_authentication_repository.dart';
import 'mocks/mock_health_repository.dart';

const _uid = '0b8f0b3e-1111-4222-8333-444455556666';
const _rounds = 3;

final _oct8 = DateTime(2026, 10, 8);
final _oct9 = DateTime(2026, 10, 9);

/// 端末の壁時計（オフセット無し、ミリ秒まで）。
String _wall(DateTime value) {
  expect(value.isUtc, isFalse, reason: '端末の値は壁時計（ローカル）で持つ');
  return value.toIso8601String();
}

/// サーバの値（PostgREST の返す形）を、年月日時刻の文字列にする。
String _serverWall(String stored) {
  expect(stored.endsWith('+00:00'), isTrue, reason: stored);
  final body = stored.substring(0, stored.length - 6);
  return _wall(wallClockFromDb('${body}Z'));
}

/// 裏で走っている送信が終わるまで待つ（閉じる前に、実機と同じく最後まで送らせる）。
Future<void> _settle(FakePostgrest server) async {
  var last = -1;
  var stable = 0;
  while (stable < 5) {
    await pumpEventQueue();
    if (server.requests.length == last) {
      stable++;
    } else {
      stable = 0;
      last = server.requests.length;
    }
  }
}

class _Queues {
  String widget = '[]';
  String siri = '[]';

  void acknowledgeWidget(List<String> ids) {
    final rows = (jsonDecode(widget) as List)
        .where((row) => !ids.contains((row as Map)['registrationId']))
        .toList();
    widget = jsonEncode(rows);
  }

  void acknowledgeSiri(List<String> ids) {
    final rows = (jsonDecode(siri) as List)
        .where((row) => !ids.contains((row as Map)['id']))
        .toList();
    siri = jsonEncode(rows);
  }
}

class _Device {
  _Device._(this.harness, this.controller, this.client, this.server);

  final FakePostgrest server;
  final IsarTestHarness harness;
  final AppController controller;
  final SupabaseClient client;

  /// 新しく入れたアプリ（端末 DB と設定が空）。[keepData] なら同じ端末 DB のまま
  /// アプリだけ起動し直す。
  static Future<_Device> launch({
    required FakePostgrest server,
    required _Queues queues,
    IsarTestHarness? keepData,
    bool online = true,
  }) async {
    final harness = keepData ?? await IsarTestHarness.create();
    if (keepData == null) {
      SharedPreferences.setMockInitialValues({});
      await harness.userRepository.saveProfile(
        UserProfile(
          birthDate: DateTime(1990, 1, 1),
          gender: Gender.male,
          heightCm: 170,
          weightKg: 72,
        ),
      );
      await harness.userRepository.saveGoal(
        Goal(
          type: GoalType.maintain,
          targetWeightKg: 72,
          targetDate: DateTime(2026, 12, 31),
        ),
      );
      await harness.settingsRepository.saveNutritionSettings(
        const NutritionSettings(
          useHealthIntegration: false,
          activityLevel: ActivityLevel.moderate,
        ),
      );
    }
    final preferences = await SharedPreferences.getInstance();
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel(lockScreenMealMethodChannel),
      (call) async {
        switch (call.method) {
          case 'readPending':
            return queues.widget;
          case 'acknowledge':
            queues.acknowledgeWidget(
              List<String>.from((call.arguments as Map)['ids'] as List),
            );
            return null;
        }
        return null;
      },
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel(siriVoiceMethodChannel),
      (call) async {
        switch (call.method) {
          case 'readPending':
            return queues.siri;
          case 'acknowledge':
            queues.acknowledgeSiri(
              List<String>.from((call.arguments as Map)['ids'] as List),
            );
            return null;
        }
        return null;
      },
    );
    final client = SupabaseClient(
      'https://example.supabase.co',
      'test-anon-key',
      httpClient: server,
    );
    final pending = PendingRecordStore(preferences: preferences);
    final sync = SupabaseDataSyncRepository(
      userRepository: harness.userRepository,
      settingsRepository: harness.settingsRepository,
      foodRepository: harness.foodRepository,
      exerciseRepository: harness.exerciseRepository,
      alcoholRepository: harness.alcoholRepository,
      weightRepository: harness.weightRepository,
      client: client,
      pendingRecords: pending,
    );
    final controller = AppController(
      healthRepository: MockHealthRepository(isAvailable: false),
      authenticationRepository: MockAuthenticationRepository(
        currentUser: const AuthUser(id: _uid, email: 'owner@example.com'),
      ),
      dataSyncRepository: online ? sync : null,
      localSessionStore: LocalSessionStore(preferences: preferences),
      userRepository: harness.userRepository,
      settingsRepository: harness.settingsRepository,
      foodRepository: harness.foodRepository,
      exerciseRepository: harness.exerciseRepository,
      alcoholRepository: harness.alcoholRepository,
      weightRepository: harness.weightRepository,
      savedFoodRepository: harness.savedFoodRepository,
      lockScreenMealGateway: LockScreenMealGatewayImpl(preferences: preferences),
      siriVoiceGateway: SiriVoiceGatewayImpl(),
      pendingRecords: pending,
      termsAgreed: () async => true,
    );
    if (online) {
      await controller.handleAuthenticatedSession();
    } else {
      await controller.loadPersistedState();
      await controller.syncLockScreenMeals();
      await controller.syncSiriVoiceLogs();
    }
    await pumpEventQueue();
    expect(controller.lastSyncFailed, isFalse, reason: '${controller.syncFailure}');
    return _Device._(harness, controller, client, server);
  }

  /// 起動し直す（端末 DB は残す）。
  Future<_Device> relaunch(
    FakePostgrest server,
    _Queues queues, {
    bool online = true,
  }) async {
    await _settle(server);
    controller.dispose();
    await client.dispose();
    return launch(
      server: server,
      queues: queues,
      keepData: harness,
      online: online,
    );
  }

  /// 強制同期（未送信を送ってから全表を取り直す）。
  Future<void> syncNow() async {
    await controller.handleAuthenticatedSession(force: true);
    await pumpEventQueue();
    expect(controller.lastSyncFailed, isFalse, reason: '${controller.syncFailure}');
  }

  Future<void> uninstall() async {
    await _settle(server);
    controller.dispose();
    await client.dispose();
    await harness.dispose();
  }

  /// 端末にある記録を、日時は壁時計の文字列、中身はサーバへ送る形で並べる。
  Future<Map<String, Object?>> snapshot() async {
    final foods = await harness.foodRepository.loadAll();
    final exercises = await harness.exerciseRepository.loadAll();
    final alcohol = await harness.alcoholRepository.loadAll();
    final weights = await harness.weightRepository.loadAll();
    // 画面が持つ一覧も、端末 DB と同じであること。
    expect(
      controller.foodEntries.map((e) => '${e.id}@${_wall(e.loggedAt)}').toSet(),
      foods.map((e) => '${e.id}@${_wall(e.loggedAt)}').toSet(),
    );
    expect(
      controller.exerciseEntries
          .map((e) => '${e.id}@${_wall(e.loggedAt)}')
          .toSet(),
      exercises.map((e) => '${e.id}@${_wall(e.loggedAt)}').toSet(),
    );
    return {
      'food': {
        for (final e in foods)
          e.id: {
            ...FoodMasterRowMapper.foodEntryToRow(e, userId: _uid),
            'wall': _wall(e.loggedAt),
          },
      },
      'exercise': {
        for (final e in exercises)
          e.id: {
            ...ExerciseEntryRowMapper.toRow(e, userId: _uid),
            'wall': _wall(e.loggedAt),
          },
      },
      'alcohol': {
        for (final e in alcohol)
          e.id: {
            ...FoodMasterRowMapper.alcoholEntryToRow(e, userId: _uid),
            'wall': _wall(e.consumedAt),
          },
      },
      'weight': {
        for (final e in weights)
          e.id: {
            'weight_kg': e.weightKg,
            'source': e.source.storageValue,
            'wall': _wall(e.recordedAt),
          },
      },
    };
  }

  double intakeOn(DateTime day) {
    controller.refreshDailySummary(referenceDate: day);
    return controller.summary!.intakeKcal;
  }

  double burnOn(DateTime day) {
    controller.refreshDailySummary(referenceDate: day);
    return controller.summary!.exerciseBurnKcal;
  }
}

/// サーバの行（updated_at はサーバが付けるので外す）。
Map<String, Map<String, dynamic>> _serverRows(FakePostgrest server, String table) {
  return {
    for (final row in server.rows(table))
      row['entry_id'] as String: Map<String, dynamic>.from(row)
        ..remove('updated_at'),
  };
}

Map<String, String> _serverWalls(
  FakePostgrest server,
  String table,
  String column,
) {
  return {
    for (final row in server.rows(table))
      row['entry_id'] as String: _serverWall(row[column] as String),
  };
}

Map<String, String> _localWalls(Map<String, Object?> snapshot, String kind) {
  final rows = snapshot[kind]! as Map;
  return {
    for (final entry in rows.entries)
      entry.key as String: (entry.value as Map)['wall'] as String,
  };
}

/// 本番の社長の行と同じ形（2026-10-09 09:2x JST に戻した値の形）。
void _seedProductionShapedRows(FakePostgrest server) {
  server.rows('users').add({
    'id': _uid,
    'email': 'owner@example.com',
    'created_at': '2026-09-01T00:00:00+00:00',
  });
  Map<String, dynamic> food(
    String id,
    String loggedAt, {
    required String origin,
    double kcal = 98,
    double quantity = 1,
  }) => {
    'memo': null,
    'name': '若鶏ささみ（生）',
    'user_id': _uid,
    'entry_id': id,
    'quantity': quantity,
    'logged_at': loggedAt,
    'unit_type': 'g',
    'sort_order': 1,
    'updated_at': '2026-10-09T00:19:35.438016+00:00',
    'base_amount': 100,
    'source_type': 'manual',
    'fat_per_unit': 0.8,
    'carb_per_unit': 0.1,
    'kcal_per_unit': kcal,
    'meal_group_id': null,
    'record_origin': origin,
    'saved_food_id': null,
    'consumed_amount': 100 * quantity,
    'meal_group_name': null,
    'protein_per_unit': 23.9,
    'official_food_code': null,
    'official_food_name': null,
    'source_food_owner_user_id': null,
    'source_saved_food_version': null,
  };
  server.rows('food_entries').addAll([
    food('c4a16c8b-c7f5-45b6-b15d-13c840a48b79', '2026-10-08T01:15:00+00:00',
        origin: 'app', quantity: 1.5),
    food('1D518030-8F77-4C8C-AF76-FFA8953DBBA8',
        '2026-10-08T01:17:18.818+00:00', origin: 'widget', kcal: 500),
    food('4F37EF89-0000-4000-8000-000000000001',
        '2026-10-08T08:21:14.271+00:00', origin: 'siri', quantity: 3),
    food('68B4EE4B-AB55-49D9-844A-8B9FF677B6BD',
        '2026-10-08T13:21:35.338+00:00', origin: 'siri', quantity: 3),
    food('late-2330', '2026-10-08T23:30:00+00:00', origin: 'app', kcal: 200),
    food('last-2359', '2026-10-08T23:59:59.999+00:00', origin: 'app', kcal: 10),
    food('midnight-0000', '2026-10-09T00:00:00+00:00', origin: 'app', kcal: 20),
    food('early-0030', '2026-10-09T00:30:00+00:00', origin: 'widget', kcal: 300),
  ]);
  Map<String, dynamic> exercise(String id, String loggedAt, double kcal) => {
    'name': 'ウォーキング',
    'reps': null,
    'sets': null,
    'notes': null,
    'user_id': _uid,
    'entry_id': id,
    'net_kcal': kcal,
    'intensity': '17190',
    'logged_at': loggedAt,
    'met_value': null,
    'gross_kcal': kcal,
    'source_key': 'compendium_2024_17190',
    'updated_at': '2026-10-09T00:19:35.438016+00:00',
    'activity_id': 'walk_brisk',
    'burned_kcal': kcal,
    'distance_km': 5,
    'category_key': 'aerobic',
    'duration_min': 62,
    'record_origin': 'widget',
    'lift_weight_kg': null,
    'calculation_source': 'met_estimate',
    'weight_kg_snapshot': 72,
    'calculation_version': 'exercise_distance_v1',
  };
  server.rows('exercise_entries').addAll([
    exercise('ex-0113', '2026-10-08T01:13:00+00:00', 100),
    exercise('C97263C2-1DE3-4480-9B39-794C27E301BB',
        '2026-10-08T09:50:46.784+00:00', 180),
    exercise('ex-2330', '2026-10-08T23:30:00+00:00', 50),
    exercise('ex-0030', '2026-10-09T00:30:00+00:00', 70),
  ]);
  server.rows('alcohol_entries').add({
    'user_id': _uid,
    'entry_id': 'alc-2345',
    'beverage_name': 'ビール',
    'amount': 350,
    'unit': 'ml',
    'alcohol_percentage': 5,
    'total_calories': 140,
    'pure_alcohol_grams': 14,
    'alcohol_calories': 98,
    'consumed_at': '2026-10-08T23:45:00+00:00',
    'updated_at': '2026-10-09T00:19:35.438016+00:00',
  });
  server.rows('weight_entries').add({
    'user_id': _uid,
    'entry_id': 'w-0705',
    'weight_kg': 72,
    'recorded_at': '2026-10-08T07:05:00+00:00',
    'source': 'manual',
    'updated_at': '2026-10-09T00:19:35.438016+00:00',
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    // 実機（日本）と同じ条件で回すのが本来。UTC では +9 時間ずれる不具合が
    // 表に出ないので、そのときは目立つように知らせる（CI に TZ が無くても落とさない）。
    if (_oct8.timeZoneOffset != const Duration(hours: 9)) {
      // ignore: avoid_print
      print('注意: TZ=Asia/Tokyo ではないため、9時間ずれの検出力が落ちています');
    }
  });

  test('新規インストール: 本番と同じ形の行を取得し、再インストールと同期を繰り返しても変わらない', () async {
    final server = FakePostgrest();
    final queues = _Queues();
    _seedProductionShapedRows(server);
    final serverFoodBefore = _serverRows(server, 'food_entries');
    final serverExerciseBefore = _serverRows(server, 'exercise_entries');
    final serverAlcoholBefore = _serverRows(server, 'alcohol_entries');
    final serverWeightBefore = _serverRows(server, 'weight_entries');
    final expectedFoodWalls = _serverWalls(server, 'food_entries', 'logged_at');
    final expectedExerciseWalls =
        _serverWalls(server, 'exercise_entries', 'logged_at');

    // 本番の値の壁時計そのもの（例: Siri 13:21:35.338 JST）。
    expect(
      expectedFoodWalls['68B4EE4B-AB55-49D9-844A-8B9FF677B6BD'],
      '2026-10-08T13:21:35.338',
    );

    Map<String, Object?>? first;
    for (var install = 0; install < _rounds; install++) {
      var device = await _Device.launch(server: server, queues: queues);
      final snap = await device.snapshot();
      expect(_localWalls(snap, 'food'), expectedFoodWalls,
          reason: 'install $install');
      expect(_localWalls(snap, 'exercise'), expectedExerciseWalls,
          reason: 'install $install');
      expect(_localWalls(snap, 'alcohol'),
          {'alc-2345': '2026-10-08T23:45:00.000'});
      expect(_localWalls(snap, 'weight'), {'w-0705': '2026-10-08T07:05:00.000'});
      first ??= snap;
      expect(snap, first, reason: 'install $install: 中身が変わった');

      // 日ごとの集計: 10/8 は 23:59:59.999 まで、10/9 は 0:00 から。
      final oct8Foods = device.controller.foodEntries
          .where((e) => isLoggedOnLocalDay(e.loggedAt, _oct8))
          .map((e) => e.id)
          .toSet();
      expect(oct8Foods, hasLength(6));
      expect(oct8Foods.contains('last-2359'), isTrue);
      expect(oct8Foods.contains('midnight-0000'), isFalse);
      final oct9Foods = device.controller.foodEntries
          .where((e) => isLoggedOnLocalDay(e.loggedAt, _oct9))
          .map((e) => e.id)
          .toSet();
      expect(oct9Foods, {'midnight-0000', 'early-0030'});
      expect(device.intakeOn(_oct9), closeTo(20 + 300, 0.01));
      expect(device.burnOn(_oct9), greaterThan(0));

      for (var round = 0; round < _rounds; round++) {
        await device.syncNow();
        expect(await device.snapshot(), first,
            reason: 'install $install round $round');
        expect(_serverRows(server, 'food_entries'), serverFoodBefore,
            reason: 'install $install round $round');
        expect(_serverRows(server, 'exercise_entries'), serverExerciseBefore);
        expect(_serverRows(server, 'alcohol_entries'), serverAlcoholBefore);
        expect(_serverRows(server, 'weight_entries'), serverWeightBefore);
      }
      // アプリを閉じて開き直しても同じ。
      device = await device.relaunch(server, queues);
      expect(await device.snapshot(), first);
      await device.uninstall();
    }
  });

  test('送信→取得: 端末で付けた記録・ウィジェット・Siri・編集・削除が往復で変わらない', () async {
    final server = FakePostgrest();
    final queues = _Queues();
    server.rows('users').add({
      'id': _uid,
      'email': 'owner@example.com',
      'created_at': '2026-09-01T00:00:00+00:00',
    });
    var device = await _Device.launch(server: server, queues: queues);
    final c = device.controller;

    await c.addFood(
      FoodEntry(
        id: 'app-2330',
        name: '夜食のおにぎり',
        kcalPerBase: 180,
        loggedAt: DateTime(2026, 10, 8, 23, 30),
      ),
    );
    await c.addFood(
      FoodEntry(
        id: 'app-0030',
        name: 'ヨーグルト',
        kcalPerBase: 60,
        loggedAt: DateTime(2026, 10, 9, 0, 30, 15, 250),
      ),
    );
    await c.addFood(
      FoodEntry(
        id: 'app-to-delete',
        name: '消す食事',
        kcalPerBase: 999,
        loggedAt: DateTime(2026, 10, 8, 12),
      ),
    );
    await c.addExercise(
      ExerciseEntry(
        id: 'ex-app-2330',
        name: '散歩',
        durationMin: 20,
        burnedKcal: 60,
        loggedAt: DateTime(2026, 10, 8, 23, 30),
      ),
    );
    await c.addExercise(
      ExerciseEntry(
        id: 'ex-to-delete',
        name: '消す運動',
        durationMin: 10,
        burnedKcal: 30,
        loggedAt: DateTime(2026, 10, 9, 0, 30),
      ),
    );
    await c.addAlcohol(
      AlcoholEntry(
        id: 'alc-0030',
        beverageName: 'ハイボール',
        amount: 350,
        unit: 'ml',
        alcoholPercentage: 7,
        totalCalories: 180,
        pureAlcoholGrams: 19.6,
        alcoholCalories: 137,
        consumedAt: DateTime(2026, 10, 9, 0, 30),
      ),
    );
    await c.recordManualWeight(71.8, recordedAt: DateTime(2026, 10, 8, 23, 50));
    await pumpEventQueue();

    // ウィジェット（Swift の LockScreenMealStore.makePendingRecord と同じ形）。
    queues.widget = jsonEncode([
      {
        'registrationId': 'reg-meal',
        'ownerUserId': _uid,
        'slot': 0,
        'kind': 'meal',
        'templateId': 'widget-meal-0',
        'mealGroupId': 'GROUP-1',
        'mealGroupName': '朝ごはん',
        'loggedAt': '2026-10-08T23:30:12.345',
        'surface': 'lock',
        'items': [
          {
            'id': 'W-FOOD-1',
            'name': 'ささみ',
            'kcalPerBase': 500,
            'baseAmount': 100,
            'unitType': 'g',
            'consumedAmount': 100,
            'sortOrder': 1,
          },
        ],
      },
      {
        'registrationId': 'reg-ex',
        'ownerUserId': _uid,
        'slot': 1,
        'kind': 'exercise',
        'templateId': '',
        'mealGroupName': 'ウォーキング',
        'loggedAt': '2026-10-09T00:30:46.784',
        'surface': 'home',
        'exercises': [
          {
            'id': 'W-EX-1',
            'activityId': 'walk_brisk',
            'name': 'ウォーキング',
            'durationMin': 62,
            'distanceKm': 5,
            'sortOrder': 0,
          },
        ],
      },
    ]);
    // Siri（Swift の SiriVoiceLog.foodRecord / exerciseRecord と同じ形）。
    queues.siri = jsonEncode([
      {
        'kind': 'food',
        'id': 'SIRI-FOOD-1',
        'ownerUserId': _uid,
        'loggedAt': '2026-10-08T08:21:14.271',
        'name': '若鶏ささみ（生）',
        'baseAmount': 100,
        'unit': 'g',
        'consumedAmount': 300,
        'kcalPerBase': 98,
        'proteinPerBase': 23.9,
        'fatPerBase': 0.8,
        'carbPerBase': 0.1,
        'officialFoodCode': '11227',
      },
      {
        'kind': 'exercise',
        'id': 'SIRI-EX-1',
        'ownerUserId': _uid,
        'loggedAt': '2026-10-09T00:00:00.000',
        'activityId': 'walk_brisk',
        'amount': 30,
        'quantityUnit': 'minutes',
        'weightKg': 72,
      },
    ]);
    await c.syncLockScreenMeals();
    await c.syncSiriVoiceLogs();
    // 写真で登録（サーバの応答はモデル部分だけ差し替えた本物のハンドラの出力）。
    final photo = await PhotoMealClient(
      invoke: (_) async => jsonDecode(
        File('test/fixtures/analyze_meal_photo_ok.json').readAsStringSync(),
      ),
    ).analyze(jpeg: Uint8List.fromList([1, 2, 3]), dishName: '', amount: '');
    final photoEntry = await saveConfirmedPhotoMeal(
      controller: c,
      loggedAt: DateTime(2026, 10, 9, 0, 5, 30),
      name: photo.estimate.dishName,
      amountText: photo.estimate.amount,
      kcal: photo.estimate.kcal,
      proteinG: photo.estimate.proteinG,
      fatG: photo.estimate.fatG,
      carbG: photo.estimate.carbG,
    );
    await pumpEventQueue();
    expect(jsonDecode(queues.widget), isEmpty, reason: '取り込み済みは消える');
    expect(jsonDecode(queues.siri), isEmpty);

    // 編集（量や時間を変えても日時はそのまま）と削除。
    final onigiri = c.foodEntries.firstWhere((e) => e.id == 'app-2330');
    await c.updateFood(onigiri.copyWith(consumedAmount: 2));
    final walk = c.exerciseEntries.firstWhere((e) => e.id == 'ex-app-2330');
    await c.updateExercise(walk.copyWith(durationMin: 25, burnedKcal: 75));
    await c.deleteFood('app-to-delete');
    await c.deleteExercise('ex-to-delete');
    await pumpEventQueue();
    // 編集の送信（全件）が走っている最中に消しても、サーバに書き戻されない。
    expect(server.rows('food_entries').map((r) => r['entry_id']),
        isNot(contains('app-to-delete')));
    expect(server.rows('exercise_entries').map((r) => r['entry_id']),
        isNot(contains('ex-to-delete')));

    final expectedFood = {
      photoEntry.id: '2026-10-09T00:05:30.000',
      'app-2330': '2026-10-08T23:30:00.000',
      'app-0030': '2026-10-09T00:30:15.250',
      'W-FOOD-1': '2026-10-08T23:30:12.345',
      'SIRI-FOOD-1': '2026-10-08T08:21:14.271',
    };
    const expectedExercise = {
      'ex-app-2330': '2026-10-08T23:30:00.000',
      'W-EX-1': '2026-10-09T00:30:46.784',
      'SIRI-EX-1': '2026-10-09T00:00:00.000',
    };

    final local0 = await device.snapshot();
    expect(_localWalls(local0, 'food'), expectedFood);
    expect(_localWalls(local0, 'exercise'), expectedExercise);
    expect(_localWalls(local0, 'alcohol'),
        {'alc-0030': '2026-10-09T00:30:00.000'});
    expect(_localWalls(local0, 'weight').values.single,
        '2026-10-08T23:50:00.000');
    final foodRow = (local0['food']! as Map)['app-2330'] as Map;
    expect(foodRow['consumed_amount'], 2);
    final exRow = (local0['exercise']! as Map)['ex-app-2330'] as Map;
    expect(exRow['duration_min'], 25);
    expect((local0['food']! as Map)['W-FOOD-1']['record_origin'], 'widget');
    expect((local0['food']! as Map)['SIRI-FOOD-1']['record_origin'], 'siri');

    Map<String, Map<String, dynamic>>? serverFood;
    Map<String, Map<String, dynamic>>? serverExercise;
    for (var round = 0; round < _rounds; round++) {
      await device.syncNow();
      expect(await device.snapshot(), local0, reason: 'round $round');
      // サーバには端末と同じ年月日時刻が、UTC の印で入る（戻した本番の行と同じ形）。
      expect(_serverWalls(server, 'food_entries', 'logged_at'), expectedFood,
          reason: 'round $round');
      expect(_serverWalls(server, 'exercise_entries', 'logged_at'),
          expectedExercise,
          reason: 'round $round');
      expect(
        server.rows('food_entries').map((r) => r['logged_at']).toSet(),
        {
          '2026-10-08T23:30:00+00:00',
          '2026-10-09T00:30:15.25+00:00',
          '2026-10-08T23:30:12.345+00:00',
          '2026-10-08T08:21:14.271+00:00',
          '2026-10-09T00:05:30+00:00',
        },
      );
      expect(_serverWalls(server, 'alcohol_entries', 'consumed_at'),
          {'alc-0030': '2026-10-09T00:30:00.000'});
      expect(_serverWalls(server, 'weight_entries', 'recorded_at').values.single,
          '2026-10-08T23:50:00.000');
      serverFood ??= _serverRows(server, 'food_entries');
      serverExercise ??= _serverRows(server, 'exercise_entries');
      expect(_serverRows(server, 'food_entries'), serverFood);
      expect(_serverRows(server, 'exercise_entries'), serverExercise);
    }

    // 別の端末に入れ直す（新規インストール）を3回。
    await device.uninstall();
    for (var install = 0; install < _rounds; install++) {
      device = await _Device.launch(server: server, queues: queues);
      expect(await device.snapshot(), local0, reason: 'reinstall $install');
      expect(device.intakeOn(_oct9), closeTo(60 + 180 + 820, 0.01),
          reason: '10/9 はヨーグルト 60・ハイボール 180・写真の弁当 820');
      await device.syncNow();
      expect(_serverRows(server, 'food_entries'), serverFood);
      expect(_serverRows(server, 'exercise_entries'), serverExercise);
      await device.uninstall();
    }
  });

  test('送信が長引いている最中に消した記録は、サーバに書き戻されず再インストールで復活しない', () async {
    final server = FakePostgrest();
    final queues = _Queues();
    server.rows('users').add({
      'id': _uid,
      'email': 'owner@example.com',
      'created_at': '2026-09-01T00:00:00+00:00',
    });
    var device = await _Device.launch(server: server, queues: queues);
    final c = device.controller;
    await c.addFood(
      FoodEntry(
        id: 'keep',
        name: '残す食事',
        kcalPerBase: 300,
        loggedAt: DateTime(2026, 10, 8, 23, 30),
      ),
    );
    await c.addFood(
      FoodEntry(
        id: 'mistake',
        name: '間違えて付けた食事',
        kcalPerBase: 900,
        loggedAt: DateTime(2026, 10, 9, 0, 30),
      ),
    );
    await c.addExercise(
      ExerciseEntry(
        id: 'walk',
        name: '散歩',
        durationMin: 20,
        burnedKcal: 60,
        loggedAt: DateTime(2026, 10, 8, 23, 30),
      ),
    );
    await _settle(server);
    expect(server.rows('food_entries').map((r) => r['entry_id']).toSet(),
        {'keep', 'mistake'});

    // 運動を直す → 全件の送信が始まり、食事の送信が回線で止まっている。
    final release = Completer<void>();
    server
      ..holdPostsTo = 'food_entries'
      ..holdUntil = release.future;
    final walk = c.exerciseEntries.single;
    await c.updateExercise(walk.copyWith(durationMin: 30, burnedKcal: 90));
    while (server.heldPosts == 0) {
      await pumpEventQueue();
    }
    // その間に、間違えた食事を消す。
    var deleted = false;
    final deleting = c.deleteFood('mistake').then((_) => deleted = true);
    await pumpEventQueue();
    release.complete();
    server.holdUntil = null;
    await deleting;
    expect(deleted, isTrue);
    await _settle(server);

    expect(server.rows('food_entries').map((r) => r['entry_id']).toSet(),
        {'keep'}, reason: '消した記録がサーバに書き戻された');
    for (var round = 0; round < _rounds; round++) {
      await device.syncNow();
      expect(server.rows('food_entries').map((r) => r['entry_id']).toSet(),
          {'keep'});
    }
    await device.uninstall();
    device = await _Device.launch(server: server, queues: queues);
    expect(_localWalls(await device.snapshot(), 'food'),
        {'keep': '2026-10-08T23:30:00.000'});
    expect(device.controller.exerciseEntries.single.durationMin, 30);
    await device.uninstall();
  });

  test('端末内だけ: 再起動で読み直しても日時と件数が変わらない', () async {
    final server = FakePostgrest();
    final queues = _Queues();
    var device = await _Device.launch(
      server: server,
      queues: queues,
      online: false,
    );
    await device.controller.addFood(
      FoodEntry(
        id: 'local-2330',
        name: '夜食',
        kcalPerBase: 200,
        loggedAt: DateTime(2026, 10, 8, 23, 30),
      ),
    );
    await device.controller.addExercise(
      ExerciseEntry(
        id: 'local-ex-0030',
        name: '散歩',
        durationMin: 10,
        burnedKcal: 30,
        loggedAt: DateTime(2026, 10, 9, 0, 30),
      ),
    );
    queues.siri = jsonEncode([
      {
        'kind': 'food',
        'id': 'SIRI-LOCAL',
        'ownerUserId': _uid,
        'loggedAt': '2026-10-09T00:00:00.001',
        'name': 'バナナ',
        'baseAmount': 1,
        'unit': 'piece',
        'consumedAmount': 1,
        'kcalPerBase': 86,
      },
    ]);
    await device.controller.syncSiriVoiceLogs();
    final first = await device.snapshot();
    expect(_localWalls(first, 'food'), {
      'local-2330': '2026-10-08T23:30:00.000',
      'SIRI-LOCAL': '2026-10-09T00:00:00.001',
    });
    for (var round = 0; round < _rounds; round++) {
      device = await device.relaunch(server, queues, online: false);
      expect(await device.snapshot(), first, reason: 'restart $round');
    }
    expect(server.requests, isEmpty, reason: 'オフラインでは何も送らない');
    await device.uninstall();
  });

  test('送信に失敗した記録は、あとで送っても日時が変わらず二重にもならない', () async {
    final server = FakePostgrest();
    final queues = _Queues();
    server.rows('users').add({
      'id': _uid,
      'email': 'owner@example.com',
      'created_at': '2026-09-01T00:00:00+00:00',
    });
    var device = await _Device.launch(server: server, queues: queues);
    server.failWritesTo.add('food_entries');
    await device.controller.addFood(
      FoodEntry(
        id: 'offline-0030',
        name: '深夜のラーメン',
        kcalPerBase: 500,
        loggedAt: DateTime(2026, 10, 9, 0, 30),
      ),
    );
    await pumpEventQueue();
    expect(server.rows('food_entries'), isEmpty);
    // 通信が戻らないまま開き直しても、手元の記録は消えない。
    await device.controller.handleAuthenticatedSession(force: true);
    await pumpEventQueue();
    expect(
      (await device.harness.foodRepository.loadAll()).map((e) => e.id),
      ['offline-0030'],
    );
    server.failWritesTo.clear();
    for (var round = 0; round < _rounds; round++) {
      await device.syncNow();
      expect(server.rows('food_entries'), hasLength(1));
      expect(server.rows('food_entries').single['logged_at'],
          '2026-10-09T00:30:00+00:00');
      final local = await device.harness.foodRepository.loadAll();
      expect(local.map((e) => _wall(e.loggedAt)), ['2026-10-09T00:30:00.000']);
      // 送れたら「未送信」の印は消え、取得も再開する。
      expect(device.controller.hasUnsentRecords, isFalse, reason: 'round $round');
      expect(await PendingRecordStore(
        preferences: await SharedPreferences.getInstance(),
      ).count(), 0, reason: 'round $round');
    }
    // 開き直しても「未送信の記録があります」は出ず、食事の取得も止まっていない
    // （別の端末で付けた記録が届く）。
    server.rows('food_entries').add({
      ...server.rows('food_entries').single,
      'entry_id': 'other-device-2330',
      'name': '別の端末の夜食',
      'logged_at': '2026-10-08T23:30:00+00:00',
    });
    device = await device.relaunch(server, queues);
    expect(device.controller.hasUnsentRecords, isFalse);
    expect(_localWalls(await device.snapshot(), 'food'), {
      'offline-0030': '2026-10-09T00:30:00.000',
      'other-device-2330': '2026-10-08T23:30:00.000',
    });
    await device.uninstall();
    device = await _Device.launch(server: server, queues: queues);
    expect(_localWalls(await device.snapshot(), 'food'), {
      'offline-0030': '2026-10-09T00:30:00.000',
      'other-device-2330': '2026-10-08T23:30:00.000',
    });
    await device.uninstall();
  });
}
