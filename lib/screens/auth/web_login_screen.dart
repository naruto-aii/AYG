import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/supabase_config.dart';
import '../../repositories/auth_exceptions.dart';
import '../../repositories/authentication_repository.dart';
import '../../state/app_controller.dart';
import '../../theme/app_spacing.dart';

class WebLoginScreen extends StatefulWidget {
  const WebLoginScreen({
    super.key,
    required this.controller,
    required this.authenticationRepository,
  });

  final AppController controller;
  final AuthenticationRepository authenticationRepository;

  @override
  State<WebLoginScreen> createState() => _WebLoginScreenState();
}

class _WebLoginScreenState extends State<WebLoginScreen> {
  bool _isLoading = false;

  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      await widget.authenticationRepository.loginWithGoogle();
      await widget.controller.handleAuthenticatedSession();
    } on GoogleSignInCancelledException {
      return;
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Googleログインに失敗しました: $error')));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('リンクを開けませんでした: $url')));
    }
  }

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
                'AYG',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Webプレビュー（友人テスト用）',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Health連携は無効です。Activity Level で目標を計算します。',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: _isLoading ? null : _signInWithGoogle,
                icon: _isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.login),
                label: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  child: Text('Googleでログイン'),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: AppSpacing.md,
                children: [
                  TextButton(
                    onPressed: () => _openUrl(SupabaseConfig.termsUrl),
                    child: const Text('利用規約'),
                  ),
                  TextButton(
                    onPressed: () => _openUrl(SupabaseConfig.privacyUrl),
                    child: const Text('プライバシーポリシー'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
