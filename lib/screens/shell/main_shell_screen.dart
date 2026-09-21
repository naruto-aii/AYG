import 'package:flutter/material.dart';

import '../../repositories/authentication_repository.dart';
import '../../repositories/health_repository.dart';
import '../../services/open_food_facts_service.dart';
import '../../state/app_controller.dart';
import '../../widgets/navigation/calonavi_tab_bar.dart';
import '../../widgets/layout/app_responsive.dart';
import '../../widgets/layout/app_sidebar_navigation.dart';
import '../food/food_form_navigation.dart';
import '../history/history_calendar_screen.dart';
import '../food/food_tab_screen.dart';
import '../home/home_screen.dart';
import '../settings/settings_screen.dart';
import '../weight/weight_placeholder_screen.dart';
import '../workout/workout_tab_screen.dart';

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
  int _selectedIndex = 0;

  void _selectTab(int index) {
    setState(() => _selectedIndex = index);
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
      HomeScreen(
        controller: widget.controller,
        openFoodFactsService: widget.openFoodFactsService,
        foodFormBuilder: widget.foodFormBuilder,
        onOpenHistoryCalendar: _openHistoryCalendar,
        onOpenWorkoutTab: () => _selectTab(2),
        onOpenWeightTab: () => _selectTab(3),
      ),
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
      const WeightPlaceholderScreen(),
      SettingsScreen(
        controller: widget.controller,
        authenticationRepository: widget.authenticationRepository,
        healthRepository: widget.healthRepository,
        openFoodFactsService: widget.openFoodFactsService,
      ),
    ];

    final useSidebar = isDesktopLayout(context);

    if (useSidebar) {
      return Scaffold(
        body: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppSidebarNavigation(
              selectedIndex: _selectedIndex,
              onDestinationSelected: _selectTab,
            ),
            const VerticalDivider(width: 1, thickness: 1),
            Expanded(
              child: IndexedStack(index: _selectedIndex, children: screens),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: screens),
      bottomNavigationBar: CalonaviTabBar(
        screenIndex: _selectedIndex,
        onSelectScreen: _selectTab,
      ),
    );
  }
}
