import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'web_barcode_support.dart';

/// Web 向け JAN / EAN-13 バーコードスキャン画面。
///
/// ボタン押下後にのみカメラを起動する。
class WebBarcodeScannerScreen extends StatefulWidget {
  const WebBarcodeScannerScreen({super.key});

  @override
  State<WebBarcodeScannerScreen> createState() =>
      _WebBarcodeScannerScreenState();
}

class _WebBarcodeScannerScreenState extends State<WebBarcodeScannerScreen> {
  final MobileScannerController _controller = MobileScannerController(
    formats: [BarcodeFormat.ean13],
  );
  final DuplicateBarcodeDetector _duplicateDetector =
      DuplicateBarcodeDetector();

  bool _hasScanned = false;
  bool _isClosing = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _close([String? barcode]) async {
    if (_isClosing) {
      return;
    }
    _isClosing = true;
    await _controller.stop();
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop(barcode);
  }

  Future<void> _handleDetect(BarcodeCapture capture) async {
    if (_hasScanned) {
      return;
    }

    final barcode = capture.barcodes.firstOrNull;
    final normalized = normalizeJanEan13Barcode(barcode?.rawValue);
    if (normalized == null) {
      return;
    }
    if (!_duplicateDetector.shouldAccept(normalized)) {
      return;
    }

    _hasScanned = true;
    await _close(normalized);
  }

  void _handlePermissionDenied() {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('カメラを利用できません。バーコード番号を入力してください。')),
    );
    _close();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('バーコードをスキャン'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => _close(),
        ),
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

              if (isPermissionDenied) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _handlePermissionDenied();
                });
              }

              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    isPermissionDenied
                        ? 'カメラ権限が必要です。ブラウザ設定で許可するか、バーコード番号を入力してください。'
                        : 'カメラを起動できませんでした。バーコード番号を入力してください。',
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            },
          ),
          IgnorePointer(
            child: Center(
              child: Container(
                width: 280,
                height: 120,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white, width: 3),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          const Positioned(
            left: 16,
            right: 16,
            bottom: 32,
            child: Text(
              'バーコードを枠内に合わせてください',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
                shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
