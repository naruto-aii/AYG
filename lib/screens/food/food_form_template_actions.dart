import 'package:flutter/material.dart';

import '../../state/app_controller.dart';
import 'food_meal_registration_screen.dart';

Future<void> openFoodTemplatePicker({
  required BuildContext context,
  required AppController controller,
  DateTime? initialLoggedAt,
  VoidCallback? onMealRegistered,
}) async {
  final registered = await openFoodMealRegistrationFromTemplatePicker(
    context: context,
    controller: controller,
    initialLoggedAt: initialLoggedAt,
  );
  if (registered == true) {
    onMealRegistered?.call();
  }
}
