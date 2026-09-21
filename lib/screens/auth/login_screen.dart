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
import '../../widgets/brand/app_brand_mark.dart';
import '../../widgets/brand/brand_assets.dart';
import '../../widgets/brand/login_background.dart';
import '../../widgets/layout/design_canvas.dart';
import '../legal/legal_document.dart';
import '../legal/legal_document_screen.dart';

/// ログイン画面。
///
/// レイアウトは Figma「01 ログイン」の 390×844 をそのまま座標で置き、
/// [DesignCanvas] が画面サイズに合わせて丸ごと拡大縮小する。
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
  // --- Figma「01 ログイン」実測値（390×844 基準）-----------------------
  static const double _contentLeft = 28;
  static const double _contentWidth = 335;

  static const double _markWidth = 130;
  static const double _markTop = 126;
  static const double _wordmarkTop = 266;
  static const double _wordmarkSize = 40;

  static const double _taglineTop = 342;
  static const double _descTop = 420;

  static const double _buttonTop = 518;
  static const double _buttonGap = 13;

  static const double _consentTop = 762;
  static const double _footerTop = 799;
  static const double _footerHeight = 25;

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

  /// Web 固有の注意書き。通常は表示されない。
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

  Widget _buildLogo() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const AppBrandMark(size: _markWidth),
        SizedBox(
          height:
              _wordmarkTop - _markTop - _markWidth * AppBrandMark.heightRatio,
        ),
        Text(
          AppStrings.appTitle,
          textAlign: TextAlign.center,
          style: AppTypography.headingXl.copyWith(
            fontSize: _wordmarkSize,
            height: 1.3,
            letterSpacing: -_wordmarkSize * 0.025,
            color: AppColors.textBrand,
          ),
        ),
      ],
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _LegalLink(
          label: '利用規約',
          onTap: () => showLegalDocument(context, LegalDocument.terms),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text(
            '|',
            style: AppTypography.bodyS.copyWith(color: AppColors.textMuted),
          ),
        ),
        _LegalLink(
          label: 'プライバシーポリシー',
          onTap: () => showLegalDocument(context, LegalDocument.privacy),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final notices = _buildNotices();

    return Scaffold(
      backgroundColor: AppColors.bgPage,
      body: Stack(
        children: [
          // 背景は3層に分けて画面の端に貼り付ける（帯も見切れも出さない）
          const LoginBackground(),
          DesignCanvas(
            child: Stack(
              children: [
                // ロゴ（マーク＋カロナビ）
                Positioned(
                  top: _markTop,
                  left: 0,
                  right: 0,
                  child: Center(child: _buildLogo()),
                ),
                // タグライン
                Positioned(
                  top: _taglineTop,
                  left: _contentLeft,
                  width: _contentWidth,
                  child: Text(
                    AppStrings.loginTaglineMultiline,
                    textAlign: TextAlign.center,
                    style: AppTypography.tagline,
                  ),
                ),
                // 説明文
                Positioned(
                  top: _descTop,
                  left: _contentLeft,
                  width: _contentWidth,
                  child: Text(
                    AppStrings.loginDescription,
                    textAlign: TextAlign.center,
                    style: AppTypography.bodyS.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
                // 認証ボタン
                Positioned(
                  top: _buttonTop,
                  left: _contentLeft,
                  width: _contentWidth,
                  child: Column(
                    children: [
                      AuthButton(
                        label: AppStrings.loginWithGoogle,
                        background: AuthButtonStyles.googleBackground,
                        foreground: AuthButtonStyles.googleForeground,
                        markAssetPath: BrandAssets.googleMarkSvg,
                        markBackground: AppColors.cream0,
                        loading: _isLoading,
                        onPressed: _isLoading ? null : _signInWithGoogle,
                      ),
                      const SizedBox(height: _buttonGap),
                      AuthButton(
                        label: AppStrings.loginWithApple,
                        background: AuthButtonStyles.appleBackground,
                        foreground: AuthButtonStyles.appleForeground,
                        markAssetPath: BrandAssets.appleMarkSvg,
                        glyphSize: 24,
                        onPressed: _isLoading ? null : _signInWithApple,
                      ),
                    ],
                  ),
                ),
                // 同意文言（Figma には無いが法務表示として残す）
                Positioned(
                  top: _consentTop,
                  left: _contentLeft,
                  width: _contentWidth,
                  child: Text(
                    AppStrings.loginLegalAgreement,
                    textAlign: TextAlign.center,
                    style: AppTypography.caption,
                  ),
                ),
                // 規約リンク
                Positioned(
                  top: _footerTop,
                  left: 0,
                  right: 0,
                  height: _footerHeight,
                  child: _buildFooter(context),
                ),
                // Web 固有の注意書き
                if (notices.isNotEmpty)
                  Positioned(
                    top: 47,
                    left: 8,
                    right: 8,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: notices,
                    ),
                  ),
              ],
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
        padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 2),
        child: Text(
          label,
          style: AppTypography.bodyS.copyWith(color: AppColors.textBrand),
        ),
      ),
    );
  }
}
