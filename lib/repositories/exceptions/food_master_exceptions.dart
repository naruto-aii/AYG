/// publish_saved_food RPC 失敗の機械判定用。
enum PublishFailureKind {
  duplicate,
  rateLimitHourly,
  rateLimitDaily,
  notOwner,
  invalidState,
  validation,
  alreadyPublic,
  moderationBlocked,
  notAuthenticated,
  network,
  unknown,
}

/// 食品マスター Repository 共通例外。
sealed class FoodMasterException implements Exception {
  const FoodMasterException(this.message);

  final String message;

  @override
  String toString() => message;
}

class FoodMasterNetworkException extends FoodMasterException {
  const FoodMasterNetworkException([super.message = 'Network request failed.']);
}

class FoodMasterAuthenticationException extends FoodMasterException {
  const FoodMasterAuthenticationException([
    super.message = 'Authentication required.',
  ]);
}

class FoodMasterPermissionException extends FoodMasterException {
  const FoodMasterPermissionException([super.message = 'Permission denied.']);
}

class FoodMasterValidationException extends FoodMasterException {
  const FoodMasterValidationException(super.message);
}

class FoodMasterDuplicateException extends FoodMasterException {
  const FoodMasterDuplicateException([
    super.message = 'Duplicate public food exists.',
  ]);
}

class FoodMasterRateLimitException extends FoodMasterException {
  const FoodMasterRateLimitException({
    required this.kind,
    String message = 'Publish rate limit exceeded.',
  }) : super(message);

  final PublishFailureKind kind;
}

class PublishSavedFoodException extends FoodMasterException {
  const PublishSavedFoodException({
    required this.kind,
    required String message,
  }) : super(message);

  final PublishFailureKind kind;
}

class FoodMasterNotFoundException extends FoodMasterException {
  const FoodMasterNotFoundException([super.message = 'Resource not found.']);
}

class FoodMasterConflictException extends FoodMasterException {
  const FoodMasterConflictException([super.message = 'Conflict.']);
}

class SelfRatingNotAllowedException extends FoodMasterException {
  const SelfRatingNotAllowedException([
    super.message = 'Self rating is not allowed.',
  ]);
}

class SelfReportNotAllowedException extends FoodMasterException {
  const SelfReportNotAllowedException([
    super.message = 'Self report is not allowed.',
  ]);
}
