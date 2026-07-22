import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../models/food_entry.dart';
import '../../models/macro_field.dart';
import '../../services/open_food_facts_service.dart';
import '../../state/app_controller.dart';
import '../../widgets/food/macro_nutrition_fields.dart';
import '../../widgets/food/macro_nutrition_input_controller.dart';
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
}
