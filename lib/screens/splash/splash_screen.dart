import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../constants/app_strings.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../widgets/brand/brand_assets.dart';

/// 起動時のスプラッシュ演出。
///
/// Figma の SPLASH（9コマ / Smart Animate）をそのまま時間軸に落としたもの。
/// 設計キャンバスは 390×844。実画面では縦横比を保ったまま拡大縮小する。
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, required this.onCompleted});

  /// 演出が終わったときに呼ばれる。
  final VoidCallback onCompleted;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  // --- 設計キャンバス ---------------------------------------------------
  static const double _designWidth = 390;
  static const double _designHeight = 844;

  /// ブランドマークの実描画サイズと中心。
  static const double _markWidth = 150;
  static const double _markHeight = 152;
  static const Offset _markCenter = Offset(195, 422);

  /// 「カロナビ」1文字ぶんの送り幅と、文字ブロックの左上。
  static const double _charAdvance = 40;
  static const double _charFontSize = 40;
  static const Offset _wordTopLeft = Offset(115, 524);
  static const double _wordHeight = 58;

  // --- タイムライン（ミリ秒）-------------------------------------------
  // Figma のインタラクション設定（待機 + アニメ時間）をそのまま積算した値。
  static const List<List<double>> _charSpans = [
    [500, 680], // カ  待機500 + EaseOut180
    [730, 880], // ロ  待機50  + EaseOut150
    [930, 1080], // ナ
    [1130, 1280], // ビ
  ];
  static const List<double> _fall = [1500, 1920]; // 待機220 + EaseIn420
  static const List<double> _squash = [1930, 2020]; // 待機10 + Linear90
  static const List<double> _bounce = [2021, 2221]; // Linear200
  static const List<double> _expand = [2222, 2622]; // EaseOut400
  static const int _totalMs = 2922; // 拡大後 300ms 保持

  // --- ドットのキーフレーム（中心座標と直径）---------------------------
  static const _DotState _dotStart = _DotState(260.7, -40, 21.5, 21.5);
  static const _DotState _dotFallen = _DotState(260.7, 387.3, 18.3, 28);
  static const _DotState _dotSquashed = _DotState(260.7, 394.6, 31.2, 13.3);
  static const _DotState _dotBounced = _DotState(268.7, 338.6, 21.5, 21.5);
  static const _DotState _dotExpanded = _DotState(268.7, 338.6, 1200, 1200);

  late final AnimationController _controller;
  bool _notified = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: _totalMs),
    )..addStatusListener((status) {
      if (status == AnimationStatus.completed && !_notified) {
        _notified = true;
        widget.onCompleted();
      }
    });
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// 指定区間の進捗（0.0〜1.0）を返す。
  double _progress(double nowMs, List<double> span, Curve curve) {
    final start = span[0];
    final end = span[1];
    if (nowMs <= start) return 0;
    if (nowMs >= end) return 1;
    return curve.transform((nowMs - start) / (end - start));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPage,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final scale = math.min(
            constraints.maxWidth / _designWidth,
            constraints.maxHeight / _designHeight,
          );
          final offsetX = (constraints.maxWidth - _designWidth * scale) / 2;
          final offsetY = (constraints.maxHeight - _designHeight * scale) / 2;

          return AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final nowMs = _controller.value * _totalMs;

              var dot = _DotState.lerp(
                _dotStart,
                _dotFallen,
                _progress(nowMs, _fall, Curves.easeIn),
              );
              dot = _DotState.lerp(
                dot,
                _dotSquashed,
                _progress(nowMs, _squash, Curves.linear),
              );
              dot = _DotState.lerp(
                dot,
                _dotBounced,
                _progress(nowMs, _bounce, Curves.linear),
              );
              dot = _DotState.lerp(
                dot,
                _dotExpanded,
                _progress(nowMs, _expand, Curves.easeOut),
              );

              Positioned place({
                required double left,
                required double top,
                required double width,
                required double height,
                required Widget child,
              }) {
                return Positioned(
                  left: offsetX + left * scale,
                  top: offsetY + top * scale,
                  width: width * scale,
                  height: height * scale,
                  child: child,
                );
              }

              return Stack(
                clipBehavior: Clip.hardEdge,
                children: [
                  // ブランドマーク（静止）
                  place(
                    left: _markCenter.dx - _markWidth / 2,
                    top: _markCenter.dy - _markHeight / 2,
                    width: _markWidth,
                    height: _markHeight,
                    child: SvgPicture.asset(
                      BrandAssets.brandMarkSvg,
                      fit: BoxFit.fill,
                    ),
                  ),
                  // 「カロナビ」1文字ずつフェードイン
                  place(
                    left: _wordTopLeft.dx,
                    top: _wordTopLeft.dy,
                    width: _charAdvance * AppStrings.appTitle.length,
                    height: _wordHeight,
                    child: Row(
                      children: [
                        for (var i = 0; i < AppStrings.appTitle.length; i++)
                          Opacity(
                            opacity: _progress(
                              nowMs,
                              _charSpans[i],
                              Curves.easeOut,
                            ),
                            child: SizedBox(
                              width: _charAdvance * scale,
                              child: Text(
                                AppStrings.appTitle[i],
                                textAlign: TextAlign.center,
                                style: AppTypography.headingXl.copyWith(
                                  fontSize: _charFontSize * scale,
                                  height: 1.3,
                                  letterSpacing: 0,
                                  color: AppColors.textBrand,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  // オレンジの点
                  place(
                    left: dot.centerX - dot.width / 2,
                    top: dot.centerY - dot.height / 2,
                    width: dot.width,
                    height: dot.height,
                    child: const DecoratedBox(
                      decoration: BoxDecoration(
                        color: AppColors.accentOrange,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

/// オレンジの点の状態（中心座標と直径）。すべて設計キャンバス基準。
@immutable
class _DotState {
  const _DotState(this.centerX, this.centerY, this.width, this.height);

  final double centerX;
  final double centerY;
  final double width;
  final double height;

  static _DotState lerp(_DotState a, _DotState b, double t) {
    if (t <= 0) return a;
    if (t >= 1) return b;
    double mix(double x, double y) => x + (y - x) * t;
    return _DotState(
      mix(a.centerX, b.centerX),
      mix(a.centerY, b.centerY),
      mix(a.width, b.width),
      mix(a.height, b.height),
    );
  }
}
