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
作成者欄は「削除済みユーザー」になる（`saved_foods.owner_deleted`）。
未適用のあいだは、アプリがメール依頼にフォールバックする。

## 決まったこと（2026-09-20）

- 初回公開は App Store のみ。Google Play は出さない
- 運営名義は法人化まで個人・麹池成
- アカウント削除後の公開食品は残し、作成者欄は「削除済みユーザー」
- 法務文面は、弁護士未確認のまま出す（残余リスクは薄いと判断した場合）

## 課金（2026-09-20 決定）

商品名: カロナビ+
- 月額 380円 / 年額 4,180円（月額×11、1ヶ月分お得）
- Product ID: `calonavi_plus_monthly` / `calonavi_plus_yearly`
- 無料枠: 公開食品検索 5回/日、食事テンプレート 3件、運動テンプレート 3件
- 加入中は3つとも無制限
- 記録・Health・バーコード・公開投稿は無料のまま

App Store Connect で上記 Product ID の自動更新サブスクリプションを作るのは Owner 作業。

## Owner の作業

1. **本番 Supabase**: 上記 SQL を適用する。適用前にバックアップ。`service_role` は共有しない
2. **サポートメール**: 住所・電話の請求と削除依頼を、本人確認のうえ遅滞なく返す
3. **App Store Connect**: プライバシー / 利用規約 / アカウント削除 URL、Privacy Nutrition Labels、年齢
4. **Sign in with Apple**: アプリ側は未実装。Developer 登録だけでは足りない。実装後に提出する
5. **アプリ内課金**: 商品が決まってから App Store Connect と StoreKit
6. **番地・私用電話を公開ページに載せない**
7. **TestFlight / 審査提出**
