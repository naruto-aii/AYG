import 'package:flutter/material.dart';

import 'repositories/authentication_repository.dart';
import 'repositories/health_repository.dart';
import 'screens/auth/login_screen.dart';
import 'screens/onboarding/health_setup_screen.dart';
import 'screens/shell/main_shell_screen.dart';
import 'services/open_food_facts_service.dart';
import 'state/app_controller.dart';
import 'theme/app_theme.dart';

class AygApp extends StatelessWidget {
  const AygApp({
    super.key,
    required this.controller,
    required this.openFoodFactsService,
    required this.healthRepository,
    required this.authenticationRepository,
  });

  final AppController controller;
  final OpenFoodFactsService openFoodFactsService;
  final HealthRepository healthRepository;
  final AuthenticationRepository authenticationRepository;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AYG',
      theme: AppTheme.light,
      home: ListenableBuilder(
        listenable: controller,
        builder: (context, child) {
          if (!controller.isAuthenticated) {
            return LoginScreen(
              controller: controller,
              authenticationRepository: authenticationRepository,
            );
          }

          if (_shouldShowMainShell(controller)) {
            return MainShellScreen(
              controller: controller,
              openFoodFactsService: openFoodFactsService,
              authenticationRepository: authenticationRepository,
              healthRepository: healthRepository,
            );
          }

          return HealthSetupScreen(
            controller: controller,
            openFoodFactsService: openFoodFactsService,
            healthRepository: healthRepository,
            authenticationRepository: authenticationRepository,
          );
        },
      ),
    );
  }

  bool _shouldShowMainShell(AppController controller) {
    return controller.onboardingComplete &&
        controller.profile != null &&
        controller.goal != null &&
        controller.nutritionSettings != null;
  }
}
