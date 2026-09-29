import 'package:ayg/utils/id_generator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('generateUniqueId', () {
    test('returns distinct UUID v4 values in rapid succession', () {
      final ids = List.generate(100, (_) => generateUniqueId());
      expect(ids.toSet(), hasLength(100));
      for (final id in ids) {
        expect(
          RegExp(
            r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
          ).hasMatch(id),
          isTrue,
        );
      }
    });
  });
}
