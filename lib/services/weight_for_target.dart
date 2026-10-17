import 'dart:math' as math;

import '../models/calculation/weight_sample.dart';
import '../models/calculation/weight_selection.dart';
import '../models/health_profile_data.dart';
import '../utils/local_date.dart';
import '../utils/record_clock.dart';

export '../models/calculation/weight_selection.dart';

WeightSeries describeWeightSeries({
  required List<WeightSample> samples,
  required DateTime reference,
  double? fallbackKg,
}) {
  final selection = selectWeight(
    samples: samples,
    reference: reference,
    fallbackKg: fallbackKg,
  );
  int? spanDays;
  if (samples.length >= 2) {
    final sorted = [...samples]
      ..sort((a, b) => compareRecordInstants(a.measuredAt, b.measuredAt));
    spanDays = localDayStart(
      civilClock(sorted.last.measuredAt),
    ).difference(localDayStart(civilClock(sorted.first.measuredAt))).inDays;
  }
  final useLanding =
      samples.length >= landingMinSamples &&
      (spanDays ?? 0) >= landingMinSpanDays;
  return WeightSeries(
    selection: selection,
    sampleCount: samples.length,
    spanDays: spanDays,
    smoothedKg: useLanding ? smoothWeight(samples, reference) : null,
    useLandingFormula: useLanding,
  );
}

/// 手入力と Health のうち、測定時刻が新しい方。同時刻は手入力。
WeightSelection selectWeight({
  required List<WeightSample> samples,
  required DateTime reference,
  double? fallbackKg,
}) {
  final manual = _latest(samples, WeightSource.manual);
  final health = _latest(samples, WeightSource.health);
  final chosen = _newer(manual, health);
  final healthAge = health == null
      ? null
      : calendarAgeDays(health.measuredAt, reference);

  if (chosen == null) {
    return WeightSelection(
      kg: fallbackKg ?? 0,
      measuredAt: null,
      source: WeightSource.manual,
      ageDays: null,
      stale: false,
      healthAgeDays: healthAge,
      healthUpdateStopped:
          healthAge != null && healthAge > healthUpdateStoppedAfterDays,
      hasMeasurementTime: false,
    );
  }

  final age = calendarAgeDays(chosen.measuredAt, reference);
  return WeightSelection(
    kg: chosen.kg,
    measuredAt: chosen.measuredAt,
    source: chosen.source,
    ageDays: age,
    stale: age > weightStaleAfterDays,
    healthAgeDays: healthAge,
    healthUpdateStopped:
        healthAge != null && healthAge > healthUpdateStoppedAfterDays,
    hasMeasurementTime: true,
  );
}

/// 半減期7日。古い記録ほど影響が小さい。
double smoothWeight(List<WeightSample> samples, DateTime reference) {
  var weighted = 0.0;
  var total = 0.0;
  for (final sample in samples) {
    final ageDays =
        civilClock(
          reference,
        ).difference(civilClock(sample.measuredAt)).inMinutes /
        1440;
    final age = ageDays < 0 ? 0.0 : ageDays;
    final weight = math.pow(0.5, age / smoothingHalfLifeDays).toDouble();
    weighted += weight * sample.kg;
    total += weight;
  }
  if (total == 0) {
    return samples.isEmpty ? 0 : samples.last.kg;
  }
  return weighted / total;
}

int calendarAgeDays(DateTime measuredAt, DateTime reference) {
  final days = localDayStart(
    civilClock(reference),
  ).difference(localDayStart(civilClock(measuredAt))).inDays;
  return days < 0 ? 0 : days;
}

WeightSample? _latest(List<WeightSample> samples, WeightSource source) {
  WeightSample? best;
  for (final sample in samples) {
    if (sample.source != source) {
      continue;
    }
    // 新しい記録は秒未満を印に使う。壁時計で同じか新しい方を採る。
    // 同じ壁時計なら、後から足した方を新しいとする。
    if (best == null ||
        compareRecordInstants(sample.measuredAt, best.measuredAt) >= 0) {
      best = sample;
    }
  }
  return best;
}

WeightSample? _newer(WeightSample? manual, WeightSample? health) {
  if (manual == null) {
    return health;
  }
  if (health == null) {
    return manual;
  }
  if (compareRecordInstants(health.measuredAt, manual.measuredAt) > 0) {
    return health;
  }
  return manual;
}
