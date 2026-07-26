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
import '../../utils/nutrition_format.dart';
import '../../widgets/food/macro_nutrition_fields.dart';
import '../../widgets/food/macro_nutrition_input_controller.dart';
import '../../widgets/saved_food/duplicate_saved_food_dialog.dart';
import '../../widgets/saved_food/saved_food_suggestion_list.dart';
import 'barcode_scanner_screen.dart';

class FoodFormScreen extends StatefulWidget {
  const FoodFormScreen({
    super.key,
    required this.controller,
    required this.openFoodFactsService,
    this.entry,
  });

  final AppController controller;
  final OpenFoodFactsService openFoodFactsService;
  final FoodEntry? entry;

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
  FoodEntrySource _sourceType = FoodEntrySource.manual;
  String? _selectedSavedFoodId;
  String? _sourceFoodOwnerUserId;
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
          await widget.controller.findPrivateDuplicateSavedFood(foodDraft.name) !=
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
      padding: const EdgeInsets.only(top: 8),
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
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            children: [
              if (!widget.isEditing) ...[
                if (_isMobilePlatform) ...[
                  FilledButton.icon(
                    onPressed: _isSearching ? null : _openBarcodeScanner,
                    icon: const Icon(Icons.qr_code_scanner, size: 28),
                    label: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        'カメラでバーコードをスキャン',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
                const Text(
                  'バーコード（テキスト入力）',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _barcodeController,
                  decoration: const InputDecoration(
                    labelText: 'バーコード',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  enabled: !_isSearching,
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _isSearching ? null : () => _searchByBarcode(),
                  icon: _isSearching
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.search),
                  label: Text(_isSearching ? '検索中...' : 'バーコードで検索'),
                ),
                const SizedBox(height: 24),
                Text(
                  '手入力',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: _manualInputHighlighted
                        ? Theme.of(context).colorScheme.error
                        : null,
                  ),
                ),
                if (_manualInputHighlighted)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'APIから取得できなかった項目は手入力してください。',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
              ],
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: '食品名',
                  border: OutlineInputBorder(),
                ),
                textInputAction: TextInputAction.next,
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
                const SizedBox(height: 12),
                Text(
                  '基準: ${widget.controller.formatBaseAmountLabel(baseAmount: _baseAmount, unitType: _unitType)} · '
                  '${formatNullableNutrient(_macroInput.parseOptional(MacroField.kcal))}kcal',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
              const SizedBox(height: 16),
              MacroNutritionFields(
                controller: _macroInput,
                readOnly: _fromSavedFoodSelection,
                validator: (value, label) =>
                    _validateOptionalNonNegativeNumber(label)(value),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _quantityController,
                decoration: InputDecoration(
                  labelText: quantityLabel,
                  border: const OutlineInputBorder(),
                ),
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
                const SizedBox(height: 16),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('食品として保存'),
                  subtitle: const Text('次回以降、保存済み食品から再利用できます'),
                  value: _saveAsFood,
                  onChanged: (value) => setState(() => _saveAsFood = value),
                ),
              ],
              if (widget.isEditing) ...[
                const SizedBox(height: 32),
                OutlinedButton(
                  onPressed: _confirmDelete,
                  child: const Text('削除'),
                ),
              ],
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton(
            onPressed: _save,
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Text('保存', style: TextStyle(fontSize: 16)),
            ),
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

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('削除確認'),
        content: Text('「${entry.name}」を削除しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('削除'),
          ),
        ],
      ),
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
