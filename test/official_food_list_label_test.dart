import 'package:ayg/models/official_food.dart';
import 'package:ayg/models/official_food_list_label.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const tunaName = '＜魚類＞　（まぐろ類）　くろまぐろ　天然　赤身　生';
  const tunaDisplay = 'くろまぐろ（天然・赤身・生）';

  test('akami heading starts with the cut, category is short', () {
    final match = OfficialFoodMatch(
      foodCode: '10253',
      name: tunaName,
      displayName: tunaDisplay,
      kcal: 115,
    );

    expect(match.listTitle, tunaDisplay);
    expect(match.listTitle.contains('魚類'), isFalse);
    expect(match.listTitle.contains('まぐろ類'), isFalse);
    expect(match.listTitle.startsWith('くろまぐろ'), isTrue);
    expect(match.listCategory, '魚・まぐろ');
  });

  test('missing display name still drops the class headings', () {
    final match = OfficialFoodMatch(foodCode: '10253', name: tunaName);

    expect(match.listTitle, 'くろまぐろ 天然 赤身 生');
    expect(match.listTitle.startsWith('＜'), isFalse);
    expect(match.listCategory, '魚・まぐろ');
  });

  test('rice has no class line', () {
    final match = OfficialFoodMatch(
      foodCode: '01088',
      name: 'こめ　［水稲めし］　精白米　うるち米',
      displayName: '精白米（うるち米・水稲めし）',
    );

    expect(match.listTitle, '精白米（うるち米・水稲めし）');
    expect(match.listCategory, isEmpty);
  });

  test('beef and chicken classes shorten by dropping 類', () {
    expect(OfficialFoodListLabel.category('＜畜肉類＞　うし　［和牛肉］　サーロイン　脂身つき　生'), '畜肉');
    expect(OfficialFoodListLabel.category('＜鳥肉類＞　にわとり　［若どり］　ささみ　生'), '鳥肉');
    expect(
      OfficialFoodListLabel.productTitle(
        displayName: '和牛 サーロイン（脂身つき・生）',
        officialName: '＜畜肉類＞　うし　［和牛肉］　サーロイン　脂身つき　生',
      ),
      '和牛 サーロイン（脂身つき・生）',
    );
  });

  test('long subgroup is left off so the calorie still fits', () {
    expect(OfficialFoodListLabel.category('＜調味料類＞　（ウスターソース類）　ウスターソース'), '調味料');
    expect(
      OfficialFoodListLabel.category('＜牛乳及び乳製品＞　（発酵乳・乳酸菌飲料）　ヨーグルト　全脂無糖'),
      '乳・発酵乳',
    );
    expect(OfficialFoodListLabel.category('＜その他＞　あまに　いり'), isEmpty);
  });

  test('list subtitle joins the short class and the calorie', () {
    final line = OfficialFoodListLabel.category(tunaName);
    expect(
      '$line${OfficialFoodListLabel.categoryKcalSeparator}115 kcal / 100g',
      '魚・まぐろ · 115 kcal / 100g',
    );
  });
}
