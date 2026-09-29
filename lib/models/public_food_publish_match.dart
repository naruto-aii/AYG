import 'saved_food.dart';

/// 公開食品の完全一致候補（Good/Bad 件数付き）。
class PublicFoodPublishMatch {
  const PublicFoodPublishMatch({
    required this.food,
    required this.goodCount,
    required this.badCount,
  });

  final SavedFood food;
  final int goodCount;
  final int badCount;
}

/// 公開前の類似食品候補。
class PublicFoodSimilarMatch {
  const PublicFoodSimilarMatch({
    required this.food,
    required this.goodCount,
    required this.badCount,
    required this.reason,
  });

  final SavedFood food;
  final int goodCount;
  final int badCount;
  final PublicFoodSimilarReason reason;
}

enum PublicFoodSimilarReason {
  sameNameDifferentAmount,
  namePrefix,
  barcodeMatch,
}

extension PublicFoodSimilarReasonX on PublicFoodSimilarReason {
  String get label => switch (this) {
    PublicFoodSimilarReason.sameNameDifferentAmount => '名称一致・基準量/単位が異なる',
    PublicFoodSimilarReason.namePrefix => '名称が類似',
    PublicFoodSimilarReason.barcodeMatch => 'バーコード一致',
  };
}
