import 'package:flutter/material.dart';

import '../../constants/app_strings.dart';
import '../../models/user_profile.dart';
import '../../state/app_controller.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_icons.dart';
import '../../theme/app_typography.dart';
import '../../widgets/design/design_button.dart';
import '../../widgets/design/design_field.dart';
import '../../widgets/design/design_page.dart';
import '../../widgets/design/design_segment.dart';
import '../../widgets/design/icon_circle.dart';

class SettingsBasicInfoScreen extends StatefulWidget {
  const SettingsBasicInfoScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<SettingsBasicInfoScreen> createState() =>
      _SettingsBasicInfoScreenState();
}

class _SettingsBasicInfoScreenState extends State<SettingsBasicInfoScreen> {
  late DateTime _birthDate;
  late Gender _gender;
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final profile = widget.controller.profile!;
    _birthDate = profile.birthDate;
    _gender = profile.gender;
    _heightController.text = profile.heightCm.toStringAsFixed(0);
    _weightController.text = profile.weightKg.toStringAsFixed(1);
  }

  @override
  void dispose() {
    _heightController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate,
      firstDate: DateTime(1900),
      lastDate: now,
    );
    if (picked != null) {
      setState(() => _birthDate = picked);
    }
  }

  void _warn(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _save() async {
    final height = double.tryParse(_heightController.text.trim());
    if (height == null || height < 100 || height > 250) {
      _warn('身長は 100〜250 cm の範囲で入力してください');
      return;
    }
    final weight = double.tryParse(_weightController.text.trim());
    if (weight == null || weight < 30 || weight > 300) {
      _warn('現在体重は 30〜300 kg の範囲で入力してください');
      return;
    }

    setState(() => _isSaving = true);
    await widget.controller.updateBasicProfile(
      birthDate: _birthDate,
      gender: _gender,
      heightCm: height,
      manualWeightKg: weight,
    );
    if (!mounted) {
      return;
    }
    setState(() => _isSaving = false);
    _warn('保存しました');
    Navigator.of(context).pop();
  }

  Widget _icon(String asset) => AppIcon(
    asset,
    size: 24,
    color: IconCircle.foregroundOf(IconCircleTone.green),
  );

  @override
  Widget build(BuildContext context) {
    final useHealth = widget.controller.useHealthIntegration;
    final weightNote = useHealth
        ? '${widget.controller.weightDataSourceLabel}\n${AppStrings.weightManualOverwriteNotice}'
        : widget.controller.weightDataSourceLabel;

    return DesignPage(
      bottomBar: DesignButton(
        label: AppStrings.save,
        showTrailingIcon: false,
        loading: _isSaving,
        onPressed: _isSaving ? null : _save,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const DesignTitleBlock(
            title: AppStrings.settingsBasicInfo,
            subtitle: 'Health から取れた値も、ここで直せます。',
          ),
          DesignFieldCard(
            icon: _icon(AppIcons.calendar),
            label: AppStrings.birthDate,
            child: DesignInputBox(
              onTap: _pickBirthDate,
              child: Text(
                '${_birthDate.year}年 ${_birthDate.month}月 ${_birthDate.day}日',
                style: AppTypography.bodyL.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          DesignFieldCard(
            icon: _icon(AppIcons.gender),
            label: AppStrings.gender,
            verticalPadding: 18,
            child: DesignSegmentGroup<Gender>(
              values: Gender.values,
              labelOf: (gender) => gender.label,
              selected: _gender,
              onChanged: (gender) => setState(() => _gender = gender),
            ),
          ),
          const SizedBox(height: 10),
          DesignFieldCard(
            icon: _icon(AppIcons.height),
            label: AppStrings.heightCm,
            child: DesignInputBox(
              suffix: 'cm',
              child: DesignTextInput(
                controller: _heightController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          DesignFieldCard(
            icon: _icon(AppIcons.scale),
            label: AppStrings.currentWeightKg,
            child: DesignInputBox(
              suffix: 'kg',
              child: DesignTextInput(
                controller: _weightController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            weightNote,
            style: AppTypography.caption.copyWith(color: AppColors.textMuted),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
