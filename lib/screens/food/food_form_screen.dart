import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../models/duplicate_saved_food_resolution.dart';
import '../../models/food_entry.dart';
import '../../models/food_entry_source.dart';
import '../../models/food_source_type.dart';
import '../../models/food_unit_type.dart';
import '../../models/macro_field.dart';
import '../../models/saved_food.dart';
import '../../models/saved_food_draft.dart';
import '../../services/macro_nutrition_consistency_policy.dart';
import '../../services/open_food_facts_service.dart';
import '../../state/app_controller.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../utils/nutrition_format.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/app_confirm_dialog.dart';
import '../../widgets/common/app_text_field.dart';
import '../../widgets/common/primary_button.dart';
import '../../widgets/common/secondary_button.dart';
import '../../widgets/food/macro_nutrition_fields.dart';
import '../../widgets/food/macro_nutrition_input_controller.dart';
import '../../widgets/saved_food/duplicate_saved_food_dialog.dart';
import '../../widgets/saved_food/saved_food_suggestion_list.dart';
import '../saved_food/public_food_search_screen.dart';
import 'barcode_scanner_screen.dart';

class FoodFormScreen extends StatefulWidget {
  const FoodFormScreen({
    super.key,
    required this.controller,
    required this.openFoodFactsService,
    this.entry,
    this.initialPublicFood,
  });

  final AppController controller;
  final OpenFoodFactsService openFoodFactsService;
  final FoodEntry? entry;
  final SavedFood? initialPublicFood;

  bool get isEditing => entry != null;

  @override
  State<FoodFormScreen> createState() => _FoodFormScreenState();
}

class _FoodFormScreenState extends State<FoodFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _barcodeController = TextEditingController();
  final _nameController = TextEditingController();
  final _quantityController = TextEditingController();
  late final MacroNutritionInputController _macroInput;

  bool _isSearching = false;
  bool _manualInputHighlighted = false;
  bool _saveAsFood = true;
  bool _fromSavedFoodSelection = false;
  bool _barcodeSectionExpanded = false;
  FoodEntrySource _sourceType = FoodEntrySource.manual;
  String? _selectedSavedFoodId;
  String? _sourceFoodOwnerUserId;
  int? _sourceSavedFoodVersion;
  double _baseAmount = 1;
  FoodUnitType _unitType = FoodUnitType.serving;
  List<SavedFood> _savedFoodSuggestions = const [];

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
    final entry = widget.entry;
    _sourceType = entry?.sourceType ?? FoodEntrySource.manual;
    _nameController.text = entry?.name ?? '';
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
    _nameController.removeListener(_onNameChanged);
    _barcodeController.dispose();
    _nameController.dispose();
    _quantityController.dispose();
    _macroInput.dispose();
    super.dispose();
  }

  Future<void> _onNameChanged() async {
    if (widget.isEditing || _fromSavedFoodSelection) {
      return;
    }

    final query = _nameController.text.trim();
    if (query.isEmpty) {
      if (mounted) {
        setState(() => _savedFoodSuggestions = const []);
      }
      return;
    }

    final results = await widget.controller.searchOwnSavedFoods(query);
    if (!mounted) {
      return;
    }
    setState(() => _savedFoodSuggestions = results);
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
      _savedFoodSuggestions = const [];
      _nameController.text = selection.name;
      _quantityController.text = selection.baseAmount.toString();
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
    _showMessage('商品情報を取得しました。数量を確認して保存してください。');
  }

  Future<void> _openPublicFoodSearch() async {
    final food = await Navigator.of(context).push<SavedFood>(
      MaterialPageRoute<SavedFood>(
        builder: (context) => PublicFoodSearchScreen(
          controller: widget.controller,
          selectForMealEntry: true,
        ),
      ),
    );
    if (food != null && mounted) {
      _applySavedFoodSelection(food);
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
      loggedAt: widget.entry?.loggedAt ?? DateTime.now(),
    );
  }

  SavedFoodDraft _buildSavedFoodDraft(FoodEntry entry) {
    return SavedFoodDraft(
      name: entry.name,
      baseAmount: entry.baseAmount,
      unitType: entry.unitType,
      kcalPerBase: entry.kcalPerBase,
      proteinPerBase: entry.proteinPerBase,
      fatPerBase: entry.fatPerBase,
      carbPerBase: entry.carbPerBase,
      sourceType: switch (entry.sourceType) {
        FoodEntrySource.openFoodFacts => FoodSourceType.openFoodFacts,
        _ => FoodSourceType.manual,
      },
    );
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
      await widget.controller.updateFood(entry);
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
      final foodDraft = _buildSavedFoodDraft(entry);
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
      _showMessage('食事は保存されましたが、食品登録に失敗しました');
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
      child: Text(
        '今回の摂取: ${formatNullableNutrient(kcal)}kcal · '
        'P${formatNullableNutrient(protein)} '
        'F${formatNullableNutrient(fat)} '
        'C${formatNullableNutrient(carb)}',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final quantityLabel = _usesSavedFoodBaseModel
        ? '摂取量（${_unitType.label}）'
        : '数量（未入力時は1）';

    return Scaffold(
      appBar: AppBar(title: Text(widget.isEditing ? '食事を編集' : '食事を追加')),
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenPadding,
              AppSpacing.md,
              AppSpacing.screenPadding,
              100,
            ),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            children: [
              if (!widget.isEditing) ...[
                AppCard(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SecondaryButton(
                        label: '公開食品を検索',
                        icon: Icons.public,
                        onPressed: _openPublicFoodSearch,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      SecondaryButton(
                        label: _barcodeSectionExpanded
                            ? 'バーコード入力を閉じる'
                            : 'バーコードから追加',
                        icon: Icons.qr_code,
                        onPressed: () => setState(
                          () => _barcodeSectionExpanded =
                              !_barcodeSectionExpanded,
                        ),
                      ),
                      if (_barcodeSectionExpanded) ...[
                        if (_isMobilePlatform) ...[
                          const SizedBox(height: AppSpacing.xs),
                          PrimaryButton(
                            label: 'カメラでスキャン',
                            icon: Icons.qr_code_scanner,
                            onPressed: _isSearching
                                ? null
                                : _openBarcodeScanner,
                          ),
                        ],
                        const SizedBox(height: AppSpacing.sm),
                        AppTextField(
                          controller: _barcodeController,
                          label: 'バーコード',
                          keyboardType: TextInputType.number,
                          readOnly: _isSearching,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        PrimaryButton(
                          label: _isSearching ? '検索中...' : 'バーコードで検索',
                          icon: Icons.search,
                          loading: _isSearching,
                          onPressed: _isSearching
                              ? null
                              : () => _searchByBarcode(),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                if (_manualInputHighlighted)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: Text(
                      '取得できなかった項目があります。下の欄から入力してください。',
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: AppColors.error),
                    ),
                  ),
              ],
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppTextField(
                      key: const ValueKey('food_name_field'),
                      controller: _nameController,
                      label: '食品名',
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return '食品名を入力してください';
                        }
                        return null;
                      },
                    ),
                    if (!widget.isEditing && !_fromSavedFoodSelection)
                      SavedFoodSuggestionList(
                        controller: widget.controller,
                        foods: _savedFoodSuggestions,
                        onSelected: _applySavedFoodSelection,
                      ),
                    if (_usesSavedFoodBaseModel) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        '基準: ${widget.controller.formatBaseAmountLabel(baseAmount: _baseAmount, unitType: _unitType)} · '
                        '${formatNullableNutrient(_macroInput.parseOptional(MacroField.kcal))}kcal',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                    const SizedBox(height: AppSpacing.md),
                    MacroNutritionFields(
                      controller: _macroInput,
                      readOnly: _fromSavedFoodSelection,
                      validator: (value, label) =>
                          _validateOptionalNonNegativeNumber(label)(value),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppTextField(
                      controller: _quantityController,
                      label: quantityLabel,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      onChanged: (_) => setState(() {}),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return null;
                        }
                        final parsed = double.tryParse(value);
                        if (parsed == null || parsed <= 0) {
                          return '0より大きい値を入力してください';
                        }
                        return null;
                      },
                    ),
                    if (_buildTotalPreview() != null) _buildTotalPreview()!,
                    if (_showSaveAsFoodCheckbox) ...[
                      const SizedBox(height: AppSpacing.sm),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('食品として保存'),
                        subtitle: const Text('次回以降、保存済み食品から再利用できます'),
                        value: _saveAsFood,
                        onChanged: (value) =>
                            setState(() => _saveAsFood = value),
                      ),
                    ],
                  ],
                ),
              ),
              if (widget.isEditing) ...[
                const SizedBox(height: AppSpacing.lg),
                SecondaryButton(
                  label: '削除',
                  icon: Icons.delete_outline,
                  onPressed: _confirmDelete,
                ),
              ],
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            AppSpacing.sm,
          ),
          child: Theme(
            data: Theme.of(context).copyWith(
              filledButtonTheme: FilledButtonThemeData(
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
              ),
            ),
            child: PrimaryButton(label: '保存', onPressed: _save),
          ),
        ),
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

    await widget.controller.deleteFood(entry.id);
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop();
  }
}
