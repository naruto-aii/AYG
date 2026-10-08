import 'package:flutter/material.dart';

import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../widgets/design/design_card.dart';
import '../../widgets/design/design_page.dart';

/// 設定の「使い方」。いまの画面にある操作だけを書く。
class HowToUseScreen extends StatelessWidget {
  const HowToUseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DesignPage(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const DesignTitleBlock(
            title: '使い方',
            subtitle: 'はじめての操作と、無料とカロナビ+の違いです。',
          ),
          DesignCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _Section(
                  title: '食事を記録する',
                  body:
                      'ホームの「食事追加」か、下の「食事」にある「食事を追加」から、食品名と量を入れて保存します。保存した食事は、その日の「今日の食事」に出ます。',
                ),
                const SizedBox(height: AppSpacing.md),
                const _Section(
                  title: '残りのカロリー',
                  body:
                      'ホームの「今日あと」は、その日の食事目標から、食べた分を引いた残りです。運動を記録すると、その消費が残りに足されます。目標を超えると「超過」と出ます。iPhoneでヘルスケア連携を使っているときは、生活活動として見込んだ分を超えた活動量も残りに足します。',
                ),
                const SizedBox(height: AppSpacing.md),
                const _Section(
                  title: '目標を決める',
                  body:
                      '設定の「プロフィールと目標」にある「目標設定」で、減量・維持・増量と、目標体重、目標日を保存します。1日のカロリーは自動で計算するか、自分でカロリーと、たんぱく質・脂質・炭水化物を入れます。',
                ),
                const SizedBox(height: AppSpacing.md),
                const _Section(
                  title: '運動を記録する',
                  body:
                      'ホームの「運動追加」か、下の「運動」から記録します。種目を選ぶと、時間や距離から消費カロリーを計算できるものがあります。計算しない種目は、カロリーを自分で入れます。',
                ),
                const SizedBox(height: AppSpacing.md),
                const _Section(
                  title: 'ウィジェットと、音声登録 (β)',
                  body:
                      'ウィジェットでワンタップ記録は、ホーム画面とロック画面のウィジェットです。ホーム画面の大きなウィジェットは、残りカロリーに加え、アプリを開かずに食事と運動を登録します。枠は食事と運動を自由に組み合わせられます。ロック画面の3枠は、ホームの1〜3枠目を種類も含めてそのまま使います。枠の中身は、保存した食事・運動テンプレートを選んで食品や種目ごとに量を変えて入れるか、その場で作ります。枠に入れても元のテンプレートは変わらず、テンプレートの件数にも入りません。アプリの中で保存しただけでは、ホーム画面やロック画面に自動では付きません。ホーム画面は、いちばん左のページを長押しし、左上「編集」から「ウィジェットを追加」でカロナビを選びます。ロック画面は、長押しして「カスタマイズ」→「ロック画面」と進み、時刻の上下の枠をタップしてカロナビを選び、「完了」を押します。音声のショートカットは、自分で追加しません。使う前に、設定アプリの「Siriと検索」（または「Apple IntelligenceとSiri」）でSiriをオンにし、カロナビにログインしておきます。「Hey Siri、カロナビに登録」または「Hey Siri、カロナビ登録」と話し、Siriの短い質問に答えます。食事は「Hey Siri、カロナビで食事を記録」、運動は「Hey Siri、カロナビで運動を記録」です。質問には「ささみ100g」のように量まで答えられます。一覧にある食品は「Hey Siri、カロナビで食事にささみ」、運動は「Hey Siri、カロナビで運動にウォーキング」です。この言い方では量は続く質問に答えます。一覧に無いものは「カロナビで食事を記録」から話します。登録した内容を読み上げます。直前の1件は「Hey Siri、カロナビで今登録したやつ消して」で消せます。候補が分かれるときだけ、登録の前に確認します。牛ももの焼き200gのように詳しく答えると、その場で登録できます。牛肉のように種類が分かれると、部位を聞くことがあります。食事か運動か決まらないときは、どちらに登録するかを確認します。食品成分表と、ブロックしていない人の公開食品もSiriから登録できます。保存した食品とテンプレート名は、アプリを開いたあと「カロナビで食事に」のあとに言えます。',
                ),
                const SizedBox(height: AppSpacing.md),
                const _Section(
                  title: '無料とカロナビ+',
                  body:
                      '無料でも、食事・運動・体重の記録、記録の共有、食事テンプレート4件、運動テンプレート4件が使えます。カロナビ+では食事と運動のテンプレートの件数制限がなくなり、食事のメモ、直近3日の食品、ウィジェットでワンタップ記録、音声登録 (β)、パーソナルコーチ (β)、写真で登録 (β)、AIで探す (β) が使えます。ウィジェットとSiriで、記録を速くできます。あわせて、β版機能への先行アクセスが付きます。ウィジェットの置き方と音声の始め方は、上の節と各画面に書いてあります。',
                ),
                const SizedBox(height: AppSpacing.md),
                const _Section(
                  title: 'テンプレート',
                  body:
                      '食事テンプレートは、よく食べる食品を一度に登録します。運動テンプレートは、よくする運動の組み合わせです。無料はそれぞれ4件までで、カロナビ+は何件でも保存できます。ウィジェットのボタンの中身は、この一覧から選んで量を変えて入れられます。入れても元のテンプレートは変わりません。',
                ),
                const SizedBox(height: AppSpacing.md),
                const _Section(
                  title: 'メモ',
                  body: '食事のメモはカロナビ+です。無料のときは「メモ」を押すと案内が出ます。メモはカロリーの計算には使いません。',
                ),
                const SizedBox(height: AppSpacing.md),
                const _Section(
                  title: '運動のきつさ',
                  body:
                      '種目によっては、楽からきついまで選べます。同じ時間でも、きつさで消費カロリーが変わります。カロリーを自分で入れる種目には、きつさはありません。',
                ),
                const SizedBox(height: AppSpacing.md),
                const _Section(
                  title: 'パーソナルコーチ (β)',
                  body:
                      'ホームの「パーソナルコーチ (β)」は、残りカロリーを時間帯に合わせて今日これからの食事と間食に分け、食事ごとに主食・主菜・副菜の組み合わせと量を提案します。11時までは朝食・昼食・間食・夕食、11時から15時までは昼食・間食・夕食、15時から22時までは夕食、22時以降は間食だけです。1食は850kcalまで、間食は乳製品や果物で1回200kcalまでです。画面の上に、今日の残りカロリーを食事ごとに何kcalずつ食べるかと、その合計を出します。食事ごとに食品とおすすめの量・kcalが並び、量を変えるとkcalも変わります。食べすぎた日は運動を提案します。「ほかの案」で次の案を見られます。食べた食事ごとに量を確認して登録し、登録するまで記録には入りません。登録した食事は次に開いたとき「登録済み」になり、新しい残りカロリーで、まだの食事を組み直します。',
                ),
                const SizedBox(height: AppSpacing.md),
                const _Section(
                  title: 'お知らせ',
                  body: 'ホーム上部の「お知らせ」は、運営からの連絡です。赤い点は未読で、開くと既読になります。',
                ),
                const SizedBox(height: AppSpacing.md),
                const _Section(
                  title: '体重',
                  body:
                      '体重の記録は、1日のカロリー計算に使います。手入力とヘルスケアは、測った時刻が新しい方です。7日より古いときは、画面が記録を促します。',
                ),
                const SizedBox(height: AppSpacing.md),
                const _Section(
                  title: '記録を共有する',
                  body:
                      'ホーム右上の共有を押すと、今日の摂取カロリーが、目標に対する丸い進捗の画像で送れます。文章には、目標のうちどれだけ摂ったかと、アプリの紹介、リンクが入ります。送る相手は、iPhoneの共有で選びます。共有は無料です。',
                ),
                const SizedBox(height: AppSpacing.md),
                const _Section(
                  title: '食品の探し方',
                  body:
                      '食事の追加では、手入力、バーコード、食品を探す、テンプレート、写真で登録から記録できます。保存済み食品や定番の食品、公開食品は「食品を探す」から選べます。公開食品は、ほかの人が公開した食品で、氏名やメールは載りません。公開した食品は、アカウントを削除しても残ります。写真で登録 (β) はカロナビ+です。写真を撮るか、カメラロールから選びます。料理名は任意です。入れると精度が上がります。量も任意で、グラム・個数・杯数など、できるだけ正確に入れると精度が上がります。補足も任意で、油の量や脂身、ソースなど写真で分かりにくい特徴を書けます。カロリーとPFCはAIの推定です。登録の前に確認して、数値を直せます。料理名を入れなかったときは、登録のときに名前を確認します。写真はカロナビに保存しません。AIで探す (β) もカロナビ+です。検索で見つからない食品は、チェーン店のメニューなども含めて、AIがカロリーとPFCの推定を出します。推定だと表示します。',
                ),
                const SizedBox(height: AppSpacing.md),
                const _Section(
                  title: 'レビューのお願い',
                  body:
                      '7日続けて記録したあと、またはウィジェットか音声で登録したあとに出ることがあります。断ると次は出ません。評価の内容はアプリでは受け取りません。',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppTypography.titleM),
        const SizedBox(height: AppSpacing.sm),
        Text(body, style: AppTypography.bodyS),
      ],
    );
  }
}
