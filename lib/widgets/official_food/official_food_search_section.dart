import 'dart:async';

import 'package:flutter/material.dart';

import '../../config/official_foods_flag.dart';
import '../../constants/official_food_copy.dart';
import '../../models/official_food.dart';
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
    this.repository,
    this.active = true,
    this.debounce = const Duration(milliseconds: 250),
  });

  final TextEditingController query;
  final ValueChanged<OfficialFoodMatch> onSelected;
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
      if (_results.isNotEmpty && mounted) {
        setState(() => _results = const []);
      }
      return;
    }
    final query = widget.query.text.trim();
    if (query.isEmpty) {
      if (_results.isNotEmpty && mounted) {
        setState(() => _results = const []);
      }
      return;
    }
    _timer = Timer(widget.debounce, () => _search(query));
  }

  Future<void> _search(String query) async {
    final repository = widget.repository ?? SupabaseOfficialFoodRepository();
    final token = ++_request;
    final rows = await repository.search(query);
    if (!mounted || token != _request) {
      return;
    }
    if (widget.query.text.trim() != query) {
      return;
    }
    setState(() => _results = rows);
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
          '食品成分表',
          style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 8),
        for (final match in _results) ...[
          SettingsRow(
            icon: AppIcons.rice,
            title: match.recordName,
            subtitle:
                '${formatNullableNutrient(match.kcal)} kcal / ${match.baseAmount.toStringAsFixed(0)}g ・ '
                '${OfficialFoodCopy.shortAttribution}',
            onTap: () => widget.onSelected(match),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}
