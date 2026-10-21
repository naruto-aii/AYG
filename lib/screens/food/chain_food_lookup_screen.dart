import 'package:flutter/material.dart';

import '../../services/ai_food_lookup_client.dart';
import '../../services/photo_meal.dart';
import '../../state/app_controller.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../widgets/design/design_button.dart';
import '../../widgets/design/design_field.dart';
import '../../widgets/design/design_page.dart';
import 'ai_food_lookup_screen.dart';

const chainFoodLookupTitle = '外食・コンビニ';

/// 店名と品名を入れて、AIで探すと同じ推定へ進む。
class ChainFoodLookupScreen extends StatefulWidget {
  const ChainFoodLookupScreen({
    super.key,
    required this.controller,
    required this.loggedAt,
    this.client,
    this.captureOnly = false,
  });

  final AppController controller;
  final DateTime loggedAt;
  final AiFoodLookupClient? client;

  /// true のとき、推定は食事に保存せず確認内容だけ返す。
  final bool captureOnly;

  @override
  State<ChainFoodLookupScreen> createState() => _ChainFoodLookupScreenState();
}

class _ChainFoodLookupScreenState extends State<ChainFoodLookupScreen> {
  final _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final query = _query.text.trim();
    if (query.isEmpty) {
      return;
    }
    final picked = await Navigator.of(context).push<Object?>(
      MaterialPageRoute<Object?>(
        settings: const RouteSettings(name: 'chain_food_lookup_results'),
        builder: (context) => AiFoodLookupScreen(
          controller: widget.controller,
          query: query,
          loggedAt: widget.loggedAt,
          client: widget.client ?? AiFoodLookupClient.supabase(),
          title: chainFoodLookupTitle,
          captureOnly: widget.captureOnly,
        ),
      ),
    );
    if (!mounted || picked == null) {
      return;
    }
    if (widget.captureOnly) {
      if (picked is ConfirmedFoodCapture) {
        Navigator.of(context).pop(picked);
      }
      return;
    }
    if (picked == true) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ready = _query.text.trim().isNotEmpty;
    return DesignPage(
      bottomBar: DesignButton(
        label: '推定する',
        showTrailingIcon: false,
        onPressed: ready ? _submit : null,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const DesignTitleBlock(
            title: chainFoodLookupTitle,
            subtitle: '店名と品名を入れてください。',
          ),
          const SizedBox(height: AppSpacing.md),
          DesignInputBox(
            child: DesignTextInput(
              inputKey: const Key('chain-food-lookup-field'),
              controller: _query,
              hintText: '店名と商品名',
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '例）牛丼 大盛',
            style: AppTypography.bodyS.copyWith(color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}
