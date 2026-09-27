import '../models/saved_food_persistence_error.dart';

/// Message safe to show in a snackbar or dialog.
///
/// Known app errors use their Japanese text. Anything else, including
/// exception class names and plugin strings, becomes [fallback].
String userFacingErrorMessage(Object error, {required String fallback}) {
  if (error is SavedFoodPersistenceException) {
    return error.userMessage;
  }
  return fallback;
}
