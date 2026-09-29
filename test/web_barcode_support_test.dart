import 'package:ayg/platform/web/web_barcode_support.dart';
import 'package:ayg/services/open_food_facts_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('normalizeJanEan13Barcode', () {
    test('strips non-digit characters', () {
      expect(normalizeJanEan13Barcode('301-7620-4220-03'), '3017620422003');
    });

    test('accepts valid 13-digit JAN/EAN-13', () {
      expect(normalizeJanEan13Barcode('3017620422003'), '3017620422003');
    });

    test('rejects invalid lengths', () {
      expect(normalizeJanEan13Barcode('1234567'), isNull);
      expect(normalizeJanEan13Barcode('12345678901234'), isNull);
      expect(normalizeJanEan13Barcode(''), isNull);
    });
  });

  group('DuplicateBarcodeDetector', () {
    test('accepts first code and rejects immediate duplicate', () {
      final detector = DuplicateBarcodeDetector();

      expect(detector.shouldAccept('3017620422003'), isTrue);
      expect(detector.shouldAccept('3017620422003'), isFalse);
    });

    test('accepts code again after reset', () {
      final detector = DuplicateBarcodeDetector();

      expect(detector.shouldAccept('3017620422003'), isTrue);
      detector.reset();
      expect(detector.shouldAccept('3017620422003'), isTrue);
    });
  });

  group('WebBarcodeLookup', () {
    test('passes normalized barcode to Open Food Facts', () async {
      final service = _RecordingOpenFoodFactsService();
      final lookup = WebBarcodeLookup(service);

      final result = await lookup.lookupRaw('301-7620-4220-03');

      expect(result.normalized, '3017620422003');
      expect(service.lastBarcode, '3017620422003');
      expect(result.data?.name, 'テスト商品');
      expect(result.failure, isNull);
    });

    test('returns notFound for invalid barcode without calling API', () async {
      final service = _RecordingOpenFoodFactsService();
      final lookup = WebBarcodeLookup(service);

      final result = await lookup.lookupRaw('123');

      expect(result.normalized, isNull);
      expect(service.lastBarcode, isNull);
      expect(result.failure, OffLookupFailure.notFound);
    });

    test('returns failure when Open Food Facts lookup fails', () async {
      final service = _RecordingOpenFoodFactsService(
        failure: OffLookupFailure.network,
      );
      final lookup = WebBarcodeLookup(service);

      final result = await lookup.lookupRaw('3017620422003');

      expect(result.normalized, '3017620422003');
      expect(result.failure, OffLookupFailure.network);
      expect(result.data, isNull);
    });
  });

  group('isWebBarcodeScanAvailable', () {
    test('returns false in test VM runtime', () {
      expect(
        isWebBarcodeScanAvailable(
          baseUri: Uri.parse('https://example.com/AYG/'),
        ),
        isFalse,
      );
    });
  });
}

class _RecordingOpenFoodFactsService extends OpenFoodFactsService {
  _RecordingOpenFoodFactsService({this.failure})
    : super(userAgent: 'AYG/0.1 (test@example.com)');

  String? lastBarcode;
  final OffLookupFailure? failure;

  @override
  Future<({FoodLookupResult? data, OffLookupFailure? failure})> fetchByBarcode(
    String barcode,
  ) async {
    lastBarcode = barcode;
    if (failure != null) {
      return (data: null, failure: failure);
    }
    return (
      data: const FoodLookupResult(name: 'テスト商品', kcalPerUnit: 100),
      failure: null,
    );
  }
}
