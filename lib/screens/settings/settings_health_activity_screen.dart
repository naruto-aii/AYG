import 'package:flutter/material.dart';

import '../../constants/app_strings.dart';
import '../../models/activity_level.dart';
import '../../repositories/health_repository.dart';
import '../../state/app_controller.dart';
import '../../theme/app_spacing.dart';

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

  @override
  Widget build(BuildContext context) {
    final useHealth = _useHealthIntegration;

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.settingsHealthActivity)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(AppStrings.healthIntegration),
              subtitle: widget.healthRepository.isAvailable
                  ? null
                  : const Text(AppStrings.healthUnavailableOnDevice),
              value: useHealth,
              onChanged: _isBusy || !widget.healthRepository.isAvailable
                  ? null
                  : (value) async {
                      setState(() => _useHealthIntegration = value);
                      await _toggleHealth(value);
                    },
            ),
            if (useHealth) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                AppStrings.healthUsingActiveEnergy,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              OutlinedButton.icon(
                onPressed: _isBusy ? null : _resyncHealth,
                icon: const Icon(Icons.sync),
                label: const Text(AppStrings.healthResync),
              ),
            ],
            if (!useHealth) ...[
              const SizedBox(height: AppSpacing.lg),
              Text(
                AppStrings.activityLevel,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: AppSpacing.xs),
              ...ActivityLevel.values.map(
                (level) => RadioListTile<ActivityLevel>(
                  title: Text(AppStrings.activityLevelLabel(level)),
                  subtitle: Text('係数 ${level.factor}'),
                  value: level,
                  groupValue: _activityLevel,
                  onChanged: _isBusy
                      ? null
                      : (value) {
                          if (value != null) {
                            setState(() => _activityLevel = value);
                          }
                        },
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              FilledButton(
                onPressed: _isBusy ? null : _saveActivityLevel,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: _isBusy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text(AppStrings.save),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
