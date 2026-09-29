import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../utils/nutrition_format.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_icons.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_typography.dart';
import '../../widgets/design/design_button.dart';
import '../../widgets/design/design_field.dart';
import '../../widgets/design/design_page.dart';

/// カメラで EAN-13 / JAN バーコードを読み取る画面。
class BarcodeScannerScreen extends StatefulWidget {
  const BarcodeScannerScreen({super.key});

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  final MobileScannerController _controller = MobileScannerController(
    formats: [BarcodeFormat.ean13],
  );

  final _manualController = TextEditingController();
  bool _hasScanned = false;

  @override
  void dispose() {
    _controller.dispose();
    _manualController.dispose();
    super.dispose();
  }

  /// 番号を手で入れた場合も、読み取りと同じ形で呼び出し元へ返す。
  void _submitManual() {
    final normalized = normalizeEan13Barcode(_manualController.text.trim());
    if (normalized == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('13桁のバーコード番号を入力してください')));
      return;
    }
    _hasScanned = true;
    Navigator.of(context).pop(normalized);
  }

  Future<void> _handleDetect(BarcodeCapture capture) async {
    if (_hasScanned) {
      return;
    }

    final barcode = capture.barcodes.firstOrNull;
    final normalized = normalizeEan13Barcode(barcode?.rawValue);
    if (normalized == null) {
      return;
    }

    _hasScanned = true;
    await _controller.stop();

    if (!mounted) {
      return;
    }

    Navigator.of(context).pop(normalized);
  }

  @override
  Widget build(BuildContext context) {
    return DesignPage(
      bottomBar: DesignButton(
        label: '手入力に切り替える',
        style: DesignButtonStyle.outline,
        showTrailingIcon: false,
        onPressed: () => Navigator.of(context).pop(),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const DesignTitleBlock(
            title: 'バーコードを読み取る',
            subtitle: '市販の食品のバーコードに、枠を合わせてください。',
          ),
          // Figma: 角丸の暗いカメラ面＋白い枠
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.xl),
            child: SizedBox(
              height: 300,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  const ColoredBox(color: AppColors.green900),
                  MobileScanner(
                    controller: _controller,
                    onDetect: _handleDetect,
                    errorBuilder: (context, error) {
                      final isPermissionDenied =
                          error.errorCode ==
                          MobileScannerErrorCode.permissionDenied;

                      if (isPermissionDenied) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'カメラを利用できません。番号の入力か、手入力をご利用ください。',
                                ),
                              ),
                            );
                          }
                        });
                      }

                      return ColoredBox(
                        color: AppColors.green900,
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              isPermissionDenied
                                  ? 'カメラ権限が必要です'
                                  : 'カメラを起動できませんでした',
                              textAlign: TextAlign.center,
                              style: AppTypography.bodyS.copyWith(
                                color: AppColors.cream0,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  IgnorePointer(
                    child: Center(
                      child: Container(
                        width: 238,
                        height: 120,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          border: Border.all(color: AppColors.cream0, width: 3),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 40,
                    child: IgnorePointer(
                      child: Text(
                        'バーコードが枠に入ると自動で読み取ります',
                        textAlign: TextAlign.center,
                        style: AppTypography.caption.copyWith(
                          color: AppColors.cream0,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'または バーコードの番号を入力',
            style: AppTypography.caption.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: DesignInputBox(
                  radius: AppRadius.sm,
                  verticalPadding: 11,
                  child: DesignTextInput(
                    controller: _manualController,
                    hintText: '例）4901001234567',
                    keyboardType: TextInputType.number,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Material(
                color: AppColors.bgPrimary,
                borderRadius: BorderRadius.circular(AppRadius.sm),
                child: InkWell(
                  onTap: _submitManual,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  child: const SizedBox(
                    width: 48,
                    height: 48,
                    child: Center(
                      child: AppIcon(
                        AppIcons.search,
                        size: 20,
                        color: AppColors.iconOnPrimary,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
