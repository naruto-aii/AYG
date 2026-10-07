import 'analytics.dart';

/// 画面が呼ぶ操作の記録。テストは同じ関数を、画面の処理として使う。
abstract final class CatalogActions {
  static void loginTap(String provider) {
    Analytics.emit('login_tap', {'provider': provider});
  }

  static void loginResult({
    required String provider,
    required String result,
    String? errorKind,
    bool? isNewAccount,
  }) {
    Analytics.emit('login_result', {
      'provider': provider,
      'result': result,
      'error_kind': errorKind,
      'is_new_account': isNewAccount,
    });
  }

  static void onboardingStepView(String step) {
    Analytics.emit('onboarding_step_view', {'step': step});
  }

  static void onboardingStepComplete({
    required String step,
    required int durationMs,
    required bool skipped,
  }) {
    Analytics.emit('onboarding_step_complete', {
      'step': step,
      'duration_ms': durationMs,
      'skipped': skipped,
    });
  }

  static void foodSearchResultSelect({
    required String source,
    required int position,
    required int resultCount,
    required int queryLength,
    required String itemKind,
    String? searchQueryId,
  }) {
    Analytics.emit('food_search_result_select', {
      'source': source,
      'position': position,
      'result_count': resultCount,
      'query_length': queryLength,
      'item_kind': itemKind,
      'search_query_id': searchQueryId,
    });
  }

  static void recentFoodsOpen({required bool isPlus}) {
    Analytics.emit('recent_foods_open', {'is_plus': isPlus});
  }

  static void barcodeScanOpen() {
    Analytics.emit('barcode_scan_open');
  }

  static void barcodeScanResult({
    required String method,
    required String result,
    required int durationMs,
  }) {
    Analytics.emit('barcode_scan_result', {
      'method': method,
      'result': result,
      'duration_ms': durationMs,
    });
  }

  static void barcodeLookupResult({
    required String result,
    int? httpStatus,
    required int latencyMs,
  }) {
    Analytics.emit('barcode_lookup_result', {
      'result': result,
      'http_status': httpStatus,
      'latency_ms': latencyMs,
    });
  }

  static void savedFoodUpdated({
    required String savedFoodId,
    required String visibility,
    required String changedFields,
  }) {
    Analytics.emit('saved_food_updated', {
      'saved_food_id': savedFoodId,
      'visibility': visibility,
      'changed_fields': changedFields,
    });
  }

  static void publicFoodDuplicateWarning({
    required String kind,
    required String choice,
  }) {
    Analytics.emit('public_food_duplicate_warning', {
      'kind': kind,
      'choice': choice,
    });
  }

  static void publicFoodRated({
    required String savedFoodId,
    required String rating,
  }) {
    Analytics.emit('public_food_rated', {
      'saved_food_id': savedFoodId,
      'rating': rating,
    });
  }

  static void publicFoodReported({
    required String savedFoodId,
    required String reason,
  }) {
    Analytics.emit('public_food_reported', {
      'saved_food_id': savedFoodId,
      'reason': reason,
    });
  }

  static void officialFoodDetailView(String officialFoodCode) {
    Analytics.emit('official_food_detail_view', {
      'official_food_code': officialFoodCode,
    });
  }

  static void exerciseSearchResultSelect({
    required String source,
    required int position,
    required int resultCount,
  }) {
    Analytics.emit('exercise_search_result_select', {
      'source': source,
      'position': position,
      'result_count': resultCount,
    });
  }

  static void landingGuidanceShown(String guidanceKind) {
    Analytics.emit('landing_guidance_shown', {'guidance_kind': guidanceKind});
  }

  static void settingsChanged({
    required String settingKey,
    required String newValue,
  }) {
    Analytics.emit('settings_changed', {
      'setting_key': settingKey,
      'new_value': newValue,
    });
  }

  static void historyDaySelected(int daysAgo) {
    Analytics.emit('history_day_selected', {'days_ago': daysAgo});
  }

  static void legalDocumentView(String document) {
    Analytics.emit('legal_document_view', {'document': document});
  }

  static void contactTap(String channel) {
    Analytics.emit('contact_tap', {'channel': channel});
  }

  static void coachProposalShown({
    required String coachProposalLogId,
    required int proposalsCount,
  }) {
    Analytics.emit('coach_proposal_shown', {
      'coach_proposal_log_id': coachProposalLogId,
      'proposals_count': proposalsCount,
    });
  }

  static void coachProposalRegistered({
    required String coachProposalLogId,
    required List<String> foodEntryIds,
  }) {
    Analytics.emit('coach_proposal_registered', {
      'coach_proposal_log_id': coachProposalLogId,
      'food_entry_ids': foodEntryIds,
    });
  }

  static void shareTap({
    required String card,
    required String result,
    String? activityType,
  }) {
    Analytics.emit('share_tap', {
      'card': card,
      'result': result,
      'activity_type': activityType,
    });
  }

  static void announcementRead(String announcementId) {
    Analytics.emit('announcement_read', {'announcement_id': announcementId});
  }

  static void reviewPromptShown(String trigger) {
    Analytics.emit('review_prompt_shown', {'trigger': trigger});
  }

  static void reviewPromptAnswer(String answer) {
    Analytics.emit('review_prompt_answer', {'answer': answer});
  }

  static void accountDeletionStarted(String step) {
    Analytics.emit('account_deletion_started', {'step': step});
  }

  static void appError({
    required String errorType,
    required String where,
    required bool fatal,
  }) {
    Analytics.emit('app_error', {
      'error_type': errorType,
      'where': where,
      'fatal': fatal,
    });
  }
}
