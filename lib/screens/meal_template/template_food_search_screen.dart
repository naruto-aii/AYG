import 'package:flutter/material.dart';

import '../../config/demo_mode.dart';
import '../../demo/demo_ai.dart';
import '../../models/official_food.dart';
import '../../models/saved_food.dart';
import '../../repositories/official_food_repository.dart';
import '../../repositories/plus_funnel_repository.dart';
import '../../services/ai_food_lookup_client.dart';
import '../../services/photo_meal.dart';
import '../../state/app_controller.dart';
import '../../theme/app_icons.dart';
import '../../widgets/design/design_field.dart';
import '../../widgets/design/design_page.dart';
import '../../widgets/design/settings_row.dart';
import '../../widgets/food/combined_food_search.dart';
import '../food/ai_food_lookup_screen.dart';
import '../food/chain_food_lookup_screen.dart';
import '../subscription/plus_gate.dart';

/// 食事テンプレートとウィジェットの食品選び。
///
/// 食事登録の「食品を探す」と同じ検索（保存済み・定番・公開・AI・外食）を使い、
/// 選んだ食品は食事には足さない。
class TemplateFoodSearchScreen extends StatefulWidget {
  const TemplateFoodSearchScreen({
    super.key,
    required this.controller,
    this.officialFoods,
    this.searchOverrides,
    this.aiLookup,
  });

  final AppController controller;
  final OfficialFoodRepository? officialFoods;
  final CombinedFoodSearchOverrides? searchOverrides;
  final AiFoodLookupClient? aiLookup;

  @override
  State<TemplateFoodSearchScreen> createState() =>
      _TemplateFoodSearchScreenState();
}

class _TemplateFoodSearchScreenState extends State<TemplateFoodSearchScreen> {
  final _queryController = TextEditingController();

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  AiFoodLookupClient? get _lookupClient =>
      widget.aiLookup ?? (calonaviDemoMode ? demoAiFoodLookupClient() : null);

  Future<void> _openChainLookup() async {
    final allowed = await ensureCalonaviPlus(
      context,
      widget.controller,
      message: '外食・コンビニは、カロナビ+です。店名と品名から、カロリーとPFCの推定を出します。',
      feature: PlusFunnelFeature.aiFoodLookup,
    );
    if (!allowed || !mounted) {
      return;
    }
    final picked = await Navigator.of(context).push<Object?>(
      MaterialPageRoute<Object?>(
        settings: const RouteSettings(name: 'chain_food_lookup'),
        builder: (context) => ChainFoodLookupScreen(
          controller: widget.controller,
          loggedAt: DateTime.now(),
          captureOnly: true,
          client: _lookupClient,
        ),
      ),
    );
    if (picked is ConfirmedFoodCapture && mounted) {
      Navigator.of(context).pop(picked);
    }
  }

  Future<void> _openAiLookup(String query) async {
    final picked = await captureAiFoodLookup(
      context: context,
      controller: widget.controller,
      query: query,
      loggedAt: DateTime.now(),
      client: _lookupClient,
    );
    if (picked != null && mounted) {
      Navigator.of(context).pop(picked);
    }
  }

  void _pickSaved(SavedFood food) {
    Navigator.of(context).pop(food);
  }

  void _pickOfficial(OfficialFoodMatch match) {
    Navigator.of(context).pop(match);
  }

  @override
  Widget build(BuildContext context) {
    final overrides = widget.searchOverrides;
    return DesignPage(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const DesignTitleBlock(
            title: '食品を検索',
            subtitle: '保存済み・定番の食品・公開食品から探せます。',
          ),
          DesignSearchField(
            key: const Key('template-food-search-field'),
            controller: _queryController,
            hintText: '食品名で検索',
          ),
          const SizedBox(height: 12),
          SettingsRow(
            key: const Key('chain-food-lookup-row'),
            icon: AppIcons.meal,
            title: chainFoodLookupTitle,
            subtitle: '店名と品名で推定',
            onTap: _openChainLookup,
          ),
          const SizedBox(height: 12),
          CombinedFoodSearch(
            controller: widget.controller,
            query: _queryController,
            officialFoods: overrides?.officialFoods ?? widget.officialFoods,
            searchSaved: overrides?.searchSaved,
            searchOfficial: overrides?.searchOfficial,
            searchPublic: overrides?.searchPublic,
            debounce: overrides?.debounce ?? const Duration(milliseconds: 250),
            onSavedFood: _pickSaved,
            onOfficialFood: _pickOfficial,
            onPublicFood: (match) => _pickSaved(match.food),
            onAiFoodLookup: _openAiLookup,
            onManualEntry: (query) => Navigator.of(context).pop(query),
            browseSavedWhenEmpty: true,
          ),
        ],
      ),
    );
  }
}
