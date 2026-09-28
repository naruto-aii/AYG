# 言語学習 UI デモ

Duolingo の画面構成と操作（学習パス、レッスン、ストーリー、リーグ、クエスト、ショップ）をブラウザで辿る非公式デモです。Duolingo, Inc. とは関係ありません。

日本語話者向けに、韓国語・英語・スペイン語・フランス語・中国語・ドイツ語のコースを切り替えられます。問題文はオリジナルの見本で、学ぶ言語と日本語が対になっています。進捗はコースごとに、アカウント情報とあわせてこのブラウザの localStorage だけに保存されます。

## 開発

```bash
cd duolingo-web
npm install
npm run dev
```

## 公開用ビルド

```bash
npm run build
```

成果物は `docs/lingo/` に出ます。GitHub Pages では次の URL で公開します。

https://naruto-aii.github.io/AYG/lingo/
