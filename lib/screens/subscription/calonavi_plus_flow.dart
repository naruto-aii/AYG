import 'package:flutter/material.dart';

import '../../constants/app_strings.dart';
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

/// プラン1枚分の表示とその購入アクションをまとめたもの。
class _PlanOption {
  const _PlanOption({
    required this.period,
    required this.offer,
    required this.note,
    required this.purchase,
    this.badgeLabel,
  });

  final PlusBillingPeriod period;
  final SubscriptionProductOffer offer;
  final String note;
  final String? badgeLabel;
  final Future<void> Function() purchase;
}

class _CalonaviPlusEntryScreenState extends State<CalonaviPlusEntryScreen> {
  bool _busy = false;
  bool _loadingPrices = true;
  SubscriptionOfferings? _offerings;
  PlusBillingPeriod? _selectedPeriod;

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
      _selectedPeriod = _defaultSelection(offerings);
    });
  }

  /// 一番お得な期間を初期選択にする（年額 › 半年 › 月額）。
  PlusBillingPeriod? _defaultSelection(SubscriptionOfferings offerings) {
    if (offerings.yearly?.canPurchase ?? false) {
      return PlusBillingPeriod.year;
    }
    if (offerings.semiannual?.canPurchase ?? false) {
      return PlusBillingPeriod.semiannual;
    }
    if (offerings.monthly?.canPurchase ?? false) {
      return PlusBillingPeriod.month;
    }
    return null;
  }

  List<_PlanOption> get _plans {
    final offerings = _offerings;
    if (offerings == null) {
      return const [];
    }
    final plans = <_PlanOption>[];
    final monthly = offerings.monthly;
    if (monthly != null && monthly.canPurchase) {
      plans.add(
        _PlanOption(
          period: PlusBillingPeriod.month,
          offer: monthly,
          note: AppStrings.plusMonthlyNote,
          purchase: widget.repository.purchaseMonthly,
        ),
      );
    }
    final semiannual = offerings.semiannual;
    if (semiannual != null && semiannual.canPurchase) {
      plans.add(
        _PlanOption(
          period: PlusBillingPeriod.semiannual,
          offer: semiannual,
          note: AppStrings.plusSemiannualNote,
          badgeLabel: AppStrings.plusBadgeSave,
          purchase: widget.repository.purchaseSemiannual,
        ),
      );
    }
    final yearly = offerings.yearly;
    if (yearly != null && yearly.canPurchase) {
      plans.add(
        _PlanOption(
          period: PlusBillingPeriod.year,
          offer: yearly,
          note: AppStrings.plusYearlyNote,
          badgeLabel: AppStrings.plusBadgeBestValue,
          purchase: widget.repository.purchaseYearly,
        ),
      );
    }
    return plans;
  }

  Future<void> _confirm() async {
    final plans = _plans;
    final period = _selectedPeriod;
    if (period == null || plans.isEmpty) {
      return;
    }
    _PlanOption? selected;
    for (final plan in plans) {
      if (plan.period == period) {
        selected = plan;
        break;
      }
    }
    selected ??= plans.first;
    await _purchase(selected.purchase);
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
    final plans = _plans;
    final selected = _selectedPeriod;
    _PlanOption? selectedPlan;
    for (final plan in plans) {
      if (plan.period == selected) {
        selectedPlan = plan;
        break;
      }
    }
    final ctaEnabled = !_busy && selectedPlan != null;
    final ctaLabel = selectedPlan == null
        ? 'カロナビ+を始める'
        : '${selectedPlan.offer.localizedPrice}${AppStrings.plusCtaPrefix}';

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
              key: const Key('calonavi-plus-cta'),
              label: ctaLabel,
              showTrailingIcon: false,
              loading: _busy,
              onPressed: ctaEnabled ? _confirm : null,
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
          const SizedBox(height: AppSpacing.lg),
          if (_loadingPrices)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (plans.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: Text(
                '価格を取得できませんでした',
                textAlign: TextAlign.center,
                style: AppTypography.bodyS,
              ),
            )
          else ...[
            Text('プランを選ぶ', style: AppTypography.titleM),
            const SizedBox(height: AppSpacing.sm),
            for (var i = 0; i < plans.length; i++) ...[
              if (i > 0) const SizedBox(height: AppSpacing.sm),
              SelectCard(
                key: Key('calonavi-plus-plan-${plans[i].period.name}'),
                title: plusPeriodLabel(plans[i].period),
                description:
                    '${plans[i].offer.localizedPrice} ・ ${plans[i].note}',
                selected: plans[i].period == selected,
                minHeight: 84,
                badge: plans[i].badgeLabel == null
                    ? null
                    : _PlanBadge(label: plans[i].badgeLabel!),
                onTap: _busy
                    ? null
                    : () => setState(() => _selectedPeriod = plans[i].period),
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

  /// 使い方の例など、補足として小さく出す文章。
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
