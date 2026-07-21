import 'package:flutter/material.dart';

import '../../state/app_controller.dart';
import '../../theme/app_spacing.dart';

class WeightRecordScreen extends StatefulWidget {
  const WeightRecordScreen({
    super.key,
    required this.controller,
    this.initialWeightKg,
  });

  final AppController controller;
  final double? initialWeightKg;

  @override
  State<WeightRecordScreen> createState() => _WeightRecordScreenState();
}

class _WeightRecordScreenState extends State<WeightRecordScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _weightController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _weightController = TextEditingController(
      text: widget.initialWeightKg?.toStringAsFixed(1) ?? '',
    );
  }

  @override
  void dispose() {
    _weightController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_formKey.currentState?.validate() != true) {
      return;
    }

    setState(() => _isSaving = true);
    await widget.controller.recordManualWeight(
      double.parse(_weightController.text),
    );

    if (!mounted) {
      return;
    }

    setState(() => _isSaving = false);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('体重を記録しました')));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('体重を記録')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              Text(
                '今日の体重を入力してください',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              if (widget.controller.useHealthIntegration) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Health同期がONの場合、Healthの体重を優先して利用します。',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              TextFormField(
                controller: _weightController,
                decoration: const InputDecoration(
                  labelText: '体重 (kg)',
                  border: OutlineInputBorder(),
                  suffixText: 'kg',
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '体重を入力してください';
                  }
                  final parsed = double.tryParse(value);
                  if (parsed == null || parsed < 30 || parsed > 300) {
                    return '30〜300 kg の範囲で入力してください';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.lg),
              FilledButton(
                onPressed: _isSaving ? null : _save,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('記録する'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
