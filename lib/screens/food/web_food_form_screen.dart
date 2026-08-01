import 'package:flutter/material.dart';

import '../../models/food_entry.dart';
import '../../models/food_entry_source.dart';
import '../../models/food_unit_type.dart';
import '../../models/macro_field.dart';
import '../../models/meal_template_draft.dart';
import '../../models/saved_food.dart';
import '../../platform/web/web_barcode_scanner_screen.dart';
import '../../platform/web/web_barcode_support.dart';
import '../../services/macro_nutrition_consistency_policy.dart';
import '../../services/open_food_facts_service.dart';
import '../../state/app_controller.dart';
import '../../utils/nutrition_format.dart';
import '../../widgets/food/macro_nutrition_fields.dart';
import '../../widgets/food/macro_nutrition_input_controller.dart';
import '../../widgets/common/logged_at_picker_field.dart';
import '../../widgets/saved_food/saved_food_suggestion_list.dart';
import '../saved_food/public_food_search_screen.dart';
import 'food_form_template_actions.dart';

typedef BarcodeScanAvailabilityChecker = bool Function();

/// Web 向け食事追加・編集画面（カメラスキャン対応）。
class WebFoodFormScreen extends StatefulWidget {
  const WebFoodFormScreen({
    super.key,
    required this.controller,
    required this.openFoodFactsService,
    this.entry,
    this.initialPublicFood,
    this.initialLoggedAt,
    this.barcodeScanAvailabilityChecker = isWebBarcodeScanAvailable,
    this.barcodeLookupBuilder = WebBarcodeLookup.new,
  });

  final AppController controller;
  final OpenFoodFactsService openFoodFactsService;
  final FoodEntry? entry;
  final SavedFood? initialPublicFood;
  final DateTime? initialLoggedAt;
  final BarcodeScanAvailabilityChecker barcodeScanAvailabilityChecker;
  final WebBarcodeLookup Function(OpenFoodFactsService service)
  barcodeLookupBuilder;

  bool get isEditing => entry != null;

  @override
  State<WebFoodFormScreen> createState() => _WebFoodFormScreenState();
}

class _WebFoodFormScreenState extends State<WebFoodFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _barcodeController = TextEditingController();
  final _nameController = TextEditingController();
  final _quantityController = TextEditingController();
  late final MacroNutritionInputController _macroInput;

  bool _isSearching = false;
  bool _manualInputHighlighted = false;
  bool _fromSavedFoodSelection = false;
  FoodEntrySource _sourceType = FoodEntrySource.manual;
  String? _selectedSavedFoodId;
  String? _sourceFoodOwnerUserId;
  int? _sourceSavedFoodVersion;
  double _baseAmount = 1;
  FoodUnitType _unitType = FoodUnitType.serving;
  List<SavedFood> _savedFoodSuggestions = const [];
  late DateTime _loggedAt;

  bool get _usesSavedFoodBaseModel =>
      _fromSavedFoodSelection || _selectedSavedFoodId != null;

  @override
  void initState() {
    super.initState();
    _macroInput = MacroNutritionInputController();
    final entry = widget.entry;
    _loggedAt = (entry?.loggedAt ?? widget.initialLoggedAt ?? DateTime.now())
        .toLocal();
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

  Future<void> _openCameraScanner() async {
    if (_isSearching) {
      return;
    }

    if (!widget.barcodeScanAvailabilityChecker()) {
      _showMessage('カメラを利用できません。バーコード番号を入力してください。');
      return;
    }

    final barcode = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        builder: (context) => const WebBarcodeScannerScreen(),
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

    final lookup = widget.barcodeLookupBuilder(widget.openFoodFactsService);
    final result = await lookup.lookupRaw(barcode);

    if (!mounted) {
      return;
    }

    setState(() => _isSearching = false);

    if (result.normalized != null) {
      _barcodeController.text = result.normalized!;
    }

    if (result.failure != null) {
      setState(() => _manualInputHighlighted = true);
      _showMessage(messageForOffFailure(result.failure!));
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
      _sourceSavedFoodVersion = null;
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
      loggedAt: _loggedAt,
    );
  }

  MealTemplateItemDraft? _buildTemplateItemDraft() {
    if (!_macroInput.prepareForSave()) {
      return null;
    }

    final consumedAmount = _parseQuantity(_quantityController.text);
    final baseAmount = _usesSavedFoodBaseModel ? _baseAmount : 1.0;
    final unitType = _usesSavedFoodBaseModel ? _unitType : FoodUnitType.serving;

    return buildMealTemplateItemDraftFromFoodForm(
      name: _nameController.text,
      consumedAmount: consumedAmount,
      baseAmount: baseAmount,
      unitType: unitType,
      kcalPerBase: _macroInput.parseOptional(MacroField.kcal),
      proteinPerBase: _macroInput.parseOptional(MacroField.protein),
      fatPerBase: _macroInput.parseOptional(MacroField.fat),
      carbPerBase: _macroInput.parseOptional(MacroField.carb),
      savedFoodId: _selectedSavedFoodId,
      sourceOwnerUserId: _sourceFoodOwnerUserId,
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

  Future<void> _openTemplateCreate() {
    return openFoodTemplateCreate(context, widget.controller);
  }

  Future<void> _saveAsTemplate() async {
    final draft = _buildTemplateItemDraft();
    if (draft == null) {
      _showMessage('テンプレートに保存する内容を入力してください');
      return;
    }

    await saveCurrentFoodAsTemplate(
      context: context,
      controller: widget.controller,
      itemDraft: draft,
    );
  }

  Future<void> _save() async {
    if (_isSearching) {
      return;
    }

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
    } else {
      await widget.controller.saveFoodEntryWithOptionalSavedFood(
        entry: entry,
        saveAsFood: false,
      );
    }

    if (!mounted) {
      return;
    }
    Navigator.of(context).pop();
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

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        '今回の摂取: ${formatNullableNutrient(kcal)}kcal',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    );
  }

  Future<void> _openPublicFoodSearch() async {
    final food = await Navigator.of(context).push<SavedFood>(
      MaterialPageRoute<SavedFood>(
        builder: (context) => PublicFoodSearchScreen(
          controller: widget.controller,
          openFoodFactsService: widget.openFoodFactsService,
          selectForMealEntry: true,
        ),
      ),
    );
    if (food != null && mounted) {
      _applySavedFoodSelection(food);
    }
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
                OutlinedButton.icon(
                  onPressed: _openTemplatePicker,
                  icon: const Icon(Icons.view_list_outlined),
                  label: const Text('テンプレートから追加'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _openTemplateCreate,
                  icon: const Icon(Icons.add_box_outlined),
                  label: const Text('テンプレートを作成'),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _openPublicFoodSearch,
                  icon: const Icon(Icons.public),
                  label: const Text('公開食品を検索'),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _isSearching ? null : _openCameraScanner,
                  icon: const Icon(Icons.qr_code_scanner, size: 28),
                  label: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 14),
                    child: Text(
                      'カメラでバーコードを読み取る',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'バーコード（テキスト入力）',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const ValueKey('web_barcode_field'),
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
                key: const ValueKey('web_food_name_field'),
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
              if (!widget.isEditing) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _saveAsTemplate,
                  icon: const Icon(Icons.bookmark_add_outlined),
                  label: const Text('入力内容をテンプレートとして保存'),
                ),
              ],
              LoggedAtPickerField(
                loggedAt: _loggedAt,
                onChanged: (value) => setState(() => _loggedAt = value),
              ),
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
            onPressed: _isSearching ? null : _save,
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Text('保存', style: TextStyle(fontSize: 16)),
            ),
          ),
        ),
      ),
    );
  }
}

Widget webFoodFormScreenBuilder({
  required AppController controller,
  required OpenFoodFactsService openFoodFactsService,
  FoodEntry? entry,
  DateTime? initialLoggedAt,
  SavedFood? initialPublicFood,
}) {
  return WebFoodFormScreen(
    controller: controller,
    openFoodFactsService: openFoodFactsService,
    entry: entry,
    initialLoggedAt: initialLoggedAt,
    initialPublicFood: initialPublicFood,
  );
}
