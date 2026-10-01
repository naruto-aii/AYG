import '../models/calculation/calculation_versions.dart';
import '../models/exercise_category.dart';
import '../models/exercise_entry.dart';
import '../models/exercise_quantity_unit.dart';
import '../utils/food_search_normalizer.dart';
import 'met_intensity_presets.dart';

export 'met_intensity_presets.dart' show MetIntensityOption;

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

  /// 距離を分に直す速度（km/h）。自転車はカロリーにも使う。
  /// 歩行・走行のカロリーは [netKcalPerKgKm] で、この速度は分カラム用。
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

/// 種目一覧。
///
/// MET は 2024 Adult Compendium of Physical Activities
/// （Herrmann et al., J Sport Health Sci. 2024;13(1):6–12。
/// https://pacompendium.com/ ）。コード番号を [MetActivityDefinition.sourceKey] に残す。
/// コンペンディウムが種目を分けていないものは、同じコードの MET を個別の名前で使う。
///
/// 歩行・走行の距離式は ACSM の歩行式・走行式の水平成分。
/// 歩行 0.1 mL·kg⁻¹·m⁻¹ = 0.5 kcal·kg⁻¹·km⁻¹。
/// 走行 0.2 mL·kg⁻¹·m⁻¹ = 1.0 kcal·kg⁻¹·km⁻¹。
/// 1 L の酸素を 5 kcal とする。安静の 3.5 mL·kg⁻¹·min⁻¹ は入れない。
/// ジョギングも走行と同じ水平成分（1 km あたりのこの項は速度で変わらない）。
///
/// 自転車はコード 01020（10–11.9 mph、6.8 MET）の下限 10 mph = 16.09344 km/h で
/// 距離を分に直し、既存の MET 式（MET × 3.5 × 体重 / 200 × 分）にかける。
///
/// 回数の種目は、1回の秒数をカロリーの式として特定できないので自動計算しない。
/// ベンチプレスは単独のコードが無く、その他と旧記録の筋トレは公表 MET が無い。
class MetActivityCatalog {
  MetActivityCatalog._();

  static const calculationVersion = CalculationVersions.exerciseMet;
  static const lastUpdated = '2026-10-01';

  static const herrmann2024Doi = '10.1016/j.jshs.2023.10.010';

  static const _standard = 'standard';

  static final ledger = <MetSourceLedgerEntry>[
    MetSourceLedgerEntry(
      sourceKey: 'herrmann2024_compendium',
      citation:
          'Herrmann SD, Willis EA, Ainsworth BE, et al. 2024 Adult Compendium '
          'of Physical Activities. J Sport Health Sci. 2024;13(1):6–12. '
          'DOI: 10.1016/j.jshs.2023.10.010',
      confirmedOn: DateTime(2026, 9, 30),
      rightsCategory: 'bibliographicCitation',
      url: 'https://doi.org/10.1016/j.jshs.2023.10.010',
    ),
    MetSourceLedgerEntry(
      sourceKey: 'pacompendium_met_definition',
      citation:
          'Compendium of Physical Activities — Definition of MET '
          '(https://pacompendium.com/)。1 MET = 1 kcal·kg⁻¹·h⁻¹。',
      confirmedOn: DateTime(2026, 9, 30),
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
      confirmedOn: DateTime(2026, 9, 30),
      rightsCategory: 'formulaOrTheory',
      url: 'https://www.acsm.org/',
    ),
  ];

  static final activities = <MetActivityDefinition>[
    _distanceFactor(
      id: 'walk_brisk',
      displayName: 'ウォーキング',
      category: ExerciseCategory.aerobic,
      met: 3.8,
      sourceKey: 'compendium_2024_17190',
      description:
          'コード 17190 Walking, 2.8 to 3.4 mph, level, moderate pace。'
          '消費は MET ではなく 0.5 kcal·kg⁻¹·km⁻¹。'
          '分カラム用の速度は範囲内の 3 mph（4.828 km/h）。',
      netKcalPerKgKm: 0.5,
      referenceSpeedKmh: 4.828032,
      calorieFormula:
          '追加消費 kcal = 0.5 × 体重kg × 距離km。'
          'ACSM 歩行式 VO2 (mL·kg⁻¹·min⁻¹) = 0.1 × 速度(m/min) + 3.5 の水平成分 '
          '0.1 mL·kg⁻¹·m⁻¹ を、1 L の酸素 = 5 kcal で 1 km にすると 0.5 kcal·kg⁻¹·km⁻¹。'
          '安静の 3.5 は入れない。'
          '種目の対応は 2024 Adult Compendium コード 17190（3.8 MET）。この MET は消費に使わない。'
          '分カラムの速度 3 mph（4.828 km/h）は 2.8–3.4 mph の範囲内で、消費の式には入らない。',
      aliases: const [
        'うぉーきんぐ',
        '歩き',
        'あるき',
        '歩く',
        'あるく',
        'ウォーク',
        'うぉーく',
        'walk',
        'walking',
      ],
    ),
    _distanceFactor(
      id: 'jogging',
      displayName: 'ジョギング',
      category: ExerciseCategory.aerobic,
      met: 7.5,
      sourceKey: 'compendium_2024_12020',
      description: 'コード 12020 Jogging, general。消費は走行と同じ 1.0 kcal·kg⁻¹·km⁻¹。',
      netKcalPerKgKm: 1.0,
      calorieFormula:
          '追加消費 kcal = 1.0 × 体重kg × 距離km。'
          'ACSM 走行式 VO2 (mL·kg⁻¹·min⁻¹) = 0.2 × 速度(m/min) + 3.5 の水平成分 '
          '0.2 mL·kg⁻¹·m⁻¹ を、1 L の酸素 = 5 kcal で 1 km にすると 1.0 kcal·kg⁻¹·km⁻¹。'
          'この水平成分は速度で変わらない。安静の 3.5 は入れない。'
          '種目の対応は 2024 Adult Compendium コード 12020 Jogging, general（7.5 MET）。'
          'この MET は消費に使わない。',
      aliases: const ['じょぎんぐ', 'ジョグ', 'じょぐ', 'jog', 'jogging'],
    ),
    _distanceFactor(
      id: 'running',
      displayName: 'ランニング',
      category: ExerciseCategory.aerobic,
      met: 8.0,
      sourceKey: 'compendium_2024_12150',
      description: 'コード 12150 Running。消費は 1.0 kcal·kg⁻¹·km⁻¹。',
      netKcalPerKgKm: 1.0,
      calorieFormula:
          '追加消費 kcal = 1.0 × 体重kg × 距離km。'
          'ACSM 走行式 VO2 (mL·kg⁻¹·min⁻¹) = 0.2 × 速度(m/min) + 3.5 の水平成分 '
          '0.2 mL·kg⁻¹·m⁻¹ を、1 L の酸素 = 5 kcal で 1 km にすると 1.0 kcal·kg⁻¹·km⁻¹。'
          '安静の 3.5 は入れない。'
          '種目の対応は 2024 Adult Compendium コード 12150 Running（8.0 MET）。'
          'この MET は消費に使わない。',
      aliases: const ['らんにんぐ', 'らん', 'ラン', '走り', 'はしり', 'run', 'running'],
    ),
    _distanceSpeed(
      id: 'cycle_road',
      displayName: '自転車',
      category: ExerciseCategory.aerobic,
      met: 6.8,
      sourceKey: 'compendium_2024_01020',
      description:
          'コード 01020 Bicycling, 10-11.9 mph, leisure, 6.8 MET。'
          '距離は下限 10 mph（16.09344 km/h）で分に直す。',
      referenceSpeedKmh: 16.09344,
      calorieFormula:
          '分 = 距離km ÷ 16.09344 × 60。'
          '16.09344 km/h はコード 01020（10–11.9 mph、6.8 MET）の下限 10 mph。'
          '追加消費 kcal = (6.8 − 1) × 3.5 × 体重kg ÷ 200 × 分。'
          '1 MET = 1 kcal·kg⁻¹·h⁻¹。安静の 1 MET は引く。',
      aliases: const [
        'じてんしゃ',
        'チャリ',
        'ちゃり',
        'サイクリング',
        'さいくりんぐ',
        'bike',
        'bicycle',
        'cycling',
      ],
    ),
    _minutes(
      id: 'swim_lap',
      displayName: '水泳',
      category: ExerciseCategory.aerobic,
      met: 5.8,
      sourceKey: 'compendium_2024_18292',
      description:
          'コード 18292 Swimming, crawl, slow speed, moderate effort, 5.8 MET。',
      aliases: const ['すいえい', '泳ぎ', 'およぎ', 'スイム', 'すいむ', 'swim', 'swimming'],
    ),
    _minutes(
      id: 'hiking',
      displayName: 'ハイキング',
      category: ExerciseCategory.aerobic,
      met: 5.3,
      sourceKey: 'compendium_2024_17082',
      description: 'コード 17082 Hiking or walking at a normal pace through fields and hillsides, 5.3 MET。',
      aliases: const ['はいきんぐ', 'ハイク', 'はいく', 'hike', 'hiking'],
    ),
    _minutes(
      id: 'stationary_bike',
      displayName: 'エアロバイク',
      category: ExerciseCategory.aerobic,
      met: 6.8,
      sourceKey: 'compendium_2024_01200',
      description: 'コード 01200 Bicycling, stationary, general, 6.8 MET。',
      aliases: const [
        'えあろばいく',
        'エアロ',
        'えあろ',
        'exercise bike',
        'stationary bike',
      ],
    ),
    _minutes(
      id: 'elliptical',
      displayName: 'エリプティカル',
      category: ExerciseCategory.aerobic,
      met: 5.0,
      sourceKey: 'compendium_2024_02048',
      description: 'コード 02048 Elliptical trainer, moderate effort, 5.0 MET。',
      aliases: const ['えりぷてぃかる', 'クロストレーナー', 'くろすとれーなー', 'elliptical'],
    ),
    _minutes(
      id: 'rowing',
      displayName: 'ローイング',
      category: ExerciseCategory.aerobic,
      met: 5.0,
      sourceKey: 'compendium_2024_02071',
      description: 'コード 02071 Rowing, stationary ergometer, general, <100 watts, moderate effort, 5.0 MET。',
      aliases: const ['ろーいんぐ', 'ボート', 'ぼーと', 'rowing', 'row'],
    ),
    _minutes(
      id: 'basketball',
      displayName: 'バスケットボール',
      category: ExerciseCategory.sport,
      met: 7.5,
      sourceKey: 'compendium_2024_15055',
      description: 'コード 15055 Basketball, general, 7.5 MET。',
      aliases: const ['ばすけっとぼーる', 'バスケ', 'ばすけ', 'basketball'],
    ),
    _minutes(
      id: 'soccer',
      displayName: 'サッカー',
      category: ExerciseCategory.sport,
      met: 7.0,
      sourceKey: 'compendium_2024_15610',
      description: 'コード 15610 Soccer, casual, general, 7.0 MET。',
      aliases: const ['さっかー', 'soccer', 'football'],
    ),
    _minutes(
      id: 'futsal',
      displayName: 'フットサル',
      category: ExerciseCategory.sport,
      met: 7.8,
      sourceKey: 'compendium_2024_15195',
      description: 'コード 15195 Futsal, 7.8 MET。',
      aliases: const ['ふっとさる', 'futsal'],
    ),
    _minutes(
      id: 'tennis',
      displayName: 'テニス',
      category: ExerciseCategory.sport,
      met: 6.8,
      sourceKey: 'compendium_2024_15675',
      description: 'コード 15675 Tennis, general, moderate effort, 6.8 MET。',
      aliases: const ['てにす', 'tennis'],
    ),
    _minutes(
      id: 'badminton',
      displayName: 'バドミントン',
      category: ExerciseCategory.sport,
      met: 5.5,
      sourceKey: 'compendium_2024_15030',
      description:
          'コード 15030 Badminton, social singles and doubles, general, 5.5 MET。',
      aliases: const ['ばどみんとん', 'バド', 'ばど', 'badminton'],
    ),
    _minutes(
      id: 'table_tennis',
      displayName: '卓球',
      category: ExerciseCategory.sport,
      met: 4.0,
      sourceKey: 'compendium_2024_15660',
      description: 'コード 15660 Table tennis, ping pong, 4.0 MET。',
      aliases: const ['たっきゅう', 'ピンポン', 'ぴんぽん', 'table tennis', 'ping pong'],
    ),
    _minutes(
      id: 'volleyball',
      displayName: 'バレーボール',
      category: ExerciseCategory.sport,
      met: 4.0,
      sourceKey: 'compendium_2024_15710',
      description: 'コード 15710 Volleyball, 4.0 MET。',
      aliases: const ['ばれーぼーる', 'バレー', 'ばれー', 'volleyball'],
    ),
    _minutes(
      id: 'baseball',
      displayName: '野球',
      category: ExerciseCategory.sport,
      met: 5.0,
      sourceKey: 'compendium_2024_15620',
      description:
          'コード 15620 Softball or baseball, general, moderate effort, 5.0 MET。',
      aliases: const ['やきゅう', 'ベースボール', 'べーすぼーる', 'baseball'],
    ),
    _minutes(
      id: 'golf',
      displayName: 'ゴルフ',
      category: ExerciseCategory.sport,
      met: 4.5,
      sourceKey: 'compendium_2024_15255',
      description: 'コード 15255 Golf, general, 4.5 MET。',
      aliases: const ['ごるふ', 'golf'],
    ),
    _reps(
      id: 'squat',
      displayName: 'スクワット',
      met: 5.0,
      sourceKey: 'compendium_2024_02052',
      description:
          'コード 02052 Resistance training, squats, deadlift, slow or explosive, 5.0 MET。'
          'スクワットとデッドリフトは同じコード。',
      aliases: const ['すくわっと', 'squat', 'squats'],
      requiresManualKcal: true,
    ),
    _reps(
      id: 'deadlift',
      displayName: 'デッドリフト',
      met: 5.0,
      sourceKey: 'compendium_2024_02052',
      description:
          'コード 02052 Resistance training, squats, deadlift, slow or explosive, 5.0 MET。'
          'スクワットとデッドリフトは同じコード。',
      aliases: const ['でっどりふと', 'デッド', 'でっど', 'deadlift'],
      requiresManualKcal: true,
    ),
    _reps(
      id: 'bench_press',
      displayName: 'ベンチプレス',
      met: 3.5,
      sourceKey: 'compendium_2024_02054',
      description:
          'コード 02054 Resistance training, multiple exercises, 8-15 reps, 3.5 MET。'
          'ベンチプレス単独のコードは無い。',
      aliases: const ['べんちぷれす', 'ベンチ', 'べんち', 'bench press', 'bench'],
      requiresManualKcal: true,
    ),
    _reps(
      id: 'push_up',
      displayName: '腕立て伏せ',
      met: 3.8,
      sourceKey: 'compendium_2024_02022',
      description: 'コード 02022 Calisthenics, moderate effort (pushups, sit ups, pull-ups, lunges), 3.8 MET。',
      aliases: const ['うでたてふせ', 'ウデタテフセ', '腕立て', 'うでたて', 'push up', 'pushup'],
      requiresManualKcal: true,
    ),
    _reps(
      id: 'sit_up',
      displayName: '腹筋',
      met: 3.8,
      sourceKey: 'compendium_2024_02022',
      description: 'コード 02022 Calisthenics, moderate effort (pushups, sit ups, pull-ups, lunges), 3.8 MET。',
      aliases: const ['ふっきん', 'フクキン', 'シットアップ', 'しっとあっぷ', 'sit up', 'situp'],
      requiresManualKcal: true,
    ),
    _reps(
      id: 'pull_up',
      displayName: '懸垂',
      met: 3.8,
      sourceKey: 'compendium_2024_02022',
      description: 'コード 02022 Calisthenics, moderate effort (pushups, sit ups, pull-ups, lunges), 3.8 MET。',
      aliases: const [
        'けんすい',
        'ケンスイ',
        'チンニング',
        'ちんにんぐ',
        'pull up',
        'pullup',
        'chin up',
      ],
      requiresManualKcal: true,
    ),
    _minutes(
      id: 'yoga',
      displayName: 'ヨガ',
      category: ExerciseCategory.dailyActivity,
      met: 2.3,
      sourceKey: 'compendium_2024_02150',
      description: 'コード 02150 Yoga, Hatha, 2.3 MET。',
      aliases: const ['よが', 'yoga'],
    ),
    _minutes(
      id: 'stretch',
      displayName: 'ストレッチ',
      category: ExerciseCategory.dailyActivity,
      met: 2.3,
      sourceKey: 'compendium_2024_02101',
      description: 'コード 02101 Stretching, mild, 2.3 MET。',
      aliases: const ['すとれっち', 'stretch', 'stretching'],
    ),
    _minutes(
      id: 'housework',
      displayName: '家事',
      category: ExerciseCategory.dailyActivity,
      met: 3.3,
      sourceKey: 'compendium_2024_05030',
      description:
          'コード 05030 Cleaning, house or cabin, general, 3.3 MET。'
          '生活活動に含まれるため追加消費は計算しない。',
      lifestyleIncluded: true,
      aliases: const ['かじ', 'カジ', 'housework', 'chores'],
    ),
    _minutes(
      id: 'cleaning',
      displayName: '掃除',
      category: ExerciseCategory.dailyActivity,
      met: 3.3,
      sourceKey: 'compendium_2024_05010',
      description:
          'コード 05010 Cleaning, sweeping carpet or floors, general, 3.3 MET。'
          '生活活動に含まれるため追加消費は計算しない。',
      lifestyleIncluded: true,
      aliases: const ['そうじ', 'ソウジ', 'cleaning', 'sweeping'],
    ),
    MetActivityDefinition(
      id: 'strength_general',
      displayName: '筋トレ',
      category: ExerciseCategory.strength,
      defaultMet: 5.0,
      defaultIntensityId: 'moderate',
      sourceKey: 'weight_training_moderate_5_0',
      description: '古い記録用。検索には出さない。',
      quantityUnit: ExerciseQuantityUnit.durationMin,
      aliases: const ['筋トレ'],
      searchable: false,
      requiresManualKcal: true,
      intensityOptions: MetIntensityPresets.strengthOptions,
    ),
    MetActivityDefinition(
      id: 'custom',
      displayName: 'その他（手入力）',
      category: ExerciseCategory.other,
      defaultMet: 3.0,
      defaultIntensityId: 'light',
      sourceKey: 'other_light_3_0',
      description: '別名検索の対象外。',
      quantityUnit: ExerciseQuantityUnit.durationMin,
      aliases: const [],
      searchable: false,
      requiresManualKcal: true,
      intensityOptions: MetIntensityPresets.otherOptions,
    ),
  ];

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

  /// 正規化後の入力が、別名と一致するか別名に含まれる種目。
  /// 文字の正規化は公式食品の [FoodSearchNormalizer] と同じ。
  /// 空文字と、検索対象外の種目は返さない。
  static List<MetActivityDefinition> search(String query) {
    final normalizedQuery = FoodSearchNormalizer.normalize(query);
    if (normalizedQuery.isEmpty) {
      return const [];
    }
    final hits = <MetActivityDefinition>[];
    for (final activity in activities) {
      if (!activity.searchable) {
        continue;
      }
      final matched = activity.aliases.any((alias) {
        final normalizedAlias = FoodSearchNormalizer.normalize(alias);
        return normalizedAlias.isNotEmpty &&
            (normalizedAlias == normalizedQuery ||
                normalizedAlias.contains(normalizedQuery));
      });
      if (matched) {
        hits.add(activity);
      }
    }
    hits.sort((a, b) => a.displayName.compareTo(b.displayName));
    return hits;
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

  static MetActivityDefinition _distanceFactor({
    required String id,
    required String displayName,
    required ExerciseCategory category,
    required double met,
    required String sourceKey,
    required String description,
    required double netKcalPerKgKm,
    required List<String> aliases,
    double? referenceSpeedKmh,
    String? calorieFormula,
  }) {
    return _built(
      id: id,
      displayName: displayName,
      category: category,
      met: met,
      sourceKey: sourceKey,
      description: description,
      quantityUnit: ExerciseQuantityUnit.distanceKm,
      aliases: aliases,
      netKcalPerKgKm: netKcalPerKgKm,
      referenceSpeedKmh: referenceSpeedKmh,
      calorieFormula: calorieFormula,
    );
  }

  static MetActivityDefinition _distanceSpeed({
    required String id,
    required String displayName,
    required ExerciseCategory category,
    required double met,
    required String sourceKey,
    required String description,
    required double referenceSpeedKmh,
    required List<String> aliases,
    String? calorieFormula,
  }) {
    return _built(
      id: id,
      displayName: displayName,
      category: category,
      met: met,
      sourceKey: sourceKey,
      description: description,
      quantityUnit: ExerciseQuantityUnit.distanceKm,
      aliases: aliases,
      referenceSpeedKmh: referenceSpeedKmh,
      calorieFormula: calorieFormula,
    );
  }

  static MetActivityDefinition _minutes({
    required String id,
    required String displayName,
    required ExerciseCategory category,
    required double met,
    required String sourceKey,
    required String description,
    required List<String> aliases,
    bool lifestyleIncluded = false,
  }) {
    return _built(
      id: id,
      displayName: displayName,
      category: category,
      met: met,
      sourceKey: sourceKey,
      description: description,
      quantityUnit: ExerciseQuantityUnit.durationMin,
      aliases: aliases,
      lifestyleIncluded: lifestyleIncluded,
      calorieFormula: lifestyleIncluded
          ? null
          : '追加消費 kcal = ($met − 1) × 3.5 × 体重kg ÷ 200 × 分。'
                '$description '
                '1 MET = 1 kcal·kg⁻¹·h⁻¹（3.5 mL·kg⁻¹·min⁻¹ × 5 kcal/L）。'
                '安静の 1 MET は引いて追加分だけにする。',
    );
  }

  static MetActivityDefinition _reps({
    required String id,
    required String displayName,
    required double met,
    required String sourceKey,
    required String description,
    required List<String> aliases,
    bool requiresManualKcal = false,
  }) {
    return _built(
      id: id,
      displayName: displayName,
      category: ExerciseCategory.strength,
      met: met,
      sourceKey: sourceKey,
      description: description,
      quantityUnit: ExerciseQuantityUnit.reps,
      aliases: aliases,
      requiresManualKcal: requiresManualKcal,
    );
  }

  static MetActivityDefinition _built({
    required String id,
    required String displayName,
    required ExerciseCategory category,
    required double met,
    required String sourceKey,
    required String description,
    required ExerciseQuantityUnit quantityUnit,
    required List<String> aliases,
    bool lifestyleIncluded = false,
    bool requiresManualKcal = false,
    double? netKcalPerKgKm,
    double? referenceSpeedKmh,
    String? calorieFormula,
  }) {
    return MetActivityDefinition(
      id: id,
      displayName: displayName,
      category: category,
      defaultMet: met,
      defaultIntensityId: _standard,
      sourceKey: sourceKey,
      description: description,
      quantityUnit: quantityUnit,
      aliases: _aliases(displayName, aliases),
      lifestyleIncluded: lifestyleIncluded,
      requiresManualKcal: requiresManualKcal,
      netKcalPerKgKm: netKcalPerKgKm,
      referenceSpeedKmh: referenceSpeedKmh,
      calorieFormula: calorieFormula,
      intensityOptions: [
        MetIntensityOption(
          id: _standard,
          label: '標準',
          description: description,
          met: met,
          sourceKey: sourceKey,
        ),
      ],
    );
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
