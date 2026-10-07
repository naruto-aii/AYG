import 'package:flutter/material.dart';

import '../../models/official_food.dart';
import '../../models/public_food_search_match.dart';
import '../../models/saved_food.dart';
import '../../services/public_food_meal_add_flow.dart';
import '../../state/app_controller.dart';
import '../../widgets/design/design_field.dart';
import '../../widgets/design/design_page.dart';
import '../../widgets/food/combined_food_search.dart';
import '../../widgets/saved_food/public_food_detail_sheet.dart';
import '../official_food/official_food_detail_screen.dart';

/// 食事登録の「食品を探す」。保存済み・定番の食品・公開食品をまとめて探す。
class MealFoodSearchScreen extends StatefulWidget {
  const MealFoodSearchScreen({
    super.key,
    required this.controller,
    this.searchOverrides,
  });

  final AppController controller;
  final CombinedFoodSearchOverrides? searchOverrides;

  @override
  State<MealFoodSearchScreen> createState() => _MealFoodSearchScreenState();
}

class _MealFoodSearchScreenState extends State<MealFoodSearchScreen> {
  final _queryController = TextEditingController();
  final _searchHandle = CombinedFoodSearchHandle();

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  void _pickSaved(SavedFood food) {
    Navigator.of(context).pop(food);
  }

  void _pickOfficial(OfficialFoodMatch match) {
    openOfficialFoodDetail(context, widget.controller, match);
  }

  Future<void> _pickPublic(PublicFoodSearchMatch match) async {
    final foodForMeal = await showPublicFoodDetailSheet(
      context: context,
      controller: widget.controller,
      match: match,
      selectForMealEntry: true,
      onBlocked: () => _searchHandle.hideOwner(match.food.ownerUserId),
    );
    if (foodForMeal == null || !mounted) {
      return;
    }
    final added = await PublicFoodMealAddFlow.start(
      context: context,
      controller: widget.controller,
      food: foodForMeal,
      onOpenManualForm: (context, food) => Navigator.of(context).pop(food),
    );
    if (added && mounted) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DesignPage(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const DesignTitleBlock(
            title: '食品を探す',
            subtitle: '保存済み、定番の食品、公開食品をまとめて表示します。',
          ),
          DesignSearchField(
            key: const Key('meal-food-search-field'),
            controller: _queryController,
            hintText: '食品名で検索',
          ),
          const SizedBox(height: 18),
          CombinedFoodSearch(
            controller: widget.controller,
            query: _queryController,
            handle: _searchHandle,
            officialFoods: widget.searchOverrides?.officialFoods,
            searchSaved: widget.searchOverrides?.searchSaved,
            searchOfficial: widget.searchOverrides?.searchOfficial,
            searchPublic: widget.searchOverrides?.searchPublic,
            debounce:
                widget.searchOverrides?.debounce ??
                const Duration(milliseconds: 250),
            onSavedFood: _pickSaved,
            onOfficialFood: _pickOfficial,
            onPublicFood: _pickPublic,
          ),
        ],
      ),
    );
  }
}
