import 'package:flutter/material.dart';

import '../../models/macro_field.dart';
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

  final Set<MacroField> _locked = {};
  bool _imeComposing = false;
  bool _suppressListener = false;
  MacroField? _activeField;
  String? _negativeMessage;
  MacroConsistencyWarning? _consistencyWarning;

  MacroFieldSource sourceOf(MacroField field) => _sources[field]!;

  String? get negativeMessage => _negativeMessage;

  MacroConsistencyWarning? get consistencyWarning => _consistencyWarning;

  bool get isImeComposing => _imeComposing;

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
    _setLoaded(MacroField.kcal, kcal);
    _setLoaded(MacroField.protein, protein);
    _setLoaded(MacroField.fat, fat);
    _setLoaded(MacroField.carb, carb);
    _locked.clear();
    _negativeMessage = null;
    _consistencyWarning = null;
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
    _sources[field] = MacroFieldSource.user;
    _locked.add(field);
    _recalculate(changedField: field);
  }

  ParsedMacroInput _parseField(MacroField field) {
    return NutritionValueCalculator.parse(controllerFor(field).text);
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
    _locked.add(field);
  }

  void _recalculate({MacroField? changedField}) {
    if (_imeComposing) {
      return;
    }
    _negativeMessage = null;
    _consistencyWarning = null;

    final kcal = _parseField(MacroField.kcal);
    final protein = _parseField(MacroField.protein);
    final fat = _parseField(MacroField.fat);
    final carb = _parseField(MacroField.carb);

    final allValid = [kcal, protein, fat, carb].every((f) => f.isValid);
    if (allValid) {
      _consistencyWarning = NutritionValueCalculator.checkConsistency(
        kcal: kcal.value!,
        protein: protein.value!,
        fat: fat.value!,
        carb: carb.value!,
      );
      notifyListeners();
      return;
    }

    final result = NutritionValueCalculator.calculateMissing(
      kcal: kcal,
      protein: protein,
      fat: fat,
      carb: carb,
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

    final target = result.field;
    if (_locked.contains(target) && changedField != target) {
      notifyListeners();
      return;
    }
    if (_activeField == target) {
      notifyListeners();
      return;
    }

    _suppressListener = true;
    controllerFor(target).text = NutritionValueCalculator.formatForField(
      target,
      result.value!,
    );
    _sources[target] = MacroFieldSource.auto;
    _suppressListener = false;
    notifyListeners();
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
