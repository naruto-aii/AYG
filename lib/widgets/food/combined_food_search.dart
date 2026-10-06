import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/official_food.dart';
import '../../models/official_food_list_label.dart';
import '../../models/public_food_search_match.dart';
import '../../models/saved_food.dart';
import '../../repositories/official_food_repository.dart';
import '../../services/usage_record.dart';
import '../../state/app_controller.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_icons.dart';
import '../../theme/app_typography.dart';
import '../../utils/nutrition_format.dart';
import '../design/settings_row.dart';
import '../official_food/official_food_attribution_line.dart';

/// 食事登録の「探す」とテンプレートの「食品検索」が共有する検索結果。
///
/// 入力に応じて、保存済み・食品成分表・公開食品を見出し付きでまとめて出す。
class CombinedFoodSearch extends StatefulWidget {
  const CombinedFoodSearch({
    super.key,
    required this.controller,
    required this.query,
    this.officialFoods,
    this.searchSaved,
    this.searchOfficial,
    this.searchPublic,
    this.onSavedFood,
    this.onOfficialFood,
    this.onPublicFood,
    this.handle,
    this.debounce = const Duration(milliseconds: 250),
  });

  static const hint = '食品名を入れると、保存済み・定番の食品・公開食品から候補が出ます。';
  static const emptyMessage = '該当する食品が見つかりませんでした';
  static const savedHeading = '保存済み';
  static const officialHeading = '定番の食品';
  static const publicHeading = '公開食品';
  static const savedError = '保存済み食品の検索に失敗しました';
  static const officialError = '定番の食品の検索に失敗しました';
  static const publicError = '公開食品の検索に失敗しました';
  static const loadingLabel = '検索中';

  final AppController controller;
  final TextEditingController query;
  final OfficialFoodRepository? officialFoods;
  final Future<List<SavedFood>> Function(String query)? searchSaved;
  final Future<OfficialFoodSearchResult> Function(String query)? searchOfficial;
  final Future<List<PublicFoodSearchMatch>> Function(String query)?
  searchPublic;
  final ValueChanged<SavedFood>? onSavedFood;
  final ValueChanged<OfficialFoodMatch>? onOfficialFood;
  final ValueChanged<PublicFoodSearchMatch>? onPublicFood;

  /// 公開食品の作成者を結果から外す。
  final CombinedFoodSearchHandle? handle;
  final Duration debounce;

  @override
  State<CombinedFoodSearch> createState() => _CombinedFoodSearchState();
}

/// [CombinedFoodSearch] の結果から、特定の公開者を隠す。
class CombinedFoodSearchHandle {
  void Function(String ownerUserId)? _hideOwner;

  void hideOwner(String ownerUserId) {
    _hideOwner?.call(ownerUserId);
  }
}

class _CombinedFoodSearchState extends State<CombinedFoodSearch> {
  List<SavedFood> _saved = const [];
  List<OfficialFoodMatch> _official = const [];
  List<PublicFoodSearchMatch> _public = const [];
  String? _savedError;
  String? _officialError;
  String? _publicError;
  bool _loading = false;
  Timer? _timer;
  int _generation = 0;
  final _hiddenOwners = <String>{};

  @override
  void initState() {
    super.initState();
    widget.handle?._hideOwner = _hideOwner;
    widget.query.addListener(_schedule);
  }

  @override
  void didUpdateWidget(CombinedFoodSearch oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.handle != widget.handle) {
      oldWidget.handle?._hideOwner = null;
      widget.handle?._hideOwner = _hideOwner;
    }
    if (oldWidget.query != widget.query) {
      oldWidget.query.removeListener(_schedule);
      widget.query.addListener(_schedule);
      _schedule();
    }
  }

  @override
  void dispose() {
    widget.handle?._hideOwner = null;
    _timer?.cancel();
    widget.query.removeListener(_schedule);
    super.dispose();
  }

  void _hideOwner(String ownerUserId) {
    if (!mounted) {
      return;
    }
    setState(() => _hiddenOwners.add(ownerUserId));
  }

  void _schedule() {
    _timer?.cancel();
    final query = widget.query.text.trim();
    if (query.isEmpty) {
      _generation++;
      if (_loading ||
          _saved.isNotEmpty ||
          _official.isNotEmpty ||
          _public.isNotEmpty ||
          _savedError != null ||
          _officialError != null ||
          _publicError != null) {
        setState(() {
          _loading = false;
          _saved = const [];
          _official = const [];
          _public = const [];
          _savedError = null;
          _officialError = null;
          _publicError = null;
        });
      }
      return;
    }
    _timer = Timer(widget.debounce, () => unawaited(_search(query)));
  }

  Future<void> _search(String query) async {
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _saved = const [];
      _official = const [];
      _public = const [];
      _savedError = null;
      _officialError = null;
      _publicError = null;
    });

    final savedFuture = _loadSaved(query);
    final officialFuture = _loadOfficial(query);
    final publicFuture = _loadPublic(query);
    final saved = await savedFuture;
    final official = await officialFuture;
    final public = await publicFuture;
    if (!mounted || generation != _generation) {
      return;
    }
    if (widget.query.text.trim() != query) {
      return;
    }
    setState(() {
      _loading = false;
      _saved = saved.rows;
      _savedError = saved.error;
      _official = official.matches;
      _officialError = official.failed
          ? CombinedFoodSearch.officialError
          : null;
      _public = public.rows;
      _publicError = public.error;
    });
  }

  Future<({List<SavedFood> rows, String? error})> _loadSaved(
    String query,
  ) async {
    try {
      final search = widget.searchSaved;
      final rows = search != null
          ? await search(query)
          : await widget.controller.searchOwnSavedFoods(query);
      return (rows: rows, error: null);
    } catch (_) {
      return (rows: const <SavedFood>[], error: CombinedFoodSearch.savedError);
    }
  }

  Future<OfficialFoodSearchResult> _loadOfficial(String query) async {
    final search = widget.searchOfficial;
    if (search != null) {
      try {
        return await search(query);
      } catch (error) {
        return OfficialFoodSearchResult.failed(error);
      }
    }
    widget.controller.recordFoodSearch(
      source: FoodSearchSources.officialFood,
      query: query,
    );
    final repository = widget.officialFoods ?? SupabaseOfficialFoodRepository();
    if (repository is SupabaseOfficialFoodRepository) {
      return repository.searchReporting(query);
    }
    try {
      return OfficialFoodSearchResult(matches: await repository.search(query));
    } catch (error) {
      return OfficialFoodSearchResult.failed(error);
    }
  }

  Future<({List<PublicFoodSearchMatch> rows, String? error})> _loadPublic(
    String query,
  ) async {
    try {
      final search = widget.searchPublic;
      final rows = search != null
          ? await search(query)
          : await widget.controller.searchPublicSavedFoods(
              query,
              surfaceErrors: true,
            );
      return (rows: rows, error: null);
    } catch (_) {
      return (
        rows: const <PublicFoodSearchMatch>[],
        error: CombinedFoodSearch.publicError,
      );
    }
  }

  String _officialSubtitle(OfficialFoodMatch match) {
    final amount =
        '${formatNullableNutrient(match.kcal)} kcal / ${match.baseAmount.toStringAsFixed(0)}g';
    final category = match.listCategory;
    if (category.isEmpty) {
      return amount;
    }
    return '$category${OfficialFoodListLabel.categoryKcalSeparator}$amount';
  }

  List<PublicFoodSearchMatch> get _visiblePublic {
    return [
      for (final match in _public)
        if (!_hiddenOwners.contains(match.food.ownerUserId)) match,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final query = widget.query.text.trim();
    final muted = AppTypography.bodyS.copyWith(color: AppColors.textMuted);
    final public = _visiblePublic;
    final hasRows =
        _saved.isNotEmpty || _official.isNotEmpty || public.isNotEmpty;
    final hasError =
        _savedError != null || _officialError != null || _publicError != null;

    if (query.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Text(
          CombinedFoodSearch.hint,
          key: const Key('combined-food-search-hint'),
          textAlign: TextAlign.center,
          style: muted,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_loading)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              CombinedFoodSearch.loadingLabel,
              key: const Key('combined-food-search-loading'),
              textAlign: TextAlign.center,
              style: muted,
            ),
          ),
        if (_savedError != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(_savedError!, style: muted),
          ),
        if (_saved.isNotEmpty) ...[
          Text(CombinedFoodSearch.savedHeading, style: AppTypography.titleS),
          const SizedBox(height: 8),
          for (final food in _saved) ...[
            SettingsRow(
              icon: AppIcons.bookmark,
              title: food.name,
              subtitle:
                  '${widget.controller.formatSavedFoodBaseLabel(food)} ・ '
                  '${formatNullableNutrient(food.kcalPerBase)} kcal',
              onTap: widget.onSavedFood == null
                  ? null
                  : () => widget.onSavedFood!(food),
            ),
            const SizedBox(height: 8),
          ],
        ],
        if (_officialError != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(_officialError!, style: muted),
          ),
        if (_official.isNotEmpty) ...[
          Text(CombinedFoodSearch.officialHeading, style: AppTypography.titleS),
          const SizedBox(height: 8),
          for (final match in _official) ...[
            SettingsRow(
              icon: AppIcons.rice,
              title: match.isCandidate
                  ? '${match.listTitle}（候補）'
                  : match.listTitle,
              subtitle: _officialSubtitle(match),
              onTap: widget.onOfficialFood == null
                  ? null
                  : () => widget.onOfficialFood!(match),
            ),
            const SizedBox(height: 8),
          ],
          const OfficialFoodAttributionLine(),
          const SizedBox(height: 8),
        ],
        if (_publicError != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(_publicError!, style: muted),
          ),
        if (public.isNotEmpty) ...[
          Text(CombinedFoodSearch.publicHeading, style: AppTypography.titleS),
          const SizedBox(height: 8),
          for (final match in public) ...[
            SettingsRow(
              icon: AppIcons.meal,
              title: match.food.name,
              subtitle:
                  '${widget.controller.formatSavedFoodBaseLabel(match.food)} ・ '
                  '${formatNullableNutrient(match.food.kcalPerBase)} kcal',
              onTap: widget.onPublicFood == null
                  ? null
                  : () => widget.onPublicFood!(match),
            ),
            const SizedBox(height: 8),
          ],
        ],
        if (!_loading && !hasRows && !hasError)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text(
              CombinedFoodSearch.emptyMessage,
              key: const Key('combined-food-search-empty'),
              textAlign: TextAlign.center,
              style: muted,
            ),
          ),
      ],
    );
  }
}
