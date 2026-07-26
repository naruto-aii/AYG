import 'package:flutter/material.dart';

import '../../models/macro_field.dart';
import '../../services/nutrition_value_calculator.dart';

/// 食事フォームの kcal / P / F / C 入力状態を管理する。
///
/// 常に「手入力 3 項目 + 自動計算 1 項目」を維持する。
class MacroNutritionInputController extends ChangeNotifier {
  MacroNutritionInputController();

  final kcalController = TextEditingController();
  final proteinController = TextEditingController();
  final fatController = TextEditingController();
  final carbController = TextEditingController();

  final Map<MacroField, MacroFieldSource> _sources = {
    MacroField.kcal: MacroFieldSource.empty,
    MacroField.protein: MacroFieldSource.empty,
    MacroField.fat: MacroFieldSource.empty,
    MacroField.carb: MacroFieldSource.empty,
  };

  final List<MacroField> _manualOrder = [];
  MacroField? _autoField;
  MacroField? _previousAutoField;
  bool _imeComposing = false;
  bool _suppressListener = false;
  MacroField? _activeField;
  String? _negativeMessage;

  MacroFieldSource sourceOf(MacroField field) => _sources[field]!;

  MacroField? get autoField => _autoField;

  String? get negativeMessage => _negativeMessage;

  bool get isImeComposing => _imeComposing;

  bool get canSave {
    if (_negativeMessage != null) {
      return false;
    }

    final parsed = _parseAll();
    final validCount = _validCount(parsed);
    if (validCount <= 2) {
      return true;
    }
    if (validCount == 3) {
      return true;
    }

    return NutritionValueCalculator.isConsistent(
      kcal: parsed.kcal.value!,
      protein: parsed.protein.value!,
      fat: parsed.fat.value!,
      carb: parsed.carb.value!,
    );
  }

  TextEditingController controllerFor(MacroField field) {
    return switch (field) {
      MacroField.kcal => kcalController,
      MacroField.protein => proteinController,
      MacroField.fat => fatController,
      MacroField.carb => carbController,
    };
  }

  void initializeFromNullable({
    double? kcal,
    double? protein,
    double? fat,
    double? carb,
  }) {
    _suppressListener = true;
    _manualOrder.clear();
    _autoField = null;
    _previousAutoField = null;
    _setLoaded(MacroField.kcal, kcal);
    _setLoaded(MacroField.protein, protein);
    _setLoaded(MacroField.fat, fat);
    _setLoaded(MacroField.carb, carb);
    _negativeMessage = null;
    _suppressListener = false;
    notifyListeners();
  }

  void applyExternalValues({
    double? kcal,
    double? protein,
    double? fat,
    double? carb,
  }) {
    _suppressListener = true;
    _manualOrder.clear();
    _autoField = null;
    _previousAutoField = null;
    if (kcal != null) {
      _setUser(MacroField.kcal, kcal);
    }
    if (protein != null) {
      _setUser(MacroField.protein, protein);
    }
    if (fat != null) {
      _setUser(MacroField.fat, fat);
    }
    if (carb != null) {
      _setUser(MacroField.carb, carb);
    }
    _suppressListener = false;
    _recalculate(changedField: null);
  }

  /// 保存直前に最終整合を行う。成功時 true。
  bool prepareForSave() {
    _recalculate(changedField: null, force: true);
    return canSave;
  }

  void setImeComposing(bool composing) {
    if (_imeComposing == composing) {
      return;
    }
    _imeComposing = composing;
    if (!composing) {
      _recalculate(changedField: _activeField);
    }
  }

  void onFieldFocus(MacroField field) {
    _activeField = field;
  }

  void onFieldChanged(MacroField field) {
    if (_suppressListener) {
      return;
    }
    if (_imeComposing) {
      return;
    }
    final textController = controllerFor(field);
    if (textController.value.composing.isValid) {
      _imeComposing = true;
      return;
    }
    _imeComposing = false;

    final parsed = NutritionValueCalculator.parse(textController.text);
    if (parsed.state == MacroParseState.empty) {
      _sources[field] = MacroFieldSource.empty;
      _manualOrder.remove(field);
      if (_autoField == field) {
        _autoField = null;
      }
      _recalculate(changedField: field);
      return;
    }

    if (field == _autoField) {
      _previousAutoField = _autoField;
      _autoField = null;
    }

    _sources[field] = MacroFieldSource.user;
    _registerManual(field);
    _recalculate(changedField: field);
  }

  ParsedMacroInput _parseField(MacroField field) {
    return NutritionValueCalculator.parse(controllerFor(field).text);
  }

  ({
    ParsedMacroInput kcal,
    ParsedMacroInput protein,
    ParsedMacroInput fat,
    ParsedMacroInput carb,
  })
  _parseAll() {
    return (
      kcal: _parseField(MacroField.kcal),
      protein: _parseField(MacroField.protein),
      fat: _parseField(MacroField.fat),
      carb: _parseField(MacroField.carb),
    );
  }

  int _validCount(
    ({
      ParsedMacroInput kcal,
      ParsedMacroInput protein,
      ParsedMacroInput fat,
      ParsedMacroInput carb,
    })
    parsed,
  ) {
    return [
      parsed.kcal,
      parsed.protein,
      parsed.fat,
      parsed.carb,
    ].where((field) => field.isValid).length;
  }

  void _registerManual(MacroField field) {
    _manualOrder.remove(field);
    _manualOrder.add(field);
    if (_sources[field] == MacroFieldSource.auto) {
      _sources[field] = MacroFieldSource.user;
    }
  }

  void _setLoaded(MacroField field, double? value) {
    final controller = controllerFor(field);
    if (value == null) {
      controller.text = '';
      _sources[field] = MacroFieldSource.empty;
      return;
    }
    controller.text = NutritionValueCalculator.formatForField(field, value);
    _sources[field] = MacroFieldSource.loaded;
  }

  void _setUser(MacroField field, double value) {
    controllerFor(field).text = NutritionValueCalculator.formatForField(
      field,
      value,
    );
    _sources[field] = MacroFieldSource.user;
    _registerManual(field);
  }

  MacroField? _pickAutoField({
    required MacroField? changedField,
    required int validCount,
  }) {
    if (validCount == 3) {
      for (final field in MacroField.values) {
        if (!_parseField(field).isValid) {
          return field;
        }
      }
      return null;
    }

    if (validCount == 4) {
      if (_autoField != null) {
        return _autoField;
      }
      if (_previousAutoField != null &&
          _previousAutoField != changedField &&
          _parseField(_previousAutoField!).isValid) {
        return _previousAutoField;
      }
      for (final field in _manualOrder) {
        if (field != changedField && _parseField(field).isValid) {
          return field;
        }
      }
    }

    return null;
  }

  void _recalculate({MacroField? changedField, bool force = false}) {
    if (_imeComposing && !force) {
      return;
    }
    _negativeMessage = null;

    final parsed = _parseAll();
    final values = [parsed.kcal, parsed.protein, parsed.fat, parsed.carb];
    if (values.any(
      (field) =>
          field.state == MacroParseState.partial ||
          field.state == MacroParseState.invalid,
    )) {
      notifyListeners();
      return;
    }

    final validCount = _validCount(parsed);
    if (validCount <= 2) {
      if (_autoField != null) {
        _clearAutoField(_autoField!);
      }
      notifyListeners();
      return;
    }

    final target = _pickAutoField(
      changedField: changedField,
      validCount: validCount,
    );
    if (target == null) {
      notifyListeners();
      return;
    }

    if (_activeField == target && !force) {
      notifyListeners();
      return;
    }

    final result = validCount == 3
        ? NutritionValueCalculator.calculateMissing(
            kcal: parsed.kcal,
            protein: parsed.protein,
            fat: parsed.fat,
            carb: parsed.carb,
            targetField: target,
          )
        : NutritionValueCalculator.reconcileField(
            field: target,
            kcal: parsed.kcal,
            protein: parsed.protein,
            fat: parsed.fat,
            carb: parsed.carb,
          );

    if (result == null) {
      notifyListeners();
      return;
    }

    if (result.negative) {
      _negativeMessage =
          '入力値の組み合わせでは${_label(result.field)}を'
          '正の値に計算できません。';
      notifyListeners();
      return;
    }

    _applyAutoValue(target, result.value!);
    notifyListeners();
  }

  void _applyAutoValue(MacroField field, double value) {
    if (_autoField != null && _autoField != field) {
      _manualOrder.remove(_autoField);
    }

    _suppressListener = true;
    controllerFor(field).text = NutritionValueCalculator.formatForField(
      field,
      value,
    );
    _sources[field] = MacroFieldSource.auto;
    _manualOrder.remove(field);
    _autoField = field;
    _previousAutoField = field;
    _suppressListener = false;
  }

  void _clearAutoField(MacroField field) {
    _suppressListener = true;
    controllerFor(field).text = '';
    _sources[field] = MacroFieldSource.empty;
    _manualOrder.remove(field);
    if (_autoField == field) {
      _autoField = null;
    }
    _suppressListener = false;
  }

  String _label(MacroField field) {
    return switch (field) {
      MacroField.kcal => 'カロリー',
      MacroField.protein => 'たんぱく質',
      MacroField.fat => '脂質',
      MacroField.carb => '炭水化物',
    };
  }

  double? parseOptional(MacroField field) {
    final parsed = _parseField(field);
    if (!parsed.isValid) {
      return null;
    }
    return parsed.value;
  }

  @override
  void dispose() {
    kcalController.dispose();
    proteinController.dispose();
    fatController.dispose();
    carbController.dispose();
    super.dispose();
  }
}
