import 'package:flutter/material.dart';

import '../../models/food_report.dart';
import '../../models/saved_food.dart';
import '../../state/app_controller.dart';
import '../../utils/food_report_display_labels.dart';

Future<bool> showPublicFoodReportDialog({
  required BuildContext context,
  required AppController controller,
  required SavedFood food,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) =>
        _PublicFoodReportDialog(controller: controller, food: food),
  );
  return result ?? false;
}

class _PublicFoodReportDialog extends StatefulWidget {
  const _PublicFoodReportDialog({required this.controller, required this.food});

  final AppController controller;
  final SavedFood food;

  @override
  State<_PublicFoodReportDialog> createState() =>
      _PublicFoodReportDialogState();
}

class _PublicFoodReportDialogState extends State<_PublicFoodReportDialog> {
  FoodReportReasonCode _reason = FoodReportReasonCode.incorrectNutrition;
  final _detailController = TextEditingController();
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _detailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSubmitting) {
      return;
    }
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final result = await widget.controller.submitPublicFoodReport(
      food: widget.food,
      reasonCode: _reason,
      detailText: _detailController.text.trim().isEmpty
          ? null
          : _detailController.text.trim(),
    );

    if (!mounted) {
      return;
    }

    if (result.success) {
      Navigator.of(context).pop(true);
      return;
    }

    setState(() {
      _isSubmitting = false;
      _errorMessage = result.errorMessage ?? '通報に失敗しました';
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('公開食品を通報'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('「${widget.food.name}」'),
            const SizedBox(height: 12),
            DropdownButtonFormField<FoodReportReasonCode>(
              initialValue: _reason,
              decoration: const InputDecoration(
                labelText: '理由',
                border: OutlineInputBorder(),
              ),
              items: FoodReportReasonCode.values
                  .map(
                    (code) => DropdownMenuItem(
                      value: code,
                      child: Text(FoodReportDisplayLabels.reason(code)),
                    ),
                  )
                  .toList(),
              onChanged: _isSubmitting
                  ? null
                  : (value) {
                      if (value != null) {
                        setState(() => _reason = value);
                      }
                    },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _detailController,
              decoration: const InputDecoration(
                labelText: '詳細（任意）',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              enabled: !_isSubmitting,
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting
              ? null
              : () => Navigator.of(context).pop(false),
          child: const Text('キャンセル'),
        ),
        FilledButton(
          onPressed: _isSubmitting ? null : _submit,
          child: _isSubmitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('通報する'),
        ),
      ],
    );
  }
}
