import 'package:flutter/material.dart';

import '../../models/food_entry.dart';
import '../../models/macro_field.dart';
import '../../platform/web/web_barcode_scanner_screen.dart';
import '../../platform/web/web_barcode_support.dart';
import '../../services/open_food_facts_service.dart';
import '../../state/app_controller.dart';
import '../../widgets/food/macro_nutrition_fields.dart';
import '../../widgets/food/macro_nutrition_input_controller.dart';

typedef BarcodeScanAvailabilityChecker = bool Function();

/// Web 向け食事追加・編集画面（カメラスキャン対応）。
class WebFoodFormScreen extends StatefulWidget {
  const WebFoodFormScreen({
    super.key,
    required this.controller,
    required this.openFoodFactsService,
    this.entry,
    this.barcodeScanAvailabilityChecker = isWebBarcodeScanAvailable,
    this.barcodeLookupBuilder = WebBarcodeLookup.new,
  });

  final AppController controller;
  final OpenFoodFactsService openFoodFactsService;
  final FoodEntry? entry;
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

  @override
  void initState() {
    super.initState();
    _macroInput = MacroNutritionInputController();
    final entry = widget.entry;
    _nameController.text = entry?.name ?? '';
    _macroInput.initializeFromNullable(
      kcal: entry?.kcalPerUnit,
      protein: entry?.proteinPerUnit,
      fat: entry?.fatPerUnit,
      carb: entry?.carbPerUnit,
    );
    _quantityController.text = entry?.quantity.toString() ?? '1';
  }

  @override
  void dispose() {
    _barcodeController.dispose();
    _nameController.dispose();
    _quantityController.dispose();
    _macroInput.dispose();
    super.dispose();
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

    return FoodEntry(
      id: widget.entry?.id ?? widget.controller.generateId(),
      name: _nameController.text.trim(),
      kcalPerUnit: _macroInput.parseOptional(MacroField.kcal),
      proteinPerUnit: _macroInput.parseOptional(MacroField.protein),
      fatPerUnit: _macroInput.parseOptional(MacroField.fat),
      carbPerUnit: _macroInput.parseOptional(MacroField.carb),
      quantity: _parseQuantity(_quantityController.text),
      loggedAt: widget.entry?.loggedAt ?? DateTime.now(),
    );
  }

  void _save() {
    if (_isSearching) {
      return;
    }

    final entry = _buildEntry();
    if (entry == null) {
      return;
    }

    if (widget.isEditing) {
      widget.controller.updateFood(entry);
    } else {
      widget.controller.addFood(entry);
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

    widget.controller.deleteFood(entry.id);
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

  @override
  Widget build(BuildContext context) {
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
              const SizedBox(height: 16),
              MacroNutritionFields(
                controller: _macroInput,
                validator: (value, label) =>
                    _validateOptionalNonNegativeNumber(label)(value),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _quantityController,
                decoration: const InputDecoration(
                  labelText: '数量（未入力時は1）',
                  border: OutlineInputBorder(),
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
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
}) {
  return WebFoodFormScreen(
    controller: controller,
    openFoodFactsService: openFoodFactsService,
    entry: entry,
  );
}
