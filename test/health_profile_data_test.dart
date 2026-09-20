import 'package:ayg/models/health_profile_data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('empty profile has no values', () {
    expect(HealthProfileData.empty.hasAnyValue, isFalse);
  });

  test('weight only counts as a value', () {
    expect(const HealthProfileData(weightKg: 60).hasAnyValue, isTrue);
  });
}
