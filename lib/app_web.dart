import 'package:flutter/material.dart';

import 'repositories/authentication_repository.dart';
import 'screens/auth/web_login_screen.dart';
import 'screens/onboarding/web_onboarding_screen.dart';
import 'screens/shell/web_main_shell_screen.dart';
import 'services/open_food_facts_service.dart';
import 'state/app_controller.dart';
import 'theme/app_theme.dart';

class AygWebApp extends StatelessWidget {
  const AygWebApp({
    super.key,
    required this.controller,
    required this.openFoodFactsService,
    required this.authenticationRepository,
  });

  final AppController controller;
  final OpenFoodFactsService openFoodFactsService;
  final AuthenticationRepository authenticationRepository;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AYG Web Preview',
      theme: AppTheme.light,
      home: ListenableBuilder(
        listenable: controller,
        builder: (context, child) {
          if (!controller.isAuthenticated) {
            return WebLoginScreen(
              controller: controller,
              authenticationRepository: authenticationRepository,
            );
          }

          if (_shouldShowMainShell(controller)) {
            return WebMainShellScreen(
              controller: controller,
              openFoodFactsService: openFoodFactsService,
              authenticationRepository: authenticationRepository,
            );
          }

          return WebOnboardingScreen(
            controller: controller,
            openFoodFactsService: openFoodFactsService,
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
