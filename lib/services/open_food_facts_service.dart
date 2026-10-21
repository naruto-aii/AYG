import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/open_food_facts_config.dart';
import 'analytics/catalog_actions.dart';

enum OffLookupFailure {
  configurationError,
  notFound,
  rateLimited,
  network,
  invalidResponse,
  timeout,
}

class FoodLookupResult {
  const FoodLookupResult({
    this.name,
    this.kcalPerUnit,
    this.proteinPerUnit,
    this.fatPerUnit,
    this.carbPerUnit,
    this.packageGrams,
  });

  final String? name;
  final double? kcalPerUnit;
  final double? proteinPerUnit;
  final double? fatPerUnit;
  final double? carbPerUnit;

  /// 商品の内容量（g）。栄養は 100g あたりなので、1食分にはしない。
  final double? packageGrams;
}

/// バーコードの栄養は 100g あたり。保存する基準量と、食べるグラム。
class BarcodeFoodAmount {
  const BarcodeFoodAmount({
    required this.baseGrams,
    required this.consumedGrams,
  });

  static const baseGramsPerNutrition = 100.0;

  final double baseGrams;
  final double consumedGrams;

  factory BarcodeFoodAmount.fromPackage(double? packageGrams) {
    final consumed =
        packageGrams != null && packageGrams > 0 && packageGrams < 100000
        ? packageGrams
        : baseGramsPerNutrition;
    return BarcodeFoodAmount(
      baseGrams: baseGramsPerNutrition,
      consumedGrams: consumed,
    );
  }
}

class OpenFoodFactsService {
  OpenFoodFactsService({
    required this.userAgent,
    http.Client? client,
    this.timeout = const Duration(seconds: 10),
  }) : _client = client ?? http.Client();

  final String userAgent;
  final http.Client _client;
  final Duration timeout;

  static const _baseUrl = 'https://world.openfoodfacts.org';
  static const _fields = 'code,product_name,nutriments,quantity,serving_size';

  Future<({FoodLookupResult? data, OffLookupFailure? failure})> fetchByBarcode(
    String barcode,
  ) async {
    final started = DateTime.now();
    final result = await _fetchByBarcode(barcode);
    CatalogActions.barcodeLookupResult(
      result: result.failure == null ? 'found' : result.failure!.name,
      latencyMs: DateTime.now().difference(started).inMilliseconds,
    );
    return result;
  }

  Future<({FoodLookupResult? data, OffLookupFailure? failure})> _fetchByBarcode(
    String barcode,
  ) async {
    final trimmed = barcode.trim();
    if (trimmed.isEmpty) {
      return (data: null, failure: OffLookupFailure.notFound);
    }

    if (!_isUserAgentConfigured()) {
      return (data: null, failure: OffLookupFailure.configurationError);
    }

    final uri = Uri.parse('$_baseUrl/api/v3/product/$trimmed?fields=$_fields');

    try {
      final response = await _client
          .get(uri, headers: {'User-Agent': userAgent})
          .timeout(timeout);

      if (response.statusCode == 429) {
        return (data: null, failure: OffLookupFailure.rateLimited);
      }

      if (response.statusCode == 404) {
        return (data: null, failure: OffLookupFailure.notFound);
      }

      if (response.statusCode != 200) {
        return (data: null, failure: OffLookupFailure.network);
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        return (data: null, failure: OffLookupFailure.invalidResponse);
      }

      final result = parseProductResponse(decoded);
      if (result == null) {
        return (data: null, failure: OffLookupFailure.notFound);
      }

      return (data: result, failure: null);
    } on TimeoutException {
      return (data: null, failure: OffLookupFailure.timeout);
    } catch (_) {
      return (data: null, failure: OffLookupFailure.network);
    }
  }

  bool _isUserAgentConfigured() {
    if (userAgent.trim().isEmpty) {
      return false;
    }
    if (userAgent.contains('CONTACT_PLACEHOLDER')) {
      return false;
    }
    if (!OpenFoodFactsConfig.isContactConfigured) {
      return false;
    }
    return true;
  }

  /// v3 API レスポンスから [FoodLookupResult] を生成する。
  /// OFF 提供値をそのまま返す（kcal の 4/9/4 再計算は行わない）。
  static FoodLookupResult? parseProductResponse(Map<String, dynamic> json) {
    final product = json['product'];
    if (product is! Map<String, dynamic>) {
      return null;
    }

    final name = _stringValue(product['product_name']);
    final nutriments = product['nutriments'];
    if (name == null && nutriments is! Map<String, dynamic>) {
      return null;
    }

    final nutrimentsMap = nutriments is Map<String, dynamic>
        ? nutriments
        : <String, dynamic>{};

    return FoodLookupResult(
      name: name,
      kcalPerUnit: _nutrientValue(nutrimentsMap, 'energy-kcal_100g'),
      proteinPerUnit: _nutrientValue(nutrimentsMap, 'proteins_100g'),
      fatPerUnit: _nutrientValue(nutrimentsMap, 'fat_100g'),
      carbPerUnit: _nutrientValue(nutrimentsMap, 'carbohydrates_100g'),
      packageGrams: packageGramsOf(_stringValue(product['quantity'])),
    );
  }

  /// 「45 g」「45g」「0.045 kg」をグラムにする。読めなければ null。
  static double? packageGramsOf(String? raw) {
    if (raw == null) {
      return null;
    }
    final text = raw.trim().toLowerCase().replaceAll(',', '.');
    final match = RegExp(
      r'(\d+(?:\.\d+)?)\s*(kg|g|キログラム|グラム)',
    ).firstMatch(text);
    if (match == null) {
      return null;
    }
    final amount = double.tryParse(match.group(1)!);
    if (amount == null || amount <= 0) {
      return null;
    }
    final unit = match.group(2);
    final grams = unit == 'kg' || unit == 'キログラム' ? amount * 1000 : amount;
    if (!grams.isFinite || grams <= 0 || grams >= 100000) {
      return null;
    }
    return grams;
  }

  static String? _stringValue(Object? value) {
    if (value is! String) {
      return null;
    }
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static double? _nutrientValue(Map<String, dynamic> nutriments, String key) {
    final value = nutriments[key];
    if (value is num) {
      return value.toDouble();
    }
    return null;
  }
}
