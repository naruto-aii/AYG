/// Fixed banned words for public food names.
///
/// One list, checked at publish time and when a public row's name changes.
/// There is no admin editor and no remote dictionary.
const List<String> publicFoodBannedWords = <String>[
  'fuck',
  'fucking',
  'motherfucker',
  'shit',
  'bullshit',
  'asshole',
  'bitch',
  'bastard',
  'cunt',
  'dick',
  'cock',
  'pussy',
  'whore',
  'slut',
  'nigger',
  'nigga',
  'faggot',
  'retard',
  'rape',
  'くそ',
  'くそったれ',
  'ちくしょう',
  'ちんこ',
  'ちんぽ',
  'まんこ',
  'うんこ',
  'きんたま',
  'ファック',
  'セックス',
  'フェラ',
  '中出し',
  '死ね',
  '殺す',
  'きちがい',
  '池沼',
  'エロ',
];

/// Halfwidth katakana, mapped to hiragana. Both strings are the same length.
const String publicFoodHalfwidthKatakanaFrom =
    'ｦｧｨｩｪｫｬｭｮｯｰｱｲｳｴｵｶｷｸｹｺｻｼｽｾｿﾀﾁﾂﾃﾄﾅﾆﾇﾈﾉﾊﾋﾌﾍﾎﾏﾐﾑﾒﾓﾔﾕﾖﾗﾘﾙﾚﾛﾜﾝ';

const String publicFoodHalfwidthKatakanaTo =
    'をぁぃぅぇぉゃゅょっーあいうえおかきくけこさしすせそたちつてとなにぬねのはひふへほまみむめもやゆよらりるれろわん';

/// 1:1 confusable fold applied after NFKC. Both strings are the same length.
/// Accents, Cyrillic/Latin lookalikes, and symbol/digit substitutions.
/// Kept identical to the translate() pair in the banned-name migration.
const String publicFoodConfusableFrom =
    'àáâãäåÀÁÂÃÄÅèéêëÈÉÊËìíîïÌÍÎÏòóôõöÒÓÔÕÖùúûüÙÚÛÜýÿÝŸñÑçÇаАеЕоОрРсСуУхХіІјЈѕЅԁԀ013457@\$!';

const String publicFoodConfusableTo =
    'aaaaaaaaaaaaeeeeeeeeiiiiiiiioooooooooouuuuuuuuyyyynnccaaeeooppccyyxxiijjssddoieastasi';
