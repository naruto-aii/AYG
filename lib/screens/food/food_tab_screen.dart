import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../models/food_entry.dart';
import '../../services/open_food_facts_service.dart';
import '../../state/app_controller.dart';
import '../../utils/history_grouping.dart';
import '../../widgets/common/app_confirm_dialog.dart';
import '../../widgets/history/food_history_list.dart';
import '../../widgets/layout/app_content_constraint.dart';
import '../history/history_calendar_screen.dart';
import '../meal_template/meal_template_list_screen.dart';
import '../alcohol/alcohol_form_screen.dart';
import 'food_form_navigation.dart';

class FoodTabScreen extends StatelessWidget {
  const FoodTabScreen({
    super.key,
    required this.controller,
    required this.openFoodFactsService,
    this.foodFormBuilder,
  });

  final AppController controller;
  final OpenFoodFactsService openFoodFactsService;
  final FoodFormScreenBuilder? foodFormBuilder;

  Future<void> _confirmDeleteFood(BuildContext context, FoodEntry entry) async {
    final confirmed = await showAppConfirmDialog(
      context: context,
      title: '削除確認',
      message: '「${entry.name}」を削除しますか？',
    );

    if (confirmed == true) {
      try {
        await controller.deleteFood(entry.id);
      } catch (error, stackTrace) {
        debugPrint('deleteFood failed: $error\n$stackTrace');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('食事の削除に失敗しました。もう一度お試しください'),
            ),
          );
        }
      }
    }
  }

  void _openFoodForm(BuildContext context, {FoodEntry? entry}) {
    openFoodFormScreen(
      context,
      controller: controller,
      openFoodFactsService: openFoodFactsService,
      entry: entry,
      foodFormBuilder: foodFormBuilder,
    );
  }

  void _openAlcoholForm(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => AlcoholFormScreen(controller: controller),
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
          appBar: AppBar(
            title: const Text('食事'),
            actions: [
              Semantics(
                label: '履歴カレンダー',
                button: true,
                child: IconButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (context) => HistoryCalendarScreen(
                          controller: controller,
                          openFoodFactsService: openFoodFactsService,
                          foodFormBuilder: foodFormBuilder,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.calendar_month_outlined),
                ),
              ),
              Semantics(
                label: '食事テンプレート',
                button: true,
                child: IconButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (context) =>
                            MealTemplateListScreen(controller: controller),
                      ),
                    );
                  },
                  icon: const Icon(Icons.view_list_outlined),
                ),
              ),
              Semantics(
                label: '記録追加',
                button: true,
                child: PopupMenuButton<String>(
                  icon: const Icon(Icons.add),
                  onSelected: (value) {
                    switch (value) {
                      case 'food':
                        _openFoodForm(context);
                      case 'alcohol':
                        _openAlcoholForm(context);
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'food', child: Text('食事を追加')),
                    PopupMenuItem(value: 'alcohol', child: Text('アルコールを追加')),
                  ],
                ),
              ),
            ],
          ),
          body: SafeArea(
            child: AppContentConstraint(
              expandVertically: true,
              child: FoodHistoryList(
                dateGroups: displayGroups,
                onTapEntry: (entry) => _openFoodForm(context, entry: entry),
                onDeleteEntry: (entry) => _confirmDeleteFood(context, entry),
              ),
            ),
          ),
        );
      },
    );
  }
}
