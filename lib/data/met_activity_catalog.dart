import '../models/calculation/calculation_versions.dart';
import '../models/exercise_category.dart';
import 'met_intensity_presets.dart';

export 'met_intensity_presets.dart' show MetIntensityOption;

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
  final String rightsCategory;
}

class MetActivityDefinition {
  const MetActivityDefinition({
    required this.id,
    required this.displayName,
    required this.category,
    required this.defaultMet,
    required this.defaultIntensityId,
    required this.sourceKey,
    this.description,
    this.intensityOptions = const [],
  });

  final String id;
  final String displayName;
  final ExerciseCategory category;
  final double defaultMet;
  final String defaultIntensityId;
  final String sourceKey;
  final String? description;
  final List<MetIntensityOption> intensityOptions;

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

class MetActivityCatalog {
  MetActivityCatalog._();

  static const calculationVersion = CalculationVersions.exerciseMet;
  static const lastUpdated = '2026-08-02';

  static const herrmann2024Doi = '10.1016/j.jshs.2023.10.010';

  static final ledger = <MetSourceLedgerEntry>[
    MetSourceLedgerEntry(
      sourceKey: 'herrmann2024_compendium',
      citation:
          'Herrmann SD, Willis EA, Ainsworth BE, et al. 2024 Adult Compendium '
          'of Physical Activities. J Sport Health Sci. 2024;13(1):6–12. '
          'DOI: 10.1016/j.jshs.2023.10.010',
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
  ];

  static final activities = <MetActivityDefinition>[
    MetActivityDefinition(
      id: 'walk_brisk',
      displayName: 'ウォーキング',
      category: ExerciseCategory.aerobic,
      defaultMet: 3.5,
      defaultIntensityId: 'moderate',
      sourceKey: 'walking_moderate_3_5',
      description: '平地でのウォーキング',
      intensityOptions: [
        MetIntensityOption(
          id: 'easy',
          label: 'ゆっくり',
          description: '会話を楽に続けられる',
          met: 2.8,
          sourceKey: 'walking_easy_2_8',
        ),
        MetIntensityOption(
          id: 'moderate',
          label: 'ほどよい',
          description: '会話はできるが少し息が弾む',
          met: 3.5,
          sourceKey: 'walking_moderate_3_5',
        ),
        MetIntensityOption(
          id: 'hard',
          label: 'きつい',
          description: '短い言葉しか話せない',
          met: 4.5,
          sourceKey: 'walking_hard_4_5',
        ),
      ],
    ),
    MetActivityDefinition(
      id: 'run_jog',
      displayName: 'ランニング・ジョギング',
      category: ExerciseCategory.aerobic,
      defaultMet: 7.0,
      defaultIntensityId: 'moderate',
      sourceKey: 'running_moderate_7_0',
      intensityOptions: [
        MetIntensityOption(
          id: 'easy',
          label: 'ゆっくり',
          description: '会話を楽に続けられる',
          met: 6.0,
          sourceKey: 'running_easy_6_0',
        ),
        MetIntensityOption(
          id: 'moderate',
          label: 'ほどよい',
          description: '会話はできるが少し息が弾む',
          met: 8.0,
          sourceKey: 'running_moderate_8_0',
        ),
        MetIntensityOption(
          id: 'hard',
          label: 'きつい',
          description: '短い言葉しか話せない',
          met: 10.0,
          sourceKey: 'running_hard_10_0',
        ),
      ],
    ),
    MetActivityDefinition(
      id: 'cycle_road',
      displayName: '自転車',
      category: ExerciseCategory.aerobic,
      defaultMet: 6.0,
      defaultIntensityId: 'moderate',
      sourceKey: 'cycling_moderate_6_0',
      intensityOptions: const [
        MetIntensityOption(
          id: 'easy',
          label: 'ゆっくり',
          description: '会話を楽に続けられる',
          met: 4.0,
          sourceKey: 'cycling_easy',
        ),
        MetIntensityOption(
          id: 'moderate',
          label: 'ほどよい',
          description: '会話はできるが少し息が弾む',
          met: 6.0,
          sourceKey: 'cycling_moderate',
        ),
        MetIntensityOption(
          id: 'hard',
          label: 'きつい',
          description: '短い言葉しか話せない',
          met: 8.0,
          sourceKey: 'cycling_hard',
        ),
      ],
    ),
    MetActivityDefinition(
      id: 'swim_lap',
      displayName: '水泳',
      category: ExerciseCategory.aerobic,
      defaultMet: 5.8,
      defaultIntensityId: 'moderate',
      sourceKey: 'swimming_moderate_5_8',
      intensityOptions: const [
        MetIntensityOption(
          id: 'easy',
          label: 'ゆっくり',
          description: '会話を楽に続けられる',
          met: 4.5,
          sourceKey: 'swimming_easy',
        ),
        MetIntensityOption(
          id: 'moderate',
          label: 'ほどよい',
          description: '会話はできるが少し息が弾む',
          met: 5.8,
          sourceKey: 'swimming_moderate',
        ),
        MetIntensityOption(
          id: 'hard',
          label: 'きつい',
          description: '短い言葉しか話せない',
          met: 7.5,
          sourceKey: 'swimming_hard',
        ),
      ],
    ),
    MetActivityDefinition(
      id: 'strength_general',
      displayName: '筋力トレーニング（総合）',
      category: ExerciseCategory.strength,
      defaultMet: 5.0,
      defaultIntensityId: 'moderate',
      sourceKey: 'weight_training_moderate_5_0',
      description: 'セット間休憩を含む全体時間で記録',
      intensityOptions: MetIntensityPresets.strengthOptions,
    ),
    MetActivityDefinition(
      id: 'strength_machine',
      displayName: 'マシントレーニング',
      category: ExerciseCategory.strength,
      defaultMet: 5.0,
      defaultIntensityId: 'moderate',
      sourceKey: 'weight_training_moderate_5_0',
      intensityOptions: MetIntensityPresets.strengthOptions,
    ),
    MetActivityDefinition(
      id: 'basketball',
      displayName: 'バスケットボール',
      category: ExerciseCategory.sport,
      defaultMet: 6.5,
      defaultIntensityId: 'moderate',
      sourceKey: 'basketball_game_6_5',
      intensityOptions: MetIntensityPresets.sportOptions,
    ),
    MetActivityDefinition(
      id: 'yoga',
      displayName: 'ヨガ・ストレッチ',
      category: ExerciseCategory.dailyActivity,
      defaultMet: 2.5,
      defaultIntensityId: 'light',
      sourceKey: 'yoga_hatha_2_5',
      intensityOptions: MetIntensityPresets.dailyActivityOptions,
    ),
    MetActivityDefinition(
      id: 'housework',
      displayName: '家事・掃除',
      category: ExerciseCategory.dailyActivity,
      defaultMet: 3.0,
      defaultIntensityId: 'moderate',
      sourceKey: 'daily_moderate_3_0',
      intensityOptions: MetIntensityPresets.dailyActivityOptions,
    ),
    MetActivityDefinition(
      id: 'custom',
      displayName: 'その他（手入力）',
      category: ExerciseCategory.other,
      defaultMet: 3.0,
      defaultIntensityId: 'default',
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
      if (id == 'strength_vigorous' && activity.id == 'strength_general') {
        return activity;
      }
      if (id == 'run_moderate' && activity.id == 'run_jog') {
        return activity;
      }
    }
    return null;
  }

  static List<MetActivityDefinition> byCategory(ExerciseCategory category) {
    return activities.where((a) => a.category == category).toList();
  }

  static List<ExerciseCategory> get selectableCategories => [
    ExerciseCategory.aerobic,
    ExerciseCategory.strength,
    ExerciseCategory.sport,
    ExerciseCategory.dailyActivity,
    ExerciseCategory.other,
  ];
}
