/// 食品成分表の表示文。
///
/// [storedAttribution] はデータベースが成分表由来の食品に固定する文で、画面には出さない。
/// 画面の文は、100gあたりで保存し、微量を0、推定値を括弧なしの数値にしている、という実装に合わせる。
abstract final class OfficialFoodCopy {
  static const storedAttribution = '出典：日本食品標準成分表（八訂）増補2023年（文部科学省）を加工して作成';

  static const nutritionPer100g = '栄養の数値は、文部科学省の日本食品標準成分表を100gあたりで保存しています。';

  static const traceAndEstimate = '微量は0、推定値は括弧を外した数値です。';

  static const scaledToGrams = '食べたグラム数に合わせて計算します。';

  static const nameProcessing = '食品名は、公式の名称とは別に、短い表示名と読みを付けています。';

  /// 設定と詳細に出す全文。
  static const explanation =
      '$nutritionPer100g$traceAndEstimate$scaledToGrams$nameProcessing';

  /// 検索の出典。幅が1行に足りるときは全文、足りないときは数値の説明だけ。
  static const fullAttribution = explanation;

  static const compactAttribution = '$nutritionPer100g$traceAndEstimate';

  static const shortAttribution = compactAttribution;

  static const externalLinkLabel = '文部科学省ウェブサイトへ移動します';

  static String aliasAttribution({
    required String alias,
    required String officialName,
    required String foodCode,
  }) {
    return '「$alias」は運営が付けた別名です。成分表の食品名：$officialName（食品番号 $foodCode）';
  }

  static final sourcePage = Uri.parse(
    'https://www.mext.go.jp/a_menu/syokuhinseibun/mext_00001.html',
  );
}
