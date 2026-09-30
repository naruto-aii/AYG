/// 安全な速度では目標日に着地できないときの案内。
///
/// 目標日と目標体重は、ここからは変えない。利用者がボタンを押したときだけ変える。
enum LandingGuidanceKind { exceedsSafeSpeed, slowPaceCannotReach }

enum LandingGuidanceAction { extendDate, changeWeight, useStandardPace }

class LandingGuidance {
  const LandingGuidance({
    required this.kind,
    required this.recommended,
    required this.alternative,
    required this.suggestedDate,
    required this.suggestedWeightKg,
    required this.message,
  });

  final LandingGuidanceKind kind;
  final LandingGuidanceAction recommended;
  final LandingGuidanceAction? alternative;
  final DateTime? suggestedDate;
  final double? suggestedWeightKg;
  final String message;

  String labelFor(LandingGuidanceAction action) {
    return switch (action) {
      LandingGuidanceAction.extendDate =>
        suggestedDate == null
            ? '目標日を延ばす'
            : '目標日を${suggestedDate!.year}年${suggestedDate!.month}月${suggestedDate!.day}日に延ばす',
      LandingGuidanceAction.changeWeight =>
        suggestedWeightKg == null
            ? '目標体重を変える'
            : '目標体重を${suggestedWeightKg!.toStringAsFixed(1)} kgにする',
      LandingGuidanceAction.useStandardPace => '標準ペースにする',
    };
  }
}

/// 前日比の基準として保存する、自動計算の食事目標。
class AutoTargetAnchor {
  const AutoTargetAnchor({
    required this.targetKcal,
    required this.targetOn,
    required this.priorKcal,
  });

  final double targetKcal;
  final DateTime targetOn;
  final double? priorKcal;
}
