import 'package:flutter/material.dart';

import '../../constants/app_strings.dart';
import '../../models/activity_level.dart';
import '../../repositories/health_repository.dart';
import '../../state/app_controller.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../widgets/design/design_button.dart';
import '../../widgets/design/design_icon.dart';
import '../../widgets/design/design_page.dart';
import '../../widgets/design/select_card.dart';

class SettingsHealthActivityScreen extends StatefulWidget {
  const SettingsHealthActivityScreen({
    super.key,
    required this.controller,
    required this.healthRepository,
  });

  final AppController controller;
  final HealthRepository healthRepository;

  @override
  State<SettingsHealthActivityScreen> createState() =>
      _SettingsHealthActivityScreenState();
}

class _SettingsHealthActivityScreenState
    extends State<SettingsHealthActivityScreen> {
  late bool _useHealthIntegration;
  ActivityLevel? _activityLevel;
  bool _isBusy = false;

  @override
  void initState() {
    super.initState();
    final settings = widget.controller.nutritionSettings!;
    _useHealthIntegration = settings.useHealthIntegration;
    _activityLevel = settings.activityLevel ?? ActivityLevel.moderate;
  }

  Future<void> _toggleHealth(bool enabled) async {
    setState(() => _isBusy = true);

    if (enabled) {
      if (!widget.healthRepository.isAvailable) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text(AppStrings.healthUnavailableOnDevice)),
          );
        }
        setState(() {
          _isBusy = false;
          _useHealthIntegration = false;
        });
        return;
      }

      final granted = await widget.controller.enableHealthIntegration();
      if (!mounted) {
        return;
      }
      if (!granted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Healthデータを取得できませんでした。取得できない項目は手入力してください。'),
          ),
        );
      }
      setState(() {
        _useHealthIntegration = widget.controller.useHealthIntegration;
        _isBusy = false;
      });
      return;
    }

    await widget.controller.disableHealthIntegration(
      activityLevel: _activityLevel,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _useHealthIntegration = false;
      _isBusy = false;
    });
  }

  Future<void> _resyncHealth() async {
    setState(() => _isBusy = true);
    final success = await widget.controller.resyncHealthData();
    if (!mounted) {
      return;
    }
    setState(() => _isBusy = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success ? 'Healthデータを再取得しました' : 'Healthデータを取得できませんでした'),
      ),
    );
  }

  Future<void> _saveActivityLevel() async {
    if (_activityLevel == null) {
      return;
    }
    setState(() => _isBusy = true);
    await widget.controller.updateActivityLevel(_activityLevel!);
    if (!mounted) {
      return;
    }
    setState(() => _isBusy = false);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('保存しました')));
  }

  Future<void> _selectHealth(bool enabled) async {
    if (_isBusy || enabled == _useHealthIntegration) {
      return;
    }
    setState(() => _useHealthIntegration = enabled);
    await _toggleHealth(enabled);
  }

  @override
  Widget build(BuildContext context) {
    final useHealth = _useHealthIntegration;
    final available = widget.healthRepository.isAvailable;

    return DesignPage(
      bottomBar: useHealth
          ? null
          : DesignButton(
              label: AppStrings.save,
              showTrailingIcon: false,
              loading: _isBusy,
              onPressed: _isBusy ? null : _saveActivityLevel,
            ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const DesignTitleBlock(
            title: '活動・Health',
            subtitle: '歩数や運動の取り込み方を決めます。',
          ),
          SelectCard(
            title: '連携する（推奨）',
            description: available
                ? '歩数や運動のデータを自動で取り込み、\nよりカンタンに記録できます。'
                : AppStrings.healthUnavailableOnDevice,
            selected: useHealth,
            onTap: _isBusy || !available ? null : () => _selectHealth(true),
          ),
          const SizedBox(height: 14),
          SelectCard(
            title: '連携しない',
            description: 'すべて手動で入力します。\nあとから切り替えられます。',
            selected: !useHealth,
            onTap: _isBusy ? null : () => _selectHealth(false),
          ),
          if (useHealth) ...[
            const SizedBox(height: 14),
            Text(
              AppStrings.healthUsingActiveEnergy,
              style: AppTypography.bodyS.copyWith(color: AppColors.textMuted),
            ),
            const SizedBox(height: 14),
            DesignButton(
              label: AppStrings.healthResync,
              style: DesignButtonStyle.outline,
              showTrailingIcon: false,
              loading: _isBusy,
              leading: const DesignIcon(
                Symbols.sync_rounded,
                size: 20,
                color: AppColors.textBrand,
              ),
              onPressed: _isBusy ? null : _resyncHealth,
            ),
          ] else ...[
            const SizedBox(height: 22),
            Text(AppStrings.activityLevel, style: AppTypography.titleS),
            const SizedBox(height: 10),
            for (final level in ActivityLevel.values) ...[
              SelectCard(
                title: AppStrings.activityLevelLabel(level),
                description: AppStrings.activityLevelDescription(level),
                selected: _activityLevel == level,
                minHeight: 0,
                onTap: _isBusy
                    ? null
                    : () => setState(() => _activityLevel = level),
              ),
              const SizedBox(height: 10),
            ],
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
