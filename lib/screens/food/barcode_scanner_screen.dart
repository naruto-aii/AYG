import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../utils/nutrition_format.dart';

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

  void _handlePermissionDenied() {
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('バーコードをスキャン')),
      body: MobileScanner(
        controller: _controller,
        onDetect: _handleDetect,
        errorBuilder: (context, error) {
          final isPermissionDenied =
              error.errorCode == MobileScannerErrorCode.permissionDenied;

          if (isPermissionDenied) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('カメラを利用できません。手入力またはテキスト検索をご利用ください。'),
                  ),
                );
                _handlePermissionDenied();
              }
            });
          }

          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                isPermissionDenied ? 'カメラ権限が必要です' : 'カメラを起動できませんでした',
                textAlign: TextAlign.center,
              ),
            ),
          );
        },
      ),
    );
  }
}
