import 'package:flutter/material.dart';

import '../../models/exercise_category.dart';
import '../../models/workout_template.dart';
import '../../state/app_controller.dart';
import '../../theme/app_spacing.dart';
import '../../utils/id_generator.dart';
import '../../widgets/common/delete_with_undo.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/app_empty_state.dart';
import '../../widgets/common/app_loading_state.dart';
import '../../widgets/common/app_text_field.dart';
import '../../widgets/layout/app_content_constraint.dart';

class WorkoutTemplateFormScreen extends StatefulWidget {
  const WorkoutTemplateFormScreen({
    super.key,
    required this.controller,
    this.templateId,
    this.initialItem,
  });

  final AppController controller;
  final String? templateId;
  final WorkoutTemplateItem? initialItem;

  bool get isEditing => templateId != null;

  @override
  State<WorkoutTemplateFormScreen> createState() =>
      _WorkoutTemplateFormScreenState();
}

class _WorkoutTemplateFormScreenState extends State<WorkoutTemplateFormScreen> {
  final _nameController = TextEditingController();
  final _items = <WorkoutTemplateItem>[];
  bool _isSaving = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialItem;
    if (initial != null) {
      _items.add(initial);
    }
    if (widget.isEditing) {
      _loadExisting();
    }
  }

  Future<void> _loadExisting() async {
    setState(() => _isLoading = true);
    final bundle = await widget.controller.getWorkoutTemplateWithItems(
      widget.templateId!,
    );
    if (!mounted || bundle == null) {
      return;
    }
    _nameController.text = bundle.template.name;
    setState(() {
      _items
        ..clear()
        ..addAll(bundle.items);
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _addItem() async {
    final item = await showDialog<WorkoutTemplateItem>(
      context: context,
      builder: (context) =>
          _WorkoutTemplateItemDialog(sortOrder: _items.length + 1),
    );
    if (item != null) {
      setState(() => _items.add(item));
    }
  }

  Future<void> _save() async {
    if (_nameController.text.trim().isEmpty || _items.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('テンプレート名と1件以上の種目が必要です')));
      return;
    }

    setState(() => _isSaving = true);
    try {
      await widget.controller.saveWorkoutTemplate(
        draft: WorkoutTemplateDraft(
          name: _nameController.text.trim(),
          items: _items,
        ),
        templateId: widget.templateId,
      );
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('保存に失敗しました: $error')));
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.isEditing ? 'テンプレート編集' : 'テンプレート作成')),
        body: const AppLoadingState(),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(widget.isEditing ? 'テンプレート編集' : 'テンプレート作成')),
      body: SafeArea(
        child: AppContentConstraint(
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              AppTextField(controller: _nameController, label: 'テンプレート名'),
              const SizedBox(height: AppSpacing.md),
              for (final item in _items)
                AppCard(
                  child: ListTile(
                    title: Text(item.name),
                    subtitle: Text(
                      '${item.durationMin}分'
                      '${item.sets != null ? ' · ${item.sets}セット' : ''}',
                    ),
                  ),
                ),
              TextButton.icon(
                onPressed: _addItem,
                icon: const Icon(Icons.add),
                label: const Text('種目を追加'),
              ),
              const SizedBox(height: AppSpacing.lg),
              FilledButton(
                onPressed: _isSaving ? null : _save,
                child: Text(_isSaving ? '保存中…' : '保存'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class WorkoutTemplateListScreen extends StatefulWidget {
  const WorkoutTemplateListScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<WorkoutTemplateListScreen> createState() =>
      _WorkoutTemplateListScreenState();
}

class _WorkoutTemplateListScreenState extends State<WorkoutTemplateListScreen> {
  final _searchController = TextEditingController();
  List<WorkoutTemplate> _templates = const [];
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
    final templates = await widget.controller.searchWorkoutTemplates(
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
            WorkoutTemplateFormScreen(controller: widget.controller),
      ),
    );
    if (saved == true) {
      await _reload();
    }
  }

  Future<void> _openEdit(WorkoutTemplate template) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (context) => WorkoutTemplateFormScreen(
          controller: widget.controller,
          templateId: template.templateId,
        ),
      ),
    );
    if (saved == true) {
      await _reload();
    }
  }

  Future<void> _deleteTemplate(WorkoutTemplate template) async {
    final bundle = await widget.controller.getWorkoutTemplateWithItems(
      template.templateId,
    );
    if (bundle == null) {
      return;
    }

    await confirmDeleteWithUndo<WorkoutTemplateWithItems>(
      context: context,
      title: '削除確認',
      message: '「${template.name}」を削除しますか？',
      snapshot: bundle,
      onDelete: () =>
          widget.controller.deleteWorkoutTemplate(template.templateId),
      onRestore: (restored) =>
          widget.controller.restoreWorkoutTemplateBundle(restored),
    );
    if (mounted) {
      await _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('運動テンプレート'),
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
                    ? AppEmptyState(
                        message: '運動テンプレートがありません',
                        actionLabel: 'テンプレートを作成',
                        onAction: _openCreate,
                      )
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
                              child: ListTile(
                                title: Text(template.name),
                                subtitle: Text('利用 ${template.useCount} 回'),
                                onTap: () => _openEdit(template),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete_outline),
                                  onPressed: () => _deleteTemplate(template),
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

class _WorkoutTemplateItemDialog extends StatefulWidget {
  const _WorkoutTemplateItemDialog({required this.sortOrder});

  final int sortOrder;

  @override
  State<_WorkoutTemplateItemDialog> createState() =>
      _WorkoutTemplateItemDialogState();
}

class _WorkoutTemplateItemDialogState
    extends State<_WorkoutTemplateItemDialog> {
  final _nameController = TextEditingController();
  final _durationController = TextEditingController(text: '30');
  final _setsController = TextEditingController();
  final _repsController = TextEditingController();
  final _weightController = TextEditingController();
  ExerciseCategory _category = ExerciseCategory.strength;

  @override
  void dispose() {
    _nameController.dispose();
    _durationController.dispose();
    _setsController.dispose();
    _repsController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameController.text.trim();
    final duration = int.tryParse(_durationController.text.trim());
    if (name.isEmpty || duration == null || duration <= 0) {
      return;
    }

    Navigator.of(context).pop(
      WorkoutTemplateItem(
        itemId: generateUniqueId(),
        name: name,
        categoryKey: _category.id,
        durationMin: duration,
        sets: int.tryParse(_setsController.text.trim()),
        reps: int.tryParse(_repsController.text.trim()),
        liftWeightKg: double.tryParse(_weightController.text.trim()),
        sortOrder: widget.sortOrder,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('種目を追加'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppTextField(controller: _nameController, label: '種目名'),
            const SizedBox(height: AppSpacing.sm),
            DropdownButtonFormField<ExerciseCategory>(
              value: _category,
              decoration: const InputDecoration(labelText: '分類'),
              items: ExerciseCategory.values
                  .map(
                    (category) => DropdownMenuItem(
                      value: category,
                      child: Text(category.labelJa),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _category = value);
                }
              },
            ),
            const SizedBox(height: AppSpacing.sm),
            AppTextField(
              controller: _durationController,
              label: '時間（分）',
              keyboardType: TextInputType.number,
            ),
            AppTextField(
              controller: _setsController,
              label: 'セット',
              keyboardType: TextInputType.number,
            ),
            AppTextField(
              controller: _repsController,
              label: '回数',
              keyboardType: TextInputType.number,
            ),
            AppTextField(
              controller: _weightController,
              label: '重量（kg）',
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('キャンセル'),
        ),
        FilledButton(onPressed: _submit, child: const Text('追加')),
      ],
    );
  }
}

class WorkoutTemplatePickerScreen extends StatefulWidget {
  const WorkoutTemplatePickerScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<WorkoutTemplatePickerScreen> createState() =>
      _WorkoutTemplatePickerScreenState();
}

class _WorkoutTemplatePickerScreenState
    extends State<WorkoutTemplatePickerScreen> {
  final _searchController = TextEditingController();
  List<WorkoutTemplate> _templates = const [];
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
    final templates = await widget.controller.searchWorkoutTemplates(
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
            WorkoutTemplateFormScreen(controller: widget.controller),
      ),
    );
    if (saved == true) {
      await _reload();
    }
  }

  void _select(WorkoutTemplate template) {
    Navigator.of(context).pop(template);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('運動テンプレート'),
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
                    ? const AppEmptyState(message: '運動テンプレートがありません')
                    : ListView.builder(
                        itemCount: _templates.length,
                        itemBuilder: (context, index) {
                          final template = _templates[index];
                          return AppCard(
                            child: ListTile(
                              title: Text(template.name),
                              subtitle: Text('利用 ${template.useCount} 回'),
                              onTap: () => _select(template),
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
