import 'package:flutter/material.dart';

import '../../models/meal_template.dart';
import '../../models/meal_template_apply.dart';
import '../../state/app_controller.dart';
import '../../utils/nutrition_format.dart';
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
  }

  Future<void> _deleteTemplate(MealTemplate template) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('削除確認'),
        content: Text('「${template.name}」を削除しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('削除'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    await widget.controller.deleteMealTemplate(template.templateId);
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('食事テンプレート'),
        actions: [
          IconButton(
            onPressed: _openCreate,
            icon: const Icon(Icons.add),
            tooltip: '新規作成',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                labelText: 'テンプレート名で検索',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _templates.isEmpty
                ? const Center(child: Text('食事テンプレートがありません'))
                : ListView.builder(
                    itemCount: _templates.length,
                    itemBuilder: (context, index) {
                      final template = _templates[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 6,
                        ),
                        child: ListTile(
                          title: Text(template.name),
                          subtitle: Text(
                            '食品数: — · '
                            '${formatNullableNutrient(template.totalKcal)}kcal · '
                            'P${formatNullableNutrient(template.totalProteinG)} '
                            'F${formatNullableNutrient(template.totalFatG)} '
                            'C${formatNullableNutrient(template.totalCarbG)} · '
                            '使用${template.useCount}回',
                          ),
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
                                child: Text('今日の食事に追加'),
                              ),
                              PopupMenuItem(value: 'edit', child: Text('編集')),
                              PopupMenuItem(value: 'delete', child: Text('削除')),
                            ],
                          ),
                          onTap: () => _applyTemplate(template),
                        ),
                      );
                    },
                  ),
          ),
        ],
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
            const SizedBox(height: 12),
            ...widget.issues.map((issue) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
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
