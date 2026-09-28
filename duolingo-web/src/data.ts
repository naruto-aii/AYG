import type { LessonNode, Question, Rival, Section } from './types'

const greetBasic: Question[] = [
  {
    type: 'choice',
    prompt: 'このハングルの意味を選んでください',
    sentence: '안녕하세요.',
    choices: ['こんにちは', 'さようなら', 'ありがとう', 'ごめんなさい'],
    answer: 0,
  },
  {
    type: 'bank',
    prompt: '日本語にあうハングルを作ってください',
    sentence: 'はじめまして',
    answer: ['만나서', '반갑습니다.'],
    extra: ['감사합니다.', '안녕히'],
  },
  {
    type: 'listen',
    prompt: '聞こえたハングルの意味を選んでください',
    speak: '감사합니다.',
    choices: ['ありがとう', 'こんにちは', 'ごめんなさい', 'はい'],
    answer: 0,
  },
  {
    type: 'blank',
    prompt: '「こんにちは」になるように選んでください',
    before: '안녕',
    after: '.',
    choices: ['하세요', '가세요', '계세요', '드세요'],
    answer: 0,
  },
]

const greetLeave: Question[] = [
  {
    type: 'choice',
    prompt: 'このハングルの意味を選んでください',
    sentence: '안녕히 가세요.',
    choices: ['行ってらっしゃい', 'こんにちは', 'おやすみ', 'ごめんなさい'],
    answer: 0,
  },
  {
    type: 'bank',
    prompt: '日本語にあうハングルを作ってください',
    sentence: '行ってらっしゃい',
    answer: ['안녕히', '가세요.'],
    extra: ['계세요.', '감사합니다.'],
  },
  {
    type: 'choice',
    prompt: '日本語にあうハングルを選んでください',
    sentence: 'はい',
    choices: ['네', '아니요', '물', '집'],
    answer: 0,
  },
  {
    type: 'match',
    prompt: 'ハングルと日本語のペアを選んでください',
    pairs: [
      ['안녕하세요', 'こんにちは'],
      ['감사합니다', 'ありがとう'],
      ['네', 'はい'],
      ['아니요', 'いいえ'],
    ],
  },
]

const greetPolite: Question[] = [
  {
    type: 'choice',
    prompt: 'このハングルの意味を選んでください',
    sentence: '만나서 반갑습니다.',
    choices: ['はじめまして', 'お疲れ様', 'いただきます', 'ただいま'],
    answer: 0,
  },
  {
    type: 'bank',
    prompt: '日本語にあうハングルを作ってください',
    sentence: 'お先に失礼します（自分が去るとき）',
    answer: ['안녕히', '계세요.'],
    extra: ['가세요.', '안녕하세요.'],
  },
  {
    type: 'listen',
    prompt: '聞こえたハングルの意味を選んでください',
    speak: '안녕하세요.',
    choices: ['こんにちは', 'さようなら', 'おやすみ', 'ありがとう'],
    answer: 0,
  },
  {
    type: 'blank',
    prompt: '「いいえ」になる語を選んでください',
    before: '',
    after: '',
    choices: ['아니요', '네', '물', '밥'],
    answer: 0,
  },
]

const storyMorning: Question[] = [
  {
    type: 'choice',
    prompt: 'ケンの最初のあいさつはどれですか',
    choices: ['안녕하세요', '안녕히 가세요', '감사합니다', '죄송합니다'],
    answer: 0,
  },
  {
    type: 'choice',
    prompt: '「はじめまして」にあたるハングルはどれですか',
    choices: ['만나서 반갑습니다', '잘 자요', '맛있어요', '얼마예요'],
    answer: 0,
  },
  {
    type: 'bank',
    prompt: 'ハナの返事「はい、はじめまして」を作ってください',
    sentence: '네, 반갑습니다',
    answer: ['네,', '반갑습니다.'],
    extra: ['아니요,'],
  },
]

const review1: Question[] = [
  {
    type: 'choice',
    prompt: 'このハングルの意味を選んでください',
    sentence: '감사합니다.',
    choices: ['ありがとう', 'こんにちは', 'お願い', 'いいえ'],
    answer: 0,
  },
  {
    type: 'match',
    prompt: 'ハングルと日本語のペアを選んでください',
    pairs: [
      ['안녕히 가세요', '行ってらっしゃい'],
      ['안녕히 계세요', 'お先に失礼します'],
      ['안녕하세요', 'こんにちは'],
      ['죄송합니다', 'ごめんなさい'],
    ],
  },
  {
    type: 'listen',
    prompt: '聞こえたハングルの意味を選んでください',
    speak: '만나서 반갑습니다.',
    choices: ['はじめまして', 'こんにちは', 'さようなら', 'ありがとう'],
    answer: 0,
  },
  {
    type: 'blank',
    prompt: '「ありがとう」になるように選んでください',
    before: '감사',
    after: '.',
    choices: ['합니다', '하세요', '이에요', '예요'],
    answer: 0,
  },
]

const nameLesson: Question[] = [
  {
    type: 'choice',
    prompt: 'このハングルの意味を選んでください',
    sentence: '저는 하나예요.',
    choices: ['私はハナです', 'ハナは学生です', 'ハナはここにいます', 'ハナが好きです'],
    answer: 0,
  },
  {
    type: 'bank',
    prompt: '日本語にあうハングルを作ってください',
    sentence: '私は学生です',
    answer: ['저는', '학생이에요.'],
    extra: ['선생님이에요.', '물이에요.'],
  },
  {
    type: 'blank',
    prompt: '「日本人です」になるように選んでください',
    before: '일본 ',
    after: '.',
    choices: ['사람이에요', '학생이에요', '물이에요', '집이에요'],
    answer: 0,
  },
  {
    type: 'choice',
    prompt: '日本語にあうハングルを選んでください',
    sentence: 'お名前は何ですか',
    choices: ['이름이 뭐예요?', '어디예요?', '얼마예요?', '누구예요?'],
    answer: 0,
  },
]

const origin: Question[] = [
  {
    type: 'bank',
    prompt: '日本語にあうハングルを作ってください',
    sentence: '私は日本人です',
    answer: ['저는', '일본', '사람이에요.'],
    extra: ['학생이에요.'],
  },
  {
    type: 'choice',
    prompt: 'このハングルの意味を選んでください',
    sentence: '학생이에요.',
    choices: ['学生です', '先生です', 'ここにいます', '眠いです'],
    answer: 0,
  },
  {
    type: 'match',
    prompt: 'ハングルと日本語のペアを選んでください',
    pairs: [
      ['이름', '名前'],
      ['학생', '学生'],
      ['일본', '日本'],
      ['저', '私'],
    ],
  },
  {
    type: 'listen',
    prompt: '聞こえたハングルの意味を選んでください',
    speak: '제 이름은 켄이에요.',
    choices: ['私の名前はケンです', 'ケンは友達です', 'ケンへ行きます', 'ケンがいます'],
    answer: 0,
  },
]

const storyIntro: Question[] = [
  {
    type: 'choice',
    prompt: '話し手の名前はどれですか',
    choices: ['하나', '켄', '미오', '레오'],
    answer: 0,
  },
  {
    type: 'choice',
    prompt: '「学生です」にあたるハングルはどれですか',
    choices: ['학생이에요', '선생님이에요', '의사예요', '요리사예요'],
    answer: 0,
  },
  {
    type: 'bank',
    prompt: '自己紹介の文を作ってください',
    sentence: '私の名前はハナです',
    answer: ['제', '이름은', '하나예요.'],
    extra: ['켄이에요.'],
  },
]

const review2: Question[] = [
  {
    type: 'blank',
    prompt: '「私はハナです」になるように選んでください',
    before: '저는 ',
    after: '.',
    choices: ['하나예요', '하나이에요', '물이에요', '집이에요'],
    answer: 0,
  },
  {
    type: 'choice',
    prompt: 'このハングルの意味を選んでください',
    sentence: '저는 일본 사람이에요.',
    choices: ['私は日本人です', '私は日本へ行きます', '日本が好きです', '日本は大きいです'],
    answer: 0,
  },
  {
    type: 'listen',
    prompt: '聞こえたハングルの意味を選んでください',
    speak: '학생이에요.',
    choices: ['学生です', '先生です', '眠いです', '忙しいです'],
    answer: 0,
  },
]

const order: Question[] = [
  {
    type: 'choice',
    prompt: 'このハングルの意味を選んでください',
    sentence: '커피 주세요.',
    choices: ['☕ コーヒーをください', '💧 水をください', '🍞 パンをください', '🍎 りんごをください'],
    answer: 0,
  },
  {
    type: 'bank',
    prompt: '日本語にあうハングルを作ってください',
    sentence: '水をください',
    answer: ['물', '주세요.'],
    extra: ['커피', '메뉴'],
  },
  {
    type: 'choice',
    prompt: '日本語にあうハングルを選んでください',
    sentence: 'メニューをください',
    choices: ['메뉴 주세요', '계산해 주세요', '자리 있어요?', '포장해 주세요'],
    answer: 0,
  },
  {
    type: 'listen',
    prompt: '聞こえたハングルの意味を選んでください',
    speak: '커피 주세요.',
    choices: ['コーヒーをください', '水をください', 'お茶をください', '牛乳をください'],
    answer: 0,
  },
]

const taste: Question[] = [
  {
    type: 'choice',
    prompt: 'このハングルの意味を選んでください',
    sentence: '맛있어요.',
    choices: ['おいしいです', '高いです', '冷たいです', '大きいです'],
    answer: 0,
  },
  {
    type: 'blank',
    prompt: '「お茶をください」になるように選んでください',
    before: '차 ',
    after: '.',
    choices: ['주세요', '있어요', '없어요', '예요'],
    answer: 0,
  },
  {
    type: 'match',
    prompt: 'ハングルと日本語のペアを選んでください',
    pairs: [
      ['커피', 'コーヒー'],
      ['물', '水'],
      ['주세요', 'ください'],
      ['메뉴', 'メニュー'],
    ],
  },
  {
    type: 'bank',
    prompt: '日本語にあうハングルを作ってください',
    sentence: 'これはおいしいです',
    answer: ['이거', '맛있어요.'],
    extra: ['물이에요.'],
  },
]

const storyCafe: Question[] = [
  {
    type: 'choice',
    prompt: '客が最初に頼んだものはどれですか',
    choices: ['커피', '물', '차', '우유'],
    answer: 0,
  },
  {
    type: 'bank',
    prompt: '注文の文を作ってください',
    sentence: 'コーヒーをください',
    answer: ['커피', '주세요.'],
    extra: ['안녕하세요'],
  },
]

const review3: Question[] = [
  {
    type: 'listen',
    prompt: '聞こえたハングルの意味を選んでください',
    speak: '물 주세요.',
    choices: ['水をください', 'メニューをください', 'ありがとう', 'さようなら'],
    answer: 0,
  },
  {
    type: 'choice',
    prompt: 'このハングルの意味を選んでください',
    sentence: '맛있어요.',
    choices: ['おいしいです', 'からいです', '新しいです', '私のです'],
    answer: 0,
  },
  {
    type: 'blank',
    prompt: '「コーヒーをください」になるように選んでください',
    before: '커피 ',
    after: '.',
    choices: ['주세요', '안녕하세요', '잘 자요', '이름'],
    answer: 0,
  },
]

const where: Question[] = [
  {
    type: 'choice',
    prompt: 'このハングルの意味を選んでください',
    sentence: '역이 어디예요?',
    choices: ['駅はどこですか', '駅まで歩きます', '駅で降ります', '駅は新しいです'],
    answer: 0,
  },
  {
    type: 'bank',
    prompt: '日本語にあうハングルを作ってください',
    sentence: '右に行ってください',
    answer: ['오른쪽으로', '가세요.'],
    extra: ['왼쪽으로', '곧장'],
  },
  {
    type: 'listen',
    prompt: '聞こえたハングルの意味を選んでください',
    speak: '왼쪽으로 가세요.',
    choices: ['左に行ってください', '右に行ってください', 'まっすぐです', '止まってください'],
    answer: 0,
  },
  {
    type: 'match',
    prompt: 'ハングルと日本語のペアを選んでください',
    pairs: [
      ['역', '駅'],
      ['왼쪽', '左'],
      ['오른쪽', '右'],
      ['어디', 'どこ'],
    ],
  },
]

const ticket: Question[] = [
  {
    type: 'choice',
    prompt: 'このハングルの意味を選んでください',
    sentence: '서울행 표 주세요.',
    choices: ['ソウル行きの切符をください', 'ソウルに住んでいます', 'ソウルが好きです', 'ソウルは遠いです'],
    answer: 0,
  },
  {
    type: 'blank',
    prompt: '「いくらですか」になるように選んでください',
    before: '얼마',
    after: '?',
    choices: ['예요', '이에요', '하세요', '주세요'],
    answer: 0,
  },
  {
    type: 'bank',
    prompt: '日本語にあうハングルを作ってください',
    sentence: 'これはいくらですか',
    answer: ['이거', '얼마예요?'],
    extra: ['어디예요?', '주세요.'],
  },
  {
    type: 'choice',
    prompt: '日本語にあうハングルを選んでください',
    sentence: 'まっすぐ行ってください',
    choices: ['곧장 가세요', '돌아가세요', '뛰세요', '앉으세요'],
    answer: 0,
  },
]

const storyStreet: Question[] = [
  {
    type: 'choice',
    prompt: '人は何を探していますか',
    choices: ['역', '카페', '학교', '공원'],
    answer: 0,
  },
  {
    type: 'choice',
    prompt: '案内はどちらへ行きますか',
    choices: ['왼쪽', '오른쪽', '뒤', '위'],
    answer: 0,
  },
]

const review4: Question[] = [
  {
    type: 'listen',
    prompt: '聞こえたハングルの意味を選んでください',
    speak: '역이 어디예요?',
    choices: ['駅はどこですか', '切符をください', 'いくらですか', 'こんにちは'],
    answer: 0,
  },
  {
    type: 'bank',
    prompt: '日本語にあうハングルを作ってください',
    sentence: '左に行ってください',
    answer: ['왼쪽으로', '가세요.'],
    extra: ['오른쪽으로', '집'],
  },
  {
    type: 'blank',
    prompt: '「ソウル行きの切符」になるように選んでください',
    before: '서울',
    after: ' 표',
    choices: ['행', '역', '물', '집'],
    answer: 0,
  },
]

const routine: Question[] = [
  {
    type: 'choice',
    prompt: 'このハングルの意味を選んでください',
    sentence: '일곱 시에 일어나요.',
    choices: ['7時に起きます', '7時に寝ます', '7時に食べます', '7時に着きます'],
    answer: 0,
  },
  {
    type: 'bank',
    prompt: '日本語にあうハングルを作ってください',
    sentence: '歩いて会社へ行きます',
    answer: ['걸어서', '회사에', '가요.'],
    extra: ['자요.'],
  },
  {
    type: 'listen',
    prompt: '聞こえたハングルの意味を選んでください',
    speak: '아침을 먹어요.',
    choices: ['朝ごはんを食べます', '昼ごはんを食べます', '水を飲みます', '本を読みます'],
    answer: 0,
  },
  {
    type: 'match',
    prompt: 'ハングルと日本語のペアを選んでください',
    pairs: [
      ['일어나요', '起きます'],
      ['아침', '朝ごはん'],
      ['회사', '会社'],
      ['걸어요', '歩きます'],
    ],
  },
]

const evening: Question[] = [
  {
    type: 'choice',
    prompt: 'このハングルの意味を選んでください',
    sentence: '밤에 책을 읽어요.',
    choices: ['夜に本を読みます', '夜に走ります', '朝に読みます', '駅で読みます'],
    answer: 0,
  },
  {
    type: 'blank',
    prompt: '「11時に寝ます」になるように選んでください',
    before: '열한 시에 ',
    after: '.',
    choices: ['자요', '일어나요', '먹어요', '읽어요'],
    answer: 0,
  },
  {
    type: 'bank',
    prompt: '日本語にあうハングルを作ってください',
    sentence: 'また明日',
    answer: ['내일', '봐요.'],
    extra: ['안녕하세요.', '잘'],
  },
  {
    type: 'choice',
    prompt: '日本語にあうハングルを選んでください',
    sentence: '疲れました',
    choices: ['피곤해요', '괜찮아요', '배고파요', '준비됐어요'],
    answer: 0,
  },
]

const storyDay: Question[] = [
  {
    type: 'choice',
    prompt: '起きる時間はいつですか',
    choices: ['일곱 시', '아홉 시', '열두 시', '열 시'],
    answer: 0,
  },
  {
    type: 'choice',
    prompt: '夜にすることはどれですか',
    choices: ['책을 읽어요', '수영해요', '운전해요', '쇼핑해요'],
    answer: 0,
  },
]

const review5: Question[] = [
  {
    type: 'listen',
    prompt: '聞こえたハングルの意味を選んでください',
    speak: '일곱 시에 일어나요.',
    choices: ['7時に起きます', '7時に寝ます', '7時に出発します', '7時に会います'],
    answer: 0,
  },
  {
    type: 'bank',
    prompt: '日本語にあうハングルを作ってください',
    sentence: '私は疲れました',
    answer: ['저는', '피곤해요.'],
    extra: ['괜찮아요.', '학생이에요.'],
  },
  {
    type: 'choice',
    prompt: 'このハングルの意味を選んでください',
    sentence: '내일 봐요.',
    choices: ['また明日', '昨夜ね', '今行きます', 'こちらです'],
    answer: 0,
  },
]

function lesson(
  id: string,
  kind: LessonNode['kind'],
  title: string,
  xp: number,
  questions: Question[],
  passage?: string[],
): LessonNode {
  return { id, kind, title, xp, questions, passage }
}

export const sections: Section[] = [
  {
    id: 's1',
    title: 'セクション 1',
    kicker: '韓国語の入門',
    units: [
      {
        id: 'u1',
        title: 'あいさつをしよう',
        color: '#58cc02',
        dark: '#46a302',
        phrases: [
          { ko: '안녕하세요', ja: 'こんにちは' },
          { ko: '감사합니다', ja: 'ありがとう' },
          { ko: '죄송합니다', ja: 'ごめんなさい' },
          { ko: '안녕히 가세요', ja: '行ってらっしゃい' },
          { ko: '안녕히 계세요', ja: 'お先に失礼します' },
          { ko: '만나서 반갑습니다', ja: 'はじめまして' },
        ],
        nodes: [
          lesson('u1l1', 'lesson', '基本のあいさつ', 15, greetBasic),
          lesson('u1l2', 'lesson', '礼と別れ', 15, greetLeave),
          { id: 'u1c', kind: 'chest', title: '宝箱', gems: 20 },
          lesson('u1s', 'story', '朝の駅', 15, storyMorning, [
            '하나: 안녕하세요!',
            '（ハナ：こんにちは！）',
            '켄: 안녕하세요. 만나서 반갑습니다.',
            '（ケン：こんにちは。はじめまして。）',
            '하나: 네, 반갑습니다.',
            '（ハナ：はい、はじめまして。）',
          ]),
          lesson('u1t', 'trophy', 'ユニット 1 の復習', 20, review1),
        ],
      },
      {
        id: 'u2',
        title: '自分のことを話そう',
        color: '#ce82ff',
        dark: '#a568cc',
        phrases: [
          { ko: '저는 하나예요', ja: '私はハナです' },
          { ko: '학생이에요', ja: '学生です' },
          { ko: '일본 사람이에요', ja: '日本人です' },
          { ko: '이름이 뭐예요?', ja: 'お名前は何ですか' },
          { ko: '제 이름은 켄이에요', ja: '私の名前はケンです' },
        ],
        nodes: [
          lesson('u2l1', 'lesson', '名前', 15, nameLesson),
          lesson('u2l2', 'lesson', '出身と職業', 15, origin),
          { id: 'u2c', kind: 'chest', title: '宝箱', gems: 25 },
          lesson('u2s', 'story', 'はじめての会話', 15, storyIntro, [
            '하나: 안녕하세요. 저는 하나예요.',
            '（ハナ：こんにちは。私はハナです。）',
            '하나: 일본 사람이에요. 학생이에요.',
            '（ハナ：日本人です。学生です。）',
            '켄: 만나서 반갑습니다. 제 이름은 켄이에요.',
            '（ケン：はじめまして。私の名前はケンです。）',
          ]),
          lesson('u2t', 'trophy', 'ユニット 2 の復習', 20, review2),
        ],
      },
      {
        id: 'u3',
        title: 'カフェで注文しよう',
        color: '#1cb0f6',
        dark: '#1899d6',
        phrases: [
          { ko: '커피 주세요', ja: 'コーヒーをください' },
          { ko: '물 주세요', ja: '水をください' },
          { ko: '메뉴 주세요', ja: 'メニューをください' },
          { ko: '맛있어요', ja: 'おいしいです' },
          { ko: '이거 얼마예요?', ja: 'これはいくらですか' },
        ],
        nodes: [
          lesson('u3l1', 'lesson', '注文', 15, order),
          lesson('u3l2', 'lesson', '味', 15, taste),
          { id: 'u3c', kind: 'chest', title: '宝箱', gems: 25 },
          lesson('u3s', 'story', '小さなカフェ', 15, storyCafe, [
            '하나: 커피 주세요.',
            '（ハナ：コーヒーをください。）',
            '직원: 네, 여기요.',
            '（店員：はい、どうぞ。）',
            '하나: 맛있어요. 감사합니다.',
            '（ハナ：おいしいです。ありがとう。）',
          ]),
          lesson('u3t', 'trophy', 'ユニット 3 の復習', 20, review3),
        ],
      },
    ],
  },
  {
    id: 's2',
    title: 'セクション 2',
    kicker: '街と一日',
    units: [
      {
        id: 'u4',
        title: '道をたずねよう',
        color: '#ff86d0',
        dark: '#e066b0',
        phrases: [
          { ko: '역이 어디예요?', ja: '駅はどこですか' },
          { ko: '왼쪽으로 가세요', ja: '左に行ってください' },
          { ko: '오른쪽으로 가세요', ja: '右に行ってください' },
          { ko: '곧장 가세요', ja: 'まっすぐ行ってください' },
          { ko: '얼마예요?', ja: 'いくらですか' },
          { ko: '서울행 표 주세요', ja: 'ソウル行きの切符をください' },
        ],
        nodes: [
          lesson('u4l1', 'lesson', '方向', 15, where),
          lesson('u4l2', 'lesson', '切符', 15, ticket),
          { id: 'u4c', kind: 'chest', title: '宝箱', gems: 30 },
          lesson('u4s', 'story', '駅までの道', 15, storyStreet, [
            '하나: 실례합니다. 역이 어디예요?',
            '（ハナ：すみません。駅はどこですか？）',
            '직원: 왼쪽으로 가세요. 곧장 가세요.',
            '（店員：左に行ってください。まっすぐ行ってください。）',
            '하나: 감사합니다.',
            '（ハナ：ありがとう。）',
          ]),
          lesson('u4t', 'trophy', 'ユニット 4 の復習', 20, review4),
        ],
      },
      {
        id: 'u5',
        title: '一日の流れ',
        color: '#ff9600',
        dark: '#e08600',
        phrases: [
          { ko: '일곱 시에 일어나요', ja: '7時に起きます' },
          { ko: '아침을 먹어요', ja: '朝ごはんを食べます' },
          { ko: '걸어서 회사에 가요', ja: '歩いて会社へ行きます' },
          { ko: '밤에 책을 읽어요', ja: '夜に本を読みます' },
          { ko: '피곤해요', ja: '疲れました' },
          { ko: '내일 봐요', ja: 'また明日' },
        ],
        nodes: [
          lesson('u5l1', 'lesson', '朝', 15, routine),
          lesson('u5l2', 'lesson', '夜', 15, evening),
          { id: 'u5c', kind: 'chest', title: '宝箱', gems: 30 },
          lesson('u5s', 'story', 'ふつうの一日', 15, storyDay, [
            '저는 일곱 시에 일어나요.',
            '（私は7時に起きます。）',
            '아침을 먹어요. 걸어서 회사에 가요.',
            '（朝ごはんを食べます。歩いて会社へ行きます。）',
            '밤에는 책을 읽어요.',
            '（夜には本を読みます。）',
            '피곤해요. 내일 봐요.',
            '（疲れました。また明日。）',
          ]),
          lesson('u5t', 'trophy', 'ユニット 5 の復習', 20, review5),
        ],
      },
    ],
  },
]

export const practiceLessons: LessonNode[] = [
  lesson('p-listen', 'lesson', 'リスニング', 10, [greetBasic[2], greetPolite[2], order[3], where[2]]),
  lesson('p-match', 'lesson', 'ハングルマッチ', 10, [greetLeave[3], taste[2], where[3]]),
  lesson('p-build', 'lesson', '文を作る', 10, [greetBasic[1], nameLesson[1], ticket[2], evening[2]]),
]

export const rivals: Rival[] = [
  { id: 'haru', name: 'はると', xp: 920 },
  { id: 'mio', name: 'みお', xp: 860 },
  { id: 'ren', name: 'れん', xp: 810 },
  { id: 'sora', name: 'そら', xp: 760 },
  { id: 'yui', name: 'ゆい', xp: 700 },
  { id: 'kaito', name: 'かいと', xp: 640 },
  { id: 'aoi', name: 'あおい', xp: 590 },
  { id: 'hinata', name: 'ひなた', xp: 520 },
  { id: 'riku', name: 'りく', xp: 470 },
  { id: 'mei', name: 'めい', xp: 410 },
  { id: 'nana', name: 'なな', xp: 360 },
  { id: 'yuma', name: 'ゆうま', xp: 280 },
  { id: 'rio', name: 'りお', xp: 190 },
  { id: 'itsuki', name: 'いつき', xp: 120 },
]

export const shopItems = [
  {
    id: 'freeze',
    name: 'ストリークフリーズ',
    desc: '1日休んでも連続記録を守れます。同時に2個まで。',
    price: 200,
  },
  {
    id: 'hearts',
    name: 'ハート全回復',
    desc: 'ハートを5個に戻します。',
    price: 350,
  },
  {
    id: 'boost',
    name: '2倍のXP',
    desc: '15分間、レッスンのXPが2倍になります。',
    price: 100,
  },
] as const

export const reasons = ['旅行', '仕事', '学校', 'ドラマと音楽', 'ただ楽しいから']

export const goals = [
  { minutes: 5, label: 'カジュアル', xp: 10 },
  { minutes: 10, label: 'まじめ', xp: 20 },
  { minutes: 15, label: 'ガッツリ', xp: 30 },
  { minutes: 20, label: '超人', xp: 50 },
]

export function goalXp(minutes: number) {
  return goals.find((goal) => goal.minutes === minutes)?.xp ?? 10
}

export function allUnits() {
  return sections.flatMap((section) => section.units)
}

export function allPathNodes() {
  return allUnits().flatMap((unit) => unit.nodes)
}

export function findUnit(unitId: string) {
  return allUnits().find((unit) => unit.id === unitId) ?? null
}

export function findPathNode(nodeId: string) {
  for (const section of sections) {
    for (const unit of section.units) {
      const node = unit.nodes.find((item) => item.id === nodeId)
      if (node) return { section, unit, node }
    }
  }
  return null
}

export function findPractice(id: string) {
  return practiceLessons.find((item) => item.id === id) ?? null
}

export function isNodeDone(nodeId: string, completed: string[], chests: string[]) {
  const found = findPathNode(nodeId)
  if (!found) return false
  if (found.node.kind === 'chest') return chests.includes(nodeId)
  return completed.includes(nodeId)
}

export function isUnlocked(nodeId: string, completed: string[], chests: string[]) {
  const nodes = allPathNodes()
  const index = nodes.findIndex((node) => node.id === nodeId)
  if (index < 0) return false
  if (index === 0) return true
  return isNodeDone(nodes[index - 1].id, completed, chests)
}

export function currentNodeId(completed: string[], chests: string[]) {
  const nodes = allPathNodes()
  const next = nodes.find((node) => !isNodeDone(node.id, completed, chests))
  return next?.id ?? nodes[nodes.length - 1]?.id ?? null
}

export function lessonXp(node: LessonNode, already: boolean) {
  if (node.id.startsWith('p-')) return 10
  return already ? 5 : node.xp
}

export function correctLabel(question: Question) {
  if (question.type === 'choice' || question.type === 'listen' || question.type === 'blank') {
    return question.choices[question.answer] ?? ''
  }
  if (question.type === 'bank') return question.answer.join(' ')
  return 'すべてのペア'
}

export function leagueFor(xp: number) {
  if (xp >= 600) return { name: 'エメラルド', color: '#2bd96b' }
  if (xp >= 300) return { name: 'ゴールド', color: '#ffc800' }
  if (xp >= 100) return { name: 'シルバー', color: '#cfd6dd' }
  return { name: 'ブロンズ', color: '#cd7f32' }
}
