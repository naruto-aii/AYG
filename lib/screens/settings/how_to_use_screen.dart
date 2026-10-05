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
            subtitle: '食事、残りカロリー、目標、運動の入り方です。',
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
                      'ウィジェットと音声登録は iPhone だけで、カロナビ+の機能です。ホームの大きなウィジェットは、残りカロリーに加え、食事3つと運動2つをワンタッチで登録します。ロック画面は同じ食事3つです。このパターンは食事テンプレートの4件とは別です。アプリの中で保存しただけでは、ホーム画面やロック画面に自動では付きません。ホーム画面は、いちばん左のページを長押しし、左上「編集」から「ウィジェットを追加」でカロナビを選びます。ロック画面は、長押しして「カスタマイズ」→「ロック画面」と進み、時刻の上下の枠をタップしてカロナビを選び、「完了」を押します。音声は「Hey Siri、カロナビで」のあとに話します。食事か運動かを判別し、「鶏むね100gの食事でいいですね」のように復唱して、合っていれば登録します。どちらとも取れないときは、復唱で食事か運動かを確認します。',
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
