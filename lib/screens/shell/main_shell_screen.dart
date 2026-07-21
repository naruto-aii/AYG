import 'package:flutter/material.dart';

import '../../repositories/authentication_repository.dart';
import '../../services/open_food_facts_service.dart';
import '../../state/app_controller.dart';
import '../food/food_tab_screen.dart';
import '../home/home_screen.dart';
import '../settings/settings_placeholder_screen.dart';
import '../weight/weight_placeholder_screen.dart';
import '../workout/workout_tab_screen.dart';

class MainShellScreen extends StatefulWidget {
  const MainShellScreen({
    super.key,
    required this.controller,
    required this.openFoodFactsService,
    required this.authenticationRepository,
  });

  final AppController controller;
  final OpenFoodFactsService openFoodFactsService;
  final AuthenticationRepository authenticationRepository;

  @override
  State<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends State<MainShellScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final screens = [
      HomeScreen(
        controller: widget.controller,
        openFoodFactsService: widget.openFoodFactsService,
      ),
      FoodTabScreen(
        controller: widget.controller,
        openFoodFactsService: widget.openFoodFactsService,
      ),
      WorkoutTabScreen(controller: widget.controller),
      const WeightPlaceholderScreen(),
      SettingsPlaceholderScreen(
        controller: widget.controller,
        authenticationRepository: widget.authenticationRepository,
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
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.restaurant_outlined),
            selectedIcon: Icon(Icons.restaurant),
            label: 'Food',
          ),
          NavigationDestination(
            icon: Icon(Icons.fitness_center_outlined),
            selectedIcon: Icon(Icons.fitness_center),
            label: 'Workout',
          ),
          NavigationDestination(
            icon: Icon(Icons.monitor_weight_outlined),
            selectedIcon: Icon(Icons.monitor_weight),
            label: 'Weight',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
