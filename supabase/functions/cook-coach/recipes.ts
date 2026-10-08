// 家庭料理100品。各スロットの候補は、その調理で成立するものだけ。
// 料理名の {スロット} は入れ替え後の食品名になる。
// アプリには埋め込まない。追加は seed を足して migration を出し、DBへ入れる。

import { totalCookingMinutes } from "./plan.ts";
import { optionFromFood, slot, type CookOption, type CookRecipe, type CookSlot } from "./select.ts";

type Genre = "和" | "洋" | "中" | "エスニック";
type Category = "主菜" | "副菜" | "主食" | "汁物" | "丼麺" | "軽い品";
type Kind =
  | "fry"
  | "miso"
  | "simmer"
  | "don"
  | "oyako"
  | "steam"
  | "soup"
  | "egg"
  | "cold"
  | "ohitashi"
  | "ae"
  | "pasta"
  | "microwave"
  | "nanban"
  | "chanchan"
  | "mapo"
  | "nikujaga"
  | "chahan"
  | "toast"
  | "tk"
  | "natto";

function o(pairs: Array<[string, number]>): CookOption[] {
  return pairs.map(([id, grams]) => optionFromFood(id, grams));
}

function s(key: string, pairs: Array<[string, number]>): CookSlot {
  const options = o(pairs);
  return slot(key, options[0].role, options);
}

const meats = (c: number, t: number, p: number, b: number, a: number) =>
  s("protein", [["chicken", c], ["thigh", t], ["pork", p], ["beef", b], ["atsuage", a]]);
const meatsNoSoy = (c: number, t: number, p: number, b: number) =>
  s("protein", [["chicken", c], ["thigh", t], ["pork", p], ["beef", b]]);
const chickenPair = (c: number, t: number) => s("protein", [["chicken", c], ["thigh", t]]);
const veg4 = (c: number, h: number, p: number, m: number) =>
  s("veg", [["cabbage", c], ["hakusai", h], ["piman", p], ["moyashi", m]]);
const leaf3 = (c: number, h: number, sPinach: number) =>
  s("veg", [["cabbage", c], ["hakusai", h], ["spinach", sPinach]]);

function seasoningTail(steps: string[], keys: Set<string>): string[] {
  const text = steps.join("\n");
  const missing: string[] = [];
  const table: Array<[string, string, string]> = [
    ["soy", "しょうゆ", "しょうゆ{g:soy}g"],
    ["mirin", "みりん", "みりん{g:mirin}g"],
    ["sugar", "砂糖", "砂糖{g:sugar}g"],
    ["miso", "味噌", "味噌{g:miso}g"],
    ["salt", "塩", "塩{g:salt}g"],
    ["pepper", "こしょう", "こしょう{g:pepper}g"],
    ["vinegar", "酢", "酢{g:vinegar}g"],
    ["dashi", "顆粒だし", "顆粒だし{g:dashi}g"],
    ["sake", "料理酒", "料理酒{g:sake}g"],
  ];
  for (const [key, word, phrase] of table) {
    if (keys.has(key) && !text.includes(word)) {
      missing.push(phrase);
    }
  }
  if (missing.length === 0) {
    return steps;
  }
  return [...steps, `${missing.join("と")}を加えて味をととのえる。`];
}

function stepsFor(kind: Kind, keys: Set<string>): string[] {
  const rice = keys.has("rice") ? "{rice}{g:rice}gを器に盛り、具をのせる。" : "火を止めて器に盛る。";
  if (kind === "tk") {
    return [
      "{rice}{g:rice}gを器に盛る。",
      "卵{g:egg}gを落とし、しょうゆ{g:soy}gをかける。",
      "電子レンジで2分加熱する。",
      "3分置いて火が通ったら出す。",
    ];
  }
  if (kind === "natto") {
    return [
      "{rice}{g:rice}gに{protein}{g:protein}gをのせる。",
      keys.has("egg")
        ? "卵{g:egg}gを落とし、しょうゆ{g:soy}gをかける。"
        : "しょうゆ{g:soy}gをかけて混ぜる。",
      "電子レンジで2分加熱する。",
      "3分置いてから出す。",
    ];
  }
  if (kind === "fry") {
    const lines = [
      keys.has("veg")
        ? "{protein}と{veg}を食べやすく切る。"
        : "{protein}を一口大に切る。",
      "フライパンを中火にし、{oil}{g:oil}gを熱して{protein}を3分焼く。",
    ];
    if (keys.has("veg")) {
      lines.push("{veg}を加えて2分炒め、しょうゆ{g:soy}gとみりん{g:mirin}gを絡める。");
    } else if (keys.has("onion")) {
      lines.push("{onion}を加えて2分炒め、しょうゆ{g:soy}gとみりん{g:mirin}gを絡める。");
    } else {
      lines.push("しょうゆ{g:soy}gとみりん{g:mirin}gを加えて2分絡め、中まで火を通す。");
    }
    if (keys.has("ginger")) {
      lines[0] = `${lines[0].replace(/。$/, "")}。{ginger}{g:ginger}gを添える。`;
    }
    if (keys.has("onion") && !lines[2].includes("{onion}")) {
      lines[2] = `{onion}を加えて${lines[2]}`;
    }
    if (keys.has("egg")) {
      lines.splice(3, 0, "卵{g:egg}gを流し入れて火を通す。");
    }
    lines.push(rice);
    return lines;
  }
  if (kind === "miso") {
    return [
      "{protein}と{veg}を食べやすく切る。",
      "フライパンを中火にし、{oil}{g:oil}gを熱して{protein}を3分炒める。",
      "{veg}と味噌{g:miso}gと砂糖{g:sugar}gと料理酒{g:sake}gを加えて2分炒め合わせる。",
      rice,
    ];
  }
  if (kind === "simmer") {
    const head = keys.has("veg") ? "{protein}と{veg}を食べやすく切る。" : "{protein}を食べやすく切る。";
    return [
      head,
      "鍋に水を200mlと顆粒だし{g:dashi}gを入れて中火で煮立たせる。",
      "{protein}を入れて6分煮て、しょうゆ{g:soy}gとみりん{g:mirin}gと砂糖{g:sugar}gを加える。",
      "弱火で4分煮て、具に味を含ませる。",
      ...(keys.has("rice") ? ["{rice}{g:rice}gにのせる。"] : []),
    ];
  }
  if (kind === "don") {
    return [
      keys.has("veg") ? "{protein}と{veg}を一口大に切る。" : "{protein}を一口大に切る。",
      "フライパンを中火にし、{oil}{g:oil}gを熱して{protein}を3分焼く。",
      "しょうゆ{g:soy}gとみりん{g:mirin}gと砂糖{g:sugar}gを加えて2分絡める。",
      "ごはん{g:rice}gにのせてすぐに出す。",
    ];
  }
  if (kind === "oyako") {
    return [
      "{protein}と玉ねぎ{g:onion}gを切る。",
      "鍋に水を150mlと顆粒だし{g:dashi}g、しょうゆ{g:soy}g、みりん{g:mirin}gを入れて煮立たせる。",
      "{protein}と玉ねぎを5分煮る。",
      "卵{g:egg}gを回し入れ、ふたをして2分加熱してごはん{g:rice}gにのせる。",
    ];
  }
  if (kind === "steam") {
    return [
      "{protein}を食べやすく切り、耐熱皿に並べる。",
      "しょうゆ{g:soy}gとみりん{g:mirin}gと塩{g:salt}gをふる。",
      "電子レンジで4分加熱し、取り出して2分蒸らす。",
      keys.has("veg") ? "{veg}を添える。" : "中まで火が通ったことを確かめる。",
      keys.has("rice") ? "{rice}{g:rice}gと一緒に器へ盛る。" : "器に盛ってすぐに出す。",
    ];
  }
  if (kind === "soup") {
    const body = keys.has("veg") ? "{protein}と{veg}を鍋に入れる。" : "{protein}を鍋に入れる。";
    return [
      "鍋に水を300mlと顆粒だし{g:dashi}gを入れて中火にする。",
      `${body}5分煮る。`,
      "味噌{g:miso}gを溶き入れ、しょうゆ{g:soy}gを足して2分煮て火を止める。",
      keys.has("rice") ? "{rice}{g:rice}gを入れて器に注ぐ。" : "器に注いですぐに出す。",
    ];
  }
  if (kind === "egg") {
    const extra = keys.has("veg") ? "{veg}を先に1分炒めてから、" : "";
    return [
      keys.has("pepper")
        ? "卵{g:egg}gを溶き、塩{g:salt}gとこしょう{g:pepper}gを加える。"
        : "卵{g:egg}gを溶き、塩{g:salt}gを加える。",
      "フライパンを中火にし、{oil}{g:oil}gを熱する。",
      `${extra}溶き卵を流して3分焼く。`,
      "2分待って形が固まったら器に盛る。",
    ];
  }
  if (kind === "cold") {
    return [
      "絹ごし豆腐{g:tofu}gを器に出す。",
      "しょうゆ{g:soy}gをかけ、しょうが{g:ginger}gをのせる。",
      "冷蔵庫で5分冷やし、味を見て出す。",
    ];
  }
  if (kind === "ohitashi") {
    return [
      "{veg}を鍋で3分ゆでて、水気をよく切る。",
      "しょうゆ{g:soy}gと顆粒だし{g:dashi}gを和える。",
      "2分置いて味を含ませてから器に盛る。",
    ];
  }
  if (kind === "ae") {
    return [
      "{veg}を食べやすく切り、塩{g:salt}gをふる。",
      "しょうゆ{g:soy}gと酢{g:vinegar}gと砂糖{g:sugar}gを和える。",
      "5分置いて味がなじんだら器に盛る。",
    ];
  }
  if (kind === "pasta") {
    return [
      "スパゲティ{g:pasta}gを湯で6分ゆでる。",
      "フライパンで{oil}{g:oil}gを熱し、{protein}と{veg}を2分炒める。",
      "しょうゆ{g:soy}gとこしょう{g:pepper}gを加えて1分絡める。",
      "ゆでたスパゲティを戻し入れて火を通し、器に盛る。",
    ];
  }
  if (kind === "microwave") {
    return [
      "{veg}を洗って耐熱皿に乗せる。",
      "電子レンジで4分加熱する。",
      "バター{g:butter}gと塩{g:salt}gをのせ、こしょう{g:pepper}gを振る。",
      "2分置いて熱いうちに出す。",
    ];
  }
  if (kind === "nanban") {
    return [
      "{protein}と玉ねぎ{g:onion}gを食べやすく切る。",
      "フライパンを中火にし、{oil}{g:oil}gで{protein}を4分焼く。",
      "酢{g:vinegar}gとしょうゆ{g:soy}gと砂糖{g:sugar}gを混ぜ、2分漬けてなじませる。",
      "玉ねぎを添えて器に盛る。",
    ];
  }
  if (kind === "chanchan") {
    return [
      "鮭{g:protein}gと{veg}を食べやすく切る。",
      "フライパンに鮭と{veg}、味噌{g:miso}g、砂糖{g:sugar}g、しょうゆ{g:soy}gを入れる。",
      "ふたをして中火で6分焼く。",
      "2分蒸らしてから器に盛る。",
    ];
  }
  if (kind === "mapo") {
    return [
      "木綿豆腐{g:tofu}gと{protein}を食べやすく切る。",
      "フライパンにごま油{g:oil}gを熱し、{protein}とねぎ{g:negi}gを3分炒める。",
      "豆腐と水を50ml、しょうゆ{g:soy}gと味噌{g:miso}gと砂糖{g:sugar}gを加えて4分煮る。",
      keys.has("rice") ? "とろみがついたらごはん{g:rice}gにのせる。" : "とろみがついたら器に盛る。",
    ];
  }
  if (kind === "nikujaga") {
    return [
      "{protein}とじゃがいも{g:potato}gと玉ねぎ{g:onion}gを食べる大きさに切る。",
      "鍋に水を200mlと顆粒だし{g:dashi}gを入れ、{protein}を5分煮る。",
      "じゃがいもと玉ねぎ、しょうゆ{g:soy}g、みりん{g:mirin}g、砂糖{g:sugar}gを加える。",
      "弱火で6分煮て、じゃがいもに火を通す。",
    ];
  }
  if (kind === "chahan") {
    return [
      keys.has("veg") ? "{protein}と{veg}を小さく切り、卵{g:egg}gを溶いておく。" : "{protein}を小さく切り、卵{g:egg}gを溶いておく。",
      "フライパンを中火にし、{oil}{g:oil}gで{protein}を2分炒める。",
      "卵とごはん{g:rice}gを加えて3分炒め、しょうゆ{g:soy}gと塩{g:salt}gで味をつける。",
      "パラッとしたら火を止めて器に盛る。",
    ];
  }
  return [
    "食パン{g:bread}gに{protein}をのせる。",
    "フライパンを弱火にし、バター{g:butter}gで2分焼く。",
    "塩{g:salt}gとこしょう{g:pepper}gを振る。",
    "3分加熱して中まで温まったら皿に出す。",
  ];
}

function dish(
  id: string,
  name: string,
  genre: Genre,
  category: Category,
  method: string,
  kind: Kind,
  slots: CookSlot[],
): CookRecipe {
  const keys = new Set(slots.map((item) => item.key));
  const steps = seasoningTail(stepsFor(kind, keys), keys);
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

const oil = (grams: number) => s("oil", [["oil", grams]]);
const sesame = (grams: number) => s("oil", [["sesame", grams]]);
const soy = (grams: number) => s("soy", [["soy", grams]]);
const mirin = (grams: number) => s("mirin", [["mirin", grams]]);
const sugar = (grams: number) => s("sugar", [["sugar", grams]]);
const salt = (grams: number) => s("salt", [["salt", grams]]);
const miso = (grams: number) => s("miso", [["miso", grams]]);
const dashi = (grams: number) => s("dashi", [["dashi", grams]]);
const sake = (grams: number) => s("sake", [["sake", grams]]);
const pepper = (grams: number) => s("pepper", [["pepper", grams]]);
const vinegar = (grams: number) => s("vinegar", [["vinegar", grams]]);
const rice = (grams: number) => s("rice", [["rice", grams]]);
const egg = (grams: number) => s("egg", [["egg", grams]]);
const ginger = (grams: number) => s("ginger", [["ginger", grams]]);

function frySeason(oilG = 8, soyG = 10, mirinG = 10): CookSlot[] {
  return [oil(oilG), soy(soyG), mirin(mirinG)];
}

export function buildCookRecipes(): CookRecipe[] {
  const list: CookRecipe[] = [
    dish("shoga", "{protein}の生姜焼き", "和", "主菜", "焼", "fry", [
      meats(130, 120, 120, 110, 80), ginger(20), ...frySeason(8, 12, 12),
    ]),
    dish("shoga-don", "{protein}の生姜焼き丼", "和", "丼麺", "焼", "fry", [
      meats(120, 110, 110, 100, 70), ginger(20), rice(180), ...frySeason(10, 12, 12),
    ]),
    dish("shoga-light", "{protein}の塩だれ焼き", "和", "主菜", "焼", "fry", [
      meatsNoSoy(170, 150, 140, 130), ginger(20), ...frySeason(6, 8, 8), salt(1),
    ]),
    dish("miso-itame", "{protein}と{veg}の味噌炒め", "和", "主菜", "炒", "miso", [
      meats(120, 110, 120, 100, 80), veg4(90, 110, 70, 90), oil(8), miso(12), sugar(6), sake(8),
    ]),
    dish("miso-don", "{protein}と{veg}の味噌炒め丼", "和", "丼麺", "炒", "miso", [
      meats(110, 100, 110, 90, 70), veg4(70, 90, 50, 70), rice(170), oil(8), miso(12), sugar(6), sake(8),
    ]),
    dish("soy-itame", "{protein}と{veg}の醤油炒め", "和", "主菜", "炒", "fry", [
      meats(140, 130, 130, 110, 80), veg4(100, 120, 80, 100), ...frySeason(8, 12, 8),
    ]),
    dish("soy-rice", "{protein}と{veg}の醤油炒め丼", "和", "丼麺", "炒", "fry", [
      meats(120, 110, 120, 100, 70), veg4(80, 100, 60, 80), rice(190), ...frySeason(10, 10, 10),
    ]),
    dish("nikujaga", "肉じゃが", "和", "主菜", "煮", "nikujaga", [
      meatsNoSoy(90, 90, 100, 90),
      s("potato", [["potato", 180]]),
      s("onion", [["onion", 70]]),
      dashi(8), soy(12), mirin(12), sugar(8),
    ]),
    dish("oyako", "親子丼", "和", "丼麺", "煮", "oyako", [
      chickenPair(110, 100),
      s("onion", [["onion", 50]]),
      egg(50), rice(180), dashi(6), soy(10), mirin(10),
    ]),
    dish("oyako-large", "大盛り親子丼", "和", "丼麺", "煮", "oyako", [
      chickenPair(180, 160),
      s("onion", [["onion", 60]]),
      egg(100), rice(260), dashi(8), soy(12), mirin(12),
    ]),
    dish("gyudon", "牛こま丼", "和", "丼麺", "焼", "don", [
      s("protein", [["beef", 120]]), rice(200), oil(6), soy(12), mirin(12), sugar(6),
    ]),
    dish("butadon", "豚こま丼", "和", "丼麺", "焼", "don", [
      s("protein", [["pork", 120]]), rice(190), oil(8), soy(12), mirin(10), sugar(4),
    ]),
    dish("chanchan", "鮭と{veg}のちゃんちゃん焼き", "和", "主菜", "焼", "chanchan", [
      s("protein", [["salmon", 130]]),
      s("veg", [["cabbage", 90], ["onion", 70], ["hakusai", 100]]),
      miso(12), sugar(6), soy(6),
    ]),
    dish("salmon-fry", "鮭と{veg}の味噌炒め", "和", "主菜", "炒", "miso", [
      s("protein", [["salmon", 130]]),
      veg4(80, 100, 60, 80),
      oil(6), miso(10), sugar(4), sake(6),
    ]),
    dish("salmon-rice", "鮭の焼き丼", "和", "丼麺", "焼", "don", [
      s("protein", [["salmon", 140]]), rice(170), oil(6), soy(8), mirin(8), sugar(4),
    ]),
    dish("nanban", "{protein}の南蛮漬け", "和", "主菜", "焼", "nanban", [
      chickenPair(140, 130),
      s("onion", [["onion", 60]]),
      oil(8), vinegar(12), soy(10), sugar(8),
    ]),
    dish("steam-rice", "{protein}のレンジ蒸し丼", "和", "丼麺", "蒸", "steam", [
      meatsNoSoy(140, 130, 120, 110), rice(180), soy(10), mirin(8), salt(1),
    ]),
    dish("steam-plate", "{protein}の塩蒸し", "和", "主菜", "蒸", "steam", [
      meatsNoSoy(170, 150, 140, 120), soy(8), mirin(6), salt(1),
    ]),
    dish("miso-soup-tofu", "木綿豆腐と{veg}の味噌汁", "和", "汁物", "煮", "soup", [
      s("protein", [["tofu", 120]]), veg4(40, 50, 40, 40), dashi(6), miso(12), soy(4),
    ]),
    dish("miso-soup-pork", "{protein}の味噌汁", "和", "汁物", "煮", "soup", [
      meatsNoSoy(70, 70, 70, 60), dashi(6), miso(12), soy(4),
    ]),
    dish("hiyayakko", "冷奴", "和", "副菜", "和え", "cold", [
      s("tofu", [["kinu", 150]]), soy(8), ginger(20),
    ]),
    dish("ohitashi-leaf", "{veg}のおひたし", "和", "副菜", "和え", "ohitashi", [
      leaf3(80, 90, 70), soy(8), dashi(3),
    ]),
    dish("cabbage-ae", "{veg}の和え物", "和", "副菜", "和え", "ae", [
      veg4(80, 90, 60, 80), salt(1), soy(6), vinegar(8), sugar(4),
    ]),
    dish("cucumber-ae", "きゅうりの和え物", "和", "副菜", "和え", "ae", [
      s("veg", [["cucumber", 80]]), salt(1), soy(6), vinegar(8), sugar(4),
    ]),
    dish("potato-butter", "{veg}のバター蒸し", "和", "軽い品", "蒸", "microwave", [
      s("veg", [["potato", 160], ["pumpkin", 120]]),
      s("butter", [["butter", 6]]), salt(1), pepper(1),
    ]),
    dish("tamago", "卵焼き", "和", "軽い品", "焼", "egg", [
      egg(100), oil(1), salt(1), pepper(1),
    ]),
    dish("tamago-veg", "卵と{veg}の炒め", "和", "主菜", "炒", "egg", [
      egg(100), veg4(70, 80, 50, 70), oil(4), salt(1), pepper(1),
    ]),
    dish("tamago-gohan", "卵かけご飯", "和", "丼麺", "蒸", "tk", [
      egg(50), rice(160), soy(8), salt(1),
    ]),
    dish("natto-gohan", "納豆和えご飯", "和", "丼麺", "和え", "natto", [
      s("protein", [["natto", 50]]), rice(160), soy(6), salt(1),
    ]),
    dish("udon", "{protein}と{veg}の煮込みうどん", "和", "丼麺", "煮", "soup", [
      meatsNoSoy(80, 80, 80, 70),
      s("veg", [["onion", 40], ["negi", 40]]),
      s("rice", [["udon", 200]]),
      dashi(6), miso(8), soy(6),
    ]),
    dish("soba", "{protein}とねぎの煮込みそば", "和", "丼麺", "煮", "soup", [
      meatsNoSoy(70, 70, 70, 60),
      s("veg", [["negi", 40]]),
      s("rice", [["soba", 180]]),
      dashi(6), miso(8), soy(6),
    ]),
    dish("chahan", "{protein}チャーハン", "中", "丼麺", "炒", "chahan", [
      meatsNoSoy(80, 80, 90, 70), egg(50), rice(200), oil(8), soy(8), salt(1),
    ]),
    dish("chahan-veg", "{protein}と{veg}の炒飯", "中", "丼麺", "炒", "chahan", [
      meatsNoSoy(70, 70, 80, 60),
      veg4(50, 60, 40, 50),
      egg(50), rice(190), oil(8), soy(8), salt(1),
    ]),
    dish("mapo", "麻婆豆腐", "中", "主菜", "炒", "mapo", [
      meatsNoSoy(80, 70, 90, 70),
      s("tofu", [["tofu", 180]]),
      s("negi", [["negi", 40]]),
      sesame(6), soy(8), miso(10), sugar(4),
    ]),
    dish("mapo-don", "麻婆豆腐丼", "中", "丼麺", "炒", "mapo", [
      s("protein", [["pork", 80], ["chicken", 90]]),
      s("tofu", [["tofu", 150]]),
      s("negi", [["negi", 40]]),
      rice(180), sesame(6), soy(8), miso(10), sugar(4),
    ]),
    dish("hoikoro", "{protein}と{veg}の細切り炒め", "中", "主菜", "炒", "fry", [
      meatsNoSoy(120, 110, 120, 100),
      s("veg", [["piman", 70], ["cabbage", 80], ["moyashi", 80]]),
      ...frySeason(8, 10, 8),
    ]),
    dish("subuta", "酢豚", "中", "主菜", "炒", "nanban", [
      s("protein", [["pork", 130]]),
      s("onion", [["onion", 70]]),
      oil(8), vinegar(14), soy(10), sugar(10),
    ]),
    dish("tomato-egg", "トマトと卵の炒め", "中", "主菜", "炒", "egg", [
      egg(100), s("veg", [["tomato", 100]]), oil(6), salt(1), pepper(1),
    ]),
    dish("tomato-egg-rice", "トマトと卵の炒め丼", "中", "丼麺", "炒", "egg", [
      egg(100), s("veg", [["tomato", 80]]), rice(160), oil(6), salt(1), pepper(1),
    ]),
    dish("chinjao", "{protein}とピーマンの炒め", "中", "主菜", "炒", "fry", [
      meatsNoSoy(130, 120, 130, 110),
      s("veg", [["piman", 80]]),
      ...frySeason(8, 10, 8),
    ]),
    dish("moyashi-pork", "{protein}ともやしの炒め", "中", "主菜", "炒", "fry", [
      s("protein", [["pork", 120], ["chicken", 130], ["beef", 100]]),
      s("veg", [["moyashi", 100]]),
      ...frySeason(8, 10, 6),
    ]),
    dish("hakusai-pork", "{protein}と白菜のうま煮", "中", "主菜", "煮", "simmer", [
      meatsNoSoy(100, 100, 110, 90),
      s("veg", [["hakusai", 120]]),
      dashi(8), soy(10), mirin(8), sugar(4),
    ]),
    dish("tofu-stir", "木綿豆腐と{veg}の炒め", "中", "主菜", "炒", "fry", [
      s("protein", [["tofu", 200]]),
      veg4(70, 80, 50, 70),
      ...frySeason(6, 8, 6),
    ]),
    dish("garlic-chicken", "{protein}のにんにく炒め", "中", "主菜", "炒", "fry", [
      meatsNoSoy(150, 140, 130, 120),
      s("ginger", [["garlic", 20]]),
      ...frySeason(8, 10, 6),
    ]),
    dish("egg-drop", "かきたま汁", "中", "汁物", "煮", "soup", [
      s("protein", [["egg", 50]]), dashi(6), miso(6), soy(4),
    ]),
    dish("tuna-cabbage", "ツナとキャベツの和風パスタ", "洋", "丼麺", "炒", "pasta", [
      s("protein", [["tuna", 70]]),
      s("veg", [["cabbage", 70]]),
      s("pasta", [["pasta", 180]]),
      oil(6), soy(8), pepper(1),
    ]),
    dish("tuna-tomato", "ツナとトマトのパスタ", "洋", "丼麺", "炒", "pasta", [
      s("protein", [["tuna", 70]]),
      s("veg", [["tomato", 80]]),
      s("pasta", [["pasta", 180]]),
      oil(6), soy(6), pepper(1),
    ]),
    dish("salmon-pasta", "鮭とほうれん草のパスタ", "洋", "丼麺", "炒", "pasta", [
      s("protein", [["salmon", 100]]),
      s("veg", [["spinach", 50]]),
      s("pasta", [["pasta", 170]]),
      oil(6), soy(6), pepper(1),
    ]),
    dish("chicken-tomato", "{protein}のトマト煮", "洋", "主菜", "煮", "simmer", [
      meatsNoSoy(140, 130, 120, 110),
      s("veg", [["tomato", 100]]),
      dashi(4), soy(6), mirin(6), sugar(4),
    ]),
    dish("chicken-tomato-rice", "{protein}のトマト煮丼", "洋", "丼麺", "煮", "simmer", [
      meatsNoSoy(120, 110, 110, 100),
      s("veg", [["tomato", 80]]),
      rice(170), dashi(4), soy(6), mirin(6), sugar(4),
    ]),
    dish("omelette", "オムレツ", "洋", "主菜", "焼", "egg", [
      egg(100), oil(4), salt(1), pepper(1),
    ]),
    dish("omelette-veg", "{veg}のオムレツ", "洋", "主菜", "焼", "egg", [
      s("veg", [["tomato", 60], ["spinach", 40], ["onion", 50]]),
      egg(100), oil(4), salt(1), pepper(1),
    ]),
    dish("hamburger", "{protein}のハンバーグ", "洋", "主菜", "焼", "fry", [
      meatsNoSoy(140, 130, 130, 120),
      s("onion", [["onion", 50]]),
      ...frySeason(8, 8, 8),
    ]),
    dish("saute", "{protein}のソテー", "洋", "主菜", "焼", "fry", [
      meatsNoSoy(150, 140, 130, 120), ...frySeason(8, 6, 6), salt(1),
    ]),
    dish("saute-veg", "{protein}と{veg}のソテー", "洋", "主菜", "焼", "fry", [
      meatsNoSoy(140, 130, 120, 110),
      s("veg", [["broccoli", 80], ["piman", 60], ["spinach", 60]]),
      ...frySeason(8, 6, 6),
    ]),
    dish("gratin-toast", "ツナトースト", "洋", "軽い品", "焼", "toast", [
      s("protein", [["tuna", 60]]),
      s("bread", [["bread", 70]]),
      s("butter", [["butter", 5]]),
      salt(1), pepper(1),
    ]),
    dish("cheese-toast", "チーズトースト", "洋", "軽い品", "焼", "toast", [
      s("protein", [["cheese", 20]]),
      s("bread", [["bread", 70]]),
      s("butter", [["butter", 5]]),
      salt(1), pepper(1),
    ]),
    dish("egg-bread", "卵の焼きトースト", "洋", "主食", "焼", "toast", [
      s("protein", [["egg", 50]]),
      s("bread", [["bread", 70]]),
      s("butter", [["butter", 5]]),
      salt(1), pepper(1),
    ]),
    dish("potato-salad", "じゃがいもの和え物", "洋", "副菜", "和え", "ae", [
      s("veg", [["potato", 120]]),
      salt(1), soy(4), vinegar(6), sugar(3),
    ]),
    dish("broccoli-ae", "ブロッコリーの和え物", "洋", "副菜", "和え", "ae", [
      s("veg", [["broccoli", 80]]), salt(1), soy(6), vinegar(6), sugar(3),
    ]),
    dish("minestrone", "トマトスープ", "洋", "汁物", "煮", "soup", [
      s("protein", [["tofu", 80], ["chicken", 70]]),
      s("veg", [["tomato", 80]]),
      dashi(4), miso(6), soy(4),
    ]),
    dish("creamless-stew", "{protein}とじゃがいもの煮込み", "洋", "主菜", "煮", "nikujaga", [
      meatsNoSoy(120, 110, 110, 100),
      s("potato", [["potato", 150]]),
      s("onion", [["onion", 60]]),
      dashi(6), soy(8), mirin(8), sugar(4),
    ]),
    dish("fish-meuniere", "鮭のムニエル", "洋", "主菜", "焼", "fry", [
      s("protein", [["salmon", 140]]),
      s("oil", [["butter", 6]]),
      soy(4), mirin(4), salt(1),
    ]),
    dish("garlic-tomato", "{protein}とトマトのにんにく炒め", "エスニック", "主菜", "炒", "fry", [
      meatsNoSoy(140, 130, 120, 110),
      s("veg", [["tomato", 90]]),
      s("ginger", [["garlic", 20]]),
      ...frySeason(8, 8, 6),
    ]),
    dish("garlic-cabbage", "{protein}とキャベツのにんにく炒め", "エスニック", "主菜", "炒", "fry", [
      meatsNoSoy(130, 120, 130, 110),
      s("veg", [["cabbage", 90]]),
      s("ginger", [["garlic", 20]]),
      ...frySeason(8, 8, 6),
    ]),
    dish("ethnic-veg", "{protein}と{veg}のエスニック炒め", "エスニック", "主菜", "炒", "miso", [
      meatsNoSoy(120, 110, 120, 100),
      veg4(80, 90, 70, 80),
      oil(8), miso(8), sugar(4), sake(6),
    ]),
    dish("ethnic-soup", "{protein}とトマトのスープ", "エスニック", "汁物", "煮", "soup", [
      meatsNoSoy(80, 80, 80, 70),
      s("veg", [["tomato", 80]]),
      dashi(6), miso(8), soy(4),
    ]),
    dish("ethnic-don", "{protein}のトマト丼", "エスニック", "丼麺", "煮", "simmer", [
      meatsNoSoy(130, 120, 110, 100),
      s("veg", [["tomato", 70]]),
      rice(180), dashi(4), soy(8), mirin(6), sugar(4),
    ]),
    dish("chicken-broccoli", "鶏むね肉とブロッコリーの甘辛炒め", "洋", "主菜", "炒", "fry", [
      s("protein", [["chicken", 170]]),
      s("veg", [["broccoli", 100]]),
      oil(10), soy(6), mirin(8), sugar(12),
    ]),
    dish("chicken-broccoli-any", "{protein}とブロッコリーの炒め", "洋", "主菜", "炒", "fry", [
      meatsNoSoy(150, 140, 130, 120),
      s("veg", [["broccoli", 80]]),
      ...frySeason(8, 8, 8),
    ]),
    dish("low-oil-chicken", "{protein}と{veg}の蒸し炒め", "和", "主菜", "蒸", "steam", [
      meatsNoSoy(160, 140, 130, 120),
      veg4(60, 70, 50, 60),
      soy(8), mirin(8), salt(1),
    ]),
    dish("hearty-don", "{protein}と卵の丼", "和", "丼麺", "焼", "chahan", [
      meatsNoSoy(220, 180, 160, 150),
      egg(100), rice(280), oil(12), soy(10), salt(1),
    ]),
    dish("pork-cabbage-rice", "豚こまとキャベツの丼", "和", "丼麺", "炒", "fry", [
      s("protein", [["pork", 120]]),
      s("veg", [["cabbage", 80]]),
      s("onion", [["onion", 50]]),
      rice(180), ...frySeason(8, 10, 8),
    ]),
    dish("chicken-onion-rice", "鶏むね肉と玉ねぎの丼", "和", "丼麺", "炒", "fry", [
      s("protein", [["chicken", 140]]),
      s("onion", [["onion", 70]]),
      rice(170), ...frySeason(10, 10, 8),
    ]),
    dish("chicken-spinach-rice", "鶏むね肉とほうれん草の丼", "和", "丼麺", "炒", "fry", [
      s("protein", [["chicken", 150]]),
      s("veg", [["spinach", 60]]),
      rice(180), ...frySeason(10, 8, 8),
    ]),
    dish("tofu-rice", "木綿豆腐の丼", "和", "丼麺", "焼", "don", [
      s("protein", [["tofu", 200]]), rice(150), oil(4), soy(8), mirin(6), sugar(4),
    ]),
    dish("natto-egg-rice", "納豆と卵の丼", "和", "丼麺", "蒸", "natto", [
      s("protein", [["natto", 60]]), egg(50), rice(140), soy(6), salt(1),
    ]),
    dish("salmon-cabbage-rice", "鮭とキャベツの丼", "和", "丼麺", "焼", "don", [
      s("protein", [["salmon", 140]]),
      s("veg", [["cabbage", 70]]),
      rice(120), oil(8), soy(8), mirin(6), sugar(2),
    ]),
    dish("cabbage-egg", "キャベツと卵の炒め", "和", "軽い品", "炒", "egg", [
      egg(50), s("veg", [["cabbage", 80]]), oil(3), soy(8), mirin(12), salt(1),
    ]),
    dish("chicken-potato", "鶏むね肉とじゃがいもの煮物", "和", "主菜", "煮", "nikujaga", [
      s("protein", [["chicken", 160]]),
      s("potato", [["potato", 180]]),
      s("onion", [["onion", 60]]),
      dashi(8), soy(8), mirin(12), sugar(10),
    ]),
    dish("many-bowl", "鶏むね肉とキャベツの丼", "和", "丼麺", "炒", "fry", [
      s("protein", [["chicken", 160]]),
      s("veg", [["cabbage", 70]]),
      egg(50), rice(200), oil(12), soy(8), mirin(8),
    ]),
    dish("pork-only-rice", "豚こまの照り焼き丼", "和", "丼麺", "焼", "don", [
      s("protein", [["pork", 120]]), rice(180), oil(8), soy(10), mirin(10), sugar(6),
    ]),
    dish("avoid-oil-chicken", "鶏むね肉の煮丼", "和", "丼麺", "煮", "oyako", [
      s("protein", [["chicken", 140]]),
      s("onion", [["onion", 40]]),
      egg(50), rice(170), dashi(6), soy(10), mirin(10),
    ]),
    dish("negi-salt", "{protein}のねぎ塩炒め", "和", "主菜", "炒", "fry", [
      meats(140, 130, 130, 110, 80),
      s("veg", [["negi", 50]]),
      oil(8), soy(6), mirin(6), salt(1),
    ]),
    dish("chuka-don", "{protein}と{veg}の中華丼", "中", "丼麺", "焼", "don", [
      meatsNoSoy(120, 110, 110, 100),
      veg4(70, 90, 60, 70),
      rice(180), oil(8), soy(10), mirin(8), sugar(6),
    ]),
    dish("yurinchi", "油淋鶏", "中", "主菜", "焼", "nanban", [
      chickenPair(140, 130),
      s("onion", [["onion", 60]]),
      oil(8), vinegar(12), soy(10), sugar(8),
    ]),
    dish("tofu-chuka", "木綿豆腐と{veg}の中華炒め", "中", "主菜", "炒", "fry", [
      s("protein", [["tofu", 180]]),
      veg4(80, 100, 60, 80),
      ...frySeason(6, 8, 6),
    ]),
    dish("negi-fry", "{protein}とねぎの炒め", "中", "主菜", "炒", "fry", [
      meatsNoSoy(130, 120, 120, 110),
      s("veg", [["negi", 50]]),
      ...frySeason(8, 10, 6),
    ]),
    dish("tuna-chuka", "ツナと{veg}の中華炒め", "中", "主菜", "炒", "fry", [
      s("protein", [["tuna", 80]]),
      veg4(80, 100, 60, 80),
      ...frySeason(6, 8, 6),
    ]),
    dish("egg-tomato-soup", "{protein}とトマトのスープ", "中", "汁物", "煮", "soup", [
      s("protein", [["egg", 50]]),
      s("veg", [["tomato", 80]]),
      dashi(6), miso(8), soy(4),
    ]),
    dish("chuka-steam", "{protein}の中華蒸し", "中", "主菜", "蒸", "steam", [
      meatsNoSoy(160, 150, 140, 120),
      soy(8), mirin(8), salt(1),
    ]),
    dish("hakusai-fry", "白菜と{protein}の炒め", "中", "主菜", "炒", "fry", [
      meatsNoSoy(120, 110, 120, 100),
      s("veg", [["hakusai", 120]]),
      ...frySeason(8, 10, 8),
    ]),
    dish("grill", "{protein}のグリル", "洋", "主菜", "焼", "fry", [
      meatsNoSoy(160, 150, 140, 130),
      ...frySeason(6, 6, 6), salt(1), pepper(1),
    ]),
    dish("tuna-onion-pasta", "ツナと玉ねぎのパスタ", "洋", "丼麺", "炒", "pasta", [
      s("protein", [["tuna", 70]]),
      s("veg", [["onion", 70]]),
      s("pasta", [["pasta", 180]]),
      oil(6), soy(8), pepper(1),
    ]),
    dish("broccoli-grill", "{protein}とブロッコリーのグリル", "洋", "主菜", "焼", "fry", [
      meatsNoSoy(150, 140, 130, 120),
      s("veg", [["broccoli", 80]]),
      ...frySeason(6, 6, 6), salt(1), pepper(1),
    ]),
    dish("salmon-tomato-pasta", "鮭とトマトのパスタ", "洋", "丼麺", "炒", "pasta", [
      s("protein", [["salmon", 100]]),
      s("veg", [["tomato", 80]]),
      s("pasta", [["pasta", 170]]),
      oil(6), soy(6), pepper(1),
    ]),
    dish("tuna-sandwich", "ツナの焼きサンド", "洋", "軽い品", "焼", "toast", [
      s("protein", [["tuna", 70]]),
      s("bread", [["bread", 70]]),
      s("butter", [["butter", 5]]),
      salt(1), pepper(1),
    ]),
    dish("ethnic-tomato", "{protein}とトマトの炒め", "エスニック", "主菜", "炒", "fry", [
      meatsNoSoy(140, 130, 120, 110),
      s("veg", [["tomato", 90]]),
      ...frySeason(8, 8, 6),
    ]),
    dish("tuna-ethnic", "ツナとキャベツのエスニック炒め", "エスニック", "主菜", "炒", "miso", [
      s("protein", [["tuna", 80]]),
      s("veg", [["cabbage", 90]]),
      oil(8), miso(10), sugar(6), sake(8),
    ]),
    dish("garlic-don", "{protein}のガーリック丼", "エスニック", "丼麺", "焼", "fry", [
      meatsNoSoy(120, 110, 110, 100),
      s("ginger", [["garlic", 20]]),
      rice(180), ...frySeason(8, 10, 8),
    ]),
  ];
  const seen = new Set<string>();
  for (const recipe of list) {
    if (seen.has(recipe.id)) {
      throw new Error(`duplicate recipe id ${recipe.id}`);
    }
    seen.add(recipe.id);
  }
  return list;
}

export const cookRecipes = buildCookRecipes();
