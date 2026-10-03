import 'package:ayg/models/display_name.dart';
import 'package:ayg/models/user_profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DisplayName', () {
    test('joins the Apple name parts that were actually returned', () {
      expect(
        DisplayName.fromPersonName(givenName: 'Taro', familyName: 'Yamada'),
        'Taro Yamada',
      );
      expect(
        DisplayName.fromPersonName(givenName: ' 花子 ', familyName: ''),
        '花子',
      );
      expect(
        DisplayName.fromPersonName(givenName: null, familyName: null),
        isNull,
      );
      expect(
        DisplayName.fromPersonName(givenName: ' ', familyName: ' '),
        isNull,
      );
    });

    test('reads only full_name and name from auth metadata', () {
      expect(
        DisplayName.fromUserMetadata({'full_name': ' 山田 太郎 ', 'name': 'other'}),
        '山田 太郎',
      );
      expect(
        DisplayName.fromUserMetadata({'name': 'Google User'}),
        'Google User',
      );
      expect(
        DisplayName.fromUserMetadata({
          'given_name': '太郎',
          'family_name': '山田',
          'email': 'a@example.com',
        }),
        isNull,
      );
      expect(DisplayName.fromUserMetadata(null), isNull);
      expect(DisplayName.fromUserMetadata({'full_name': '   '}), isNull);
    });

    test('keeps a saved name ahead of a sign-in suggestion', () {
      expect(
        DisplayName.fieldValue(saved: '自分の名前', suggested: '連携の名前'),
        '自分の名前',
      );
      expect(DisplayName.fieldValue(saved: '  ', suggested: '連携の名前'), '連携の名前');
      expect(DisplayName.fieldValue(saved: null, suggested: null), '');
    });

    test('rejects an empty name and a name past 40 characters', () {
      expect(DisplayName.validate(' '), DisplayNameError.empty);
      expect(DisplayName.validate('あ' * 40), isNull);
      expect(DisplayName.validate('あ' * 41), DisplayNameError.tooLong);
    });
  });

  test('display name does not replace gender', () {
    final profile = UserProfile(
      birthDate: DateTime(1990, 1, 1),
      gender: Gender.female,
      heightCm: 160,
      weightKg: 55,
      displayName: '山田 花子',
    );

    expect(profile.gender, Gender.female);
    expect(profile.displayName, '山田 花子');

    final updated = profile.copyWith(weightKg: 54);
    expect(updated.gender, Gender.female);
    expect(updated.displayName, '山田 花子');
    expect(updated.weightKg, 54);
  });
}
