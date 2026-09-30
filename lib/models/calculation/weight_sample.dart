import '../health_profile_data.dart';

/// 計算に渡す体重の1件。測定時刻を持つ。
class WeightSample {
  const WeightSample({
    required this.kg,
    required this.measuredAt,
    required this.source,
  });

  final double kg;
  final DateTime measuredAt;
  final WeightSource source;
}
