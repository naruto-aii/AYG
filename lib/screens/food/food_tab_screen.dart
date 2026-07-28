import 'package:flutter/material.dart';

import '../../models/food_entry.dart';
import '../../services/open_food_facts_service.dart';
import '../../state/app_controller.dart';
import '../../theme/app_spacing.dart';
import '../../utils/history_grouping.dart';
import '../../widgets/brand/app_logo.dart';
import '../../widgets/common/app_confirm_dialog.dart';
import '../../widgets/history/food_history_list.dart';
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
      await controller.deleteFood(entry.id);
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
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _openFoodForm(context),
            icon: const Icon(Icons.add),
            label: const Text('食事追加'),
          ),
          body: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screenPadding,
                    AppSpacing.screenPadding,
                    AppSpacing.screenPadding,
                    AppSpacing.sm,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const AppLogo(height: 28),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        '食事',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: FoodHistoryList(
                    dateGroups: displayGroups,
                    onTapEntry: (entry) => _openFoodForm(context, entry: entry),
                    onDeleteEntry: (entry) =>
                        _confirmDeleteFood(context, entry),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
