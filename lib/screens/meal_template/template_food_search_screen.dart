import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/official_food.dart';
import '../../models/public_food_search_match.dart';
import '../../models/saved_food.dart';
import '../../repositories/official_food_repository.dart';
import '../../services/usage_record.dart';
import '../../state/app_controller.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_icons.dart';
import '../../theme/app_typography.dart';
import '../../utils/nutrition_format.dart';
import '../../widgets/design/design_button.dart';
import '../../widgets/design/design_field.dart';
import '../../widgets/design/design_page.dart';
import '../../widgets/design/settings_row.dart';
import '../../widgets/official_food/official_food_search_section.dart';

/// 食事テンプレートとウィジェットの食品選び。
///
/// 食事登録と同じく、保存済み食品・公開食品・食品成分表を検索できる。
/// 選んだ食品は食事には足さず、呼び出し元へ返す。
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
  List<SavedFood> _saved = const [];
  List<PublicFoodSearchMatch> _public = const [];
  bool _searchingPublic = false;
  String? _publicMessage;
  Timer? _savedTimer;
  int _savedGeneration = 0;

  @override
  void initState() {
    super.initState();
    _queryController.addListener(_scheduleSaved);
    unawaited(_loadSaved(''));
  }

  @override
  void dispose() {
    _savedTimer?.cancel();
    _queryController.removeListener(_scheduleSaved);
    _queryController.dispose();
    super.dispose();
  }

  void _scheduleSaved() {
    _savedTimer?.cancel();
    final query = _queryController.text.trim();
    _savedTimer = Timer(const Duration(milliseconds: 250), () {
      unawaited(_loadSaved(query));
    });
  }

  Future<void> _loadSaved(String query) async {
    final generation = ++_savedGeneration;
    final foods = query.isEmpty
        ? await widget.controller.getOwnSavedFoodSuggestions()
        : await widget.controller.searchOwnSavedFoods(query);
    if (!mounted || generation != _savedGeneration) {
      return;
    }
    if (_queryController.text.trim() != query) {
      return;
    }
    setState(() => _saved = foods);
  }

  Future<void> _searchPublic() async {
    final query = _queryController.text.trim();
    if (query.isEmpty) {
      setState(() {
        _public = const [];
        _publicMessage = '食品名を入れてから公開食品を検索してください';
      });
      return;
    }
    setState(() {
      _searchingPublic = true;
      _publicMessage = null;
    });
    try {
      final results = await widget.controller.searchPublicSavedFoods(query);
      if (!mounted) {
        return;
      }
      setState(() {
        _public = results;
        _searchingPublic = false;
        _publicMessage = results.isEmpty ? '該当する公開食品が見つかりませんでした' : null;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _searchingPublic = false;
        _public = const [];
        _publicMessage = '公開食品の検索に失敗しました';
      });
    }
  }

  void _pickSaved(SavedFood food) {
    Navigator.of(context).pop(food);
  }

  void _pickPublic(PublicFoodSearchMatch match) {
    Navigator.of(context).pop(match.food);
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
            subtitle: '食事の登録と同じです。保存済み食品と食品成分表は入力すると出ます。公開食品は検索で探します。',
          ),
          DesignSearchField(
            key: const Key('template-food-search-field'),
            controller: _queryController,
            hintText: '食品名で検索',
            onSubmitted: (_) => _searchPublic(),
          ),
          const SizedBox(height: 10),
          DesignButton(
            key: const Key('template-food-search-public'),
            label: _searchingPublic ? '検索中...' : '公開食品を検索',
            showTrailingIcon: false,
            height: 52,
            loading: _searchingPublic,
            onPressed: _searchingPublic ? null : _searchPublic,
          ),
          const SizedBox(height: 18),
          if (_saved.isNotEmpty) ...[
            Text('保存済み', style: AppTypography.titleS),
            const SizedBox(height: 8),
            for (final food in _saved) ...[
              SettingsRow(
                icon: AppIcons.bookmark,
                title: food.name,
                subtitle:
                    '${widget.controller.formatSavedFoodBaseLabel(food)} ・ '
                    '${formatNullableNutrient(food.kcalPerBase)} kcal',
                onTap: () => _pickSaved(food),
              ),
              const SizedBox(height: 8),
            ],
          ],
          OfficialFoodSearchSection(
            query: _queryController,
            repository: widget.officialFoods,
            onSearched: (query) => widget.controller.recordFoodSearch(
              source: FoodSearchSources.officialFood,
              query: query,
            ),
            onSelected: _pickOfficial,
          ),
          if (_publicMessage != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                _publicMessage!,
                style: AppTypography.bodyS.copyWith(color: AppColors.textMuted),
              ),
            ),
          if (_public.isNotEmpty) ...[
            Text('公開食品', style: AppTypography.titleS),
            const SizedBox(height: 8),
            for (final match in _public) ...[
              SettingsRow(
                icon: AppIcons.meal,
                title: match.food.name,
                subtitle:
                    '${widget.controller.formatSavedFoodBaseLabel(match.food)} ・ '
                    '${formatNullableNutrient(match.food.kcalPerBase)} kcal',
                onTap: () => _pickPublic(match),
              ),
              const SizedBox(height: 8),
            ],
          ],
          if (_saved.isEmpty && _public.isEmpty && _publicMessage == null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(
                '食品名を入れると、保存済み食品と食品成分表から候補が出ます。',
                textAlign: TextAlign.center,
                style: AppTypography.bodyS.copyWith(color: AppColors.textMuted),
              ),
            ),
        ],
      ),
    );
  }
}
