import '../models/exercise_category.dart';

/// 個別 MET 値の出典台帳エントリ。
class MetSourceLedgerEntry {
  const MetSourceLedgerEntry({
    required this.sourceKey,
    required this.citation,
    required this.confirmedOn,
    required this.rightsCategory,
  });

  final String sourceKey;
  final String citation;
  final DateTime confirmedOn;

  /// bibliographicCitation | formulaOrTheory | selectedFactualParameter
  final String rightsCategory;
}

/// アプリ独自の運動候補（Compendium 表の転載なし）。
class MetActivityDefinition {
  const MetActivityDefinition({
    required this.id,
    required this.displayName,
    required this.category,
    required this.defaultMet,
    required this.sourceKey,
    this.description,
    this.intensityOptions = const [],
  });

  final String id;
  final String displayName;
  final ExerciseCategory category;
  final double defaultMet;
  final String sourceKey;
  final String? description;

  /// 強度ラベル → MET の対応（空なら defaultMet のみ）。
  final List<MetIntensityOption> intensityOptions;
}

class MetIntensityOption {
  const MetIntensityOption({
    required this.label,
    required this.met,
    required this.sourceKey,
  });

  final String label;
  final double met;
  final String sourceKey;
}

/// 初期収録の代表運動カタログ。
class MetActivityCatalog {
  MetActivityCatalog._();

  static const calculationVersion = 'met-v1';
  static const lastUpdated = '2026-07-28';

  static const herrmann2024Doi = '10.1016/j.jshs.2023.10.010';

  static final ledger = <MetSourceLedgerEntry>[
    MetSourceLedgerEntry(
      sourceKey: 'herrmann2024_compendium',
      citation:
          'Herrmann SD, Willis EA, Ainsworth BE, et al. 2024 Adult Compendium '
          'of Physical Activities. J Sport Health Sci. 2024;13(1):6–12. '
          'DOI: $herrmann2024Doi',
      confirmedOn: DateTime(2026, 7, 28),
      rightsCategory: 'bibliographicCitation',
    ),
    MetSourceLedgerEntry(
      sourceKey: 'pacompendium_met_definition',
      citation:
          'Compendium of Physical Activities — Definition of MET '
          '(https://pacompendium.com/)',
      confirmedOn: DateTime(2026, 7, 28),
      rightsCategory: 'formulaOrTheory',
    ),
    MetSourceLedgerEntry(
      sourceKey: 'walking_moderate_3_5',
      citation: 'Walking 3.5 mph, level — selected MET 3.5 (Herrmann 2024)',
      confirmedOn: DateTime(2026, 7, 28),
      rightsCategory: 'selectedFactualParameter',
    ),
    MetSourceLedgerEntry(
      sourceKey: 'running_6mph_9_8',
      citation: 'Running 6 mph — selected MET 9.8 (Herrmann 2024)',
      confirmedOn: DateTime(2026, 7, 28),
      rightsCategory: 'selectedFactualParameter',
    ),
    MetSourceLedgerEntry(
      sourceKey: 'cycling_moderate_6_8',
      citation: 'Bicycling 12–13.9 mph — selected MET 8.0 (Herrmann 2024)',
      confirmedOn: DateTime(2026, 7, 28),
      rightsCategory: 'selectedFactualParameter',
    ),
    MetSourceLedgerEntry(
      sourceKey: 'weight_training_vigorous_6_0',
      citation: 'Weight lifting vigorous — selected MET 6.0 (Herrmann 2024)',
      confirmedOn: DateTime(2026, 7, 28),
      rightsCategory: 'selectedFactualParameter',
    ),
    MetSourceLedgerEntry(
      sourceKey: 'swimming_moderate_5_8',
      citation: 'Swimming moderate — selected MET 5.8 (Herrmann 2024)',
      confirmedOn: DateTime(2026, 7, 28),
      rightsCategory: 'selectedFactualParameter',
    ),
    MetSourceLedgerEntry(
      sourceKey: 'yoga_hatha_2_5',
      citation: 'Yoga Hatha — selected MET 2.5 (Herrmann 2024)',
      confirmedOn: DateTime(2026, 7, 28),
      rightsCategory: 'selectedFactualParameter',
    ),
    MetSourceLedgerEntry(
      sourceKey: 'basketball_game_6_5',
      citation: 'Basketball game — selected MET 6.5 (Herrmann 2024)',
      confirmedOn: DateTime(2026, 7, 28),
      rightsCategory: 'selectedFactualParameter',
    ),
  ];

  static const activities = <MetActivityDefinition>[
    MetActivityDefinition(
      id: 'walk_brisk',
      displayName: 'ウォーキング（速歩）',
      category: ExerciseCategory.aerobic,
      defaultMet: 3.5,
      sourceKey: 'walking_moderate_3_5',
      description: '平地での速歩',
    ),
    MetActivityDefinition(
      id: 'run_moderate',
      displayName: 'ランニング（中程度）',
      category: ExerciseCategory.aerobic,
      defaultMet: 9.8,
      sourceKey: 'running_6mph_9_8',
      description: '時速約10km前後のジョギング',
    ),
    MetActivityDefinition(
      id: 'cycle_road',
      displayName: '自転車（ロード）',
      category: ExerciseCategory.aerobic,
      defaultMet: 8.0,
      sourceKey: 'cycling_moderate_6_8',
      description: '平地〜緩やかな坂のサイクリング',
    ),
    MetActivityDefinition(
      id: 'swim_lap',
      displayName: '水泳（泳ぎ）',
      category: ExerciseCategory.aerobic,
      defaultMet: 5.8,
      sourceKey: 'swimming_moderate_5_8',
    ),
    MetActivityDefinition(
      id: 'strength_vigorous',
      displayName: '筋トレ（高強度）',
      category: ExerciseCategory.strength,
      defaultMet: 6.0,
      sourceKey: 'weight_training_vigorous_6_0',
      description: 'セット間休憩を含む全体時間で記録',
      intensityOptions: [
        MetIntensityOption(
          label: '中程度',
          met: 3.5,
          sourceKey: 'weight_training_vigorous_6_0',
        ),
        MetIntensityOption(
          label: '高強度',
          met: 6.0,
          sourceKey: 'weight_training_vigorous_6_0',
        ),
      ],
    ),
    MetActivityDefinition(
      id: 'basketball',
      displayName: 'バスケットボール',
      category: ExerciseCategory.sport,
      defaultMet: 6.5,
      sourceKey: 'basketball_game_6_5',
    ),
    MetActivityDefinition(
      id: 'yoga',
      displayName: 'ヨガ',
      category: ExerciseCategory.flexibility,
      defaultMet: 2.5,
      sourceKey: 'yoga_hatha_2_5',
    ),
    MetActivityDefinition(
      id: 'custom',
      displayName: 'その他（手入力）',
      category: ExerciseCategory.other,
      defaultMet: 3.0,
      sourceKey: 'pacompendium_met_definition',
    ),
  ];

  static MetActivityDefinition? findById(String? id) {
    if (id == null) {
      return null;
    }
    for (final activity in activities) {
      if (activity.id == id) {
        return activity;
      }
    }
    return null;
  }

  static List<MetActivityDefinition> byCategory(ExerciseCategory category) {
    return activities.where((a) => a.category == category).toList();
  }
}
