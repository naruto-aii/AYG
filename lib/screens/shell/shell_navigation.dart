import 'package:flutter/material.dart';

import '../../repositories/authentication_repository.dart';
import '../../repositories/health_repository.dart';
import '../../services/open_food_facts_service.dart';
import '../../state/app_controller.dart';
import '../food/food_form_navigation.dart';
import 'main_shell_screen.dart';

typedef MainShellScreenBuilder =
    Widget Function({
      required AppController controller,
      required OpenFoodFactsService openFoodFactsService,
      required AuthenticationRepository authenticationRepository,
      HealthRepository? healthRepository,
      FoodFormScreenBuilder? foodFormBuilder,
    });

Widget defaultMainShellScreenBuilder({
  required AppController controller,
  required OpenFoodFactsService openFoodFactsService,
  required AuthenticationRepository authenticationRepository,
  HealthRepository? healthRepository,
  FoodFormScreenBuilder? foodFormBuilder,
}) {
  return MainShellScreen(
    controller: controller,
    openFoodFactsService: openFoodFactsService,
    authenticationRepository: authenticationRepository,
    healthRepository: healthRepository,
    foodFormBuilder: foodFormBuilder,
  );
}
