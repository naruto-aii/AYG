import 'package:ayg/utils/food_name_normalizer.dart';
import 'package:ayg/utils/food_search_normalizer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('matches the shared search-key cases', () {
    const cases = <String, String>{
      'ご飯': 'ご飯',
      'ごはん': 'ごはん',
      'ゴハン': 'ごはん',
      'ｺﾞﾊﾝ': 'ごはん',
      '白米': '白米',
      'ライス': 'らいす',
      'ﾗｲｽ': 'らいす',
      'ラーメン': 'らめん',
      'らーめん': 'らめん',
      'トースト': 'とすと',
      '食パン': '食ぱん',
      'ギョーザ': 'ぎょざ',
      'カレーライスのルー': 'かれらいすのる',
      'ウィンナー': 'うぃんな',
      'ＡＢＣ': 'abc',
      'ご　飯': 'ご飯',
      'たまご': 'たまご',
      'タマゴ': 'たまご',
      '鶏むね': '鶏むね',
      'とうふ': 'とうふ',
      'ぎゅうにゅう': 'ぎゅうにゅう',
    };
    for (final entry in cases.entries) {
      expect(
        FoodSearchNormalizer.normalize(entry.key),
        entry.value,
        reason: entry.key,
      );
    }
  });

  test('leaves the saved-food name normalizer unchanged', () {
    expect(FoodNameNormalizer.normalize('  ゴハン  '), 'ゴハン');
    expect(FoodNameNormalizer.normalize('ご　飯'), 'ご 飯');
    expect(FoodSearchNormalizer.normalize('  ゴハン  '), 'ごはん');
  });
}
