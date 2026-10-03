import 'dart:convert';

import '../models/food_entry.dart';
import '../models/food_entry_source.dart';
import '../models/food_unit_type.dart';
import '../models/meal_template.dart';

/// ホームとロック画面のウィジェットが共有する JSON（version 2）。
///
/// ウィジェット拡張は Isar を開けない。ボタンを押した瞬間に App Group へ
/// 今日の食事を1件追記し、アプリは次回の起動・復帰でそれを取り込む。
/// `loggedAt` は押した時刻の壁時計（オフセット無し）で、取り込み時刻ではない。
const int lockScreenMealSchemaVersion = 2;

const String lockScreenMealMethodChannel = 'com.narutoaii.ayg/lock_screen_meal';

/// ウィジェットと Siri が読む有料フラグ。既定は false。
///
/// 設定のスイッチからは変えない。カロナビ+ の加入が有効なときだけ true になり、
/// 期限切れか返金で false に戻る。Health の数値はここには入れない。
abstract final class LockScreenMealPaidFlag {
  static const String storageKey = 'lock_screen_meal_paid';

  static bool readValue(bool? stored) => stored ?? false;
}

class LockScreenMealButtonConfig {
  const LockScreenMealButtonConfig({
    required this.slot,
    required this.label,
    this.templateId,
  });

  final int slot;
  final String label;
  final String? templateId;

  LockScreenMealButtonConfig copyWith({
    String? label,
    String? templateId,
    bool clearTemplate = false,
  }) {
    return LockScreenMealButtonConfig(
      slot: slot,
      label: label ?? this.label,
      templateId: clearTemplate ? null : (templateId ?? this.templateId),
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
    '間食',
    'ジョギング',
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
    return LockScreenMealButtonConfig(slot: slot, label: label);
  }
}

/// ウィジェットに出す、今日の残り・摂取・消費。
class MealWidgetFigures {
  const MealWidgetFigures({this.remainingKcal, this.intakeKcal, this.burnKcal});

  final int? remainingKcal;
  final int? intakeKcal;
  final int? burnKcal;
}

class LockScreenMealButtonSnapshot {
  const LockScreenMealButtonSnapshot({
    required this.slot,
    required this.label,
    this.templateId,
    this.templateName,
    this.items = const [],
  });

  final int slot;
  final String label;
  final String? templateId;
  final String? templateName;
  final List<MealTemplateItem> items;

  bool get canRegister =>
      templateId != null && templateId!.trim().isNotEmpty && items.isNotEmpty;
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
}

class LockScreenMealImportPlan {
  const LockScreenMealImportPlan({
    required this.entries,
    required this.acknowledgeIds,
    required this.templateIds,
  });

  final List<FoodEntry> entries;
  final List<String> acknowledgeIds;
  final List<String> templateIds;
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
    final templateId = button.templateId?.trim();
    if (ownerUserId.trim().isEmpty ||
        templateId == null ||
        templateId.isEmpty ||
        button.items.isEmpty) {
      return const LockScreenMealRegisterResult(
        status: LockScreenMealRegisterStatus.unassigned,
      );
    }

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
      ),
    );
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
  for (final meal in pending) {
    if (meal.ownerUserId != ownerUserId) {
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
          'templateId': button.templateId,
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
        final templateId = _asString(row['templateId']);
        bySlot[slot] = LockScreenMealButtonConfig(
          slot: slot,
          label: _asString(row['label']) ?? '',
          templateId: templateId == null || templateId.isEmpty
              ? null
              : templateId,
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
          'templateId': meal.templateId,
          'mealGroupId': meal.mealGroupId,
          'mealGroupName': meal.mealGroupName,
          'loggedAt': formatLockScreenLoggedAt(meal.loggedAt),
          if (meal.surface != null) 'surface': meal.surface,
          'items': [for (final entry in meal.entries) _entryJson(entry)],
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
      final templateId = _asString(row['templateId']);
      final mealGroupId = _asString(row['mealGroupId']);
      final loggedAtRaw = _asString(row['loggedAt']);
      if (registrationId == null ||
          ownerUserId == null ||
          templateId == null ||
          mealGroupId == null ||
          loggedAtRaw == null) {
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
        ),
      );
    }
    return meals;
  }

  static Map<String, Object?> _buttonJson(LockScreenMealButtonSnapshot button) {
    return {
      'slot': button.slot,
      'label': button.label,
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
