# カロナビ 法務・サポート

公開 HTML（`legal/*.html`）が正です。App Store の URL と、アプリ内の全画面表示は同じ原稿です。
弁護士確認は未実施です。

運営・販売業者の氏名: 麹池成 / 所在地: 東京都 / 連絡先: calonavi.ayg.support@gmail.com

| 文書 | 公開 URL |
| --- | --- |
| 目次 | https://naruto-aii.github.io/AYG/legal/ |
| プライバシーポリシー | https://naruto-aii.github.io/AYG/legal/privacy.html |
| 利用規約 | https://naruto-aii.github.io/AYG/legal/terms.html |
| 特定商取引法に基づく表記 | https://naruto-aii.github.io/AYG/legal/tokushoho.html |
| サポート | https://naruto-aii.github.io/AYG/legal/support.html |
| アカウント削除 | https://naruto-aii.github.io/AYG/legal/account-deletion.html |

参照した公開書類: あすけん利用規約・特商法、カロミル利用規約、FiNC 特商法、消費者庁・特商法11条、個人情報保護法の公表事項。文面はカロナビ用に書き直しています。

## 今回埋めた項目

利用規約: 適用、定義、非医療、アカウント、未成年、課金・定期購入の解約、公開食品の利用許諾、禁止、知財、退会、非保証、損害賠償の上限、反社、地位譲渡、分離可能性、変更、準拠法。

プライバシー: 事業者の氏名、取得項目、利用目的、Health の広告不使用、第三者提供、委託、国外取扱い、安全管理、保管期間、開示・訂正・利用停止、未成年。

特商法11条: 氏名、住所、電話（請求開示）、メール、価格、数量、送料、通信料、支払方法・時期、提供時期、申込期限、返品、定期購入の解約、動作環境。

## アカウント削除 RPC（本番未適用）

`supabase/migrations/20260920120000_delete_own_account_keep_public_foods.sql`

Owner が本番 Supabase の SQL Editor で適用する。エージェントは本番に適用しない。
適用後、設定 → アカウント削除から個人データが消え、公開食品は残る。
未適用のあいだは、アプリがメール依頼にフォールバックする。

## Owner の意思決定が必要な項目

すでに決まっていること（氏名 麹池成、東京都、IAP 初日、公開食品は削除後も残す、Health を出す、全年齢、Web Preview はアプリ非依存なら非公開可、legal HTML は公開維持）は再確認不要。

残っている判断:

1. **課金の中身**: 何を売るか（買い切り / 定期購入 / 両方）、価格、初回の商品数。特商法の価格欄と購入確認画面はこれに依存する。
2. **初回公開の店**: App Store のみか、同時に Google Play も出すか。
3. **Apple ログインを出す時期**: Google ログインがあるため、App Store 提出前に Sign in with Apple が必要（ガイドライン 4.8）。今のボタンは「準備中」。提出前に実装するか、提出を Apple ログイン完了まで待つか。
4. **法人化後の名義**: 屋号なしの個人（麹池成）のまま出すか、法人後に全書類を差し替えるか。差し替え時は効力発生日を決める。
5. **住所・電話の請求対応方針**: ページには東京都とメールだけ。利用者・購入見込みの人から請求が来たら、本人確認のうえ遅滞なく開示する。誰が確認し、何をもって本人とするか（ログイン同一メール必須、など）を決める。
6. **公開食品を残す範囲の再確認**: 削除後も食品名・栄養が他ユーザーから見える。Apple は UGC 削除を期待することがある。開示済みなので通る想定だが、残したくない種類があれば今のうちに分ける。

弁護士レビューは未実施。文面を「法令適合保証」とは言えない。出すか出さないかの最終判断は Owner。

## Owner の作業が必要な項目

エージェントが代行できない、または本番権限が必要な作業。

1. **本番 Supabase**: 上記 SQL を SQL Editor で適用する。適用前にバックアップを取る。`service_role` は共有しない。
2. **サポートメール監視**: `calonavi.ayg.support@gmail.com` を日常的に見る。特商法の住所・電話請求と、RPC 未適用時のアカウント削除依頼は「遅滞なく」返す。
3. **App Store Connect**: プライバシーポリシー URL、利用規約 URL、アカウント削除 URL、Privacy Nutrition Labels（Health は目標計算のみ、広告・マーケティングに使わない）、年齢、連絡先。
4. **Sign in with Apple**: Apple Developer で identifier / key / capability を作り、Supabase Auth に設定する。`.p8` はリポジトリに置かない。実装後は削除時に Apple トークン無効化も必要。
5. **アプリ内課金**: App Store Connect で商品と価格を作る。実装（StoreKit / Play Billing）と、特商法上の購入確認表示は商品が決まってから。
6. **公開してよい連絡先の管理**: 番地、私用電話、身分証画像を legal HTML やストア説明に載せない。請求が来たときだけ、本人確認のうえ個別に返す。
7. **TestFlight / 審査提出**: 証明書、スクリーンショット、審査メモ（Health の用途、公開食品が残ること、アカウント削除の手順）。
8. **Google Play を出す場合**: データセーフティ、アカウント削除 URL、課金商品を別途用意する。
