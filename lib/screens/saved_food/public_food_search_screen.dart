import 'package:flutter/material.dart';

import '../../models/public_food_search_match.dart';
import '../../models/saved_food.dart';
import '../../state/app_controller.dart';
import '../../widgets/saved_food/public_food_detail_sheet.dart';
import '../../widgets/saved_food/public_food_search_result_tile.dart';
import '../food/food_form_screen.dart';
import '../../services/open_food_facts_service.dart';

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
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _errorMessage = null;
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
      setState(() => _errorMessage = 'バーコードを入力してください');
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
      selectForMealEntry: widget.selectForMealEntry,
      onUseForMeal: _handleUseForMeal,
    );
  }

  void _handleUseForMeal(SavedFood food) {
    if (widget.selectForMealEntry) {
      Navigator.of(context).pop(food);
      return;
    }

    final service = widget.openFoodFactsService;
    if (service == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('食事登録画面を開けませんでした')));
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => FoodFormScreen(
          controller: widget.controller,
          openFoodFactsService: service,
          initialPublicFood: food,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.selectForMealEntry ? '公開食品を選択' : '公開食品検索'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _queryController,
                  decoration: const InputDecoration(
                    labelText: '食品名で検索',
                    border: OutlineInputBorder(),
                  ),
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _search(),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _isSearching ? null : () => _search(),
                  icon: _isSearching
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.search),
                  label: Text(_isSearching ? '検索中...' : '検索'),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _barcodeController,
                  decoration: const InputDecoration(
                    labelText: 'バーコード',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _isSearching ? null : _searchByBarcode,
                  icon: const Icon(Icons.qr_code),
                  label: const Text('バーコードで検索'),
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _errorMessage!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
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
    );
  }
}
