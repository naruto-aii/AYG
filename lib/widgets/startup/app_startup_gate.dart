import 'package:flutter/material.dart';

import '../../state/app_controller.dart';
import '../../theme/app_spacing.dart';
import '../common/primary_button.dart';

/// 認証・同期・オンボーディング判定中のローディング。
class AppStartupLoadingScreen extends StatelessWidget {
  const AppStartupLoadingScreen({super.key, this.message = '読み込み中…'});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: AppSpacing.md),
            Text(message, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}

/// 初回同期失敗時の再試行画面（オンボーディングと区別）。
class AppSyncRetryScreen extends StatelessWidget {
  const AppSyncRetryScreen({
    super.key,
    required this.controller,
    required this.onLogout,
  });

  final AppController controller;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Text(
                'データの取得に失敗しました',
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'ネットワーク接続を確認して、もう一度お試しください。',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const Spacer(),
              PrimaryButton(
                label: '再試行',
                loading: controller.isSyncInProgress,
                onPressed: controller.isSyncInProgress
                    ? null
                    : () => controller.retryAuthenticatedSync(),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextButton(onPressed: onLogout, child: const Text('ログアウト')),
            ],
          ),
        ),
      ),
    );
  }
}
