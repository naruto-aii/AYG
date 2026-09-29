import 'package:flutter/material.dart';

import '../../repositories/authentication_repository.dart';
import '../../repositories/health_repository.dart';
import '../../services/open_food_facts_service.dart';
import '../../state/app_controller.dart';
import '../../theme/app_colors.dart';
import '../../widgets/design/design_tab_bar.dart';
import '../../widgets/layout/app_responsive.dart';
import '../../widgets/layout/app_sidebar_navigation.dart';
import '../food/food_form_navigation.dart';
import '../food/food_tab_screen.dart';
import '../history/history_calendar_screen.dart';
import '../home/home_screen.dart';
import '../settings/settings_screen.dart';
import '../weight/weight_tab_screen.dart';
import '../workout/workout_tab_screen.dart';

/// タブの並び。Figma のタブバーと同じで、ホームが中央。
enum ShellTab { food, workout, home, weight, settings }

class MainShellScreen extends StatefulWidget {
  const MainShellScreen({
    super.key,
    required this.controller,
    required this.openFoodFactsService,
    required this.authenticationRepository,
    this.healthRepository,
    this.foodFormBuilder,
  });

  final AppController controller;
  final OpenFoodFactsService openFoodFactsService;
  final AuthenticationRepository authenticationRepository;
  final HealthRepository? healthRepository;
  final FoodFormScreenBuilder? foodFormBuilder;

  @override
  State<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends State<MainShellScreen> {
  ShellTab _selected = ShellTab.home;

  void _selectTab(ShellTab tab) {
    setState(() => _selected = tab);
  }

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

  @override
  Widget build(BuildContext context) {
    final screens = [
      FoodTabScreen(
        controller: widget.controller,
        openFoodFactsService: widget.openFoodFactsService,
        foodFormBuilder: widget.foodFormBuilder,
      ),
      WorkoutTabScreen(
        controller: widget.controller,
        openFoodFactsService: widget.openFoodFactsService,
        foodFormBuilder: widget.foodFormBuilder,
      ),
      HomeScreen(
        controller: widget.controller,
        openFoodFactsService: widget.openFoodFactsService,
        foodFormBuilder: widget.foodFormBuilder,
        onOpenHistoryCalendar: _openHistoryCalendar,
        onOpenWorkoutTab: () => _selectTab(ShellTab.workout),
        onOpenWeightTab: () => _selectTab(ShellTab.weight),
      ),
      WeightTabScreen(controller: widget.controller),
      SettingsScreen(
        controller: widget.controller,
        authenticationRepository: widget.authenticationRepository,
        healthRepository: widget.healthRepository,
        openFoodFactsService: widget.openFoodFactsService,
      ),
    ];

    if (isDesktopLayout(context)) {
      return Scaffold(
        body: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppSidebarNavigation(
              selectedIndex: _selected.index,
              onDestinationSelected: (index) =>
                  _selectTab(ShellTab.values[index]),
            ),
            const VerticalDivider(width: 1, thickness: 1),
            Expanded(
              child: IndexedStack(index: _selected.index, children: screens),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.bgPage,
      body: IndexedStack(index: _selected.index, children: screens),
      bottomNavigationBar: DesignTabBar(
        selectedIndex: _selected.index,
        onSelected: (index) => _selectTab(ShellTab.values[index]),
      ),
    );
  }
}
