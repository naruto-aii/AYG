# カロナビ 法務・サポート

公開 HTML（`legal/*.html`）が正です。App Store の URL とアプリ内の全画面表示は同じ原稿です。

| 文書 | 公開 URL |
| --- | --- |
| 目次 | https://naruto-aii.github.io/AYG/legal/ |
| プライバシーポリシー | https://naruto-aii.github.io/AYG/legal/privacy.html |
| 利用規約 | https://naruto-aii.github.io/AYG/legal/terms.html |
| サポート | https://naruto-aii.github.io/AYG/legal/support.html |
| アカウント削除 | https://naruto-aii.github.io/AYG/legal/account-deletion.html |

運営: 個人（カロナビ） / 所在地: 東京都 / 連絡先: calonavi.ayg.support@gmail.com

ユーザー向け文書には、屋号にしていない名前の説明や、設計時のペルソナは書かない。
弁護士確認は未実施。

有料のアプリ内課金を出すときは、利用規約とは別に「特定商取引法に基づく表記」を用意する。
屋号を届出していれば屋号、していなければ原則氏名。いまの無料公開では規約に本名は書かない。

原稿は `legal/*.html` を直し、`web-preview` へ push する。

## アカウント削除 RPC（本番未適用）

`supabase/migrations/20260920120000_delete_own_account_keep_public_foods.sql`

Owner が本番 Supabase の SQL Editor で適用する。エージェントは本番に適用しない。
