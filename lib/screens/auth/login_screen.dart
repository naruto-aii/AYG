import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../config/demo_mode.dart';
import '../../constants/app_strings.dart';
import '../../demo/demo_authentication_repository.dart';
import '../../platform/web/in_app_browser_detector.dart';
import '../../platform/web/web_browser_utils.dart';
import '../../repositories/auth_exceptions.dart';
import '../../repositories/authentication_repository.dart';
import '../../services/ai_data_consent.dart';
import '../../services/analytics/catalog_actions.dart';
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

  static const double _consentTop = 714;
  static const double _footerTop = 799;
  static const double _footerHeight = 25;

  bool _isLoading = false;

  Future<void> _signInWithGoogle() =>
      _signIn(widget.authenticationRepository.loginWithGoogle, 'Google');

  Future<void> _signInWithApple() =>
      _signIn(widget.authenticationRepository.loginWithApple, 'Apple');

  Future<void> _signInAsDemo() async {
    final repository = widget.authenticationRepository;
    if (repository is DemoAuthenticationRepository) {
      await _signIn(repository.loginAsDemo, 'デモ');
    }
  }

  /// Google / Apple 共通のログイン処理。
  /// キャンセルは何も出さず、失敗だけ通知する。
  Future<void> _signIn(Future<void> Function() login, String label) async {
    if (_isLoading) {
      return;
    }
    final provider = label == 'Apple' ? 'apple' : 'google';
    CatalogActions.loginTap(provider);
    setState(() => _isLoading = true);
    try {
      if (kIsWeb) {
        // Web は外部ブラウザへ遷移して戻るので、押した時点の同意を先に残す。
        await AiDataConsent.recordLoginAgreement();
      }
      await login();
      CatalogActions.loginResult(provider: provider, result: 'success');
      if (kIsWeb) {
        // Web は外部ブラウザへ遷移するので、戻ってきたときに復帰する。
        return;
      }
      // ボタンを押してログインできたことが、下の同意文への同意。
      await AiDataConsent.recordLoginAgreement();
      await widget.controller.handleAuthenticatedSession();
    } on SignInCancelledException {
      CatalogActions.loginResult(provider: provider, result: 'cancelled');
      return;
    } catch (error) {
      CatalogActions.loginResult(
        provider: provider,
        result: 'failed',
        errorKind: error.runtimeType.toString(),
      );
      if (!mounted) {
        return;
      }
      final message = error is SignInFailedException
          ? error.message
          : error.toString();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$labelログインに失敗しました: $message')));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
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
                      if (calonaviDemoMode) ...[
                        const SizedBox(height: 4),
                        TextButton(
                          key: const Key('demo-sign-in'),
                          onPressed: _isLoading ? null : _signInAsDemo,
                          child: Text(
                            'デモではじめる',
                            style: AppTypography.labelM.copyWith(
                              color: AppColors.textBrand,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                // 同意文言（Figma には無いが法務表示として残す）
                Positioned(
                  top: _consentTop,
                  left: _contentLeft,
                  width: _contentWidth,
                  child: const Column(
                    children: [
                      Text(
                        AppStrings.loginLegalAgreementMultiline,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        style: AppTypography.caption,
                      ),
                      SizedBox(height: 8),
                      Text(
                        AppStrings.loginAiDisclosureMultiline,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        style: AppTypography.caption,
                      ),
                    ],
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
