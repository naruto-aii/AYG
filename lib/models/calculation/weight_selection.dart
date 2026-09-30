import '../health_profile_data.dart';

/// 選んだ体重がこの日数より古いと、不足を増やさない。
const weightStaleAfterDays = 7;

/// Health の測定がこの日数より古いと、更新停止を画面に書く。
const healthUpdateStoppedAfterDays = 14;

const landingMinSamples = 3;
const landingMinSpanDays = 7;
const smoothingHalfLifeDays = 7.0;

/// 計算に使った体重と、画面に出す文言。
class WeightSelection {
  const WeightSelection({
    required this.kg,
    required this.measuredAt,
    required this.source,
    required this.ageDays,
    required this.stale,
    required this.healthAgeDays,
    required this.healthUpdateStopped,
    required this.hasMeasurementTime,
  });

  final double kg;
  final DateTime? measuredAt;
  final WeightSource? source;
  final int? ageDays;
  final bool stale;
  final int? healthAgeDays;
  final bool healthUpdateStopped;
  final bool hasMeasurementTime;

  String get sourceLabel => switch (source) {
    WeightSource.health => 'Health',
    WeightSource.manual || null => 'アプリ',
  };

  String get ageLabel {
    if (!hasMeasurementTime || ageDays == null) {
      return '記録日時なし';
    }
    if (ageDays == 0) {
      return '今日';
    }
    if (ageDays == 1) {
      return '昨日';
    }
    return '$ageDays日前';
  }

  String get usageLabel =>
      '計算に使用: ${kg.toStringAsFixed(1)} kg · $sourceLabel · $ageLabel';

  String? get healthUpdateStoppedNote {
    if (!healthUpdateStopped || healthAgeDays == null) {
      return null;
    }
    return 'Healthの体重は$healthAgeDays日前のままです。更新が止まっています。';
  }

  String? get staleRecordPrompt {
    if (!stale) {
      return null;
    }
    return '体重が7日より古いので、不足は増やしていません。体重を記録してください。';
  }
}

class WeightSeries {
  const WeightSeries({
    required this.selection,
    required this.sampleCount,
    required this.spanDays,
    required this.smoothedKg,
    required this.useLandingFormula,
  });

  final WeightSelection selection;
  final int sampleCount;
  final int? spanDays;
  final double? smoothedKg;

  /// 記録が3回以上、かつ最初と最後が7日以上離れている。
  final bool useLandingFormula;
}
