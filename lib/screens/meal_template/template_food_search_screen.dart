import 'package:flutter/material.dart';

import '../../models/official_food.dart';
import '../../models/saved_food.dart';
import '../../repositories/official_food_repository.dart';
import '../../state/app_controller.dart';
import '../../widgets/design/design_field.dart';
import '../../widgets/design/design_page.dart';
import '../../widgets/food/combined_food_search.dart';

/// 食事テンプレートとウィジェットの食品選び。
///
/// 食事登録の「食品を探す」と同じ検索結果を使い、選んだ食品は食事には足さない。
class TemplateFoodSearchScreen extends StatefulWidget {
  const TemplateFoodSearchScreen({
    super.key,
    required this.controller,
    this.officialFoods,
  });

  final AppController controller;
  final OfficialFoodRepository? officialFoods;

  @override
  State<TemplateFoodSearchScreen> createState() =>
      _TemplateFoodSearchScreenState();
}

class _TemplateFoodSearchScreenState extends State<TemplateFoodSearchScreen> {
  final _queryController = TextEditingController();

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  void _pickSaved(SavedFood food) {
    Navigator.of(context).pop(food);
  }

  void _pickOfficial(OfficialFoodMatch match) {
    Navigator.of(context).pop(match);
  }

  @override
  Widget build(BuildContext context) {
    return DesignPage(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const DesignTitleBlock(
            title: '食品を検索',
            subtitle: '保存済み、食品成分表、公開食品をまとめて表示します。',
          ),
          DesignSearchField(
            key: const Key('template-food-search-field'),
            controller: _queryController,
            hintText: '食品名で検索',
          ),
          const SizedBox(height: 18),
          CombinedFoodSearch(
            controller: widget.controller,
            query: _queryController,
            officialFoods: widget.officialFoods,
            onSavedFood: _pickSaved,
            onOfficialFood: _pickOfficial,
            onPublicFood: (match) => _pickSaved(match.food),
          ),
        ],
      ),
    );
  }
}
