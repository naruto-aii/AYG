import 'package:flutter/material.dart';

import '../../constants/app_strings.dart';
import '../../models/user_profile.dart';
import '../../state/app_controller.dart';
import '../../theme/app_spacing.dart';

class SettingsBasicInfoScreen extends StatefulWidget {
  const SettingsBasicInfoScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<SettingsBasicInfoScreen> createState() =>
      _SettingsBasicInfoScreenState();
}

class _SettingsBasicInfoScreenState extends State<SettingsBasicInfoScreen> {
  final _formKey = GlobalKey<FormState>();
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

  Future<void> _save() async {
    if (_formKey.currentState?.validate() != true) {
      return;
    }

    setState(() => _isSaving = true);
    await widget.controller.updateBasicProfile(
      birthDate: _birthDate,
      gender: _gender,
      heightCm: double.parse(_heightController.text),
      manualWeightKg: double.parse(_weightController.text),
    );
    if (!mounted) {
      return;
    }
    setState(() => _isSaving = false);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('保存しました')));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final birthDateLabel =
        '${_birthDate.year}/${_birthDate.month}/${_birthDate.day}';
    final useHealth = widget.controller.useHealthIntegration;

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.settingsBasicInfo)),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(AppStrings.birthDate),
                subtitle: Text(birthDateLabel),
                trailing: const Icon(Icons.calendar_today),
                onTap: _pickBirthDate,
              ),
              const SizedBox(height: AppSpacing.md),
              DropdownButtonFormField<Gender>(
                initialValue: _gender,
                decoration: const InputDecoration(
                  labelText: AppStrings.gender,
                  border: OutlineInputBorder(),
                ),
                items: Gender.values
                    .map(
                      (gender) => DropdownMenuItem(
                        value: gender,
                        child: Text(gender.label),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _gender = value);
                  }
                },
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _heightController,
                decoration: const InputDecoration(
                  labelText: AppStrings.heightCm,
                  border: OutlineInputBorder(),
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '身長を入力してください';
                  }
                  final parsed = double.tryParse(value);
                  if (parsed == null || parsed < 100 || parsed > 250) {
                    return '100〜250 cm の範囲で入力してください';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _weightController,
                decoration: InputDecoration(
                  labelText: AppStrings.currentWeightKg,
                  border: const OutlineInputBorder(),
                  helperText: useHealth
                      ? '${widget.controller.weightDataSourceLabel}\n${AppStrings.weightManualOverwriteNotice}'
                      : widget.controller.weightDataSourceLabel,
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '現在体重を入力してください';
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
                      : const Text(AppStrings.save),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
