import 'package:supabase_flutter/supabase_flutter.dart';

import '../exceptions/food_master_exceptions.dart';

class SupabaseErrorMapper {
  const SupabaseErrorMapper._();

  static Never mapAndThrow(Object error, {String context = 'request'}) {
    throw map(error, context: context);
  }

  static FoodMasterException map(Object error, {String context = 'request'}) {
    if (error is FoodMasterException) {
      return error;
    }

    if (error is AuthException) {
      return const FoodMasterAuthenticationException();
    }

    if (error is PostgrestException) {
      return _mapPostgrest(error, context: context);
    }

    if (error.toString().contains('SocketException') ||
        error.toString().contains('Failed host lookup') ||
        error.toString().contains('ClientException')) {
      return FoodMasterNetworkException('$context failed: network error.');
    }

    return FoodMasterNetworkException('$context failed: $error');
  }

  static PublishSavedFoodException mapPublishFailure(Object error) {
    if (error is PublishSavedFoodException) {
      return error;
    }

    final mapped = map(error, context: 'publish_saved_food');
    if (mapped is PublishSavedFoodException) {
      return mapped;
    }

    if (mapped is FoodMasterDuplicateException) {
      return PublishSavedFoodException(
        kind: PublishFailureKind.duplicate,
        message: mapped.message,
      );
    }

    if (mapped is FoodMasterRateLimitException) {
      return PublishSavedFoodException(
        kind: mapped.kind,
        message: mapped.message,
      );
    }

    if (mapped is FoodMasterAuthenticationException) {
      return PublishSavedFoodException(
        kind: PublishFailureKind.notAuthenticated,
        message: mapped.message,
      );
    }

    if (mapped is FoodMasterNotFoundException) {
      return PublishSavedFoodException(
        kind: PublishFailureKind.notOwner,
        message: mapped.message,
      );
    }

    if (mapped is FoodMasterValidationException) {
      return PublishSavedFoodException(
        kind: PublishFailureKind.validation,
        message: mapped.message,
      );
    }

    return PublishSavedFoodException(
      kind: PublishFailureKind.unknown,
      message: mapped.message,
    );
  }

  static FoodMasterException _mapPostgrest(
    PostgrestException error, {
    required String context,
  }) {
    final message = error.message.toLowerCase();
    final details = (error.details?.toString() ?? '').toLowerCase();
    final combined = '$message $details';

    if (combined.contains('duplicate public food') ||
        (combined.contains('duplicate key') && context.contains('publish'))) {
      return const FoodMasterDuplicateException();
    }

    if (combined.contains('hourly publish rate limit')) {
      return const FoodMasterRateLimitException(
        kind: PublishFailureKind.rateLimitHourly,
      );
    }

    if (combined.contains('daily publish rate limit')) {
      return const FoodMasterRateLimitException(
        kind: PublishFailureKind.rateLimitDaily,
      );
    }

    if (combined.contains('publish_saved_food') &&
        combined.contains('public visibility requires')) {
      return const PublishSavedFoodException(
        kind: PublishFailureKind.validation,
        message: 'Direct public visibility update is not allowed.',
      );
    }

    if (combined.contains('not authenticated') || combined.contains('jwt')) {
      return const FoodMasterAuthenticationException();
    }

    if (combined.contains('not found') || error.code == 'PGRST116') {
      return FoodMasterNotFoundException(error.message);
    }

    if (combined.contains('duplicate') || error.code == '23505') {
      return FoodMasterConflictException(error.message);
    }

    if (combined.contains('self rating')) {
      return const SelfRatingNotAllowedException();
    }

    if (combined.contains('self report') ||
        (combined.contains('reporter') && combined.contains('target'))) {
      return const SelfReportNotAllowedException();
    }

    if (combined.contains('permission denied') ||
        combined.contains('row-level security') ||
        error.code == '42501') {
      return FoodMasterPermissionException(error.message);
    }

    if (combined.contains('moderation') ||
        combined.contains('not publishable') ||
        combined.contains('already public') ||
        combined.contains('base_amount') ||
        combined.contains('nutrition values') ||
        combined.contains('invalid unit_type') ||
        combined.contains('name and normalized_name')) {
      if (combined.contains('already public')) {
        return PublishSavedFoodException(
          kind: PublishFailureKind.alreadyPublic,
          message: error.message,
        );
      }
      if (combined.contains('moderation')) {
        return PublishSavedFoodException(
          kind: PublishFailureKind.moderationBlocked,
          message: error.message,
        );
      }
      if (combined.contains('not publishable')) {
        return PublishSavedFoodException(
          kind: PublishFailureKind.invalidState,
          message: error.message,
        );
      }
      return FoodMasterValidationException(error.message);
    }

    return FoodMasterNetworkException('$context failed: ${error.message}');
  }
}
