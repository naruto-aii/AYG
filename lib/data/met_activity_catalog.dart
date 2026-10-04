import '../models/calculation/calculation_versions.dart';
import '../models/exercise_category.dart';
import '../models/exercise_entry.dart';
import '../models/exercise_quantity_unit.dart';
import '../utils/food_search_normalizer.dart';
import 'met_intensity_presets.dart';

export 'met_intensity_presets.dart' show MetIntensityOption;

part 'met_activity_entries.dart';

/// 個別 MET 値の出典台帳エントリ。
class MetSourceLedgerEntry {
  const MetSourceLedgerEntry({
    required this.sourceKey,
    required this.citation,
    required this.confirmedOn,
    required this.rightsCategory,
    this.url,
  });

  final String sourceKey;
  final String citation;
  final DateTime confirmedOn;
  final String rightsCategory;
  final String? url;
}

class MetActivityDefinition {
  const MetActivityDefinition({
    required this.id,
    required this.displayName,
    required this.category,
    required this.defaultMet,
    required this.defaultIntensityId,
    required this.sourceKey,
    required this.quantityUnit,
    required this.aliases,
    this.description,
    this.intensityOptions = const [],
    this.searchable = true,
    this.lifestyleIncluded = false,
    this.requiresManualKcal = false,
    this.netKcalPerKgKm,
    this.referenceSpeedKmh,
    this.calorieFormula,
  });

  final String id;
  final String displayName;
  final ExerciseCategory category;
  final double defaultMet;
  final String defaultIntensityId;
  final String sourceKey;
  final String? description;
  final List<MetIntensityOption> intensityOptions;

  /// 入力の単位。カロリー式はこれで決まる。
  final ExerciseQuantityUnit quantityUnit;

  /// 正式名、ひらがな、カタカナ、英語、短い呼び方。種目ごと。
  final List<String> aliases;

  /// 別名検索に出す。その他（手入力）と旧記録用の種目は false。
  final bool searchable;

  /// 生活活動に含まれる。追加消費は 0。
  final bool lifestyleIncluded;

  /// 消費カロリーの式を出典まで特定できない。利用者が kcal を入れる。
  final bool requiresManualKcal;

  /// 安静分を含まない kcal·kg⁻¹·km⁻¹。歩行・走行だけ。
  final double? netKcalPerKgKm;

  /// 距離を分に直す速度（km/h）。標準の強度。自転車はカロリーにも使う。
  /// 歩行のカロリーは [netKcalPerKgKm] で、この速度は分カラム用。
  final double? referenceSpeedKmh;

  /// 自動計算を残す種目の出典と式。手入力の種目は null。
  final String? calorieFormula;

  MetIntensityOption? intensityById(String? id) {
    if (id == null) {
      return null;
    }
    for (final option in intensityOptions) {
      if (option.id == id) {
        return option;
      }
    }
    return null;
  }

  /// 選んだ強度の速度。無ければ種目の標準速度。
  double? speedFor(String? intensityId) {
    return intensityById(intensityId)?.referenceSpeedKmh ?? referenceSpeedKmh;
  }

  MetIntensityOption get defaultIntensity =>
      intensityById(defaultIntensityId) ??
      (intensityOptions.isNotEmpty
          ? intensityOptions.first
          : MetIntensityOption(
              id: 'default',
              label: '標準',
              description: '',
              met: defaultMet,
              sourceKey: sourceKey,
            ));
}

/// 2024 Adult Compendium のコード1件。
class _Code {
  const _Code(this.code, this.met, this.english, {this.mph});

  final String code;
  final double met;
  final String english;

  /// 説明に書いてある速度（mph）。範囲は下限。屋外自転車だけ。
  final double? mph;
}

/// 種目一覧。
///
/// MET は 2024 Adult Compendium of Physical Activities
/// （Herrmann et al., J Sport Health Sci. 2024;13(1):6–12。
/// https://pacompendium.com/ ）。コード番号を [MetActivityDefinition.sourceKey] に残す。
///
/// 同じ MET のコードは画面の強度を一つにする。残すコードは、その種目の標準コードが
/// その MET なら標準、そうでなければ表の先に出たコード。
///
/// 歩行・走行の距離式は ACSM の歩行式・走行式の水平成分。
/// 歩行 0.1 mL·kg⁻¹·m⁻¹ = 0.5 kcal·kg⁻¹·km⁻¹。
/// 走行 0.2 mL·kg⁻¹·m⁻¹ = 1.0 kcal·kg⁻¹·km⁻¹。
/// 1 L の酸素を 5 kcal とする。安静の 3.5 mL·kg⁻¹·min⁻¹ は入れない。
/// ジョギングも走行と同じ水平成分。この MET は消費に使わない。
///
/// 屋外の自転車は、選んだコードの説明にある速度（範囲は下限）で距離を分に直し、
/// 追加消費 kcal = (MET − 1) × 3.5 × 体重kg ÷ 200 × 分。
/// 標準はコード 01020 の下限 10 mph = 16.09344 km/h。
///
/// 競歩、ノルディックウォーキング、スケート、カヌーは距離ではなく分と MET。
class MetActivityCatalog {
  MetActivityCatalog._();

  static const calculationVersion = CalculationVersions.exerciseMet;
  static const lastUpdated = '2026-10-04';

  static const herrmann2024Doi = '10.1016/j.jshs.2023.10.010';

  static const _mphToKmh = 1.609344;

  static final ledger = <MetSourceLedgerEntry>[
    MetSourceLedgerEntry(
      sourceKey: 'herrmann2024_compendium',
      citation:
          'Herrmann SD, Willis EA, Ainsworth BE, et al. 2024 Adult Compendium '
          'of Physical Activities. J Sport Health Sci. 2024;13(1):6–12. '
          'DOI: 10.1016/j.jshs.2023.10.010',
      confirmedOn: DateTime(2026, 10, 4),
      rightsCategory: 'bibliographicCitation',
      url: 'https://doi.org/10.1016/j.jshs.2023.10.010',
    ),
    MetSourceLedgerEntry(
      sourceKey: 'pacompendium_met_definition',
      citation:
          'Compendium of Physical Activities — Definition of MET '
          '(https://pacompendium.com/)。1 MET = 1 kcal·kg⁻¹·h⁻¹。',
      confirmedOn: DateTime(2026, 10, 4),
      rightsCategory: 'formulaOrTheory',
      url: 'https://pacompendium.com/',
    ),
    MetSourceLedgerEntry(
      sourceKey: 'acsm_walk_run_distance',
      citation:
          'American College of Sports Medicine. ACSM\'s Guidelines for '
          'Exercise Testing and Prescription. Level walking '
          'VO2 = 0.1 × speed(m/min) + 3.5. Level running '
          'VO2 = 0.2 × speed(m/min) + 3.5. '
          '水平成分だけを 1 km と 5 kcal/L で直すと、歩行 0.5、走行 1.0 '
          'kcal·kg⁻¹·km⁻¹（安静分を含まない）。',
      confirmedOn: DateTime(2026, 10, 4),
      rightsCategory: 'formulaOrTheory',
      url: 'https://www.acsm.org/',
    ),
  ];

  static final activities = _activityDefinitions;

  static const _legacyIds = <String, String>{
    'run_jog': 'running',
    'run_moderate': 'running',
    'strength_vigorous': 'strength_general',
    'strength_machine': 'strength_general',
  };

  static MetActivityDefinition? findById(String? id) {
    if (id == null) {
      return null;
    }
    final resolved = _legacyIds[id] ?? id;
    for (final activity in activities) {
      if (activity.id == resolved) {
        return activity;
      }
    }
    return null;
  }

  static List<MetActivityDefinition> byCategory(ExerciseCategory category) {
    return activities
        .where((activity) => activity.category == category)
        .toList();
  }

  /// 検索欄が空のときに出す種目。別名検索の対象だけ。その他（手入力）は含まない。
  static List<MetActivityDefinition> get listed {
    final items = activities.where((activity) => activity.searchable).toList();
    items.sort((a, b) => a.displayName.compareTo(b.displayName));
    return items;
  }

  /// 検索語が別名と一致する種目を先に返す。
  /// 一致が無いときだけ、別名が検索語で始まる種目を返す。
  /// 一致があるときは、それに加えて表示名が検索語で始まる種目だけを足す。
  /// 長い別名の途中に検索語が含まれるだけの種目は出さない。
  static List<MetActivityDefinition> search(String query) {
    final normalizedQuery = FoodSearchNormalizer.normalize(query);
    if (normalizedQuery.isEmpty) {
      return const [];
    }
    final searchable = activities.where((activity) => activity.searchable);
    final exact = <MetActivityDefinition>[];
    final prefix = <MetActivityDefinition>[];
    for (final activity in searchable) {
      if (_aliasEquals(activity, normalizedQuery)) {
        exact.add(activity);
      }
      if (_aliasStartsWith(activity, normalizedQuery)) {
        prefix.add(activity);
      }
    }
    final hits = <MetActivityDefinition>[];
    final seen = <String>{};
    if (exact.isEmpty) {
      for (final activity in prefix) {
        if (seen.add(activity.id)) {
          hits.add(activity);
        }
      }
    } else {
      for (final activity in exact) {
        if (seen.add(activity.id)) {
          hits.add(activity);
        }
      }
      for (final activity in prefix) {
        if (_displayNameStartsWith(activity, normalizedQuery) &&
            seen.add(activity.id)) {
          hits.add(activity);
        }
      }
    }
    hits.sort((a, b) => a.displayName.compareTo(b.displayName));
    return hits;
  }

  static bool _aliasEquals(MetActivityDefinition activity, String query) {
    for (final alias in activity.aliases) {
      final normalized = FoodSearchNormalizer.normalize(alias);
      if (normalized.isNotEmpty && normalized == query) {
        return true;
      }
    }
    return false;
  }

  static bool _aliasStartsWith(MetActivityDefinition activity, String query) {
    for (final alias in activity.aliases) {
      final normalized = FoodSearchNormalizer.normalize(alias);
      if (normalized.isNotEmpty && normalized.startsWith(query)) {
        return true;
      }
    }
    return false;
  }

  static bool _displayNameStartsWith(
    MetActivityDefinition activity,
    String query,
  ) {
    final name = FoodSearchNormalizer.normalize(activity.displayName);
    return name.isNotEmpty && name.startsWith(query);
  }

  static String quantityLabelFor(ExerciseEntry entry) {
    final unit =
        findById(entry.activityId)?.quantityUnit ??
        ExerciseQuantityUnit.durationMin;
    switch (unit) {
      case ExerciseQuantityUnit.distanceKm:
        final km = entry.distanceKm;
        if (km != null && km > 0) {
          final text = km == km.roundToDouble()
              ? km.toStringAsFixed(0)
              : km.toStringAsFixed(1);
          return '$text km';
        }
        return '${entry.durationMin} 分';
      case ExerciseQuantityUnit.reps:
        final reps = entry.reps;
        if (reps != null && reps > 0) {
          return '$reps 回';
        }
        return '${entry.durationMin} 分';
      case ExerciseQuantityUnit.durationMin:
        return '${entry.durationMin} 分';
    }
  }

  /// 出典と式が特定でき、自動計算を残す種目。
  static List<MetActivityDefinition> get automaticCalorieActivities {
    return activities
        .where((activity) => activity.calorieFormula != null)
        .toList();
  }

  /// 消費カロリーを利用者が入れる種目。
  static List<MetActivityDefinition> get manualCalorieActivities {
    return activities.where((activity) => activity.requiresManualKcal).toList();
  }

  static List<ExerciseCategory> get selectableCategories => [
    ExerciseCategory.aerobic,
    ExerciseCategory.strength,
    ExerciseCategory.sport,
    ExerciseCategory.dailyActivity,
    ExerciseCategory.other,
  ];

  static double _kmh(double mph) {
    if (mph == 10) {
      return 16.09344;
    }
    return mph * _mphToKmh;
  }

  /// 括弧の外にある最初の読点より後ろ。強度の見分けに使う。
  static String _intensityLabel(String english) {
    var depth = 0;
    for (var i = 0; i < english.length; i++) {
      final ch = english[i];
      if (ch == '(') {
        depth++;
      } else if (ch == ')' && depth > 0) {
        depth--;
      } else if (ch == ',' && depth == 0) {
        final rest = english.substring(i + 1).trim();
        if (rest.isNotEmpty) {
          return rest;
        }
      }
    }
    return english;
  }

  static List<_Code> _uniqueMets(List<_Code> codes, String defaultCode) {
    final chosen = <double, _Code>{};
    for (final code in codes) {
      final current = chosen[code.met];
      if (current == null || code.code == defaultCode) {
        chosen[code.met] = code;
      }
    }
    final seen = <double>{};
    final result = <_Code>[];
    for (final code in codes) {
      if (seen.add(code.met)) {
        result.add(chosen[code.met]!);
      }
    }
    return result;
  }

  static MetActivityDefinition _define({
    required String id,
    required String displayName,
    required ExerciseCategory category,
    required List<_Code> codes,
    String? defaultCode,
    ExerciseQuantityUnit quantityUnit = ExerciseQuantityUnit.durationMin,
    double? netKcalPerKgKm,
    double? referenceSpeedKmh,
    bool lifestyleIncluded = false,
    List<String> aliases = const [],
    String? formulaPrefix,
  }) {
    final fallback = defaultCode ?? codes.first.code;
    final unique = _uniqueMets(codes, fallback);
    final labelCounts = <String, int>{};
    for (final code in unique) {
      final label = _intensityLabel(code.english);
      labelCounts[label] = (labelCounts[label] ?? 0) + 1;
    }
    final options = <MetIntensityOption>[
      for (final code in unique)
        MetIntensityOption(
          id: code.code,
          label: (labelCounts[_intensityLabel(code.english)] ?? 0) > 1
              ? '${_intensityLabel(code.english)} · ${code.code}'
              : _intensityLabel(code.english),
          description: code.english,
          met: code.met,
          sourceKey: 'compendium_2024_${code.code}',
          referenceSpeedKmh: code.mph == null ? null : _kmh(code.mph!),
        ),
    ];
    MetIntensityOption? standard;
    for (final option in options) {
      if (option.id == fallback) {
        standard = option;
        break;
      }
    }
    if (standard == null) {
      throw StateError('$id の標準コード $fallback が強度に無い');
    }
    final speed = standard.referenceSpeedKmh ?? referenceSpeedKmh;
    return MetActivityDefinition(
      id: id,
      displayName: displayName,
      category: category,
      defaultMet: standard.met,
      defaultIntensityId: standard.id,
      sourceKey: standard.sourceKey,
      description: standard.description,
      quantityUnit: quantityUnit,
      aliases: _aliases(displayName, aliases),
      lifestyleIncluded: lifestyleIncluded,
      netKcalPerKgKm: netKcalPerKgKm,
      referenceSpeedKmh: speed,
      calorieFormula: lifestyleIncluded
          ? null
          : _formula(
              quantityUnit: quantityUnit,
              netKcalPerKgKm: netKcalPerKgKm,
              options: options,
              standard: standard,
              prefix: formulaPrefix,
            ),
      intensityOptions: options,
    );
  }

  static String _formula({
    required ExerciseQuantityUnit quantityUnit,
    required double? netKcalPerKgKm,
    required List<MetIntensityOption> options,
    required MetIntensityOption standard,
    required String? prefix,
  }) {
    final lines = options
        .map((option) {
          final speed = option.referenceSpeedKmh;
          final speedText = speed == null
              ? ''
              : '、速度 ${speed.toStringAsFixed(5)} km/h';
          return '${option.id} / ${option.met} / ${option.description}$speedText';
        })
        .join('\n');
    final head = prefix ?? '';
    if (quantityUnit == ExerciseQuantityUnit.distanceKm &&
        netKcalPerKgKm != null) {
      return '追加消費 kcal = $netKcalPerKgKm × 体重kg × 距離km。'
          'MET は消費に使わない。'
          'コード ${standard.id}、${standard.met} MET、${standard.description}。'
          '$head\n$lines';
    }
    if (quantityUnit == ExerciseQuantityUnit.distanceKm) {
      return '分 = 距離km ÷ 速度km/h × 60。'
          '速度は選んだコードの説明にある mph で、範囲は下限。1 mph = 1.609344 km/h。'
          '標準はコード ${standard.id}、${standard.met} MET、'
          '${standard.referenceSpeedKmh} km/h、${standard.description}。'
          '追加消費 kcal = (MET − 1) × 3.5 × 体重kg ÷ 200 × 分。'
          '$head\n$lines';
    }
    final choice = options.length > 1 ? '強度が複数あるときは、選んだコードの MET を使う。' : '';
    return '追加消費 kcal = (MET − 1) × 3.5 × 体重kg ÷ 200 × 分。'
        '標準はコード ${standard.id}、${standard.met} MET、${standard.description}。'
        '$choice$head\n$lines';
  }

  static List<String> _aliases(String displayName, List<String> extra) {
    final seen = <String>{};
    final result = <String>[];
    for (final raw in [displayName, ...extra]) {
      final value = raw.trim();
      if (value.isEmpty || !seen.add(value)) {
        continue;
      }
      result.add(value);
    }
    return result;
  }
}
