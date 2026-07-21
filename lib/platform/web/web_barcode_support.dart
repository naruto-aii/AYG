import 'package:flutter/foundation.dart';

import '../../services/open_food_facts_service.dart';
import '../../utils/nutrition_format.dart';

/// Web 上で HTTPS コンテキストかどうか（カメラ API 前提）。
bool isWebBarcodeScanAvailable({Uri? baseUri}) {
  if (!kIsWeb) {
    return false;
  }
  final uri = baseUri ?? Uri.base;
  return uri.scheme == 'https';
}

/// 13 桁 JAN / EAN-13 正規化。
String? normalizeJanEan13Barcode(String? raw) => normalizeEan13Barcode(raw);

/// 同一コードの連続検出を防止する。
class DuplicateBarcodeDetector {
  String? _lastAcceptedCode;

  bool shouldAccept(String normalizedCode) {
    if (_lastAcceptedCode == normalizedCode) {
      return false;
    }
    _lastAcceptedCode = normalizedCode;
    return true;
  }

  void reset() {
    _lastAcceptedCode = null;
  }
}

/// スキャン結果を Open Food Facts 検索へ渡す。
class WebBarcodeLookup {
  const WebBarcodeLookup(this._service);

  final OpenFoodFactsService _service;

  Future<
    ({FoodLookupResult? data, OffLookupFailure? failure, String? normalized})
  >
  lookupRaw(String raw) async {
    final normalized = normalizeJanEan13Barcode(raw);
    if (normalized == null) {
      return (data: null, failure: OffLookupFailure.notFound, normalized: null);
    }

    final result = await _service.fetchByBarcode(normalized);
    return (data: result.data, failure: result.failure, normalized: normalized);
  }
}

String messageForOffFailure(OffLookupFailure failure) {
  return switch (failure) {
    OffLookupFailure.configurationError =>
      'User-Agent（連絡先）が未設定です。設定後に再度お試しください。',
    OffLookupFailure.notFound => '商品が見つかりませんでした。手入力してください。',
    OffLookupFailure.rateLimited => 'アクセスが集中しています。しばらくしてからお試しください。',
    OffLookupFailure.network => '通信に失敗しました。手入力をご利用ください。',
    OffLookupFailure.invalidResponse => '商品情報を読み取れませんでした。手入力してください。',
    OffLookupFailure.timeout => '通信がタイムアウトしました。手入力してください。',
  };
}
