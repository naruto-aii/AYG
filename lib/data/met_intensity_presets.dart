import '../models/exercise_category.dart';

/// 主観的強度と内部 MET の対応（画面に直書きしない）。
class MetIntensityPresets {
  MetIntensityPresets._();

  static const strengthOptions = [
    MetIntensityOption(
      id: 'light',
      label: '軽め',
      description: 'フォーム練習、軽い重量、余裕を持って続けられる',
      met: 3.5,
      sourceKey: 'weight_training_light_3_5',
    ),
    MetIntensityOption(
      id: 'moderate',
      label: 'ふつう',
      description: '適度にきついが、まだ数回は続けられる',
      met: 5.0,
      sourceKey: 'weight_training_moderate_5_0',
    ),
    MetIntensityOption(
      id: 'hard',
      label: 'きつい',
      description: '高重量や短い休憩で、かなりきつい',
      met: 6.0,
      sourceKey: 'weight_training_vigorous_6_0',
    ),
  ];

  static const aerobicOptions = [
    MetIntensityOption(
      id: 'easy',
      label: 'ゆっくり',
      description: '会話を楽に続けられる',
      met: 3.5,
      sourceKey: 'aerobic_easy_3_5',
    ),
    MetIntensityOption(
      id: 'moderate',
      label: 'ほどよい',
      description: '会話はできるが少し息が弾む',
      met: 5.0,
      sourceKey: 'aerobic_moderate_5_0',
    ),
    MetIntensityOption(
      id: 'hard',
      label: 'きつい',
      description: '短い言葉しか話せない',
      met: 7.0,
      sourceKey: 'aerobic_hard_7_0',
    ),
  ];

  static const sportOptions = [
    MetIntensityOption(
      id: 'light',
      label: '軽め',
      description: '練習・ウォームアップ中心',
      met: 4.0,
      sourceKey: 'sport_light_4_0',
    ),
    MetIntensityOption(
      id: 'moderate',
      label: 'ふつう',
      description: '試合や本格的な練習',
      met: 6.5,
      sourceKey: 'sport_moderate_6_5',
    ),
    MetIntensityOption(
      id: 'hard',
      label: 'きつい',
      description: '高強度の試合・インターバル',
      met: 8.0,
      sourceKey: 'sport_hard_8_0',
    ),
  ];

  static const dailyActivityOptions = [
    MetIntensityOption(
      id: 'light',
      label: '軽め',
      description: 'ゆったりした動き',
      met: 2.5,
      sourceKey: 'daily_light_2_5',
    ),
    MetIntensityOption(
      id: 'moderate',
      label: 'ふつう',
      description: '少し息が上がる程度',
      met: 3.5,
      sourceKey: 'daily_moderate_3_5',
    ),
  ];

  static List<MetIntensityOption> forCategory(ExerciseCategory category) {
    return switch (category) {
      ExerciseCategory.strength => strengthOptions,
      ExerciseCategory.aerobic => aerobicOptions,
      ExerciseCategory.sport => sportOptions,
      ExerciseCategory.dailyActivity => dailyActivityOptions,
      ExerciseCategory.other => const [],
    };
  }
}

/// カタログ内の強度定義（[MetActivityCatalog] と共有）。
class MetIntensityOption {
  const MetIntensityOption({
    required this.id,
    required this.label,
    required this.description,
    required this.met,
    required this.sourceKey,
  });

  final String id;
  final String label;
  final String description;
  final double met;
  final String sourceKey;
}
