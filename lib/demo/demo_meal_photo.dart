import 'dart:typed_data';

import 'package:image/image.dart' as img;

import '../screens/food/photo_meal_screen.dart';

/// カメラの代わりに、丼の色の JPEG を返す。
class DemoMealPhotoSource implements MealPhotoSource {
  const DemoMealPhotoSource();

  @override
  Future<Uint8List?> takePhoto() async => demoMealJpeg();

  @override
  Future<Uint8List?> pickFromLibrary() async => demoMealJpeg();
}

Uint8List? _cached;

Uint8List demoMealJpeg() {
  final cached = _cached;
  if (cached != null) {
    return cached;
  }
  final image = img.Image(width: 480, height: 360);
  img.fill(image, color: img.ColorRgb8(214, 148, 72));
  img.fillRect(
    image,
    x1: 90,
    y1: 70,
    x2: 390,
    y2: 290,
    color: img.ColorRgb8(168, 96, 42),
  );
  final bytes = Uint8List.fromList(img.encodeJpg(image, quality: 70));
  _cached = bytes;
  return bytes;
}
