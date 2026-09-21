import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../platform/web/web_browser_utils.dart';
import '../../constants/app_strings.dart';
import '../../platform/web/in_app_browser_detector.dart';
import '../../repositories/auth_exceptions.dart';
import '../../repositories/authentication_repository.dart';
import '../../state/app_controller.dart';
import '../../theme/app_colors.dart';
import '../../widgets/brand/app_logo.dart';
import '../../widgets/brand/brand_assets.dart';
import '../../widgets/common/primary_button.dart';
import '../../widgets/common/secondary_button.dart';
import '../../widgets/layout/app_form_constraint.dart';
import '../../widgets/layout/app_responsive.dart';
import '../legal/legal_document.dart';
import '../legal/legal_document_screen.dart';

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
    } on GoogleSignInFailedException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
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
    setState(() => _isLoading = true);
    try {
      await widget.authenticationRepository.loginWithApple();
      if (kIsWeb) {
        return;
      }
      await widget.controller.handleAuthenticatedSession();
    } on AppleSignInCancelledException {
      return;
    } on AppleSignInUnavailableException {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.loginAppleUnavailableOnWeb)),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Appleログインに失敗しました: $error')));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildLoginContent(BuildContext context) {
    return Column(
      children: [
        if (InAppBrowserDetector.shouldRecommendExternalBrowser)
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
        if (!widget.authStorageAvailable)
          const MaterialBanner(
            content: Text(
              'ブラウザのストレージが利用できないため、ログイン状態を保持できません。プライベートブラウズを解除するか、通常モードで開いてください。',
            ),
            actions: [SizedBox.shrink()],
          ),
        Expanded(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 335),
              child: Column(
                children: [
                  const SizedBox(height: 48),
                  const AppLogo(markSize: 120, vertical: true),
                  const SizedBox(height: 24),
                  Text(
                    AppStrings.loginTagline,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: AppColors.textBrand,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    AppStrings.loginBody,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const Spacer(),
                  PrimaryButton(
                    label: 'Googleでログイン',
                    leading: const _GoogleMark(),
                    trailingChevron: true,
                    loading: _isLoading,
                    onPressed: _isLoading ? null : _signInWithGoogle,
                  ),
                  const SizedBox(height: 13),
                  SecondaryButton(
                    label: 'Appleでログイン',
                    icon: Icons.apple,
                    trailingChevron: true,
                    onPressed: _isLoading ? null : _signInWithApple,
                  ),
                  const SizedBox(height: 28),
                ],
              ),
            ),
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton(
              onPressed: () => showLegalDocument(context, LegalDocument.terms),
              child: const Text('利用規約'),
            ),
            Text(
              '|',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
            ),
            TextButton(
              onPressed: () =>
                  showLegalDocument(context, LegalDocument.privacy),
              child: const Text('プライバシーポリシー'),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final content = _buildLoginContent(context);

    return Scaffold(
      backgroundColor: AppColors.backgroundCream,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          color: AppColors.backgroundCream,
          image: DecorationImage(
            image: AssetImage(BrandAssets.loginBackground),
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
          ),
        ),
        child: SafeArea(
          child: isDesktopLayout(context)
              ? Center(child: AppFormConstraint(child: content))
              : content,
        ),
      ),
    );
  }
}

class _GoogleMark extends StatelessWidget {
  const _GoogleMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
      child: const Text(
        'G',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: Color(0xFF4285F4),
          height: 1,
        ),
      ),
    );
  }
}
