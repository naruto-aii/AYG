import 'package:flutter/material.dart';

import '../../models/saved_food.dart';
import '../../state/app_controller.dart';
import '../../utils/nutrition_format.dart';
import '../../utils/saved_food_display_labels.dart';
import 'saved_food_form_screen.dart';

class SavedFoodListScreen extends StatefulWidget {
  const SavedFoodListScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<SavedFoodListScreen> createState() => _SavedFoodListScreenState();
}

class _SavedFoodListScreenState extends State<SavedFoodListScreen> {
  final _searchController = TextEditingController();
  List<SavedFood> _foods = const [];
  bool _isLoading = true;
  String? _errorMessage;

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
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final foods = await widget.controller.searchOwnSavedFoods(
        _searchController.text.trim(),
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _foods = foods;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = error.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _openCreate() async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (context) =>
            SavedFoodFormScreen(controller: widget.controller),
      ),
    );
    if (saved == true) {
      await _reload();
    }
  }

  Future<void> _openEdit(SavedFood food) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (context) =>
            SavedFoodFormScreen(controller: widget.controller, food: food),
      ),
    );
    if (saved == true) {
      await _reload();
    }
  }

  Future<void> _confirmDelete(SavedFood food) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('削除確認'),
        content: Text('「${food.name}」を削除しますか？\n過去の食事記録は変更されません。'),
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

    try {
      await widget.controller.deleteSavedFood(food.foodId);
      await _reload();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('削除に失敗しました: $error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('保存済み食品'),
        actions: [
          IconButton(
            onPressed: _openCreate,
            icon: const Icon(Icons.add),
            tooltip: '新規作成',
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  labelText: '食品名で検索',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.search),
                ),
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _errorMessage != null
                  ? Center(child: Text(_errorMessage!))
                  : _foods.isEmpty
                  ? const Center(child: Text('保存済み食品がありません'))
                  : ListView.separated(
                      itemCount: _foods.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final food = _foods[index];
                        return ListTile(
                          title: Text(food.name),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${widget.controller.formatSavedFoodBaseLabel(food)} · '
                                '${formatNullableNutrient(food.kcalPerBase)}kcal · '
                                'P${formatNullableNutrient(food.proteinPerBase)} '
                                'F${formatNullableNutrient(food.fatPerBase)} '
                                'C${formatNullableNutrient(food.carbPerBase)}',
                              ),
                              Text(
                                '${SavedFoodDisplayLabels.visibility(food.visibility)} · '
                                '${SavedFoodDisplayLabels.sourceType(food.sourceType)} · '
                                '利用${food.useCount}回 · '
                                '更新 ${_formatDateTime(food.updatedAt)}',
                              ),
                            ],
                          ),
                          isThreeLine: true,
                          trailing: PopupMenuButton<String>(
                            onSelected: (value) {
                              switch (value) {
                                case 'edit':
                                  _openEdit(food);
                                case 'delete':
                                  _confirmDelete(food);
                              }
                            },
                            itemBuilder: (context) => const [
                              PopupMenuItem(value: 'edit', child: Text('編集')),
                              PopupMenuItem(value: 'delete', child: Text('削除')),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openCreate,
        child: const Icon(Icons.add),
      ),
    );
  }

  String _formatDateTime(DateTime value) {
    final local = value.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '${local.year}/$month/$day $hour:$minute';
  }
}
