import 'package:ayg/models/public_food_search_match.dart';
import 'package:ayg/models/saved_food.dart';
import 'package:ayg/services/open_food_facts_service.dart';
import 'package:ayg/state/app_controller.dart';
import 'package:ayg/theme/app_spacing.dart';
import 'package:ayg/widgets/common/app_card.dart';
import 'package:ayg/widgets/common/app_empty_state.dart';
import 'package:ayg/widgets/common/app_loading_state.dart';
import 'package:ayg/widgets/common/app_text_field.dart';
import 'package:ayg/widgets/common/primary_button.dart';
import 'package:ayg/widgets/common/secondary_button.dart';
import 'package:ayg/widgets/saved_food/public_food_detail_sheet.dart';
import 'package:ayg/widgets/saved_food/public_food_search_result_tile.dart';
import 'package:flutter/material.dart';

import 'prototype_food_fixtures.dart';

/// Screenshot専用。本番 [PublicFoodSearchScreen] と同じUIを描画し、
/// fixture repository + seed query で検索結果を自動表示する。
class PrototypePublicFoodSearchPage extends StatefulWidget {
  const PrototypePublicFoodSearchPage({
    super.key,
    required this.controller,
    this.openFoodFactsService,
  });

  final AppController controller;
  final OpenFoodFactsService? openFoodFactsService;

  @override
  State<PrototypePublicFoodSearchPage> createState() =>
      _PrototypePublicFoodSearchPageState();
}

class _PrototypePublicFoodSearchPageState
    extends State<PrototypePublicFoodSearchPage> {
  final _queryController = TextEditingController();
  final _barcodeController = TextEditingController();
  List<PublicFoodSearchMatch> _results = const [];
  bool _isSearching = false;
  String? _errorMessage;
  bool _hasSearched = false;
  bool _useBarcodeSearch = false;

  @override
  void initState() {
    super.initState();
    _queryController.text = prototypePublicSearchSeedQuery;
    WidgetsBinding.instance.addPostFrameCallback((_) => _search());
  }

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
    await showPublicFoodDetailSheet(
      context: context,
      controller: widget.controller,
      match: match,
      selectForMealEntry: false,
      onUseForMeal: _handleUseForMeal,
      onBlocked: () {
        setState(() {
          _results = _results
              .where((item) => item.food.ownerUserId != match.food.ownerUserId)
              .toList();
        });
      },
    );
  }

  void _handleUseForMeal(SavedFood food) {
    final service = widget.openFoodFactsService;
    if (service == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('食事登録画面を開けませんでした')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('公開食品検索')),
      body: SafeArea(
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
    );
  }
}
