import 'package:flutter/material.dart';

import '../../constants/app_strings.dart';
import '../../models/activity_level.dart';
import '../../models/nutrition_settings.dart';
import '../../repositories/authentication_repository.dart';
import '../../services/open_food_facts_service.dart';
import '../../state/app_controller.dart';
import '../../theme/app_typography.dart';
import '../../widgets/design/design_button.dart';
import '../../widgets/design/design_page.dart';
import '../../widgets/design/select_card.dart';
import '../shell/main_shell_screen.dart';

/// 初回オンボーディング: 活動量の選択。
///
/// Health 連携をしない場合にだけ通る。Figma には画面がないので、
/// 他のオンボーディング画面と同じ部品で組んである。
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
  bool _isSaving = false;

  Future<void> _complete() async {
    setState(() => _isSaving = true);

    widget.controller.setNutritionSettings(
      NutritionSettings(
        useHealthIntegration: false,
        activityLevel: _activityLevel,
      ),
    );

    try {
      await widget.controller.completeOnboarding();
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('保存に失敗しました: $error')));
      return;
    }

    if (!mounted) {
      return;
    }

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
    return DesignPage(
      bodyPadding: const EdgeInsets.symmetric(horizontal: 20),
      header: DesignHeader(leading: const DesignBackButton()),
      bottomBar: DesignButton(
        label: 'はじめる',
        loading: _isSaving,
        onPressed: _isSaving ? null : _complete,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 10),
          Text(AppStrings.activityLevel, style: AppTypography.headingXl),
          const SizedBox(height: 4),
          Text('日々の活動量に近いものを選んでください', style: AppTypography.bodyM),
          const SizedBox(height: 18),
          for (final level in ActivityLevel.values) ...[
            SelectCard(
              title: AppStrings.activityLevelLabel(level),
              description: AppStrings.activityLevelDescription(level),
              selected: _activityLevel == level,
              onTap: _isSaving
                  ? null
                  : () => setState(() => _activityLevel = level),
            ),
            const SizedBox(height: 14),
          ],
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}
