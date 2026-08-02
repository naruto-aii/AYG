import 'package:flutter/material.dart';

import '../../models/food_entry.dart';
import '../../services/open_food_facts_service.dart';
import '../../state/app_controller.dart';
import '../../utils/history_grouping.dart';
import '../../utils/local_date.dart';
import '../../widgets/common/delete_with_undo.dart';
import '../../widgets/history/food_history_list.dart';
import '../../widgets/history/history_tab_body.dart';
import '../../widgets/layout/app_content_constraint.dart';
import '../alcohol/alcohol_form_screen.dart';
import '../history/history_calendar_screen.dart';
import '../meal_template/meal_template_list_screen.dart';
import 'food_form_navigation.dart';

class FoodTabScreen extends StatefulWidget {
  const FoodTabScreen({
    super.key,
    required this.controller,
    required this.openFoodFactsService,
    this.foodFormBuilder,
  });

  final AppController controller;
  final OpenFoodFactsService openFoodFactsService;
  final FoodFormScreenBuilder? foodFormBuilder;

  @override
  State<FoodTabScreen> createState() => _FoodTabScreenState();
}

class _FoodTabScreenState extends State<FoodTabScreen> {
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    _selectedDate = localDayStart(DateTime.now());
  }

  DateTime get _initialLoggedAtForNewEntry =>
      initialLoggedAtForSelectedDay(_selectedDate);

  DateTime get _initialConsumedAtForNewEntry => _initialLoggedAtForNewEntry;

  void _openHistoryCalendar() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => HistoryCalendarScreen(
          controller: widget.controller,
          openFoodFactsService: widget.openFoodFactsService,
          foodFormBuilder: widget.foodFormBuilder,
        ),
      ),
    );
  }

  Future<void> _confirmDeleteFood(BuildContext context, FoodEntry entry) async {
    await confirmDeleteWithUndo<FoodEntry>(
      context: context,
      title: '削除確認',
      message: '「${entry.name}」を削除しますか？',
      snapshot: entry,
      onDelete: () => widget.controller.deleteFood(entry.id),
      onRestore: (restored) => widget.controller.addFood(restored),
    );
  }

  void _openFoodForm(BuildContext context, {FoodEntry? entry}) {
    if (entry == null && !canAddRecordOnDay(_selectedDate)) {
      showFutureDayAddBlockedSnackBar(context);
      return;
    }

    openFoodFormScreen(
      context,
      controller: widget.controller,
      openFoodFactsService: widget.openFoodFactsService,
      entry: entry,
      initialLoggedAt: entry == null ? _initialLoggedAtForNewEntry : null,
      foodFormBuilder: widget.foodFormBuilder,
    );
  }

  void _openAlcoholForm(BuildContext context) {
    if (!canAddRecordOnDay(_selectedDate)) {
      showFutureDayAddBlockedSnackBar(context);
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => AlcoholFormScreen(
          controller: widget.controller,
          initialConsumedAt: _initialConsumedAtForNewEntry,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, child) {
        final dateGroups = groupFoodEntriesByDate(
          widget.controller.foodEntries,
          referenceDate: _selectedDate,
          todayOnly: true,
        );
        final displayGroups = dateGroups.isEmpty
            ? [
                HistoryDateGroup<FoodEntry>(
                  date: _selectedDate,
                  label: dateLabelFor(
                    _selectedDate,
                    referenceDate: DateTime.now(),
                  ),
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
                  onPressed: _openHistoryCalendar,
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
                        builder: (context) => MealTemplateListScreen(
                          controller: widget.controller,
                        ),
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
              child: HistoryTabBody(
                selectedDate: _selectedDate,
                onSelectedDateChanged: (date) {
                  setState(() => _selectedDate = date);
                },
                onOpenCalendar: _openHistoryCalendar,
                listChild: FoodHistoryList(
                  dateGroups: displayGroups,
                  onTapEntry: (entry) => _openFoodForm(context, entry: entry),
                  onDeleteEntry: (entry) => _confirmDeleteFood(context, entry),
                  emptyMessage: 'この日の食事記録はありません',
                  emptyActionLabel: canAddRecordOnDay(_selectedDate)
                      ? '食事を追加'
                      : null,
                  onEmptyAction: canAddRecordOnDay(_selectedDate)
                      ? () => _openFoodForm(context)
                      : null,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
