import 'package:flutter/material.dart';

import '../../models/public_food_search_match.dart';
import '../../models/saved_food.dart';
import '../../state/app_controller.dart';
import '../../services/open_food_facts_service.dart';
import '../../services/public_food_meal_add_flow.dart';
import '../../widgets/saved_food/public_food_detail_sheet.dart';
import '../food/food_form_screen.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_icons.dart';
import '../../theme/app_typography.dart';
import '../../utils/nutrition_format.dart';
import '../../widgets/design/design_button.dart';
import '../../widgets/design/design_field.dart';
import '../../widgets/design/design_page.dart';
import '../../widgets/design/settings_row.dart';
import '../../widgets/design/weight_parts.dart';

class PublicFoodSearchScreen extends StatefulWidget {
  const PublicFoodSearchScreen({
    super.key,
    required this.controller,
    this.openFoodFactsService,
    this.selectForMealEntry = false,
  });

  final AppController controller;
  final OpenFoodFactsService? openFoodFactsService;
  final bool selectForMealEntry;

  @override
  State<PublicFoodSearchScreen> createState() => _PublicFoodSearchScreenState();
}

class _PublicFoodSearchScreenState extends State<PublicFoodSearchScreen> {
  final _queryController = TextEditingController();
  final _barcodeController = TextEditingController();
  List<PublicFoodSearchMatch> _results = const [];
  bool _isSearching = false;
  String? _errorMessage;
  bool _hasSearched = false;
  bool _useBarcodeSearch = false;

  @override
  void dispose() {
    _queryController.dispose();
    _barcodeController.dispose();
    super.dispose();
  }

  Future<void> _search({String? queryOverride}) async {
    final query = (queryOverride ?? _queryController.text).trim();
    if (query.isEmpty) {
      setState(() {
        _results = const [];
        _errorMessage = '検索キーワードを入力してください';
        _hasSearched = true;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _errorMessage = null;
      _hasSearched = true;
    });

    try {
      final results = await widget.controller.searchPublicSavedFoods(query);
      if (!mounted) {
        return;
      }
      setState(() {
        _results = results;
        _isSearching = false;
        if (results.isEmpty) {
          _errorMessage = '該当する公開食品が見つかりませんでした';
        }
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isSearching = false;
        _errorMessage = '検索に失敗しました。食事の保存には影響しません。';
        _results = const [];
      });
    }
  }

  Future<void> _searchByBarcode() async {
    final barcode = _barcodeController.text.trim();
    if (barcode.isEmpty) {
      setState(() {
        _errorMessage = 'バーコードを入力してください';
        _hasSearched = true;
      });
      return;
    }
    _queryController.text = barcode;
    await _search(queryOverride: barcode);
  }

  Future<void> _openMatch(PublicFoodSearchMatch match) async {
    final foodForMeal = await showPublicFoodDetailSheet(
      context: context,
      controller: widget.controller,
      match: match,
      selectForMealEntry: widget.selectForMealEntry,
      onBlocked: () {
        setState(() {
          _results = _results
              .where((item) => item.food.ownerUserId != match.food.ownerUserId)
              .toList();
        });
      },
    );
    if (foodForMeal != null && mounted) {
      await _handleUseForMeal(foodForMeal);
    }
  }

  Future<void> _handleUseForMeal(SavedFood food) async {
    if (widget.selectForMealEntry) {
      final added = await PublicFoodMealAddFlow.start(
        context: context,
        controller: widget.controller,
        food: food,
        onOpenManualForm: (context, food) => Navigator.of(context).pop(food),
      );
      if (added && mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('食事に追加しました')));
      }
      return;
    }

    final service = widget.openFoodFactsService;
    final added = await PublicFoodMealAddFlow.start(
      context: context,
      controller: widget.controller,
      food: food,
      onOpenManualForm: service == null
          ? null
          : (context, food) {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (context) => FoodFormScreen(
                    controller: widget.controller,
                    openFoodFactsService: service,
                    initialPublicFood: food,
                  ),
                ),
              );
            },
    );
    if (added && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('食事に追加しました')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return DesignPage(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DesignTitleBlock(
            title: widget.selectForMealEntry ? '公開食品を選ぶ' : '公開食品から追加',
            subtitle: 'みんなが登録した食品から探して追加できます。',
          ),
          DesignChipGroup<bool>(
            values: const [false, true],
            labelOf: (barcode) => barcode ? 'バーコード' : '食品名',
            selected: _useBarcodeSearch,
            onChanged: (barcode) => setState(() => _useBarcodeSearch = barcode),
          ),
          const SizedBox(height: 12),
          DesignSearchField(
            controller: _useBarcodeSearch
                ? _barcodeController
                : _queryController,
            hintText: _useBarcodeSearch ? '例）4901001234567' : '食品名で検索',
            keyboardType: _useBarcodeSearch ? TextInputType.number : null,
            onSubmitted: (_) {
              if (_isSearching) return;
              _useBarcodeSearch ? _searchByBarcode() : _search();
            },
          ),
          const SizedBox(height: 10),
          DesignButton(
            label: _isSearching ? '検索中...' : '検索',
            showTrailingIcon: false,
            height: 52,
            loading: _isSearching,
            onPressed: _isSearching
                ? null
                : () => _useBarcodeSearch ? _searchByBarcode() : _search(),
          ),
          const SizedBox(height: 18),
          if (_isSearching)
            const SizedBox.shrink()
          else if (_results.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Text(
                _errorMessage != null
                    ? _errorMessage!
                    : _hasSearched
                    ? '該当する公開食品が見つかりませんでした'
                    : '食品名またはバーコードで検索してください',
                textAlign: TextAlign.center,
                style: AppTypography.bodyS.copyWith(color: AppColors.textMuted),
              ),
            )
          else
            for (final match in _results) ...[
              SettingsRow(
                icon: AppIcons.meal,
                title: match.food.name,
                subtitle:
                    '${widget.controller.formatSavedFoodBaseLabel(match.food)} ・ '
                    '${formatNullableNutrient(match.food.kcalPerBase)} kcal ・ '
                    '${match.hasLowRating ? '評価に注意' : 'Good ${match.goodCount}'}',
                onTap: () => _openMatch(match),
              ),
              const SizedBox(height: 8),
            ],
          if (_results.isNotEmpty)
            Text(
              '気になる食品を選ぶと、内容を確認してから追加できます。',
              textAlign: TextAlign.center,
              style: AppTypography.caption.copyWith(color: AppColors.textMuted),
            ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
