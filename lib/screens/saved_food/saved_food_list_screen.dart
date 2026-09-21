import 'package:flutter/material.dart';

import '../../models/food_visibility.dart';
import '../../models/saved_food.dart';
import '../../state/app_controller.dart';
import '../../utils/nutrition_format.dart';
import '../../utils/saved_food_display_labels.dart';
import '../../widgets/common/app_confirm_dialog.dart';
import '../../services/open_food_facts_service.dart';
import 'public_food_search_screen.dart';
import 'saved_food_form_screen.dart';
import 'saved_food_publish_flow.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_icons.dart';
import '../../theme/app_typography.dart';
import '../../widgets/design/design_button.dart';
import '../../widgets/design/design_field.dart';
import '../../widgets/design/design_icon.dart';
import '../../widgets/design/design_page.dart';
import '../../widgets/design/settings_row.dart';
import '../../widgets/design/weight_parts.dart';

enum _MyFoodVisibilityFilter { all, private, public }

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
  _MyFoodVisibilityFilter _visibilityFilter = _MyFoodVisibilityFilter.all;

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

  List<SavedFood> get _filteredFoods {
    return _foods.where((food) {
      return switch (_visibilityFilter) {
        _MyFoodVisibilityFilter.all => true,
        _MyFoodVisibilityFilter.private =>
          food.visibility == FoodVisibility.private,
        _MyFoodVisibilityFilter.public =>
          food.visibility == FoodVisibility.public,
      };
    }).toList();
  }

  Future<void> _confirmDelete(SavedFood food) async {
    final confirmed = await showAppConfirmDialog(
      context: context,
      title: '削除確認',
      message: 'この食品を削除しますか？\n過去の食事記録は削除されません。',
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
    final foods = _filteredFoods;

    return DesignPage(
      bottomBar: DesignButton(label: '食品を登録', onPressed: _openCreate),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DesignTitleBlock(
            title: '保存食品',
            subtitle: 'よく食べる食品を登録しておくと、次から選ぶだけです。',
            trailing: IconButton(
              tooltip: '公開食品検索',
              onPressed: _openPublicSearch,
              icon: const AppIcon(
                AppIcons.search,
                size: 24,
                color: AppColors.iconPrimary,
              ),
            ),
          ),
          DesignSearchField(controller: _searchController, hintText: '食品を検索'),
          const SizedBox(height: 12),
          DesignChipGroup<_MyFoodVisibilityFilter>(
            values: _MyFoodVisibilityFilter.values,
            labelOf: (filter) => switch (filter) {
              _MyFoodVisibilityFilter.all => 'すべて',
              _MyFoodVisibilityFilter.private => '非公開',
              _MyFoodVisibilityFilter.public => '公開中',
            },
            selected: _visibilityFilter,
            onChanged: (filter) => setState(() => _visibilityFilter = filter),
          ),
          const SizedBox(height: 16),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_errorMessage != null || foods.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Text(
                _errorMessage ??
                    (_foods.isEmpty ? 'マイ食品がありません' : '該当する食品がありません'),
                textAlign: TextAlign.center,
                style: AppTypography.bodyS.copyWith(color: AppColors.textMuted),
              ),
            )
          else
            for (final food in foods) ...[
              SettingsRow(
                icon: AppIcons.bookmark,
                title: food.name,
                subtitle:
                    '${widget.controller.formatSavedFoodBaseLabel(food)} ・ '
                    '${formatNullableNutrient(food.kcalPerBase)} kcal ・ '
                    '${SavedFoodDisplayLabels.visibility(food.visibility)}',
                onTap: () => _openEdit(food),
                trailing: PopupMenuButton<String>(
                  tooltip: 'メニュー',
                  icon: const DesignIcon(
                    Symbols.more_horiz_rounded,
                    size: 22,
                    color: AppColors.iconMuted,
                  ),
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
                    const PopupMenuItem(value: 'edit', child: Text('編集')),
                    if (food.visibility == FoodVisibility.private)
                      const PopupMenuItem(
                        value: 'publish',
                        child: Text('公開する'),
                      ),
                    if (food.visibility == FoodVisibility.public)
                      const PopupMenuItem(
                        value: 'unpublish',
                        child: Text('非公開にする'),
                      ),
                    const PopupMenuItem(value: 'delete', child: Text('削除')),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
          const SizedBox(height: 16),
        ],
      ),
    );
  }

}
