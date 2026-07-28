import 'package:flutter/material.dart';

import '../../constants/app_strings.dart';
import '../../models/activity_level.dart';
import '../../models/nutrition_settings.dart';
import '../../repositories/authentication_repository.dart';
import '../../services/open_food_facts_service.dart';
import '../../state/app_controller.dart';
import '../../widgets/common/primary_button.dart';
import '../../widgets/onboarding/onboarding_scaffold.dart';
import '../shell/main_shell_screen.dart';

class ActivityLevelScreen extends StatefulWidget {
  const ActivityLevelScreen({
    super.key,
    required this.controller,
    required this.openFoodFactsService,
    required this.authenticationRepository,
  });

  final AppController controller;
  final OpenFoodFactsService openFoodFactsService;
  final AuthenticationRepository authenticationRepository;

  @override
  State<ActivityLevelScreen> createState() => _ActivityLevelScreenState();
}

class _ActivityLevelScreenState extends State<ActivityLevelScreen> {
  ActivityLevel _activityLevel = ActivityLevel.moderate;

  void _complete() {
    widget.controller.setNutritionSettings(
      NutritionSettings(
        useHealthIntegration: false,
        activityLevel: _activityLevel,
      ),
    );
    widget.controller.completeOnboarding();

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (context) => MainShellScreen(
          controller: widget.controller,
          openFoodFactsService: widget.openFoodFactsService,
          authenticationRepository: widget.authenticationRepository,
        ),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingScaffold(
      title: AppStrings.activityLevel,
      subtitle: '日々の活動量を選択してください',
      body: Column(
        children: ActivityLevel.values
            .map(
              (level) => RadioListTile<ActivityLevel>(
                contentPadding: EdgeInsets.zero,
                title: Text(AppStrings.activityLevelLabel(level)),
                subtitle: Text('係数 ${level.factor}'),
                value: level,
                groupValue: _activityLevel,
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _activityLevel = value);
                  }
                },
              ),
            )
            .toList(),
      ),
      action: PrimaryButton(label: '完了', onPressed: _complete),
    );
  }
}
