import 'package:ayg/models/food_visibility.dart';
import 'package:ayg/widgets/saved_food/saved_food_visibility_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('SavedFoodVisibilitySelector defaults to private', (
    tester,
  ) async {
    FoodVisibility? selected = FoodVisibility.private;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SavedFoodVisibilitySelector(
            value: selected!,
            onChanged: (value) => selected = value,
          ),
        ),
      ),
    );

    expect(find.text('非公開'), findsOneWidget);
    expect(find.text('公開'), findsOneWidget);

    await tester.tap(find.text('公開'));
    await tester.pumpAndSettle();

    expect(selected, FoodVisibility.public);
  });
}
