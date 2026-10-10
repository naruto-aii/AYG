# カロナビ

食事・運動・体重を記録する iOS アプリです。画面は Flutter の iOS アプリです。

## アプリを見る

```bash
tool/run_ios.sh
```

release で実機に入れるときも同じスクリプトを使う。

```bash
tool/run_ios.sh --release
```

App Store 提出用の Archive は、先に `tool/prepare_ios_release.sh` を実行する。そのスクリプトが `flutter build ios --config-only` に `--dart-define-from-file=tool/dart_defines.local.json` を付ける。この指定を外して config-only を実行しない。

## ウェブサイト

GitHub Pages は法務ページと静的ページです。アプリの画面ではありません。

- https://naruto-aii.github.io/AYG/legal/privacy.html
- https://naruto-aii.github.io/AYG/legal/
- https://naruto-aii.github.io/AYG/lp/
- https://naruto-aii.github.io/AYG/lingo/
- https://naruto-aii.github.io/AYG/craft/
- https://naruto-aii.github.io/AYG/tenshoku/
