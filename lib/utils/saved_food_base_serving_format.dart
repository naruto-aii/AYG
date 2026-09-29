import '../models/saved_food.dart';

/// 保存済み食品の基準量表示・入力正規化。
class SavedFoodBaseServingFormat {
  SavedFoodBaseServingFormat._();

  static const unsetLabel = '基準量未設定';

  /// 整数は小数点なし、小数は末尾ゼロを除いて表示する。
  static String formatQuantity(double value) {
    if (value.isNaN || value.isInfinite || value <= 0) {
      return value.toString();
    }
    if (value == value.truncateToDouble()) {
      return value.toInt().toString();
    }
    var formatted = value.toStringAsFixed(4);
    formatted = formatted.replaceFirst(RegExp(r'0+$'), '');
    formatted = formatted.replaceFirst(RegExp(r'\.$'), '');
    return formatted;
  }

  static String formatPerBaseLabel({
    required bool baseServingDefined,
    required double baseAmount,
    required String baseUnit,
  }) {
    if (!baseServingDefined) {
      return unsetLabel;
    }
    final unit = baseUnit.trim();
    if (unit.isEmpty || baseAmount <= 0) {
      return unsetLabel;
    }
    return '${formatQuantity(baseAmount)}$unitあたり';
  }

  static String formatSavedFood(SavedFood food) {
    return formatPerBaseLabel(
      baseServingDefined: food.baseServingDefined,
      baseAmount: food.baseAmount,
      baseUnit: food.baseUnit,
    );
  }

  static String? validateQuantity(String? raw, {String label = '基準数量'}) {
    if (raw == null || raw.trim().isEmpty) {
      return '$labelを入力してください';
    }
    final parsed = double.tryParse(raw.trim());
    if (parsed == null || parsed <= 0) {
      return '$labelは0より大きい数値で入力してください';
    }
    return null;
  }

  static String? validateUnit(String? raw, {String label = '基準単位'}) {
    if (raw == null || raw.trim().isEmpty) {
      return '$labelを入力してください';
    }
    return null;
  }

  static double? parseQuantity(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    final parsed = double.tryParse(trimmed);
    if (parsed == null || parsed <= 0) {
      return null;
    }
    return parsed;
  }

  static String? parseUnit(String raw) {
    final trimmed = raw.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
