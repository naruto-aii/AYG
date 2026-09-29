# 転職クエスト

30日で転職準備を練習するブラウザゲームです。公開ページでは `/tenshoku/` に置きます。

経歴を1行にすること、人に話を聞くこと、求人の分解、模擬面接、架空の条件比較までを1回のプレイで通します。登場する会社と金額はすべて架空で、職業紹介やキャリア相談のサービスではありません。

## 遊び方

1日に1つだけ行動します。体力が尽きると、次の伸びが半分になります。8日目以降、応募が1件あれば選考です。15日目以降は、現職に残ることもできます。記録はこのブラウザに残ります。

## 開発

```bash
node --test games/tenshoku/test/logic.test.mjs
python3 -m http.server 8766 --directory games/tenshoku
```

Pages への配置は `tool/assemble_pages_site.sh` が `games/tenshoku` をサイトの `tenshoku/` にコピーします。
