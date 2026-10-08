import 'dart:typed_data';

import 'package:image/image.dart' as img;

import '../models/food_entry.dart';
import '../models/food_entry_source.dart';
import '../models/food_unit_type.dart';
import '../state/app_controller.dart';

/// サーバと同じ上限。負の値と、ありえない大きさは記録しない。
const photoMealMaxKcal = 10000.0;
const photoMealMaxMacroG = 1000.0;
const photoMealPfcAbsoluteKcal = 50.0;
const photoMealPfcRelative = 0.2;
const photoMealLongEdge = 1024;
const photoMealNoteMaxLength = 100;

const photoMealNoteChips = <String>[
  '油多め',
  '油少なめ',
  '脂身多め',
  'タレ・ソース多め',
  'ご飯少なめ',
  '揚げ物',
  '皮なし',
];

/// チップは文末に足す。既にある語と、100字を超える足し方は変えない。
String appendPhotoMealNote(
  String current,
  String chip, {
  int maxLength = photoMealNoteMaxLength,
}) {
  if (chip.isEmpty || current.contains(chip)) {
    return current;
  }
  final next = current.isEmpty ? chip : '$current、$chip';
  if (next.length > maxLength) {
    return current;
  }
  return next;
}

class PhotoMealItemEstimate {
  const PhotoMealItemEstimate({
    required this.name,
    required this.amount,
    required this.kcal,
    required this.proteinG,
    required this.fatG,
    required this.carbG,
  });

  final String name;
  final String amount;
  final double kcal;
  final double proteinG;
  final double fatG;
  final double carbG;
}

class PhotoMealEstimate {
  const PhotoMealEstimate({
    required this.dishName,
    required this.amount,
    required this.kcal,
    required this.proteinG,
    required this.fatG,
    required this.carbG,
    required this.confidence,
    required this.items,
  });

  final String dishName;
  final String amount;
  final double kcal;
  final double proteinG;
  final double fatG;
  final double carbG;
  final double confidence;
  final List<PhotoMealItemEstimate> items;
}

class PhotoMealAnalysis {
  const PhotoMealAnalysis({required this.usageId, required this.estimate});

  final String? usageId;
  final PhotoMealEstimate estimate;
}

double photoMealDerivedKcal(double proteinG, double fatG, double carbG) {
  return proteinG * 4 + fatG * 9 + carbG * 4;
}

bool photoMealPfcMatches(
  double kcal,
  double proteinG,
  double fatG,
  double carbG,
) {
  final derived = photoMealDerivedKcal(proteinG, fatG, carbG);
  final diff = (kcal - derived).abs();
  final scale = kcal > derived ? kcal : derived;
  final tolerance = photoMealPfcAbsoluteKcal > photoMealPfcRelative * scale
      ? photoMealPfcAbsoluteKcal
      : photoMealPfcRelative * scale;
  return diff <= tolerance;
}

bool _finiteInRange(Object? value, double max) {
  return value is num && value.isFinite && value >= 0 && value <= max;
}

bool photoMealNutritionOk(Map<dynamic, dynamic> row) {
  if (!_finiteInRange(row['kcal'], photoMealMaxKcal) ||
      !_finiteInRange(row['protein_g'], photoMealMaxMacroG) ||
      !_finiteInRange(row['fat_g'], photoMealMaxMacroG) ||
      !_finiteInRange(row['carb_g'], photoMealMaxMacroG)) {
    return false;
  }
  return photoMealPfcMatches(
    (row['kcal'] as num).toDouble(),
    (row['protein_g'] as num).toDouble(),
    (row['fat_g'] as num).toDouble(),
    (row['carb_g'] as num).toDouble(),
  );
}

String? _text(Object? value, int max, {required bool allowEmpty}) {
  if (value is! String) {
    return null;
  }
  final trimmed = value.trim();
  if (trimmed.length > max) {
    return null;
  }
  if (!allowEmpty && trimmed.isEmpty) {
    return null;
  }
  return trimmed;
}

PhotoMealItemEstimate? _item(Object? raw) {
  if (raw is! Map) {
    return null;
  }
  final name = _text(raw['name'], 80, allowEmpty: false);
  final amount = _text(raw['amount'], 40, allowEmpty: true);
  if (name == null || amount == null || !photoMealNutritionOk(raw)) {
    return null;
  }
  return PhotoMealItemEstimate(
    name: name,
    amount: amount,
    kcal: (raw['kcal'] as num).toDouble(),
    proteinG: (raw['protein_g'] as num).toDouble(),
    fatG: (raw['fat_g'] as num).toDouble(),
    carbG: (raw['carb_g'] as num).toDouble(),
  );
}

/// サーバの JSON を、記録してよい形だけに通す。合わなければ null。
PhotoMealEstimate? parsePhotoMealEstimate(Object? raw) {
  if (raw is! Map) {
    return null;
  }
  final dishName = _text(raw['dish_name'], 80, allowEmpty: false);
  final amount = _text(raw['amount'], 40, allowEmpty: true);
  if (dishName == null || amount == null || !photoMealNutritionOk(raw)) {
    return null;
  }
  if (!_finiteInRange(raw['confidence'], 1)) {
    return null;
  }
  final itemsRaw = raw['items'];
  if (itemsRaw is! List || itemsRaw.length > 12) {
    return null;
  }
  final items = <PhotoMealItemEstimate>[];
  for (final item in itemsRaw) {
    final parsed = _item(item);
    if (parsed == null) {
      return null;
    }
    items.add(parsed);
  }
  return PhotoMealEstimate(
    dishName: dishName,
    amount: amount,
    kcal: (raw['kcal'] as num).toDouble(),
    proteinG: (raw['protein_g'] as num).toDouble(),
    fatG: (raw['fat_g'] as num).toDouble(),
    carbG: (raw['carb_g'] as num).toDouble(),
    confidence: (raw['confidence'] as num).toDouble(),
    items: items,
  );
}

/// 表示の丸めで「直した」と数えない。
bool photoMealNumbersDiffer(double left, double right) {
  return (left - right).abs() >= 0.51;
}

bool photoMealWasEdited({
  required PhotoMealEstimate original,
  required String name,
  required String amount,
  required double kcal,
  required double proteinG,
  required double fatG,
  required double carbG,
}) {
  if (name.trim() != original.dishName.trim()) {
    return true;
  }
  if (amount.trim() != original.amount.trim()) {
    return true;
  }
  return photoMealNumbersDiffer(kcal, original.kcal) ||
      photoMealNumbersDiffer(proteinG, original.proteinG) ||
      photoMealNumbersDiffer(fatG, original.fatG) ||
      photoMealNumbersDiffer(carbG, original.carbG);
}

class ParsedPhotoAmount {
  const ParsedPhotoAmount({required this.amount, required this.unit});

  final double amount;
  final FoodUnitType unit;
}

/// 量の文から、倍率にならない単位を取る。読めなければ 1 食分。
ParsedPhotoAmount parsePhotoAmount(String raw) {
  final text = raw.trim().toLowerCase();
  final match = RegExp(
    r'^(\d+(?:\.\d+)?)\s*(g|ｇ|グラム|ml|ｍｌ|ミリリットル|個)$',
  ).firstMatch(text);
  if (match == null) {
    return const ParsedPhotoAmount(amount: 1, unit: FoodUnitType.serving);
  }
  final amount = double.tryParse(match.group(1)!);
  if (amount == null || amount <= 0) {
    return const ParsedPhotoAmount(amount: 1, unit: FoodUnitType.serving);
  }
  final unit = switch (match.group(2)) {
    'ml' || 'ｍｌ' || 'ミリリットル' => FoodUnitType.ml,
    '個' => FoodUnitType.piece,
    _ => FoodUnitType.g,
  };
  return ParsedPhotoAmount(amount: amount, unit: unit);
}

/// 確認した合計を 1 件にする。基準量と摂取量を同じにして、合計が倍率で変わらない。
FoodEntry foodEntryFromPhotoMeal({
  required String id,
  required String name,
  required String amountText,
  required double kcal,
  required double proteinG,
  required double fatG,
  required double carbG,
  required DateTime loggedAt,
}) {
  final parsed = parsePhotoAmount(amountText);
  return FoodEntry(
    id: id,
    name: name.trim(),
    kcalPerBase: kcal,
    proteinPerBase: proteinG,
    fatPerBase: fatG,
    carbPerBase: carbG,
    baseAmount: parsed.amount,
    unitType: parsed.unit,
    consumedAmount: parsed.amount,
    sourceType: FoodEntrySource.manual,
    loggedAt: loggedAt,
  );
}

/// 手入力と同じ [AppController.addFood]。未送信の印は 1 件だけ付く。
Future<FoodEntry> saveConfirmedPhotoMeal({
  required AppController controller,
  required DateTime loggedAt,
  required String name,
  required String amountText,
  required double kcal,
  required double proteinG,
  required double fatG,
  required double carbG,
}) async {
  final entry = foodEntryFromPhotoMeal(
    id: controller.generateId(),
    name: name,
    amountText: amountText,
    kcal: kcal,
    proteinG: proteinG,
    fatG: fatG,
    carbG: carbG,
    loggedAt: loggedAt,
  );
  await controller.addFood(entry);
  return entry;
}

/// 長辺を約 1024px の JPEG にする。元のバイトは返さない。
Uint8List compressMealPhoto(
  Uint8List bytes, {
  int longEdge = photoMealLongEdge,
  int quality = 80,
}) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) {
    throw const FormatException('写真を読み取れませんでした');
  }
  final longest = decoded.width > decoded.height ? decoded.width : decoded.height;
  final resized = longest <= longEdge
      ? decoded
      : img.copyResize(
          decoded,
          width: decoded.width >= decoded.height ? longEdge : null,
          height: decoded.height > decoded.width ? longEdge : null,
          interpolation: img.Interpolation.linear,
        );
  var jpeg = Uint8List.fromList(img.encodeJpg(resized, quality: quality));
  if (jpeg.length > 1200000 && quality > 60) {
    jpeg = Uint8List.fromList(img.encodeJpg(resized, quality: 60));
  }
  return jpeg;
}

String formatPhotoNumber(double value) {
  if (!value.isFinite) {
    return '';
  }
  if ((value - value.roundToDouble()).abs() < 0.05) {
    return value.round().toString();
  }
  return value.toStringAsFixed(1);
}
