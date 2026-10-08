import 'dart:async';

import 'package:flutter/material.dart';

import '../../config/subscription_catalog.dart';
import '../../constants/app_strings.dart';
import '../../repositories/plus_funnel_repository.dart';
import '../../services/analytics/analytics.dart';
import '../../repositories/subscription_exceptions.dart';
import '../../repositories/subscription_repository.dart';
import '../../services/subscription_offer.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../widgets/design/design_button.dart';
import '../../widgets/design/design_icon.dart';
import '../../widgets/design/design_page.dart';
import '../../widgets/design/icon_circle.dart';
import '../../widgets/design/select_card.dart';
import '../legal/legal_document.dart';
import '../legal/legal_document_screen.dart';

/// ウィジェットと Siri の案内、設定からカロナビ+へ進む。
///
/// 表示金額は、ストアが返した税込価格を使う。返せないときだけ画面の予備表示を出す。
/// 購入処理は商品IDだけを渡す。この画面を開いただけでは購入も登録もしない。
/// フラグはここでは立てない。
Future<void> showCalonaviPlus(
  BuildContext context, {
  required SubscriptionRepository repository,
  PlusFunnelFeature? feature,
  PlusFunnelRepository? funnel,
}) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      settings: const RouteSettings(name: 'calonavi_plus_flow_MaterialPageRoute_0'),
      fullscreenDialog: true,
      builder: (context) => CalonaviPlusEntryScreen(
        repository: repository,
        feature: feature,
        funnel: funnel,
      ),
    ),
  );
}

/// `¥2,900` のような円表示だけを読む。ドルなどは読まない。
int? yenAmount(String localized) {
  final match = RegExp(
    r'^[¥￥]\s*([0-9]{1,3}(?:,[0-9]{3})*|[0-9]+)$',
  ).firstMatch(localized.trim());
  if (match == null) {
    return null;
  }
  return int.tryParse(match.group(1)!.replaceAll(',', ''));
}

String _groupDigits(int value) {
  final text = value.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < text.length; i++) {
    if (i > 0 && (text.length - i) % 3 == 0) {
      buffer.write(',');
    }
    buffer.write(text[i]);
  }
  return buffer.toString();
}

class CalonaviPlusEntryScreen extends StatefulWidget {
  const CalonaviPlusEntryScreen({
    super.key,
    required this.repository,
    this.feature,
    this.funnel,
  });

  final SubscriptionRepository repository;
  final PlusFunnelFeature? feature;
  final PlusFunnelRepository? funnel;

  @override
  State<CalonaviPlusEntryScreen> createState() =>
      _CalonaviPlusEntryScreenState();
}

class _PlanOption {
  const _PlanOption({
    required this.plan,
    required this.price,
    required this.note,
    this.badgeLabel,
  });

  final PlusPlan plan;
  final String price;
  final String note;
  final String? badgeLabel;
}

class _CalonaviPlusEntryScreenState extends State<CalonaviPlusEntryScreen> {
  bool _busy = false;
  bool _loadingPrices = true;
  SubscriptionOfferings? _offerings;

  /// 開いたときは年額。月額か半年を押したときだけ、そのプランに変わる。
  PlusPlan _selected = PlusPlan.yearly;

  @override
  void initState() {
    super.initState();
    _openedAt = DateTime.now();
    _record(PlusFunnelEvent.paywallOpen);
    _loadPrices();
  }

  DateTime _openedAt = DateTime.now();
  bool _purchased = false;

  @override
  void dispose() {
    Analytics.emit('paywall_close', {
      'dwell_ms': DateTime.now().difference(_openedAt).inMilliseconds,
      'last_selected_product_id': SubscriptionCatalog.planKeyFor(_selected),
      'purchased': _purchased,
    });
    super.dispose();
  }

  void _record(PlusFunnelEvent event, {String? productId}) {
    final featureName = switch (widget.feature) {
      PlusFunnelFeature.memo => 'food_memo',
      null => 'other',
      _ => widget.feature!.storageValue,
    };
    final planId = SubscriptionCatalog.planKeyForProduct(productId);
    switch (event) {
      case PlusFunnelEvent.paywallOpen:
        Analytics.emit('paywall_open', {
          'entry_point': widget.feature == null ? 'settings' : 'gate_$featureName',
          'products_loaded': !_loadingPrices && _offerings != null,
        });
      case PlusFunnelEvent.planSelect:
        Analytics.emit('plan_select', {'product_id': planId});
      case PlusFunnelEvent.purchaseTap:
        Analytics.emit('purchase_tap', {
          'product_id': planId,
          'entry_point': widget.feature == null ? 'settings' : 'gate_$featureName',
        });
      case PlusFunnelEvent.purchaseSuccess:
      case PlusFunnelEvent.purchaseCancel:
      case PlusFunnelEvent.purchaseFailed:
        break;
      case PlusFunnelEvent.restoreTap:
        Analytics.emit('restore_tap', {'product_id': planId});
      case PlusFunnelEvent.gateShown:
      case PlusFunnelEvent.gateTap:
        break;
    }
    final funnel = widget.funnel;
    if (funnel == null) {
      return;
    }
    unawaited(() async {
      try {
        await funnel.record(
          event: event,
          feature: widget.feature,
          productId: planId ?? productId,
        );
      } catch (error, stackTrace) {
        debugPrint('[AYG] plus funnel record failed: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
    }());
  }

  Future<void> _loadPrices() async {
    if (widget.repository.testPurchaseToggleEnabled) {
      await Future<void>.value();
      if (!mounted) {
        return;
      }
      setState(() {
        _offerings = SubscriptionOfferings.failed;
        _loadingPrices = false;
      });
      return;
    }
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

  bool _hasStorePrice(SubscriptionProductOffer? offer) {
    final price = offer?.localizedPrice.trim() ?? '';
    return offer != null && offer.canPurchase && price.isNotEmpty;
  }

  /// ストアの金額が無いときだけ、画面に出す予備。購入には渡さない。
  String _displayPrice(PlusPlan plan, SubscriptionProductOffer? offer) {
    if (_hasStorePrice(offer)) {
      return offer!.localizedPrice.trim();
    }
    return switch (plan) {
      PlusPlan.monthly => AppStrings.plusFallbackMonthlyPrice,
      PlusPlan.halfYear => AppStrings.plusFallbackHalfYearPrice,
      PlusPlan.yearly => AppStrings.plusFallbackYearlyPrice,
    };
  }

  /// 半年と年額の注記は、いま画面に出している金額から割る。
  String _note(PlusPlan plan, String price) {
    if (plan == PlusPlan.monthly) {
      return AppStrings.plusMonthlyNote;
    }
    final amount = yenAmount(price);
    if (amount == null) {
      return '';
    }
    final months = _months(plan);
    final exact = amount % months == 0;
    final perMonth = exact ? amount ~/ months : (amount / months).round();
    final digits = _groupDigits(perMonth);
    return exact ? '月あたり$digits円' : '月あたり約$digits円';
  }

  /// 月額より月あたりが安いときだけ。いちばん安いプランが「一番お得」。
  String? _badge(PlusPlan plan, Map<PlusPlan, int?> yen) {
    if (plan == PlusPlan.monthly) {
      return null;
    }
    final monthly = yen[PlusPlan.monthly];
    final amount = yen[plan];
    if (monthly == null || amount == null || monthly <= 0) {
      return null;
    }
    final months = _months(plan);
    if (amount >= monthly * months) {
      return null;
    }
    var best = true;
    for (final other in PlusPlan.values) {
      if (other == PlusPlan.monthly || other == plan) {
        continue;
      }
      final otherAmount = yen[other];
      if (otherAmount == null) {
        continue;
      }
      final otherMonths = _months(other);
      if (otherAmount >= monthly * otherMonths) {
        continue;
      }
      if (amount * otherMonths > otherAmount * months) {
        best = false;
      }
    }
    return best ? AppStrings.plusBadgeBestValue : AppStrings.plusBadgeSave;
  }

  int _months(PlusPlan plan) {
    return switch (plan) {
      PlusPlan.monthly => 1,
      PlusPlan.halfYear => 6,
      PlusPlan.yearly => 12,
    };
  }

  List<_PlanOption> get _plans {
    final offerings = _offerings;
    final prices = {
      for (final plan in PlusPlan.values)
        plan: _displayPrice(plan, offerings?.offerFor(plan)),
    };
    final yen = {
      for (final entry in prices.entries) entry.key: yenAmount(entry.value),
    };
    return [
      for (final plan in PlusPlan.values)
        _PlanOption(
          plan: plan,
          price: prices[plan]!,
          note: _note(plan, prices[plan]!),
          badgeLabel: _badge(plan, yen),
        ),
    ];
  }

  _PlanOption get _selectedPlan {
    return _plans.firstWhere((plan) => plan.plan == _selected);
  }

  Future<void> _confirm() async {
    final plan = _selected;
    final productId = SubscriptionCatalog.planKeyFor(plan);
    _record(PlusFunnelEvent.purchaseTap, productId: productId);
    await _purchase(
      () => widget.repository.purchasePlan(plan),
      productId: productId,
    );
  }

  Future<void> _purchase(
    Future<void> Function() action, {
    required String productId,
  }) async {
    await _guarded(() async {
      await action();
      if (!mounted) {
        return;
      }
      if (widget.repository.isPlusActive) {
        _purchased = true;
        _record(PlusFunnelEvent.purchaseSuccess, productId: productId);
        _showMessage(
          widget.repository.testPurchaseToggleEnabled
              ? 'テスト用にカロナビ+にしました'
              : '購入しました',
        );
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      } else {
        _record(PlusFunnelEvent.purchaseCancel, productId: productId);
      }
    }, productId: productId);
  }

  Future<void> _restore() async {
    _record(
      PlusFunnelEvent.restoreTap,
      productId: SubscriptionCatalog.planKeyFor(_selected),
    );
    await _guarded(() async {
      await widget.repository.restore();
      if (!mounted) {
        return;
      }
      Analytics.emit('restore_result', {
        'result': widget.repository.isPlusActive ? 'restored' : 'none_found',
      });
      _showMessage(
        widget.repository.isPlusActive ? '購入を復元しました' : '有効な購入は見つかりませんでした',
      );
    }, recordPurchaseFailure: false);
  }

  Future<void> _guarded(
    Future<void> Function() action, {
    String? productId,
    bool recordPurchaseFailure = true,
  }) async {
    setState(() => _busy = true);
    try {
      await action();
    } on SubscriptionPurchaseUnavailableException {
      if (recordPurchaseFailure) {
        _record(PlusFunnelEvent.purchaseFailed, productId: productId);
      }
      if (!mounted) {
        return;
      }
      _showMessage('この環境ではアプリ内課金を使えません');
    } catch (_) {
      if (recordPurchaseFailure) {
        _record(PlusFunnelEvent.purchaseFailed, productId: productId);
      }
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
    final plans = _loadingPrices ? const <_PlanOption>[] : _plans;
    final selectedPlan = plans.isEmpty ? null : _selectedPlan;

    return DesignPage(
      header: Align(
        alignment: Alignment.centerRight,
        child: IconButton(
          key: const Key('calonavi-plus-close'),
          tooltip: '閉じる',
          icon: const DesignIcon(
            Symbols.close_rounded,
            size: 22,
            color: AppColors.iconMuted,
          ),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      bodyPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenHorizontal,
      ),
      bottomBarPadding: const EdgeInsets.fromLTRB(
        AppSpacing.screenHorizontal,
        6,
        AppSpacing.screenHorizontal,
        6,
      ),
      bottomBar: plans.isEmpty
          ? null
          : DesignButton(
              key: const Key('plus-purchase'),
              label: '${selectedPlan!.price}${AppStrings.plusCtaPrefix}',
              showTrailingIcon: false,
              loading: _busy,
              onPressed: _busy ? null : _confirm,
            ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.sm),
          Center(
            child: IconCircle(
              size: 72,
              tone: IconCircleTone.green,
              child: const DesignIcon(
                Symbols.workspace_premium_rounded,
                size: 36,
                color: AppColors.iconPrimary,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'カロナビ+',
            textAlign: TextAlign.center,
            style: AppTypography.headingL,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            AppStrings.plusHeroSubtitle,
            textAlign: TextAlign.center,
            style: AppTypography.bodyM,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            AppStrings.plusBetaAccessLead,
            textAlign: TextAlign.center,
            style: AppTypography.bodyM,
          ),
          const SizedBox(height: AppSpacing.lg),
          _Benefit(
            icon: Symbols.bookmark_rounded,
            title: AppStrings.plusBenefitTemplateTitle,
            body: AppStrings.plusBenefitTemplateBody,
          ),
          const SizedBox(height: AppSpacing.md),
          _Benefit(
            icon: Symbols.edit_note_rounded,
            title: AppStrings.plusBenefitNoteTitle,
            body: AppStrings.plusBenefitNoteBody,
          ),
          const SizedBox(height: AppSpacing.md),
          _Benefit(
            icon: Symbols.widgets_rounded,
            title: AppStrings.plusBenefitWidgetTitle,
            body: AppStrings.plusBenefitWidgetBody,
          ),
          const SizedBox(height: AppSpacing.md),
          _Benefit(
            icon: Symbols.mic_rounded,
            title: AppStrings.plusBenefitSiriTitle,
            body: AppStrings.plusBenefitSiriBody,
            detail: AppStrings.siriVoicePaidGuidance,
          ),
          const SizedBox(height: AppSpacing.md),
          _Benefit(
            icon: Symbols.photo_camera_rounded,
            title: AppStrings.plusBenefitPhotoTitle,
            body: AppStrings.plusBenefitPhotoBody,
          ),
          const SizedBox(height: AppSpacing.md),
          _Benefit(
            icon: Symbols.search_rounded,
            title: AppStrings.plusBenefitAiLookupTitle,
            body: AppStrings.plusBenefitAiLookupBody,
          ),
          const SizedBox(height: AppSpacing.md),
          _Benefit(
            icon: Symbols.eco_rounded,
            title: AppStrings.plusBetaAccessTitle,
            body: AppStrings.plusBetaAccessBody,
          ),
          const SizedBox(height: AppSpacing.lg),
          if (_loadingPrices)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
              child: Center(child: CircularProgressIndicator()),
            )
          else ...[
            Text('プランを選ぶ', style: AppTypography.titleM),
            const SizedBox(height: AppSpacing.sm),
            for (var i = 0; i < plans.length; i++) ...[
              if (i > 0) const SizedBox(height: AppSpacing.sm),
              SelectCard(
                key: Key('plus-plan-${plans[i].plan.name}'),
                title: plusPlanLabel(plans[i].plan),
                description: plans[i].note.isEmpty
                    ? plans[i].price
                    : '${plans[i].price} ・ ${plans[i].note}',
                selected: plans[i].plan == _selected,
                minHeight: 84,
                badge: plans[i].badgeLabel == null
                    ? null
                    : _PlanBadge(label: plans[i].badgeLabel!),
                onTap: _busy
                    ? null
                    : () {
                        setState(() => _selected = plans[i].plan);
                        _record(
                          PlusFunnelEvent.planSelect,
                          productId: SubscriptionCatalog.planKeyFor(plans[i].plan),
                        );
                      },
              ),
            ],
          ],
          const SizedBox(height: AppSpacing.md),
          DesignButton(
            label: '購入を復元',
            style: DesignButtonStyle.outline,
            showTrailingIcon: false,
            onPressed: _busy ? null : _restore,
          ),
          const SizedBox(height: AppSpacing.lg),
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
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _LegalLink(label: '利用規約', document: LegalDocument.terms),
              _LegalLink(
                label: 'プライバシーポリシー',
                document: LegalDocument.privacy,
              ),
              _LegalLink(
                label: '特定商取引法に基づく表記',
                document: LegalDocument.tokushoho,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LegalLink extends StatelessWidget {
  const _LegalLink({required this.label, required this.document});

  final String label;
  final LegalDocument document;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: () => showLegalDocument(context, document),
      style: TextButton.styleFrom(
        padding: EdgeInsets.zero,
        minimumSize: Size.zero,
        alignment: Alignment.centerLeft,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(label, style: AppTypography.labelM),
    );
  }
}

class _Benefit extends StatelessWidget {
  const _Benefit({
    required this.icon,
    required this.title,
    required this.body,
    this.detail,
  });

  final IconData icon;
  final String title;
  final String body;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        IconCircle(
          size: 40,
          tone: IconCircleTone.green,
          child: DesignIcon(icon, size: 20, color: AppColors.iconPrimary),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTypography.titleS),
              const SizedBox(height: 2),
              Text(body, style: AppTypography.bodyS),
              if (detail case final detail?) ...[
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: AppColors.bgSurfaceGreenSoft,
                    borderRadius: AppRadius.input,
                  ),
                  child: Text(detail, style: AppTypography.caption),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _PlanBadge extends StatelessWidget {
  const _PlanBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.bgPrimary,
        borderRadius: AppRadius.chip,
      ),
      child: Text(
        label,
        style: AppTypography.caption.copyWith(
          color: AppColors.textOnPrimary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
