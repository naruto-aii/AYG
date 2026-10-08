// 家庭料理100品。各スロットの候補は、その調理で成立するものだけ。
// 料理名の {スロット} は入れ替え後の食品名になる。
// アプリには埋め込まない。追加は recipes.ts を編集し、seed を出して DB へ入れる。

import { totalCookingMinutes } from "./plan.ts";
import { optionFromFood, slot, type CookRecipe, type CookSlot } from "./select.ts";

type Genre = "和" | "洋" | "中" | "エスニック";
type Category = "主菜" | "副菜" | "主食" | "汁物" | "丼麺" | "軽い品";
type Pair = [string, number];

function s(key: string, pairs: Pair[]): CookSlot {
  const options = pairs.map(([id, grams]) => optionFromFood(id, grams));
  return slot(key, options[0].role, options);
}

const stirP: Pair[] = [
  ["chicken", 130], ["thigh", 120], ["pork", 110], ["beef", 110], ["loin", 100],
  ["gPork", 100], ["gChicken", 120], ["gBeef", 100], ["atsuage", 140], ["salmon", 120],
  ["squid", 120], ["shrimp", 120], ["bacon", 70], ["wiener", 80], ["chikuwa", 90],
];
const meatP: Pair[] = [
  ["chicken", 140], ["thigh", 130], ["pork", 120], ["beef", 110], ["loin", 110],
];
const groundP: Pair[] = [["gPork", 110], ["gChicken", 130], ["gBeef", 100]];
const fishP: Pair[] = [
  ["salmon", 120], ["saba", 100], ["hokke", 110], ["aji", 120], ["tara", 140], ["buri", 90], ["ankou", 150],
];
const noodleP: Pair[] = [
  ["chicken", 80], ["pork", 70], ["thigh", 80], ["chikuwa", 80], ["atsuage", 80], ["shrimp", 80],
];
const veg10: Pair[] = [
  ["cabbage", 90], ["hakusai", 100], ["piman", 70], ["moyashi", 90], ["onion", 70],
  ["carrot", 60], ["eggplant", 80], ["spinach", 70], ["komatsuna", 80], ["shimeji", 70],
  ["broccoli", 80], ["daikon", 80], ["negi", 50], ["corn", 70],
];
const leaf: Pair[] = [
  ["spinach", 80], ["komatsuna", 80], ["cabbage", 80], ["hakusai", 100], ["lettuce", 70], ["broccoli", 80],
];

const oil = (g = 8) => s("oil", [["oil", g]]);
const soy = (g = 10) => s("soy", [["soy", g]]);
const mirin = (g = 8) => s("mirin", [["mirin", g]]);
const sugar = (g = 6) => s("sugar", [["sugar", g]]);
const salt = (g = 1) => s("salt", [["salt", g]]);
const pepper = (g = 1) => s("pepper", [["pepper", g]]);
const miso = (g = 12) => s("miso", [["miso", g]]);
const dashi = (g = 6) => s("dashi", [["dashi", g]]);
const sake = (g = 8) => s("sake", [["sake", g]]);
const vinegar = (g = 10) => s("vinegar", [["vinegar", g]]);
const butter = (g = 10) => s("oil", [["butter", g]]);
const ginger = (g = 25) => s("ginger", [["ginger", g]]);
const garlic = (g = 20) => s("garlic", [["garlic", g]]);

function dish(
  id: string,
  name: string,
  genre: Genre,
  category: Category,
  method: string,
  steps: string[],
  slots: CookSlot[],
): CookRecipe {
  return {
    id,
    name,
    genre,
    category,
    method,
    minutes: totalCookingMinutes(steps.join("\n")),
    steps,
    slots,
  };
}

const fry = (extra: string) => [
  "{protein}と{veg}を食べやすく切る。",
  "フライパンを中火にし、{oil}{g:oil}gを熱して{protein}を4分焼く。",
  `{veg}を加えて3分炒め、${extra}`,
  "火を止めて器に盛る。",
];

export function buildCookRecipes(): CookRecipe[] {
  const recipes: CookRecipe[] = [
    dish("shoyu-fry", "{protein}と{veg}の醤油炒め", "和", "主菜", "炒", fry("しょうゆ{g:soy}gとみりん{g:mirin}gを絡める。"), [
      s("protein", stirP), s("veg", veg10), oil(), soy(), mirin(),
    ]),
    dish("miso-fry", "{protein}と{veg}の味噌炒め", "和", "主菜", "炒", fry("味噌{g:miso}gと砂糖{g:sugar}gと料理酒{g:sake}gを絡める。"), [
      s("protein", stirP), s("veg", veg10), oil(), miso(), sugar(), sake(),
    ]),
    dish("salt-fry", "{protein}と{veg}の塩だれ炒め", "和", "主菜", "炒", fry("しょうゆ{g:soy}gと塩{g:salt}gを絡める。"), [
      s("protein", stirP), s("veg", veg10), oil(), soy(8), salt(),
    ]),
    dish("garlic-fry", "{protein}と{veg}のにんにく炒め", "中", "主菜", "炒", [
      "{protein}と{veg}と{garlic}を食べやすく切る。",
      "フライパンを中火にし、{oil}{g:oil}gを熱して{garlic}{g:garlic}gと{protein}を4分炒める。",
      "{veg}としょうゆ{g:soy}gとみりん{g:mirin}gを加えて3分炒め合わせる。",
      "火を止めて器に盛る。",
    ], [s("protein", stirP), s("veg", veg10), garlic(), oil(), soy(), mirin()]),
    dish("chuka-fry", "{protein}と{veg}の中華炒め", "中", "主菜", "炒", fry("しょうゆ{g:soy}gと料理酒{g:sake}gとこしょう{g:pepper}gを絡める。"), [
      s("protein", stirP), s("veg", veg10), oil(), soy(), sake(), pepper(),
    ]),
    dish("sweet-fry", "{protein}と{veg}の甘辛炒め", "和", "主菜", "炒", fry("しょうゆ{g:soy}gとみりん{g:mirin}gと砂糖{g:sugar}gを絡める。"), [
      s("protein", meatP), s("veg", veg10), oil(), soy(), mirin(), sugar(),
    ]),
    dish("shoga", "{protein}の生姜焼き", "和", "主菜", "焼", [
      "{protein}を一口大に切り、{ginger}をすりおろす。",
      "フライパンを中火にし、{oil}{g:oil}gを熱して{protein}を5分焼く。",
      "{ginger}{g:ginger}gとしょうゆ{g:soy}gとみりん{g:mirin}gを加えて3分絡める。",
      "中まで火を通して器に盛る。",
    ], [s("protein", meatP), ginger(), oil(), soy(12), mirin(12)]),
    dish("teriyaki", "{protein}の照り焼き", "和", "主菜", "焼", [
      "{protein}を一口大に切る。",
      "フライパンを中火にし、{oil}{g:oil}gを熱して{protein}を5分焼く。",
      "しょうゆ{g:soy}gとみりん{g:mirin}gと砂糖{g:sugar}gを加えて3分絡め、照りを出す。",
      "火を止めて器に盛る。",
    ], [s("protein", meatP), oil(), soy(12), mirin(10), sugar(6)]),
    dish("shioyaki", "{protein}の塩焼き", "和", "主菜", "焼", [
      "{protein}の水気をふく。",
      "フライパンを中火にし、{oil}{g:oil}gを熱して{protein}を6分焼く。",
      "塩{g:salt}gとこしょう{g:pepper}gをふり、2分焼いて中まで火を通す。",
      "器に盛る。",
    ], [s("protein", meatP), oil(6), salt(), pepper()]),
    dish("nikujaga", "{protein}の肉じゃが", "和", "主菜", "煮", [
      "{protein}とじゃがいもと玉ねぎを食べやすく切る。",
      "鍋に水を300mlと顆粒だし{g:dashi}gを入れて中火で煮立たせる。",
      "{protein}と玉ねぎを入れて8分煮る。",
      "じゃがいもを入れて10分煮る。",
      "しょうゆ{g:soy}gとみりん{g:mirin}gと砂糖{g:sugar}gを加えて7分煮て味を含ませる。",
    ], [
      s("protein", [["pork", 90], ["beef", 90], ["thigh", 100], ["chicken", 100]]),
      s("potato", [["potato", 160]]),
      s("onion", [["onion", 70]]),
      dashi(8), soy(12), mirin(12), sugar(8),
    ]),
    dish("nikudofu", "{protein}の肉豆腐", "和", "主菜", "煮", [
      "{protein}と木綿豆腐と玉ねぎを食べやすく切る。",
      "鍋に水を250mlと顆粒だし{g:dashi}gを入れて煮立たせる。",
      "{protein}と玉ねぎを入れて6分煮る。",
      "木綿豆腐としょうゆ{g:soy}gとみりん{g:mirin}gを加えて5分煮る。",
    ], [
      s("protein", [["pork", 80], ["beef", 80], ["chicken", 90]]),
      s("tofu", [["tofu", 160]]),
      s("onion", [["onion", 50]]),
      dashi(), soy(10), mirin(8),
    ]),
    dish("oyako", "親子丼", "和", "丼麺", "煮", [
      "{protein}と玉ねぎを切る。",
      "鍋に水を150mlと顆粒だし{g:dashi}gを入れて煮立たせる。",
      "{protein}と玉ねぎを入れて6分煮る。",
      "しょうゆ{g:soy}gとみりん{g:mirin}gを加え、卵{g:egg}gを回し入れて2分加熱する。",
      "ごはん{g:rice}gにのせてすぐに出す。",
    ], [
      s("protein", [["chicken", 110], ["thigh", 100]]),
      s("onion", [["onion", 50]]),
      s("egg", [["egg", 50]]),
      s("rice", [["rice", 180]]),
      dashi(), soy(10), mirin(10),
    ]),
    dish("gyudon", "牛こま丼", "和", "丼麺", "煮", [
      "牛こまをほぐし、玉ねぎを薄切りにする。",
      "鍋に水を100mlとしょうゆ{g:soy}gとみりん{g:mirin}gと砂糖{g:sugar}gを入れて煮立たせる。",
      "牛こまと玉ねぎを入れて8分煮て味を含ませる。",
      "ごはん{g:rice}gにのせて出す。",
    ], [
      s("protein", [["beef", 120]]),
      s("onion", [["onion", 60]]),
      s("rice", [["rice", 200]]),
      soy(12), mirin(12), sugar(6),
    ]),
    dish("butadon", "{protein}丼", "和", "丼麺", "焼", [
      "{protein}を一口大に切る。",
      "フライパンを中火にし、{oil}{g:oil}gを熱して{protein}を4分焼く。",
      "しょうゆ{g:soy}gとみりん{g:mirin}gと砂糖{g:sugar}gを加えて3分絡める。",
      "ごはん{g:rice}gにのせて出す。",
    ], [
      s("protein", [["pork", 120], ["loin", 100]]),
      s("rice", [["rice", 190]]),
      oil(), soy(12), mirin(10), sugar(4),
    ]),
    dish("teri-don", "{protein}の照り焼き丼", "和", "丼麺", "焼", [
      "{protein}を一口大に切る。",
      "フライパンを中火にし、{oil}{g:oil}gを熱して{protein}を4分焼く。",
      "しょうゆ{g:soy}gとみりん{g:mirin}gと砂糖{g:sugar}gを加えて3分絡める。",
      "ごはん{g:rice}gにのせて出す。",
    ], [s("protein", meatP), s("rice", [["rice", 180]]), oil(), soy(10), mirin(10), sugar(6)]),
    dish("fish-shio", "{protein}の塩焼き", "和", "主菜", "焼", [
      "{protein}の水気をふく。",
      "フライパンを中火にし、{oil}{g:oil}gを熱して{protein}を7分焼く。",
      "塩{g:salt}gとこしょう{g:pepper}gをふり、2分焼いて中まで火を通す。",
      "器に盛る。",
    ], [s("protein", fishP), oil(6), salt(1), pepper()]),
    dish("fish-miso", "{protein}の味噌煮", "和", "主菜", "煮", [
      "{protein}を食べやすく切る。",
      "鍋に水を200mlと顆粒だし{g:dashi}gと料理酒{g:sake}gを入れて煮立たせる。",
      "{protein}を入れて8分煮る。",
      "味噌{g:miso}gと砂糖{g:sugar}gとしょうゆ{g:soy}gを加えて5分煮て味を含ませる。",
    ], [
      s("protein", [["saba", 110], ["salmon", 120], ["buri", 90], ["hokke", 120]]),
      dashi(8), sake(), miso(14), sugar(6), soy(6),
    ]),
    dish("buri-daikon", "{protein}と大根の煮物", "和", "主菜", "煮", [
      "{protein}と大根を食べやすく切る。",
      "鍋に水を300mlと顆粒だし{g:dashi}gを入れて煮立たせる。",
      "大根を入れて10分煮る。",
      "{protein}としょうゆ{g:soy}gとみりん{g:mirin}gと砂糖{g:sugar}gを加えて8分煮る。",
    ], [
      s("protein", [["buri", 90], ["saba", 100], ["salmon", 110]]),
      s("veg", [["daikon", 140]]),
      dashi(8), soy(10), mirin(10), sugar(6),
    ]),
    dish("chanchan", "鮭と{veg}のちゃんちゃん焼き", "和", "主菜", "焼", [
      "鮭と{veg}を食べやすく切る。",
      "フライパンに{veg}と鮭を重ね、味噌{g:miso}gと砂糖{g:sugar}gとしょうゆ{g:soy}gを溶いたたれをのせる。",
      "ふたをして中火で8分焼く。",
      "たれを回しかけて2分絡め、器に盛る。",
    ], [
      s("protein", [["salmon", 130]]),
      s("veg", [["cabbage", 90], ["hakusai", 100], ["negi", 50]]),
      miso(12), sugar(6), soy(6),
    ]),
    dish("mapo", "麻婆豆腐", "中", "主菜", "煮", [
      "{protein}と木綿豆腐とねぎを切る。",
      "フライパンを中火にし、{oil}{g:oil}gで{protein}を3分炒め、豆板醤{g:douban}gを加える。",
      "水を80mlと木綿豆腐とねぎを入れて6分煮る。",
      "しょうゆ{g:soy}gと味噌{g:miso}gと砂糖{g:sugar}gを加え、片栗粉{g:starch}gを水で溶いて2分とろみをつける。",
    ], [
      s("protein", groundP),
      s("tofu", [["tofu", 180]]),
      s("negi", [["negi", 40]]),
      oil(8),
      s("douban", [["douban", 8]]),
      s("starch", [["starch", 8]]),
      soy(8), miso(10), sugar(4),
    ]),
    dish("mapo-nasu", "{protein}となすの麻婆", "中", "主菜", "煮", [
      "{protein}となすを食べやすく切る。",
      "フライパンを中火にし、{oil}{g:oil}gでなすと{protein}を4分炒める。",
      "水を60mlと豆板醤{g:douban}gとしょうゆ{g:soy}gと味噌{g:miso}gを入れて5分煮る。",
      "片栗粉{g:starch}gを水で溶いて2分とろみをつける。",
    ], [
      s("protein", groundP),
      s("veg", [["eggplant", 120]]),
      oil(10),
      s("douban", [["douban", 8]]),
      s("starch", [["starch", 8]]),
      soy(8), miso(8),
    ]),
    dish("subuta", "{protein}の酢豚", "中", "主菜", "炒", [
      "{protein}と玉ねぎとピーマンとにんじんを一口大に切る。",
      "フライパンを中火にし、{oil}{g:oil}gを熱して{protein}を4分焼く。",
      "野菜を加えて3分炒め、酢{g:vinegar}gとしょうゆ{g:soy}gと砂糖{g:sugar}gを加える。",
      "片栗粉{g:starch}gを水で溶いて2分とろみをつけ、器に盛る。",
    ], [
      s("protein", [["pork", 130], ["loin", 110]]),
      s("onion", [["onion", 60]]),
      s("piman", [["piman", 50]]),
      s("carrot", [["carrot", 40]]),
      oil(8), vinegar(12), soy(8), sugar(10),
      s("starch", [["starch", 8]]),
    ]),
    dish("ebi-chili", "えびちり", "中", "主菜", "炒", [
      "えびの背わたを取る。",
      "フライパンを中火にし、{oil}{g:oil}gと豆板醤{g:douban}gを熱してえびを3分炒める。",
      "ケチャップ{g:ketchup}gとしょうゆ{g:soy}gと砂糖{g:sugar}gと水を40ml加えて3分煮る。",
      "片栗粉{g:starch}gを水で溶いて2分とろみをつけ、器に盛る。",
    ], [
      s("protein", [["shrimp", 140]]),
      oil(8),
      s("douban", [["douban", 6]]),
      s("ketchup", [["ketchup", 12]]),
      soy(6), sugar(6),
      s("starch", [["starch", 8]]),
    ]),
    dish("curry", "{protein}カレー", "洋", "主菜", "煮", [
      "{protein}と玉ねぎとにんじんを食べやすく切る。",
      "鍋に水を350mlを入れて中火にし、{protein}と野菜を10分煮る。",
      "カレールウ{g:roux}gとしょうゆ{g:soy}gと塩{g:salt}gを溶かし、8分煮てとろみをつける。",
      "火を止めて3分置き、器に盛る。",
    ], [
      s("protein", [["chicken", 110], ["thigh", 100], ["pork", 90], ["beef", 90], ["gPork", 90]]),
      s("onion", [["onion", 80]]),
      s("carrot", [["carrot", 50]]),
      s("roux", [["roux", 25]]),
      soy(6), salt(),
    ]),
    dish("curry-rice", "{protein}のカレー丼", "洋", "丼麺", "煮", [
      "{protein}と玉ねぎを切る。",
      "鍋に水を300mlを入れて{protein}と玉ねぎを8分煮る。",
      "カレールウ{g:roux}gとしょうゆ{g:soy}gと塩{g:salt}gを溶かし、6分煮てとろみをつける。",
      "ごはん{g:rice}gにかけて出す。",
    ], [
      s("protein", [["chicken", 90], ["pork", 80], ["beef", 80]]),
      s("onion", [["onion", 60]]),
      s("rice", [["rice", 180]]),
      s("roux", [["roux", 22]]),
      soy(6), salt(),
    ]),
    dish("hamburg", "{protein}のハンバーグ", "洋", "主菜", "焼", [
      "玉ねぎをみじん切りにし、フライパンで3分炒めて冷ます。",
      "{protein}と炒めた玉ねぎと塩{g:salt}gとこしょう{g:pepper}gをねる。",
      "フライパンを中火にし、{oil}{g:oil}gを熱して片面を6分焼く。",
      "裏返して6分焼き、中まで火を通す。",
      "ケチャップ{g:ketchup}gとウスターソース{g:worcester}gを加えて3分絡める。",
    ], [
      s("protein", groundP),
      s("onion", [["onion", 50]]),
      oil(6), salt(), pepper(),
      s("ketchup", [["ketchup", 12]]),
      s("worcester", [["worcester", 8]]),
    ]),
    dish("meuniere", "{protein}のムニエル", "洋", "主菜", "焼", [
      "{protein}の水気をふき、小麦粉{g:flour}gをまぶす。",
      "フライパンを中火にし、バター{g:oil}gを熱して{protein}を片面4分焼く。",
      "裏返して4分焼き、塩{g:salt}gとこしょう{g:pepper}gをふる。",
      "バターの香りが立ったら器に盛る。",
    ], [
      s("protein", [["salmon", 120], ["aji", 130], ["tara", 140], ["hokke", 120], ["shrimp", 130]]),
      s("flour", [["flour", 15]]),
      butter(10), salt(), pepper(),
    ]),
    dish("tomato-stew", "{protein}のトマト煮", "洋", "主菜", "煮", [
      "{protein}とトマトを食べやすく切る。",
      "鍋に水を150mlとコンソメ{g:consomme}gを入れて煮立たせる。",
      "{protein}を入れて6分煮る。",
      "トマトとケチャップ{g:ketchup}gと塩{g:salt}gを加えて5分煮て器に盛る。",
    ], [
      s("protein", [["chicken", 140], ["thigh", 120]]),
      s("veg", [["tomato", 100]]),
      s("consomme", [["consomme", 5]]),
      s("ketchup", [["ketchup", 10]]),
      salt(),
    ]),
    dish("napoli", "{protein}のナポリタン", "洋", "丼麺", "炒", [
      "スパゲティを袋の表示どおりゆで、{protein}と玉ねぎとピーマンを切る。",
      "フライパンを中火にし、{oil}{g:oil}gで{protein}と野菜を4分炒める。",
      "ゆでたスパゲティとケチャップ{g:ketchup}gとウスターソース{g:worcester}gを加えて3分炒め合わせる。",
      "塩{g:salt}gで味を見て器に盛る。",
    ], [
      s("protein", [["wiener", 70], ["ham", 60], ["bacon", 40]]),
      s("onion", [["onion", 50]]),
      s("piman", [["piman", 40]]),
      s("rice", [["pasta", 180]]),
      oil(6),
      s("ketchup", [["ketchup", 15]]),
      s("worcester", [["worcester", 6]]),
      salt(),
    ]),
    dish("yakisoba", "{protein}と{veg}の焼きそば", "中", "丼麺", "炒", [
      "{protein}と{veg}を食べやすく切る。",
      "フライパンを中火にし、{oil}{g:oil}gで{protein}を3分炒める。",
      "{veg}と中華麺を加えて3分炒め、しょうゆ{g:soy}gとウスターソース{g:worcester}gを絡める。",
      "全体が混ざったら器に盛る。",
    ], [
      s("protein", [["pork", 70], ["chicken", 80], ["squid", 80], ["shrimp", 80], ["loin", 60]]),
      s("veg", [["cabbage", 80], ["moyashi", 70], ["piman", 40], ["onion", 40], ["carrot", 30], ["hakusai", 80]]),
      s("rice", [["ramen", 180]]),
      oil(8), soy(8),
      s("worcester", [["worcester", 8]]),
    ]),
    dish("udon", "{protein}と{veg}の煮込みうどん", "和", "丼麺", "煮", [
      "{protein}と{veg}を切る。",
      "鍋に水を350mlと顆粒だし{g:dashi}gを入れて煮立たせる。",
      "{protein}と{veg}を入れて6分煮る。",
      "うどんと味噌{g:miso}gとしょうゆ{g:soy}gを加えて4分煮る。",
    ], [
      s("protein", noodleP),
      s("veg", [["negi", 40], ["spinach", 50], ["onion", 50], ["cabbage", 60], ["carrot", 40], ["shimeji", 50]]),
      s("rice", [["udon", 200]]),
      dashi(), miso(8), soy(6),
    ]),
    dish("soba", "{protein}と{veg}の煮込みそば", "和", "丼麺", "煮", [
      "{protein}と{veg}を切る。",
      "鍋に水を350mlと顆粒だし{g:dashi}gを入れて煮立たせる。",
      "{protein}と{veg}を入れて5分煮る。",
      "そばを入れて、しょうゆ{g:soy}gとみりん{g:mirin}gを加えて4分煮る。",
    ], [
      s("protein", [["chicken", 70], ["pork", 60], ["chikuwa", 70], ["shrimp", 70]]),
      s("veg", [["negi", 40], ["spinach", 40], ["onion", 40], ["cabbage", 50]]),
      s("rice", [["soba", 180]]),
      dashi(), soy(8), mirin(6),
    ]),
    dish("ramen", "{protein}と{veg}の中華麺", "中", "丼麺", "煮", [
      "{protein}と{veg}を切る。",
      "鍋に水を400mlと顆粒だし{g:dashi}gとしょうゆ{g:soy}gを入れて煮立たせる。",
      "{protein}を入れて5分煮る。",
      "中華麺と{veg}を入れて4分煮て器に盛る。",
    ], [
      s("protein", [["pork", 60], ["chicken", 70], ["chikuwa", 60], ["wiener", 50]]),
      s("veg", [["negi", 50], ["menma", 50], ["spinach", 50], ["moyashi", 60], ["hakusai", 70]]),
      s("rice", [["ramen", 180]]),
      dashi(8), soy(10), pepper(),
    ]),
    dish("chahan", "{protein}チャーハン", "中", "丼麺", "炒", [
      "{protein}を細かく切る。",
      "フライパンを中火にし、{oil}{g:oil}gを熱して{protein}を3分炒める。",
      "卵{g:egg}gを流し入れて火を通し、ごはん{g:rice}gを加えて3分炒める。",
      "しょうゆ{g:soy}gと塩{g:salt}gを振って器に盛る。",
    ], [
      s("protein", [["chicken", 80], ["pork", 70], ["shrimp", 80], ["squid", 80], ["ham", 50]]),
      s("egg", [["egg", 50]]),
      s("rice", [["rice", 200]]),
      oil(8), soy(8), salt(),
    ]),
    dish("omurice", "{protein}のオムライス", "洋", "丼麺", "炒", [
      "{protein}と玉ねぎをみじん切りにする。",
      "フライパンを中火にし、{oil}{g:oil}gで{protein}と玉ねぎを4分炒め、ごはん{g:rice}gとケチャップ{g:ketchup}gを混ぜる。",
      "別のフライパンで卵{g:egg}gを2分焼いて薄く広げる。",
      "ご飯を包み、ケチャップをかけて出す。",
    ], [
      s("protein", [["chicken", 70], ["pork", 60], ["gPork", 60]]),
      s("onion", [["onion", 40]]),
      s("rice", [["rice", 180]]),
      s("egg", [["egg", 50]]),
      oil(6),
      s("ketchup", [["ketchup", 15]]),
      salt(),
    ]),
    dish("zosui", "{protein}の雑炊", "和", "丼麺", "煮", [
      "{protein}を小さく切る。",
      "鍋に水を300mlと顆粒だし{g:dashi}gを入れて煮立たせる。",
      "{protein}を入れて5分煮る。",
      "ごはん{g:rice}gとしょうゆ{g:soy}gと塩{g:salt}gを加えて4分煮て、卵{g:egg}gを回し入れる。",
    ], [
      s("protein", [["chicken", 70], ["salmon", 70], ["pork", 60]]),
      s("rice", [["rice", 120]]),
      s("egg", [["egg", 50]]),
      dashi(), soy(6), salt(),
    ]),
    dish("curry-udon", "{protein}のカレーうどん", "和", "丼麺", "煮", [
      "{protein}と玉ねぎを切る。",
      "鍋に水を400mlを入れて{protein}と玉ねぎを6分煮る。",
      "カレールウ{g:roux}gを溶かし、うどんを加えて5分煮る。",
      "しょうゆ{g:soy}gと塩{g:salt}gで味を見て器に盛る。",
    ], [
      s("protein", [["chicken", 70], ["pork", 60], ["beef", 60]]),
      s("onion", [["onion", 50]]),
      s("rice", [["udon", 200]]),
      s("roux", [["roux", 20]]),
      soy(4), salt(),
    ]),
    dish("don-fry", "{protein}と{veg}の炒め丼", "和", "丼麺", "炒", [
      "{protein}と{veg}を食べやすく切る。",
      "フライパンを中火にし、{oil}{g:oil}gを熱して{protein}を3分焼く。",
      "{veg}としょうゆ{g:soy}gとみりん{g:mirin}gを加えて3分炒める。",
      "ごはん{g:rice}gにのせて出す。",
    ], [
      s("protein", [["chicken", 100], ["thigh", 90], ["pork", 90], ["beef", 80], ["shrimp", 90], ["squid", 90]]),
      s("veg", [["cabbage", 60], ["piman", 50], ["onion", 50], ["spinach", 50], ["moyashi", 60], ["carrot", 40]]),
      s("rice", [["rice", 170]]),
      oil(), soy(8), mirin(8),
    ]),
    dish("miso-soup", "{veg}の味噌汁", "和", "汁物", "煮", [
      "{veg}を食べやすく切る。",
      "鍋に水を300mlと顆粒だし{g:dashi}gを入れて4分煮立たせる。",
      "{veg}を入れて3分煮る。",
      "味噌{g:miso}gとしょうゆ{g:soy}gを溶き入れて火を止める。",
    ], [
      s("veg", [
        ["tofu", 120], ["cabbage", 50], ["negi", 40], ["daikon", 60], ["spinach", 50],
        ["onion", 50], ["hakusai", 70], ["aburaage", 40], ["shimeji", 50], ["carrot", 50],
        ["komatsuna", 50], ["potato", 50],
      ]),
      dashi(), miso(12), soy(4),
    ]),
    dish("miso-plain", "わかめとねぎの味噌汁", "和", "汁物", "煮", [
      "わかめとねぎを食べやすく切る。",
      "鍋に水を300mlと顆粒だし{g:dashi}gを入れて4分煮立たせる。",
      "わかめとねぎを入れて3分煮る。",
      "味噌{g:miso}gとしょうゆ{g:soy}gを溶き入れて火を止める。",
    ], [
      s("wakame", [["wakame", 20]]),
      s("negi", [["negi", 40]]),
      dashi(), miso(12), soy(4),
    ]),
    dish("tonjiru", "豚汁", "和", "汁物", "煮", [
      "豚こまと{veg}を食べやすく切る。",
      "鍋に水を400mlと顆粒だし{g:dashi}gを入れて煮立たせる。",
      "豚こまと{veg}を入れて8分煮る。",
      "味噌{g:miso}gとしょうゆ{g:soy}gを溶き入れて2分煮て火を止める。",
    ], [
      s("protein", [["pork", 60]]),
      s("veg", [["daikon", 80], ["carrot", 40], ["gobo", 40], ["onion", 50], ["konnyaku", 80]]),
      dashi(8), miso(14), soy(4),
    ]),
    dish("kakitama", "かきたま汁", "和", "汁物", "煮", [
      "卵を溶いておく。",
      "鍋に水を300mlと顆粒だし{g:dashi}gとしょうゆ{g:soy}gと塩{g:salt}gを入れて4分煮立たせる。",
      "溶き卵を回し入れ、2分加熱して火を止める。",
      "器に盛る。",
    ], [s("egg", [["egg", 50]]), dashi(), soy(6), salt()]),
    dish("egg-tomato-soup", "卵とトマトのスープ", "中", "汁物", "煮", [
      "トマトをざく切りにし、卵を溶く。",
      "鍋に水を300mlと顆粒だし{g:dashi}gと塩{g:salt}gを入れて煮立たせる。",
      "トマトを入れて4分煮る。",
      "溶き卵を回し入れ、こしょう{g:pepper}gをふって2分加熱する。",
    ], [
      s("egg", [["egg", 50]]),
      s("veg", [["tomato", 80]]),
      dashi(), salt(), pepper(),
    ]),
    dish("tomato-soup", "トマトと{veg}のスープ", "洋", "汁物", "煮", [
      "トマトと{veg}を切る。",
      "鍋に水を300mlとコンソメ{g:consomme}gを入れて煮立たせる。",
      "トマトと{veg}を入れて6分煮る。",
      "塩{g:salt}gとこしょう{g:pepper}gで味を見て器に盛る。",
    ], [
      s("veg", [["onion", 50], ["cabbage", 60], ["carrot", 40], ["potato", 60]]),
      s("tomato", [["tomato", 100]]),
      s("consomme", [["consomme", 5]]),
      salt(), pepper(),
    ]),
    dish("corn-soup", "コーンスープ", "洋", "汁物", "煮", [
      "鍋に牛乳{g:milk}gと水を100mlとコンソメ{g:consomme}gを入れて中火にする。",
      "とうもろこしを加えて4分煮る。",
      "塩{g:salt}gとこしょう{g:pepper}gを加えて2分煮て火を止める。",
      "器に盛る。",
    ], [
      s("veg", [["corn", 80]]),
      s("milk", [["milk", 150]]),
      s("consomme", [["consomme", 4]]),
      salt(), pepper(),
    ]),
    dish("milk-soup", "キャベツとベーコンのミルクスープ", "洋", "汁物", "煮", [
      "キャベツとベーコンを食べやすく切る。",
      "鍋に水を200mlと牛乳{g:milk}gを入れて中火にする。",
      "キャベツとベーコンとバター{g:oil}gを入れて6分煮る。",
      "塩{g:salt}gとこしょう{g:pepper}gを加えて2分煮て火を止める。",
    ], [
      s("veg", [["cabbage", 80]]),
      s("protein", [["bacon", 70]]),
      s("milk", [["milk", 150]]),
      butter(8), salt(), pepper(),
    ]),
    dish("veg-soup", "{veg}のコンソメスープ", "洋", "汁物", "煮", [
      "{veg}を食べやすく切る。",
      "鍋に水を350mlとコンソメ{g:consomme}gを入れて煮立たせる。",
      "{veg}を入れて6分煮る。",
      "塩{g:salt}gとこしょう{g:pepper}gを加えて火を止める。",
    ], [
      s("veg", [["cabbage", 70], ["onion", 50], ["carrot", 40], ["potato", 70], ["tomato", 80], ["broccoli", 60]]),
      s("consomme", [["consomme", 5]]),
      salt(), pepper(),
    ]),
    dish("hiyayakko", "冷奴", "和", "副菜", "冷", [
      "絹ごし豆腐を器に盛る。",
      "しょうが{g:ginger}gをすりおろしてのせる。",
      "しょうゆ{g:soy}gをかけて5分置き、味をなじませて出す。",
    ], [s("protein", [["kinu", 150]]), ginger(), soy(8)]),
    dish("ohitashi", "{veg}のおひたし", "和", "副菜", "煮", [
      "{veg}を食べやすく切る。",
      "鍋に湯を沸かし、{veg}を2分ゆでて水気をしぼる。",
      "顆粒だし{g:dashi}gとしょうゆ{g:soy}gとみりん{g:mirin}gを混ぜたたれをかける。",
      "3分置いて味を含ませて出す。",
    ], [s("veg", leaf), dashi(3), soy(8), mirin(6)]),
    dish("aemono", "{veg}の和え物", "和", "副菜", "和え", [
      "{veg}を食べやすく切る。",
      "鍋に湯を沸かし、{veg}を2分ゆでて水気を切る。",
      "塩{g:salt}gとしょうゆ{g:soy}gと酢{g:vinegar}gと砂糖{g:sugar}gで和える。",
      "3分置いて味をなじませる。",
    ], [
      s("veg", [["cucumber", 80], ["spinach", 70], ["cabbage", 70], ["daikon", 80], ["moyashi", 80], ["carrot", 50], ["komatsuna", 70], ["broccoli", 70]]),
      salt(), soy(6), vinegar(8), sugar(4),
    ]),
    dish("kinpira", "{veg}のきんぴら", "和", "副菜", "炒", [
      "{veg}を細切りにする。",
      "フライパンを中火にし、{oil}{g:oil}gを熱して{veg}を4分炒める。",
      "しょうゆ{g:soy}gとみりん{g:mirin}gと砂糖{g:sugar}gを加えて3分炒め、水分を飛ばす。",
      "火を止めて器に盛る。",
    ], [
      s("veg", [["gobo", 60], ["carrot", 60], ["daikon", 70], ["rakkyo", 50]]),
      oil(6), soy(8), mirin(8), sugar(4),
    ]),
    dish("potato-butter", "じゃがいものバター蒸し", "洋", "軽い品", "蒸", [
      "じゃがいもを一口大に切る。",
      "耐熱皿に入れてラップをし、電子レンジで4分加熱する。",
      "バター{g:oil}gと塩{g:salt}gとこしょう{g:pepper}gを加えて混ぜる。",
      "もう1分加熱してから出す。",
    ], [s("veg", [["potato", 160]]), butter(8), salt(), pepper()]),
    dish("potato-salad", "ポテトサラダ", "洋", "副菜", "和え", [
      "じゃがいもを一口大に切り、{veg}も小さく切る。",
      "鍋に湯を沸かし、じゃがいもを8分ゆでて火を通す。",
      "{veg}を2分ゆでて水気を切る。",
      "マヨネーズ{g:mayo}gと塩{g:salt}gとこしょう{g:pepper}gで和えて器に盛る。",
    ], [
      s("potato", [["potato", 140]]),
      s("veg", [["cucumber", 40], ["carrot", 40], ["corn", 40], ["onion", 30]]),
      s("mayo", [["mayo", 15]]),
      salt(), pepper(),
    ]),
    dish("tamagoyaki", "卵焼き", "和", "軽い品", "焼", [
      "卵を溶き、塩{g:salt}gとこしょう{g:pepper}gを混ぜる。",
      "フライパンを中火にし、{oil}{g:oil}gを熱する。",
      "卵液を流し入れて2分焼く。",
      "巻いて3分火を通し、器に盛る。",
    ], [s("egg", [["egg", 100]]), oil(4), salt(), pepper()]),
    dish("egg-cabbage", "卵と{veg}の炒め", "和", "主菜", "炒", [
      "卵を溶き、{veg}を食べやすく切る。",
      "フライパンを中火にし、{oil}{g:oil}gで{veg}を3分炒める。",
      "卵を流し入れて2分火を通す。",
      "しょうゆ{g:soy}gと塩{g:salt}gを振って器に盛る。",
    ], [
      s("egg", [["egg", 100]]),
      s("veg", [["cabbage", 80], ["tomato", 80], ["spinach", 60], ["onion", 50]]),
      oil(6), soy(6), salt(),
    ]),
    dish("egg-tomato", "トマトと卵の炒め", "中", "主菜", "炒", [
      "トマトをざく切りにし、卵を溶く。",
      "フライパンを中火にし、{oil}{g:oil}gでトマトを3分炒める。",
      "卵を流し入れて2分火を通す。",
      "塩{g:salt}gとこしょう{g:pepper}gを振って器に盛る。",
    ], [s("veg", [["tomato", 100]]), s("egg", [["egg", 100]]), oil(6), salt(), pepper()]),
    dish("tk", "卵とじ丼", "和", "丼麺", "煮", [
      "卵を溶いておく。",
      "鍋に水を200mlと顆粒だし{g:dashi}gとしょうゆ{g:soy}gとみりん{g:mirin}gを入れて4分煮立たせる。",
      "溶き卵を回し入れて2分火を通し、半熟になったら火を止める。",
      "ごはん{g:rice}gにかけて出す。",
    ], [
      s("egg", [["egg", 100]]),
      s("rice", [["rice", 180]]),
      dashi(), soy(8), mirin(8),
    ]),
    dish("natto-rice", "納豆チャーハン", "中", "丼麺", "炒", [
      "卵を溶き、納豆と混ぜておく。",
      "フライパンを中火にし、{oil}{g:oil}gを熱して卵と納豆を2分炒める。",
      "ごはん{g:rice}gとしょうゆ{g:soy}gとこしょう{g:pepper}gを加えて3分炒め合わせる。",
      "火を止めて器に盛る。",
    ], [
      s("protein", [["natto", 50]]),
      s("egg", [["egg", 50]]),
      s("rice", [["rice", 160]]),
      oil(6), soy(6), pepper(),
    ]),
    dish("ham-egg", "{protein}と卵の炒め", "洋", "主菜", "炒", [
      "{protein}を食べやすく切る。",
      "フライパンを中火にし、{oil}{g:oil}gで{protein}を3分焼く。",
      "卵{g:egg}gを流し入れて2分火を通す。",
      "塩{g:salt}gとこしょう{g:pepper}gを振って器に盛る。",
    ], [
      s("protein", [["ham", 60], ["bacon", 40], ["wiener", 70]]),
      s("egg", [["egg", 50]]),
      oil(4), salt(), pepper(),
    ]),
    dish("tuna-toast", "ツナトースト", "洋", "軽い品", "焼", [
      "ツナと塩{g:salt}gとこしょう{g:pepper}gを混ぜる。",
      "食パンにのせる。",
      "フライパンを中火にし、バター{g:oil}gを熱して片面を3分焼く。",
      "裏返して2分焼き、器に盛る。",
    ], [
      s("protein", [["tuna", 70]]),
      s("bread", [["bread", 70]]),
      butter(6), salt(), pepper(),
    ]),
    dish("cheese-toast", "チーズトースト", "洋", "軽い品", "焼", [
      "食パンにプロセスチーズをのせる。",
      "塩{g:salt}gとこしょう{g:pepper}gをふる。",
      "フライパンを中火にし、バター{g:oil}gを熱して3分焼く。",
      "チーズが溶けたら2分置いて出す。",
    ], [
      s("cheese", [["cheese", 25]]),
      s("bread", [["bread", 70]]),
      butter(5), salt(), pepper(),
    ]),
    dish("egg-toast", "目玉焼きトースト", "洋", "主食", "焼", [
      "食パンを一口大に切る。",
      "フライパンを中火にし、バター{g:oil}gを熱してパンを3分焼く。",
      "卵を流し入れて2分火を通す。",
      "塩{g:salt}gとこしょう{g:pepper}gを振って器に盛る。",
    ], [s("egg", [["egg", 50]]), s("bread", [["bread", 70]]), butter(6), salt(), pepper()]),
    dish("tuna-pasta", "ツナと{veg}のパスタ", "洋", "丼麺", "炒", [
      "スパゲティをゆで、{veg}を切る。",
      "フライパンを中火にし、{oil}{g:oil}gでツナと{veg}を3分炒める。",
      "ゆでたスパゲティとしょうゆ{g:soy}gとこしょう{g:pepper}gを加えて3分炒め合わせる。",
      "器に盛る。",
    ], [
      s("protein", [["tuna", 70]]),
      s("veg", [["cabbage", 70], ["spinach", 50], ["tomato", 80], ["onion", 50]]),
      s("rice", [["pasta", 180]]),
      oil(6), soy(6), pepper(),
    ]),
    dish("salmon-pasta", "鮭と{veg}のパスタ", "洋", "丼麺", "炒", [
      "スパゲティをゆで、鮭と{veg}を切る。",
      "フライパンを中火にし、{oil}{g:oil}gで鮭を4分焼く。",
      "{veg}とゆでたスパゲティとしょうゆ{g:soy}gとこしょう{g:pepper}gを加えて3分炒める。",
      "器に盛る。",
    ], [
      s("protein", [["salmon", 100]]),
      s("veg", [["spinach", 50], ["tomato", 70], ["broccoli", 60]]),
      s("rice", [["pasta", 170]]),
      oil(6), soy(6), pepper(),
    ]),
    dish("yurinchi", "油淋鶏", "中", "主菜", "焼", [
      "{protein}とねぎを食べやすく切る。",
      "フライパンを中火にし、{oil}{g:oil}gを熱して{protein}を6分焼く。",
      "酢{g:vinegar}gとしょうゆ{g:soy}gと砂糖{g:sugar}gと水を30mlとねぎを煮立たせてたれにする。",
      "焼いた{protein}にたれをかけて器に盛る。",
    ], [
      s("protein", [["chicken", 150], ["thigh", 140]]),
      s("negi", [["negi", 40]]),
      oil(10), vinegar(14), soy(8), sugar(8),
    ]),
    dish("nanban", "{protein}の南蛮漬け", "和", "主菜", "煮", [
      "{protein}と玉ねぎを切る。",
      "フライパンを中火にし、{oil}{g:oil}gで{protein}を5分焼く。",
      "酢{g:vinegar}gとしょうゆ{g:soy}gと砂糖{g:sugar}gと水を40mlを煮立たせる。",
      "焼いた{protein}と玉ねぎを入れて4分煮て味を含ませる。",
    ], [
      s("protein", [["chicken", 130], ["thigh", 120], ["aji", 120], ["tara", 130]]),
      s("onion", [["onion", 60]]),
      oil(6), vinegar(16), soy(8), sugar(8),
    ]),
    dish("ethnic", "{protein}と{veg}のエスニック炒め", "エスニック", "主菜", "炒", [
      "{protein}と{veg}を食べやすく切る。",
      "フライパンを中火にし、{oil}{g:oil}gを熱して{protein}を4分炒める。",
      "{veg}とナンプラー{g:nampla}gと砂糖{g:sugar}gを加えて3分炒め合わせる。",
      "火を止めて器に盛る。",
    ], [
      s("protein", [["chicken", 120], ["thigh", 110], ["pork", 100], ["shrimp", 110], ["squid", 110], ["gPork", 90]]),
      s("veg", [["cabbage", 80], ["piman", 60], ["eggplant", 80], ["onion", 50], ["moyashi", 70], ["tomato", 70]]),
      oil(8),
      s("nampla", [["nampla", 10]]),
      sugar(4), pepper(),
    ]),
    dish("lemon-chicken", "{protein}のレモン焼き", "エスニック", "主菜", "焼", [
      "{protein}を一口大に切る。",
      "フライパンを中火にし、{oil}{g:oil}gを熱して{protein}を6分焼く。",
      "レモン{g:lemon}gの汁とナンプラー{g:nampla}gと砂糖{g:sugar}gを加えて2分絡める。",
      "器に盛る。",
    ], [
      s("protein", [["chicken", 150], ["thigh", 140]]),
      s("lemon", [["lemon", 25]]),
      oil(8),
      s("nampla", [["nampla", 8]]),
      sugar(4),
    ]),
    dish("avocado", "アボカドと{veg}の和え", "洋", "副菜", "和え", [
      "アボカドと{veg}を食べやすく切る。",
      "ボウルで塩{g:salt}gとこしょう{g:pepper}gとしょうゆ{g:soy}gを混ぜる。",
      "アボカドと{veg}を和える。",
      "5分置いて味をなじませて出す。",
    ], [
      s("avocado", [["avocado", 70]]),
      s("veg", [["lettuce", 40], ["cucumber", 50], ["tomato", 60], ["onion", 30]]),
      salt(), pepper(), soy(6),
    ]),
    dish("konnyaku", "こんにゃくと{veg}の煮物", "和", "副菜", "煮", [
      "こんにゃくを下ゆでし、{veg}を切る。",
      "鍋に水を250mlと顆粒だし{g:dashi}gを入れて煮立たせる。",
      "こんにゃくと{veg}を入れて8分煮る。",
      "しょうゆ{g:soy}gとみりん{g:mirin}gと砂糖{g:sugar}gを加えて5分煮て器に盛る。",
    ], [
      s("protein", [["konnyaku", 120]]),
      s("veg", [["daikon", 60], ["carrot", 40], ["gobo", 40], ["onion", 40]]),
      dashi(), soy(8), mirin(8), sugar(4),
    ]),
    dish("pumpkin", "かぼちゃの煮物", "和", "副菜", "煮", [
      "かぼちゃを一口大に切る。",
      "鍋に水を200mlと顆粒だし{g:dashi}gを入れて煮立たせる。",
      "かぼちゃを入れて8分煮る。",
      "しょうゆ{g:soy}gとみりん{g:mirin}gと砂糖{g:sugar}gを加えて4分煮て器に盛る。",
    ], [s("veg", [["pumpkin", 140]]), dashi(), soy(8), mirin(8), sugar(6)]),
    dish("menma", "めんまの炒め", "中", "副菜", "炒", [
      "めんまとねぎを食べやすく切る。",
      "フライパンを中火にし、{oil}{g:oil}gを熱してめんまを2分炒める。",
      "しょうゆ{g:soy}gとみりん{g:mirin}gを加えて3分絡める。",
      "火を止めて器に盛る。",
    ], [s("veg", [["menma", 60]]), s("negi", [["negi", 50]]), oil(4), soy(6), mirin(6)]),
    dish("nasu-nibitashi", "なすの煮びたし", "和", "副菜", "煮", [
      "なすを食べやすく切る。",
      "鍋に水を250mlと顆粒だし{g:dashi}gを入れて煮立たせる。",
      "なすを入れて6分煮る。",
      "しょうゆ{g:soy}gとみりん{g:mirin}gを加えて2分煮て火を止める。",
    ], [
      s("veg", [["eggplant", 120]]),
      dashi(), soy(8), mirin(8),
    ]),
    dish("gobo-simmer", "ごぼうの煮物", "和", "副菜", "煮", [
      "ごぼうをささがきにして水にさらす。",
      "鍋に水を200mlと顆粒だし{g:dashi}gを入れて煮立たせる。",
      "ごぼうを入れて8分煮る。",
      "しょうゆ{g:soy}gとみりん{g:mirin}gと砂糖{g:sugar}gを加えて4分煮て器に盛る。",
    ], [s("veg", [["gobo", 80]]), dashi(), soy(8), mirin(8), sugar(4)]),
    dish("cucumber-sunomono", "きゅうりの酢の物", "和", "副菜", "和え", [
      "きゅうりを薄切りにして塩{g:salt}gでもむ。",
      "水気をしぼる。",
      "酢{g:vinegar}gとしょうゆ{g:soy}gと砂糖{g:sugar}gで和える。",
      "5分置いて味をなじませて出す。",
    ], [s("veg", [["cucumber", 80]]), salt(), vinegar(10), soy(4), sugar(4)]),
    dish("avocado-tofu", "アボカドと豆腐の和え", "洋", "副菜", "和え", [
      "アボカドと木綿豆腐を食べやすく切る。",
      "しょうゆ{g:soy}gと塩{g:salt}gを混ぜる。",
      "アボカドと豆腐を和える。",
      "5分置いてから出す。",
    ], [s("avocado", [["avocado", 60]]), s("tofu", [["tofu", 120]]), soy(6), salt()]),
    dish("chikuwa-ae", "ちくわと{veg}の和え", "和", "副菜", "和え", [
      "ちくわと{veg}を食べやすく切る。",
      "{veg}を2分ゆでて水気を切る。",
      "ちくわとしょうゆ{g:soy}gと酢{g:vinegar}gと砂糖{g:sugar}gで和える。",
      "3分置いて器に盛る。",
    ], [
      s("protein", [["chikuwa", 60]]),
      s("veg", [["cucumber", 50], ["cabbage", 50]]),
      soy(6), vinegar(6), sugar(3),
    ]),
    dish("tuna-ae", "ツナとキャベツの和え", "和", "副菜", "和え", [
      "キャベツを食べやすく切って2分ゆでる。",
      "水気をしぼり、ツナと合わせる。",
      "しょうゆ{g:soy}gと酢{g:vinegar}gと砂糖{g:sugar}gで和える。",
      "3分置いて器に盛る。",
    ], [s("protein", [["tuna", 60]]), s("veg", [["cabbage", 80]]), soy(6), vinegar(6), sugar(3)]),
    dish("veg-salt", "{veg}の塩炒め", "和", "副菜", "炒", [
      "{veg}を食べやすく切る。",
      "フライパンを中火にし、{oil}{g:oil}gを熱して{veg}を4分炒める。",
      "塩{g:salt}gとしょうゆ{g:soy}gを振って2分炒め合わせる。",
      "火を止めて器に盛る。",
    ], [s("veg", veg10), oil(6), salt(), soy(4)]),
    dish("lettuce-fry", "{veg}のにんにく炒め", "中", "副菜", "炒", [
      "{veg}と{garlic}を食べる大きさに切る。",
      "フライパンを中火にし、{oil}{g:oil}gと{garlic}{g:garlic}gを3分熱する。",
      "{veg}を加えて2分炒め、しょうゆ{g:soy}gと塩{g:salt}gを絡める。",
      "すぐに火を止めて器に盛る。",
    ], [
      s("veg", [["lettuce", 70], ["cabbage", 70], ["hakusai", 80], ["spinach", 60]]),
      garlic(), oil(6), soy(4), salt(),
    ]),
    dish("broccoli-grill", "{protein}とブロッコリーのソテー", "洋", "主菜", "焼", [
      "{protein}とブロッコリーを食べやすく切る。",
      "フライパンを中火にし、{oil}{g:oil}gを熱して{protein}を5分焼く。",
      "ブロッコリーを加えて3分炒め、塩{g:salt}gとこしょう{g:pepper}gとしょうゆ{g:soy}gをふる。",
      "器に盛る。",
    ], [
      s("protein", [["chicken", 140], ["thigh", 120], ["pork", 100], ["salmon", 110], ["loin", 90]]),
      s("veg", [["broccoli", 80]]),
      oil(8), salt(), pepper(), soy(4),
    ]),
    dish("hoikoro", "{protein}と{veg}の回鍋肉", "中", "主菜", "炒", [
      "{protein}と{veg}を食べやすく切る。",
      "フライパンを中火にし、{oil}{g:oil}gで{protein}を4分炒める。",
      "{veg}と豆板醤{g:douban}gと味噌{g:miso}gとしょうゆ{g:soy}gを加えて3分炒め合わせる。",
      "火を止めて器に盛る。",
    ], [
      s("protein", [["pork", 110], ["loin", 90]]),
      s("veg", [["cabbage", 90], ["hakusai", 100], ["piman", 50]]),
      oil(8),
      s("douban", [["douban", 6]]),
      miso(8), soy(6),
    ]),
    dish("chinjao", "{protein}とピーマンの細切り炒め", "中", "主菜", "炒", [
      "{protein}とピーマンを細切りにする。",
      "フライパンを中火にし、{oil}{g:oil}gを熱して{protein}を3分炒める。",
      "ピーマンとしょうゆ{g:soy}gと料理酒{g:sake}gと砂糖{g:sugar}gを加えて3分炒める。",
      "火を止めて器に盛る。",
    ], [
      s("protein", [["pork", 110], ["chicken", 120], ["beef", 90], ["loin", 90]]),
      s("veg", [["piman", 80]]),
      oil(8), soy(8), sake(6), sugar(4),
    ]),
    dish("yudofu", "煮込み湯豆腐", "和", "主菜", "煮", [
      "木綿豆腐を食べやすく切る。",
      "鍋に水を300mlと顆粒だし{g:dashi}gを入れて煮立たせる。",
      "豆腐を入れて6分煮る。",
      "しょうゆ{g:soy}gと塩{g:salt}gを添え、器に盛る。",
    ], [s("protein", [["tofu", 200]]), dashi(), soy(8), salt()]),
    dish("negima", "{protein}とねぎの炒め", "和", "主菜", "炒", [
      "{protein}とねぎを食べやすく切る。",
      "フライパンを中火にし、{oil}{g:oil}gを熱して{protein}を4分焼く。",
      "ねぎとしょうゆ{g:soy}gとみりん{g:mirin}gを加えて3分炒め合わせる。",
      "火を止めて器に盛る。",
    ], [
      s("protein", [["chicken", 130], ["thigh", 120], ["pork", 110], ["beef", 100]]),
      s("veg", [["negi", 50]]),
      oil(8), soy(8), mirin(8),
    ]),
    dish("saba-miso-don", "さばの味噌煮丼", "和", "丼麺", "煮", [
      "さばを食べやすく切る。",
      "鍋に水を200mlと顆粒だし{g:dashi}gを入れて煮立たせる。",
      "さばを入れて6分煮る。",
      "味噌{g:miso}gと砂糖{g:sugar}gとしょうゆ{g:soy}gを加えて4分煮て、ごはん{g:rice}gにのせる。",
    ], [
      s("protein", [["saba", 100]]),
      s("rice", [["rice", 170]]),
      dashi(), miso(12), sugar(4), soy(6),
    ]),
    dish("shake-don", "鮭の焼き丼", "和", "丼麺", "焼", [
      "鮭を一口大に切る。",
      "フライパンを中火にし、{oil}{g:oil}gを熱して鮭を5分焼く。",
      "しょうゆ{g:soy}gとみりん{g:mirin}gと砂糖{g:sugar}gを加えて2分絡める。",
      "ごはん{g:rice}gにのせて出す。",
    ], [
      s("protein", [["salmon", 120]]),
      s("rice", [["rice", 170]]),
      oil(6), soy(8), mirin(8), sugar(4),
    ]),
    dish("garlic-don", "{protein}のガーリック丼", "洋", "丼麺", "焼", [
      "{protein}と{garlic}を食べる大きさに切る。",
      "フライパンを中火にし、{oil}{g:oil}gを熱して{protein}と{garlic}{g:garlic}gを4分炒める。",
      "しょうゆ{g:soy}gとみりん{g:mirin}gを加えて2分絡める。",
      "ごはん{g:rice}gにのせて出す。",
    ], [
      s("protein", [["chicken", 110], ["pork", 100], ["thigh", 100], ["beef", 90], ["shrimp", 100]]),
      s("rice", [["rice", 170]]),
      garlic(20), oil(8), soy(8), mirin(6),
    ]),
    dish("omelette", "オムレツ", "洋", "主菜", "焼", [
      "卵を溶き、塩{g:salt}gとこしょう{g:pepper}gを混ぜる。",
      "フライパンを中火にし、バター{g:oil}gを熱する。",
      "卵液を流し入れて2分焼く。",
      "半分に折って3分火を通し、器に盛る。",
    ], [s("egg", [["egg", 100]]), butter(8), salt(), pepper()]),
    dish("spinach-goma", "ほうれん草のごま和え", "和", "副菜", "和え", [
      "ほうれん草を2分ゆでて水気をしぼる。",
      "しょうゆ{g:soy}gと砂糖{g:sugar}gとすりごま{g:goma}gとごま油{g:oil}gで和える。",
      "3分置いて味をなじませる。",
      "器に盛る。",
    ], [
      s("veg", [["spinach", 80]]),
      soy(6), sugar(3),
      s("goma", [["surigoma", 8]]),
      s("oil", [["sesame", 4]]),
    ]),
    dish("corn-butter", "とうもろこしのバター炒め", "洋", "副菜", "炒", [
      "とうもろこしを食べやすく切る。",
      "フライパンを中火にし、バター{g:oil}gを熱してとうもろこしを4分炒める。",
      "塩{g:salt}gとこしょう{g:pepper}gをふる。",
      "もう1分炒めて器に盛る。",
    ], [s("veg", [["corn", 100]]), butter(8), salt(), pepper()]),
    dish("ika-fry", "いかと{veg}の炒め", "和", "主菜", "炒", [
      "いかと{veg}を食べやすく切る。",
      "フライパンを中火にし、{oil}{g:oil}gを熱していかを3分炒める。",
      "{veg}としょうゆ{g:soy}gとみりん{g:mirin}gを加えて3分炒め合わせる。",
      "火を止めて器に盛る。",
    ], [
      s("protein", [["squid", 130]]),
      s("veg", [["cabbage", 70], ["piman", 50], ["onion", 50], ["moyashi", 70]]),
      oil(8), soy(8), mirin(6),
    ]),
    dish("shrimp-fry", "えびと{veg}の炒め", "中", "主菜", "炒", [
      "えびと{veg}を食べる大きさにする。",
      "フライパンを中火にし、{oil}{g:oil}gを熱してえびを3分炒める。",
      "{veg}としょうゆ{g:soy}gと料理酒{g:sake}gを加えて3分炒め合わせる。",
      "火を止めて器に盛る。",
    ], [
      s("protein", [["shrimp", 130]]),
      s("veg", [["broccoli", 70], ["piman", 50], ["onion", 40], ["cabbage", 60]]),
      oil(8), soy(8), sake(6),
    ]),
    dish("medamayaki", "目玉焼き", "洋", "主菜", "焼", [
      "卵を割りほぐさず、塩とこしょうを用意する。",
      "フライパンを中火にし、{oil}{g:oil}gを熱して卵を2分焼く。",
      "塩{g:salt}gとこしょう{g:pepper}gをふる。",
      "3分置いて黄身まで火を通して器に盛る。",
    ], [s("egg", [["egg", 100]]), oil(1), salt(), pepper()]),
    dish("tofu-steak", "豆腐ステーキ", "和", "主菜", "焼", [
      "木綿豆腐の水気を切り、厚く切る。",
      "フライパンを中火にし、{oil}{g:oil}gを熱して豆腐を片面4分焼く。",
      "裏返して4分焼き、しょうゆ{g:soy}gとみりん{g:mirin}gを絡める。",
      "ねぎ{g:negi}gをのせて器に盛る。",
    ], [
      s("protein", [["tofu", 180]]),
      s("negi", [["negi", 30]]),
      oil(6), soy(8), mirin(6),
    ]),
    dish("garlic-pasta", "{protein}のにんにくパスタ", "洋", "丼麺", "炒", [
      "スパゲティをゆで、{garlic}を薄切りにする。",
      "フライパンを中火にし、{oil}{g:oil}gで{garlic}{g:garlic}gと{protein}を4分炒める。",
      "ゆでたスパゲティとしょうゆ{g:soy}gと塩{g:salt}gを加えて3分炒め合わせる。",
      "器に盛る。",
    ], [
      s("protein", [["bacon", 40], ["shrimp", 80], ["squid", 80], ["chicken", 70]]),
      s("garlic", [["garlic", 15]]),
      s("rice", [["pasta", 180]]),
      oil(8), soy(6), salt(),
    ]),
    dish("onion-soup", "炒め玉ねぎのスープ", "洋", "汁物", "煮", [
      "玉ねぎを薄切りにする。",
      "鍋に水を350mlとコンソメ{g:consomme}gを入れて煮立たせる。",
      "玉ねぎを入れて8分煮る。",
      "塩{g:salt}gとこしょう{g:pepper}gを加えて火を止める。",
    ], [
      s("veg", [["onion", 80]]),
      s("consomme", [["consomme", 5]]),
      salt(), pepper(),
    ]),
    dish("egg-miso", "卵の味噌汁", "和", "汁物", "煮", [
      "卵を溶いておく。",
      "鍋に水を300mlと顆粒だし{g:dashi}gを入れて4分煮立たせる。",
      "味噌{g:miso}gとしょうゆ{g:soy}gを溶き入れる。",
      "溶き卵を回し入れて2分加熱し、火を止める。",
    ], [s("egg", [["egg", 50]]), dashi(), miso(12), soy(4)]),
    dish("coleslaw", "{veg}のコールスロー和え", "洋", "副菜", "和え", [
      "{veg}を細切りにする。",
      "塩{g:salt}gをふって水気をしぼる。",
      "マヨネーズ{g:mayo}gとこしょう{g:pepper}gで和える。",
      "5分置いて味をなじませて出す。",
    ], [
      s("veg", [["cabbage", 70], ["lettuce", 60], ["carrot", 40]]),
      s("mayo", [["mayo", 12]]),
      salt(), pepper(),
    ]),
    dish("milk-okayu", "牛乳がゆ", "和", "主食", "煮", [
      "ごはんを鍋に入れる。",
      "牛乳{g:milk}gと水を100mlを加えて中火にする。",
      "8分煮てごはんをやわらかくする。",
      "塩{g:salt}gと砂糖{g:sugar}gを加えて2分煮て火を止める。",
    ], [
      s("rice", [["rice", 60]]),
      s("milk", [["milk", 100]]),
      salt(), sugar(3),
    ]),
  ];
  return recipes;
}

export const cookRecipes = buildCookRecipes();
