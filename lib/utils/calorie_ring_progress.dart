import 'dart:math' as math;

/// カロリーリングの塗りの割合（0.0〜1.0）。アプリのホームとウィジェットで同じ式を使う。
///
/// リングの中の「今日あと ○kcal」と同じ数字から作るので、
/// 一周ちょうど塗られたとき＝「あと 0kcal」＝今日の目標（運動で増えた分も含む）に届いた、になる。
///
/// - 今日食べてよい量 = 摂取 + 残り（= 目標 + 運動などの消費）
/// - 割合 = 摂取 ÷ 今日食べてよい量。10% 刻みなどには丸めない
/// - 残りが 0 未満（超過）は 1.0（一周）
/// - 目標が 0 以下（未設定）や数字が壊れているときは 0.0
///
/// 運動をしない日は「摂取 ÷ 目標」と同じ値になる。
/// Swift の `MealWidgetFigures.ringFraction` と同じ。
double calorieRingProgress({
  required double intakeKcal,
  required double remainingKcal,
  required double targetKcal,
}) {
  if (!intakeKcal.isFinite || !remainingKcal.isFinite || !targetKcal.isFinite) {
    return 0;
  }
  if (targetKcal <= 0) {
    return 0;
  }
  if (remainingKcal < 0) {
    return 1;
  }
  if (intakeKcal <= 0) {
    return 0;
  }
  final budget = intakeKcal + remainingKcal;
  if (budget <= 0) {
    return 0;
  }
  return (intakeKcal / budget).clamp(0.0, 1.0);
}

/// 端が丸い線で弧を描くとき、丸い端が両側に線幅の半分ずつはみ出す分（一周に対する割合）。
///
/// 半径 [radius]・線幅 [strokeWidth] の円で、はみ出しの合計は線幅1本分。
/// これを差し引いて描くと、見た目の塗りの長さが [calorieRingProgress] と一致する。
/// 差し引かないと、約97%で輪が閉じて見えてしまう。
double ringRoundCapFraction({
  required double radius,
  required double strokeWidth,
}) {
  if (radius <= 0 || strokeWidth <= 0) {
    return 0;
  }
  return strokeWidth / (2 * math.pi * radius);
}

/// 丸い端の線で、見た目が 0〜[progress] ちょうどになる描画範囲（一周に対する割合）。
///
/// - 0 以下: 描かない（null）
/// - 1 以上: 一周（0〜1。閉じた輪なので端は出ない）
/// - 丸い端より短いとき: 0〜[progress] のまま描く（線幅ぶんの点になる）
/// - それ以外: 両端を丸い端の半分ずつ内側に寄せる
({double from, double to})? ringTrimRange({
  required double progress,
  required double capFraction,
}) {
  if (!progress.isFinite || progress <= 0) {
    return null;
  }
  if (progress >= 1) {
    return (from: 0.0, to: 1.0);
  }
  if (progress <= capFraction) {
    return (from: 0.0, to: progress);
  }
  final half = capFraction / 2;
  return (from: half, to: progress - half);
}
