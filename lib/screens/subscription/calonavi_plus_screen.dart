import 'package:flutter/material.dart';

import '../../config/subscription_catalog.dart';
import '../../constants/app_strings.dart';
import '../../repositories/subscription_exceptions.dart';
import '../../repositories/subscription_repository.dart';
import '../../state/app_controller.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/primary_button.dart';
import '../../widgets/common/secondary_button.dart';
import '../../widgets/layout/app_content_constraint.dart';

Future<bool> guardPlusFeature({
  required BuildContext context,
  required AppController controller,
  required Future<void> Function() ensure,
}) async {
  try {
    await ensure();
    return true;
  } on SubscriptionLimitExceededException {
    if (context.mounted) {
      await showCalonaviPlus(context, controller.subscriptionRepository);
    }
    return false;
  }
}

Future<void> showCalonaviPlus(
  BuildContext context,
  SubscriptionRepository repository,
) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (context) => CalonaviPlusScreen(repository: repository),
    ),
  );
}

class CalonaviPlusScreen extends StatefulWidget {
  const CalonaviPlusScreen({super.key, required this.repository});

  final SubscriptionRepository repository;

  @override
  State<CalonaviPlusScreen> createState() => _CalonaviPlusScreenState();
}

class _CalonaviPlusScreenState extends State<CalonaviPlusScreen> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
      if (!mounted) {
        return;
      }
      if (widget.repository.isPlusActive && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    } on SubscriptionPurchaseUnavailableException {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.plusPurchaseUnavailable)),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$error')));
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final body = Theme.of(context).textTheme.bodyMedium;

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.plusTitle),
        leading: IconButton(
          tooltip: '閉じる',
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close),
        ),
      ),
      body: SafeArea(
        child: AppContentConstraint(
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              Text(AppStrings.plusLead, style: body),
              const SizedBox(height: AppSpacing.md),
              const AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('・公開食品検索が無制限'),
                    Text('・食事テンプレートが無制限'),
                    Text('・運動テンプレートが無制限'),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                AppStrings.plusFreeQuota,
                style: body?.copyWith(color: AppColors.secondaryText),
              ),
              const SizedBox(height: AppSpacing.lg),
              PrimaryButton(
                label: '${SubscriptionCatalog.monthlyLabel}で続ける',
                loading: _busy,
                onPressed: _busy
                    ? null
                    : () => _run(widget.repository.purchaseMonthly),
              ),
              SecondaryButton(
                label:
                    '${SubscriptionCatalog.yearlyLabel}（${SubscriptionCatalog.yearlySavingLabel}）',
                onPressed: _busy
                    ? null
                    : () => _run(widget.repository.purchaseYearly),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextButton(
                onPressed: _busy
                    ? null
                    : () => _run(widget.repository.restore),
                child: const Text(AppStrings.plusRestore),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                AppStrings.plusLegalNote,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
