import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../utils/nutrition_format.dart';

/// カメラで EAN / JAN / UPC バーコードを読み取る画面。
class BarcodeScannerScreen extends StatefulWidget {
  const BarcodeScannerScreen({super.key});

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  final MobileScannerController _controller = MobileScannerController(
    autoStart: true,
    facing: CameraFacing.back,
    formats: const [
      BarcodeFormat.ean13,
      BarcodeFormat.ean8,
      BarcodeFormat.upcA,
      BarcodeFormat.upcE,
    ],
  );

  bool _hasScanned = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
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

  Future<void> _toggleTorch() async {
    await _controller.toggleTorch();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('バーコードをスキャン'),
        actions: [
          IconButton(
            tooltip: 'ライト',
            onPressed: _toggleTorch,
            icon: const Icon(Icons.flash_on),
          ),
          IconButton(
            tooltip: '閉じる',
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _handleDetect,
            errorBuilder: (context, error) {
              final isPermissionDenied =
                  error.errorCode == MobileScannerErrorCode.permissionDenied;

              return ColoredBox(
                color: Colors.black,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          isPermissionDenied
                              ? 'カメラの使用が許可されていません。iPhoneの設定 → カロナビ → カメラをオンにしてください。'
                              : 'カメラを起動できませんでした。もう一度開くか、番号を手入力してください。',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white),
                        ),
                        const SizedBox(height: 16),
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('戻る'),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          const IgnorePointer(child: _BarcodeViewfinder()),
          const Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: EdgeInsets.fromLTRB(24, 0, 24, 48),
              child: Text(
                'バーコードを枠内に合わせてください',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BarcodeViewfinder extends StatelessWidget {
  const _BarcodeViewfinder();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _ViewfinderPainter(), child: const SizedBox.expand());
  }
}

class _ViewfinderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cutout = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(size.width / 2, size.height / 2),
        width: size.width * 0.78,
        height: 160,
      ),
      const Radius.circular(16),
    );
    final overlay = Path()
      ..addRect(Offset.zero & size)
      ..addRRect(cutout)
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(overlay, Paint()..color = const Color(0x88000000));
    canvas.drawRRect(
      cutout,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
