import 'package:flutter/material.dart';

import '../../constants/app_strings.dart';
import '../../repositories/authentication_repository.dart';
import '../../repositories/health_repository.dart';
import '../../services/open_food_facts_service.dart';
import '../../state/app_controller.dart';
import '../food/food_form_navigation.dart';
import '../food/food_tab_screen.dart';
import '../food/web_food_form_screen.dart';
import '../home/home_screen.dart';
import '../settings/settings_screen.dart';
import '../weight/weight_placeholder_screen.dart';
import '../workout/workout_tab_screen.dart';

class WebMainShellScreen extends StatefulWidget {
  const WebMainShellScreen({
    super.key,
    required this.controller,
    required this.openFoodFactsService,
    required this.authenticationRepository,
  });

  final AppController controller;
  final OpenFoodFactsService openFoodFactsService;
  final AuthenticationRepository authenticationRepository;

  @override
  State<WebMainShellScreen> createState() => _WebMainShellScreenState();
}

class _WebMainShellScreenState extends State<WebMainShellScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final screens = [
      HomeScreen(
        controller: widget.controller,
        openFoodFactsService: widget.openFoodFactsService,
        foodFormBuilder: webFoodFormScreenBuilder,
      ),
      FoodTabScreen(
        controller: widget.controller,
        openFoodFactsService: widget.openFoodFactsService,
        foodFormBuilder: webFoodFormScreenBuilder,
      ),
      WorkoutTabScreen(controller: widget.controller),
      const WeightPlaceholderScreen(),
      SettingsScreen(
        controller: widget.controller,
        authenticationRepository: widget.authenticationRepository,
        hideHealthSettings: true,
      ),
    ];

    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() => _selectedIndex = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: AppStrings.navHome,
          ),
          NavigationDestination(
            icon: Icon(Icons.restaurant_outlined),
            selectedIcon: Icon(Icons.restaurant),
            label: AppStrings.navFood,
          ),
          NavigationDestination(
            icon: Icon(Icons.fitness_center_outlined),
            selectedIcon: Icon(Icons.fitness_center),
            label: AppStrings.navWorkout,
          ),
          NavigationDestination(
            icon: Icon(Icons.monitor_weight_outlined),
            selectedIcon: Icon(Icons.monitor_weight),
            label: AppStrings.navWeight,
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: AppStrings.navSettings,
          ),
        ],
      ),
    );
  }
}

Widget webMainShellScreenBuilder({
  required AppController controller,
  required OpenFoodFactsService openFoodFactsService,
  required AuthenticationRepository authenticationRepository,
  HealthRepository? healthRepository,
  FoodFormScreenBuilder? foodFormBuilder,
}) {
  return WebMainShellScreen(
    controller: controller,
    openFoodFactsService: openFoodFactsService,
    authenticationRepository: authenticationRepository,
  );
}
