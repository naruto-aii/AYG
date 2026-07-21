import 'package:flutter/material.dart';

import '../../models/exercise_entry.dart';
import '../../state/app_controller.dart';

class ExerciseFormScreen extends StatefulWidget {
  const ExerciseFormScreen({super.key, required this.controller, this.entry});

  final AppController controller;
  final ExerciseEntry? entry;

  bool get isEditing => entry != null;

  @override
  State<ExerciseFormScreen> createState() => _ExerciseFormScreenState();
}

class _ExerciseFormScreenState extends State<ExerciseFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _durationController;
  late final TextEditingController _burnedKcalController;

  @override
  void initState() {
    super.initState();
    final entry = widget.entry;
    _nameController = TextEditingController(text: entry?.name ?? '');
    _durationController = TextEditingController(
      text: entry?.durationMin.toString() ?? '',
    );
    _burnedKcalController = TextEditingController(
      text: entry?.burnedKcal.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _durationController.dispose();
    _burnedKcalController.dispose();
    super.dispose();
  }

  ExerciseEntry? _buildEntry() {
    if (_formKey.currentState?.validate() != true) {
      return null;
    }

    return ExerciseEntry(
      id: widget.entry?.id ?? widget.controller.generateId(),
      name: _nameController.text.trim(),
      durationMin: int.parse(_durationController.text),
      burnedKcal: double.parse(_burnedKcalController.text),
      loggedAt: widget.entry?.loggedAt ?? DateTime.now(),
    );
  }

  void _save() {
    final entry = _buildEntry();
    if (entry == null) {
      return;
    }

    if (widget.isEditing) {
      widget.controller.updateExercise(entry);
    } else {
      widget.controller.addExercise(entry);
    }

    Navigator.of(context).pop();
  }

  Future<void> _confirmDelete() async {
    final entry = widget.entry;
    if (entry == null) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('削除確認'),
        content: Text('「${entry.name}」を削除しますか？'),
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

    widget.controller.deleteExercise(entry.id);
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.isEditing ? '運動を編集' : '運動を追加')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: '運動名',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '運動名を入力してください';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _durationController,
                decoration: const InputDecoration(
                  labelText: '実施時間（分）',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '実施時間を入力してください';
                  }
                  final parsed = int.tryParse(value);
                  if (parsed == null || parsed <= 0) {
                    return '1以上の整数を入力してください';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _burnedKcalController,
                decoration: const InputDecoration(
                  labelText: '消費 kcal',
                  border: OutlineInputBorder(),
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '消費 kcal を入力してください';
                  }
                  final parsed = double.tryParse(value);
                  if (parsed == null || parsed < 0) {
                    return '0以上の数値を入力してください';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 32),
              FilledButton(onPressed: _save, child: const Text('保存')),
              if (widget.isEditing) ...[
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: _confirmDelete,
                  child: const Text('削除'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
