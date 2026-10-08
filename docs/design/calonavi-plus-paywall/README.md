# カロナビ+ 課金画面

このフォルダの画像は、実際のアプリコード
[`lib/screens/subscription/calonavi_plus_flow.dart`](../../../lib/screens/subscription/calonavi_plus_flow.dart)
（`CalonaviPlusEntryScreen`）をそのまま動かして撮ったスクリーンショットです。
手描きのモックアップではなく、コードが生成する実物の見た目なので、
Cursor など他のツールからもこのデザインをそのまま把握・再現できます。

- `top.png` — 画面の先頭（見出し・ベネフィット一覧）
- `plans.png` — プラン選択カード（月額 / 半年 / 年額）
- `legal-footer.png` — プラン選択の続きと規約・特商法リンク

開いたときは年額が選ばれています。月額か半年を押すと、そのプランに変わり、下のボタンの文言も変わります。
価格はプレビュー用の仮の表示です（月額¥980 / 半年¥4,900 / 年額¥8,800）。半年は月あたり約817円（1か月分お得）、年額は月あたり約733円（月額より約25%お得）です。
実機では StoreKit（App Store Connect の商品設定）が返す金額がそのまま出ます。
この確認用の画面は購入も登録も走らせません。`UnavailableSubscriptionRepository` の購入は例外になります。

## 同じ画面を自分の手元で再現する方法

ログインや Supabase 接続なしで、この画面だけを単体で開ける最小限の
エントリーポイントを一時的に作ってビルドします。

```bash
cat > lib/dev_preview_entry.dart << 'EOF'
import 'package:flutter/material.dart';

import 'package:ayg/config/subscription_catalog.dart';
import 'package:ayg/repositories/unavailable_subscription_repository.dart';
import 'package:ayg/screens/subscription/calonavi_plus_flow.dart';
import 'package:ayg/services/subscription_offer.dart';
import 'package:ayg/theme/app_theme.dart';

void main() {
  runApp(
    MaterialApp(
      theme: AppTheme.light,
      home: CalonaviPlusEntryScreen(repository: _PreviewPlus()),
    ),
  );
}

class _PreviewPlus extends UnavailableSubscriptionRepository {
  @override
  Future<SubscriptionOfferings> loadOfferings() async {
    return const SubscriptionOfferings(
      monthly: SubscriptionProductOffer(
        productId: SubscriptionCatalog.monthlyProductId,
        period: PlusBillingPeriod.month,
        localizedPrice: '¥980',
      ),
      halfYear: SubscriptionProductOffer(
        productId: SubscriptionCatalog.halfYearProductId,
        period: PlusBillingPeriod.halfYear,
        localizedPrice: '¥4,900',
      ),
      yearly: SubscriptionProductOffer(
        productId: SubscriptionCatalog.yearlyProductId,
        period: PlusBillingPeriod.year,
        localizedPrice: '¥8,800',
      ),
      loadFailed: false,
    );
  }
}
EOF

flutter run -d chrome -t lib/dev_preview_entry.dart
# 終わったら lib/dev_preview_entry.dart は削除する（コミットしない）
```

画面の文言やプラン構成を変えたときは、この手順で撮り直して
このフォルダの画像を更新してください。
