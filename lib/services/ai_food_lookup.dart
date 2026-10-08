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
    this.collectionId,
  });

  final String name;
  final String amount;
  final double kcal;
  final double proteinG;
  final double fatG;
  final double carbG;

  /// チェーンや商品の名前として知っているか。数値の出典には使わない。
  final bool knownProduct;

  /// 収集表の行。検索結果には出さない。
  final String? collectionId;

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

/// 量や大きさの言い方。これだけが一致しても、別の料理とは見ない。
const aiFoodLookupSizeWords = <String>{
  '大盛',
  '並盛',
  '小盛',
  '特盛',
  '普通盛',
  '普通',
};

String normalizeAiFoodName(String raw) {
  return raw
      .replaceAll(RegExp(r'[\u0000-\u001f]'), ' ')
      .replaceAll(RegExp(r'[<>]'), '')
      .replaceAll(RegExp(r'[\s\u3000]+'), ' ')
      .trim()
      .toLowerCase();
}

/// 検索語の食品か、その量の違いだけを残す。別の料理は落とす。
bool aiFoodCandidateMatchesQuery(String query, String name) {
  final normalizedQuery = normalizeAiFoodName(query);
  final normalizedName = normalizeAiFoodName(name);
  if (normalizedQuery.isEmpty || normalizedName.isEmpty) {
    return false;
  }
  if (normalizedName.contains(normalizedQuery) ||
      normalizedQuery.contains(normalizedName)) {
    return true;
  }
  final tokens = normalizedQuery
      .split(RegExp(r'[\s()（）・、,./]+'))
      .where((token) => token.length >= 2)
      .toList();
  final food = tokens
      .where((token) => !aiFoodLookupSizeWords.contains(token))
      .toList();
  final required = food.isEmpty ? tokens : food;
  return required.any(normalizedName.contains);
}

List<AiFoodCandidate>? parseAiFoodCandidates(Object? raw, {String? query}) {
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
    if (query != null &&
        !aiFoodCandidateMatchesQuery(query, name.trim())) {
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
        collectionId: item['collection_id'] is String &&
                (item['collection_id'] as String).isNotEmpty
            ? item['collection_id'] as String
            : null,
      ),
    );
  }
  if (candidates.isEmpty) {
    return null;
  }
  return candidates;
}
