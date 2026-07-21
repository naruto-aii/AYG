import 'package:flutter/material.dart';

import '../../models/food_entry.dart';
import '../../services/open_food_facts_service.dart';
import '../../state/app_controller.dart';
import '../../utils/history_grouping.dart';
import '../../widgets/history/food_history_list.dart';
import 'web_food_form_screen.dart';

class WebFoodTabScreen extends StatelessWidget {
  const WebFoodTabScreen({
    super.key,
    required this.controller,
    required this.openFoodFactsService,
  });

  final AppController controller;
  final OpenFoodFactsService openFoodFactsService;

  Future<void> _confirmDeleteFood(BuildContext context, FoodEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('削除確認'),
        content: Text('「${entry.name}」を削除しますか？'),
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

    if (confirmed == true) {
      controller.deleteFood(entry.id);
    }
  }

  void _openFoodForm(BuildContext context, {FoodEntry? entry}) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => WebFoodFormScreen(
          controller: controller,
          openFoodFactsService: openFoodFactsService,
          entry: entry,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, child) {
        final dateGroups = groupFoodEntriesByDate(
          controller.foodEntries,
          referenceDate: DateTime.now(),
        );
        final displayGroups = dateGroups.isEmpty
            ? [
                HistoryDateGroup<FoodEntry>(
                  date: DateTime.now(),
                  label: '今日',
                  items: const [],
                ),
              ]
            : dateGroups;

        return Scaffold(
          appBar: AppBar(title: const Text('食事')),
          floatingActionButton: FloatingActionButton(
            onPressed: () => _openFoodForm(context),
            child: const Icon(Icons.add),
          ),
          body: SafeArea(
            child: FoodHistoryList(
              dateGroups: displayGroups,
              onTapEntry: (entry) => _openFoodForm(context, entry: entry),
              onDeleteEntry: (entry) => _confirmDeleteFood(context, entry),
            ),
          ),
        );
      },
    );
  }
}
