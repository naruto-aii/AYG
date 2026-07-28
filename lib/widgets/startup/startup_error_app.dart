import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

import '../../bootstrap/web_init_error.dart';
import '../../theme/app_theme.dart';
import '../common/app_error_state.dart';

/// 起動時例外の最小フォールバック画面。
class StartupErrorApp extends StatelessWidget {
  const StartupErrorApp({super.key, required this.error, this.stackTrace});

  final Object error;
  final StackTrace? stackTrace;

  String _message() {
    final code = error is WebInitException
        ? (error as WebInitException).code.code
        : WebInitErrorCode.initUnknown.code;

    if (kDebugMode) {
      return '初期化に失敗しました ($code)\n\n$error';
    }
    return '初期化に失敗しました ($code)。ページを再読み込みしてください。';
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'カロナビ',
      theme: AppTheme.light,
      home: Scaffold(
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: AppErrorState(
                message: _message(),
                onRetry: () => web.window.location.reload(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
