import 'dart:convert';

import '../data/met_activity_catalog.dart';
import '../models/exercise_calculation_source.dart';
import '../models/exercise_entry.dart';
import '../models/exercise_quantity_unit.dart';
import '../models/food_entry.dart';
import '../models/food_entry_source.dart';
import '../models/food_unit_type.dart';
import '../models/saved_food.dart';
import '../services/exercise_calorie_calculator.dart';
import '../utils/food_search_normalizer.dart';
import 'lock_screen_meal.dart';

/// Siri の食事・運動登録。
///
/// 復唱して「はい」のときだけ1件作る。「いいえ」と無言では作らない。
/// 食品は渡されたデータベースの完全一致だけ。運動は既存の式で計算できる量だけ。
/// 食事テンプレートの一発登録はここには無い。
const String siriVoiceMethodChannel = 'com.narutoaii.ayg/siri_voice';

enum SiriAnswer { yes, no, silence }

enum SiriVoiceStatus {
  ready,
  unpaid,
  signedOut,
  notFound,
  ambiguous,
  unsupportedAmount,
  missingWeight,
  declined,
  silence,
  registered,
}

enum SiriQuantityUnit {
  grams,
  milliliters,
  piece,
  serving,
  minutes,
  kilometers,
  reps,
}

class SiriQuantity {
  const SiriQuantity(this.amount, this.unit);

  final double amount;
  final SiriQuantityUnit unit;
}

class SiriFoodRecord {
  const SiriFoodRecord({
    required this.id,
    required this.speakName,
    required this.keys,
    required this.baseAmount,
    required this.unit,
    required this.source,
    this.kcalPerBase,
    this.proteinPerBase,
    this.fatPerBase,
    this.carbPerBase,
    this.savedFoodId,
    this.sourceOwnerUserId,
    this.version,
    this.officialFoodCode,
    this.officialFoodName,
  });

  final String id;
  final String speakName;
  final List<String> keys;
  final double baseAmount;
  final FoodUnitType unit;
  final FoodEntrySource source;
  final double? kcalPerBase;
  final double? proteinPerBase;
  final double? fatPerBase;
  final double? carbPerBase;
  final String? savedFoodId;
  final String? sourceOwnerUserId;
  final int? version;
  final String? officialFoodCode;
  final String? officialFoodName;

  factory SiriFoodRecord.saved(SavedFood food) {
    return SiriFoodRecord(
      id: food.foodId,
      speakName: food.name,
      keys: _keys([food.normalizedName, food.name, food.officialFoodName]),
      baseAmount: food.baseAmount,
      unit: food.unitType,
      source: FoodEntrySource.savedFood,
      kcalPerBase: food.kcalPerBase,
      proteinPerBase: food.proteinPerBase,
      fatPerBase: food.fatPerBase,
      carbPerBase: food.carbPerBase,
      savedFoodId: food.foodId,
      sourceOwnerUserId: food.ownerUserId,
      version: food.version,
      officialFoodCode: food.officialFoodCode,
      officialFoodName: food.officialFoodName,
    );
  }

  factory SiriFoodRecord.official({
    required String foodCode,
    required String name,
    required String speakName,
    required List<String> matchTexts,
    required double baseAmount,
    required FoodUnitType unit,
    double? kcalPerBase,
    double? proteinPerBase,
    double? fatPerBase,
    double? carbPerBase,
  }) {
    return SiriFoodRecord(
      id: foodCode,
      speakName: speakName,
      keys: _keys(matchTexts),
      baseAmount: baseAmount <= 0 ? 100 : baseAmount,
      unit: unit,
      source: FoodEntrySource.mextSfct,
      kcalPerBase: kcalPerBase,
      proteinPerBase: proteinPerBase,
      fatPerBase: fatPerBase,
      carbPerBase: carbPerBase,
      officialFoodCode: foodCode,
      officialFoodName: name,
    );
  }
}

class SiriVoiceContext {
  const SiriVoiceContext({
    required this.paid,
    required this.ownerUserId,
    required this.foods,
    this.weightKg,
  });

  final bool paid;
  final String ownerUserId;
  final double? weightKg;
  final List<SiriFoodRecord> foods;
}

class SiriVoicePlan {
  const SiriVoicePlan._({
    required this.status,
    required this.spoken,
    required this.asksConfirmation,
    this.food,
    this.activityId,
    this.quantity,
  });

  final SiriVoiceStatus status;
  final String spoken;
  final bool asksConfirmation;
  final SiriFoodRecord? food;
  final String? activityId;
  final SiriQuantity? quantity;

  bool get isReady => status == SiriVoiceStatus.ready && asksConfirmation;
}

class SiriVoiceResult {
  const SiriVoiceResult({
    required this.status,
    required this.spoken,
    this.food,
    this.exercise,
  });

  final SiriVoiceStatus status;
  final String spoken;
  final FoodEntry? food;
  final ExerciseEntry? exercise;

  bool get registered =>
      status == SiriVoiceStatus.registered &&
      (food != null || exercise != null);
}

class SiriVoiceImportPlan {
  const SiriVoiceImportPlan({
    required this.foods,
    required this.exercises,
    required this.acknowledgeIds,
  });

  final List<FoodEntry> foods;
  final List<ExerciseEntry> exercises;
  final List<String> acknowledgeIds;
}

SiriQuantity? parseSiriQuantity(String raw) {
  final compact = raw.trim().replaceAll(' ', '').replaceAll('　', '');
  final match = RegExp(r'^(\d+(?:\.\d+)?)(.*)$').firstMatch(compact);
  if (match == null) {
    return null;
  }
  final amount = double.tryParse(match.group(1)!);
  if (amount == null || amount <= 0 || amount >= 100000) {
    return null;
  }
  final unit = switch (match.group(2)) {
    'g' || 'G' || 'ｇ' || 'グラム' => SiriQuantityUnit.grams,
    'ml' || 'mL' || 'ML' || 'ｍｌ' || 'ミリリットル' => SiriQuantityUnit.milliliters,
    '個' || 'こ' || 'コ' => SiriQuantityUnit.piece,
    '食' || '食分' => SiriQuantityUnit.serving,
    '分' || '分間' => SiriQuantityUnit.minutes,
    '回' => SiriQuantityUnit.reps,
    'km' || 'KM' || '㎞' || 'キロ' || 'キロメートル' => SiriQuantityUnit.kilometers,
    _ => null,
  };
  if (unit == null) {
    return null;
  }
  return SiriQuantity(amount, unit);
}

String formatSiriQuantity(SiriQuantity quantity) {
  final amount = quantity.amount;
  final number = amount == amount.roundToDouble()
      ? '${amount.round()}'
      : amount.toString();
  final suffix = switch (quantity.unit) {
    SiriQuantityUnit.grams => 'g',
    SiriQuantityUnit.milliliters => 'ml',
    SiriQuantityUnit.piece => '個',
    SiriQuantityUnit.serving => '食',
    SiriQuantityUnit.minutes => '分',
    SiriQuantityUnit.kilometers => 'km',
    SiriQuantityUnit.reps => '回',
  };
  return '$number$suffix';
}

SiriVoicePlan planSiriFood({
  required SiriVoiceContext context,
  required String name,
  required String quantity,
}) {
  final blocked = _blocked(context);
  if (blocked != null) {
    return blocked;
  }
  final split = _split(name, quantity);
  final parsed = parseSiriQuantity(split.quantity);
  if (split.name.isEmpty) {
    return _stop(SiriVoiceStatus.notFound, '食品名が分かりません');
  }
  if (parsed == null) {
    return _stop(SiriVoiceStatus.unsupportedAmount, '量が分かりません');
  }
  final key = FoodSearchNormalizer.normalize(split.name);
  final matches = context.foods
      .where((food) => food.keys.contains(key))
      .toList();
  final saved = matches
      .where((food) => food.source == FoodEntrySource.savedFood)
      .toList();
  final pool = saved.isNotEmpty
      ? saved
      : matches
            .where((food) => food.source == FoodEntrySource.mextSfct)
            .toList();
  if (pool.isEmpty) {
    return _stop(SiriVoiceStatus.notFound, '${split.name}は見つかりません');
  }
  final ids = pool.map((food) => food.id).toSet();
  if (ids.length != 1) {
    return _stop(SiriVoiceStatus.ambiguous, '${split.name}はひとつに決まりません');
  }
  final food = pool.first;
  if (!_foodUnitFits(food.unit, parsed.unit)) {
    return _stop(
      SiriVoiceStatus.unsupportedAmount,
      '${food.speakName}は${food.unit.label}で指定してください',
    );
  }
  return SiriVoicePlan._(
    status: SiriVoiceStatus.ready,
    spoken: '${food.speakName}を${formatSiriQuantity(parsed)}ですね',
    asksConfirmation: true,
    food: food,
    quantity: parsed,
  );
}

SiriVoicePlan planSiriExercise({
  required SiriVoiceContext context,
  required String name,
  required String quantity,
}) {
  final blocked = _blocked(context);
  if (blocked != null) {
    return blocked;
  }
  final split = _split(name, quantity);
  final parsed = parseSiriQuantity(split.quantity);
  if (split.name.isEmpty) {
    return _stop(SiriVoiceStatus.notFound, '種目が分かりません');
  }
  if (parsed == null) {
    return _stop(SiriVoiceStatus.unsupportedAmount, '量が分かりません');
  }
  final key = FoodSearchNormalizer.normalize(split.name);
  final matches = MetActivityCatalog.activities.where((activity) {
    if (!activity.searchable) {
      return false;
    }
    return activity.aliases.any(
      (alias) => FoodSearchNormalizer.normalize(alias) == key,
    );
  }).toList();
  if (matches.isEmpty) {
    return _stop(SiriVoiceStatus.notFound, '${split.name}は見つかりません');
  }
  if (matches.length != 1) {
    return _stop(SiriVoiceStatus.ambiguous, '${split.name}はひとつに決まりません');
  }
  final activity = matches.single;
  if (activity.requiresManualKcal ||
      activity.quantityUnit == ExerciseQuantityUnit.reps) {
    return _stop(
      SiriVoiceStatus.unsupportedAmount,
      '${activity.displayName}は手入力の種目です',
    );
  }
  final spokenUnitFits = switch (activity.quantityUnit) {
    ExerciseQuantityUnit.durationMin => parsed.unit == SiriQuantityUnit.minutes,
    ExerciseQuantityUnit.distanceKm =>
      parsed.unit == SiriQuantityUnit.kilometers,
    ExerciseQuantityUnit.reps => false,
  };
  if (!spokenUnitFits) {
    final unitLabel = switch (activity.quantityUnit) {
      ExerciseQuantityUnit.distanceKm => 'km',
      ExerciseQuantityUnit.durationMin => '分',
      ExerciseQuantityUnit.reps => '回',
    };
    return _stop(
      SiriVoiceStatus.unsupportedAmount,
      '${activity.displayName}は$unitLabelで指定してください',
    );
  }
  final needsWeight = !activity.lifestyleIncluded;
  final weight = context.weightKg;
  if (needsWeight && (weight == null || weight <= 0)) {
    return _stop(SiriVoiceStatus.missingWeight, '体重が無いので登録できません');
  }
  final built = buildSiriExerciseEntry(
    id: 'check',
    activityId: activity.id,
    amount: parsed.amount,
    unit: parsed.unit,
    weightKg: weight,
    loggedAt: DateTime(2026),
  );
  if (built == null) {
    return _stop(SiriVoiceStatus.unsupportedAmount, '計算できないので登録しません');
  }
  return SiriVoicePlan._(
    status: SiriVoiceStatus.ready,
    spoken: '${activity.displayName}を${formatSiriQuantity(parsed)}ですね',
    asksConfirmation: true,
    activityId: activity.id,
    quantity: parsed,
  );
}

SiriVoiceResult commitSiriVoice({
  required SiriVoicePlan plan,
  required SiriAnswer answer,
  required DateTime loggedAt,
  required String ownerUserId,
  required double? weightKg,
  required String Function() newId,
}) {
  if (!plan.isReady) {
    return SiriVoiceResult(status: plan.status, spoken: plan.spoken);
  }
  if (answer == SiriAnswer.no) {
    return const SiriVoiceResult(
      status: SiriVoiceStatus.declined,
      spoken: '登録しません',
    );
  }
  if (answer != SiriAnswer.yes) {
    return const SiriVoiceResult(
      status: SiriVoiceStatus.silence,
      spoken: '登録しません',
    );
  }
  final food = plan.food;
  final quantity = plan.quantity;
  if (food != null && quantity != null) {
    return SiriVoiceResult(
      status: SiriVoiceStatus.registered,
      spoken: '登録しました',
      food: FoodEntry(
        id: newId(),
        name: food.speakName,
        kcalPerBase: food.kcalPerBase,
        proteinPerBase: food.proteinPerBase,
        fatPerBase: food.fatPerBase,
        carbPerBase: food.carbPerBase,
        baseAmount: food.baseAmount,
        unitType: food.unit,
        consumedAmount: quantity.amount,
        sourceType: food.source,
        savedFoodId: food.savedFoodId,
        sourceFoodOwnerUserId: food.sourceOwnerUserId,
        sourceSavedFoodVersion: food.version,
        officialFoodCode: food.officialFoodCode,
        officialFoodName: food.officialFoodName,
        loggedAt: loggedAt,
      ),
    );
  }
  final activityId = plan.activityId;
  if (activityId != null && quantity != null) {
    final exercise = buildSiriExerciseEntry(
      id: newId(),
      activityId: activityId,
      amount: quantity.amount,
      unit: quantity.unit,
      weightKg: weightKg,
      loggedAt: loggedAt,
    );
    if (exercise == null) {
      return const SiriVoiceResult(
        status: SiriVoiceStatus.unsupportedAmount,
        spoken: '計算できないので登録しません',
      );
    }
    return SiriVoiceResult(
      status: SiriVoiceStatus.registered,
      spoken: '登録しました',
      exercise: exercise,
    );
  }
  return const SiriVoiceResult(
    status: SiriVoiceStatus.unsupportedAmount,
    spoken: '登録しません',
  );
}

ExerciseEntry? buildSiriExerciseEntry({
  required String id,
  required String activityId,
  required double amount,
  required SiriQuantityUnit unit,
  required double? weightKg,
  required DateTime loggedAt,
}) {
  final activity = MetActivityCatalog.findById(activityId);
  if (activity == null ||
      !activity.searchable ||
      activity.requiresManualKcal ||
      activity.quantityUnit == ExerciseQuantityUnit.reps) {
    return null;
  }
  if (activity.lifestyleIncluded) {
    if (unit != SiriQuantityUnit.minutes) {
      return null;
    }
    final minutes = amount.round();
    if (minutes <= 0 || minutes >= 24 * 60) {
      return null;
    }
    return ExerciseEntry(
      id: id,
      name: activity.displayName,
      durationMin: minutes,
      burnedKcal: 0,
      loggedAt: loggedAt,
      category: activity.category,
      activityId: activity.id,
      netKcal: 0,
      grossKcal: 0,
      calculationSource: ExerciseCalculationSource.lifestyleIncluded,
      calculationVersion: MetActivityCatalog.calculationVersion,
      sourceKey: activity.sourceKey,
    );
  }
  final weight = weightKg;
  if (weight == null || weight <= 0) {
    return null;
  }
  const calculator = ExerciseCalorieCalculator();
  switch (activity.quantityUnit) {
    case ExerciseQuantityUnit.durationMin:
      if (unit != SiriQuantityUnit.minutes || activity.calorieFormula == null) {
        return null;
      }
      final minutes = amount.round();
      final estimate = calculator.estimate(
        met: activity.defaultMet,
        weightKg: weight,
        durationMinutes: minutes,
        sourceKey: activity.sourceKey,
      );
      if (estimate == null) {
        return null;
      }
      return ExerciseEntry(
        id: id,
        name: activity.displayName,
        durationMin: minutes,
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
    case ExerciseQuantityUnit.distanceKm:
      if (unit != SiriQuantityUnit.kilometers) {
        return null;
      }
      final factor = activity.netKcalPerKgKm;
      final estimate = factor != null
          ? calculator.estimateByDistanceFactor(
              weightKg: weight,
              distanceKm: amount,
              netKcalPerKgKm: factor,
              sourceKey: activity.sourceKey,
            )
          : activity.referenceSpeedKmh == null
          ? null
          : calculator.estimateByDistanceSpeed(
              met: activity.defaultMet,
              weightKg: weight,
              distanceKm: amount,
              speedKmh: activity.referenceSpeedKmh!,
              sourceKey: activity.sourceKey,
            );
      if (estimate == null) {
        return null;
      }
      return ExerciseEntry(
        id: id,
        name: activity.displayName,
        durationMin: ExerciseCalorieCalculator.companionDurationMin(
          distanceKm: amount,
          referenceSpeedKmh: activity.referenceSpeedKmh,
        ),
        burnedKcal: estimate.grossKcal,
        loggedAt: loggedAt,
        category: activity.category,
        activityId: activity.id,
        intensity: activity.defaultIntensityId,
        distanceKm: amount,
        metValue: factor == null ? activity.defaultMet : null,
        grossKcal: estimate.grossKcal,
        netKcal: estimate.netKcal,
        weightKgSnapshot: weight,
        calculationSource: estimate.calculationSource,
        calculationVersion: estimate.calculationVersion,
        sourceKey: activity.sourceKey,
      );
    case ExerciseQuantityUnit.reps:
      return null;
  }
}

abstract final class SiriVoiceCodec {
  static String encodeCatalog({
    required String ownerUserId,
    required double? weightKg,
    required bool officialFoodsEnabled,
    required String supabaseUrl,
    required String supabaseAnonKey,
    required List<SiriFoodRecord> foods,
  }) {
    return jsonEncode({
      'version': 1,
      'ownerUserId': ownerUserId,
      'weightKg': weightKg,
      'officialFoodsEnabled': officialFoodsEnabled,
      'supabaseUrl': officialFoodsEnabled ? supabaseUrl : '',
      'supabaseAnonKey': officialFoodsEnabled ? supabaseAnonKey : '',
      'foods': [for (final food in foods) _foodJson(food)],
      'activities': [
        for (final activity in MetActivityCatalog.activities)
          if (activity.searchable)
            {
              'id': activity.id,
              'speakName': activity.displayName,
              'keys': [
                for (final alias in activity.aliases)
                  FoodSearchNormalizer.normalize(alias),
              ],
              'unit': activity.quantityUnit.name,
              'requiresManualKcal': activity.requiresManualKcal,
              'lifestyleIncluded': activity.lifestyleIncluded,
            },
      ],
    });
  }

  static String encodePending({
    required String ownerUserId,
    FoodEntry? food,
    ExerciseEntry? exercise,
    double? weightKg,
  }) {
    final rows = <Map<String, Object?>>[];
    if (food != null) {
      rows.add({
        'kind': 'food',
        'id': food.id,
        'ownerUserId': ownerUserId,
        'loggedAt': formatLockScreenLoggedAt(food.loggedAt),
        'name': food.name,
        'baseAmount': food.baseAmount,
        'unit': food.unitType.storageValue,
        'consumedAmount': food.consumedAmount,
        'kcalPerBase': food.kcalPerBase,
        'proteinPerBase': food.proteinPerBase,
        'fatPerBase': food.fatPerBase,
        'carbPerBase': food.carbPerBase,
        'source': food.sourceType.storageValue,
        'savedFoodId': food.savedFoodId,
        'sourceOwnerUserId': food.sourceFoodOwnerUserId,
        'version': food.sourceSavedFoodVersion,
        'officialFoodCode': food.officialFoodCode,
        'officialFoodName': food.officialFoodName,
      });
    }
    if (exercise != null) {
      final unit = exercise.distanceKm != null
          ? SiriQuantityUnit.kilometers
          : SiriQuantityUnit.minutes;
      final amount = exercise.distanceKm ?? exercise.durationMin.toDouble();
      rows.add({
        'kind': 'exercise',
        'id': exercise.id,
        'ownerUserId': ownerUserId,
        'loggedAt': formatLockScreenLoggedAt(exercise.loggedAt),
        'activityId': exercise.activityId,
        'amount': amount,
        'quantityUnit': unit.name,
        'weightKg': weightKg ?? exercise.weightKgSnapshot,
      });
    }
    return jsonEncode(rows);
  }

  static SiriVoiceImportPlan decodePending({
    required String? raw,
    required String ownerUserId,
    required Set<String> existingFoodIds,
    required Set<String> existingExerciseIds,
  }) {
    if (raw == null || raw.trim().isEmpty) {
      return const SiriVoiceImportPlan(
        foods: [],
        exercises: [],
        acknowledgeIds: [],
      );
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      return const SiriVoiceImportPlan(
        foods: [],
        exercises: [],
        acknowledgeIds: [],
      );
    }
    if (decoded is! List) {
      return const SiriVoiceImportPlan(
        foods: [],
        exercises: [],
        acknowledgeIds: [],
      );
    }
    final foods = <FoodEntry>[];
    final exercises = <ExerciseEntry>[];
    final acknowledgeIds = <String>[];
    for (final row in decoded) {
      if (row is! Map) {
        continue;
      }
      final id = _string(row['id']);
      final owner = _string(row['ownerUserId']);
      if (id == null || owner == null || owner != ownerUserId) {
        continue;
      }
      acknowledgeIds.add(id);
      final loggedAt = _loggedAt(row['loggedAt']);
      if (loggedAt == null) {
        continue;
      }
      if (row['kind'] == 'food') {
        if (existingFoodIds.contains(id)) {
          continue;
        }
        final entry = _foodEntry(row, id: id, loggedAt: loggedAt);
        if (entry != null) {
          foods.add(entry);
        }
        continue;
      }
      if (row['kind'] == 'exercise') {
        if (existingExerciseIds.contains(id)) {
          continue;
        }
        final amount = _double(row['amount']);
        final unit = _quantityUnit(_string(row['quantityUnit']));
        final activityId = _string(row['activityId']);
        if (amount == null || unit == null || activityId == null) {
          continue;
        }
        final entry = buildSiriExerciseEntry(
          id: id,
          activityId: activityId,
          amount: amount,
          unit: unit,
          weightKg: _double(row['weightKg']),
          loggedAt: loggedAt,
        );
        if (entry != null) {
          exercises.add(entry);
        }
      }
    }
    return SiriVoiceImportPlan(
      foods: foods,
      exercises: exercises,
      acknowledgeIds: acknowledgeIds,
    );
  }
}

SiriVoicePlan? _blocked(SiriVoiceContext context) {
  if (!context.paid) {
    return _stop(SiriVoiceStatus.unpaid, 'こちらはカロナビ+の機能です');
  }
  if (context.ownerUserId.trim().isEmpty) {
    return _stop(SiriVoiceStatus.signedOut, 'ログインしてください');
  }
  return null;
}

SiriVoicePlan _stop(SiriVoiceStatus status, String spoken) {
  return SiriVoicePlan._(
    status: status,
    spoken: spoken,
    asksConfirmation: false,
  );
}

({String name, String quantity}) _split(String name, String quantity) {
  if (parseSiriQuantity(quantity) != null) {
    return (name: _cleanName(name), quantity: quantity.trim());
  }
  final source = quantity.trim().isEmpty
      ? name.trim()
      : '${name.trim()}${quantity.trim()}';
  final match = RegExp(r'^(?:食事に|運動に)?(.+?)を\s*(\d.*)$').firstMatch(source);
  if (match == null) {
    return (name: _cleanName(name), quantity: quantity.trim());
  }
  return (name: match.group(1)!.trim(), quantity: match.group(2)!.trim());
}

String _cleanName(String raw) {
  var name = raw.trim();
  if (name.startsWith('食事に')) {
    name = name.substring('食事に'.length);
  } else if (name.startsWith('運動に')) {
    name = name.substring('運動に'.length);
  }
  if (name.endsWith('を')) {
    name = name.substring(0, name.length - 1);
  }
  return name.trim();
}

bool _foodUnitFits(FoodUnitType foodUnit, SiriQuantityUnit spoken) {
  return switch (foodUnit) {
    FoodUnitType.g => spoken == SiriQuantityUnit.grams,
    FoodUnitType.ml => spoken == SiriQuantityUnit.milliliters,
    FoodUnitType.piece => spoken == SiriQuantityUnit.piece,
    FoodUnitType.serving => spoken == SiriQuantityUnit.serving,
  };
}

List<String> _keys(List<String?> texts) {
  final keys = <String>{};
  for (final text in texts) {
    final key = FoodSearchNormalizer.normalize(text);
    if (key.isNotEmpty) {
      keys.add(key);
    }
  }
  return keys.toList();
}

Map<String, Object?> _foodJson(SiriFoodRecord food) {
  return {
    'id': food.id,
    'speakName': food.speakName,
    'keys': food.keys,
    'baseAmount': food.baseAmount,
    'unit': food.unit.storageValue,
    'kcalPerBase': food.kcalPerBase,
    'proteinPerBase': food.proteinPerBase,
    'fatPerBase': food.fatPerBase,
    'carbPerBase': food.carbPerBase,
    'source': food.source.storageValue,
    'savedFoodId': food.savedFoodId,
    'sourceOwnerUserId': food.sourceOwnerUserId,
    'version': food.version,
    'officialFoodCode': food.officialFoodCode,
    'officialFoodName': food.officialFoodName,
  };
}

FoodEntry? _foodEntry(
  Map row, {
  required String id,
  required DateTime loggedAt,
}) {
  final name = _string(row['name']);
  final base = _double(row['baseAmount']);
  final consumed = _double(row['consumedAmount']);
  final unit = FoodUnitTypeX.tryParse(_string(row['unit']));
  if (name == null ||
      base == null ||
      base <= 0 ||
      consumed == null ||
      consumed <= 0 ||
      unit == null) {
    return null;
  }
  final source =
      FoodEntrySourceX.tryParse(_string(row['source'])) ??
      FoodEntrySource.savedFood;
  return FoodEntry(
    id: id,
    name: name,
    kcalPerBase: _double(row['kcalPerBase']),
    proteinPerBase: _double(row['proteinPerBase']),
    fatPerBase: _double(row['fatPerBase']),
    carbPerBase: _double(row['carbPerBase']),
    baseAmount: base,
    unitType: unit,
    consumedAmount: consumed,
    sourceType: source,
    savedFoodId: _string(row['savedFoodId']),
    sourceFoodOwnerUserId: _string(row['sourceOwnerUserId']),
    sourceSavedFoodVersion: row['version'] == null
        ? null
        : _int(row['version']),
    officialFoodCode: _string(row['officialFoodCode']),
    officialFoodName: _string(row['officialFoodName']),
    loggedAt: loggedAt,
  );
}

SiriQuantityUnit? _quantityUnit(String? raw) {
  return switch (raw) {
    'grams' => SiriQuantityUnit.grams,
    'milliliters' => SiriQuantityUnit.milliliters,
    'piece' => SiriQuantityUnit.piece,
    'serving' => SiriQuantityUnit.serving,
    'minutes' => SiriQuantityUnit.minutes,
    'kilometers' => SiriQuantityUnit.kilometers,
    'reps' => SiriQuantityUnit.reps,
    _ => null,
  };
}

DateTime? _loggedAt(Object? raw) {
  final text = _string(raw);
  if (text == null) {
    return null;
  }
  try {
    return parseLockScreenLoggedAt(text);
  } on FormatException {
    return null;
  }
}

String? _string(Object? value) {
  if (value is! String) {
    return null;
  }
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : value;
}

double? _double(Object? value) {
  if (value is num) {
    return value.toDouble();
  }
  return null;
}

int _int(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return 0;
}
