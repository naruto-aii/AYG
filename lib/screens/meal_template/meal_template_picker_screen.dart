import 'package:flutter/material.dart';

import '../../models/meal_template.dart';
import '../../state/app_controller.dart';
import '../../utils/macro_display.dart';
import '../../utils/nutrition_format.dart';
import 'meal_template_form_screen.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../widgets/design/design_button.dart';
import '../../widgets/design/design_field.dart';
import '../../widgets/design/design_icon.dart';
import '../../widgets/design/design_page.dart';
import '../../widgets/design/select_card.dart';

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
  MealTemplate? _selected;

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
    final selected = _selected;

    return DesignPage(
      bottomBar: DesignButton(
        label: 'この内容で追加',
        onPressed: selected == null ? null : () => _select(selected),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DesignTitleBlock(
            title: 'テンプレートから追加',
            subtitle: '選んだ組み合わせを、そのまま記録します。',
            trailing: IconButton(
              tooltip: 'テンプレートを作成',
              onPressed: _openCreate,
              icon: const DesignIcon(
                Symbols.add_rounded,
                size: 26,
                color: AppColors.iconPrimary,
              ),
            ),
          ),
          DesignSearchField(
            controller: _searchController,
            hintText: 'テンプレートを検索',
          ),
          const SizedBox(height: 16),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_templates.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Text(
                '食事テンプレートがありません',
                textAlign: TextAlign.center,
                style: AppTypography.bodyS.copyWith(color: AppColors.textMuted),
              ),
            )
          else
            for (final template in _templates) ...[
              SelectCard(
                title: template.name,
                description:
                    '${formatNullableNutrient(template.totalKcal)} kcal ・ '
                    '${formatMacroSummaryInline(proteinG: template.totalProteinG, fatG: template.totalFatG, carbG: template.totalCarbG)}',
                selected: selected?.templateId == template.templateId,
                minHeight: 0,
                onTap: () => setState(() => _selected = template),
              ),
              const SizedBox(height: 14),
            ],
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}
