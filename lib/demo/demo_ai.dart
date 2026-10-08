import '../services/ai_food_lookup_client.dart';
import '../services/photo_meal_client.dart';

/// デモではネットワークへ出さない。料理名と量があれば、その名前を推定に使う。
Future<Object?> demoPhotoMealInvoke(Map<String, Object?> body) async {
  await Future<void>.delayed(const Duration(milliseconds: 600));
  final dish = (body['dish_name'] as String?)?.trim();
  final amount = (body['amount'] as String?)?.trim();
  final name = (dish == null || dish.isEmpty) ? '親子丼' : dish;
  final serving = (amount == null || amount.isEmpty) ? '1杯' : amount;
  return {
    'ok': true,
    'usage_id': 'demo-photo',
    'estimate': {
      'dish_name': name,
      'amount': serving,
      'kcal': 694,
      'protein_g': 34,
      'fat_g': 22,
      'carb_g': 90,
      'confidence': 0.62,
      'items': [
        {
          'name': 'ご飯',
          'amount': '200g',
          'kcal': 336,
          'protein_g': 5,
          'fat_g': 1,
          'carb_g': 74,
        },
        {
          'name': '親子丼の具',
          'amount': serving,
          'kcal': 358,
          'protein_g': 29,
          'fat_g': 21,
          'carb_g': 16,
        },
      ],
    },
  };
}

PhotoMealClient demoPhotoMealClient() {
  return PhotoMealClient(invoke: demoPhotoMealInvoke);
}

Future<Object?> demoFoodLookupInvoke(Map<String, Object?> body) async {
  await Future<void>.delayed(const Duration(milliseconds: 500));
  final query = (body['query'] as String?)?.trim() ?? '';
  final List<Map<String, Object?>> candidates;
  if (query.contains('牛丼')) {
    candidates = [
      _candidate('牛丼（大盛）', '1杯', 820, 32, 28, 110, true),
      _candidate('牛丼（並盛）', '1杯', 570, 22, 18, 80, true),
    ];
  } else if (query.contains('筑前煮')) {
    candidates = [
      _candidate('筑前煮', '1人前', 272, 18, 8, 32, false),
      _candidate('筑前煮（煮汁ひかえめ）', '1人前', 214, 16, 6, 26, false),
    ];
  } else {
    candidates = [
      _candidate(query.isEmpty ? '料理' : query, '1人前', 320, 16, 10, 40, false),
    ];
  }
  return {
    'ok': true,
    'usage_id': 'demo-lookup',
    'cache_hit': false,
    'candidates': candidates,
  };
}

Map<String, Object?> _candidate(
  String name,
  String amount,
  int kcal,
  int protein,
  int fat,
  int carb,
  bool known,
) {
  return {
    'name': name,
    'amount': amount,
    'kcal': kcal,
    'protein_g': protein,
    'fat_g': fat,
    'carb_g': carb,
    'known_product': known,
  };
}

AiFoodLookupClient demoAiFoodLookupClient() {
  return AiFoodLookupClient(invoke: demoFoodLookupInvoke);
}
