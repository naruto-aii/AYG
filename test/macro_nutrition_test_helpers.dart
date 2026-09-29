import 'package:ayg/config/open_food_facts_config.dart';
import 'package:ayg/models/activity_level.dart';
import 'package:ayg/models/goal.dart';
import 'package:ayg/models/macro_field.dart';
import 'package:ayg/models/nutrition_settings.dart';
import 'package:ayg/models/user_profile.dart';
import 'package:ayg/repositories/authentication_repository.dart';
import 'package:ayg/services/open_food_facts_service.dart';
import 'package:ayg/state/app_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'mocks/mock_authentication_repository.dart';
import 'mocks/mock_health_repository.dart';

Future<
  ({
    AppController controller,
    OpenFoodFactsService openFoodFactsService,
    MockAuthenticationRepository authRepository,
    MockHealthRepository healthRepository,
  })
>
createOnboardedAppController() async {
  final openFoodFactsService = OpenFoodFactsService(
    userAgent: OpenFoodFactsConfig.userAgent,
  );
  final healthRepository = MockHealthRepository(isAvailable: false);
  final authRepository = MockAuthenticationRepository(
    currentUser: const AuthUser(id: 'user-1', email: 'test@example.com'),
  );
  final controller = AppController(
    healthRepository: healthRepository,
    authenticationRepository: authRepository,
  );

  controller.setProfile(
    UserProfile(
      birthDate: DateTime(1990, 1, 1),
      gender: Gender.male,
      heightCm: 175,
      weightKg: 75,
    ),
  );
  controller.setNutritionSettings(
    const NutritionSettings(
      useHealthIntegration: false,
      activityLevel: ActivityLevel.moderate,
    ),
  );
  controller.setGoal(
    Goal(
      type: GoalType.maintain,
      targetWeightKg: 75,
      targetDate: DateTime(2026, 10, 1),
    ),
  );
  await controller.completeOnboarding();

  return (
    controller: controller,
    openFoodFactsService: openFoodFactsService,
    authRepository: authRepository,
    healthRepository: healthRepository,
  );
}

Future<void> enterMacro(
  WidgetTester tester,
  MacroField field,
  String value,
) async {
  await tester.enterText(
    find.byKey(ValueKey('macro_field_${field.name}')),
    value,
  );
  await tester.pump();
}

String macroText(WidgetTester tester, MacroField field) {
  final editable = tester.widget<EditableText>(
    find.descendant(
      of: find.byKey(ValueKey('macro_field_${field.name}')),
      matching: find.byType(EditableText),
    ),
  );
  return editable.controller.text;
}

Future<void> tapMacroField(WidgetTester tester, MacroField field) async {
  await tester.tap(find.byKey(ValueKey('macro_field_${field.name}')));
  await tester.pump();
}
