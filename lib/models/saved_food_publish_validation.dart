/// 公開前クライアント検証結果。
class SavedFoodPublishValidationResult {
  const SavedFoodPublishValidationResult({
    required this.isValid,
    this.errors = const [],
    this.manualMacroConsistent,
  });

  final bool isValid;
  final List<String> errors;

  /// manual 食品の 4/9/4 整合。null は対象外。
  final bool? manualMacroConsistent;

  static const valid = SavedFoodPublishValidationResult(isValid: true);
}
