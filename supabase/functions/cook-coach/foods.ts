// レシピが参照する成分表の行。food_code は official_foods にあるコード。
// 100g あたりの値は八訂の掲載値に合わせたもので、チェックとテストで使う。
// 本番の選定は毎回 official_foods の値で計算し直す。

export type CookRole = "protein" | "veg" | "staple" | "seasoning" | "oil" | "egg" | "other";

export type CookFood = {
  id: string;
  code: string;
  label: string;
  officialName: string;
  match: string[];
  kcal: number;
  proteinG: number;
  fatG: number;
  carbG: number;
  staple: boolean;
  role: CookRole;
};

export const cookFoods: CookFood[] = [
  food("rice", "01088", "ごはん", "精白米めし", ["ごはん", "ご飯", "白米", "お米"], 156, 2.5, 0.3, 37.1, true, "staple"),
  food("brown", "01085", "玄米ごはん", "玄米めし", ["玄米", "玄米ごはん"], 152, 2.8, 1, 35.6, false, "staple"),
  food("bread", "01026", "食パン", "角形食パン", ["食パン", "パン"], 248, 8.9, 4.1, 46.4, false, "staple"),
  food("udon", "01039", "うどん", "うどんゆで", ["うどん"], 95, 2.6, 0.4, 21.6, false, "staple"),
  food("soba", "01128", "そば", "そばゆで", ["そば", "蕎麦"], 130, 4.8, 1, 26, false, "staple"),
  food("pasta", "01064", "スパゲティ", "マカロニ・スパゲッティゆで", ["スパゲティ", "パスタ"], 149, 5.8, 0.9, 30.3, false, "staple"),
  food("chicken", "11220", "鶏むね肉", "にわとり むね 皮なし 生", ["鶏むね肉", "鶏むね", "鶏胸肉", "鶏肉"], 108, 23.3, 1.5, 0.1, false, "protein"),
  food("thigh", "11224", "鶏もも肉", "にわとり もも 皮なし 生", ["鶏もも肉", "鶏もも", "鶏モモ"], 127, 19, 5.9, 0, false, "protein"),
  food("pork", "11115", "豚こま", "ぶた こま切れ", ["豚こま", "豚こま切れ", "豚コマ", "豚肉"], 183, 18.5, 11.5, 0.2, false, "protein"),
  food("beef", "11019", "牛こま", "うし もも 生", ["牛こま", "牛もも", "牛肉"], 182, 21.2, 10.6, 0.4, false, "protein"),
  food("atsuage", "04039", "厚揚げ", "厚揚げ", ["厚揚げ", "あつあげ"], 344, 18.6, 28, 4.5, false, "protein"),
  food("salmon", "10134", "鮭", "しろさけ 生", ["鮭", "さけ", "サーモン", "しろさけ"], 133, 22.3, 4.1, 0.1, false, "protein"),
  food("tuna", "10263", "ツナ", "ツナ缶", ["ツナ", "ツナ缶"], 232, 17.7, 16.5, 0.1, false, "protein"),
  food("egg", "12004", "卵", "鶏卵 全卵 生", ["卵", "たまご", "玉子"], 151, 12.3, 10.3, 0.3, false, "egg"),
  food("tofu", "04032", "木綿豆腐", "木綿豆腐", ["木綿豆腐", "豆腐"], 73, 7, 4.9, 1.5, false, "protein"),
  food("kinu", "04033", "絹ごし豆腐", "絹ごし豆腐", ["絹ごし豆腐", "絹豆腐", "冷奴"], 56, 5.3, 3.5, 2, false, "protein"),
  food("natto", "04046", "納豆", "納豆", ["納豆"], 184, 16.5, 10, 12.1, false, "protein"),
  food("aburaage", "04040", "油揚げ", "油揚げ 生", ["油揚げ"], 386, 18.6, 33.1, 2.5, false, "other"),
  food("cabbage", "06061", "キャベツ", "キャベツ 結球葉 生", ["キャベツ"], 23, 1.3, 0.1, 5.2, false, "veg"),
  food("hakusai", "06233", "白菜", "はくさい 結球葉 生", ["白菜", "はくさい"], 14, 0.8, 0.1, 3.2, false, "veg"),
  food("piman", "06245", "ピーマン", "青ピーマン 果実 生", ["ピーマン"], 20, 0.9, 0.2, 5.1, false, "veg"),
  food("moyashi", "06291", "もやし", "りょくとうもやし 生", ["もやし"], 14, 1.7, 0.1, 2.6, false, "veg"),
  food("onion", "06153", "玉ねぎ", "たまねぎ りん茎 生", ["玉ねぎ", "たまねぎ", "タマネギ"], 33, 1, 0.1, 7.6, false, "veg"),
  food("spinach", "06267", "ほうれん草", "ほうれんそう 葉 生", ["ほうれん草", "ほうれんそう"], 18, 2.2, 0.4, 3.1, false, "veg"),
  food("tomato", "06182", "トマト", "トマト 果実 生", ["トマト"], 20, 0.7, 0.1, 4.7, false, "veg"),
  food("carrot", "06214", "にんじん", "にんじん 根 生", ["にんじん", "人参"], 35, 0.6, 0.1, 8.7, false, "veg"),
  food("potato", "02017", "じゃがいも", "じゃがいも 塊茎 生", ["じゃがいも", "ジャガイモ", "ポテト"], 76, 1.8, 0.1, 17.6, false, "veg"),
  food("broccoli", "06264", "ブロッコリー", "ブロッコリー ゆで", ["ブロッコリー"], 30, 3.9, 0.4, 5.2, false, "veg"),
  food("cucumber", "06065", "きゅうり", "きゅうり 果実 生", ["きゅうり"], 13, 1, 0.1, 3, false, "veg"),
  food("eggplant", "06191", "なす", "なす 果実 生", ["なす", "ナス"], 18, 1, 0.1, 5.1, false, "veg"),
  food("daikon", "06134", "大根", "だいこん 根 生", ["大根", "だいこん"], 15, 0.4, 0.1, 4.1, false, "veg"),
  food("negi", "06226", "ねぎ", "根深ねぎ 生", ["ねぎ", "長ねぎ", "ネギ"], 28, 1.4, 0.1, 6.3, false, "veg"),
  food("shimeji", "08017", "しめじ", "ぶなしめじ ゆで", ["しめじ"], 22, 2.7, 0.2, 5.2, false, "veg"),
  food("pumpkin", "06049", "かぼちゃ", "かぼちゃ ゆで", ["かぼちゃ"], 80, 1.6, 0.3, 21.3, false, "veg"),
  food("ginger", "06103", "しょうが", "しょうが 根茎 生", ["しょうが", "生姜"], 30, 0.9, 0.3, 6.6, false, "other"),
  food("garlic", "06223", "にんにく", "にんにく りん茎 生", ["にんにく", "ニンニク"], 134, 6, 0.9, 27.5, false, "other"),
  food("milk", "13003", "牛乳", "普通牛乳", ["牛乳"], 61, 3.3, 3.8, 4.8, false, "other"),
  food("cheese", "13040", "プロセスチーズ", "プロセスチーズ", ["チーズ", "プロセスチーズ"], 313, 22.7, 26, 1.3, false, "other"),
  food("oil", "14006", "サラダ油", "調合油", ["サラダ油", "油"], 921, 0, 100, 0, true, "oil"),
  food("sesame", "14002", "ごま油", "ごま油", ["ごま油"], 921, 0, 100, 0, true, "oil"),
  food("butter", "14017", "バター", "有塩バター", ["バター"], 700, 0.6, 81, 0.2, true, "oil"),
  food("soy", "17007", "しょうゆ", "こいくちしょうゆ", ["しょうゆ", "醤油"], 71, 7.7, 0, 7.1, true, "seasoning"),
  food("mirin", "16025", "みりん", "本みりん", ["みりん", "本みりん"], 241, 0.1, 0, 43, true, "seasoning"),
  food("sugar", "03003", "砂糖", "上白糖", ["砂糖"], 386, 0, 0, 100, true, "seasoning"),
  food("salt", "17012", "塩", "食塩", ["塩", "食塩"], 0, 0, 0, 0, true, "seasoning"),
  food("miso", "17045", "味噌", "米みそ 淡色辛みそ", ["味噌", "みそ"], 186, 12.5, 6, 21, true, "seasoning"),
  food("vinegar", "17015", "酢", "穀物酢", ["酢", "お酢"], 25, 0.1, 0, 2.4, true, "seasoning"),
  food("pepper", "17063", "こしょう", "黒こしょう", ["こしょう", "胡椒", "コショウ"], 378, 11, 6, 66, true, "seasoning"),
  food("dashi", "17028", "顆粒だし", "顆粒だし", ["顆粒だし", "だし", "和風だし"], 230, 18, 2, 36, true, "seasoning"),
  food("sake", "17138", "料理酒", "料理酒", ["料理酒", "酒"], 110, 0.2, 0, 5, true, "seasoning"),
];

const byId = new Map(cookFoods.map((item) => [item.id, item]));

export function cookFood(id: string): CookFood {
  const found = byId.get(id);
  if (!found) {
    throw new Error(`unknown cook food ${id}`);
  }
  return found;
}

function food(
  id: string,
  code: string,
  label: string,
  officialName: string,
  match: string[],
  kcal: number,
  proteinG: number,
  fatG: number,
  carbG: number,
  staple: boolean,
  role: CookRole,
): CookFood {
  return { id, code, label, officialName, match, kcal, proteinG, fatG, carbG, staple, role };
}
