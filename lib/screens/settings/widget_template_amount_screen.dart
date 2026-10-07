import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/met_activity_catalog.dart';
import '../../models/exercise_quantity_unit.dart';
import '../../models/food_unit_type.dart';
import '../../models/meal_template.dart';
import '../../models/meal_template_draft.dart';
import '../../models/workout_template.dart';
import '../../services/lock_screen_meal.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../utils/id_generator.dart';
import '../../utils/nutrition_format.dart';
import '../../widgets/design/design_button.dart';
import '../../widgets/design/design_card.dart';
import '../../widgets/design/design_field.dart';
import '../../widgets/design/design_page.dart';

/// 入力欄の数字。0 以下や空は受け付けない。
double? parseWidgetAmount(String raw) {
  final text = raw.trim().replaceAll(',', '');
  if (text.isEmpty) {
    return null;
  }
  final value = double.tryParse(text);
  if (value == null || !value.isFinite || value <= 0) {
    return null;
  }
  return value;
}

String _formatAmount(double value) {
  if (value == value.roundToDouble()) {
    return value.toInt().toString();
  }
  final text = value.toStringAsFixed(1);
  return text.endsWith('.0') ? text.substring(0, text.length - 2) : text;
}

/// テンプレートの食品ごとに量を入れ、ウィジェットの枠の中身にする。
///
/// 保存先はウィジェットの枠だけ。元の食事テンプレートは変えない。
class WidgetMealAmountScreen extends StatefulWidget {
  const WidgetMealAmountScreen({
    super.key,
    required this.templateName,
    required this.items,
  });

  final String templateName;
  final List<MealTemplateItem> items;

  @override
  State<WidgetMealAmountScreen> createState() => _WidgetMealAmountScreenState();
}

class _WidgetMealAmountScreenState extends State<WidgetMealAmountScreen> {
  late final List<TextEditingController> _amounts = [
    for (final item in widget.items)
      TextEditingController(text: _formatAmount(item.consumedAmount)),
  ];

  @override
  void dispose() {
    for (final controller in _amounts) {
      controller.dispose();
    }
    super.dispose();
  }

  double? _kcalFor(int index) {
    final item = widget.items[index];
    final amount = parseWidgetAmount(_amounts[index].text);
    final kcal = item.kcalPerBase;
    if (amount == null || kcal == null || item.baseAmount <= 0) {
      return null;
    }
    return kcal * amount / item.baseAmount;
  }

  double get _total {
    var total = 0.0;
    for (var i = 0; i < widget.items.length; i++) {
      total += _kcalFor(i) ?? 0;
    }
    return total;
  }

  void _submit() {
    final drafts = <MealTemplateItemDraft>[];
    for (var i = 0; i < widget.items.length; i++) {
      final amount = parseWidgetAmount(_amounts[i].text);
      if (amount == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('量は0より大きい数字にしてください')),
        );
        return;
      }
      drafts.add(
        MealTemplateItemDraft.fromTemplateItem(
          widget.items[i],
        ).copyWith(consumedAmount: amount).copyWithSortOrder(i + 1),
      );
    }
    Navigator.of(context).pop(
      MealTemplateDraft(name: widget.templateName, items: drafts),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DesignPage(
      bottomBar: DesignButton(
        key: const Key('widget-template-amount-save'),
        label: 'この量にする',
        showTrailingIcon: false,
        onPressed: widget.items.isEmpty ? null : _submit,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DesignTitleBlock(
            title: widget.templateName,
            subtitle: '食品ごとに、ウィジェットで登録する量を入れます。元のテンプレートは変わりません。',
          ),
          for (var i = 0; i < widget.items.length; i++) ...[
            if (i > 0) const SizedBox(height: AppSpacing.md),
            Text(widget.items[i].name, style: AppTypography.labelM),
            const SizedBox(height: 6),
            DesignInputBox(
              suffix: widget.items[i].unitType.label,
              child: DesignTextInput(
                controller: _amounts[i],
                inputKey: Key('widget-template-amount-$i'),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                ],
                onChanged: (_) => setState(() {}),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          DesignCard(
            elevated: false,
            child: Text(
              '合計 約${formatNullableNutrient(_total)}kcal',
              key: const Key('widget-template-amount-total'),
              style: AppTypography.titleM,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
      ),
    );
  }
}

/// ウィジェットで登録できる種目か。手入力の種目と一覧に無い種目は外す。
bool widgetWorkoutItemUsable(WorkoutTemplateItem item) {
  final activity = MetActivityCatalog.findById(item.activityId);
  return activity != null && !activity.requiresManualKcal;
}

/// 運動テンプレートの種目ごとに時間（または距離）を入れ、ウィジェットの枠の中身にする。
class WidgetWorkoutAmountScreen extends StatefulWidget {
  const WidgetWorkoutAmountScreen({
    super.key,
    required this.templateName,
    required this.items,
  });

  final String templateName;
  final List<WorkoutTemplateItem> items;

  @override
  State<WidgetWorkoutAmountScreen> createState() =>
      _WidgetWorkoutAmountScreenState();
}

class _WorkoutRow {
  _WorkoutRow(this.item, this.activity, this.distance, String initial)
    : controller = TextEditingController(text: initial);

  final WorkoutTemplateItem item;
  final MetActivityDefinition activity;
  final bool distance;
  final TextEditingController controller;
}

class _WidgetWorkoutAmountScreenState extends State<WidgetWorkoutAmountScreen> {
  late final List<_WorkoutRow> _rows = _buildRows();
  late final int _skipped = widget.items.length - _rows.length;

  List<_WorkoutRow> _buildRows() {
    final rows = <_WorkoutRow>[];
    for (final item in widget.items) {
      final activity = MetActivityCatalog.findById(item.activityId);
      if (activity == null || activity.requiresManualKcal) {
        continue;
      }
      final distance = activity.quantityUnit == ExerciseQuantityUnit.distanceKm;
      var initial = '';
      if (distance) {
        final speed = activity.referenceSpeedKmh;
        if (speed != null && speed > 0 && item.durationMin > 0) {
          final km = (item.durationMin / 60 * speed * 10).round() / 10;
          if (km > 0) {
            initial = _formatAmount(km);
          }
        }
      } else if (item.durationMin > 0) {
        initial = item.durationMin.toString();
      }
      rows.add(_WorkoutRow(item, activity, distance, initial));
    }
    return rows;
  }

  @override
  void dispose() {
    for (final row in _rows) {
      row.controller.dispose();
    }
    super.dispose();
  }

  void _submit() {
    final patterns = <WidgetExercisePattern>[];
    for (var i = 0; i < _rows.length; i++) {
      final row = _rows[i];
      final amount = parseWidgetAmount(row.controller.text);
      if (amount == null || (!row.distance && amount.round() <= 0)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('量は0より大きい数字にしてください')),
        );
        return;
      }
      patterns.add(
        WidgetExercisePattern(
          itemId: generateUniqueId(),
          activityId: row.activity.id,
          name: row.item.name.trim().isEmpty
              ? row.activity.displayName
              : row.item.name.trim(),
          sortOrder: i + 1,
          durationMin: row.distance ? 0 : amount.round(),
          distanceKm: row.distance ? amount : null,
        ),
      );
    }
    Navigator.of(context).pop(patterns);
  }

  @override
  Widget build(BuildContext context) {
    return DesignPage(
      bottomBar: DesignButton(
        key: const Key('widget-template-amount-save'),
        label: 'この量にする',
        showTrailingIcon: false,
        onPressed: _rows.isEmpty ? null : _submit,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DesignTitleBlock(
            title: widget.templateName,
            subtitle: '種目ごとに、ウィジェットで登録する時間か距離を入れます。元のテンプレートは変わりません。',
          ),
          if (_rows.isEmpty)
            Text(
              'このテンプレートには、ウィジェットで登録できる種目がありません。',
              style: AppTypography.bodyM.copyWith(color: AppColors.textMuted),
            ),
          for (var i = 0; i < _rows.length; i++) ...[
            if (i > 0) const SizedBox(height: AppSpacing.md),
            Text(_rows[i].item.name, style: AppTypography.labelM),
            const SizedBox(height: 6),
            DesignInputBox(
              suffix: _rows[i].distance ? 'km' : '分',
              child: DesignTextInput(
                controller: _rows[i].controller,
                inputKey: Key('widget-template-amount-$i'),
                keyboardType: TextInputType.numberWithOptions(
                  decimal: _rows[i].distance,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(
                    RegExp(_rows[i].distance ? r'[0-9.]' : r'[0-9]'),
                  ),
                ],
              ),
            ),
          ],
          if (_skipped > 0 && _rows.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              '手入力の種目など、ウィジェットで登録できない$_skipped件は外しています。',
              style: AppTypography.bodyS.copyWith(color: AppColors.textMuted),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
        ],
      ),
    );
  }
}
