import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Figma の `Icon/*` コンポーネントを書き出した独自アイコン。
///
/// いずれも 24×24 の単色（#2D7448）で描かれているので、[AppIcon] が
/// 指定色に塗り替えて表示する。
abstract final class AppIcons {
  static const String _base = 'assets/icons';

  static const String alcohol = '$_base/alcohol.svg';
  static const String avocado = '$_base/avocado.svg';
  static const String barcode = '$_base/barcode.svg';
  static const String bookmark = '$_base/bookmark.svg';
  static const String calculator = '$_base/calculator.svg';
  static const String calendar = '$_base/calendar.svg';
  static const String calorie = '$_base/calorie.svg';
  static const String camera = '$_base/camera.svg';
  static const String document = '$_base/document.svg';
  static const String dumbbell = '$_base/dumbbell.svg';
  static const String exercise = '$_base/exercise.svg';
  static const String gender = '$_base/gender.svg';
  static const String goal = '$_base/goal.svg';
  static const String heart = '$_base/heart.svg';
  static const String height = '$_base/height.svg';
  static const String home = '$_base/home.svg';
  static const String human = '$_base/human.svg';
  static const String information = '$_base/information.svg';
  static const String logout = '$_base/logout.svg';
  static const String mail = '$_base/mail.svg';
  static const String meal = '$_base/meal.svg';
  static const String meat = '$_base/meat.svg';
  static const String pen = '$_base/pen.svg';
  static const String rice = '$_base/rice.svg';
  static const String scale = '$_base/scale.svg';
  static const String search = '$_base/search.svg';
  static const String settings = '$_base/settings.svg';
  static const String shield = '$_base/shield.svg';
  static const String template = '$_base/template.svg';
  static const String time = '$_base/time.svg';
  static const String trash = '$_base/trash.svg';
  static const String user = '$_base/user.svg';
}

/// [AppIcons] の SVG を任意の色・サイズで描く。
class AppIcon extends StatelessWidget {
  const AppIcon(this.asset, {super.key, this.size = 24, this.color});

  final String asset;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      asset,
      width: size,
      height: size,
      colorFilter: color == null
          ? null
          : ColorFilter.mode(color!, BlendMode.srcIn),
    );
  }
}
