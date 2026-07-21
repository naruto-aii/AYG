import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/open_food_facts_config.dart';

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
  });

  final String? name;
  final double? kcalPerUnit;
  final double? proteinPerUnit;
  final double? fatPerUnit;
  final double? carbPerUnit;
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
  /// テスト用に public。Prototype 用 OFF 連携（READ のみ）。
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
    );
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
