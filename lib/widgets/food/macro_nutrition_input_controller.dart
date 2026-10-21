import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../models/macro_field.dart';
import '../../services/macro_nutrition_consistency_policy.dart';
import '../../services/nutrition_value_calculator.dart';
import '../../utils/macro_display.dart';
import '../../utils/recorded_number.dart';

/// 食事フォームの kcal / P / F / C 入力状態を管理する。
///
/// 空欄で、ユーザーが一度も触っていない欄だけを自動で埋める。
/// カロリーの修正は編集開始時の PFC を同じ比率で伸ばし、
/// P / F / C の修正はカロリーを差分だけ動かす。
class MacroNutritionInputController extends ChangeNotifier {
  MacroNutritionInputController();

  final kcalController = TextEditingController();
  final proteinController = TextEditingController();
  final fatController = TextEditingController();
  final carbController = TextEditingController();

  final Map<MacroField, MacroFieldSource> _sources = {
    for (final field in MacroField.values) field: MacroFieldSource.empty,
  };

  final Map<MacroField, double?> _committed = {
    for (final field in MacroField.values) field: null,
  };

  final Set<MacroField> _touched = {};

  MacroNutritionConsistencyMode _consistencyMode =
      MacroNutritionConsistencyMode.manual;
  bool _nutritionEditedByUser = false;
  bool _imeComposing = false;
  bool _suppressListener = false;
  bool _disposed = false;
  bool _rebuildScheduled = false;
  MacroField? _lastChangedField;
  MacroField? _baselineField;
  _MacroBaseline? _baseline;
  String? _negativeMessage;

  MacroFieldSource sourceOf(MacroField field) => _sources[field]!;

  MacroField? get autoField {
    for (final field in MacroField.values) {
      if (_sources[field] == MacroFieldSource.auto) {
        return field;
      }
    }
    return null;
  }

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

    for (final field in MacroField.values) {
      if (_textIsNegative(field)) {
        return false;
      }
    }
    return true;
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
    _resetEditSession();
    _touched.clear();
    _negativeMessage = null;
    _setLoaded(MacroField.kcal, kcal);
    _setLoaded(MacroField.protein, protein);
    _setLoaded(MacroField.fat, fat);
    _setLoaded(MacroField.carb, carb);
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
    _resetEditSession();
    _touched.clear();
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

  /// 保存直前の確認。ユーザーが入れた値は書き換えない。
  bool prepareForSave() {
    return canSave;
  }

  void setImeComposing(bool composing) {
    if (_imeComposing == composing) {
      return;
    }
    _imeComposing = composing;
    if (!composing && _lastChangedField != null) {
      onFieldChanged(_lastChangedField!);
    }
  }

  void onFieldFocus(MacroField field) {
    // タップごとに編集を始め直す。同じ欄の打鍵は baseline を更新しない。
    _baseline = null;
    _baselineField = null;
    _ensureBaseline(field);
    if (_sources[field] != MacroFieldSource.auto) {
      return;
    }
    _sources[field] = MacroFieldSource.user;
    _touched.add(field);
    notifyListeners();
  }

  void onFieldChanged(MacroField field) {
    if (_suppressListener || _disposed) {
      return;
    }

    final textController = controllerFor(field);
    final parsed = NutritionValueCalculator.parse(textController.text);
    // 数字として確定している入力は、IME の composing 範囲が残っていても計算する。
    // Web では通常の数字入力でも composing が有効なままになり、残り欄が更新されない。
    if (textController.value.composing.isValid &&
        parsed.state != MacroParseState.valid &&
        parsed.state != MacroParseState.empty) {
      return;
    }

    _lastChangedField = field;
    _ensureBaseline(field);
    _activateManualModeIfNeeded();

    if (_imeComposing) {
      notifyListeners();
      return;
    }

    _commitEdit(field, parsed);
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

  void _resetEditSession() {
    _baseline = null;
    _baselineField = null;
    _lastChangedField = null;
  }

  void _ensureBaseline(MacroField field) {
    if (_baselineField == field && _baseline != null) {
      return;
    }
    _baselineField = field;
    _baseline = _MacroBaseline(
      values: Map<MacroField, double?>.from(_committed),
      sources: Map<MacroField, MacroFieldSource>.from(_sources),
    );
  }

  void _setLoaded(MacroField field, double? value) {
    if (value == null) {
      _clearField(field);
      return;
    }
    _writeText(field, value, source: MacroFieldSource.loaded, reveal: false);
  }

  void _setExternal(MacroField field, double value) {
    _writeText(field, value, source: MacroFieldSource.external, reveal: false);
  }

  void _clearField(MacroField field) {
    controllerFor(field).text = '';
    _sources[field] = MacroFieldSource.empty;
    _committed[field] = null;
  }

  void _commitEdit(MacroField field, ParsedMacroInput parsed) {
    final baseline = _baseline!;
    _negativeMessage = null;

    if (parsed.state == MacroParseState.partial ||
        parsed.state == MacroParseState.invalid) {
      _touched.add(field);
      _sources[field] = MacroFieldSource.user;
      if (_textIsNegative(field)) {
        _negativeMessage = '${_label(field)}は0以上の数値を入力してください';
      }
      if (_isFirstFill(field, baseline)) {
        _undoSessionAutos(baseline);
      } else {
        _restoreScaledFields(field, baseline);
      }
      _notify();
      return;
    }

    if (parsed.state == MacroParseState.empty) {
      _touched.add(field);
      _sources[field] = MacroFieldSource.empty;
      _committed[field] = null;
      _applyClear(field, baseline);
      _notify();
      return;
    }

    _touched.add(field);
    _sources[field] = MacroFieldSource.user;
    _committed[field] = parsed.value;
    _applyValue(field, parsed.value!, baseline);
    _notify();
  }

  void _applyClear(MacroField field, _MacroBaseline baseline) {
    final previous = baseline.values[field];
    final previousSource = baseline.sources[field]!;
    if (_isFirstFill(field, baseline)) {
      _undoSessionAutos(baseline);
      return;
    }
    if (field == MacroField.kcal) {
      if (previous != 0) {
        _restorePfc(baseline);
      }
      return;
    }
    if (previousSource == MacroFieldSource.auto) {
      return;
    }
    _applyDelta(field, 0, baseline);
  }

  bool _isFirstFill(MacroField field, _MacroBaseline baseline) {
    final previous = baseline.values[field];
    final previousSource = baseline.sources[field]!;
    return previous == null || previousSource == MacroFieldSource.empty;
  }

  /// この編集で空欄から埋めた自動値を、編集開始時の空欄に戻す。
  void _undoSessionAutos(_MacroBaseline baseline) {
    for (final field in MacroField.values) {
      if (baseline.values[field] != null) {
        continue;
      }
      if (_sources[field] != MacroFieldSource.auto) {
        continue;
      }
      _suppressListener = true;
      controllerFor(field).text = '';
      _suppressListener = false;
      _sources[field] = MacroFieldSource.empty;
      _committed[field] = null;
      _touched.remove(field);
      if (field != _baselineField) {
        _revealController(controllerFor(field));
      }
    }
  }

  void _applyValue(MacroField field, double value, _MacroBaseline baseline) {
    final previous = baseline.values[field];
    final previousSource = baseline.sources[field]!;

    if (field == MacroField.kcal) {
      if (previous == null) {
        _maybeAutoFillMissing();
        return;
      }
      if (previous == 0) {
        return;
      }
      _scalePfc(baseline, value);
      return;
    }

    final firstFill =
        previous == null || previousSource == MacroFieldSource.empty;
    if (firstFill) {
      _maybeAutoFillMissing();
      return;
    }
    _applyDelta(field, value, baseline);
  }

  void _restoreScaledFields(MacroField field, _MacroBaseline baseline) {
    if (field == MacroField.kcal) {
      final previous = baseline.values[MacroField.kcal];
      if (previous != null && previous != 0) {
        _restorePfc(baseline);
      }
      return;
    }
    final previous = baseline.values[field];
    final previousSource = baseline.sources[field]!;
    if (previous != null && previousSource != MacroFieldSource.empty) {
      _restoreField(MacroField.kcal, baseline);
    }
  }

  void _scalePfc(_MacroBaseline baseline, double newKcal) {
    final oldKcal = baseline.values[MacroField.kcal]!;
    final ratio = newKcal / oldKcal;
    for (final field in const [
      MacroField.protein,
      MacroField.fat,
      MacroField.carb,
    ]) {
      final base = baseline.values[field];
      if (base == null) {
        continue;
      }
      _writeText(field, base * ratio, source: baseline.sources[field]!);
    }
  }

  void _restorePfc(_MacroBaseline baseline) {
    for (final field in const [
      MacroField.protein,
      MacroField.fat,
      MacroField.carb,
    ]) {
      _restoreField(field, baseline);
    }
  }

  void _restoreField(MacroField field, _MacroBaseline baseline) {
    final base = baseline.values[field];
    if (base == null) {
      return;
    }
    _writeText(field, base, source: baseline.sources[field]!);
  }

  void _applyDelta(MacroField field, double newValue, _MacroBaseline baseline) {
    final oldValue = baseline.values[field] ?? 0;
    final oldKcal = baseline.values[MacroField.kcal];
    if (oldKcal == null) {
      return;
    }
    final next = oldKcal + (newValue - oldValue) * _kcalPerGram(field);
    if (next < 0) {
      _negativeMessage =
          '入力値の組み合わせでは${_label(MacroField.kcal)}を'
          '正の値に計算できません。';
      _restoreField(MacroField.kcal, baseline);
      return;
    }
    _writeText(
      MacroField.kcal,
      next,
      source: baseline.sources[MacroField.kcal]!,
    );
  }

  void _maybeAutoFillMissing() {
    final parsed = _parseAll();
    final values = [parsed.kcal, parsed.protein, parsed.fat, parsed.carb];
    if (values.any(
      (field) =>
          field.state == MacroParseState.partial ||
          field.state == MacroParseState.invalid,
    )) {
      return;
    }

    final emptyUntouched = <MacroField>[];
    var validCount = 0;
    for (final field in MacroField.values) {
      final value = _parseField(field);
      if (value.isValid) {
        validCount++;
      } else if (value.state == MacroParseState.empty &&
          !_touched.contains(field)) {
        emptyUntouched.add(field);
      }
    }
    if (validCount != 3 || emptyUntouched.length != 1) {
      return;
    }

    final target = emptyUntouched.single;
    final result = NutritionValueCalculator.calculateMissing(
      kcal: parsed.kcal,
      protein: parsed.protein,
      fat: parsed.fat,
      carb: parsed.carb,
      targetField: target,
    );
    if (result == null) {
      return;
    }
    if (result.negative || result.value == null) {
      _negativeMessage =
          '入力値の組み合わせでは${_label(target)}を'
          '正の値に計算できません。';
      return;
    }
    _writeText(target, result.value!, source: MacroFieldSource.auto);
  }

  void _writeText(
    MacroField field,
    double value, {
    required MacroFieldSource source,
    bool reveal = true,
  }) {
    final preserve =
        source == MacroFieldSource.loaded ||
        source == MacroFieldSource.external;
    final rounded = preserve ? value : _round(field, value);
    final text = preserve
        ? formatRecordedNumber(rounded)
        : NutritionValueCalculator.formatForField(field, rounded);
    final current = _parseField(field);
    final sameValue =
        current.isValid && (current.value! - rounded).abs() < 0.001;
    if (sameValue && _sources[field] == source) {
      _committed[field] = current.value;
      return;
    }

    _suppressListener = true;
    controllerFor(field).text = text;
    _suppressListener = false;
    _sources[field] = source;
    _committed[field] = NutritionValueCalculator.parse(text).value ?? rounded;
    if (source == MacroFieldSource.auto) {
      _touched.remove(field);
    }
    if (reveal && field != _baselineField) {
      _revealController(controllerFor(field));
    }
  }

  void _notify() {
    notifyListeners();
    if (_disposed || _rebuildScheduled) {
      return;
    }
    final binding = WidgetsBinding.instance;
    if (binding.schedulerPhase == SchedulerPhase.idle &&
        !binding.hasScheduledFrame) {
      return;
    }
    _rebuildScheduled = true;
    binding.addPostFrameCallback((_) {
      _rebuildScheduled = false;
      if (_disposed) {
        return;
      }
      notifyListeners();
    });
  }

  /// 入力中の欄とは別の TextField へ、計算結果を次のフレームで描く。
  void _revealController(TextEditingController controller) {
    final binding = WidgetsBinding.instance;
    if (binding.schedulerPhase == SchedulerPhase.idle &&
        !binding.hasScheduledFrame) {
      return;
    }
    final text = controller.text;
    binding.addPostFrameCallback((_) {
      if (_disposed || controller.text != text) {
        return;
      }
      controller.value = TextEditingValue(
        text: text.isEmpty ? ' ' : text,
        selection: const TextSelection.collapsed(offset: 0),
      );
      if (_disposed) {
        return;
      }
      controller.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
    });
  }

  bool _textIsNegative(MacroField field) {
    final parsed = double.tryParse(controllerFor(field).text.trim());
    return parsed != null && parsed < 0;
  }

  double _kcalPerGram(MacroField field) {
    return switch (field) {
      MacroField.protein || MacroField.carb => 4,
      MacroField.fat => 9,
      MacroField.kcal => 0,
    };
  }

  double _round(MacroField field, double value) {
    return switch (field) {
      MacroField.kcal => value.roundToDouble(),
      MacroField.protein ||
      MacroField.fat ||
      MacroField.carb => (value * 10).roundToDouble() / 10,
    };
  }

  String _label(MacroField field) => macroFieldLabel(field);

  double? parseOptional(MacroField field) {
    final parsed = _parseField(field);
    if (!parsed.isValid) {
      return null;
    }
    return parsed.value;
  }

  /// 量の変更で、基準時点の4欄を同じ倍率にする。空欄は空欄のまま。出典は変えない。
  void restoreQuantityScale({
    required Map<MacroField, String> baselineText,
    double ratio = 1,
  }) {
    _suppressListener = true;
    for (final field in MacroField.values) {
      final raw = baselineText[field] ?? '';
      final parsed = NutritionValueCalculator.parse(raw);
      final controller = controllerFor(field);
      final source = _sources[field] ?? MacroFieldSource.empty;
      if (!parsed.isValid ||
          parsed.value == null ||
          !ratio.isFinite ||
          ratio <= 0) {
        controller.text = raw;
        _sources[field] = source;
        continue;
      }
      final text = NutritionValueCalculator.formatForField(
        field,
        parsed.value! * ratio,
      );
      controller.text = text;
      _sources[field] = source;
      _committed[field] = NutritionValueCalculator.parse(text).value;
    }
    _suppressListener = false;
    _resetEditSession();
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    kcalController.dispose();
    proteinController.dispose();
    fatController.dispose();
    carbController.dispose();
    super.dispose();
  }
}

class _MacroBaseline {
  const _MacroBaseline({required this.values, required this.sources});

  final Map<MacroField, double?> values;
  final Map<MacroField, MacroFieldSource> sources;
}
