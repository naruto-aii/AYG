import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../platform/web/web_browser_utils.dart';
import '../../config/supabase_config.dart';
import '../../constants/app_strings.dart';
import '../../platform/web/in_app_browser_detector.dart';
import '../../repositories/auth_exceptions.dart';
import '../../repositories/authentication_repository.dart';
import '../../state/app_controller.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/brand/app_logo.dart';
import '../../widgets/common/primary_button.dart';
import '../../widgets/common/secondary_button.dart';
import '../../widgets/layout/app_form_constraint.dart';
import '../../widgets/layout/app_responsive.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    required this.controller,
    required this.authenticationRepository,
    this.authStorageAvailable = true,
  });

  final AppController controller;
  final AuthenticationRepository authenticationRepository;
  final bool authStorageAvailable;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isLoading = false;

  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      await widget.authenticationRepository.loginWithGoogle();
      if (kIsWeb) {
        return;
      }
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

  Widget _buildLoginContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (InAppBrowserDetector.shouldRecommendExternalBrowser) ...[
          MaterialBanner(
            content: const Text(
              'アプリ内ブラウザではGoogleログインが制限される場合があります。SafariまたはChromeで開いてください。',
            ),
            actions: [
              TextButton(
                onPressed: openCurrentUrlInExternalBrowser,
                child: const Text('外部ブラウザで開く'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        if (!widget.authStorageAvailable) ...[
          MaterialBanner(
            content: const Text(
              'ブラウザのストレージが利用できないため、ログイン状態を保持できません。プライベートブラウズを解除するか、通常モードで開いてください。',
            ),
            actions: const [SizedBox.shrink()],
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        const Spacer(),
        const Center(child: AppLogo(markSize: 72, vertical: true)),
        const SizedBox(height: AppSpacing.sm),
        Text(
          AppStrings.loginTagline,
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(color: AppColors.secondaryText),
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: _buildLoginContent(context),
    );

    return Scaffold(
      backgroundColor: AppColors.backgroundCream,
      body: SafeArea(
        child: Center(
          child: isDesktopLayout(context)
              ? AppFormConstraint(child: content)
              : content,
        ),
      ),
    );
  }
}
