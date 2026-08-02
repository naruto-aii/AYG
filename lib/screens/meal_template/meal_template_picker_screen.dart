import 'package:flutter/material.dart';

import '../../models/meal_template.dart';
import '../../state/app_controller.dart';
import '../../theme/app_spacing.dart';
import '../../utils/nutrition_format.dart';
import '../../widgets/common/compact_macro_display.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/app_empty_state.dart';
import '../../widgets/common/app_loading_state.dart';
import '../../widgets/common/app_text_field.dart';
import '../../widgets/layout/app_content_constraint.dart';
import 'meal_template_form_screen.dart';

/// テンプレート選択専用画面（食事登録への展開用）。
class MealTemplatePickerScreen extends StatefulWidget {
  const MealTemplatePickerScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<MealTemplatePickerScreen> createState() =>
      _MealTemplatePickerScreenState();
}

class _MealTemplatePickerScreenState extends State<MealTemplatePickerScreen> {
  final _searchController = TextEditingController();
  List<MealTemplate> _templates = const [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_reload);
    _reload();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    setState(() => _isLoading = true);
    final templates = await widget.controller.searchMealTemplates(
      _searchController.text.trim(),
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _templates = templates;
      _isLoading = false;
    });
  }

  Future<void> _openCreate() async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (context) =>
            MealTemplateFormScreen(controller: widget.controller),
      ),
    );
    if (saved == true) {
      await _reload();
    }
  }

  void _select(MealTemplate template) {
    Navigator.of(context).pop(template);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('テンプレートを選択'),
        actions: [
          IconButton(onPressed: _openCreate, icon: const Icon(Icons.add)),
        ],
      ),
      body: SafeArea(
        child: AppContentConstraint(
          expandVertically: true,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: AppTextField(
                  controller: _searchController,
                  label: 'テンプレート名で検索',
                  suffixIcon: const Icon(Icons.search),
                ),
              ),
              Expanded(
                child: _isLoading
                    ? const AppLoadingState()
                    : _templates.isEmpty
                    ? const AppEmptyState(message: '食事テンプレートがありません')
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                        ),
                        itemCount: _templates.length,
                        itemBuilder: (context, index) {
                          final template = _templates[index];
                          return Padding(
                            padding: const EdgeInsets.only(
                              bottom: AppSpacing.sm,
                            ),
                            child: AppCard(
                              onTap: () => _select(template),
                              child: ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(template.name),
                                subtitle: CompactMacroDisplay(
                                  kcal: template.totalKcal,
                                  proteinG: template.totalProteinG,
                                  fatG: template.totalFatG,
                                  carbG: template.totalCarbG,
                                ),
                                trailing: Text(
                                  '${formatNullableNutrient(template.totalKcal)} kcal',
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
