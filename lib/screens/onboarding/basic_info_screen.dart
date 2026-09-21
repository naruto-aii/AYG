import 'package:flutter/material.dart';

import '../../models/health_profile_data.dart';
import '../../models/user_profile.dart';
import '../../repositories/authentication_repository.dart';
import '../../services/open_food_facts_service.dart';
import '../../state/app_controller.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_icons.dart';
import '../../theme/app_typography.dart';
import '../../widgets/design/design_button.dart';
import '../../widgets/design/design_field.dart';
import '../../widgets/design/design_page.dart';
import '../../widgets/design/design_segment.dart';
import '../../widgets/design/icon_circle.dart';
import '../../widgets/design/step_indicator.dart';
import 'goal_setup_screen.dart';

/// 初回オンボーディング: 基本情報の入力。
///
/// Figma: SP / 03 初回設定 2-3 基本情報（23:201）
///
/// Health から取得できた項目もあらかじめ入れたうえで表示する（Figma と同じく
/// 4 項目を常に見せる）。取得できた値もその場で直せる。
class BasicInfoScreen extends StatefulWidget {
  const BasicInfoScreen({
    super.key,
    required this.controller,
    required this.openFoodFactsService,
    required this.healthPrefill,
    required this.authenticationRepository,
  });

  final AppController controller;
  final OpenFoodFactsService openFoodFactsService;
  final HealthProfileData healthPrefill;
  final AuthenticationRepository authenticationRepository;

  @override
  State<BasicInfoScreen> createState() => _BasicInfoScreenState();
}

class _BasicInfoScreenState extends State<BasicInfoScreen> {
  DateTime? _birthDate;
  Gender? _gender;
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _birthDate = widget.healthPrefill.birthDate;
    _gender = widget.healthPrefill.gender;
    final height = widget.healthPrefill.heightCm;
    if (height != null) {
      _heightController.text = height.toStringAsFixed(0);
    }
    final weight = widget.healthPrefill.weightKg;
    if (weight != null) {
      _weightController.text = weight.toStringAsFixed(1);
    }
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
      initialDate: _birthDate ?? DateTime(now.year - 24, now.month, now.day),
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

  void _goNext() {
    final birthDate = _birthDate;
    if (birthDate == null) {
      _warn('生年月日を選択してください');
      return;
    }

    final gender = _gender;
    if (gender == null) {
      _warn('性別を選択してください');
      return;
    }

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

    widget.controller.setProfile(
      UserProfile(
        birthDate: birthDate,
        gender: gender,
        heightCm: height,
        weightKg: weight,
      ),
    );

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => GoalSetupScreen(
          controller: widget.controller,
          openFoodFactsService: widget.openFoodFactsService,
          authenticationRepository: widget.authenticationRepository,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final birthDate = _birthDate;
    final birthDateLabel = birthDate == null
        ? '選択してください'
        : '${birthDate.year}年 ${birthDate.month}月 ${birthDate.day}日';

    return DesignPage(
      bodyPadding: const EdgeInsets.symmetric(horizontal: 20),
      header: const SizedBox(
        height: 56,
        child: Padding(
          padding: EdgeInsets.only(top: 12),
          child: Center(child: StepIndicator(current: 2)),
        ),
      ),
      bottomBar: Row(
        children: [
          Expanded(
            child: DesignButton(
              label: '戻る',
              style: DesignButtonStyle.outline,
              showTrailingIcon: false,
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: DesignButton(label: '次へ', onPressed: _goNext)),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 10),
          Text('基本情報を入力', style: AppTypography.headingXl),
          const SizedBox(height: 4),
          Text(
            '取得できなかった項目は手入力してください',
            style: AppTypography.bodyS.copyWith(color: AppColors.textMuted),
          ),
          const SizedBox(height: 12),
          DesignFieldCard(
            icon: _fieldIcon(AppIcons.calendar),
            label: '生年月日',
            child: DesignInputBox(
              onTap: _pickBirthDate,
              child: Text(
                birthDateLabel,
                style: AppTypography.bodyL.copyWith(
                  color: birthDate == null
                      ? AppColors.textMuted
                      : AppColors.textPrimary,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          DesignFieldCard(
            icon: _fieldIcon(AppIcons.gender),
            label: '性別',
            verticalPadding: 18,
            child: DesignSegmentGroup<Gender>(
              values: Gender.values,
              labelOf: (gender) => gender.label,
              selected: _gender ?? Gender.male,
              onChanged: (gender) => setState(() => _gender = gender),
            ),
          ),
          const SizedBox(height: 10),
          DesignFieldCard(
            icon: _fieldIcon(AppIcons.height),
            label: '身長（cm）',
            child: DesignInputBox(
              suffix: 'cm',
              child: DesignTextInput(
                controller: _heightController,
                hintText: '170',
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          DesignFieldCard(
            icon: _fieldIcon(AppIcons.scale),
            label: '現在体重（kg）',
            child: DesignInputBox(
              suffix: 'kg',
              child: DesignTextInput(
                controller: _weightController,
                hintText: '60.0',
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _fieldIcon(String asset) {
    return AppIcon(
      asset,
      size: 24,
      color: IconCircle.foregroundOf(IconCircleTone.green),
    );
  }
}
