import 'package:flutter/material.dart';

import '../../models/meal_template.dart';
import '../../models/meal_template_apply.dart';
import '../../models/meal_template_draft.dart';
import '../../state/app_controller.dart';
import '../../theme/app_spacing.dart';
import '../../utils/nutrition_format.dart';
import '../../widgets/common/compact_macro_display.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/delete_with_undo.dart';
import '../../widgets/common/app_empty_state.dart';
import '../../widgets/common/app_loading_state.dart';
import '../../widgets/common/app_text_field.dart';
import '../../widgets/layout/app_content_constraint.dart';
import 'meal_template_form_screen.dart';

class MealTemplateListScreen extends StatefulWidget {
  const MealTemplateListScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<MealTemplateListScreen> createState() => _MealTemplateListScreenState();
}

class _MealTemplateListScreenState extends State<MealTemplateListScreen> {
  final _searchController = TextEditingController();
  List<MealTemplate> _templates = const [];
  bool _isLoading = true;
  bool _isApplying = false;

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

  Future<void> _openEdit(MealTemplate template) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (context) => MealTemplateFormScreen(
          controller: widget.controller,
          templateId: template.templateId,
        ),
      ),
    );
    if (saved == true) {
      await _reload();
    }
  }

  Future<void> _applyTemplate(MealTemplate template) async {
    if (_isApplying) {
      return;
    }
    setState(() => _isApplying = true);
    try {
      var result = await widget.controller.applyMealTemplate(
        templateId: template.templateId,
      );
      if (!mounted) {
        return;
      }

      while (result.needsResolution) {
        final resolutions = await showMealTemplateDependencyDialog(
          context: context,
          controller: widget.controller,
          issues: result.issues,
        );
        if (resolutions == null) {
          return;
        }
        result = await widget.controller.applyMealTemplate(
          templateId: template.templateId,
          resolutions: resolutions,
        );
        if (!mounted) {
          return;
        }
      }

      if (result.cancelled) {
        return;
      }

      if (result.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '「${template.name}」から${result.createdEntryCount}件の食事を追加しました',
            ),
          ),
        );
        await _reload();
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.errorMessage ?? 'テンプレート適用に失敗しました')),
      );
    } finally {
      if (mounted) {
        setState(() => _isApplying = false);
      }
    }
  }

  Future<void> _deleteTemplate(MealTemplate template) async {
    final bundle = await widget.controller.getMealTemplateWithItems(
      template.templateId,
    );
    if (bundle == null) {
      return;
    }

    await confirmDeleteWithUndo<MealTemplateWithItems>(
      context: context,
      title: '削除確認',
      message: '「${template.name}」を削除しますか？',
      snapshot: bundle,
      onDelete: () => widget.controller.deleteMealTemplate(template.templateId),
      onRestore: (restored) =>
          widget.controller.restoreMealTemplateBundle(restored),
    );
    if (mounted) {
      await _reload();
    }
  }

  String _formatLastUsed(DateTime? value) {
    if (value == null) {
      return '未使用';
    }
    final local = value.toLocal();
    return '${local.year}/${local.month}/${local.day}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('食事テンプレート'),
        actions: [
          Semantics(
            label: 'テンプレート作成',
            button: true,
            child: IconButton(
              onPressed: _openCreate,
              icon: const Icon(Icons.add),
            ),
          ),
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
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.md,
                                vertical: AppSpacing.xs,
                              ),
                              onTap: _isApplying
                                  ? null
                                  : () => _applyTemplate(template),
                              child: ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(template.name),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    CompactMacroDisplay(
                                      kcal: template.totalKcal,
                                      proteinG: template.totalProteinG,
                                      fatG: template.totalFatG,
                                      carbG: template.totalCarbG,
                                    ),
                                    Text(
                                      '最終利用 ${_formatLastUsed(template.lastUsedAt)} · '
                                      '利用 ${template.useCount} 回',
                                    ),
                                  ],
                                ),
                                isThreeLine: true,
                                trailing: PopupMenuButton<String>(
                                  onSelected: (value) {
                                    switch (value) {
                                      case 'apply':
                                        _applyTemplate(template);
                                      case 'edit':
                                        _openEdit(template);
                                      case 'delete':
                                        _deleteTemplate(template);
                                    }
                                  },
                                  itemBuilder: (context) => const [
                                    PopupMenuItem(
                                      value: 'apply',
                                      child: Text('利用'),
                                    ),
                                    PopupMenuItem(
                                      value: 'edit',
                                      child: Text('編集'),
                                    ),
                                    PopupMenuItem(
                                      value: 'delete',
                                      child: Text('削除'),
                                    ),
                                  ],
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

Future<List<MealTemplateItemResolution>?> showMealTemplateDependencyDialog({
  required BuildContext context,
  required AppController controller,
  required List<MealTemplateDependencyIssue> issues,
}) {
  return showDialog<List<MealTemplateItemResolution>>(
    context: context,
    builder: (context) =>
        _MealTemplateDependencyDialog(controller: controller, issues: issues),
  );
}

class _MealTemplateDependencyDialog extends StatefulWidget {
  const _MealTemplateDependencyDialog({
    required this.controller,
    required this.issues,
  });

  final AppController controller;
  final List<MealTemplateDependencyIssue> issues;

  @override
  State<_MealTemplateDependencyDialog> createState() =>
      _MealTemplateDependencyDialogState();
}

class _MealTemplateDependencyDialogState
    extends State<_MealTemplateDependencyDialog> {
  late final Map<String, MealTemplateItemResolutionAction> _choices;

  @override
  void initState() {
    super.initState();
    _choices = {
      for (final issue in widget.issues)
        issue.item.itemId: MealTemplateItemResolutionAction.useSnapshot,
    };
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('食品の状態確認'),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView(
          shrinkWrap: true,
          children: [
            const Text('元食品の状態が変わっています。各項目の利用方法を選んでください。'),
            const SizedBox(height: AppSpacing.sm),
            ...widget.issues.map((issue) {
              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      issue.item.name,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    DropdownButtonFormField<MealTemplateItemResolutionAction>(
                      initialValue: _choices[issue.item.itemId],
                      items: const [
                        DropdownMenuItem(
                          value: MealTemplateItemResolutionAction.useSnapshot,
                          child: Text('スナップショット値で今回利用'),
                        ),
                        DropdownMenuItem(
                          value: MealTemplateItemResolutionAction.exclude,
                          child: Text('テンプレートから除外'),
                        ),
                        DropdownMenuItem(
                          value: MealTemplateItemResolutionAction.cancel,
                          child: Text('キャンセル'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _choices[issue.item.itemId] = value);
                        }
                      },
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('閉じる'),
        ),
        FilledButton(
          onPressed: () {
            final resolutions = _choices.entries
                .map(
                  (entry) => MealTemplateItemResolution(
                    itemId: entry.key,
                    action: entry.value,
                  ),
                )
                .toList();
            Navigator.of(context).pop(resolutions);
          },
          child: const Text('続行'),
        ),
      ],
    );
  }
}
