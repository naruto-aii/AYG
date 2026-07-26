import 'package:ayg/config/open_food_facts_config.dart';
import 'package:ayg/services/open_food_facts_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('OpenFoodFactsService.parseProductResponse', () {
    test('parses available fields from v3 response', () {
      final result = OpenFoodFactsService.parseProductResponse({
        'code': '3017620422003',
        'product': {
          'code': '3017620422003',
          'product_name': 'Nutella',
          'nutriments': {
            'energy-kcal_100g': 539,
            'proteins_100g': 6.3,
            'fat_100g': 30.9,
            'carbohydrates_100g': 57.5,
          },
          'quantity': '400 g',
          'serving_size': '15 g',
        },
      });

      expect(result, isNotNull);
      expect(result!.name, 'Nutella');
      expect(result.kcalPerUnit, 539);
      expect(result.proteinPerUnit, 6.3);
      expect(result.fatPerUnit, 30.9);
      expect(result.carbPerUnit, 57.5);
    });

    test('returns null when product is missing', () {
      final result = OpenFoodFactsService.parseProductResponse({'code': '000'});

      expect(result, isNull);
    });

    test('leaves missing nutrients as null', () {
      final result = OpenFoodFactsService.parseProductResponse({
        'product': {
          'product_name': 'Sample Food',
          'nutriments': {'energy-kcal_100g': 100},
        },
      });

      expect(result, isNotNull);
      expect(result!.name, 'Sample Food');
      expect(result.kcalPerUnit, 100);
      expect(result.proteinPerUnit, isNull);
      expect(result.fatPerUnit, isNull);
      expect(result.carbPerUnit, isNull);
    });
  });

  group('OpenFoodFactsService configuration', () {
    test(
      'returns configurationError when User-Agent contains placeholder',
      () async {
        final service = OpenFoodFactsService(
          userAgent: 'AYG/0.1 (CONTACT_PLACEHOLDER)',
        );

        final result = await service.fetchByBarcode('3017620422003');

        expect(result.data, isNull);
        expect(result.failure, OffLookupFailure.configurationError);
      },
    );

    test('reports contact as not configured without dart-define', () {
      expect(OpenFoodFactsConfig.contactEmail, isEmpty);
      expect(OpenFoodFactsConfig.isContactConfigured, isFalse);
      expect(OpenFoodFactsConfig.userAgent, 'AYG/0.1 ()');
    });
  });
}
