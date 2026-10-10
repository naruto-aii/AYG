import 'package:flutter/material.dart';

import '../../constants/app_strings.dart';
import '../../repositories/authentication_repository.dart';
import '../../services/ai_data_consent.dart';
import '../../state/app_controller.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../widgets/brand/app_brand_mark.dart';
import 'legal_document.dart';
import 'legal_document_screen.dart';

/// サインインのあと、アプリを使う前に出す利用規約とプライバシーの同意。
///
/// AI送信の一文と、不適切な内容を認めない一文を同じ画面に置く。
/// チェックボックスは増やさない。同意はアカウントごとに残す。
class TermsAgreementScreen extends StatefulWidget {
  const TermsAgreementScreen({
    super.key,
    required this.controller,
    required this.authenticationRepository,
  });

  final AppController controller;
  final AuthenticationRepository authenticationRepository;

  @override
  State<TermsAgreementScreen> createState() => _TermsAgreementScreenState();
}

class _TermsAgreementScreenState extends State<TermsAgreementScreen> {
  bool _saving = false;

  Future<void> _agree() async {
    if (_saving) {
      return;
    }
    final userId = widget.authenticationRepository.currentUser?.id;
    if (userId == null || userId.isEmpty) {
      return;
    }
    setState(() => _saving = true);
    final saved = await AiDataConsent.agreeForUser(userId);
    if (!saved) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(AppStrings.termsConsentSaveFailed)),
        );
      }
      return;
    }
    await widget.controller.handleAuthenticatedSession();
    if (mounted) {
      setState(() => _saving = false);
    }
  }

  Future<void> _decline() async {
    if (_saving) {
      return;
    }
    await widget.controller.logout();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('terms-agreement-screen'),
      backgroundColor: AppColors.bgPage,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(child: AppBrandMark(size: 72)),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    AppStrings.termsConsentTitle,
                    textAlign: TextAlign.center,
                    style: AppTypography.headingS.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    AppStrings.termsConsentLead,
                    textAlign: TextAlign.center,
                    style: AppTypography.bodyM,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  const _ConsentCard(),
                  const SizedBox(height: AppSpacing.lg),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _DocLink(
                        label: '利用規約',
                        onTap: () =>
                            showLegalDocument(context, LegalDocument.terms),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: Text(
                          '|',
                          style: AppTypography.bodyS.copyWith(
                            color: AppColors.textMuted,
                          ),
                        ),
                      ),
                      _DocLink(
                        label: 'プライバシーポリシー',
                        onTap: () =>
                            showLegalDocument(context, LegalDocument.privacy),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  FilledButton(
                    key: const Key('terms-agreement-agree'),
                    onPressed: _saving ? null : _agree,
                    child: _saving
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.textOnPrimary,
                            ),
                          )
                        : const Text(AppStrings.termsConsentAgree),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  TextButton(
                    key: const Key('terms-agreement-decline'),
                    onPressed: _saving ? null : _decline,
                    child: const Text(AppStrings.termsConsentDecline),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ConsentCard extends StatelessWidget {
  const _ConsentCard();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderDefault),
      ),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(AppStrings.termsConsentAi, style: AppTypography.bodyM),
            SizedBox(height: AppSpacing.md),
            Text(AppStrings.termsConsentUgc, style: AppTypography.bodyM),
          ],
        ),
      ),
    );
  }
}

class _DocLink extends StatelessWidget {
  const _DocLink({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
        child: Text(
          label,
          style: AppTypography.bodyS.copyWith(color: AppColors.textBrand),
        ),
      ),
    );
  }
}
