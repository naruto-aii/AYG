import '../constants/official_food_limits.dart';
import '../models/official_food.dart';
import '../utils/food_search_normalizer.dart';
import 'food_search_fuzzy.dart';

/// 公式食品1件と、その別名。
class OfficialFoodCatalogItem {
  const OfficialFoodCatalogItem({required this.food, this.aliases = const []});

  final OfficialFoodMatch food;
  final List<OfficialFoodAlias> aliases;
}

/// `search_official_foods` と同じ順位。
///
/// 完全一致、前方一致、部分一致の順。別名は食品名と同じ段で比べる。
/// 食品番号ごとに一番よい一致を残す。
/// その3段で1件も無いときだけ、1文字の言い間違いを足す。
class OfficialFoodRanker {
  const OfficialFoodRanker();

  List<OfficialFoodMatch> search({
    required String query,
    required List<OfficialFoodCatalogItem> catalog,
    int limit = 30,
    bool fuzzyFallback = true,
  }) {
    final key = OfficialFoodLimits.cap(
      FoodSearchNormalizer.normalize(OfficialFoodLimits.cap(query)),
    );
    final capped = limit.clamp(0, 100);
    if (key.isEmpty || capped == 0) {
      return const [];
    }

    final hits = <OfficialFoodMatch>[];
    for (final item in catalog) {
      hits.addAll(_strictHits(item, key));
    }
    // 完全・前方・部分が1件でもあれば、言い間違いは足さない。
    if (hits.isEmpty && fuzzyFallback) {
      final fuzzy = <OfficialFoodMatch>[];
      for (final item in catalog) {
        fuzzy.addAll(_fuzzyHits(item, key));
      }
      final close = fuzzy.where((hit) => (hit.candidateRank ?? 9) <= 1);
      hits.addAll(close.isNotEmpty ? close : fuzzy);
    }

    final best = <String, OfficialFoodMatch>{};
    for (final hit in hits) {
      final current = best[hit.foodCode];
      if (current == null || _prefer(hit, current)) {
        best[hit.foodCode] = hit;
      }
    }

    final ordered = best.values.toList()
      ..sort((a, b) {
        final rank = a.matchRank.compareTo(b.matchRank);
        if (rank != 0) {
          return rank;
        }
        final candidate = _candidateFlag(a).compareTo(_candidateFlag(b));
        if (candidate != 0) {
          return candidate;
        }
        final candidateRank = _candidateOrder(a).compareTo(_candidateOrder(b));
        if (candidateRank != 0) {
          return candidateRank;
        }
        final aliasPresence = _aliasMissing(a).compareTo(_aliasMissing(b));
        if (aliasPresence != 0) {
          return aliasPresence;
        }
        final priority = a.priority.compareTo(b.priority);
        if (priority != 0) {
          return priority;
        }
        return a.foodCode.compareTo(b.foodCode);
      });
    if (ordered.length <= capped) {
      return ordered;
    }
    return ordered.sublist(0, capped);
  }

  static List<OfficialFoodMatch> _strictHits(
    OfficialFoodCatalogItem item,
    String key,
  ) {
    final food = item.food;
    final hits = <OfficialFoodMatch>[];
    final nameRank = _bestRank([
      _rank(food.normalizedName, key),
      _rank(FoodSearchNormalizer.normalize(food.displayName), key),
      _rank(FoodSearchNormalizer.normalize(food.name), key),
      _rank(FoodSearchNormalizer.normalize(food.reading), key),
    ]);
    if (nameRank < 9) {
      hits.add(
        _copy(
          food,
          rank: nameRank,
          alias: null,
          aliasReading: null,
          priority: 100,
          isCandidate: false,
          candidateRank: null,
        ),
      );
    }
    for (final alias in item.aliases) {
      final aliasRank = _bestRank([
        _rank(alias.normalized, key),
        _rank(FoodSearchNormalizer.normalize(alias.reading), key),
        _rank(FoodSearchNormalizer.normalize(alias.alias), key),
      ]);
      if (aliasRank < 9) {
        hits.add(
          _copy(
            food,
            rank: aliasRank,
            alias: alias.alias,
            aliasReading: alias.reading,
            priority: alias.priority,
            isCandidate: alias.isCandidate,
            candidateRank: alias.candidateRank,
          ),
        );
      }
    }
    return hits;
  }

  static List<OfficialFoodMatch> _fuzzyHits(
    OfficialFoodCatalogItem item,
    String key,
  ) {
    final food = item.food;
    final hits = <OfficialFoodMatch>[];
    final nameDistance = _fuzzyDistance([
      food.normalizedName,
      FoodSearchNormalizer.normalize(food.displayName),
      FoodSearchNormalizer.normalize(food.name),
      FoodSearchNormalizer.normalize(food.reading),
    ], key);
    if (nameDistance != null) {
      hits.add(
        _copy(
          food,
          rank: 3,
          alias: null,
          aliasReading: null,
          priority: 100,
          isCandidate: true,
          candidateRank: nameDistance,
        ),
      );
    }
    for (final alias in item.aliases) {
      final distance = _fuzzyDistance([
        alias.normalized,
        FoodSearchNormalizer.normalize(alias.reading),
        FoodSearchNormalizer.normalize(alias.alias),
      ], key);
      if (distance != null) {
        hits.add(
          _copy(
            food,
            rank: 3,
            alias: alias.alias,
            aliasReading: alias.reading,
            priority: alias.priority,
            isCandidate: true,
            candidateRank: distance,
          ),
        );
      }
    }
    return hits;
  }

  static int _rank(String haystack, String needle) {
    if (haystack.isEmpty || needle.isEmpty) {
      return 9;
    }
    if (haystack == needle) {
      return 0;
    }
    final at = haystack.indexOf(needle);
    if (at == 0) {
      return 1;
    }
    if (at > 0) {
      return 2;
    }
    return 9;
  }

  static int? _fuzzyDistance(List<String> haystacks, String needle) {
    int? best;
    for (final haystack in haystacks) {
      final distance = FoodSearchFuzzy.distance(haystack, needle);
      if (distance == null) {
        continue;
      }
      if (best == null || distance < best) {
        best = distance;
      }
    }
    return best;
  }

  static int _bestRank(List<int> ranks) {
    var best = 9;
    for (final rank in ranks) {
      if (rank < best) {
        best = rank;
      }
    }
    return best;
  }

  static int _aliasMissing(OfficialFoodMatch match) {
    final alias = match.matchedAlias;
    return (alias == null || alias.isEmpty) ? 1 : 0;
  }

  static int _candidateFlag(OfficialFoodMatch match) => match.isCandidate ? 1 : 0;

  static int _candidateOrder(OfficialFoodMatch match) =>
      match.candidateRank ?? match.priority;

  /// SQL の `distinct on` と同じ順。確定した別名が候補より前。
  static bool _prefer(OfficialFoodMatch candidate, OfficialFoodMatch current) {
    if (candidate.matchRank != current.matchRank) {
      return candidate.matchRank < current.matchRank;
    }
    final candidateFlag = _candidateFlag(candidate).compareTo(
      _candidateFlag(current),
    );
    if (candidateFlag != 0) {
      return candidateFlag < 0;
    }
    final candidateRank = _candidateOrder(candidate).compareTo(
      _candidateOrder(current),
    );
    if (candidateRank != 0) {
      return candidateRank < 0;
    }
    final alias = _aliasMissing(candidate).compareTo(_aliasMissing(current));
    if (alias != 0) {
      return alias < 0;
    }
    if (candidate.priority != current.priority) {
      return candidate.priority < current.priority;
    }
    return (candidate.matchedAlias ?? '').compareTo(current.matchedAlias ?? '') <
        0;
  }

  static OfficialFoodMatch _copy(
    OfficialFoodMatch food, {
    required int rank,
    required String? alias,
    required String? aliasReading,
    required int priority,
    required bool isCandidate,
    required int? candidateRank,
  }) {
    return OfficialFoodMatch(
      foodCode: food.foodCode,
      name: food.name,
      displayName: food.displayName,
      foodGroup: food.foodGroup,
      indexNo: food.indexNo,
      reading: food.reading,
      baseAmount: food.baseAmount,
      unitType: food.unitType,
      kcal: food.kcal,
      proteinG: food.proteinG,
      fatG: food.fatG,
      carbG: food.carbG,
      fiberG: food.fiberG,
      saltEqG: food.saltEqG,
      matchedAlias: alias,
      matchedAliasReading: aliasReading,
      matchRank: rank,
      priority: priority,
      isCandidate: isCandidate,
      candidateRank: candidateRank,
    );
  }
}

extension on OfficialFoodMatch {
  /// 検索キー。食品側の normalized_name は [name] から作る。
  String get normalizedName => FoodSearchNormalizer.normalize(name);
}
