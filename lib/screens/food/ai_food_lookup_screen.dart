import 'package:flutter/material.dart';

import '../../repositories/plus_funnel_repository.dart';
import '../../services/ai_food_lookup.dart';
import '../../services/ai_food_lookup_client.dart';
import '../../services/photo_meal.dart';
import '../../services/photo_meal_client.dart';
import '../../state/app_controller.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../widgets/design/design_card.dart';
import '../../widgets/design/design_page.dart';
import '../subscription/plus_gate.dart';
import 'photo_meal_confirm_screen.dart';

const aiFoodLookupEstimateTitle = 'AIによる推定';
const aiFoodLookupEstimateSubtitle = '登録の前に確認して、数値を直せます。';
const aiFoodLookupKnownProductNote = '店や商品の名前のようです。数値はAIによる推定です。';

/// カロナビ+のあと、検索語の推定を開く。食事を保存したら true。
Future<bool> openAiFoodLookup({
  required BuildContext context,
  required AppController controller,
  required String query,
  required DateTime loggedAt,
  AiFoodLookupClient? client,
}) async {
  final allowed = await ensureCalonaviPlus(
    context,
    controller,
    message: 'AIで探す (β) は、カロナビ+です。食品名から、カロリーとPFCの推定を出します。',
    feature: PlusFunnelFeature.aiFoodLookup,
  );
  if (!allowed || !context.mounted) {
    return false;
  }
  final saved = await Navigator.of(context).push<bool>(
    MaterialPageRoute<bool>(
      settings: const RouteSettings(name: 'ai_food_lookup'),
      builder: (context) => AiFoodLookupScreen(
        controller: controller,
        query: query,
        loggedAt: loggedAt,
        client: client ?? AiFoodLookupClient.supabase(),
      ),
    ),
  );
  return saved == true;
}

/// 候補を出して、選んだ1件を写真で登録と同じ確認画面で保存する。
class AiFoodLookupScreen extends StatefulWidget {
  const AiFoodLookupScreen({
    super.key,
    required this.controller,
    required this.query,
    required this.loggedAt,
    required this.client,
  });

  final AppController controller;
  final String query;
  final DateTime loggedAt;
  final AiFoodLookupClient client;

  @override
  State<AiFoodLookupScreen> createState() => _AiFoodLookupScreenState();
}

class _AiFoodLookupScreenState extends State<AiFoodLookupScreen> {
  AiFoodLookupResult? _result;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final result = await widget.client.lookup(widget.query);
      if (!mounted) {
        return;
      }
      setState(() {
        _result = result;
        _loading = false;
      });
    } on PhotoMealFailure catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error.message;
        _loading = false;
      });
    }
  }

  Future<void> _open(AiFoodCandidate candidate) async {
    final result = _result;
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        settings: const RouteSettings(name: 'ai_food_lookup_confirm'),
        builder: (context) => PhotoMealConfirmScreen(
          controller: widget.controller,
          loggedAt: widget.loggedAt,
          hadUserDishName: candidate.name.trim().isNotEmpty,
          title: aiFoodLookupEstimateTitle,
          subtitle: aiFoodLookupEstimateSubtitle,
          analysis: PhotoMealAnalysis(
            usageId: result?.usageId,
            estimate: candidate.toEstimate(),
          ),
          recordEdit: (usageId, edited) {
            return recordAiFoodLookupOutcome(usageId: usageId, edited: edited);
          },
        ),
      ),
    );
    if (saved == true && mounted) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    return DesignPage(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const DesignTitleBlock(
            title: aiFoodLookupEstimateTitle,
            subtitle: '候補は3件までです。選んでから、数値を直せます。',
          ),
          const SizedBox(height: AppSpacing.md),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            Text(_error!, style: AppTypography.bodyM)
          else if (result != null)
            for (final candidate in result.candidates) ...[
              DesignCard(
                onTap: () => _open(candidate),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(candidate.name, style: AppTypography.titleS),
                    const SizedBox(height: 4),
                    Text(
                      '${candidate.amount} · ${formatPhotoNumber(candidate.kcal)}kcal',
                      style: AppTypography.bodyS.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                    Text(
                      'P ${formatPhotoNumber(candidate.proteinG)} · F ${formatPhotoNumber(candidate.fatG)} · C ${formatPhotoNumber(candidate.carbG)}',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                    if (candidate.knownProduct) ...[
                      const SizedBox(height: 4),
                      Text(
                        aiFoodLookupKnownProductNote,
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
        ],
      ),
    );
  }
}
