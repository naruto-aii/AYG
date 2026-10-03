import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/app_contact_config.dart';
import '../../constants/app_strings.dart';
import '../../repositories/auth_exceptions.dart';
import '../../repositories/authentication_repository.dart';
import '../../state/app_controller.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../widgets/design/design_button.dart';
import '../../widgets/design/design_page.dart';
import '../legal/legal_document.dart';
import '../legal/legal_document_screen.dart';

/// 設定から本人のアカウントを消す。公開食品は残す。
class AccountDeletionScreen extends StatefulWidget {
  const AccountDeletionScreen({
    super.key,
    required this.controller,
    required this.authenticationRepository,
    this.supportEmail,
  });

  final AppController controller;
  final AuthenticationRepository authenticationRepository;
  final String? supportEmail;

  @override
  State<AccountDeletionScreen> createState() => _AccountDeletionScreenState();
}

class _AccountDeletionScreenState extends State<AccountDeletionScreen> {
  bool _isDeleting = false;

  String get _contactEmail {
    return (widget.supportEmail ?? AppContactConfig.contactEmail).trim();
  }

  Future<void> _openMail() async {
    final email = _contactEmail;
    if (email.isEmpty) {
      return;
    }
    final uri = Uri(
      scheme: 'mailto',
      path: email,
      queryParameters: {'subject': AppStrings.accountDeletionMailSubject},
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _confirmAndDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(AppStrings.accountDeletionConfirmTitle),
          content: const Text(AppStrings.accountDeletionConfirmBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text(AppStrings.cancel),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text(AppStrings.accountDeletionExecute),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) {
      return;
    }

    setState(() => _isDeleting = true);
    try {
      final outcome = await widget.authenticationRepository.deleteOwnAccount();
      if (outcome.appleRevokeFailed && mounted) {
        setState(() => _isDeleting = false);
        await _showAppleRevokeFailed();
      }
      await widget.controller.logout(force: true);
    } on AccountDeletionUnavailableException {
      if (!mounted) {
        return;
      }
      setState(() => _isDeleting = false);
      await _showUnavailable();
    } on AccountDeletionFailedException {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.accountDeletionFailed)),
      );
    } finally {
      if (mounted) {
        setState(() => _isDeleting = false);
      }
    }
  }

  Future<void> _showAppleRevokeFailed() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text(AppStrings.accountDeletionAppleRevokeFailedTitle),
          content: const Text(AppStrings.accountDeletionAppleRevokeFailed),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(AppStrings.accountDeletionAppleRevokeFailedClose),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showUnavailable() async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(AppStrings.settingsAccountDeletion),
          content: const Text(AppStrings.accountDeletionUnavailable),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(AppStrings.cancel),
            ),
            if (_contactEmail.isNotEmpty)
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _openMail();
                },
                child: const Text(AppStrings.settingsContactOperator),
              ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return DesignPage(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const DesignTitleBlock(title: AppStrings.settingsAccountDeletion),
          Text(AppStrings.accountDeletionLead, style: AppTypography.bodyS),
          const SizedBox(height: AppSpacing.md),
          Text(AppStrings.accountDeletionRemoves, style: AppTypography.labelM),
          const SizedBox(height: AppSpacing.sm),
          Text(AppStrings.accountDeletionRemovesBody, style: AppTypography.bodyS),
          const SizedBox(height: AppSpacing.md),
          Text(AppStrings.accountDeletionKeeps, style: AppTypography.labelM),
          const SizedBox(height: AppSpacing.sm),
          Text(AppStrings.accountDeletionKeepsBody, style: AppTypography.bodyS),
          const SizedBox(height: AppSpacing.md),
          Text(AppStrings.accountDeletionBilling, style: AppTypography.bodyS),
          const SizedBox(height: AppSpacing.lg),
          DesignButton(
            label: AppStrings.accountDeletionExecute,
            style: DesignButtonStyle.danger,
            showTrailingIcon: false,
            loading: _isDeleting,
            onPressed: _isDeleting ? null : _confirmAndDelete,
          ),
          const SizedBox(height: AppSpacing.md),
          DesignButton(
            label: AppStrings.accountDeletionReadPolicy,
            style: DesignButtonStyle.outline,
            showTrailingIcon: false,
            onPressed: _isDeleting
                ? null
                : () => showLegalDocument(context, LegalDocument.accountDeletion),
          ),
        ],
      ),
    );
  }
}
