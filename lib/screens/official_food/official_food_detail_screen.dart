import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/official_food.dart';
import '../../services/official_food_logger.dart';
import '../../state/app_controller.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../utils/nutrition_format.dart';
import '../../widgets/design/design_button.dart';
import '../../widgets/design/design_page.dart';
import '../../widgets/official_food/official_food_attribution.dart';

/// 検索結果から詳細へ進む。
void openOfficialFoodDetail(
  BuildContext context,
  AppController controller,
  OfficialFoodMatch match,
) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (context) => OfficialFoodDetailScreen(
        match: match,
        controller: controller,
      ),
    ),
  );
}

/// 食品番号と成分表の食品名を残した詳細。
class OfficialFoodDetailScreen extends StatefulWidget {
  const OfficialFoodDetailScreen({
    super.key,
    required this.match,
    required this.controller,
    this.launch,
    this.logger = const OfficialFoodLogger(),
  });

  final OfficialFoodMatch match;
  final AppController controller;
  final Future<bool> Function(Uri uri, LaunchMode mode)? launch;
  final OfficialFoodLogger logger;

  @override
  State<OfficialFoodDetailScreen> createState() =>
      _OfficialFoodDetailScreenState();
}

class _OfficialFoodDetailScreenState extends State<OfficialFoodDetailScreen> {
  final _gramsController = TextEditingController(text: '100');
  bool _busy = false;

  @override
  void dispose() {
    _gramsController.dispose();
    super.dispose();
  }

  double? get _grams {
    final parsed = double.tryParse(_gramsController.text.trim());
    if (parsed == null || parsed <= 0) {
      return null;
    }
    return parsed;
  }

  Future<void> _recordMeal() async {
    final grams = _grams;
    if (grams == null || _busy) {
      return;
    }
    setState(() => _busy = true);
    try {
      final entry = widget.logger.buildEntry(
        match: widget.match,
        entryId: widget.controller.generateId(),
        grams: grams,
        loggedAt: DateTime.now(),
      );
      await widget.controller.addFood(entry);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('食事に記録しました')));
      Navigator.of(context).pop();
    } catch (error) {
      _showError('記録に失敗しました: $error');
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _savePrivateCopy() async {
    if (_busy) {
      return;
    }
    setState(() => _busy = true);
    try {
      await widget.controller.createSavedFood(
        widget.logger.buildDraft(widget.match),
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('マイ食品に保存しました')));
    } catch (error) {
      _showError('保存に失敗しました: $error');
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  void _showError(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final match = widget.match;
    final grams = _grams;
    final base = match.baseAmount <= 0 ? 100.0 : match.baseAmount;
    final logger = widget.logger;
    final muted = AppTypography.bodyS.copyWith(color: AppColors.textMuted);

    return DesignPage(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DesignTitleBlock(
            title: match.recordName,
            subtitle: '食品番号 ${match.foodCode}',
          ),
          Text(match.name, style: AppTypography.bodyM),
          if (match.isCandidate) ...[
            const SizedBox(height: 8),
            Text(
              '候補の一つです。食品名を確認してから選んでください。',
              style: AppTypography.bodyS.copyWith(color: AppColors.textMuted),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            '${formatNullableNutrient(match.kcal, fractionDigits: 1)} kcal ・ '
            'たんぱく質 ${formatNullableNutrient(match.proteinG, fractionDigits: 1)} g ・ '
            '脂質 ${formatNullableNutrient(match.fatG, fractionDigits: 1)} g ・ '
            '炭水化物 ${formatNullableNutrient(match.carbG, fractionDigits: 1)} g'
            ' / ${base.toStringAsFixed(0)}g',
            style: muted,
          ),
          const SizedBox(height: 16),
          Text('量 (g)', style: AppTypography.caption),
          const SizedBox(height: 6),
          TextField(
            key: const ValueKey('official_food_grams'),
            controller: _gramsController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(hintText: '100'),
          ),
          if (grams != null) ...[
            const SizedBox(height: 8),
            Text(
              'この量: ${formatNullableNutrient(logger.scaled(match.kcal, grams, base), fractionDigits: 1)} kcal',
              style: AppTypography.bodyS,
            ),
          ],
          const SizedBox(height: 16),
          OfficialFoodAttribution(launch: widget.launch),
          const SizedBox(height: 16),
          DesignButton(
            label: 'この量で食事に記録',
            showTrailingIcon: false,
            height: 52,
            loading: _busy,
            onPressed: grams == null || _busy ? null : _recordMeal,
          ),
          const SizedBox(height: 8),
          DesignButton(
            label: 'マイ食品に保存',
            style: DesignButtonStyle.outline,
            showTrailingIcon: false,
            height: 52,
            onPressed: _busy ? null : _savePrivateCopy,
          ),
        ],
      ),
    );
  }
}
