import 'photo_meal.dart';

/// サーバと同じ件数。食品データベースの行にはしない。
const aiFoodLookupMaxCandidates = 3;
const aiFoodLookupQueryMaxLength = 80;

class AiFoodCandidate {
  const AiFoodCandidate({
    required this.name,
    required this.amount,
    required this.kcal,
    required this.proteinG,
    required this.fatG,
    required this.carbG,
    required this.knownProduct,
  });

  final String name;
  final String amount;
  final double kcal;
  final double proteinG;
  final double fatG;
  final double carbG;

  /// チェーンや商品の名前として知っているか。数値の出典には使わない。
  final bool knownProduct;

  PhotoMealEstimate toEstimate() {
    return PhotoMealEstimate(
      dishName: name,
      amount: amount,
      kcal: kcal,
      proteinG: proteinG,
      fatG: fatG,
      carbG: carbG,
      confidence: 0,
      items: const [],
    );
  }
}

class AiFoodLookupResult {
  const AiFoodLookupResult({
    required this.usageId,
    required this.candidates,
    required this.cacheHit,
  });

  final String? usageId;
  final List<AiFoodCandidate> candidates;
  final bool cacheHit;
}

String clipAiFoodQuery(String query) {
  final trimmed = query.trim();
  if (trimmed.length <= aiFoodLookupQueryMaxLength) {
    return trimmed;
  }
  return trimmed.substring(0, aiFoodLookupQueryMaxLength);
}

List<AiFoodCandidate>? parseAiFoodCandidates(Object? raw) {
  if (raw is! List) {
    return null;
  }
  final candidates = <AiFoodCandidate>[];
  for (final item in raw) {
    if (candidates.length >= aiFoodLookupMaxCandidates) {
      break;
    }
    if (item is! Map) {
      continue;
    }
    final name = item['name'];
    final amount = item['amount'];
    final known = item['known_product'];
    if (name is! String || name.trim().isEmpty || name.trim().length > 80) {
      continue;
    }
    if (amount is! String ||
        amount.trim().isEmpty ||
        amount.trim().length > 40) {
      continue;
    }
    if (known is! bool || !photoMealNutritionOk(item)) {
      continue;
    }
    candidates.add(
      AiFoodCandidate(
        name: name.trim(),
        amount: amount.trim(),
        kcal: (item['kcal'] as num).toDouble(),
        proteinG: (item['protein_g'] as num).toDouble(),
        fatG: (item['fat_g'] as num).toDouble(),
        carbG: (item['carb_g'] as num).toDouble(),
        knownProduct: known,
      ),
    );
  }
  if (candidates.isEmpty) {
    return null;
  }
  return candidates;
}
