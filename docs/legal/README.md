# カロナビ 法務・サポート

公開 HTML（`legal/*.html`）が正です。App Store の URL と、アプリ内の全画面表示は同じ原稿です。

アプリ内では設定・ログインから全画面で開き、右上の × で閉じます。外部ブラウザは開きません（メールリンクだけ外部）。

| 文書 | 公開 URL |
| --- | --- |
| 目次 | https://naruto-aii.github.io/AYG/legal/ |
| プライバシーポリシー | https://naruto-aii.github.io/AYG/legal/privacy.html |
| 利用規約 | https://naruto-aii.github.io/AYG/legal/terms.html |
| サポート | https://naruto-aii.github.io/AYG/legal/support.html |
| アカウント削除 | https://naruto-aii.github.io/AYG/legal/account-deletion.html |

運営: 個人（カロナビ） / 所在地: 東京都 / 連絡先: calonavi.ayg.support@gmail.com

AYG は将来の法人名の予定です。現時点の屋号・会社名としては出しません。
弁護士確認は未実施です。法人化したら運営者表記を更新します。

原稿の編集は `legal/*.html` を直し、`web-preview` へ push して Deploy Web Preview を回します。アプリ内表示は同じファイルを asset として読みます。

## アカウント削除 RPC（本番未適用）

`supabase/migrations/20260920120000_delete_own_account_keep_public_foods.sql`

個人の記録は消し、公開食品は残します。Owner が本番 Supabase の SQL Editor で適用してください。エージェントは本番に適用しません。適用後に、アプリ内ワンタップ削除を足せます。
