import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'brand_assets.dart';

/// ログイン画面の背景装飾（アーク・葉・丘）。
///
/// 1枚の絵として敷くと、縦横比が 390:844 と違う画面で必ずどこかが切れるか、
/// 端に帯が出てしまう。そこで3つの層に分け、それぞれを画面の端に貼り付ける。
///
/// - 丘   : 画面の下端。横は画面幅いっぱいに伸ばす（なだらかな波なので崩れない）
/// - アーク: 画面の左上。縦横比そのまま
/// - 葉   : 画面の右端。縦横比そのまま（伸ばすと葉の形が崩れるため）
///
/// これでどの画面サイズでも、帯が出ず、要素が欠けることもない。
class LoginBackground extends StatelessWidget {
  const LoginBackground({super.key});

  /// Figma の設計キャンバス。
  static const double _designWidth = 390;
  static const double _designHeight = 844;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: LayoutBuilder(
          builder: (context, constraints) {
            // 中身と同じ倍率。装飾だけ極端に大きくならないようにする。
            final scale = math.min(
              constraints.maxWidth / _designWidth,
              constraints.maxHeight / _designHeight,
            );
            final boxHeight = _designHeight * scale;
            final boxWidth = _designWidth * scale;

            Widget layer(String asset, {required double width}) {
              return SizedBox(
                width: width,
                height: boxHeight,
                child: SvgPicture.asset(
                  asset,
                  fit: BoxFit.fill,
                  placeholderBuilder: (_) => const SizedBox.shrink(),
                ),
              );
            }

            return Stack(
              fit: StackFit.expand,
              clipBehavior: Clip.hardEdge,
              children: [
                // 左上のアーク
                Align(
                  alignment: Alignment.topLeft,
                  child: layer(BrandAssets.backgroundArcSvg, width: boxWidth),
                ),
                // 右の葉
                Align(
                  alignment: Alignment.centerRight,
                  child: layer(BrandAssets.backgroundPlantSvg, width: boxWidth),
                ),
                // 下の丘（横は画面幅いっぱい）
                Align(
                  alignment: Alignment.bottomCenter,
                  child: layer(
                    BrandAssets.backgroundHillsSvg,
                    width: constraints.maxWidth,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
