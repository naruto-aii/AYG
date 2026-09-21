import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../constants/app_strings.dart';
import '../../platform/web/in_app_browser_detector.dart';
import '../../platform/web/web_browser_utils.dart';
import '../../repositories/auth_exceptions.dart';
import '../../repositories/authentication_repository.dart';
import '../../state/app_controller.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../widgets/auth/auth_button.dart';
import '../../widgets/brand/app_logo.dart';
import '../../widgets/brand/brand_assets.dart';
import '../../widgets/brand/login_background.dart';
import '../../widgets/layout/app_form_constraint.dart';
import '../../widgets/layout/app_responsive.dart';
import '../legal/legal_document.dart';
import '../legal/legal_document_screen.dart';

/// ログイン画面。レイアウトは Figma「01 ログイン」に準拠。
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
  // --- Figma 実測値（390×844 基準）-------------------------------------
  /// 左右マージン。
  static const double _sideMargin = 28;

  /// ステータスバー下からロゴ上端まで。
  static const double _gapTopToLogo = 79;

  /// ロゴのマーク一辺。
  static const double _logoMarkSize = 130;

  /// 「カロナビ」の文字サイズ。
  static const double _logoTitleSize = 40;

  /// マークと「カロナビ」の間隔。
  static const double _logoGap = 8;

  /// ロゴ下端からタグラインまで。
  static const double _gapLogoToTagline = 24;

  /// タグラインから説明文まで。
  static const double _gapTaglineToDesc = 18;

  /// 説明文からボタンまで。
  static const double _gapDescToButtons = 35;

  /// ボタン同士の間隔。
  static const double _gapBetweenButtons = 13;

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

  List<Widget> _buildNotices() {
    final notices = <Widget>[];
    if (InAppBrowserDetector.shouldRecommendExternalBrowser) {
      notices.add(
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
      );
    }
    if (!widget.authStorageAvailable) {
      notices.add(
        const MaterialBanner(
          content: Text(
            'ブラウザのストレージが利用できないため、ログイン状態を保持できません。プライベートブラウズを解除するか、通常モードで開いてください。',
          ),
          actions: [SizedBox.shrink()],
        ),
      );
    }
    return notices;
  }

  Widget _buildFooter(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _LegalLink(
          label: '利用規約',
          onTap: () => showLegalDocument(context, LegalDocument.terms),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text('|', style: AppTypography.bodyS.copyWith(
            color: AppColors.textMuted,
          )),
        ),
        _LegalLink(
          label: 'プライバシーポリシー',
          onTap: () => showLegalDocument(context, LegalDocument.privacy),
        ),
      ],
    );
  }

  Widget _buildContent(BuildContext context) {
    final notices = _buildNotices();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (notices.isNotEmpty) ...[
          ...notices,
          const SizedBox(height: 16),
        ],
        const SizedBox(height: _gapTopToLogo),
        const Center(
          child: AppLogo(
            vertical: true,
            markSize: _logoMarkSize,
            titleSize: _logoTitleSize,
            gap: _logoGap,
          ),
        ),
        const SizedBox(height: _gapLogoToTagline),
        Text(
          AppStrings.loginTaglineMultiline,
          textAlign: TextAlign.center,
          style: AppTypography.tagline,
        ),
        const SizedBox(height: _gapTaglineToDesc),
        Text(
          AppStrings.loginDescription,
          textAlign: TextAlign.center,
          style: AppTypography.bodyS.copyWith(color: AppColors.textMuted),
        ),
        const SizedBox(height: _gapDescToButtons),
        AuthButton(
          label: AppStrings.loginWithGoogle,
          background: AuthButtonStyles.googleBackground,
          foreground: AuthButtonStyles.googleForeground,
          markAssetPath: BrandAssets.googleMarkSvg,
          markBackground: AppColors.cream0,
          loading: _isLoading,
          onPressed: _isLoading ? null : _signInWithGoogle,
        ),
        const SizedBox(height: _gapBetweenButtons),
        AuthButton(
          label: AppStrings.loginWithApple,
          background: AuthButtonStyles.appleBackground,
          foreground: AuthButtonStyles.appleForeground,
          markAssetPath: BrandAssets.appleMarkSvg,
          glyphSize: 24,
          onPressed: _isLoading ? null : _signInWithApple,
        ),
        const SizedBox(height: 32),
        _buildFooter(context),
        const SizedBox(height: 8),
        // Figma のログイン画面には無いが、法務上の同意表示なので残す。
        Text(
          AppStrings.loginLegalAgreement,
          textAlign: TextAlign.center,
          style: AppTypography.caption,
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: _sideMargin),
      child: _buildContent(context),
    );

    return Scaffold(
      backgroundColor: AppColors.bgPage,
      body: Stack(
        children: [
          const LoginBackground(),
          SafeArea(
            child: SingleChildScrollView(
              child: Center(
                child: isDesktopLayout(context)
                    ? AppFormConstraint(child: content)
                    : content,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LegalLink extends StatelessWidget {
  const _LegalLink({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Text(
          label,
          style: AppTypography.bodyS.copyWith(color: AppColors.textBrand),
        ),
      ),
    );
  }
}
