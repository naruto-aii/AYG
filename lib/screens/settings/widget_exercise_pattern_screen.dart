import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/met_activity_catalog.dart';
import '../../models/exercise_quantity_unit.dart';
import '../../services/lock_screen_meal.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../utils/id_generator.dart';
import '../../widgets/design/design_button.dart';
import '../../widgets/design/design_field.dart';
import '../../widgets/design/design_page.dart';

/// ウィジェット専用の運動パターン。運動テンプレートの一覧には保存しない。
class WidgetExercisePatternScreen extends StatefulWidget {
  const WidgetExercisePatternScreen({super.key, required this.initial});

  final List<WidgetExercisePattern> initial;

  @override
  State<WidgetExercisePatternScreen> createState() =>
      _WidgetExercisePatternScreenState();
}

class _WidgetExercisePatternScreenState
    extends State<WidgetExercisePatternScreen> {
  late final List<WidgetExercisePattern> _items = [...widget.initial];
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<MetActivityDefinition> get _results {
    return MetActivityCatalog.search(_query).take(8).toList();
  }

  Future<void> _add(MetActivityDefinition activity) async {
    final amount = await showDialog<double>(
      context: context,
      builder: (context) => _AmountDialog(activity: activity),
    );
    if (amount == null || amount <= 0 || !mounted) {
      return;
    }
    final distance = activity.quantityUnit == ExerciseQuantityUnit.distanceKm;
    setState(() {
      _items.add(
        WidgetExercisePattern(
          itemId: generateUniqueId(),
          activityId: activity.id,
          name: activity.displayName,
          sortOrder: _items.length + 1,
          durationMin: distance ? 0 : amount.round(),
          distanceKm: distance ? amount : null,
        ),
      );
      _searchController.clear();
      _query = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final results = _results;
    return DesignPage(
      bottomBar: DesignButton(
        label: 'この内容にする',
        showTrailingIcon: false,
        onPressed: () => Navigator.of(context).pop(_items),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const DesignTitleBlock(
            title: '運動パターン',
            subtitle: 'この内容はウィジェット専用です。運動テンプレートの一覧には入りません。',
          ),
          if (_items.isEmpty)
            Text(
              '種目はまだありません',
              style: AppTypography.bodyM.copyWith(color: AppColors.textMuted),
            )
          else
            for (var index = 0; index < _items.length; index++) ...[
              if (index > 0) const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widgetExercisePatternLabel(_items[index]),
                      style: AppTypography.bodyL,
                    ),
                  ),
                  TextButton(
                    onPressed: () => setState(() => _items.removeAt(index)),
                    child: Text(
                      '外す',
                      style: AppTypography.labelM.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          const SizedBox(height: AppSpacing.md),
          DesignInputBox(
            child: DesignTextInput(
              controller: _searchController,
              hintText: '種目名を入力',
              onChanged: (value) => setState(() => _query = value),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final activity in results)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => _add(activity),
                child: Text(activity.displayName, style: AppTypography.bodyL),
              ),
            ),
        ],
      ),
    );
  }
}

class _AmountDialog extends StatefulWidget {
  const _AmountDialog({required this.activity});

  final MetActivityDefinition activity;

  @override
  State<_AmountDialog> createState() => _AmountDialogState();
}

class _AmountDialogState extends State<_AmountDialog> {
  final _controller = TextEditingController();

  bool get _distance =>
      widget.activity.quantityUnit == ExerciseQuantityUnit.distanceKm;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final amount = double.tryParse(_controller.text.trim());
    if (amount == null || amount <= 0) {
      return;
    }
    if (!_distance && amount.round() <= 0) {
      return;
    }
    Navigator.of(context).pop(_distance ? amount : amount.roundToDouble());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.activity.displayName),
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
        decoration: InputDecoration(labelText: _distance ? '距離（km）' : '時間（分）'),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('キャンセル'),
        ),
        TextButton(onPressed: _submit, child: const Text('追加')),
      ],
    );
  }
}

String widgetExercisePatternLabel(WidgetExercisePattern pattern) {
  final name = pattern.name.trim().isEmpty ? pattern.activityId : pattern.name;
  final distance = pattern.distanceKm;
  if (distance != null && distance > 0) {
    return '$name ${_formatKm(distance)}km';
  }
  if (pattern.durationMin > 0) {
    return '$name ${pattern.durationMin}分';
  }
  return name;
}

String _formatKm(double km) {
  final text = km.toStringAsFixed(1);
  if (text.endsWith('.0')) {
    return text.substring(0, text.length - 2);
  }
  return text;
}
