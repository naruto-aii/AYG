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
                      '設定の「目標設定」で、減量・維持・増量と、目標体重、目標日を保存します。1日のカロリーは自動で計算するか、自分でカロリーと、たんぱく質・脂質・炭水化物を入れます。',
                ),
                const SizedBox(height: AppSpacing.md),
                const _Section(
                  title: '運動を記録する',
                  body:
                      'ホームの「運動追加」か、下の「運動」から記録します。種目を選ぶと、時間や距離から消費カロリーを計算できるものがあります。計算しない種目は、カロリーを自分で入れます。',
                ),
                const SizedBox(height: AppSpacing.md),
                const _Section(
                  title: 'ウィジェットと音声登録',
                  body:
                      'ウィジェットと音声登録は iPhone だけで、カロナビ+の機能です。ホームの大きなウィジェットは、残りカロリーに加え、食事3つと運動2つをワンタッチで登録します。ロック画面は同じ食事3つです。このパターンは食事テンプレートの4件とは別です。アプリの中で保存しただけでは、ホーム画面やロック画面に自動では付きません。ホーム画面は、いちばん左のページを長押しし、左上「編集」から「ウィジェットを追加」でカロナビを選びます。ロック画面は、長押しして「カスタマイズ」→「ロック画面」と進み、時刻の上下の枠をタップしてカロナビを選び、「完了」を押します。音声のショートカットは、自分で追加しません。使う前に、設定アプリの「Siriと検索」（または「Apple IntelligenceとSiri」）でSiriをオンにし、カロナビにログインしておきます。そのあと「Hey Siri、カロナビで」のあとに話します。食事か運動かを判別し、「鶏むね100gの食事でいいですね」のように復唱して、合っていれば登録します。どちらとも取れないときは、復唱で食事か運動かを確認します。公開食品はSiriから登録できません。Siriで記録しそうなものは、テンプレートにしておくのがおすすめです。',
                ),
                const SizedBox(height: AppSpacing.md),
                const _Section(
                  title: '無料とカロナビ+',
                  body:
                      '無料でも、食事・運動・体重の記録、記録の共有、食事テンプレート4件、運動テンプレート4件が使えます。カロナビ+では食事と運動のテンプレートの件数制限がなくなり、食事のメモ、直近3日の食品、ウィジェット、音声登録が使えます。ウィジェットの置き方と音声の始め方は、上の節と各画面に書いてあります。',
                ),
                const SizedBox(height: AppSpacing.md),
                const _Section(
                  title: 'テンプレート',
                  body:
                      '食事テンプレートは、よく食べる食品を一度に登録します。運動テンプレートは、よくする運動の組み合わせです。無料はそれぞれ4件までで、カロナビ+は何件でも保存できます。ウィジェットのボタンの中身は、この一覧とは別です。',
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
                  title: '今日のコーチ',
                  body:
                      'ホームの「今日のコーチ」は、その日の残りから食事か運動を一つ提案します。量を確認して登録するまで、記録には入りません。精度の検証中で、いまは無料です。',
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
                      '食事の追加では、手入力、バーコード、保存済み、探す、テンプレートを選べます。手入力は名前と栄養素を自分で入れます。公開食品は、ほかの人が公開した食品で、氏名やメールは載りません。公開した食品は、アカウントを削除しても残ります。',
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
