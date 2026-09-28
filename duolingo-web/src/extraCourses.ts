import type { Course, LessonNode, Question, Section } from './types'

type Line = { text: string; ja: string }

type UnitSeed = {
  title: string
  color: string
  dark: string
  phrases: Line[]
  lesson1: Question[]
  lesson2: Question[]
  storyTitle: string
  passage: string[]
  storyQs: Question[]
  review: Question[]
}

function slotted(correct: string, wrong: string[], slot: number) {
  const choices = [...wrong]
  const answer = Math.min(Math.max(slot, 0), choices.length)
  choices.splice(answer, 0, correct)
  return { choices, answer }
}

function meaning(script: string, line: Line, wrong: string[], slot: number): Question {
  return {
    type: 'choice',
    prompt: `この${script}の意味を選んでください`,
    sentence: line.text,
    ...slotted(line.ja, wrong, slot),
  }
}

function target(script: string, ja: string, answer: string, wrong: string[], slot: number): Question {
  return {
    type: 'choice',
    prompt: `日本語にあう${script}を選んでください`,
    sentence: ja,
    ...slotted(answer, wrong, slot),
  }
}

function bank(script: string, ja: string, answer: string[], extra: string[]): Question {
  return {
    type: 'bank',
    prompt: `日本語にあう${script}を作ってください`,
    sentence: ja,
    answer,
    extra,
  }
}

function listen(script: string, line: Line, wrong: string[], slot: number): Question {
  return {
    type: 'listen',
    prompt: `聞こえた${script}の意味を選んでください`,
    speak: line.text,
    ...slotted(line.ja, wrong, slot),
  }
}

function blank(promptJa: string, before: string, after: string, answer: string, wrong: string[], slot: number): Question {
  return {
    type: 'blank',
    prompt: `「${promptJa}」になるように選んでください`,
    before,
    after,
    ...slotted(answer, wrong, slot),
  }
}

function match(script: string, lines: Line[]): Question {
  return {
    type: 'match',
    prompt: `${script}と日本語のペアを選んでください`,
    pairs: lines.map((line) => [line.text, line.ja]),
  }
}

function lesson(id: string, kind: LessonNode['kind'], title: string, xp: number, questions: Question[], passage?: string[]): LessonNode {
  return { id, kind, title, xp, questions, passage }
}

function buildCourse(
  meta: Omit<Course, 'sections' | 'practice'>,
  units: UnitSeed[],
  practice: { listen: Question[]; match: Question[]; bank: Question[] },
): Course {
  const colors = units
  const made: Section[] = [
    {
      id: `${meta.id}-s1`,
      title: 'セクション 1',
      kicker: `${meta.label}の入門`,
      units: colors.slice(0, 2).map((unit, index) => toUnit(meta.id, index + 1, unit)),
    },
    {
      id: `${meta.id}-s2`,
      title: 'セクション 2',
      kicker: '街で使う',
      units: colors.slice(2).map((unit, index) => toUnit(meta.id, index + 3, unit)),
    },
  ]
  return {
    ...meta,
    sections: made,
    practice: [
      lesson(`${meta.id}-p-listen`, 'lesson', 'リスニング', 10, practice.listen),
      lesson(`${meta.id}-p-match`, 'lesson', `${meta.script}マッチ`, 10, practice.match),
      lesson(`${meta.id}-p-build`, 'lesson', '文を作る', 10, practice.bank),
    ],
  }
}

function toUnit(courseId: string, index: number, unit: UnitSeed) {
  const id = `${courseId}-u${index}`
  return {
    id,
    title: unit.title,
    color: unit.color,
    dark: unit.dark,
    phrases: unit.phrases,
    nodes: [
      lesson(`${id}l1`, 'lesson', '基本', 15, unit.lesson1),
      lesson(`${id}l2`, 'lesson', 'もう一歩', 15, unit.lesson2),
      { id: `${id}c`, kind: 'chest' as const, title: '宝箱', gems: 20 + index * 5 },
      lesson(`${id}s`, 'story', unit.storyTitle, 15, unit.storyQs, unit.passage),
      lesson(`${id}t`, 'trophy', `ユニット ${index} の復習`, 20, unit.review),
    ],
  }
}

const green = { color: '#58cc02', dark: '#46a302' }
const purple = { color: '#ce82ff', dark: '#a568cc' }
const blue = { color: '#1cb0f6', dark: '#1899d6' }
const pink = { color: '#ff86d0', dark: '#e066b0' }

function english(): Course {
  const script = '英語'
  const hello = { text: 'Hello.', ja: 'こんにちは' }
  const thanks = { text: 'Thank you.', ja: 'ありがとう' }
  const meet = { text: 'Nice to meet you.', ja: 'はじめまして' }
  const bye = { text: 'Goodbye.', ja: 'さようなら' }
  const sorry = { text: 'Sorry.', ja: 'ごめんなさい' }
  const yes = { text: 'Yes.', ja: 'はい' }
  const no = { text: 'No.', ja: 'いいえ' }
  const night = { text: 'Good night.', ja: 'おやすみなさい' }
  const hana = { text: 'I am Hana.', ja: '私はハナです' }
  const student = { text: 'I am a student.', ja: '学生です' }
  const japanese = { text: 'I am Japanese.', ja: '日本人です' }
  const nameQ = { text: 'What is your name?', ja: 'お名前は何ですか' }
  const ken = { text: 'My name is Ken.', ja: '私の名前はケンです' }
  const coffee = { text: 'Coffee, please.', ja: 'コーヒーをください' }
  const water = { text: 'Water, please.', ja: '水をください' }
  const menu = { text: 'The menu, please.', ja: 'メニューをください' }
  const tasty = { text: 'This is delicious.', ja: 'おいしいです' }
  const price = { text: 'How much is this?', ja: 'これはいくらですか' }
  const station = { text: 'Where is the station?', ja: '駅はどこですか' }
  const left = { text: 'Turn left.', ja: '左に曲がってください' }
  const right = { text: 'Turn right.', ja: '右に曲がってください' }
  const straight = { text: 'Go straight.', ja: 'まっすぐ行ってください' }
  const ticket = { text: 'A ticket, please.', ja: '切符をください' }

  const lesson1 = [
    meaning(script, hello, ['さようなら', 'ありがとう', 'ごめんなさい'], 1),
    bank(script, meet.ja, ['Nice', 'to', 'meet', 'you.'], ['Goodbye.', 'Sorry.']),
    listen(script, thanks, ['こんにちは', 'ごめんなさい', 'はい'], 2),
    blank('ありがとう', 'Thank ', '.', 'you', ['me', 'yes', 'no'], 0),
  ]
  const lesson2 = [
    target(script, bye.ja, bye.text, ['Hello.', 'Sorry.', 'Yes.'], 2),
    bank(script, night.ja, ['Good', 'night.'], ['morning.', 'bye.']),
    match(script, [hello, thanks, yes, no]),
    meaning(script, sorry, ['こんにちは', 'ありがとう', 'はい'], 0),
  ]
  const self1 = [
    meaning(script, hana, ['ハナは学生です', 'ハナが好きです', 'ハナはここにいます'], 2),
    bank(script, student.ja, ['I', 'am', 'a', 'student.'], ['teacher.', 'water.']),
    blank('日本人です', 'I am ', '.', 'Japanese', ['a student', 'Hana', 'sorry'], 1),
    target(script, nameQ.ja, nameQ.text, ['Where is the station?', 'How much is this?', 'Good night.'], 0),
  ]
  const self2 = [
    bank(script, ken.ja, ['My', 'name', 'is', 'Ken.'], ['Hana.', 'student.']),
    meaning(script, japanese, ['学生です', '私はハナです', 'お名前は何ですか'], 3),
    match(script, [hana, student, japanese, ken]),
    listen(script, nameQ, ['駅はどこですか', 'これはいくらですか', 'さようなら'], 1),
  ]
  const cafe1 = [
    target(script, coffee.ja, coffee.text, ['Water, please.', 'A ticket, please.', 'Goodbye.'], 1),
    bank(script, water.ja, ['Water,', 'please.'], ['Coffee,', 'ticket.']),
    listen(script, menu, ['水をください', '切符をください', 'こんにちは'], 0),
    meaning(script, tasty, ['高いです', '冷たいです', '忙しいです'], 2),
  ]
  const cafe2 = [
    meaning(script, price, ['駅はどこですか', 'お名前は何ですか', 'おいしいです'], 3),
    bank(script, coffee.ja, ['Coffee,', 'please.'], ['Water,', 'menu.']),
    match(script, [coffee, water, tasty, price]),
    target(script, menu.ja, menu.text, ['Coffee, please.', 'Turn left.', 'Sorry.'], 2),
  ]
  const way1 = [
    meaning(script, station, ['これはいくらですか', 'お名前は何ですか', 'さようなら'], 1),
    bank(script, left.ja, ['Turn', 'left.'], ['right.', 'straight.']),
    listen(script, straight, ['左に曲がってください', '右に曲がってください', '切符をください'], 0),
    match(script, [station, left, right, straight]),
  ]
  const way2 = [
    target(script, right.ja, right.text, ['Turn left.', 'Go straight.', 'Hello.'], 2),
    bank(script, ticket.ja, ['A', 'ticket,', 'please.'], ['Coffee,', 'Water,']),
    listen(script, station, ['これはいくらですか', '私はハナです', 'ありがとう'], 3),
    meaning(script, ticket, ['コーヒーをください', '水をください', 'メニューをください'], 1),
  ]

  return buildCourse(
    {
      id: 'en',
      label: '英語',
      speechLang: 'en-US',
      htmlLang: 'en',
      script,
      sample: 'Hello',
      sampleJa: 'こんにちは',
    },
    [
      {
        ...green,
        title: 'あいさつをしよう',
        phrases: [hello, thanks, meet, bye, sorry, yes, no, night],
        lesson1,
        lesson2,
        storyTitle: '朝の駅',
        passage: [
          'Hana: Hello!',
          '（ハナ：こんにちは！）',
          'Ken: Hello. Nice to meet you.',
          '（ケン：こんにちは。はじめまして。）',
          'Hana: Nice to meet you.',
          '（ハナ：はじめまして。）',
        ],
        storyQs: [
          target(script, 'ケンの最初のあいさつ', 'Hello.', ['Goodbye.', 'Sorry.', 'Good night.'], 0),
          meaning(script, meet, ['さようなら', 'おやすみなさい', 'ごめんなさい'], 1),
        ],
        review: [
          listen(script, bye, ['こんにちは', 'ありがとう', 'はい'], 2),
          bank(script, thanks.ja, ['Thank', 'you.'], ['Sorry.', 'Hello.']),
          meaning(script, sorry, ['ありがとう', 'はい', 'いいえ'], 3),
        ],
      },
      {
        ...purple,
        title: '自分のことを話そう',
        phrases: [hana, student, japanese, nameQ, ken],
        lesson1: self1,
        lesson2: self2,
        storyTitle: 'はじめての会話',
        passage: [
          'Hana: Hello. I am Hana.',
          '（ハナ：こんにちは。私はハナです。）',
          'Hana: I am Japanese. I am a student.',
          '（ハナ：日本人です。学生です。）',
          'Ken: Nice to meet you. My name is Ken.',
          '（ケン：はじめまして。私の名前はケンです。）',
        ],
        storyQs: [
          meaning(script, hana, ['私の名前はケンです', '学生です', '日本人です'], 0),
          target(script, student.ja, student.text, ['I am Hana.', 'I am Japanese.', 'Good night.'], 2),
        ],
        review: [
          listen(script, ken, ['私はハナです', '学生です', 'おやすみなさい'], 1),
          bank(script, japanese.ja, ['I', 'am', 'Japanese.'], ['a', 'student.']),
          match(script, [nameQ, hana, student, japanese]),
        ],
      },
      {
        ...blue,
        title: 'カフェで注文しよう',
        phrases: [coffee, water, menu, tasty, price],
        lesson1: cafe1,
        lesson2: cafe2,
        storyTitle: '小さなカフェ',
        passage: [
          'Hana: Coffee, please.',
          '（ハナ：コーヒーをください。）',
          'Staff: Here you are.',
          '（店員：どうぞ。）',
          'Hana: This is delicious. Thank you.',
          '（ハナ：おいしいです。ありがとう。）',
        ],
        storyQs: [
          target(script, coffee.ja, coffee.text, ['Water, please.', 'A ticket, please.', 'Sorry.'], 1),
          meaning(script, tasty, ['高いです', '冷たいです', 'ありがとう'], 0),
        ],
        review: [
          listen(script, water, ['コーヒーをください', 'メニューをください', '切符をください'], 2),
          bank(script, price.ja, ['How', 'much', 'is', 'this?'], ['Where', 'station?']),
          meaning(script, menu, ['水をください', 'コーヒーをください', 'おいしいです'], 3),
        ],
      },
      {
        ...pink,
        title: '道をたずねよう',
        phrases: [station, left, right, straight, ticket],
        lesson1: way1,
        lesson2: way2,
        storyTitle: '駅までの道',
        passage: [
          'Hana: Excuse me. Where is the station?',
          '（ハナ：すみません。駅はどこですか？）',
          'Staff: Turn left. Go straight.',
          '（店員：左に曲がってください。まっすぐ行ってください。）',
          'Hana: Thank you.',
          '（ハナ：ありがとう。）',
        ],
        storyQs: [
          meaning(script, station, ['これはいくらですか', '左に曲がってください', '切符をください'], 2),
          target(script, left.ja, left.text, ['Turn right.', 'Go straight.', 'Goodbye.'], 0),
        ],
        review: [
          listen(script, right, ['左に曲がってください', 'まっすぐ行ってください', '駅はどこですか'], 1),
          bank(script, straight.ja, ['Go', 'straight.'], ['left.', 'right.']),
          meaning(script, ticket, ['コーヒーをください', '水をください', 'ありがとう'], 0),
        ],
      },
    ],
    {
      listen: [lesson1[2], self2[3], cafe1[2], way1[2]],
      match: [lesson2[2], self2[2], cafe2[2]],
      bank: [lesson1[1], self1[1], cafe2[1], way2[1]],
    },
  )
}

function spanish(): Course {
  const script = 'スペイン語'
  const hello = { text: 'Hola.', ja: 'こんにちは' }
  const thanks = { text: 'Gracias.', ja: 'ありがとう' }
  const meet = { text: 'Mucho gusto.', ja: 'はじめまして' }
  const bye = { text: 'Adiós.', ja: 'さようなら' }
  const sorry = { text: 'Lo siento.', ja: 'ごめんなさい' }
  const yes = { text: 'Sí.', ja: 'はい' }
  const no = { text: 'No.', ja: 'いいえ' }
  const night = { text: 'Buenas noches.', ja: 'おやすみなさい' }
  const hana = { text: 'Me llamo Hana.', ja: '私はハナです' }
  const student = { text: 'Soy estudiante.', ja: '学生です' }
  const from = { text: 'Soy de Japón.', ja: '日本出身です' }
  const nameQ = { text: '¿Cómo te llamas?', ja: 'お名前は何ですか' }
  const ken = { text: 'Me llamo Ken.', ja: '私の名前はケンです' }
  const coffee = { text: 'Un café, por favor.', ja: 'コーヒーをください' }
  const water = { text: 'Agua, por favor.', ja: '水をください' }
  const menu = { text: 'La carta, por favor.', ja: 'メニューをください' }
  const tasty = { text: 'Está rico.', ja: 'おいしいです' }
  const price = { text: '¿Cuánto es?', ja: 'いくらですか' }
  const station = { text: '¿Dónde está la estación?', ja: '駅はどこですか' }
  const left = { text: 'Gira a la izquierda.', ja: '左に曲がってください' }
  const right = { text: 'Gira a la derecha.', ja: '右に曲がってください' }
  const straight = { text: 'Sigue recto.', ja: 'まっすぐ行ってください' }
  const ticket = { text: 'Un billete, por favor.', ja: '切符をください' }

  const lesson1 = [
    meaning(script, hello, ['さようなら', 'ありがとう', 'ごめんなさい'], 0),
    bank(script, meet.ja, ['Mucho', 'gusto.'], ['Adiós.', 'Gracias.']),
    listen(script, thanks, ['こんにちは', 'ごめんなさい', 'はい'], 1),
    blank('こんにちは', '', '.', 'Hola', ['Adiós', 'Gracias', 'Sí'], 2),
  ]
  const lesson2 = [
    target(script, bye.ja, bye.text, ['Hola.', 'Gracias.', 'Sí.'], 1),
    bank(script, night.ja, ['Buenas', 'noches.'], ['días.', 'tarde.']),
    match(script, [hello, thanks, yes, no]),
    meaning(script, sorry, ['ありがとう', 'こんにちは', 'はい'], 3),
  ]
  const self1 = [
    meaning(script, hana, ['私の名前はケンです', '学生です', '日本出身です'], 1),
    bank(script, student.ja, ['Soy', 'estudiante.'], ['de', 'Japón.']),
    blank('日本出身です', 'Soy de ', '.', 'Japón', ['Hana', 'Ken', 'agua'], 0),
    target(script, nameQ.ja, nameQ.text, ['¿Dónde está la estación?', '¿Cuánto es?', 'Buenas noches.'], 2),
  ]
  const self2 = [
    bank(script, ken.ja, ['Me', 'llamo', 'Ken.'], ['Hana.', 'estudiante.']),
    meaning(script, from, ['学生です', '私はハナです', 'いくらですか'], 0),
    match(script, [hana, student, from, ken]),
    listen(script, nameQ, ['駅はどこですか', 'いくらですか', 'さようなら'], 3),
  ]
  const cafe1 = [
    target(script, coffee.ja, coffee.text, ['Agua, por favor.', 'Un billete, por favor.', 'Adiós.'], 0),
    bank(script, water.ja, ['Agua,', 'por', 'favor.'], ['café,', 'carta,']),
    listen(script, menu, ['水をください', '切符をください', 'こんにちは'], 2),
    meaning(script, tasty, ['高いです', '冷たいです', '忙しいです'], 1),
  ]
  const cafe2 = [
    meaning(script, price, ['駅はどこですか', 'お名前は何ですか', 'おいしいです'], 0),
    bank(script, coffee.ja, ['Un', 'café,', 'por', 'favor.'], ['Agua,', 'billete,']),
    match(script, [coffee, water, tasty, price]),
    target(script, menu.ja, menu.text, ['Un café, por favor.', 'Gira a la izquierda.', 'Lo siento.'], 3),
  ]
  const way1 = [
    meaning(script, station, ['いくらですか', 'お名前は何ですか', 'さようなら'], 2),
    bank(script, left.ja, ['Gira', 'a', 'la', 'izquierda.'], ['derecha.', 'recto.']),
    listen(script, straight, ['左に曲がってください', '右に曲がってください', '切符をください'], 1),
    match(script, [station, left, right, straight]),
  ]
  const way2 = [
    target(script, right.ja, right.text, ['Gira a la izquierda.', 'Sigue recto.', 'Hola.'], 0),
    bank(script, ticket.ja, ['Un', 'billete,', 'por', 'favor.'], ['café,', 'Agua,']),
    listen(script, station, ['いくらですか', '私はハナです', 'ありがとう'], 2),
    meaning(script, ticket, ['コーヒーをください', '水をください', 'メニューをください'], 3),
  ]

  return buildCourse(
    {
      id: 'es',
      label: 'スペイン語',
      speechLang: 'es-ES',
      htmlLang: 'es',
      script,
      sample: 'Hola',
      sampleJa: 'こんにちは',
    },
    [
      {
        ...green,
        title: 'あいさつをしよう',
        phrases: [hello, thanks, meet, bye, sorry, yes, no, night],
        lesson1,
        lesson2,
        storyTitle: '朝の駅',
        passage: [
          'Hana: ¡Hola!',
          '（ハナ：こんにちは！）',
          'Ken: Hola. Mucho gusto.',
          '（ケン：こんにちは。はじめまして。）',
          'Hana: Mucho gusto.',
          '（ハナ：はじめまして。）',
        ],
        storyQs: [
          target(script, 'ケンの最初のあいさつ', 'Hola.', ['Adiós.', 'Lo siento.', 'Buenas noches.'], 1),
          meaning(script, meet, ['さようなら', 'おやすみなさい', 'ごめんなさい'], 0),
        ],
        review: [
          listen(script, bye, ['こんにちは', 'ありがとう', 'はい'], 3),
          bank(script, thanks.ja, ['Gracias.'], ['Hola.', 'Adiós.']),
          meaning(script, sorry, ['ありがとう', 'はい', 'いいえ'], 2),
        ],
      },
      {
        ...purple,
        title: '自分のことを話そう',
        phrases: [hana, student, from, nameQ, ken],
        lesson1: self1,
        lesson2: self2,
        storyTitle: 'はじめての会話',
        passage: [
          'Hana: Hola. Me llamo Hana.',
          '（ハナ：こんにちは。私はハナです。）',
          'Hana: Soy de Japón. Soy estudiante.',
          '（ハナ：日本出身です。学生です。）',
          'Ken: Mucho gusto. Me llamo Ken.',
          '（ケン：はじめまして。私の名前はケンです。）',
        ],
        storyQs: [
          meaning(script, hana, ['私の名前はケンです', '学生です', '日本出身です'], 2),
          target(script, student.ja, student.text, ['Me llamo Hana.', 'Soy de Japón.', 'Buenas noches.'], 1),
        ],
        review: [
          listen(script, ken, ['私はハナです', '学生です', 'おやすみなさい'], 0),
          bank(script, from.ja, ['Soy', 'de', 'Japón.'], ['estudiante.', 'Ken.']),
          match(script, [nameQ, hana, student, from]),
        ],
      },
      {
        ...blue,
        title: 'カフェで注文しよう',
        phrases: [coffee, water, menu, tasty, price],
        lesson1: cafe1,
        lesson2: cafe2,
        storyTitle: '小さなカフェ',
        passage: [
          'Hana: Un café, por favor.',
          '（ハナ：コーヒーをください。）',
          'Staff: Aquí tiene.',
          '（店員：どうぞ。）',
          'Hana: Está rico. Gracias.',
          '（ハナ：おいしいです。ありがとう。）',
        ],
        storyQs: [
          target(script, coffee.ja, coffee.text, ['Agua, por favor.', 'Un billete, por favor.', 'Lo siento.'], 2),
          meaning(script, tasty, ['高いです', '冷たいです', 'ありがとう'], 1),
        ],
        review: [
          listen(script, water, ['コーヒーをください', 'メニューをください', '切符をください'], 0),
          bank(script, price.ja, ['¿Cuánto', 'es?'], ['¿Dónde', 'estación?']),
          meaning(script, menu, ['水をください', 'コーヒーをください', 'おいしいです'], 3),
        ],
      },
      {
        ...pink,
        title: '道をたずねよう',
        phrases: [station, left, right, straight, ticket],
        lesson1: way1,
        lesson2: way2,
        storyTitle: '駅までの道',
        passage: [
          'Hana: Perdón. ¿Dónde está la estación?',
          '（ハナ：すみません。駅はどこですか？）',
          'Staff: Gira a la izquierda. Sigue recto.',
          '（店員：左に曲がってください。まっすぐ行ってください。）',
          'Hana: Gracias.',
          '（ハナ：ありがとう。）',
        ],
        storyQs: [
          meaning(script, station, ['いくらですか', '左に曲がってください', '切符をください'], 0),
          target(script, left.ja, left.text, ['Gira a la derecha.', 'Sigue recto.', 'Adiós.'], 1),
        ],
        review: [
          listen(script, right, ['左に曲がってください', 'まっすぐ行ってください', '駅はどこですか'], 2),
          bank(script, straight.ja, ['Sigue', 'recto.'], ['izquierda.', 'derecha.']),
          meaning(script, ticket, ['コーヒーをください', '水をください', 'ありがとう'], 1),
        ],
      },
    ],
    {
      listen: [lesson1[2], self2[3], cafe1[2], way1[2]],
      match: [lesson2[2], self2[2], cafe2[2]],
      bank: [lesson1[1], self1[1], cafe2[1], way2[1]],
    },
  )
}

function french(): Course {
  const script = 'フランス語'
  const hello = { text: 'Bonjour.', ja: 'こんにちは' }
  const thanks = { text: 'Merci.', ja: 'ありがとう' }
  const meet = { text: 'Enchanté.', ja: 'はじめまして' }
  const bye = { text: 'Au revoir.', ja: 'さようなら' }
  const sorry = { text: 'Pardon.', ja: 'ごめんなさい' }
  const yes = { text: 'Oui.', ja: 'はい' }
  const no = { text: 'Non.', ja: 'いいえ' }
  const night = { text: 'Bonne nuit.', ja: 'おやすみなさい' }
  const hana = { text: "Je m'appelle Hana.", ja: '私はハナです' }
  const student = { text: 'Je suis étudiante.', ja: '学生です' }
  const from = { text: 'Je suis japonaise.', ja: '日本人です' }
  const nameQ = { text: "Comment tu t'appelles ?", ja: 'お名前は何ですか' }
  const ken = { text: "Je m'appelle Ken.", ja: '私の名前はケンです' }
  const coffee = { text: "Un café, s'il vous plaît.", ja: 'コーヒーをください' }
  const water = { text: "De l'eau, s'il vous plaît.", ja: '水をください' }
  const menu = { text: "La carte, s'il vous plaît.", ja: 'メニューをください' }
  const tasty = { text: "C'est délicieux.", ja: 'おいしいです' }
  const price = { text: "C'est combien ?", ja: 'いくらですか' }
  const station = { text: 'Où est la gare ?', ja: '駅はどこですか' }
  const left = { text: 'Tournez à gauche.', ja: '左に曲がってください' }
  const right = { text: 'Tournez à droite.', ja: '右に曲がってください' }
  const straight = { text: 'Allez tout droit.', ja: 'まっすぐ行ってください' }
  const ticket = { text: "Un billet, s'il vous plaît.", ja: '切符をください' }

  const lesson1 = [
    meaning(script, hello, ['さようなら', 'ありがとう', 'ごめんなさい'], 2),
    bank(script, meet.ja, ['Enchanté.'], ['Bonjour.', 'Pardon.']),
    listen(script, thanks, ['こんにちは', 'ごめんなさい', 'はい'], 0),
    blank('おやすみなさい', 'Bonne ', '.', 'nuit', ['jour', 'eau', 'gare'], 1),
  ]
  const lesson2 = [
    target(script, bye.ja, bye.text, ['Bonjour.', 'Merci.', 'Oui.'], 3),
    bank(script, sorry.ja, ['Pardon.'], ['Merci.', 'Non.']),
    match(script, [hello, thanks, yes, no]),
    meaning(script, night, ['こんにちは', 'さようなら', 'ありがとう'], 1),
  ]
  const self1 = [
    meaning(script, hana, ['私の名前はケンです', '学生です', '日本人です'], 0),
    bank(script, student.ja, ['Je', 'suis', 'étudiante.'], ['japonaise.', 'Ken.']),
    blank('日本人です', 'Je suis ', '.', 'japonaise', ['étudiante', 'Hana', 'gare'], 2),
    target(script, nameQ.ja, nameQ.text, ['Où est la gare ?', "C'est combien ?", 'Bonne nuit.'], 1),
  ]
  const self2 = [
    bank(script, ken.ja, ['Je', "m'appelle", 'Ken.'], ['Hana.', 'étudiante.']),
    meaning(script, from, ['学生です', '私はハナです', 'いくらですか'], 3),
    match(script, [hana, student, from, ken]),
    listen(script, nameQ, ['駅はどこですか', 'いくらですか', 'さようなら'], 0),
  ]
  const cafe1 = [
    target(script, coffee.ja, coffee.text, ["De l'eau, s'il vous plaît.", "Un billet, s'il vous plaît.", 'Au revoir.'], 2),
    bank(script, water.ja, ["De", "l'eau,", "s'il", 'vous', 'plaît.'], ['café,', 'carte,']),
    listen(script, menu, ['水をください', '切符をください', 'こんにちは'], 1),
    meaning(script, tasty, ['高いです', '冷たいです', '忙しいです'], 0),
  ]
  const cafe2 = [
    meaning(script, price, ['駅はどこですか', 'お名前は何ですか', 'おいしいです'], 2),
    bank(script, coffee.ja, ['Un', 'café,', "s'il", 'vous', 'plaît.'], ["l'eau,", 'billet,']),
    match(script, [coffee, water, tasty, price]),
    target(script, menu.ja, menu.text, ["Un café, s'il vous plaît.", 'Tournez à gauche.', 'Pardon.'], 0),
  ]
  const way1 = [
    meaning(script, station, ['いくらですか', 'お名前は何ですか', 'さようなら'], 1),
    bank(script, left.ja, ['Tournez', 'à', 'gauche.'], ['droite.', 'droit.']),
    listen(script, straight, ['左に曲がってください', '右に曲がってください', '切符をください'], 3),
    match(script, [station, left, right, straight]),
  ]
  const way2 = [
    target(script, right.ja, right.text, ['Tournez à gauche.', 'Allez tout droit.', 'Bonjour.'], 1),
    bank(script, ticket.ja, ['Un', 'billet,', "s'il", 'vous', 'plaît.'], ['café,', "l'eau,"]),
    listen(script, station, ['いくらですか', '私はハナです', 'ありがとう'], 0),
    meaning(script, ticket, ['コーヒーをください', '水をください', 'メニューをください'], 2),
  ]

  return buildCourse(
    {
      id: 'fr',
      label: 'フランス語',
      speechLang: 'fr-FR',
      htmlLang: 'fr',
      script,
      sample: 'Bonjour',
      sampleJa: 'こんにちは',
    },
    [
      {
        ...green,
        title: 'あいさつをしよう',
        phrases: [hello, thanks, meet, bye, sorry, yes, no, night],
        lesson1,
        lesson2,
        storyTitle: '朝の駅',
        passage: [
          'Hana: Bonjour !',
          '（ハナ：こんにちは！）',
          'Ken: Bonjour. Enchanté.',
          '（ケン：こんにちは。はじめまして。）',
          'Hana: Enchanté.',
          '（ハナ：はじめまして。）',
        ],
        storyQs: [
          target(script, 'ケンの最初のあいさつ', 'Bonjour.', ['Au revoir.', 'Pardon.', 'Bonne nuit.'], 0),
          meaning(script, meet, ['さようなら', 'おやすみなさい', 'ごめんなさい'], 2),
        ],
        review: [
          listen(script, bye, ['こんにちは', 'ありがとう', 'はい'], 1),
          bank(script, thanks.ja, ['Merci.'], ['Bonjour.', 'Non.']),
          meaning(script, sorry, ['ありがとう', 'はい', 'いいえ'], 0),
        ],
      },
      {
        ...purple,
        title: '自分のことを話そう',
        phrases: [hana, student, from, nameQ, ken],
        lesson1: self1,
        lesson2: self2,
        storyTitle: 'はじめての会話',
        passage: [
          "Hana: Bonjour. Je m'appelle Hana.",
          '（ハナ：こんにちは。私はハナです。）',
          'Hana: Je suis japonaise. Je suis étudiante.',
          '（ハナ：日本人です。学生です。）',
          "Ken: Enchanté. Je m'appelle Ken.",
          '（ケン：はじめまして。私の名前はケンです。）',
        ],
        storyQs: [
          meaning(script, hana, ['私の名前はケンです', '学生です', '日本人です'], 1),
          target(script, student.ja, student.text, ["Je m'appelle Hana.", 'Je suis japonaise.', 'Bonne nuit.'], 3),
        ],
        review: [
          listen(script, ken, ['私はハナです', '学生です', 'おやすみなさい'], 2),
          bank(script, from.ja, ['Je', 'suis', 'japonaise.'], ['étudiante.', 'Ken.']),
          match(script, [nameQ, hana, student, from]),
        ],
      },
      {
        ...blue,
        title: 'カフェで注文しよう',
        phrases: [coffee, water, menu, tasty, price],
        lesson1: cafe1,
        lesson2: cafe2,
        storyTitle: '小さなカフェ',
        passage: [
          "Hana: Un café, s'il vous plaît.",
          '（ハナ：コーヒーをください。）',
          'Staff: Voilà.',
          '（店員：どうぞ。）',
          "Hana: C'est délicieux. Merci.",
          '（ハナ：おいしいです。ありがとう。）',
        ],
        storyQs: [
          target(script, coffee.ja, coffee.text, ["De l'eau, s'il vous plaît.", "Un billet, s'il vous plaît.", 'Pardon.'], 0),
          meaning(script, tasty, ['高いです', '冷たいです', 'ありがとう'], 3),
        ],
        review: [
          listen(script, water, ['コーヒーをください', 'メニューをください', '切符をください'], 1),
          bank(script, price.ja, ["C'est", 'combien', '?'], ['Où', 'est', 'gare']),
          meaning(script, menu, ['水をください', 'コーヒーをください', 'おいしいです'], 2),
        ],
      },
      {
        ...pink,
        title: '道をたずねよう',
        phrases: [station, left, right, straight, ticket],
        lesson1: way1,
        lesson2: way2,
        storyTitle: '駅までの道',
        passage: [
          'Hana: Pardon. Où est la gare ?',
          '（ハナ：すみません。駅はどこですか？）',
          'Staff: Tournez à gauche. Allez tout droit.',
          '（店員：左に曲がってください。まっすぐ行ってください。）',
          'Hana: Merci.',
          '（ハナ：ありがとう。）',
        ],
        storyQs: [
          meaning(script, station, ['いくらですか', '左に曲がってください', '切符をください'], 1),
          target(script, left.ja, left.text, ['Tournez à droite.', 'Allez tout droit.', 'Au revoir.'], 2),
        ],
        review: [
          listen(script, right, ['左に曲がってください', 'まっすぐ行ってください', '駅はどこですか'], 0),
          bank(script, straight.ja, ['Allez', 'tout', 'droit.'], ['gauche.', 'droite.']),
          meaning(script, ticket, ['コーヒーをください', '水をください', 'ありがとう'], 3),
        ],
      },
    ],
    {
      listen: [lesson1[2], self2[3], cafe1[2], way1[2]],
      match: [lesson2[2], self2[2], cafe2[2]],
      bank: [lesson1[1], self1[1], cafe2[1], way2[1]],
    },
  )
}

function chinese(): Course {
  const script = '中国語'
  const hello = { text: '你好。', ja: 'こんにちは' }
  const thanks = { text: '谢谢。', ja: 'ありがとう' }
  const meet = { text: '很高兴认识你。', ja: 'はじめまして' }
  const bye = { text: '再见。', ja: 'さようなら' }
  const sorry = { text: '对不起。', ja: 'ごめんなさい' }
  const yes = { text: '是。', ja: 'はい' }
  const no = { text: '不是。', ja: 'いいえ' }
  const night = { text: '晚安。', ja: 'おやすみなさい' }
  const hana = { text: '我是哈娜。', ja: '私はハナです' }
  const student = { text: '我是学生。', ja: '学生です' }
  const from = { text: '我是日本人。', ja: '日本人です' }
  const nameQ = { text: '你叫什么名字？', ja: 'お名前は何ですか' }
  const ken = { text: '我叫肯。', ja: '私の名前はケンです' }
  const coffee = { text: '请给我咖啡。', ja: 'コーヒーをください' }
  const water = { text: '请给我水。', ja: '水をください' }
  const menu = { text: '请给我菜单。', ja: 'メニューをください' }
  const tasty = { text: '很好吃。', ja: 'おいしいです' }
  const price = { text: '这个多少钱？', ja: 'これはいくらですか' }
  const station = { text: '车站在哪里？', ja: '駅はどこですか' }
  const left = { text: '向左拐。', ja: '左に曲がってください' }
  const right = { text: '向右拐。', ja: '右に曲がってください' }
  const straight = { text: '一直走。', ja: 'まっすぐ行ってください' }
  const ticket = { text: '请给我车票。', ja: '切符をください' }

  const lesson1 = [
    meaning(script, hello, ['さようなら', 'ありがとう', 'ごめんなさい'], 1),
    bank(script, meet.ja, ['很高兴', '认识你。'], ['再见。', '谢谢。']),
    listen(script, thanks, ['こんにちは', 'ごめんなさい', 'はい'], 3),
    blank('さようなら', '', '。', '再见', ['你好', '谢谢', '是'], 0),
  ]
  const lesson2 = [
    target(script, bye.ja, bye.text, ['你好。', '谢谢。', '是。'], 2),
    bank(script, night.ja, ['晚安。'], ['你好。', '不是。']),
    match(script, [hello, thanks, yes, no]),
    meaning(script, sorry, ['ありがとう', 'こんにちは', 'はい'], 1),
  ]
  const self1 = [
    meaning(script, hana, ['私の名前はケンです', '学生です', '日本人です'], 0),
    bank(script, student.ja, ['我是', '学生。'], ['日本人。', '肯。']),
    blank('日本人です', '我是', '。', '日本人', ['学生', '哈娜', '水'], 2),
    target(script, nameQ.ja, nameQ.text, ['车站在哪里？', '这个多少钱？', '晚安。'], 1),
  ]
  const self2 = [
    bank(script, ken.ja, ['我叫', '肯。'], ['哈娜。', '学生。']),
    meaning(script, from, ['学生です', '私はハナです', 'いくらですか'], 3),
    match(script, [hana, student, from, ken]),
    listen(script, nameQ, ['駅はどこですか', 'これはいくらですか', 'さようなら'], 0),
  ]
  const cafe1 = [
    target(script, coffee.ja, coffee.text, ['请给我水。', '请给我车票。', '再见。'], 1),
    bank(script, water.ja, ['请给我', '水。'], ['咖啡。', '菜单。']),
    listen(script, menu, ['水をください', '切符をください', 'こんにちは'], 2),
    meaning(script, tasty, ['高いです', '冷たいです', '忙しいです'], 0),
  ]
  const cafe2 = [
    meaning(script, price, ['駅はどこですか', 'お名前は何ですか', 'おいしいです'], 3),
    bank(script, coffee.ja, ['请给我', '咖啡。'], ['水。', '车票。']),
    match(script, [coffee, water, tasty, price]),
    target(script, menu.ja, menu.text, ['请给我咖啡。', '向左拐。', '对不起。'], 2),
  ]
  const way1 = [
    meaning(script, station, ['これはいくらですか', 'お名前は何ですか', 'さようなら'], 1),
    bank(script, left.ja, ['向左', '拐。'], ['向右', '一直']),
    listen(script, straight, ['左に曲がってください', '右に曲がってください', '切符をください'], 0),
    match(script, [station, left, right, straight]),
  ]
  const way2 = [
    target(script, right.ja, right.text, ['向左拐。', '一直走。', '你好。'], 3),
    bank(script, ticket.ja, ['请给我', '车票。'], ['咖啡。', '水。']),
    listen(script, station, ['これはいくらですか', '私はハナです', 'ありがとう'], 2),
    meaning(script, ticket, ['コーヒーをください', '水をください', 'メニューをください'], 1),
  ]

  return buildCourse(
    {
      id: 'zh',
      label: '中国語',
      speechLang: 'zh-CN',
      htmlLang: 'zh',
      script,
      sample: '你好',
      sampleJa: 'こんにちは',
    },
    [
      {
        ...green,
        title: 'あいさつをしよう',
        phrases: [hello, thanks, meet, bye, sorry, yes, no, night],
        lesson1,
        lesson2,
        storyTitle: '朝の駅',
        passage: [
          '哈娜：你好！',
          '（ハナ：こんにちは！）',
          '肯：你好。很高兴认识你。',
          '（ケン：こんにちは。はじめまして。）',
          '哈娜：很高兴认识你。',
          '（ハナ：はじめまして。）',
        ],
        storyQs: [
          target(script, 'ケンの最初のあいさつ', '你好。', ['再见。', '对不起。', '晚安。'], 1),
          meaning(script, meet, ['さようなら', 'おやすみなさい', 'ごめんなさい'], 0),
        ],
        review: [
          listen(script, bye, ['こんにちは', 'ありがとう', 'はい'], 2),
          bank(script, thanks.ja, ['谢谢。'], ['你好。', '再见。']),
          meaning(script, sorry, ['ありがとう', 'はい', 'いいえ'], 3),
        ],
      },
      {
        ...purple,
        title: '自分のことを話そう',
        phrases: [hana, student, from, nameQ, ken],
        lesson1: self1,
        lesson2: self2,
        storyTitle: 'はじめての会話',
        passage: [
          '哈娜：你好。我是哈娜。',
          '（ハナ：こんにちは。私はハナです。）',
          '哈娜：我是日本人。我是学生。',
          '（ハナ：日本人です。学生です。）',
          '肯：很高兴认识你。我叫肯。',
          '（ケン：はじめまして。私の名前はケンです。）',
        ],
        storyQs: [
          meaning(script, hana, ['私の名前はケンです', '学生です', '日本人です'], 2),
          target(script, student.ja, student.text, ['我是哈娜。', '我是日本人。', '晚安。'], 0),
        ],
        review: [
          listen(script, ken, ['私はハナです', '学生です', 'おやすみなさい'], 1),
          bank(script, from.ja, ['我是', '日本人。'], ['学生。', '肯。']),
          match(script, [nameQ, hana, student, from]),
        ],
      },
      {
        ...blue,
        title: 'カフェで注文しよう',
        phrases: [coffee, water, menu, tasty, price],
        lesson1: cafe1,
        lesson2: cafe2,
        storyTitle: '小さなカフェ',
        passage: [
          '哈娜：请给我咖啡。',
          '（ハナ：コーヒーをください。）',
          '店员：好的，给你。',
          '（店員：はい、どうぞ。）',
          '哈娜：很好吃。谢谢。',
          '（ハナ：おいしいです。ありがとう。）',
        ],
        storyQs: [
          target(script, coffee.ja, coffee.text, ['请给我水。', '请给我车票。', '对不起。'], 3),
          meaning(script, tasty, ['高いです', '冷たいです', 'ありがとう'], 1),
        ],
        review: [
          listen(script, water, ['コーヒーをください', 'メニューをください', '切符をください'], 0),
          bank(script, price.ja, ['这个', '多少钱？'], ['车站', '在哪里？']),
          meaning(script, menu, ['水をください', 'コーヒーをください', 'おいしいです'], 2),
        ],
      },
      {
        ...pink,
        title: '道をたずねよう',
        phrases: [station, left, right, straight, ticket],
        lesson1: way1,
        lesson2: way2,
        storyTitle: '駅までの道',
        passage: [
          '哈娜：请问，车站在哪里？',
          '（ハナ：すみません。駅はどこですか？）',
          '店员：向左拐。一直走。',
          '（店員：左に曲がってください。まっすぐ行ってください。）',
          '哈娜：谢谢。',
          '（ハナ：ありがとう。）',
        ],
        storyQs: [
          meaning(script, station, ['これはいくらですか', '左に曲がってください', '切符をください'], 0),
          target(script, left.ja, left.text, ['向右拐。', '一直走。', '再见。'], 2),
        ],
        review: [
          listen(script, right, ['左に曲がってください', 'まっすぐ行ってください', '駅はどこですか'], 3),
          bank(script, straight.ja, ['一直', '走。'], ['向左', '向右']),
          meaning(script, ticket, ['コーヒーをください', '水をください', 'ありがとう'], 1),
        ],
      },
    ],
    {
      listen: [lesson1[2], self2[3], cafe1[2], way1[2]],
      match: [lesson2[2], self2[2], cafe2[2]],
      bank: [lesson1[1], self1[1], cafe2[1], way2[1]],
    },
  )
}

function german(): Course {
  const script = 'ドイツ語'
  const hello = { text: 'Hallo.', ja: 'こんにちは' }
  const thanks = { text: 'Danke.', ja: 'ありがとう' }
  const meet = { text: 'Freut mich.', ja: 'はじめまして' }
  const bye = { text: 'Tschüss.', ja: 'さようなら' }
  const sorry = { text: 'Entschuldigung.', ja: 'ごめんなさい' }
  const yes = { text: 'Ja.', ja: 'はい' }
  const no = { text: 'Nein.', ja: 'いいえ' }
  const night = { text: 'Gute Nacht.', ja: 'おやすみなさい' }
  const hana = { text: 'Ich bin Hana.', ja: '私はハナです' }
  const student = { text: 'Ich bin Studentin.', ja: '学生です' }
  const from = { text: 'Ich komme aus Japan.', ja: '日本出身です' }
  const nameQ = { text: 'Wie heißt du?', ja: 'お名前は何ですか' }
  const ken = { text: 'Ich heiße Ken.', ja: '私の名前はケンです' }
  const coffee = { text: 'Einen Kaffee, bitte.', ja: 'コーヒーをください' }
  const water = { text: 'Wasser, bitte.', ja: '水をください' }
  const menu = { text: 'Die Karte, bitte.', ja: 'メニューをください' }
  const tasty = { text: 'Das ist lecker.', ja: 'おいしいです' }
  const price = { text: 'Wie viel kostet das?', ja: 'これはいくらですか' }
  const station = { text: 'Wo ist der Bahnhof?', ja: '駅はどこですか' }
  const left = { text: 'Links abbiegen.', ja: '左に曲がってください' }
  const right = { text: 'Rechts abbiegen.', ja: '右に曲がってください' }
  const straight = { text: 'Geradeaus gehen.', ja: 'まっすぐ行ってください' }
  const ticket = { text: 'Eine Fahrkarte, bitte.', ja: '切符をください' }

  const lesson1 = [
    meaning(script, hello, ['さようなら', 'ありがとう', 'ごめんなさい'], 0),
    bank(script, meet.ja, ['Freut', 'mich.'], ['Tschüss.', 'Danke.']),
    listen(script, thanks, ['こんにちは', 'ごめんなさい', 'はい'], 2),
    blank('おやすみなさい', 'Gute ', '.', 'Nacht', ['Hallo', 'Ja', 'Nein'], 1),
  ]
  const lesson2 = [
    target(script, bye.ja, bye.text, ['Hallo.', 'Danke.', 'Ja.'], 3),
    bank(script, sorry.ja, ['Entschuldigung.'], ['Danke.', 'Nein.']),
    match(script, [hello, thanks, yes, no]),
    meaning(script, night, ['こんにちは', 'さようなら', 'ありがとう'], 0),
  ]
  const self1 = [
    meaning(script, hana, ['私の名前はケンです', '学生です', '日本出身です'], 2),
    bank(script, student.ja, ['Ich', 'bin', 'Studentin.'], ['Hana.', 'Ken.']),
    blank('日本出身です', 'Ich komme aus ', '.', 'Japan', ['Hana', 'Ken', 'Wasser'], 0),
    target(script, nameQ.ja, nameQ.text, ['Wo ist der Bahnhof?', 'Wie viel kostet das?', 'Gute Nacht.'], 1),
  ]
  const self2 = [
    bank(script, ken.ja, ['Ich', 'heiße', 'Ken.'], ['Hana.', 'Studentin.']),
    meaning(script, from, ['学生です', '私はハナです', 'いくらですか'], 3),
    match(script, [hana, student, from, ken]),
    listen(script, nameQ, ['駅はどこですか', 'これはいくらですか', 'さようなら'], 2),
  ]
  const cafe1 = [
    target(script, coffee.ja, coffee.text, ['Wasser, bitte.', 'Eine Fahrkarte, bitte.', 'Tschüss.'], 0),
    bank(script, water.ja, ['Wasser,', 'bitte.'], ['Kaffee,', 'Karte,']),
    listen(script, menu, ['水をください', '切符をください', 'こんにちは'], 1),
    meaning(script, tasty, ['高いです', '冷たいです', '忙しいです'], 3),
  ]
  const cafe2 = [
    meaning(script, price, ['駅はどこですか', 'お名前は何ですか', 'おいしいです'], 1),
    bank(script, coffee.ja, ['Einen', 'Kaffee,', 'bitte.'], ['Wasser,', 'Fahrkarte,']),
    match(script, [coffee, water, tasty, price]),
    target(script, menu.ja, menu.text, ['Einen Kaffee, bitte.', 'Links abbiegen.', 'Entschuldigung.'], 2),
  ]
  const way1 = [
    meaning(script, station, ['これはいくらですか', 'お名前は何ですか', 'さようなら'], 0),
    bank(script, left.ja, ['Links', 'abbiegen.'], ['Rechts', 'Geradeaus']),
    listen(script, straight, ['左に曲がってください', '右に曲がってください', '切符をください'], 2),
    match(script, [station, left, right, straight]),
  ]
  const way2 = [
    target(script, right.ja, right.text, ['Links abbiegen.', 'Geradeaus gehen.', 'Hallo.'], 1),
    bank(script, ticket.ja, ['Eine', 'Fahrkarte,', 'bitte.'], ['Kaffee,', 'Wasser,']),
    listen(script, station, ['これはいくらですか', '私はハナです', 'ありがとう'], 3),
    meaning(script, ticket, ['コーヒーをください', '水をください', 'メニューをください'], 0),
  ]

  return buildCourse(
    {
      id: 'de',
      label: 'ドイツ語',
      speechLang: 'de-DE',
      htmlLang: 'de',
      script,
      sample: 'Hallo',
      sampleJa: 'こんにちは',
    },
    [
      {
        ...green,
        title: 'あいさつをしよう',
        phrases: [hello, thanks, meet, bye, sorry, yes, no, night],
        lesson1,
        lesson2,
        storyTitle: '朝の駅',
        passage: [
          'Hana: Hallo!',
          '（ハナ：こんにちは！）',
          'Ken: Hallo. Freut mich.',
          '（ケン：こんにちは。はじめまして。）',
          'Hana: Freut mich.',
          '（ハナ：はじめまして。）',
        ],
        storyQs: [
          target(script, 'ケンの最初のあいさつ', 'Hallo.', ['Tschüss.', 'Entschuldigung.', 'Gute Nacht.'], 2),
          meaning(script, meet, ['さようなら', 'おやすみなさい', 'ごめんなさい'], 1),
        ],
        review: [
          listen(script, bye, ['こんにちは', 'ありがとう', 'はい'], 0),
          bank(script, thanks.ja, ['Danke.'], ['Hallo.', 'Nein.']),
          meaning(script, sorry, ['ありがとう', 'はい', 'いいえ'], 3),
        ],
      },
      {
        ...purple,
        title: '自分のことを話そう',
        phrases: [hana, student, from, nameQ, ken],
        lesson1: self1,
        lesson2: self2,
        storyTitle: 'はじめての会話',
        passage: [
          'Hana: Hallo. Ich bin Hana.',
          '（ハナ：こんにちは。私はハナです。）',
          'Hana: Ich komme aus Japan. Ich bin Studentin.',
          '（ハナ：日本出身です。学生です。）',
          'Ken: Freut mich. Ich heiße Ken.',
          '（ケン：はじめまして。私の名前はケンです。）',
        ],
        storyQs: [
          meaning(script, hana, ['私の名前はケンです', '学生です', '日本出身です'], 0),
          target(script, student.ja, student.text, ['Ich bin Hana.', 'Ich komme aus Japan.', 'Gute Nacht.'], 1),
        ],
        review: [
          listen(script, ken, ['私はハナです', '学生です', 'おやすみなさい'], 3),
          bank(script, from.ja, ['Ich', 'komme', 'aus', 'Japan.'], ['Studentin.', 'Ken.']),
          match(script, [nameQ, hana, student, from]),
        ],
      },
      {
        ...blue,
        title: 'カフェで注文しよう',
        phrases: [coffee, water, menu, tasty, price],
        lesson1: cafe1,
        lesson2: cafe2,
        storyTitle: '小さなカフェ',
        passage: [
          'Hana: Einen Kaffee, bitte.',
          '（ハナ：コーヒーをください。）',
          'Staff: Bitte schön.',
          '（店員：どうぞ。）',
          'Hana: Das ist lecker. Danke.',
          '（ハナ：おいしいです。ありがとう。）',
        ],
        storyQs: [
          target(script, coffee.ja, coffee.text, ['Wasser, bitte.', 'Eine Fahrkarte, bitte.', 'Entschuldigung.'], 2),
          meaning(script, tasty, ['高いです', '冷たいです', 'ありがとう'], 0),
        ],
        review: [
          listen(script, water, ['コーヒーをください', 'メニューをください', '切符をください'], 1),
          bank(script, price.ja, ['Wie', 'viel', 'kostet', 'das?'], ['Wo', 'Bahnhof?']),
          meaning(script, menu, ['水をください', 'コーヒーをください', 'おいしいです'], 3),
        ],
      },
      {
        ...pink,
        title: '道をたずねよう',
        phrases: [station, left, right, straight, ticket],
        lesson1: way1,
        lesson2: way2,
        storyTitle: '駅までの道',
        passage: [
          'Hana: Entschuldigung. Wo ist der Bahnhof?',
          '（ハナ：すみません。駅はどこですか？）',
          'Staff: Links abbiegen. Geradeaus gehen.',
          '（店員：左に曲がってください。まっすぐ行ってください。）',
          'Hana: Danke.',
          '（ハナ：ありがとう。）',
        ],
        storyQs: [
          meaning(script, station, ['これはいくらですか', '左に曲がってください', '切符をください'], 1),
          target(script, left.ja, left.text, ['Rechts abbiegen.', 'Geradeaus gehen.', 'Tschüss.'], 0),
        ],
        review: [
          listen(script, right, ['左に曲がってください', 'まっすぐ行ってください', '駅はどこですか'], 2),
          bank(script, straight.ja, ['Geradeaus', 'gehen.'], ['Links', 'Rechts']),
          meaning(script, ticket, ['コーヒーをください', '水をください', 'ありがとう'], 3),
        ],
      },
    ],
    {
      listen: [lesson1[2], self2[3], cafe1[2], way1[2]],
      match: [lesson2[2], self2[2], cafe2[2]],
      bank: [lesson1[1], self1[1], cafe2[1], way2[1]],
    },
  )
}

export const extraCourses: Course[] = [english(), spanish(), french(), chinese(), german()]
