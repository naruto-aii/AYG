import 'package:flutter/material.dart';

import '../../constants/app_strings.dart';
import '../../models/activity_level.dart';
import '../../models/nutrition_settings.dart';
import '../../repositories/authentication_repository.dart';
import '../../services/open_food_facts_service.dart';
import '../../state/app_controller.dart';
import '../../theme/app_spacing.dart';
import '../food/food_form_navigation.dart';
import '../shell/shell_navigation.dart';

class ActivityLevelScreen extends StatefulWidget {
  const ActivityLevelScreen({
    super.key,
    required this.controller,
    required this.openFoodFactsService,
    required this.authenticationRepository,
    this.mainShellBuilder,
    this.foodFormBuilder,
  });

  final AppController controller;
  final OpenFoodFactsService openFoodFactsService;
  final AuthenticationRepository authenticationRepository;
  final MainShellScreenBuilder? mainShellBuilder;
  final FoodFormScreenBuilder? foodFormBuilder;

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

    final shellBuilder =
        widget.mainShellBuilder ?? defaultMainShellScreenBuilder;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (context) => shellBuilder(
          controller: widget.controller,
          openFoodFactsService: widget.openFoodFactsService,
          authenticationRepository: widget.authenticationRepository,
          foodFormBuilder: widget.foodFormBuilder,
        ),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.activityLevel)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            Text(
              '日々の活動量を選択してください',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: AppSpacing.lg),
            ...ActivityLevel.values.map(
              (level) => RadioListTile<ActivityLevel>(
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
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton(
              onPressed: _complete,
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 14),
                child: Text('完了'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
