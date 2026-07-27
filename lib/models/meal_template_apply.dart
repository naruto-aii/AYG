import 'meal_template.dart';
import 'saved_food.dart';

enum MealTemplateDependencyKind {
  sourceDeleted,
  sourceHidden,
  sourceChanged,
  creatorBlocked,
  unavailable,
}

class MealTemplateDependencyIssue {
  const MealTemplateDependencyIssue({
    required this.item,
    required this.kind,
    this.currentFood,
  });

  final MealTemplateItem item;
  final MealTemplateDependencyKind kind;
  final SavedFood? currentFood;
}

enum MealTemplateItemResolutionAction {
  useSnapshot,
  copyToPrivate,
  replace,
  exclude,
  cancel,
}

class MealTemplateItemResolution {
  const MealTemplateItemResolution({
    required this.itemId,
    required this.action,
    this.replacement,
  });

  final String itemId;
  final MealTemplateItemResolutionAction action;
  final MealTemplateItem? replacement;
}

class MealTemplateApplyResult {
  const MealTemplateApplyResult({
    required this.success,
    this.createdEntryCount = 0,
    this.issues = const [],
    this.cancelled = false,
    this.errorMessage,
  });

  final bool success;
  final int createdEntryCount;
  final List<MealTemplateDependencyIssue> issues;
  final bool cancelled;
  final String? errorMessage;

  bool get needsResolution => !success && issues.isNotEmpty && !cancelled;
}
