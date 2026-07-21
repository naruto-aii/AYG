import 'package:flutter/material.dart';

import '../../models/health_profile_data.dart';
import '../../models/user_profile.dart';
import '../../repositories/authentication_repository.dart';
import '../../services/open_food_facts_service.dart';
import '../../state/app_controller.dart';
import '../food/food_form_navigation.dart';
import '../shell/shell_navigation.dart';
import 'goal_setup_screen.dart';

class BasicInfoScreen extends StatefulWidget {
  const BasicInfoScreen({
    super.key,
    required this.controller,
    required this.openFoodFactsService,
    required this.healthPrefill,
    required this.authenticationRepository,
    this.mainShellBuilder,
    this.foodFormBuilder,
  });

  final AppController controller;
  final OpenFoodFactsService openFoodFactsService;
  final HealthProfileData healthPrefill;
  final AuthenticationRepository authenticationRepository;
  final MainShellScreenBuilder? mainShellBuilder;
  final FoodFormScreenBuilder? foodFormBuilder;

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
          mainShellBuilder: widget.mainShellBuilder,
          foodFormBuilder: widget.foodFormBuilder,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final birthDateLabel = _birthDate == null
        ? '未選択'
        : '${_birthDate!.year}/${_birthDate!.month}/${_birthDate!.day}';

    return Scaffold(
      appBar: AppBar(title: const Text('基礎情報入力')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'あなたの基礎情報を入力してください',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              if (!_needsBirthDate ||
                  !_needsGender ||
                  !_needsHeight ||
                  !_needsWeight) ...[
                const SizedBox(height: 12),
                Text(
                  'Health から取得済みの項目は入力不要です。',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: 24),
              if (_needsBirthDate) ...[
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('生年月日'),
                  subtitle: Text(birthDateLabel),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: _pickBirthDate,
                ),
                const SizedBox(height: 16),
              ],
              if (_needsGender) ...[
                DropdownButtonFormField<Gender>(
                  initialValue: _gender,
                  decoration: const InputDecoration(
                    labelText: '性別',
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
                  onChanged: (value) => setState(() => _gender = value),
                ),
                const SizedBox(height: 16),
              ],
              if (_needsHeight)
                TextFormField(
                  controller: _heightController,
                  decoration: const InputDecoration(
                    labelText: '身長 (cm)',
                    border: OutlineInputBorder(),
                  ),
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
              if (_needsHeight) const SizedBox(height: 16),
              if (_needsWeight)
                TextFormField(
                  controller: _weightController,
                  decoration: const InputDecoration(
                    labelText: '現在体重 (kg)',
                    border: OutlineInputBorder(),
                  ),
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
              const SizedBox(height: 32),
              FilledButton(onPressed: _goNext, child: const Text('次へ')),
            ],
          ),
        ),
      ),
    );
  }
}
