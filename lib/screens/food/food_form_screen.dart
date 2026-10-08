import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart' show Symbols;

import '../../models/food_visibility.dart';
import '../../models/duplicate_saved_food_resolution.dart';
import '../../models/food_entry.dart';
import '../../models/food_entry_source.dart';
import '../../models/food_source_type.dart';
import '../../models/food_unit_type.dart';
import '../../models/macro_field.dart';
import '../../models/food_form_suggestion.dart';
import '../../models/meal_template.dart';
import '../../models/saved_food.dart';
import '../../models/saved_food_draft.dart';
import '../../models/public_food_search_match.dart';
import '../../services/macro_nutrition_consistency_policy.dart';
import '../../repositories/plus_funnel_repository.dart';
import '../../services/open_food_facts_service.dart';
import '../../services/ai_food_lookup_client.dart';
import '../../services/photo_meal_client.dart';
import '../../services/public_food_meal_add_flow.dart';
import '../../state/app_controller.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_icons.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../config/demo_mode.dart';
import '../../constants/app_strings.dart';
import '../../demo/demo_ai.dart';
import '../../demo/demo_meal_photo.dart';
import '../../utils/nutrition_format.dart';
import '../../widgets/common/compact_macro_display.dart';
import '../../utils/saved_food_base_serving_format.dart';
import '../../widgets/common/app_confirm_dialog.dart';
import '../../widgets/design/design_button.dart';
import '../../widgets/design/design_icon.dart';
import '../../widgets/design/design_card.dart';
import '../../widgets/design/design_field.dart';
import '../../widgets/design/design_page.dart';
import '../../widgets/design/food_parts.dart';
import '../../widgets/food/macro_nutrition_fields.dart';
import '../../widgets/food/macro_nutrition_input_controller.dart';
import '../../widgets/food/combined_food_search.dart';
import '../../widgets/food/food_form_suggestion_list.dart';
import '../../widgets/saved_food/public_food_detail_sheet.dart';
import '../official_food/official_food_detail_screen.dart';
import '../subscription/plus_gate.dart';
import '../../services/source_food_edit_policy.dart';
import '../../widgets/food/source_food_update_dialog.dart';
import '../../widgets/saved_food/duplicate_saved_food_dialog.dart';
import '../../widgets/saved_food/saved_food_visibility_selector.dart';
import '../../widgets/saved_food/serving_amount_fields.dart';
import 'meal_food_search_screen.dart';
import 'barcode_scanner_screen.dart';
import 'ai_food_lookup_screen.dart';
import 'photo_meal_screen.dart';
import 'food_form_template_actions.dart';
import 'food_meal_registration_screen.dart';

class FoodFormScreen extends StatefulWidget {
  static const firstMealGuideKey = Key('first-meal-guide');

  const FoodFormScreen({
    super.key,
    required this.controller,
    required this.openFoodFactsService,
    this.entry,
    this.initialPublicFood,
    this.initialLoggedAt,
    this.guideFirstMeal = false,
    this.initialQuery,
    this.searchOverrides,
    this.aiLookup,
  });

  final AppController controller;
  final OpenFoodFactsService openFoodFactsService;
  final FoodEntry? entry;
  final SavedFood? initialPublicFood;
  final DateTime? initialLoggedAt;

  /// 目標設定の直後だけ、この食事登録画面の上に1件分の案内を載せる。
  final bool guideFirstMeal;

  /// Siri で見つからなかった検索語。名前欄に入れて、保存済み・定番の食品・公開食品を探す。
  final String? initialQuery;

  /// テストが食品名欄と「食品を探す」の検索先を差し替える。
  final CombinedFoodSearchOverrides? searchOverrides;

  /// テストが AIで探すの呼び出し先を差し替える。
  final AiFoodLookupClient? aiLookup;

  bool get isEditing => entry != null;

  @override
  State<FoodFormScreen> createState() => _FoodFormScreenState();
}

class _FoodFormScreenState extends State<FoodFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _barcodeController = TextEditingController();
  final _nameController = TextEditingController();
  final _quantityController = TextEditingController();
  final _saveServingQuantityController = TextEditingController(text: '100');
  final _saveServingUnitController = TextEditingController();
  late final MacroNutritionInputController _macroInput;

  bool _isSearching = false;
  bool _manualInputHighlighted = false;
  bool _saveAsFood = true;
  FoodVisibility _saveFoodVisibility = FoodVisibility.private;
  bool _fromSavedFoodSelection = false;
  bool _barcodeSectionExpanded = false;
  late bool _showFirstMealGuide;
  FoodEntrySource _sourceType = FoodEntrySource.manual;
  String? _selectedSavedFoodId;
  String? _sourceFoodOwnerUserId;
  int? _sourceSavedFoodVersion;
  double _baseAmount = 1;
  FoodUnitType _unitType = FoodUnitType.serving;
  List<FoodFormSuggestion> _formSuggestions = const [];
  final _nameSearchHandle = CombinedFoodSearchHandle();
  Timer? _suggestionTimer;
  int _suggestionGeneration = 0;
  String? _suggestionQuery;
  late DateTime _loggedAt;

  bool get _showSaveAsFoodCheckbox =>
      !widget.isEditing && !_fromSavedFoodSelection;

  bool get _usesSavedFoodBaseModel =>
      _fromSavedFoodSelection || _selectedSavedFoodId != null;

  bool get _isMobilePlatform {
    if (kIsWeb) {
      return false;
    }
    return defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.android;
  }

  @override
  void initState() {
    super.initState();
    _macroInput = MacroNutritionInputController();
    _showFirstMealGuide = widget.guideFirstMeal && widget.entry == null;
    if (_showFirstMealGuide) {
      widget.controller.finishFirstMealGuide();
    }
    final entry = widget.entry;
    _loggedAt = (entry?.loggedAt ?? widget.initialLoggedAt ?? DateTime.now())
        .toLocal();
    _sourceType = entry?.sourceType ?? FoodEntrySource.manual;
    _nameController.text = entry?.name ?? widget.initialQuery?.trim() ?? '';
    _selectedSavedFoodId = entry?.savedFoodId;
    _sourceFoodOwnerUserId = entry?.sourceFoodOwnerUserId;
    _sourceSavedFoodVersion = entry?.sourceSavedFoodVersion;
    if (entry != null && entry.hasConsumptionModel) {
      _baseAmount = entry.baseAmount;
      _unitType = entry.unitType;
      _fromSavedFoodSelection = entry.savedFoodId != null;
    }
    _macroInput.initializeFromNullable(
      kcal: entry?.kcalPerBase ?? entry?.kcalPerUnit,
      protein: entry?.proteinPerBase ?? entry?.proteinPerUnit,
      fat: entry?.fatPerBase ?? entry?.fatPerUnit,
      carb: entry?.carbPerBase ?? entry?.carbPerUnit,
      consistencyMode: MacroNutritionConsistencyPolicy.initialModeFor(
        _sourceType,
      ),
    );
    _quantityController.text = entry != null
        ? entry.consumedAmount.toString()
        : '1';
    _nameController.addListener(_onNameChanged);
    if (!widget.isEditing && _nameController.text.trim().isEmpty) {
      unawaited(_loadInitialSuggestions());
    }
    final initialPublicFood = widget.initialPublicFood;
    if (initialPublicFood != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _applySavedFoodSelection(initialPublicFood);
        }
      });
    }
  }

  @override
  void dispose() {
    _suggestionTimer?.cancel();
    _nameController.removeListener(_onNameChanged);
    _barcodeController.dispose();
    _nameController.dispose();
    _quantityController.dispose();
    _saveServingQuantityController.dispose();
    _saveServingUnitController.dispose();
    _macroInput.dispose();
    super.dispose();
  }

  Future<void> _loadInitialSuggestions() async {
    if (widget.isEditing || _fromSavedFoodSelection) {
      return;
    }
    _suggestionQuery = '';
    await _refreshSuggestions('');
  }

  /// 選択範囲が変わっただけでもコントローラは通知する。語が同じなら検索しない。
  void _onNameChanged() {
    if (widget.isEditing || _fromSavedFoodSelection) {
      _suggestionTimer?.cancel();
      _suggestionGeneration++;
      return;
    }
    final query = _nameController.text.trim();
    if (query == _suggestionQuery) {
      return;
    }
    _suggestionQuery = query;
    _suggestionTimer?.cancel();
    // 文字が入っている間は CombinedFoodSearch が保存済み・定番・公開を出す。
    if (query.isNotEmpty) {
      _suggestionGeneration++;
      if (_formSuggestions.isNotEmpty) {
        setState(() => _formSuggestions = const []);
      }
      return;
    }
    _suggestionTimer = Timer(const Duration(milliseconds: 250), () {
      unawaited(_refreshSuggestions(query));
    });
  }

  Future<void> _refreshSuggestions(String query) async {
    final generation = ++_suggestionGeneration;
    final results = await widget.controller.getFoodFormSuggestions(query);
    if (!mounted || generation != _suggestionGeneration) {
      return;
    }
    if (widget.isEditing || _fromSavedFoodSelection) {
      return;
    }
    if (_nameController.text.trim() != query) {
      return;
    }
    setState(() => _formSuggestions = results);
  }

  Future<void> _applyMealTemplateSuggestion(MealTemplate template) async {
    final registered = await openFoodMealRegistrationFromTemplate(
      context: context,
      controller: widget.controller,
      template: template,
      initialLoggedAt: _loggedAt,
    );
    if (registered == true && mounted) {
      Navigator.of(context).pop(true);
    }
  }

  void _applySavedFoodSelection(SavedFood food) {
    final selection = widget.controller.selectSavedFoodForEntry(food);
    setState(() {
      _fromSavedFoodSelection = true;
      _saveAsFood = false;
      _selectedSavedFoodId = selection.savedFoodId;
      _sourceFoodOwnerUserId = selection.sourceFoodOwnerUserId;
      _sourceSavedFoodVersion = selection.sourceSavedFoodVersion;
      _baseAmount = selection.baseAmount;
      _unitType = selection.unitType;
      _sourceType = selection.entrySourceType;
      _formSuggestions = const [];
      _nameController.text = selection.name;
      _quantityController.text = SavedFoodBaseServingFormat.formatQuantity(
        selection.baseAmount,
      );
    });
    _macroInput.applyExternalValues(
      kcal: selection.kcalPerBase,
      protein: selection.proteinPerBase,
      fat: selection.fatPerBase,
      carb: selection.carbPerBase,
    );
  }

  Future<void> _openBarcodeScanner() async {
    if (_isSearching) {
      return;
    }

    final barcode = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        settings: const RouteSettings(
          name: 'food_form_screen_MaterialPageRoute_0',
        ),
        builder: (context) => const BarcodeScannerScreen(),
      ),
    );

    if (!mounted || barcode == null) {
      return;
    }

    _barcodeController.text = barcode;
    await _searchByBarcode(barcode);
  }

  Future<void> _searchByBarcode([String? barcodeOverride]) async {
    if (_isSearching) {
      return;
    }

    final barcode = (barcodeOverride ?? _barcodeController.text).trim();
    if (barcode.isEmpty) {
      _showMessage('バーコードを入力してください');
      setState(() => _manualInputHighlighted = true);
      return;
    }

    setState(() {
      _isSearching = true;
      _manualInputHighlighted = false;
    });

    final result = await widget.openFoodFactsService.fetchByBarcode(barcode);

    if (!mounted) {
      return;
    }

    setState(() => _isSearching = false);

    if (result.failure != null) {
      setState(() => _manualInputHighlighted = true);
      _showMessage(_messageForFailure(result.failure!));
      return;
    }

    final data = result.data;
    if (data == null) {
      setState(() => _manualInputHighlighted = true);
      _showMessage('商品が見つかりませんでした。手入力してください。');
      return;
    }

    _applyLookup(data);
    setState(() => _barcodeSectionExpanded = false);
    _showMessage('商品情報を取得しました。数量を確認して保存してください。');
  }

  Future<void> _openFoodSearch() async {
    final result = await Navigator.of(context).push<Object?>(
      MaterialPageRoute<Object?>(
        settings: const RouteSettings(
          name: 'food_form_screen_MaterialPageRoute_1',
        ),
        builder: (context) => MealFoodSearchScreen(
          controller: widget.controller,
          searchOverrides: widget.searchOverrides,
          aiLookup: widget.aiLookup,
          loggedAt: _loggedAt,
        ),
      ),
    );
    if (!mounted) {
      return;
    }
    if (result == true) {
      Navigator.of(context).pop();
      return;
    }
    if (result is SavedFood) {
      _applySavedFoodSelection(result);
    }
  }

  void _applyLookup(FoodLookupResult result) {
    if (result.name != null) {
      _nameController.text = result.name!;
    }
    setState(() {
      _sourceType = FoodEntrySource.openFoodFacts;
      _fromSavedFoodSelection = false;
      _selectedSavedFoodId = null;
      _sourceFoodOwnerUserId = null;
      _baseAmount = 1;
      _unitType = FoodUnitType.serving;
    });
    _macroInput.applyExternalValues(
      kcal: result.kcalPerUnit,
      protein: result.proteinPerUnit,
      fat: result.fatPerUnit,
      carb: result.carbPerUnit,
    );
    setState(() => _manualInputHighlighted = false);
  }

  String _messageForFailure(OffLookupFailure failure) {
    return switch (failure) {
      OffLookupFailure.configurationError =>
        'User-Agent（連絡先）が未設定です。設定後に再度お試しください。',
      OffLookupFailure.notFound => '商品が見つかりませんでした。手入力してください。',
      OffLookupFailure.rateLimited => 'アクセスが集中しています。しばらくしてからお試しください。',
      OffLookupFailure.network => '通信に失敗しました。手入力してください。',
      OffLookupFailure.invalidResponse => '商品情報を読み取れませんでした。手入力してください。',
      OffLookupFailure.timeout => '通信がタイムアウトしました。手入力してください。',
    };
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  double _parseQuantity(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return 1;
    }
    return double.parse(trimmed);
  }

  FoodEntry? _buildEntry() {
    if (_formKey.currentState?.validate() != true) {
      return null;
    }

    // Figma の入力欄は素の TextField なので、Form の検証だけでは足りない。
    if (_nameController.text.trim().isEmpty) {
      _showMessage('食品名を入力してください');
      return null;
    }

    final quantityText = _quantityController.text.trim();
    if (quantityText.isNotEmpty) {
      final parsedQuantity = double.tryParse(quantityText);
      if (parsedQuantity == null || parsedQuantity <= 0) {
        _showMessage('数量は0より大きい値を入力してください');
        return null;
      }
    }

    final consumedAmount = _parseQuantity(_quantityController.text);
    final baseAmount = _usesSavedFoodBaseModel ? _baseAmount : 1.0;
    final unitType = _usesSavedFoodBaseModel ? _unitType : FoodUnitType.serving;

    return FoodEntry(
      id: widget.entry?.id ?? widget.controller.generateId(),
      name: _nameController.text.trim(),
      kcalPerBase: _macroInput.parseOptional(MacroField.kcal),
      proteinPerBase: _macroInput.parseOptional(MacroField.protein),
      fatPerBase: _macroInput.parseOptional(MacroField.fat),
      carbPerBase: _macroInput.parseOptional(MacroField.carb),
      baseAmount: baseAmount,
      unitType: unitType,
      consumedAmount: consumedAmount,
      sourceType: MacroNutritionConsistencyPolicy.resolveSaveSourceType(
        initialSourceType: _sourceType,
        nutritionEditedByUser: _macroInput.nutritionEditedByUser,
      ),
      savedFoodId: _selectedSavedFoodId,
      sourceFoodOwnerUserId: _sourceFoodOwnerUserId,
      sourceSavedFoodVersion: _sourceSavedFoodVersion,
      officialFoodCode: widget.entry?.officialFoodCode,
      officialFoodName: widget.entry?.officialFoodName,
      memo: widget.isEditing ? widget.entry?.memo : null,
      loggedAt: _loggedAt,
    );
  }

  Future<void> _openTemplatePicker() async {
    await openFoodTemplatePicker(
      context: context,
      controller: widget.controller,
      initialLoggedAt: _loggedAt,
      onMealRegistered: () {
        if (mounted) {
          Navigator.of(context).pop();
        }
      },
    );
  }

  SavedFoodDraft? _buildSavedFoodDraft() {
    final quantity = SavedFoodBaseServingFormat.parseQuantity(
      _saveServingQuantityController.text,
    );
    final unit = SavedFoodBaseServingFormat.parseUnit(
      _saveServingUnitController.text,
    );
    if (quantity == null || unit == null) {
      return null;
    }

    return SavedFoodDraft(
      name: _nameController.text.trim(),
      baseAmount: quantity,
      servingUnitLabel: unit,
      unitType: FoodUnitTypeX.inferFromUnitLabel(unit),
      kcalPerBase: _macroInput.parseOptional(MacroField.kcal),
      proteinPerBase: _macroInput.parseOptional(MacroField.protein),
      fatPerBase: _macroInput.parseOptional(MacroField.fat),
      carbPerBase: _macroInput.parseOptional(MacroField.carb),
      sourceType: switch (_sourceType) {
        FoodEntrySource.openFoodFacts => FoodSourceType.openFoodFacts,
        _ => FoodSourceType.manual,
      },
      visibility: _saveFoodVisibility,
    );
  }

  Future<void> _pickPublicFood(PublicFoodSearchMatch match) async {
    final foodForMeal = await showPublicFoodDetailSheet(
      context: context,
      controller: widget.controller,
      match: match,
      selectForMealEntry: true,
      onBlocked: () => _nameSearchHandle.hideOwner(match.food.ownerUserId),
    );
    if (foodForMeal == null || !mounted) {
      return;
    }
    final added = await PublicFoodMealAddFlow.start(
      context: context,
      controller: widget.controller,
      food: foodForMeal,
      onOpenManualForm: (context, food) {
        if (!mounted) {
          return;
        }
        _applySavedFoodSelection(food);
      },
    );
    if (added && mounted) {
      Navigator.of(context).pop(true);
    }
  }

  Future<DuplicateSavedFoodResolution?> _resolveDuplicateIfNeeded(
    SavedFoodDraft draft,
  ) async {
    final duplicate = await widget.controller.findPrivateDuplicateSavedFood(
      draft.name,
    );
    if (duplicate == null) {
      return null;
    }

    final dialogResult = await showDuplicateSavedFoodDialog(
      context: context,
      existingFood: duplicate,
      enteredName: draft.name,
    );
    if (dialogResult == null || !mounted) {
      return null;
    }

    return DuplicateSavedFoodResolution(
      action: dialogResult.action,
      draft: draft,
      existingFood: duplicate,
      newName: dialogResult.newName,
    );
  }

  Future<void> _save() async {
    if (!_macroInput.prepareForSave()) {
      _showMessage(
        _macroInput.negativeMessage ?? '栄養素の値が整合していません。入力を見直してください。',
      );
      return;
    }

    final entry = _buildEntry();
    if (entry == null) {
      return;
    }

    if (widget.isEditing) {
      final original = widget.entry!;
      SourceFoodUpdateChoice sourceChoice = SourceFoodUpdateChoice.entryOnly;
      if (SourceFoodEditPolicy.affectsSourceFood(
        original: original,
        updated: entry,
      )) {
        final isOwn =
            original.sourceFoodOwnerUserId == null ||
            original.sourceFoodOwnerUserId ==
                widget.controller.currentOwnerUserId;
        final choice = await showSourceFoodUpdateDialog(
          context: context,
          isOwnSavedFood: isOwn,
        );
        if (choice == null || choice == SourceFoodUpdateChoice.cancel) {
          return;
        }
        sourceChoice = choice;
      }

      await widget.controller.saveEditedFoodEntryWithSourceChoice(
        entry: entry,
        originalEntry: original,
        sourceChoice: sourceChoice,
      );
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop();
      return;
    }

    final shouldSaveAsFood = _showSaveAsFoodCheckbox && _saveAsFood;
    SavedFoodDraft? draft;
    DuplicateSavedFoodResolution? duplicateResolution;

    if (shouldSaveAsFood) {
      final foodDraft = _buildSavedFoodDraft();
      if (foodDraft == null) {
        _showMessage('基準数量と基準単位を入力してください');
        return;
      }
      draft = foodDraft;
      duplicateResolution = await _resolveDuplicateIfNeeded(foodDraft);
      if (duplicateResolution == null &&
          await widget.controller.findPrivateDuplicateSavedFood(
                foodDraft.name,
              ) !=
              null) {
        return;
      }
    }

    final result = await widget.controller.saveFoodEntryWithOptionalSavedFood(
      entry: entry,
      saveAsFood: shouldSaveAsFood,
      savedFoodDraft: duplicateResolution == null ? draft : null,
      duplicateResolution: duplicateResolution,
    );

    if (!mounted) {
      return;
    }

    if (!result.foodEntrySaved) {
      _showMessage('食事の保存に失敗しました');
      return;
    }

    if (result.savedFoodErrorMessage != null) {
      final userMessage =
          result.savedFoodErrorCode?.userMessage(
            detail: result.savedFoodErrorMessage,
          ) ??
          result.savedFoodErrorMessage!;
      _showMessage('食事は記録しましたが、食品としての保存に失敗しました。\n$userMessage');
    }

    if (_showFirstMealGuide) {
      setState(() => _showFirstMealGuide = false);
    }
    Navigator.of(context).pop();
  }

  String? Function(String?) _validateOptionalNonNegativeNumber(String label) {
    return (value) {
      if (value == null || value.trim().isEmpty) {
        return null;
      }
      final parsed = double.tryParse(value);
      if (parsed == null || parsed < 0) {
        return '$label は0以上の数値を入力してください';
      }
      return null;
    };
  }

  Widget? _buildTotalPreview() {
    if (!_usesSavedFoodBaseModel) {
      return null;
    }

    final consumed = double.tryParse(_quantityController.text.trim());
    if (consumed == null || consumed <= 0 || _baseAmount <= 0) {
      return null;
    }

    final multiplier = consumed / _baseAmount;
    final kcal = (_macroInput.parseOptional(MacroField.kcal) ?? 0) * multiplier;
    final protein =
        (_macroInput.parseOptional(MacroField.protein) ?? 0) * multiplier;
    final fat = (_macroInput.parseOptional(MacroField.fat) ?? 0) * multiplier;
    final carb = (_macroInput.parseOptional(MacroField.carb) ?? 0) * multiplier;

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppStrings.macroIntakePreviewPrefix,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          CompactMacroDisplay(
            kcal: kcal,
            proteinG: protein,
            fatG: fat,
            carbG: carb,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final quantityLabel = _usesSavedFoodBaseModel
        ? '摂取量（${_unitType.label}）'
        : '数量';

    return DesignPage(
      bottomBar: DesignButton(
        label: widget.isEditing ? '更新する' : '追加する',
        showTrailingIcon: false,
        onPressed: _save,
      ),
      body: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Align(
              alignment: Alignment.centerLeft,
              child: DesignBackButton(),
            ),
            const SizedBox(height: 2),
            Text(
              widget.isEditing ? '食事を編集' : '食事を追加',
              style: AppTypography.headingL,
            ),
            if (_showFirstMealGuide) ...[
              const SizedBox(height: AppSpacing.md),
              DesignCard(
                key: FoodFormScreen.firstMealGuideKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('今日の食事を1件登録', style: AppTypography.headingL),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      '食べたものを1件入れて、追加するを押してください。',
                      style: AppTypography.bodyL.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    DesignButton(
                      label: '閉じる',
                      style: DesignButtonStyle.outline,
                      showTrailingIcon: false,
                      onPressed: () =>
                          setState(() => _showFirstMealGuide = false),
                    ),
                  ],
                ),
              ),
            ],
            if (!widget.isEditing) ...[
              const SizedBox(height: 8),
              _MealAddGroups(
                showPhoto: !kIsWeb,
                barcodeSelected: _barcodeSectionExpanded,
                onPhoto: _openPhotoMeal,
                onSearch: _openFoodSearch,
                onOtherSelected: _onOtherMethodSelected,
              ),
            ],
            if (!_barcodeSectionExpanded) ...[
              const SizedBox(height: 10),
              _inputCard(context, quantityLabel),
            ],
            if (!widget.isEditing && _barcodeSectionExpanded) ...[
              const SizedBox(height: 10),
              _barcodeCard(),
            ],
            if (widget.isEditing) ...[
              const SizedBox(height: 16),
              DesignButton(
                label: '削除する',
                style: DesignButtonStyle.danger,
                showTrailingIcon: false,
                onPressed: _confirmDelete,
              ),
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  void _onOtherMethodSelected(int index) {
    switch (index) {
      case 0:
        setState(() => _barcodeSectionExpanded = false);
      case 1:
        setState(() => _barcodeSectionExpanded = true);
      case 2:
        _openTemplatePicker();
    }
  }

  Future<void> _openPhotoMeal() async {
    final allowed = await ensureCalonaviPlus(
      context,
      widget.controller,
      message:
          '写真で登録 (β) は、カロナビ+です。食事の写真から、AIがカロリーとPFCの推定を出します。登録の前に確認して、数値を直せます。',
      feature: PlusFunnelFeature.photoMeal,
    );
    if (!allowed || !mounted) {
      return;
    }
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        settings: const RouteSettings(name: 'photo_meal'),
        builder: (context) => PhotoMealScreen(
          controller: widget.controller,
          loggedAt: _loggedAt,
          client: calonaviDemoMode
              ? demoPhotoMealClient()
              : PhotoMealClient.supabase(),
          source: calonaviDemoMode ? const DemoMealPhotoSource() : null,
          recordEdit: calonaviDemoMode ? (_, _) async {} : null,
        ),
      ),
    );
    if (saved == true && mounted) {
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _openAiLookup(String query) async {
    final saved = await openAiFoodLookup(
      context: context,
      controller: widget.controller,
      query: query,
      loggedAt: _loggedAt,
      client:
          widget.aiLookup ??
          (calonaviDemoMode ? demoAiFoodLookupClient() : null),
    );
    if (saved && mounted) {
      Navigator.of(context).pop(true);
    }
  }

  /// 空欄はテンプレートと保存済みの候補。文字があるときは3種類を見出し付きで出す。
  Widget _nameLookup() {
    final overrides = widget.searchOverrides;
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: _nameController,
      builder: (context, value, _) {
        if (value.text.trim().isEmpty) {
          return FoodFormSuggestionList(
            controller: widget.controller,
            suggestions: _formSuggestions,
            onSavedFoodSelected: _applySavedFoodSelection,
            onMealTemplateSelected: _applyMealTemplateSuggestion,
          );
        }
        return CombinedFoodSearch(
          controller: widget.controller,
          query: _nameController,
          handle: _nameSearchHandle,
          officialFoods: overrides?.officialFoods,
          searchSaved: overrides?.searchSaved,
          searchOfficial: overrides?.searchOfficial,
          searchPublic: overrides?.searchPublic,
          debounce: overrides?.debounce ?? const Duration(milliseconds: 250),
          onSavedFood: _applySavedFoodSelection,
          onOfficialFood: (match) =>
              openOfficialFoodDetail(context, widget.controller, match),
          onPublicFood: _pickPublicFood,
          onAiFoodLookup: _openAiLookup,
        );
      },
    );
  }

  /// Figma: 入力カード。
  Widget _inputCard(BuildContext context, String quantityLabel) {
    return DesignCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('食品の情報を入力', style: AppTypography.titleM),
          const SizedBox(height: 12),
          Text(
            '食品名',
            style: AppTypography.caption.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          DesignInputBox(
            radius: AppRadius.sm,
            verticalPadding: 12,
            child: DesignTextInput(
              key: const ValueKey('food_name_field'),
              controller: _nameController,
              hintText: '例）オートミール、鶏むね肉（皮なし）など',
            ),
          ),
          if (!widget.isEditing && !_fromSavedFoodSelection) _nameLookup(),
          if (_usesSavedFoodBaseModel) ...[
            const SizedBox(height: 8),
            Text(
              '基準: ${widget.controller.formatBaseAmountLabel(baseAmount: _baseAmount, unitType: _unitType)} · '
              '${formatNullableNutrient(_macroInput.parseOptional(MacroField.kcal))}kcal',
              style: AppTypography.bodyS,
            ),
          ],
          const SizedBox(height: 12),
          MacroNutritionFields(
            controller: _macroInput,
            compact: true,
            readOnly: _fromSavedFoodSelection,
            validator: (value, label) =>
                _validateOptionalNonNegativeNumber(label)(value),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: MiniField(
                  label: quantityLabel,
                  unit: _usesSavedFoodBaseModel ? _unitType.label : null,
                  child: TextField(
                    controller: _quantityController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    style: AppTypography.bodyM.copyWith(
                      color: AppColors.textPrimary,
                    ),
                    decoration: const InputDecoration(
                      isDense: true,
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                      hintText: '1',
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 3,
                child: MiniField(
                  label: '記録日時',
                  onTap: _pickLoggedAt,
                  child: Text(
                    _formatLoggedAt(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodyM.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
            ],
          ),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _quantityController,
            builder: (_, _, _) =>
                _buildTotalPreview() ?? const SizedBox.shrink(),
          ),
          if (_showSaveAsFoodCheckbox) ...[
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('食品として保存'),
              subtitle: const Text('次回から「食品を探す」で選べます'),
              value: _saveAsFood,
              onChanged: (value) => setState(() => _saveAsFood = value),
            ),
            if (_saveAsFood) ...[
              const SizedBox(height: 8),
              ServingAmountFields(
                quantityController: _saveServingQuantityController,
                unitController: _saveServingUnitController,
              ),
              const SizedBox(height: 8),
              SavedFoodVisibilitySelector(
                value: _saveFoodVisibility,
                onChanged: (value) =>
                    setState(() => _saveFoodVisibility = value),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Future<void> _pickLoggedAt() async {
    final local = _loggedAt.toLocal();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: local,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (pickedDate == null || !mounted) {
      return;
    }

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(local),
    );
    if (pickedTime == null || !mounted) {
      return;
    }

    setState(() {
      _loggedAt = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );
    });
  }

  String _formatLoggedAt() {
    final local = _loggedAt.toLocal();
    const weekdays = ['月', '火', '水', '木', '金', '土', '日'];
    // 今年のうちは年を省いて、狭い枠でも日付と時刻が読めるようにする。
    final year = local.year == DateTime.now().year ? '' : '${local.year}年';
    return '$year${local.month}月${local.day}日'
        '（${weekdays[local.weekday - 1]}）'
        '${local.hour}:${local.minute.toString().padLeft(2, '0')}';
  }

  /// Figma: バーコードから追加カード。
  Widget _barcodeCard() {
    return DesignCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text('バーコードから追加', style: AppTypography.titleM),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '市販の食品をかんたんに登録',
                  textAlign: TextAlign.end,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_isMobilePlatform)
                SizedBox(
                  width: 116,
                  child: InkWell(
                    onTap: _isSearching ? null : _openBarcodeScanner,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    child: Container(
                      height: 67,
                      decoration: BoxDecoration(
                        color: AppColors.bgSurfaceGreenSoft,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          AppIcon(
                            AppIcons.camera,
                            size: 24,
                            color: AppColors.iconPrimary,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'カメラで読み取る',
                            style: AppTypography.caption.copyWith(
                              color: AppColors.textBrand,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              if (_isMobilePlatform) const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isMobilePlatform ? 'または バーコードの番号を入力' : 'バーコードの番号を入力',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: DesignInputBox(
                            radius: AppRadius.sm,
                            verticalPadding: 11,
                            child: DesignTextInput(
                              controller: _barcodeController,
                              hintText: '例）4901001234567',
                              keyboardType: TextInputType.number,
                              enabled: !_isSearching,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        InkWell(
                          onTap: _isSearching ? null : () => _searchByBarcode(),
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: AppColors.bgPrimary,
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                            ),
                            child: _isSearching
                                ? const Padding(
                                    padding: EdgeInsets.all(10),
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        AppColors.iconOnPrimary,
                                      ),
                                    ),
                                  )
                                : AppIcon(
                                    AppIcons.search,
                                    size: 20,
                                    color: AppColors.iconOnPrimary,
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_manualInputHighlighted) ...[
            const SizedBox(height: 10),
            Text(
              '取得できなかった項目があります。手入力のタブから入力してください。',
              style: AppTypography.caption.copyWith(color: AppColors.error),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _confirmDelete() async {
    final entry = widget.entry;
    if (entry == null) {
      return;
    }

    final confirmed = await showAppConfirmDialog(
      context: context,
      title: '削除確認',
      message: '「${entry.name}」を削除しますか？',
    );

    if (confirmed != true) {
      return;
    }

    try {
      await widget.controller.deleteFood(entry.id);
    } catch (error, stackTrace) {
      debugPrint('deleteFood failed: $error\n$stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('食事の削除に失敗しました。もう一度お試しください')),
        );
      }
      return;
    }
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop();
  }
}

/// 食事を追加の入口。写真で登録、検索、その他。検索と保存の処理は変えない。
class _MealAddGroups extends StatelessWidget {
  const _MealAddGroups({
    required this.showPhoto,
    required this.barcodeSelected,
    required this.onPhoto,
    required this.onSearch,
    required this.onOtherSelected,
  });

  final bool showPhoto;
  final bool barcodeSelected;
  final VoidCallback onPhoto;
  final VoidCallback onSearch;
  final ValueChanged<int> onOtherSelected;

  @override
  Widget build(BuildContext context) {
    final muted = AppTypography.bodyS.copyWith(color: AppColors.textMuted);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showPhoto) ...[
          DesignButton(
            key: const Key('meal-add-photo'),
            label: '写真で登録',
            showTrailingIcon: false,
            leading: const DesignIcon(
              Symbols.photo_camera_rounded,
              size: 22,
              color: AppColors.textOnPrimary,
            ),
            onPressed: onPhoto,
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        DesignButton(
          key: const Key('meal-add-search'),
          label: '検索',
          style: DesignButtonStyle.outline,
          showTrailingIcon: false,
          leading: const DesignIcon(
            Symbols.search_rounded,
            size: 22,
            color: AppColors.textBrand,
          ),
          onPressed: onSearch,
        ),
        const SizedBox(height: 6),
        Text('保存済み、定番の食品、公開食品をまとめて探します。', style: muted),
        const SizedBox(height: AppSpacing.md),
        Text('その他', style: AppTypography.titleS),
        FormTabBar(
          items: const [
            FormTabItem(icon: Symbols.edit_rounded, label: '手入力'),
            FormTabItem(icon: Symbols.barcode_scanner_rounded, label: 'バーコード'),
            FormTabItem(icon: Symbols.list_alt_rounded, label: 'テンプレート'),
          ],
          selectedIndex: barcodeSelected ? 1 : 0,
          onSelected: onOtherSelected,
        ),
      ],
    );
  }
}
