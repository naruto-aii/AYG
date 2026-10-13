import 'dart:async';

import 'package:flutter/material.dart';

import '../../constants/app_strings.dart';
import '../../config/demo_mode.dart';
import '../../models/display_name.dart';
import '../../models/health_profile_data.dart';
import '../../models/nutrition_settings.dart';
import '../../models/user_profile.dart';
import '../../repositories/authentication_repository.dart';
import '../../repositories/health_repository.dart';
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
/// ユーザー名を最初に入れ、続けて生年月日・性別・身長・体重を入れる。
///
/// ユーザー名の初期値は、サインインが名前を返したときだけ入れる。
/// Health の取得項目に氏名は無いので、Health からは入れない。
/// 生年月日・性別・身長・体重は、Health から取れた値を入れたうえで、その場で直せる。
class BasicInfoScreen extends StatefulWidget {
  const BasicInfoScreen({
    super.key,
    required this.controller,
    required this.openFoodFactsService,
    required this.healthPrefill,
    required this.authenticationRepository,
    required this.healthRepository,
  });

  final AppController controller;
  final OpenFoodFactsService openFoodFactsService;
  final HealthProfileData healthPrefill;
  final AuthenticationRepository authenticationRepository;
  final HealthRepository healthRepository;

  @override
  State<BasicInfoScreen> createState() => _BasicInfoScreenState();
}

class _BasicInfoScreenState extends State<BasicInfoScreen> {
  DateTime? _birthDate;
  Gender? _gender;
  final _nameController = TextEditingController();
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _nameController.text = DisplayName.fieldValue(
      suggested:
          widget.authenticationRepository.currentUser?.suggestedDisplayName,
    );
    _applyPrefill(widget.healthPrefill);
    if (calonaviDemoMode && _birthDate == null) {
      _birthDate = DateTime(1996, 4, 12);
      _gender = Gender.female;
      _heightController.text = '162';
      _weightController.text = '54.0';
    }
    unawaited(_requestHealthOnOpen());
  }

  void _applyPrefill(HealthProfileData data) {
    _birthDate ??= data.birthDate;
    _gender ??= data.gender;
    if (_heightController.text.trim().isEmpty && data.heightCm != null) {
      _heightController.text = data.heightCm!.toStringAsFixed(0);
    }
    if (_weightController.text.trim().isEmpty && data.weightKg != null) {
      _weightController.text = data.weightKg!.toStringAsFixed(1);
    }
  }

  /// 説明画面は置かない。基本情報を開いた時点で HealthKit の許可を求める。
  /// 断ったとき、対応していない端末のときは、この画面の手入力のまま進める。
  Future<void> _requestHealthOnOpen() async {
    final health = widget.healthRepository;
    final granted = await health.requestPermissions();
    if (!mounted || !health.isAvailable || !granted) {
      if (mounted && health.isAvailable && !granted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Healthデータを取得できませんでした。取得できない項目は手入力してください。'),
          ),
        );
      }
      return;
    }

    final current = widget.controller.nutritionSettings;
    widget.controller.setNutritionSettings(
      (current ?? const NutritionSettings(useHealthIntegration: true)).copyWith(
        useHealthIntegration: true,
      ),
    );
    final profile = await health.fetchProfileData();
    if (!mounted) {
      return;
    }
    await widget.controller.applyHealthProfileData(profile);
    if (!mounted) {
      return;
    }
    setState(() => _applyPrefill(profile));
  }

  @override
  void dispose() {
    _nameController.dispose();
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
    if (picked == null || !mounted) {
      return;
    }
    setState(() => _birthDate = picked);
  }

  void _warn(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _goNext() {
    final displayName = _nameController.text.trim();
    final nameError = displayNameValidationMessage(displayName);
    if (nameError != null) {
      _warn(nameError);
      return;
    }

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
        displayName: displayName,
      ),
    );

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        settings: const RouteSettings(
          name: 'basic_info_screen_MaterialPageRoute_0',
        ),
        builder: (context) => GoalSetupScreen(
          controller: widget.controller,
          openFoodFactsService: widget.openFoodFactsService,
          authenticationRepository: widget.authenticationRepository,
          healthRepository: widget.healthRepository,
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
          child: Center(child: StepIndicator(current: 1, total: 2)),
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
          Expanded(
            child: DesignButton(label: '次へ', onPressed: _goNext),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 10),
          Text('基本情報を入力', style: AppTypography.headingXl),
          const SizedBox(height: 4),
          Text(
            'ユーザー名は、この画面でも設定からでも変えられます。取得できなかった項目は手入力してください',
            style: AppTypography.bodyS.copyWith(color: AppColors.textMuted),
          ),
          const SizedBox(height: 12),
          DesignFieldCard(
            icon: _fieldIcon(AppIcons.user),
            label: AppStrings.displayName,
            child: DesignInputBox(
              child: DesignTextInput(
                key: const ValueKey('profile_display_name'),
                controller: _nameController,
                hintText: AppStrings.displayNameHint,
              ),
            ),
          ),
          const SizedBox(height: 10),
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
