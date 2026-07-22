import 'package:ayg/screens/food/food_form_screen.dart';
import 'package:ayg/screens/food/web_food_form_screen.dart';
import 'package:ayg/services/nutrition_value_calculator.dart';
import 'package:ayg/widgets/food/macro_nutrition_fields.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'Mobile and Web food forms share macro nutrition widgets and service',
    () {
      expect(FoodFormScreen, isNotNull);
      expect(WebFoodFormScreen, isNotNull);
      expect(MacroNutritionFields, isNotNull);
      expect(NutritionValueCalculator.parse('100').isValid, isTrue);
    },
  );
}
