import 'dart:async';

import 'package:flutter/material.dart';

import '../../config/official_foods_flag.dart';
import 'official_food_attribution_line.dart';
import '../../models/official_food.dart';
import '../../models/official_food_list_label.dart';
import '../../repositories/official_food_repository.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_icons.dart';
import '../../theme/app_typography.dart';
import '../../utils/nutrition_format.dart';
import '../design/settings_row.dart';

/// 既存の食品検索の下に出す食品成分表の候補。
///
/// フラグがオフのとき、通信が失敗したとき、該当がないときは何も出さない。
class OfficialFoodSearchSection extends StatefulWidget {
  const OfficialFoodSearchSection({
    super.key,
    required this.query,
    required this.onSelected,
    this.onSearched,
    this.repository,
    this.active = true,
    this.debounce = const Duration(milliseconds: 250),
  });

  final TextEditingController query;
  final ValueChanged<OfficialFoodMatch> onSelected;

  /// デバウンス後に実際へ渡した検索語。結果は渡さない。
  final ValueChanged<String>? onSearched;
  final OfficialFoodRepository? repository;
  final bool active;
  final Duration debounce;

  @override
  State<OfficialFoodSearchSection> createState() =>
      _OfficialFoodSearchSectionState();
}

class _OfficialFoodSearchSectionState extends State<OfficialFoodSearchSection> {
  List<OfficialFoodMatch> _results = const [];
  Timer? _timer;
  int _request = 0;
  String? _scheduledQuery;
  bool _inFlight = false;
  String? _pendingQuery;

  @override
  void initState() {
    super.initState();
    widget.query.addListener(_schedule);
    _schedule();
  }

  @override
  void didUpdateWidget(OfficialFoodSearchSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.query != widget.query) {
      oldWidget.query.removeListener(_schedule);
      widget.query.addListener(_schedule);
    }
    if (oldWidget.active != widget.active ||
        oldWidget.repository != widget.repository) {
      _scheduledQuery = null;
      _schedule();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    widget.query.removeListener(_schedule);
    super.dispose();
  }

  void _schedule() {
    _timer?.cancel();
    if (!widget.active || !OfficialFoodsFlag.enabled) {
      _scheduledQuery = null;
      _pendingQuery = null;
      _request++;
      if (_results.isNotEmpty && mounted) {
        setState(() => _results = const []);
      }
      return;
    }
    final query = widget.query.text.trim();
    // カーソル移動でもコントローラは通知する。同じ語の再検索はしない。
    if (query == _scheduledQuery) {
      return;
    }
    _scheduledQuery = query;
    if (query.isEmpty) {
      _pendingQuery = null;
      _request++;
      if (_results.isNotEmpty && mounted) {
        setState(() => _results = const []);
      }
      return;
    }
    _timer = Timer(widget.debounce, () => unawaited(_search(query)));
  }

  Future<void> _search(String query) async {
    if (_inFlight) {
      _pendingQuery = query;
      return;
    }
    _inFlight = true;
    final repository = widget.repository ?? SupabaseOfficialFoodRepository();
    final token = ++_request;
    widget.onSearched?.call(query);
    try {
      final rows = await repository.search(query);
      if (!mounted || token != _request) {
        return;
      }
      if (widget.query.text.trim() != query) {
        return;
      }
      setState(() => _results = rows);
    } finally {
      _inFlight = false;
      final pending = _pendingQuery;
      _pendingQuery = null;
      if (pending != null && pending != query && mounted) {
        await _search(pending);
      }
    }
  }

  String _subtitle(OfficialFoodMatch match) {
    final amount =
        '${formatNullableNutrient(match.kcal)} kcal / ${match.baseAmount.toStringAsFixed(0)}g';
    final category = match.listCategory;
    if (category.isEmpty) {
      return amount;
    }
    return '$category${OfficialFoodListLabel.categoryKcalSeparator}$amount';
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active || !OfficialFoodsFlag.enabled || _results.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '分類',
          style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 8),
        for (final match in _results) ...[
          SettingsRow(
            icon: AppIcons.rice,
            title: match.isCandidate
                ? '${match.listTitle}（候補）'
                : match.listTitle,
            subtitle: _subtitle(match),
            onTap: () => widget.onSelected(match),
          ),
          const OfficialFoodAttributionLine(),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}
