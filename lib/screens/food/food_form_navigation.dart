import 'package:flutter/material.dart';

import '../../models/food_entry.dart';
import '../../models/saved_food.dart';
import '../../services/open_food_facts_service.dart';
import '../../state/app_controller.dart';
import 'food_form_screen.dart';
import '../../models/saved_food.dart';

typedef FoodFormScreenBuilder =
    Widget Function({
      required AppController controller,
      required OpenFoodFactsService openFoodFactsService,
      FoodEntry? entry,
      SavedFood? initialPublicFood,
    });

/// プラットフォーム別の食事フォーム画面を開く。
void openFoodFormScreen(
  BuildContext context, {
  required AppController controller,
  required OpenFoodFactsService openFoodFactsService,
  FoodEntry? entry,
  FoodFormScreenBuilder? foodFormBuilder,
}) {
  final builder = foodFormBuilder ?? defaultFoodFormScreenBuilder;
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (context) => builder(
        controller: controller,
        openFoodFactsService: openFoodFactsService,
        entry: entry,
      ),
    ),
  );
}

Widget defaultFoodFormScreenBuilder({
  required AppController controller,
  required OpenFoodFactsService openFoodFactsService,
  FoodEntry? entry,
  SavedFood? initialPublicFood,
}) {
  return FoodFormScreen(
    controller: controller,
    openFoodFactsService: openFoodFactsService,
    entry: entry,
    initialPublicFood: initialPublicFood,
  );
}
