import '../config/subscription_catalog.dart';

enum SubscriptionLimitKind { publicFoodSearch, mealTemplate, workoutTemplate }

class SubscriptionLimitExceededException implements Exception {
  SubscriptionLimitExceededException(this.kind);

  final SubscriptionLimitKind kind;

  @override
  String toString() {
    return switch (kind) {
      SubscriptionLimitKind.publicFoodSearch =>
        '公開食品検索は1日${SubscriptionCatalog.publicFoodSearchesPerDay}回までです。',
      SubscriptionLimitKind.mealTemplate =>
        '無料の食事テンプレートは${SubscriptionCatalog.mealTemplateLimit}件までです。次の1件からはカロナビ+です。',
      SubscriptionLimitKind.workoutTemplate =>
        '無料の運動テンプレートは${SubscriptionCatalog.workoutTemplateLimit}件までです。次の1件からはカロナビ+です。',
    };
  }
}

class SubscriptionPurchaseUnavailableException implements Exception {
  @override
  String toString() => 'この環境ではアプリ内課金を使えません。';
}

class SubscriptionPurchaseFailedException implements Exception {
  SubscriptionPurchaseFailedException(this.message);

  final String message;

  @override
  String toString() => message;
}
