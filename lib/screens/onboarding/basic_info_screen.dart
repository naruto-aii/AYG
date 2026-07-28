import 'package:flutter/material.dart';

import '../../constants/app_strings.dart';
import '../../models/health_profile_data.dart';
import '../../models/user_profile.dart';
import '../../repositories/authentication_repository.dart';
import '../../services/open_food_facts_service.dart';
import '../../state/app_controller.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/common/app_text_field.dart';
import '../../widgets/common/primary_button.dart';
import '../../widgets/onboarding/onboarding_scaffold.dart';
import 'goal_setup_screen.dart';

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
  final _formKey = GlobalKey<FormState>();
  DateTime? _birthDate;
  Gender? _gender;
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();

  bool get _needsBirthDate => widget.healthPrefill.birthDate == null;
  bool get _needsGender => widget.healthPrefill.gender == null;
  bool get _needsHeight => widget.healthPrefill.heightCm == null;
  bool get _needsWeight => widget.healthPrefill.weightKg == null;

  @override
  void initState() {
    super.initState();
    _birthDate = widget.healthPrefill.birthDate;
    _gender = widget.healthPrefill.gender;
    if (widget.healthPrefill.heightCm != null) {
      _heightController.text = widget.healthPrefill.heightCm!.toStringAsFixed(
        0,
      );
    }
    if (widget.healthPrefill.weightKg != null) {
      _weightController.text = widget.healthPrefill.weightKg!.toStringAsFixed(
        1,
      );
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

  void _goNext() {
    if (_needsBirthDate && _birthDate == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('生年月日を選択してください')));
      return;
    }

    if (_needsGender && _gender == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('性別を選択してください')));
      return;
    }

    if (_formKey.currentState?.validate() != true) {
      return;
    }

    widget.controller.setProfile(
      UserProfile(
        birthDate: widget.healthPrefill.birthDate ?? _birthDate!,
        gender: widget.healthPrefill.gender ?? _gender!,
        heightCm:
            widget.healthPrefill.heightCm ??
            double.parse(_heightController.text),
        weightKg:
            widget.healthPrefill.weightKg ??
            double.parse(_weightController.text),
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
    final birthDateLabel = _birthDate == null
        ? AppStrings.notSelected
        : '${_birthDate!.year}/${_birthDate!.month}/${_birthDate!.day}';

    return Form(
      key: _formKey,
      child: OnboardingScaffold(
        title: '基礎情報入力',
        subtitle: 'あなたの基礎情報を入力してください',
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!_needsBirthDate ||
                !_needsGender ||
                !_needsHeight ||
                !_needsWeight)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: Text(
                  'Health から取得済みの項目は入力不要です。',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            if (_needsBirthDate) ...[
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(AppStrings.birthDate),
                subtitle: Text(birthDateLabel),
                trailing: const Icon(Icons.calendar_today_outlined),
                onTap: _pickBirthDate,
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            if (_needsGender) ...[
              DropdownButtonFormField<Gender>(
                initialValue: _gender,
                decoration: InputDecoration(labelText: AppStrings.gender),
                items: Gender.values
                    .map(
                      (gender) => DropdownMenuItem(
                        value: gender,
                        child: Text(gender.label),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() => _gender = value),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            if (_needsHeight) ...[
              AppTextField(
                controller: _heightController,
                label: AppStrings.heightCm,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: (value) {
                  if (!_needsHeight) {
                    return null;
                  }
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
            ],
            if (_needsWeight)
              AppTextField(
                controller: _weightController,
                label: AppStrings.currentWeightKg,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: (value) {
                  if (!_needsWeight) {
                    return null;
                  }
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
          ],
        ),
        action: PrimaryButton(label: AppStrings.next, onPressed: _goNext),
      ),
    );
  }
}
