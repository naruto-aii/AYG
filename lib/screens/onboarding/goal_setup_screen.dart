import 'package:flutter/material.dart';

import '../../models/activity_level.dart';
import '../../models/calculation/calorie_target_mode.dart';
import '../../models/goal.dart';
import '../../models/nutrition_settings.dart';
import '../../widgets/nutrition/calorie_target_editor.dart';
import '../../repositories/authentication_repository.dart';
import '../../repositories/health_repository.dart';
import '../../services/daily_calorie_target_planner.dart';
import '../../services/open_food_facts_service.dart';
import '../../services/weight_for_target.dart';
import '../../state/app_controller.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_icons.dart';
import '../../theme/app_typography.dart';
import '../../widgets/design/design_button.dart';
import '../../widgets/design/design_field.dart';
import '../../widgets/design/design_page.dart';
import '../../widgets/design/goal_card.dart';
import '../../widgets/design/icon_circle.dart';
import '../../widgets/design/step_indicator.dart';
import '../../widgets/design/warn_banner.dart';
import '../shell/main_shell_screen.dart';
import 'activity_level_screen.dart';
import '../../utils/user_error_message.dart';

/// 初回オンボーディング: 目標の設定。
///
/// Figma: SP / 04 初回設定 3-3 目標を設定（24:226）
class GoalSetupScreen extends StatefulWidget {
  const GoalSetupScreen({
    super.key,
    required this.controller,
    required this.openFoodFactsService,
    required this.authenticationRepository,
    required this.healthRepository,
  });

  final AppController controller;
  final OpenFoodFactsService openFoodFactsService;
  final AuthenticationRepository authenticationRepository;
  final HealthRepository healthRepository;

  @override
  State<GoalSetupScreen> createState() => _GoalSetupScreenState();
}

class _GoalSetupScreenState extends State<GoalSetupScreen> {
  /// 体重変化の安全な上限（体重の 1% / 週）。これを超えると注意を出す。
  static const double _maxWeeklyChangeRatio = 0.01;

  /// 「スキップ」で入れる既定の目標期間。
  static const Duration _defaultHorizon = Duration(days: 90);

  GoalType _goalType = GoalType.maintain;
  String? _automaticNotice;
  CalorieTargetMode _calorieMode = CalorieTargetMode.automatic;
  final _targetWeightController = TextEditingController();
  final _kcalController = TextEditingController();
  final _proteinController = TextEditingController();
  final _fatController = TextEditingController();
  final _carbController = TextEditingController();
  DateTime? _targetDate;

  double? get _currentWeightKg => widget.controller.profile?.weightKg;

  @override
  void initState() {
    super.initState();
    final current = _currentWeightKg;
    if (current != null) {
      _targetWeightController.text = current.toStringAsFixed(1);
    }
    _targetDate = DateTime.now().add(_defaultHorizon);
    _targetWeightController.addListener(_onInputChanged);
    widget.controller.addListener(_onInputChanged);
    _refreshAutomaticTargets();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onInputChanged);
    _targetWeightController
      ..removeListener(_onInputChanged)
      ..dispose();
    _kcalController.dispose();
    _proteinController.dispose();
    _fatController.dispose();
    _carbController.dispose();
    super.dispose();
  }

  /// 目標体重の入力と、体重・プロフィール・活動量の変更で計算し直す。
  void _onInputChanged() {
    if (!mounted) {
      return;
    }
    setState(_refreshAutomaticTargets);
  }

  /// 保存する予定の食事目標の設定。活動量は連携なしなら次の画面の既定（普通）。
  NutritionSettings get _pendingSettings {
    final current = widget.controller.nutritionSettings;
    return current ??
        NutritionSettings(
          useHealthIntegration: widget.controller.useHealthIntegration,
          activityLevel: widget.controller.useHealthIntegration
              ? null
              : ActivityLevel.moderate,
        );
  }

  /// 自動のあいだは、目標体重・目標日・方向性から4つの欄を埋める。
  /// プログラムからの書き込みは onChanged を通らないので、手入力には切り替わらない。
  void _refreshAutomaticTargets() {
    if (_calorieMode != CalorieTargetMode.automatic) {
      _automaticNotice = null;
      return;
    }
    final goalWeight = double.tryParse(_targetWeightController.text.trim());
    final targetDate = _targetDate;
    final goal =
        goalWeight == null ||
            goalWeight < 30 ||
            goalWeight > 300 ||
            targetDate == null
        ? null
        : Goal(
            type: _goalType,
            targetWeightKg: goalWeight,
            targetDate: targetDate,
          );
    final summary = goal == null
        ? null
        : widget.controller.previewAutomaticTargets(
            goal: goal,
            settings: _pendingSettings,
          );
    _automaticNotice = summary != null
        ? null
        : widget.controller.automaticTargetsUnavailableReason(
            goal: goal,
            settings: _pendingSettings,
            missingGoalItems: [
              if (goalWeight == null || goalWeight < 30 || goalWeight > 300)
                '目標体重（30〜300kg）',
              if (targetDate == null) '目標日',
            ],
          );
    _setTargetText(_kcalController, summary?.targetKcal);
    _setTargetText(_proteinController, summary?.targetProteinG);
    _setTargetText(_fatController, summary?.targetFatG);
    _setTargetText(_carbController, summary?.targetCarbG);
  }

  void _setTargetText(TextEditingController controller, double? value) {
    final text = value == null ? '' : value.round().toString();
    if (controller.text != text) {
      controller.text = text;
    }
  }

  String? get _arrivalNote {
    final goalWeight = double.tryParse(_targetWeightController.text.trim());
    final targetDate = _targetDate;
    final profile = widget.controller.profile;
    if (goalWeight == null || targetDate == null || profile == null) {
      return null;
    }
    final series = describeWeightSeries(
      samples: widget.controller.calculationWeightSamples(),
      reference: DateTime.now(),
      fallbackKg: profile.weightKg,
    );
    final current =
        series.smoothedKg ??
        (series.selection.kg > 0 ? series.selection.kg : profile.weightKg);
    return const DailyCalorieTargetPlanner().arrivalNote(
      currentWeightKg: current,
      goalWeightKg: goalWeight,
      goalType: _goalType,
      targetDate: targetDate,
    );
  }

  Future<void> _pickTargetDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _targetDate ?? now.add(_defaultHorizon),
      firstDate: now,
      lastDate: DateTime(now.year + 5),
    );
    if (picked == null || !mounted) {
      return;
    }
    setState(() {
      _targetDate = picked;
      _refreshAutomaticTargets();
    });
  }

  int get _daysLeft {
    final target = _targetDate;
    if (target == null) {
      return 0;
    }
    final today = DateTime.now();
    return DateTime(
      target.year,
      target.month,
      target.day,
    ).difference(DateTime(today.year, today.month, today.day)).inDays;
  }

  /// 期間に対して体重変化が急すぎるか。
  bool get _isPaceTooFast {
    final current = _currentWeightKg;
    final target = double.tryParse(_targetWeightController.text.trim());
    if (current == null || target == null || _goalType == GoalType.maintain) {
      return false;
    }
    final days = _daysLeft;
    if (days <= 0) {
      return true;
    }
    final weeklyChange = (target - current).abs() / (days / 7);
    return weeklyChange > current * _maxWeeklyChangeRatio;
  }

  void _warn(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _skip() async {
    final current = _currentWeightKg;
    if (current == null) {
      _warn('先に基本情報を入力してください');
      return;
    }
    await _save(
      Goal(
        type: GoalType.maintain,
        targetWeightKg: current,
        targetDate: DateTime.now().add(_defaultHorizon),
      ),
      updateCalorieTarget: false,
    );
  }

  Future<void> _complete() async {
    final targetDate = _targetDate;
    if (targetDate == null) {
      _warn('目標日を選択してください');
      return;
    }

    final targetWeight = double.tryParse(_targetWeightController.text.trim());
    if (targetWeight == null || targetWeight < 30 || targetWeight > 300) {
      _warn('目標体重は 30〜300 kg の範囲で入力してください');
      return;
    }

    if (_calorieMode == CalorieTargetMode.manual) {
      final message = validateManualCalorieTargets(
        kcalText: _kcalController.text,
        proteinText: _proteinController.text,
        fatText: _fatController.text,
        carbText: _carbController.text,
      );
      if (message != null) {
        _warn(message);
        return;
      }
    }

    await _save(
      Goal(
        type: _goalType,
        targetWeightKg: targetWeight,
        targetDate: targetDate,
      ),
    );
  }

  void _saveCalorieTarget() {
    final base = _pendingSettings;
    if (_calorieMode == CalorieTargetMode.manual) {
      widget.controller.setNutritionSettings(
        base.copyWith(
          calorieTargetMode: CalorieTargetMode.manual,
          manualTargetKcal: double.parse(_kcalController.text.trim()),
          manualProteinG: double.parse(_proteinController.text.trim()),
          manualFatG: double.parse(_fatController.text.trim()),
          manualCarbG: double.parse(_carbController.text.trim()),
        ),
      );
      return;
    }
    widget.controller.setNutritionSettings(
      base.copyWith(calorieTargetMode: CalorieTargetMode.automatic),
    );
  }

  Future<void> _save(Goal goal, {bool updateCalorieTarget = true}) async {
    if (updateCalorieTarget) {
      _saveCalorieTarget();
    }
    widget.controller.setGoal(goal);

    if (!widget.controller.useHealthIntegration) {
      if (!mounted) {
        return;
      }
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          settings: const RouteSettings(
            name: 'goal_setup_screen_MaterialPageRoute_0',
          ),
          builder: (context) => ActivityLevelScreen(
            controller: widget.controller,
            openFoodFactsService: widget.openFoodFactsService,
            authenticationRepository: widget.authenticationRepository,
            healthRepository: widget.healthRepository,
          ),
        ),
      );
      return;
    }

    try {
      await widget.controller.completeOnboarding();
    } catch (error) {
      if (!mounted) {
        return;
      }
      _warn(userErrorMessage(error, action: '保存'));
      return;
    }

    if (!mounted) {
      return;
    }

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(
        settings: const RouteSettings(
          name: 'goal_setup_screen_MaterialPageRoute_1',
        ),
        builder: (context) => MainShellScreen(
          controller: widget.controller,
          openFoodFactsService: widget.openFoodFactsService,
          authenticationRepository: widget.authenticationRepository,
          healthRepository: widget.healthRepository,
        ),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final targetDate = _targetDate;
    final currentWeight = _currentWeightKg;
    final days = _daysLeft;

    return DesignPage(
      bodyPadding: const EdgeInsets.symmetric(horizontal: 20),
      header: DesignHeader(
        trailing: InkWell(
          onTap: _skip,
          borderRadius: BorderRadius.circular(999),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            child: Text(
              'スキップ',
              style: AppTypography.labelM.copyWith(color: AppColors.textBrand),
            ),
          ),
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
            child: DesignButton(label: 'はじめる', onPressed: _complete),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 4),
          const Center(child: StepIndicator(current: 3)),
          const SizedBox(height: 10),
          Text(
            '目標を設定',
            textAlign: TextAlign.center,
            style: AppTypography.headingXl,
          ),
          const SizedBox(height: 8),
          Text(
            '目標体重と目標日から、\n1日の食事目標を出します。',
            textAlign: TextAlign.center,
            style: AppTypography.bodyM,
          ),
          const SizedBox(height: 18),
          Text('目標の方向性', style: AppTypography.titleS),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: GoalCard(
                  icon: _goalIcon(AppIcons.scale, GoalType.lose),
                  title: GoalType.lose.label,
                  description: '体重を減らしたい',
                  selected: _goalType == GoalType.lose,
                  onTap: () => _selectGoalType(GoalType.lose),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GoalCard(
                  icon: _goalIcon(AppIcons.human, GoalType.maintain),
                  title: GoalType.maintain.label,
                  description: '今の体重を\nキープしたい',
                  selected: _goalType == GoalType.maintain,
                  onTap: () => _selectGoalType(GoalType.maintain),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GoalCard(
                  icon: _goalIcon(AppIcons.dumbbell, GoalType.gain),
                  title: GoalType.gain.label,
                  description: '体重を増やしたい',
                  selected: _goalType == GoalType.gain,
                  onTap: () => _selectGoalType(GoalType.gain),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          DesignFieldCard(
            icon: AppIcon(
              AppIcons.scale,
              size: 24,
              color: IconCircle.foregroundOf(IconCircleTone.green),
            ),
            label: '目標体重（kg）',
            child: DesignInputBox(
              suffix: 'kg',
              child: DesignTextInput(
                controller: _targetWeightController,
                hintText: '60.0',
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            currentWeight == null
                ? '現在の体重：未登録'
                : '現在の体重：${currentWeight.toStringAsFixed(1)} kg',
            style: AppTypography.caption.copyWith(color: AppColors.textMuted),
          ),
          const SizedBox(height: 10),
          DesignFieldCard(
            icon: AppIcon(
              AppIcons.calendar,
              size: 24,
              color: IconCircle.foregroundOf(IconCircleTone.green),
            ),
            label: '目標日',
            child: DesignInputBox(
              onTap: _pickTargetDate,
              child: Text(
                targetDate == null
                    ? '選択してください'
                    : '${targetDate.year}年${targetDate.month}月${targetDate.day}日',
                style: AppTypography.bodyL.copyWith(
                  color: targetDate == null
                      ? AppColors.textMuted
                      : AppColors.textPrimary,
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            days > 0 ? 'あと 約${(days / 30).round()}か月（$days日）' : '目標日を選んでください',
            style: AppTypography.caption.copyWith(color: AppColors.textMuted),
          ),
          if (_arrivalNote != null) ...[
            const SizedBox(height: 8),
            Text(
              _arrivalNote!,
              style: AppTypography.caption.copyWith(color: AppColors.orange700),
            ),
          ],
          const SizedBox(height: 18),
          CalorieTargetEditor(
            mode: _calorieMode,
            onModeChanged: (mode) => setState(() {
              _calorieMode = mode;
              _refreshAutomaticTargets();
            }),
            onEdited: () {
              if (_calorieMode == CalorieTargetMode.manual) {
                return;
              }
              setState(() => _calorieMode = CalorieTargetMode.manual);
            },
            kcalController: _kcalController,
            proteinController: _proteinController,
            fatController: _fatController,
            carbController: _carbController,
            automaticNotice: _automaticNotice,
          ),
          if (_isPaceTooFast) ...[
            const SizedBox(height: 12),
            const WarnBanner(
              title: '期間がやや短めです。',
              description:
                  '目標達成のために、1日の摂取カロリーが\nやや少なめになる可能性があります。\n内容を確認して保存できます。',
            ),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  void _selectGoalType(GoalType type) {
    setState(() {
      _goalType = type;
      _refreshAutomaticTargets();
    });
  }

  Widget _goalIcon(String asset, GoalType type) {
    return AppIcon(
      asset,
      size: 32,
      color: _goalType == type
          ? AppColors.iconPrimary
          : AppColors.textSecondary,
    );
  }
}
