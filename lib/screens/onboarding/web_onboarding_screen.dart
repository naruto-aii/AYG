import 'package:flutter/material.dart';

import '../../models/health_profile_data.dart';
import '../../repositories/authentication_repository.dart';
import '../../services/open_food_facts_service.dart';
import '../../state/app_controller.dart';
import '../food/web_food_form_screen.dart';
import '../shell/web_main_shell_screen.dart';
import 'basic_info_screen.dart';

/// Web 向けオンボーディング（Health 選択を省略し Activity Level 経路へ）。
class WebOnboardingScreen extends StatelessWidget {
  const WebOnboardingScreen({
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
    return BasicInfoScreen(
      controller: controller,
      openFoodFactsService: openFoodFactsService,
      healthPrefill: HealthProfileData.empty,
      authenticationRepository: authenticationRepository,
      mainShellBuilder: webMainShellScreenBuilder,
      foodFormBuilder: webFoodFormScreenBuilder,
    );
  }
}
