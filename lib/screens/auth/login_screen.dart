import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/supabase_config.dart';
import '../../repositories/auth_exceptions.dart';
import '../../repositories/authentication_repository.dart';
import '../../state/app_controller.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/brand/app_logo.dart';
import '../../widgets/common/primary_button.dart';
import '../../widgets/common/secondary_button.dart';

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
      backgroundColor: AppColors.backgroundCream,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              const Center(child: AppLogo(markSize: 72, vertical: true)),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'エネルギー管理をはじめましょう',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.secondaryText,
                ),
              ),
              const Spacer(),
              PrimaryButton(
                label: 'Googleでログイン',
                icon: Icons.login,
                loading: _isLoading,
                onPressed: _isLoading ? null : _signInWithGoogle,
              ),
              SecondaryButton(
                label: 'Appleでログイン',
                icon: Icons.apple,
                onPressed: _isLoading ? null : _signInWithApple,
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
