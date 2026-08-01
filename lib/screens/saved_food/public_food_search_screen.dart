import 'package:flutter/material.dart';

import '../../models/public_food_search_match.dart';
import '../../models/saved_food.dart';
import '../../state/app_controller.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/app_empty_state.dart';
import '../../widgets/common/app_loading_state.dart';
import '../../widgets/common/app_text_field.dart';
import '../../widgets/common/primary_button.dart';
import '../../widgets/common/secondary_button.dart';
import '../../widgets/layout/app_content_constraint.dart';
import '../../services/open_food_facts_service.dart';
import '../../services/public_food_meal_add_flow.dart';
import '../../widgets/saved_food/public_food_detail_sheet.dart';
import '../../widgets/saved_food/public_food_search_result_tile.dart';
import '../food/food_form_screen.dart';

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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('食事に追加しました')),
        );
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('食事に追加しました')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.selectForMealEntry ? '公開食品を選択' : '公開食品検索'),
      ),
      body: SafeArea(
        child: AppContentConstraint(
          expandVertically: true,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SegmentedButton<bool>(
                        segments: const [
                          ButtonSegment(
                            value: false,
                            label: Text('食品名'),
                            icon: Icon(Icons.search),
                          ),
                          ButtonSegment(
                            value: true,
                            label: Text('バーコード'),
                            icon: Icon(Icons.qr_code),
                          ),
                        ],
                        selected: {_useBarcodeSearch},
                        onSelectionChanged: (selection) {
                          setState(() => _useBarcodeSearch = selection.first);
                        },
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      if (!_useBarcodeSearch) ...[
                        AppTextField(
                          controller: _queryController,
                          label: '食品名で検索',
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        PrimaryButton(
                          label: _isSearching ? '検索中...' : '検索',
                          icon: Icons.search,
                          loading: _isSearching,
                          onPressed: _isSearching ? null : () => _search(),
                        ),
                      ] else ...[
                        AppTextField(
                          controller: _barcodeController,
                          label: 'バーコード',
                          keyboardType: TextInputType.number,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        SecondaryButton(
                          label: 'バーコードで検索',
                          icon: Icons.qr_code,
                          onPressed: _isSearching ? null : _searchByBarcode,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              Expanded(
                child: _isSearching
                    ? const AppLoadingState()
                    : _errorMessage != null && _results.isEmpty
                    ? AppEmptyState(message: _errorMessage!)
                    : _results.isEmpty
                    ? AppEmptyState(
                        message: _hasSearched
                            ? '該当する公開食品が見つかりませんでした'
                            : '食品名またはバーコードで検索してください',
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                        ),
                        itemCount: _results.length,
                        itemBuilder: (context, index) {
                          final match = _results[index];
                          return PublicFoodSearchResultTile(
                            controller: widget.controller,
                            match: match,
                            onTap: () => _openMatch(match),
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
