import 'package:flutter/material.dart';

import '../../models/health_profile_data.dart';
import '../../models/nutrition_settings.dart';
import '../../repositories/authentication_repository.dart';
import '../../repositories/health_repository.dart';
import '../../services/open_food_facts_service.dart';
import '../../state/app_controller.dart';
import '../../theme/app_spacing.dart';
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

    if (!granted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Healthデータを取得できませんでした。取得できない項目は手入力してください。'),
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
    return Scaffold(
      appBar: AppBar(title: const Text('Health連携')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            Text(
              'Apple Health / Health Connect と連携しますか？',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: AppSpacing.lg),
            RadioListTile<bool>(
              title: const Text('利用する（推奨）'),
              value: true,
              groupValue: _useHealthIntegration,
              onChanged: _isLoading
                  ? null
                  : (value) => setState(() => _useHealthIntegration = value),
            ),
            RadioListTile<bool>(
              title: const Text('利用しない'),
              value: false,
              groupValue: _useHealthIntegration,
              onChanged: _isLoading
                  ? null
                  : (value) => setState(() => _useHealthIntegration = value),
            ),
            if (!widget.healthRepository.isAvailable)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xs),
                child: Text(
                  'この端末では Health 連携に対応していません。',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton(
              onPressed: _isLoading ? null : _continueNext,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('次へ'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
