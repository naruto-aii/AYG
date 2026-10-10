import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

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
  Future<void> Function()? onPlusActive,
}) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      settings: const RouteSettings(
        name: 'calonavi_plus_flow_MaterialPageRoute_0',
      ),
      fullscreenDialog: true,
      builder: (context) => CalonaviPlusEntryScreen(
        repository: repository,
        feature: feature,
        funnel: funnel,
        onPlusActive: onPlusActive,
      ),
    ),
  );
}

/// `¥4,900` のような円表示だけを読む。ドルなどは読まない。
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
    this.onPlusActive,
  });

  final SubscriptionRepository repository;
  final PlusFunnelFeature? feature;
  final PlusFunnelRepository? funnel;

  /// 購入または復元で有料になったあと、署名付き取引をサーバへ送る。
  final Future<void> Function()? onPlusActive;

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
    this.freeTrialDays,
  });

  final PlusPlan plan;
  final String price;
  final String note;
  final String? badgeLabel;

  /// ストアが無料のお試しを返したときだけ。無いときは価格だけを出す。
  final int? freeTrialDays;

  bool get hasFreeTrial => (freeTrialDays ?? 0) > 0;

  /// 価格カードの直下に出す2行。お試しがあるときだけ無料の日数を出す。
  String get ctaNote {
    final trialDays = freeTrialDays;
    if (trialDays != null && trialDays > 0) {
      return AppStrings.plusCtaTrialNote(trialDays, plusPlanLabel(plan), price);
    }
    return AppStrings.plusCtaPriceNote(plusPlanLabel(plan), price);
  }

  String get ctaLabel {
    final trialDays = freeTrialDays;
    if (trialDays != null && trialDays > 0) {
      return AppStrings.plusTrialCta(trialDays);
    }
    return '$price${AppStrings.plusCtaPrefix}';
  }
}

class _CalonaviPlusEntryScreenState extends State<CalonaviPlusEntryScreen> {
  /// 本文の設計高さがこれ未満なら、3つの価格と無料体験の注記を購入ボタンの直上に固定する。
  ///
  /// iPad 11/13 の横、iPhone SE、および PR #109 で設計高さが 640 になる iPad 11 横を含む。
  /// iPhone 15/16 のセーフエリア込み（約 630）は含めず、特典→価格の並びは変えない。
  static const _pinPricesBelow = 600.0;

  /// 固定しない範囲でも、これ未満は特典の縦余白だけ詰めて価格と注記をボタンより上に収める。
  static const _tightenBelow = 720.0;

  /// これ以上の短い画面だけ、復元と規約を価格の下へ固定する。
  ///
  /// 幅 1.5 倍のテスト画面（高さ 600）は本文が約 280 で、ここへ足すと
  /// 特典のリンクが押せなくなる。iPhone SE と iPad の横は本文がこれを超える。
  static const _pinLegalAt = 380.0;

  /// 価格バッジはカードの上にはみ出す。短い画面で特典がそこで切れると、
  /// 最終行がバッジに接する。この分だけ特典の領域を短くし、価格は動かさない。
  static const _badgeClearance = 16.0;

  bool _busy = false;
  bool _loadingPrices = true;
  SubscriptionOfferings? _offerings;

  /// 見えている特典の行が途中で切れてバッジに接しないよう、追加で空ける量。
  double _foldClearance = 0;
  double? _snapHeight;
  int? _snapPlans;
  BuildContext? _benefitScrollContext;

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

  /// 短い画面で、ビューポートの下端を横切る行は丸ごと次のスクロールへ送る。
  ///
  /// 固定の余白だけだと、機種によって最終行の上半分がバッジの直前に残る。
  void _scheduleFoldSnap() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final scrollContext = _benefitScrollContext;
      if (scrollContext == null || !scrollContext.mounted) {
        return;
      }
      final scroll = scrollContext.findRenderObject();
      if (scroll is! RenderBox || !scroll.hasSize || !scroll.attached) {
        return;
      }
      final viewportBottom = scroll
          .localToGlobal(Offset(0, scroll.size.height))
          .dy;
      double? cutScreen;
      var scale = 1.0;
      void visit(RenderObject node) {
        if (node is RenderParagraph && node.hasSize && node.size.height > 0) {
          final top = node.localToGlobal(Offset.zero).dy;
          final bottom = node.localToGlobal(Offset(0, node.size.height)).dy;
          final localScale = (bottom - top) / node.size.height;
          if (localScale.isFinite && localScale > 0) {
            scale = localScale;
          }
          if (top < viewportBottom - 1 && bottom > viewportBottom + 1) {
            if (cutScreen == null || top < cutScreen!) {
              cutScreen = top;
            }
          }
        }
        node.visitChildren(visit);
      }

      visit(scroll);
      if (cutScreen == null) {
        return;
      }
      final extra = (viewportBottom - cutScreen!) / scale;
      final next = (_foldClearance + extra).clamp(0.0, 48.0);
      if (next > _foldClearance + 0.5) {
        setState(() => _foldClearance = next);
      }
    });
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
          'entry_point': widget.feature == null
              ? 'settings'
              : 'gate_$featureName',
          'products_loaded': !_loadingPrices && _offerings != null,
        });
      case PlusFunnelEvent.planSelect:
        Analytics.emit('plan_select', {'product_id': planId});
      case PlusFunnelEvent.purchaseTap:
        Analytics.emit('purchase_tap', {
          'product_id': planId,
          'entry_point': widget.feature == null
              ? 'settings'
              : 'gate_$featureName',
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
    if (best) {
      return AppStrings.plusBadgeBestValue;
    }
    // 半年 ¥4,900 は月額6回 ¥5,880 よりちょうど1か月分安いので「1か月分お得」。
    final saving = monthly * months - amount;
    if (saving % monthly == 0) {
      return '${saving ~/ monthly}か月分お得';
    }
    return AppStrings.plusBadgeSave;
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
          freeTrialDays: _trialDays(offerings?.offerFor(plan)),
        ),
    ];
  }

  /// ストアの価格とお試しの両方があるときだけ。予備の価格では無料をうたわない。
  int? _trialDays(SubscriptionProductOffer? offer) {
    if (!_hasStorePrice(offer) || !offer!.hasFreeTrial) {
      return null;
    }
    return offer.freeTrialDays;
  }

  int? get _anyTrialDays {
    for (final plan in _loadingPrices ? const <_PlanOption>[] : _plans) {
      if (plan.hasFreeTrial) {
        return plan.freeTrialDays;
      }
    }
    return null;
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
        try {
          await widget.onPlusActive?.call();
        } catch (_) {}
        if (!mounted) {
          return;
        }
        _showMessage('購入しました');
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
      if (widget.repository.isPlusActive) {
        try {
          await widget.onPlusActive?.call();
        } catch (_) {}
      }
      if (!mounted) {
        return;
      }
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
      _showMessage('この環境ではカロナビ+を購入できません');
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

  void _openMoreFeatures() {
    showModalBottomSheet<void>(
      context: context,
      routeSettings: const RouteSettings(name: 'calonavi_plus_more_features'),
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: AppColors.bgPage,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => const _MoreFeaturesSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final plans = _loadingPrices ? const <_PlanOption>[] : _plans;
    final selectedPlan = plans.isEmpty ? null : _selectedPlan;

    return DesignPage(
      scrollable: false,
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
      bottomBar: selectedPlan == null
          ? null
          : SizedBox(
              width: double.infinity,
              child: DesignButton(
                key: const Key('plus-purchase'),
                label: selectedPlan.ctaLabel,
                showTrailingIcon: false,
                height: 58,
                loading: _busy,
                onPressed: _busy ? null : _confirm,
              ),
            ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final height = constraints.maxHeight;
          final pinPrices = height < _pinPricesBelow;
          final pinLegal = pinPrices && height >= _pinLegalAt;
          final tight = height < _tightenBelow;
          final benefits = _benefitColumn(tight: tight);
          final planCards = _planCards(plans);
          final note = selectedPlan == null ? null : _priceNote(selectedPlan);

          if (pinPrices) {
            // 価格と注記はボタン直上のまま。背の低い実機では復元と規約も固定する。
            // 長い説明は特典と一緒にスクロールする。
            if (_snapHeight != height || _snapPlans != plans.length) {
              _snapHeight = height;
              _snapPlans = plans.length;
              _foldClearance = 0;
            }
            _scheduleFoldSnap();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Builder(
                    builder: (scrollContext) {
                      _benefitScrollContext = scrollContext;
                      return SingleChildScrollView(
                        key: const Key('plus-paywall-scroll'),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            benefits,
                            if (pinLegal) _legalCopy() else _legalFooter(),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                SizedBox(height: _badgeClearance + _foldClearance),
                planCards,
                ?note,
                if (pinLegal) _legalActions(),
              ],
            );
          }

          return SingleChildScrollView(
            key: const Key('plus-paywall-scroll'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [benefits, planCards, ?note, _legalFooter()],
            ),
          );
        },
      ),
    );
  }

  Widget _benefitColumn({required bool tight}) {
    final benefitPadding = tight ? AppSpacing.xxs : AppSpacing.xs;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: IconCircle(
            size: 64,
            tone: IconCircleTone.green,
            child: const DesignIcon(
              Symbols.workspace_premium_rounded,
              size: 32,
              color: AppColors.iconPrimary,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'カロナビ+',
          textAlign: TextAlign.center,
          style: AppTypography.headingL,
        ),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          AppStrings.plusHeroSubtitle,
          textAlign: TextAlign.center,
          style: AppTypography.bodyM,
        ),
        SizedBox(height: tight ? AppSpacing.sm : AppSpacing.md),
        _HeroBenefit(
          icon: Symbols.photo_camera_rounded,
          title: AppStrings.plusBenefitPhotoTitle,
          body: AppStrings.plusHeroPhotoBody,
          verticalPadding: benefitPadding,
        ),
        _HeroBenefit(
          icon: Symbols.search_rounded,
          title: AppStrings.plusBenefitAiSearchTitle,
          body: AppStrings.plusHeroAiSearchBody,
          verticalPadding: benefitPadding,
        ),
        _HeroBenefit(
          icon: Symbols.person_rounded,
          title: AppStrings.plusBenefitCoachTitle,
          body: AppStrings.plusHeroCoachBody,
          verticalPadding: benefitPadding,
        ),
        _HeroBenefit(
          icon: Symbols.widgets_rounded,
          title: AppStrings.plusBenefitWidgetTitle,
          body: AppStrings.plusHeroWidgetBody,
          verticalPadding: benefitPadding,
        ),
        Center(
          child: TextButton(
            key: const Key('plus-more-features'),
            onPressed: _openMoreFeatures,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    AppStrings.plusMoreFeaturesLink,
                    style: AppTypography.titleS.copyWith(
                      color: AppColors.textBrand,
                    ),
                  ),
                ),
                const DesignIcon(
                  Symbols.chevron_right_rounded,
                  size: 20,
                  color: AppColors.textBrand,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _planCards(List<_PlanOption> plans) {
    if (_loadingPrices) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return IntrinsicHeight(
      key: const Key('plus-plans'),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < plans.length; i++) ...[
            if (i > 0) const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: _PlanCard(
                key: Key('plus-plan-${plans[i].plan.name}'),
                option: plans[i],
                selected: plans[i].plan == _selected,
                onTap: _busy
                    ? null
                    : () {
                        setState(() => _selected = plans[i].plan);
                        _record(
                          PlusFunnelEvent.planSelect,
                          productId: SubscriptionCatalog.planKeyFor(
                            plans[i].plan,
                          ),
                        );
                      },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _priceNote(_PlanOption plan) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text(
        plan.ctaNote,
        key: const Key('plus-cta-note'),
        textAlign: TextAlign.center,
        style: AppTypography.labelS,
      ),
    );
  }

  Widget _legalFooter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [..._restoreBlock(), _legalCopy(), ..._legalLinkBlock()],
    );
  }

  /// 短い画面で、価格と購入ボタンのあいだに残す操作。
  ///
  /// 本文が 300pt を切るテスト画面でもはみ出さないよう、ボタンの最低高は付けない。
  Widget _legalActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: TextButton(
            key: const Key('plus-restore'),
            onPressed: _busy ? null : _restore,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 2),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              '購入を復元',
              style: AppTypography.titleS.copyWith(color: AppColors.textBrand),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xxs),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.xxs,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _LegalLink(label: '利用規約', document: LegalDocument.terms),
            _LegalLink(label: 'プライバシーポリシー', document: LegalDocument.privacy),
            _LegalLink(
              label: '特定商取引法に基づく表記',
              document: LegalDocument.tokushoho,
            ),
          ],
        ),
      ],
    );
  }

  List<Widget> _restoreBlock() {
    return [
      const SizedBox(height: AppSpacing.xs),
      Center(
        child: TextButton(
          key: const Key('plus-restore'),
          onPressed: _busy ? null : _restore,
          child: Text(
            '購入を復元',
            style: AppTypography.titleS.copyWith(color: AppColors.textBrand),
          ),
        ),
      ),
    ];
  }

  Widget _legalCopy() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppSpacing.xs),
        Text(AppStrings.plusBillingPeriod, style: _legalStyle),
        const SizedBox(height: AppSpacing.xxs),
        Text(AppStrings.plusAutoRenew, style: _legalStyle),
        if (_anyTrialDays case final trialDays?) ...[
          const SizedBox(height: AppSpacing.xxs),
          Text(
            AppStrings.plusTrialNotice(trialDays),
            key: const Key('plus-trial-notice'),
            style: _legalStyle,
          ),
        ],
        const SizedBox(height: AppSpacing.xxs),
        Text(AppStrings.plusCancelHow, style: _legalStyle),
        if (_activeExpiryLabel case final expiryLabel?) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(expiryLabel, style: AppTypography.bodyS),
        ],
      ],
    );
  }

  List<Widget> _legalLinkBlock() {
    return [
      const SizedBox(height: AppSpacing.sm),
      Wrap(
        alignment: WrapAlignment.center,
        spacing: AppSpacing.md,
        runSpacing: AppSpacing.xs,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _LegalLink(label: '利用規約', document: LegalDocument.terms),
          _LegalLink(label: 'プライバシーポリシー', document: LegalDocument.privacy),
          _LegalLink(label: '特定商取引法に基づく表記', document: LegalDocument.tokushoho),
        ],
      ),
      const SizedBox(height: AppSpacing.md),
    ];
  }
}

final TextStyle _legalStyle = AppTypography.labelS.copyWith(
  fontWeight: FontWeight.w400,
  height: 1.5,
  color: AppColors.textMuted,
);

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

/// 課金画面の大きい1行（アイコン・機能名・短い説明）。シートでも使う。
class _HeroBenefit extends StatelessWidget {
  const _HeroBenefit({
    required this.icon,
    required this.title,
    required this.body,
    this.detail,
    this.verticalPadding = AppSpacing.xs,
  });

  final IconData icon;
  final String title;
  final String body;
  final String? detail;
  final double verticalPadding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: verticalPadding),
      child: Row(
        crossAxisAlignment: detail == null
            ? CrossAxisAlignment.center
            : CrossAxisAlignment.start,
        children: [
          IconCircle(
            size: 44,
            tone: IconCircleTone.green,
            child: DesignIcon(icon, size: 22, color: AppColors.iconPrimary),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTypography.titleM.copyWith(height: 1.4)),
                Text(body, style: AppTypography.bodyS.copyWith(height: 1.45)),
                if (detail case final detail?) ...[
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.xs),
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
      ),
    );
  }
}

/// 「その他の機能を見る」で開くシート。大きく出した4つ以外の機能。
class _MoreFeaturesSheet extends StatelessWidget {
  const _MoreFeaturesSheet();

  static const _rows = [
    (
      Symbols.bookmark_rounded,
      AppStrings.plusMoreTemplateTitle,
      AppStrings.plusMoreTemplateBody,
    ),
    (
      Symbols.mic_rounded,
      AppStrings.plusBenefitSiriTitle,
      AppStrings.plusBenefitSiriBody,
    ),
    (
      Symbols.storefront_rounded,
      AppStrings.plusBenefitEatingOutTitle,
      AppStrings.plusMoreEatingOutBody,
    ),
    (
      Symbols.info_rounded,
      AppStrings.plusAiLimitTitle,
      AppStrings.plusMoreAiLimitBody,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        key: const Key('plus-more-features-sheet'),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenHorizontal,
          0,
          AppSpacing.screenHorizontal,
          AppSpacing.md,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              AppStrings.plusMoreFeaturesTitle,
              textAlign: TextAlign.center,
              style: AppTypography.headingS,
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              AppStrings.plusMoreFeaturesLead,
              textAlign: TextAlign.center,
              style: AppTypography.bodyS,
            ),
            const SizedBox(height: AppSpacing.sm),
            for (var i = 0; i < _rows.length; i++) ...[
              if (i > 0)
                const Divider(
                  height: 1,
                  indent: 56,
                  color: AppColors.borderDefault,
                ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: _HeroBenefit(
                  icon: _rows[i].$1,
                  title: _rows[i].$2,
                  body: _rows[i].$3,
                  // 音声登録は、登録できる話し方の2文をそのまま添える。
                  detail: _rows[i].$2 == AppStrings.plusBenefitSiriTitle
                      ? AppStrings.siriVoicePaidGuidance
                      : null,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            DesignButton(
              key: const Key('plus-more-features-close'),
              label: AppStrings.plusMoreFeaturesClose,
              showTrailingIcon: false,
              height: 56,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}

/// 3枚横並びのプラン。期間・大きい金額・月あたり・バッジ・選択の印。
class _PlanCard extends StatelessWidget {
  const _PlanCard({
    super.key,
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final _PlanOption option;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? AppColors.green900 : AppColors.neutral900;
    final card = Material(
      color: selected ? AppColors.bgSurfaceGreenSoft : AppColors.bgSurface,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.input,
        side: BorderSide(
          color: selected ? AppColors.borderFocus : AppColors.borderDefault,
          width: selected ? 2 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(6, 8, 6, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: _SelectMark(selected: selected),
              ),
              const SizedBox(height: 2),
              Text(
                plusPlanLabel(option.plan),
                textAlign: TextAlign.center,
                style: AppTypography.titleS.copyWith(color: foreground),
              ),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  option.price,
                  maxLines: 1,
                  style: TextStyle(
                    fontFamily: AppTypography.fontFamily,
                    fontSize: selected ? 27 : 25,
                    fontWeight: FontWeight.w700,
                    height: 1.3,
                    color: foreground,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              if (option.note.isNotEmpty)
                Text(
                  option.note,
                  textAlign: TextAlign.center,
                  style: AppTypography.labelS.copyWith(
                    color: selected
                        ? AppColors.textBrand
                        : AppColors.textSecondary,
                    fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    return Semantics(
      button: true,
      selected: selected,
      label: '${plusPlanLabel(option.plan)} ${option.price}',
      child: Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Stack(
          fit: StackFit.expand,
          clipBehavior: Clip.none,
          children: [
            card,
            if (option.badgeLabel case final badge?)
              Positioned(
                top: -11,
                left: 4,
                right: 4,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: _PlanBadge(label: badge),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SelectMark extends StatelessWidget {
  const _SelectMark({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    if (selected) {
      return Container(
        width: 20,
        height: 20,
        decoration: const BoxDecoration(
          color: AppColors.bgPrimary,
          shape: BoxShape.circle,
        ),
        child: const DesignIcon(
          Symbols.check_rounded,
          size: 14,
          color: AppColors.iconOnPrimary,
        ),
      );
    }
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.neutral300, width: 1.5),
      ),
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
        maxLines: 1,
        style: AppTypography.caption.copyWith(
          color: AppColors.textOnPrimary,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}
