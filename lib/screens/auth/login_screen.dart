import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/supabase_config.dart';
import '../../repositories/auth_exceptions.dart';
import '../../repositories/authentication_repository.dart';
import '../../state/app_controller.dart';
import '../../theme/app_spacing.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    required this.controller,
    required this.authenticationRepository,
  });

  final AppController controller;
  final AuthenticationRepository authenticationRepository;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
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

  Future<void> _signInWithApple() async {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Appleログインは準備中です（TODO）')));
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
                'エネルギー管理をはじめましょう',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
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
              const SizedBox(height: AppSpacing.xs),
              OutlinedButton.icon(
                onPressed: _isLoading ? null : _signInWithApple,
                icon: const Icon(Icons.apple),
                label: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  child: Text('Appleでログイン'),
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
