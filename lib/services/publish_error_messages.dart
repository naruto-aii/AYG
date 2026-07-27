import '../repositories/exceptions/food_master_exceptions.dart';

/// publish_saved_food RPC 失敗のユーザー向けメッセージ。
class PublishErrorMessages {
  PublishErrorMessages._();

  static String messageFor(Object error) {
    if (error is PublishSavedFoodException) {
      return messageForKind(error.kind);
    }
    if (error is FoodMasterDuplicateException) {
      return messageForKind(PublishFailureKind.duplicate);
    }
    if (error is FoodMasterRateLimitException) {
      return messageForKind(error.kind);
    }
    if (error is FoodMasterAuthenticationException) {
      return messageForKind(PublishFailureKind.notAuthenticated);
    }
    if (error is FoodMasterValidationException) {
      return messageForKind(PublishFailureKind.validation);
    }
    if (error is FoodMasterPermissionException) {
      return messageForKind(PublishFailureKind.notOwner);
    }
    if (error is FoodMasterNetworkException) {
      return messageForKind(PublishFailureKind.network);
    }
    return '公開に失敗しました。時間をおいて再度お試しください。';
  }

  static String messageForKind(PublishFailureKind kind) {
    return switch (kind) {
      PublishFailureKind.duplicate => '同じ食品名・基準量・単位の公開食品がすでにあります',
      PublishFailureKind.rateLimitHourly => '1時間に公開できる上限に達しました',
      PublishFailureKind.rateLimitDaily => '本日公開できる上限に達しました',
      PublishFailureKind.notOwner => 'この食品を公開する権限がありません',
      PublishFailureKind.invalidState => 'この食品は現在公開できません',
      PublishFailureKind.validation => '公開前の入力内容を確認してください',
      PublishFailureKind.alreadyPublic => 'すでに公開されています',
      PublishFailureKind.moderationBlocked => 'モデレーション状態により公開できません',
      PublishFailureKind.notAuthenticated => 'ログインが必要です',
      PublishFailureKind.network => '通信に失敗しました。時間をおいて再度お試しください',
      PublishFailureKind.unknown => '公開に失敗しました。時間をおいて再度お試しください',
    };
  }
}
