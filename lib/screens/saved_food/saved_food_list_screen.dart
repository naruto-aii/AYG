import 'package:flutter/material.dart';

import '../../models/food_visibility.dart';
import '../../models/saved_food.dart';
import '../../state/app_controller.dart';
import '../../utils/nutrition_format.dart';
import '../../utils/saved_food_display_labels.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/common/app_empty_state.dart';
import '../../widgets/common/app_loading_state.dart';
import '../../widgets/common/app_text_field.dart';
import '../../widgets/common/app_confirm_dialog.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/layout/app_content_constraint.dart';
import '../../services/open_food_facts_service.dart';
import 'public_food_search_screen.dart';
import 'saved_food_form_screen.dart';
import 'saved_food_publish_flow.dart';

class SavedFoodListScreen extends StatefulWidget {
  const SavedFoodListScreen({
    super.key,
    required this.controller,
    this.openFoodFactsService,
  });

  final AppController controller;
  final OpenFoodFactsService? openFoodFactsService;

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
      await widget.controller.refreshSavedFoodsFromRemote();
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

  Future<void> _openPublicSearch() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) => PublicFoodSearchScreen(
          controller: widget.controller,
          openFoodFactsService: widget.openFoodFactsService,
        ),
      ),
    );
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

  Future<void> _startPublish(SavedFood food) async {
    final published = await startSavedFoodPublishFlow(
      context: context,
      controller: widget.controller,
      food: food,
    );
    if (published) {
      await _reload();
    }
  }

  Future<void> _unpublish(SavedFood food) async {
    await confirmUnpublishSavedFood(
      context: context,
      controller: widget.controller,
      food: food,
      onSuccess: _reload,
    );
  }

  Future<void> _confirmDelete(SavedFood food) async {
    final confirmed = await showAppConfirmDialog(
      context: context,
      title: '削除確認',
      message: '「${food.name}」を削除しますか？\n過去の食事記録は削除されません。',
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
          Semantics(
            label: '公開食品検索',
            button: true,
            child: IconButton(
              onPressed: _openPublicSearch,
              icon: const Icon(Icons.public),
            ),
          ),
          Semantics(
            label: '新規作成',
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
                  label: '食品名で検索',
                  suffixIcon: const Icon(Icons.search),
                ),
              ),
              Expanded(
                child: _isLoading
                    ? const AppLoadingState()
                    : _errorMessage != null
                    ? AppEmptyState(message: _errorMessage!)
                    : _foods.isEmpty
                    ? const AppEmptyState(message: '保存済み食品がありません')
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                        ),
                        itemCount: _foods.length,
                        itemBuilder: (context, index) {
                          final food = _foods[index];
                          return Padding(
                            padding: const EdgeInsets.only(
                              bottom: AppSpacing.sm,
                            ),
                            child: AppCard(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.md,
                                vertical: AppSpacing.xs,
                              ),
                              onTap: () => _openEdit(food),
                              child: ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(food.name),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${widget.controller.formatSavedFoodBaseLabel(food)} · '
                                      '${formatNullableNutrient(food.kcalPerBase)} kcal · '
                                      'P ${formatNullableNutrient(food.proteinPerBase)} '
                                      'F ${formatNullableNutrient(food.fatPerBase)} '
                                      'C ${formatNullableNutrient(food.carbPerBase)}',
                                    ),
                                    if (food.brand != null &&
                                        food.brand!.isNotEmpty)
                                      Text('ブランド: ${food.brand}'),
                                    Text(
                                      '${SavedFoodDisplayLabels.visibility(food.visibility)} · '
                                      '${SavedFoodDisplayLabels.sourceType(food.sourceType)} · '
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
                                      case 'publish':
                                        _startPublish(food);
                                      case 'unpublish':
                                        _unpublish(food);
                                      case 'delete':
                                        _confirmDelete(food);
                                    }
                                  },
                                  itemBuilder: (context) => [
                                    const PopupMenuItem(
                                      value: 'edit',
                                      child: Text('編集'),
                                    ),
                                    if (food.visibility ==
                                        FoodVisibility.private)
                                      const PopupMenuItem(
                                        value: 'publish',
                                        child: Text('公開する'),
                                      ),
                                    if (food.visibility ==
                                        FoodVisibility.public)
                                      const PopupMenuItem(
                                        value: 'unpublish',
                                        child: Text('非公開にする'),
                                      ),
                                    const PopupMenuItem(
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

  String _formatDateTime(DateTime value) {
    final local = value.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '${local.year}/$month/$day $hour:$minute';
  }
}
