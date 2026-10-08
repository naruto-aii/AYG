import 'package:flutter/material.dart';

import '../../services/ai_data_consent.dart';
import '../../theme/app_typography.dart';
import 'legal_document.dart';
import 'legal_document_screen.dart';

/// 同意済みなら true。やめる、または保存に失敗したら false。AIは呼ばない。
Future<bool> ensureAiDataConsent(BuildContext context) async {
  final consent = await AiDataConsent.load();
  if (consent.isGranted) {
    return true;
  }
  if (!context.mounted) {
    return false;
  }
  final agreed = await showAiDataConsentDialog(context);
  if (agreed != true) {
    return false;
  }
  final saved = await consent.grant();
  if (!saved && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text(aiDataConsentSaveFailedMessage)),
    );
  }
  return saved;
}

Future<bool?> showAiDataConsentDialog(BuildContext context) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    routeSettings: const RouteSettings(name: 'ai_data_consent_dialog'),
    builder: (context) => const AiDataConsentDialog(),
  );
}

class AiDataConsentDialog extends StatelessWidget {
  const AiDataConsentDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: const Key('ai-data-consent-dialog'),
      title: const Text(aiDataConsentTitle),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(aiDataConsentBody),
            const SizedBox(height: 12),
            Text(aiDataConsentSendsTitle, style: AppTypography.titleS),
            const SizedBox(height: 4),
            for (final line in aiDataConsentSends)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text('・$line'),
              ),
            const SizedBox(height: 8),
            const Text(aiDataConsentStorage),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                key: const Key('ai-data-consent-privacy'),
                onPressed: () => showLegalDocument(context, LegalDocument.privacy),
                child: const Text(aiDataConsentPrivacyLabel),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const Key('ai-data-consent-decline'),
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text(aiDataConsentDeclineLabel),
        ),
        FilledButton(
          key: const Key('ai-data-consent-accept'),
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text(aiDataConsentAcceptLabel),
        ),
      ],
    );
  }
}
