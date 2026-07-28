import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

import '../../theme/app_theme.dart';
import '../common/app_error_state.dart';

/// 起動時例外の最小フォールバック画面。
class StartupErrorApp extends StatelessWidget {
  const StartupErrorApp({super.key, required this.error, this.stackTrace});

  final Object error;
  final StackTrace? stackTrace;

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
                message: kDebugMode
                    ? '初期化に失敗しました\n\n$error'
                    : '初期化に失敗しました。ページを再読み込みしてください。',
                onRetry: () => web.window.location.reload(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
