# カロナビ 法務・サポート

公開 HTML（`legal/*.html`）が正です。App Store の URL と、アプリ内の全画面表示は同じ原稿です。

Flutter Web は開発中に機能を触るための仮公開です。アプリをリリースしたら Web 本体は非公開にします。
`legal/` だけは、App Store が公開 URL を要求するため残します。

| 文書 | 公開 URL |
| --- | --- |
| 目次 | https://naruto-aii.github.io/AYG/legal/ |
| プライバシーポリシー | https://naruto-aii.github.io/AYG/legal/privacy.html |
| 利用規約 | https://naruto-aii.github.io/AYG/legal/terms.html |
| サポート | https://naruto-aii.github.io/AYG/legal/support.html |
| アカウント削除 | https://naruto-aii.github.io/AYG/legal/account-deletion.html |
| 特定商取引法に基づく表記 | https://naruto-aii.github.io/AYG/legal/tokushoho.html |

運営: 個人（カロナビ） / 所在地: 東京都 / 連絡先: calonavi.ayg.support@gmail.com

アプリ内課金は初回公開から入れる。特商法の販売業者の氏名は、屋号がなければ原則本名。
`legal/tokushoho.html` の「アプリ公開前に記載」を、公開前に本名へ書き換える。弁護士確認は未実施。

原稿は `legal/*.html` を直し、`web-preview` へ push する。

## アカウント削除 RPC（本番未適用）

`supabase/migrations/20260920120000_delete_own_account_keep_public_foods.sql`

Owner が本番 Supabase の SQL Editor で適用する。エージェントは本番に適用しない。
