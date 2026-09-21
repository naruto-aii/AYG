import 'package:flutter/material.dart';

import '../../models/health_profile_data.dart';
import '../../models/nutrition_settings.dart';
import '../../repositories/authentication_repository.dart';
import '../../repositories/health_repository.dart';
import '../../services/open_food_facts_service.dart';
import '../../state/app_controller.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/common/choice_card.dart';
import '../../widgets/common/primary_button.dart';
import '../../widgets/onboarding/onboarding_scaffold.dart';
import 'basic_info_screen.dart';

/// 初回オンボーディング: Health 連携の選択。
class HealthSetupScreen extends StatefulWidget {
  const HealthSetupScreen({
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
  State<HealthSetupScreen> createState() => _HealthSetupScreenState();
}

class _HealthSetupScreenState extends State<HealthSetupScreen> {
  bool? _useHealthIntegration;
  bool _isLoading = false;

  Future<void> _continueWithHealth() async {
    setState(() => _isLoading = true);

    final granted = await widget.healthRepository.requestPermissions();
    final profileData = granted
        ? await widget.healthRepository.fetchProfileData()
        : HealthProfileData.empty;

    widget.controller.setNutritionSettings(
      const NutritionSettings(useHealthIntegration: true),
    );
    await widget.controller.applyHealthProfileData(profileData);

    if (!mounted) {
      return;
    }

    setState(() => _isLoading = false);

    if (!granted || !profileData.hasAnyValue) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.healthRepository.lastFailureMessage ??
                'Healthデータを取得できませんでした。取得できない項目は手入力してください。',
          ),
        ),
      );
    }

    _openBasicInfo(profileData);
  }

  void _continueWithoutHealth() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => BasicInfoScreen(
          controller: widget.controller,
          openFoodFactsService: widget.openFoodFactsService,
          healthPrefill: HealthProfileData.empty,
          authenticationRepository: widget.authenticationRepository,
        ),
      ),
    );
  }

  void _openBasicInfo(HealthProfileData prefill) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => BasicInfoScreen(
          controller: widget.controller,
          openFoodFactsService: widget.openFoodFactsService,
          healthPrefill: prefill,
          authenticationRepository: widget.authenticationRepository,
        ),
      ),
    );
  }

  void _continueNext() {
    if (_useHealthIntegration == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Health連携の利用有無を選択してください')));
      return;
    }

    if (_useHealthIntegration!) {
      _continueWithHealth();
    } else {
      _continueWithoutHealth();
    }
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingScaffold(
      showLogo: false,
      wrapBodyInCard: false,
      stepLabel: '初回設定 1/3',
      stepIndex: 0,
      title: 'Healthと連携しますか？',
      subtitle: 'Appleのヘルスケアと連携すると、歩数や運動のデータが自動で取り込まれ、入力の手間を減らすことができます。',
      body: Column(
        children: [
          ChoiceCard(
            title: '連携する（推奨）',
            subtitle: '歩数や運動のデータを自動で取り込み、よりかんたんに記録できます。',
            selected: _useHealthIntegration == true,
            onTap: _isLoading
                ? null
                : () => setState(() => _useHealthIntegration = true),
          ),
          const SizedBox(height: AppSpacing.sm),
          ChoiceCard(
            title: '連携しない',
            subtitle: 'あとから設定することもできます。すべて手動で入力します。',
            selected: _useHealthIntegration == false,
            onTap: _isLoading
                ? null
                : () => setState(() => _useHealthIntegration = false),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            widget.healthRepository.isAvailable
                ? 'お使いの端末がHealthに対応していない場合は、手動での入力方法をご案内します。'
                : 'この端末では Health 連携に対応していません。',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
      action: PrimaryButton(
        label: '次へ',
        trailingChevron: true,
        loading: _isLoading,
        onPressed: _isLoading ? null : _continueNext,
      ),
    );
  }
}
