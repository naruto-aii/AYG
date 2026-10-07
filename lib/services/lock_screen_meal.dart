import 'dart:convert';

import '../data/met_activity_catalog.dart';
import '../models/exercise_entry.dart';
import '../models/exercise_quantity_unit.dart';
import '../models/food_entry.dart';
import '../models/food_entry_source.dart';
import '../models/food_unit_type.dart';
import '../models/meal_template.dart';
import 'exercise_calorie_calculator.dart';

/// ホームとロック画面のウィジェットが共有する JSON（version 3）。
///
/// ウィジェット拡張は Isar を開けない。ボタンを押した瞬間に App Group へ
/// 今日の食事か運動を1件追記し、アプリは次回の起動・復帰でそれを取り込む。
/// `loggedAt` は押した時刻の壁時計（オフセット無し）で、取り込み時刻ではない。
///
/// ボタンの中身はウィジェット専用のパターンです。食事テンプレートの4件や
/// 運動テンプレートの一覧とは別で、テンプレート id では引きません。
const int lockScreenMealSchemaVersion = 3;

const String lockScreenMealMethodChannel = 'com.narutoaii.ayg/lock_screen_meal';

/// ウィジェットと Siri が読む有料フラグ。既定は false。
///
/// 設定のスイッチからは変えない。カロナビ+ の加入が有効なときだけ true になり、
/// 期限切れか返金で false に戻る。Health の数値はここには入れない。
abstract final class LockScreenMealPaidFlag {
  static const String storageKey = 'lock_screen_meal_paid';

  static bool readValue(bool? stored) => stored ?? false;
}

/// ウィジェットのボタンが食事か運動か。食事テンプレートの行ではない。
enum WidgetPatternKind { meal, exercise }

class WidgetExercisePattern {
  const WidgetExercisePattern({
    required this.itemId,
    required this.activityId,
    required this.name,
    required this.sortOrder,
    this.durationMin = 0,
    this.distanceKm,
    this.netKcal,
  });

  final String itemId;
  final String activityId;
  final String name;
  final int durationMin;
  final double? distanceKm;

  /// 今の体重で出した消費。ウィジェットが押した直後に残りカロリーへ足す。
  final double? netKcal;
  final int sortOrder;

  bool get canRegister {
    if (activityId.trim().isEmpty) {
      return false;
    }
    final distance = distanceKm;
    if (distance != null && distance > 0) {
      return true;
    }
    return durationMin > 0;
  }

  WidgetExercisePattern copyWith({String? itemId, double? netKcal}) {
    return WidgetExercisePattern(
      itemId: itemId ?? this.itemId,
      activityId: activityId,
      name: name,
      sortOrder: sortOrder,
      durationMin: durationMin,
      distanceKm: distanceKm,
      netKcal: netKcal ?? this.netKcal,
    );
  }
}

/// ボタンを押した分だけ、ウィジェットの整数表示を動かす。
///
/// 摂取と消費は足す。残りは「残り − 摂取増 + 消費増」で、0 未満になった分は超過にする
/// （超過の日は「−超過」から計算する）。目標はそのまま引き継ぐ。
/// Swift の `LockScreenMealStore.applyFigures` と同じ。
MealWidgetFigures applyMealWidgetFigures({
  required MealWidgetFigures figures,
  required double intakeDelta,
  required double burnDelta,
}) {
  final intakeAdd = intakeDelta.round();
  final burnAdd = burnDelta.round();
  final remaining = figures.remainingKcal;
  final overage = figures.overageKcal;
  int? nextRemaining;
  int? nextOverage = overage;
  if (remaining != null) {
    final balance = overage != null && overage > 0 ? -overage : remaining;
    final next = balance - intakeAdd + burnAdd;
    nextRemaining = next < 0 ? 0 : next;
    nextOverage = next < 0 ? -next : null;
  }
  return MealWidgetFigures(
    remainingKcal: nextRemaining,
    intakeKcal: (figures.intakeKcal ?? 0) + intakeAdd,
    burnKcal: (figures.burnKcal ?? 0) + burnAdd,
    targetKcal: figures.targetKcal,
    overageKcal: nextOverage,
  );
}

double mealItemKcal({
  required double? kcalPerBase,
  required double baseAmount,
  required double consumedAmount,
}) {
  if (kcalPerBase == null || baseAmount <= 0 || consumedAmount <= 0) {
    return 0;
  }
  return kcalPerBase * consumedAmount / baseAmount;
}

class LockScreenMealButtonConfig {
  const LockScreenMealButtonConfig({
    required this.slot,
    required this.label,
    this.kind = WidgetPatternKind.meal,
    this.contentName,
    this.items = const [],
    this.exercises = const [],
  });

  final int slot;
  final String label;
  final WidgetPatternKind kind;

  /// 食事のまとまり名。ボタンの短い文字とは別に、登録時の食事名に使う。
  final String? contentName;
  final List<MealTemplateItem> items;
  final List<WidgetExercisePattern> exercises;

  bool get hasContent => kind == WidgetPatternKind.exercise
      ? exercises.any((item) => item.canRegister)
      : items.isNotEmpty;

  LockScreenMealButtonConfig copyWith({
    String? label,
    WidgetPatternKind? kind,
    String? contentName,
    bool clearContentName = false,
    List<MealTemplateItem>? items,
    List<WidgetExercisePattern>? exercises,
  }) {
    return LockScreenMealButtonConfig(
      slot: slot,
      label: label ?? this.label,
      kind: kind ?? this.kind,
      contentName: clearContentName ? null : (contentName ?? this.contentName),
      items: items ?? this.items,
      exercises: exercises ?? this.exercises,
    );
  }
}

class LockScreenMealConfig {
  const LockScreenMealConfig({
    required this.homeButtons,
    required this.lockButtons,
  });

  static const int homeSlotCount = 5;
  static const int lockSlotCount = 3;

  static const List<String> homeDefaultLabels = [
    '朝ごはん',
    '昼ごはん',
    '夜ごはん',
    'ウォーキング',
    'ジョギング',
  ];

  static const List<WidgetPatternKind> homeDefaultKinds = [
    WidgetPatternKind.meal,
    WidgetPatternKind.meal,
    WidgetPatternKind.meal,
    WidgetPatternKind.exercise,
    WidgetPatternKind.exercise,
  ];

  static const List<String> lockDefaultLabels = ['朝', '昼', '夜'];

  final List<LockScreenMealButtonConfig> homeButtons;
  final List<LockScreenMealButtonConfig> lockButtons;

  factory LockScreenMealConfig.defaults() {
    return LockScreenMealConfig(
      homeButtons: [
        for (var slot = 0; slot < homeSlotCount; slot++)
          LockScreenMealButtonConfig(
            slot: slot,
            label: homeDefaultLabels[slot],
            kind: homeDefaultKinds[slot],
          ),
      ],
      lockButtons: [
        for (var slot = 0; slot < lockSlotCount; slot++)
          LockScreenMealButtonConfig(
            slot: slot,
            label: lockDefaultLabels[slot],
          ),
      ],
    );
  }

  LockScreenMealButtonConfig homeAt(int slot) =>
      _at(homeButtons, slot, homeDefaultLabels);

  LockScreenMealButtonConfig lockAt(int slot) =>
      _at(lockButtons, slot, lockDefaultLabels);

  /// ホームの5枠のうち、食事と運動がそれぞれ何枠か。
  ({int meal, int exercise}) get homeSlotCounts {
    var meal = 0;
    var exercise = 0;
    for (final button in homeButtons) {
      switch (button.kind) {
        case WidgetPatternKind.meal:
          meal += 1;
        case WidgetPatternKind.exercise:
          exercise += 1;
      }
    }
    return (meal: meal, exercise: exercise);
  }

  static LockScreenMealButtonConfig _at(
    List<LockScreenMealButtonConfig> buttons,
    int slot,
    List<String> fallbackLabels,
  ) {
    for (final button in buttons) {
      if (button.slot == slot) {
        return button;
      }
    }
    final label = slot >= 0 && slot < fallbackLabels.length
        ? fallbackLabels[slot]
        : '';
    final kind = fallbackLabels.length == homeSlotCount && slot >= lockSlotCount
        ? WidgetPatternKind.exercise
        : WidgetPatternKind.meal;
    return LockScreenMealButtonConfig(slot: slot, label: label, kind: kind);
  }
}

/// ウィジェットに出す、今日の残り・摂取・消費。
///
/// 目標と超過は、ウィジェットのカロリーリングをアプリのホームと同じ見た目にするために渡す。
/// 超過していない日は [overageKcal] を null にする。
class MealWidgetFigures {
  const MealWidgetFigures({
    this.remainingKcal,
    this.intakeKcal,
    this.burnKcal,
    this.targetKcal,
    this.overageKcal,
  });

  final int? remainingKcal;
  final int? intakeKcal;
  final int? burnKcal;
  final int? targetKcal;
  final int? overageKcal;
}

class LockScreenMealButtonSnapshot {
  const LockScreenMealButtonSnapshot({
    required this.slot,
    required this.label,
    this.kind = WidgetPatternKind.meal,
    this.templateId,
    this.templateName,
    this.items = const [],
    this.exercises = const [],
  });

  final int slot;
  final String label;
  final WidgetPatternKind kind;

  /// ウィジェット内のパターン id。食事テンプレートの id ではない。
  final String? templateId;
  final String? templateName;
  final List<MealTemplateItem> items;
  final List<WidgetExercisePattern> exercises;

  bool get canRegister => kind == WidgetPatternKind.exercise
      ? exercises.any((item) => item.canRegister)
      : items.isNotEmpty;
}

class LockScreenMealSnapshot {
  const LockScreenMealSnapshot({
    required this.ownerUserId,
    required this.homeButtons,
    required this.lockButtons,
    this.figures = const MealWidgetFigures(),
  });

  final String ownerUserId;
  final List<LockScreenMealButtonSnapshot> homeButtons;
  final List<LockScreenMealButtonSnapshot> lockButtons;
  final MealWidgetFigures figures;
}

enum LockScreenMealRegisterStatus { registered, unpaid, unassigned }

class LockScreenMealRegisterResult {
  const LockScreenMealRegisterResult({required this.status, this.meal});

  final LockScreenMealRegisterStatus status;
  final PendingLockScreenMeal? meal;
}

class PendingLockScreenMeal {
  const PendingLockScreenMeal({
    required this.registrationId,
    required this.ownerUserId,
    required this.slot,
    required this.templateId,
    required this.mealGroupId,
    required this.mealGroupName,
    required this.loggedAt,
    required this.entries,
    this.surface,
    this.kind = WidgetPatternKind.meal,
    this.exercises = const [],
  });

  final String registrationId;
  final String ownerUserId;
  final int slot;
  final String templateId;
  final String mealGroupId;
  final String mealGroupName;
  final DateTime loggedAt;
  final List<FoodEntry> entries;

  /// `home` または `lock`。ウィジェットが書いたときだけある。
  final String? surface;
  final WidgetPatternKind kind;
  final List<WidgetExercisePattern> exercises;
}

class LockScreenMealImportPlan {
  const LockScreenMealImportPlan({
    required this.entries,
    required this.acknowledgeIds,
    required this.templateIds,
    this.exerciseRecords = const [],
  });

  final List<FoodEntry> entries;
  final List<String> acknowledgeIds;
  final List<String> templateIds;
  final List<PendingLockScreenMeal> exerciseRecords;
}

/// ボタン押下の判定。Swift の `LockScreenMealStore.register` と同じ条件。
abstract final class LockScreenMealRegistrar {
  static LockScreenMealRegisterResult register({
    required bool paid,
    required LockScreenMealButtonSnapshot button,
    required String ownerUserId,
    required DateTime loggedAt,
    required String Function() newId,
  }) {
    if (!paid) {
      return const LockScreenMealRegisterResult(
        status: LockScreenMealRegisterStatus.unpaid,
      );
    }
    if (ownerUserId.trim().isEmpty) {
      return const LockScreenMealRegisterResult(
        status: LockScreenMealRegisterStatus.unassigned,
      );
    }
    if (button.kind == WidgetPatternKind.exercise) {
      return _registerExercise(
        button: button,
        ownerUserId: ownerUserId,
        loggedAt: loggedAt,
        newId: newId,
      );
    }
    if (button.items.isEmpty) {
      return const LockScreenMealRegisterResult(
        status: LockScreenMealRegisterStatus.unassigned,
      );
    }
    final templateId = _patternId(button);

    final mealGroupId = newId();
    final entries = <FoodEntry>[];
    for (final item in button.items) {
      if (item.baseAmount <= 0 ||
          item.consumedAmount <= 0 ||
          item.name.trim().isEmpty) {
        continue;
      }
      entries.add(
        FoodEntry(
          id: newId(),
          name: item.name,
          kcalPerBase: item.kcalPerBase,
          proteinPerBase: item.proteinPerBase,
          fatPerBase: item.fatPerBase,
          carbPerBase: item.carbPerBase,
          baseAmount: item.baseAmount,
          unitType: item.unitType,
          consumedAmount: item.consumedAmount,
          sourceType: item.savedFoodId == null
              ? FoodEntrySource.manual
              : FoodEntrySource.savedFood,
          savedFoodId: item.savedFoodId,
          sourceFoodOwnerUserId: item.sourceOwnerUserId,
          mealGroupId: mealGroupId,
          mealGroupName: button.templateName ?? button.label,
          sortOrder: item.sortOrder,
          loggedAt: loggedAt,
        ),
      );
    }
    if (entries.isEmpty) {
      return const LockScreenMealRegisterResult(
        status: LockScreenMealRegisterStatus.unassigned,
      );
    }

    return LockScreenMealRegisterResult(
      status: LockScreenMealRegisterStatus.registered,
      meal: PendingLockScreenMeal(
        registrationId: newId(),
        ownerUserId: ownerUserId,
        slot: button.slot,
        templateId: templateId,
        mealGroupId: mealGroupId,
        mealGroupName: button.templateName ?? button.label,
        loggedAt: loggedAt,
        entries: entries,
        kind: WidgetPatternKind.meal,
      ),
    );
  }

  static LockScreenMealRegisterResult _registerExercise({
    required LockScreenMealButtonSnapshot button,
    required String ownerUserId,
    required DateTime loggedAt,
    required String Function() newId,
  }) {
    final usable = [
      for (final item in button.exercises)
        if (item.canRegister) item.copyWith(itemId: newId()),
    ];
    if (usable.isEmpty) {
      return const LockScreenMealRegisterResult(
        status: LockScreenMealRegisterStatus.unassigned,
      );
    }
    return LockScreenMealRegisterResult(
      status: LockScreenMealRegisterStatus.registered,
      meal: PendingLockScreenMeal(
        registrationId: newId(),
        ownerUserId: ownerUserId,
        slot: button.slot,
        templateId: _patternId(button),
        mealGroupId: '',
        mealGroupName: button.templateName ?? button.label,
        loggedAt: loggedAt,
        entries: const [],
        kind: WidgetPatternKind.exercise,
        exercises: usable,
      ),
    );
  }

  static String _patternId(LockScreenMealButtonSnapshot button) {
    final templateId = button.templateId?.trim();
    if (templateId != null && templateId.isNotEmpty) {
      return templateId;
    }
    return 'widget-${button.kind.name}-${button.slot}';
  }
}

LockScreenMealImportPlan planLockScreenMealImport({
  required List<PendingLockScreenMeal> pending,
  required String ownerUserId,
  required Set<String> existingEntryIds,
}) {
  final entries = <FoodEntry>[];
  final acknowledgeIds = <String>[];
  final templateIds = <String>[];
  final exerciseRecords = <PendingLockScreenMeal>[];
  for (final meal in pending) {
    if (meal.ownerUserId != ownerUserId) {
      continue;
    }
    if (meal.kind == WidgetPatternKind.exercise) {
      exerciseRecords.add(meal);
      continue;
    }
    final fresh = meal.entries
        .where((entry) => !existingEntryIds.contains(entry.id))
        .toList();
    if (fresh.isNotEmpty) {
      entries.addAll(fresh);
      templateIds.add(meal.templateId);
    }
    acknowledgeIds.add(meal.registrationId);
  }
  return LockScreenMealImportPlan(
    entries: entries,
    acknowledgeIds: acknowledgeIds,
    templateIds: templateIds,
    exerciseRecords: exerciseRecords,
  );
}

abstract final class LockScreenMealCodec {
  static String encodeConfig(LockScreenMealConfig config) {
    return jsonEncode({
      'version': lockScreenMealSchemaVersion,
      'home': _encodeButtons(config.homeButtons),
      'lock': _encodeButtons(config.lockButtons),
    });
  }

  static List<Map<String, Object?>> _encodeButtons(
    List<LockScreenMealButtonConfig> buttons,
  ) {
    return [
      for (final button in buttons)
        {
          'slot': button.slot,
          'label': button.label,
          'kind': button.kind.name,
          if (button.contentName != null) 'name': button.contentName,
          'items': [for (final item in button.items) _mealItemJson(item)],
          'exercises': [
            for (final item in button.exercises) _exerciseJson(item),
          ],
        },
    ];
  }

  static LockScreenMealConfig decodeConfig(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return LockScreenMealConfig.defaults();
    }
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      return LockScreenMealConfig.defaults();
    }
    final defaults = LockScreenMealConfig.defaults();
    return LockScreenMealConfig(
      homeButtons: _decodeButtons(
        decoded['home'],
        count: LockScreenMealConfig.homeSlotCount,
        fallback: defaults.homeButtons,
      ),
      lockButtons: _decodeButtons(
        decoded['lock'] ?? decoded['buttons'],
        count: LockScreenMealConfig.lockSlotCount,
        fallback: defaults.lockButtons,
      ),
    );
  }

  static List<LockScreenMealButtonConfig> _decodeButtons(
    Object? rows, {
    required int count,
    required List<LockScreenMealButtonConfig> fallback,
  }) {
    final bySlot = <int, LockScreenMealButtonConfig>{};
    if (rows is List) {
      for (final row in rows) {
        if (row is! Map) {
          continue;
        }
        final slot = _asInt(row['slot']);
        if (slot < 0 || slot >= count) {
          continue;
        }
        bySlot[slot] = LockScreenMealButtonConfig(
          slot: slot,
          label: _asString(row['label']) ?? '',
          kind: _patternKind(
            row['kind'],
            slot: slot,
            homeSized: count == LockScreenMealConfig.homeSlotCount,
          ),
          contentName: _asString(row['name']),
          items: _mealItems(row['items']),
          exercises: _exercisePatterns(row['exercises']),
        );
      }
    }
    return [
      for (var slot = 0; slot < count; slot++) bySlot[slot] ?? fallback[slot],
    ];
  }

  static String encodeSnapshot(LockScreenMealSnapshot snapshot) {
    return jsonEncode({
      'version': lockScreenMealSchemaVersion,
      'ownerUserId': snapshot.ownerUserId,
      'remaining': snapshot.figures.remainingKcal,
      'intake': snapshot.figures.intakeKcal,
      'burn': snapshot.figures.burnKcal,
      'target': snapshot.figures.targetKcal,
      'overage': snapshot.figures.overageKcal,
      'home': [for (final button in snapshot.homeButtons) _buttonJson(button)],
      'lock': [for (final button in snapshot.lockButtons) _buttonJson(button)],
    });
  }

  static String encodePending(List<PendingLockScreenMeal> meals) {
    return jsonEncode([
      for (final meal in meals)
        {
          'registrationId': meal.registrationId,
          'ownerUserId': meal.ownerUserId,
          'slot': meal.slot,
          'kind': meal.kind.name,
          'templateId': meal.templateId,
          'mealGroupId': meal.mealGroupId,
          'mealGroupName': meal.mealGroupName,
          'loggedAt': formatLockScreenLoggedAt(meal.loggedAt),
          if (meal.surface != null) 'surface': meal.surface,
          'items': [for (final entry in meal.entries) _entryJson(entry)],
          if (meal.exercises.isNotEmpty)
            'exercises': [
              for (final item in meal.exercises) _exerciseJson(item),
            ],
        },
    ]);
  }

  static List<PendingLockScreenMeal> decodePending(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return const [];
    }
    final decoded = jsonDecode(raw);
    if (decoded is! List) {
      return const [];
    }
    final meals = <PendingLockScreenMeal>[];
    for (final row in decoded) {
      if (row is! Map) {
        continue;
      }
      final registrationId = _asString(row['registrationId']);
      final ownerUserId = _asString(row['ownerUserId']);
      final loggedAtRaw = _asString(row['loggedAt']);
      if (registrationId == null ||
          ownerUserId == null ||
          loggedAtRaw == null) {
        continue;
      }
      final kind = _patternKind(row['kind'], slot: _asInt(row['slot']));
      if (kind == WidgetPatternKind.exercise) {
        final exercises = _exercisePatterns(row['exercises']);
        if (exercises.isEmpty) {
          continue;
        }
        meals.add(
          PendingLockScreenMeal(
            registrationId: registrationId,
            ownerUserId: ownerUserId,
            slot: _asInt(row['slot']),
            templateId: _asString(row['templateId']) ?? '',
            mealGroupId: _asString(row['mealGroupId']) ?? '',
            mealGroupName: _asString(row['mealGroupName']) ?? '',
            loggedAt: parseLockScreenLoggedAt(loggedAtRaw),
            entries: const [],
            surface: _asString(row['surface']),
            kind: WidgetPatternKind.exercise,
            exercises: exercises,
          ),
        );
        continue;
      }
      final templateId = _asString(row['templateId']);
      final mealGroupId = _asString(row['mealGroupId']);
      if (templateId == null || mealGroupId == null) {
        continue;
      }
      final itemRows = row['items'];
      if (itemRows is! List) {
        continue;
      }
      final entries = <FoodEntry>[];
      for (final item in itemRows) {
        if (item is! Map) {
          continue;
        }
        final entry = _entryFromJson(
          item,
          mealGroupId: mealGroupId,
          mealGroupName: _asString(row['mealGroupName']) ?? '',
          loggedAt: parseLockScreenLoggedAt(loggedAtRaw),
        );
        if (entry != null) {
          entries.add(entry);
        }
      }
      if (entries.isEmpty) {
        continue;
      }
      meals.add(
        PendingLockScreenMeal(
          registrationId: registrationId,
          ownerUserId: ownerUserId,
          slot: _asInt(row['slot']),
          templateId: templateId,
          mealGroupId: mealGroupId,
          mealGroupName: _asString(row['mealGroupName']) ?? '',
          loggedAt: parseLockScreenLoggedAt(loggedAtRaw),
          entries: entries,
          surface: _asString(row['surface']),
          kind: WidgetPatternKind.meal,
        ),
      );
    }
    return meals;
  }

  static Map<String, Object?> _buttonJson(LockScreenMealButtonSnapshot button) {
    return {
      'slot': button.slot,
      'label': button.label,
      'kind': button.kind.name,
      'templateId': button.templateId,
      'templateName': button.templateName,
      'items': [
        for (final item in button.items)
          {
            'name': item.name,
            'kcalPerBase': item.kcalPerBase,
            'proteinPerBase': item.proteinPerBase,
            'fatPerBase': item.fatPerBase,
            'carbPerBase': item.carbPerBase,
            'baseAmount': item.baseAmount,
            'unitType': item.unitType.storageValue,
            'consumedAmount': item.consumedAmount,
            'savedFoodId': item.savedFoodId,
            'sourceOwnerUserId': item.sourceOwnerUserId,
            'sortOrder': item.sortOrder,
          },
      ],
      'exercises': [for (final item in button.exercises) _exerciseJson(item)],
    };
  }

  static Map<String, Object?> _entryJson(FoodEntry entry) {
    return {
      'id': entry.id,
      'name': entry.name,
      'kcalPerBase': entry.kcalPerBase,
      'proteinPerBase': entry.proteinPerBase,
      'fatPerBase': entry.fatPerBase,
      'carbPerBase': entry.carbPerBase,
      'baseAmount': entry.baseAmount,
      'unitType': entry.unitType.storageValue,
      'consumedAmount': entry.consumedAmount,
      'savedFoodId': entry.savedFoodId,
      'sourceOwnerUserId': entry.sourceFoodOwnerUserId,
      'sortOrder': entry.sortOrder,
    };
  }

  static FoodEntry? _entryFromJson(
    Map item, {
    required String mealGroupId,
    required String mealGroupName,
    required DateTime loggedAt,
  }) {
    final id = _asString(item['id']);
    final name = _asString(item['name']);
    final baseAmount = _asDouble(item['baseAmount']);
    final consumedAmount = _asDouble(item['consumedAmount']);
    if (id == null ||
        name == null ||
        name.trim().isEmpty ||
        baseAmount == null ||
        baseAmount <= 0 ||
        consumedAmount == null ||
        consumedAmount <= 0) {
      return null;
    }
    final savedFoodId = _asString(item['savedFoodId']);
    return FoodEntry(
      id: id,
      name: name,
      kcalPerBase: _asDouble(item['kcalPerBase']),
      proteinPerBase: _asDouble(item['proteinPerBase']),
      fatPerBase: _asDouble(item['fatPerBase']),
      carbPerBase: _asDouble(item['carbPerBase']),
      baseAmount: baseAmount,
      unitType:
          FoodUnitTypeX.tryParse(_asString(item['unitType'])) ??
          FoodUnitType.serving,
      consumedAmount: consumedAmount,
      sourceType: savedFoodId == null
          ? FoodEntrySource.manual
          : FoodEntrySource.savedFood,
      savedFoodId: savedFoodId,
      sourceFoodOwnerUserId: _asString(item['sourceOwnerUserId']),
      mealGroupId: mealGroupId,
      mealGroupName: mealGroupName,
      sortOrder: item['sortOrder'] == null ? null : _asInt(item['sortOrder']),
      loggedAt: loggedAt,
    );
  }
}

WidgetPatternKind _patternKind(
  Object? raw, {
  required int slot,
  bool homeSized = false,
}) {
  final value = _asString(raw);
  if (value == WidgetPatternKind.exercise.name) {
    return WidgetPatternKind.exercise;
  }
  if (value == WidgetPatternKind.meal.name) {
    return WidgetPatternKind.meal;
  }
  if (homeSized && slot >= LockScreenMealConfig.lockSlotCount) {
    return WidgetPatternKind.exercise;
  }
  return WidgetPatternKind.meal;
}

List<MealTemplateItem> _mealItems(Object? raw) {
  if (raw is! List) {
    return const [];
  }
  final items = <MealTemplateItem>[];
  for (final row in raw) {
    if (row is! Map) {
      continue;
    }
    final name = _asString(row['name']);
    final baseAmount = _asDouble(row['baseAmount']);
    final consumedAmount = _asDouble(row['consumedAmount']);
    if (name == null ||
        name.trim().isEmpty ||
        baseAmount == null ||
        baseAmount <= 0 ||
        consumedAmount == null ||
        consumedAmount <= 0) {
      continue;
    }
    final savedAt = _asString(row['snapshotSavedAt']);
    items.add(
      MealTemplateItem(
        itemId: _asString(row['itemId']) ?? _asString(row['id']) ?? name,
        savedFoodId: _asString(row['savedFoodId']),
        sourceOwnerUserId: _asString(row['sourceOwnerUserId']),
        name: name,
        baseAmount: baseAmount,
        unitType:
            FoodUnitTypeX.tryParse(_asString(row['unitType'])) ??
            FoodUnitType.serving,
        kcalPerBase: _asDouble(row['kcalPerBase']),
        proteinPerBase: _asDouble(row['proteinPerBase']),
        fatPerBase: _asDouble(row['fatPerBase']),
        carbPerBase: _asDouble(row['carbPerBase']),
        consumedAmount: consumedAmount,
        sortOrder: _asInt(row['sortOrder']),
        snapshotSavedAt: savedAt == null
            ? DateTime(2026, 1, 1)
            : parseLockScreenLoggedAt(savedAt),
      ),
    );
  }
  return items;
}

List<WidgetExercisePattern> _exercisePatterns(Object? raw) {
  if (raw is! List) {
    return const [];
  }
  final items = <WidgetExercisePattern>[];
  for (final row in raw) {
    if (row is! Map) {
      continue;
    }
    final activityId = _asString(row['activityId']);
    if (activityId == null) {
      continue;
    }
    final distance = _asDouble(row['distanceKm']);
    items.add(
      WidgetExercisePattern(
        itemId: _asString(row['id']) ?? _asString(row['itemId']) ?? activityId,
        activityId: activityId,
        name: _asString(row['name']) ?? '',
        sortOrder: _asInt(row['sortOrder']),
        durationMin: _asInt(row['durationMin']),
        distanceKm: distance != null && distance > 0 ? distance : null,
      ),
    );
  }
  return items;
}

Map<String, Object?> _mealItemJson(MealTemplateItem item) {
  return {
    'itemId': item.itemId,
    'name': item.name,
    'kcalPerBase': item.kcalPerBase,
    'proteinPerBase': item.proteinPerBase,
    'fatPerBase': item.fatPerBase,
    'carbPerBase': item.carbPerBase,
    'baseAmount': item.baseAmount,
    'unitType': item.unitType.storageValue,
    'consumedAmount': item.consumedAmount,
    'savedFoodId': item.savedFoodId,
    'sourceOwnerUserId': item.sourceOwnerUserId,
    'sortOrder': item.sortOrder,
    'snapshotSavedAt': formatLockScreenLoggedAt(item.snapshotSavedAt),
  };
}

Map<String, Object?> _exerciseJson(WidgetExercisePattern item) {
  return {
    'id': item.itemId,
    'name': item.name,
    'activityId': item.activityId,
    'durationMin': item.durationMin,
    'distanceKm': item.distanceKm,
    'sortOrder': item.sortOrder,
    if (item.netKcal != null) 'netKcal': item.netKcal,
  };
}

/// ウィジェットの運動パターンを、今の体重で1件の運動記録にする。
///
/// 体重が無い計算種目は null。カロリーは作らない。
ExerciseEntry? widgetExerciseEntry({
  required WidgetExercisePattern pattern,
  required double? weightKg,
  required String id,
  required DateTime loggedAt,
}) {
  if (!pattern.canRegister) {
    return null;
  }
  final activity = MetActivityCatalog.findById(pattern.activityId);
  if (activity == null || activity.requiresManualKcal) {
    return null;
  }
  final name = pattern.name.trim().isEmpty
      ? activity.displayName
      : pattern.name.trim();
  if (activity.lifestyleIncluded || activity.calorieFormula == null) {
    return ExerciseEntry(
      id: id,
      name: name,
      durationMin: pattern.durationMin > 0 ? pattern.durationMin : 1,
      burnedKcal: 0,
      loggedAt: loggedAt,
      category: activity.category,
      activityId: activity.id,
      intensity: activity.defaultIntensityId,
      distanceKm: pattern.distanceKm,
      netKcal: 0,
      grossKcal: 0,
      calculationSource: null,
      sourceKey: activity.sourceKey,
    );
  }
  final weight = weightKg;
  if (weight == null || !weight.isFinite || weight <= 0) {
    return null;
  }
  const calculator = ExerciseCalorieCalculator();
  if (activity.quantityUnit == ExerciseQuantityUnit.distanceKm) {
    final distance = pattern.distanceKm;
    if (distance == null || distance <= 0) {
      return null;
    }
    final factor = activity.netKcalPerKgKm;
    final estimate = factor != null
        ? calculator.estimateByDistanceFactor(
            weightKg: weight,
            distanceKm: distance,
            netKcalPerKgKm: factor,
            sourceKey: activity.sourceKey,
          )
        : activity.referenceSpeedKmh == null
        ? null
        : calculator.estimateByDistanceSpeed(
            met: activity.defaultMet,
            weightKg: weight,
            distanceKm: distance,
            speedKmh: activity.referenceSpeedKmh!,
            sourceKey: activity.sourceKey,
          );
    if (estimate == null) {
      return null;
    }
    return ExerciseEntry(
      id: id,
      name: name,
      durationMin: ExerciseCalorieCalculator.companionDurationMin(
        distanceKm: distance,
        referenceSpeedKmh: activity.referenceSpeedKmh,
      ),
      burnedKcal: estimate.grossKcal,
      loggedAt: loggedAt,
      category: activity.category,
      activityId: activity.id,
      intensity: activity.defaultIntensityId,
      distanceKm: distance,
      metValue: factor == null ? activity.defaultMet : null,
      grossKcal: estimate.grossKcal,
      netKcal: estimate.netKcal,
      weightKgSnapshot: weight,
      calculationSource: estimate.calculationSource,
      calculationVersion: estimate.calculationVersion,
      sourceKey: activity.sourceKey,
    );
  }
  if (pattern.durationMin <= 0 || activity.defaultMet <= 1) {
    return null;
  }
  final estimate = calculator.estimate(
    met: activity.defaultMet,
    weightKg: weight,
    durationMinutes: pattern.durationMin,
    sourceKey: activity.sourceKey,
  );
  if (estimate == null) {
    return null;
  }
  return ExerciseEntry(
    id: id,
    name: name,
    durationMin: pattern.durationMin,
    burnedKcal: estimate.grossKcal,
    loggedAt: loggedAt,
    category: activity.category,
    activityId: activity.id,
    intensity: activity.defaultIntensityId,
    metValue: activity.defaultMet,
    grossKcal: estimate.grossKcal,
    netKcal: estimate.netKcal,
    weightKgSnapshot: weight,
    calculationSource: estimate.calculationSource,
    calculationVersion: estimate.calculationVersion,
    sourceKey: activity.sourceKey,
  );
}

/// 体重が付けば計算できる種目だけ true。手入力や不明な種目は待たない。
bool widgetExerciseWaitsForWeight(
  WidgetExercisePattern pattern,
  double? weightKg,
) {
  if (!pattern.canRegister) {
    return false;
  }
  final activity = MetActivityCatalog.findById(pattern.activityId);
  if (activity == null ||
      activity.requiresManualKcal ||
      activity.lifestyleIncluded ||
      activity.calorieFormula == null) {
    return false;
  }
  return weightKg == null || !weightKg.isFinite || weightKg <= 0;
}

/// 食事の `loggedAt` と同じ、オフセット無しの壁時計。
String formatLockScreenLoggedAt(DateTime loggedAt) {
  final wall = loggedAt.isUtc ? _wallClock(loggedAt) : loggedAt;
  return wall.toIso8601String();
}

DateTime parseLockScreenLoggedAt(String raw) {
  final parsed = DateTime.parse(raw);
  if (!parsed.isUtc) {
    return parsed;
  }
  return _wallClock(parsed);
}

DateTime _wallClock(DateTime value) {
  return DateTime(
    value.year,
    value.month,
    value.day,
    value.hour,
    value.minute,
    value.second,
    value.millisecond,
    value.microsecond,
  );
}

String? _asString(Object? value) {
  if (value is! String) {
    return null;
  }
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    return null;
  }
  return value;
}

int _asInt(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return 0;
}

double? _asDouble(Object? value) {
  if (value is num) {
    return value.toDouble();
  }
  return null;
}
