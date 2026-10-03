import 'package:flutter/material.dart';

import '../../constants/app_strings.dart';
import '../../repositories/subscription_exceptions.dart';
import '../../repositories/subscription_repository.dart';
import '../../services/subscription_offer.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../widgets/design/design_button.dart';
import '../../widgets/design/design_page.dart';
import '../legal/legal_document.dart';
import '../legal/legal_document_screen.dart';

/// ウィジェットと Siri の案内からカロナビ+へ進む。
///
/// 金額は StoreKit が返した表示だけを使う。フラグはここでは立てない。
/// 加入の有無は [SubscriptionRepository] が判定し、起動と復帰でフラグへ写す。
Future<void> showCalonaviPlus(
  BuildContext context, {
  required SubscriptionRepository repository,
}) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (context) => CalonaviPlusEntryScreen(repository: repository),
    ),
  );
}

class CalonaviPlusEntryScreen extends StatefulWidget {
  const CalonaviPlusEntryScreen({super.key, required this.repository});

  final SubscriptionRepository repository;

  @override
  State<CalonaviPlusEntryScreen> createState() =>
      _CalonaviPlusEntryScreenState();
}

class _CalonaviPlusEntryScreenState extends State<CalonaviPlusEntryScreen> {
  bool _busy = false;
  bool _loadingPrices = true;
  SubscriptionOfferings? _offerings;

  @override
  void initState() {
    super.initState();
    _loadPrices();
  }

  Future<void> _loadPrices() async {
    SubscriptionOfferings offerings;
    try {
      offerings = await widget.repository.loadOfferings();
    } catch (_) {
      offerings = SubscriptionOfferings.failed;
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _offerings = offerings;
      _loadingPrices = false;
    });
  }

  Future<void> _purchase(Future<void> Function() action) async {
    await _guarded(() async {
      await action();
      if (!mounted) {
        return;
      }
      if (widget.repository.isPlusActive) {
        _showMessage('購入しました');
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      }
    });
  }

  Future<void> _restore() async {
    await _guarded(() async {
      await widget.repository.restore();
      if (!mounted) {
        return;
      }
      _showMessage(
        widget.repository.isPlusActive ? '購入を復元しました' : '有効な購入は見つかりませんでした',
      );
    });
  }

  Future<void> _guarded(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } on SubscriptionPurchaseUnavailableException {
      if (!mounted) {
        return;
      }
      _showMessage('この環境ではアプリ内課金を使えません');
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showMessage('購入できませんでした');
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String? get _activeExpiryLabel {
    final expiry = latestActivePlusExpiry(
      widget.repository.confirmedEntitlements,
      DateTime.now(),
    );
    if (expiry == null) {
      return null;
    }
    return '${AppStrings.plusCurrentExpiryPrefix}: ${formatPlusExpiryDate(expiry)}';
  }

  @override
  Widget build(BuildContext context) {
    final offerings = _offerings;
    final monthly = offerings?.monthly;
    final yearly = offerings?.yearly;
    final showMonthly = monthly != null && monthly.canPurchase;
    final showYearly = yearly != null && yearly.canPurchase;
    final monthlyOffer = showMonthly ? monthly : null;
    final yearlyOffer = showYearly ? yearly : null;

    return DesignPage(
      bodyPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenHorizontal,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const DesignTitleBlock(
            title: 'カロナビ+',
            subtitle: 'ウィジェットからの登録は、カロナビ+の機能です。',
          ),
          Text(AppStrings.siriVoicePaidGuidance, style: AppTypography.bodyS),
          const SizedBox(height: AppSpacing.md),
          if (_loadingPrices)
            Text('価格を確認しています', style: AppTypography.bodyS)
          else if (monthlyOffer == null && yearlyOffer == null)
            Text('価格を取得できませんでした', style: AppTypography.bodyS)
          else ...[
            if (monthlyOffer != null)
              DesignButton(
                label: monthlyOffer.buttonLabel,
                onPressed: _busy
                    ? null
                    : () => _purchase(widget.repository.purchaseMonthly),
              ),
            if (monthlyOffer != null && yearlyOffer != null)
              const SizedBox(height: AppSpacing.md),
            if (yearlyOffer != null)
              DesignButton(
                label: yearlyOffer.buttonLabel,
                style: monthlyOffer != null
                    ? DesignButtonStyle.secondary
                    : DesignButtonStyle.primary,
                onPressed: _busy
                    ? null
                    : () => _purchase(widget.repository.purchaseYearly),
              ),
          ],
          const SizedBox(height: AppSpacing.md),
          DesignButton(
            label: '購入を復元',
            style: DesignButtonStyle.outline,
            showTrailingIcon: false,
            onPressed: _busy ? null : _restore,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(AppStrings.plusBillingPeriod, style: AppTypography.bodyS),
          const SizedBox(height: AppSpacing.sm),
          Text(AppStrings.plusAutoRenew, style: AppTypography.bodyS),
          const SizedBox(height: AppSpacing.sm),
          Text(AppStrings.plusCancelHow, style: AppTypography.bodyS),
          if (_activeExpiryLabel case final expiryLabel?) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(expiryLabel, style: AppTypography.bodyS),
          ],
          const SizedBox(height: AppSpacing.md),
          TextButton(
            onPressed: () =>
                showLegalDocument(context, LegalDocument.tokushoho),
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              alignment: Alignment.centerLeft,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text('特定商取引法に基づく表記', style: AppTypography.labelM),
          ),
        ],
      ),
    );
  }
}
