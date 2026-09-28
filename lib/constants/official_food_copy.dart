/// 食品成分表の表示文。法務メモの文言をそのまま使う。
abstract final class OfficialFoodCopy {
  static const shortAttribution = '出典：食品成分表2023（加工）';

  static const fullAttribution =
      '出典：日本食品標準成分表（八訂）増補2023年（文部科学省）を加工して作成';

  static const sourceSentence =
      '出典：文部科学省「日本食品標準成分表（八訂）増補2023年」（https://www.mext.go.jp/a_menu/syokuhinseibun/mext_00001.html）を加工して作成';

  static const aliasSentence =
      '※1食分の値、単位、食品名の別名・よみは当社が換算・追加したものです。文部科学省が作成・保証したものではありません。';

  static const disclaimerSentence =
      '表示される栄養価は日本食品標準成分表の標準的な値にもとづく目安（計算値）です。実際の食品・商品の値とは異なることがあります。';

  static const externalLinkLabel = '文部科学省ウェブサイトへ移動します';

  static final sourcePage = Uri.parse(
    'https://www.mext.go.jp/a_menu/syokuhinseibun/mext_00001.html',
  );
}
