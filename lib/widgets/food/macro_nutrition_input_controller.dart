import 'package:flutter/material.dart';

import '../../constants/app_strings.dart';
import '../../models/macro_field.dart';
import '../../utils/macro_display.dart';
import '../../services/macro_nutrition_consistency_policy.dart';
import '../../services/nutrition_value_calculator.dart';

/// 食事フォームの kcal / P / F / C 入力状態を管理する。
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
  MacroNutritionConsistencyMode _consistencyMode =
      MacroNutritionConsistencyMode.manual;
  bool _nutritionEditedByUser = false;
  bool _imeComposing = false;
  bool _suppressListener = false;
  MacroField? _activeField;
  String? _negativeMessage;

  MacroFieldSource sourceOf(MacroField field) => _sources[field]!;

  MacroField? get autoField => _autoField;

  MacroNutritionConsistencyMode get consistencyMode => _consistencyMode;

  bool get nutritionEditedByUser => _nutritionEditedByUser;

  String? get negativeMessage => _negativeMessage;

  bool get isImeComposing => _imeComposing;

  bool get showExternalMismatchNotice {
    if (_consistencyMode != MacroNutritionConsistencyMode.preserveExternal) {
      return false;
    }

    final parsed = _parseAll();
    if (_validCount(parsed) < 4) {
      return false;
    }

    return NutritionValueCalculator.hasExternalCalorieMismatch(
      kcal: parsed.kcal.value!,
      protein: parsed.protein.value!,
      fat: parsed.fat.value!,
      carb: parsed.carb.value!,
    );
  }

  bool get canSave {
    if (_negativeMessage != null) {
      return false;
    }

    if (_consistencyMode == MacroNutritionConsistencyMode.preserveExternal) {
      return true;
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
    MacroNutritionConsistencyMode consistencyMode =
        MacroNutritionConsistencyMode.manual,
  }) {
    _suppressListener = true;
    _consistencyMode = consistencyMode;
    _nutritionEditedByUser = false;
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
    _consistencyMode = MacroNutritionConsistencyMode.preserveExternal;
    _nutritionEditedByUser = false;
    _manualOrder.clear();
    _autoField = null;
    _previousAutoField = null;
    _negativeMessage = null;

    if (kcal != null) {
      _setExternal(MacroField.kcal, kcal);
    } else {
      _clearField(MacroField.kcal);
    }
    if (protein != null) {
      _setExternal(MacroField.protein, protein);
    } else {
      _clearField(MacroField.protein);
    }
    if (fat != null) {
      _setExternal(MacroField.fat, fat);
    } else {
      _clearField(MacroField.fat);
    }
    if (carb != null) {
      _setExternal(MacroField.carb, carb);
    } else {
      _clearField(MacroField.carb);
    }

    _suppressListener = false;
    notifyListeners();
  }

  /// 保存直前に最終整合を行う。成功時 true。
  bool prepareForSave() {
    if (_consistencyMode == MacroNutritionConsistencyMode.preserveExternal) {
      return canSave;
    }

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

    final textController = controllerFor(field);
    // IME composition中はこの1回だけスキップ（数字キーボードでは通常発生しない）。
    // composing.isValid を永続フラグにしない（過去の入力が永久にブロックされるのを防ぐ）。
    if (textController.value.composing.isValid) {
      return;
    }

    final parsed = NutritionValueCalculator.parse(textController.text);
    if (parsed.state == MacroParseState.empty) {
      _sources[field] = MacroFieldSource.empty;
      _manualOrder.remove(field);
      if (_autoField == field) {
        _autoField = null;
      } else if (_autoField != null) {
        _clearAutoField(_autoField!);
      }
      _activateManualModeIfNeeded();
      _recalculate(changedField: field);
      return;
    }

    _activateManualModeIfNeeded();

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

  void _activateManualModeIfNeeded() {
    if (_consistencyMode == MacroNutritionConsistencyMode.preserveExternal) {
      _consistencyMode = MacroNutritionConsistencyMode.manual;
      _nutritionEditedByUser = true;
    }
  }

  void _registerManual(MacroField field) {
    _manualOrder.remove(field);
    _manualOrder.add(field);
    if (_sources[field] == MacroFieldSource.auto) {
      _sources[field] = MacroFieldSource.user;
    }
  }

  void _setLoaded(MacroField field, double? value) {
    if (value == null) {
      _clearField(field);
      return;
    }
    controllerFor(field).text = NutritionValueCalculator.formatForField(
      field,
      value,
    );
    _sources[field] = MacroFieldSource.loaded;
  }

  void _setExternal(MacroField field, double value) {
    controllerFor(field).text = NutritionValueCalculator.formatForField(
      field,
      value,
    );
    _sources[field] = MacroFieldSource.external;
  }

  void _clearField(MacroField field) {
    controllerFor(field).text = '';
    _sources[field] = MacroFieldSource.empty;
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
    if (_consistencyMode == MacroNutritionConsistencyMode.preserveExternal) {
      _negativeMessage = null;
      notifyListeners();
      return;
    }

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

    // 4項目すべて入力済みの整合時のみ、編集中フィールドの上書きを避ける。
    if (validCount == 4 && _activeField == target && !force) {
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

  String _label(MacroField field) => macroFieldLabel(field);

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
