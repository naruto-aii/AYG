import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../widgets/design/design_icon.dart';
import 'legal_document.dart';
import 'legal_html_view.dart';

Future<void> showLegalDocument(
  BuildContext context,
  LegalDocument document,
) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => LegalDocumentScreen(document: document),
    ),
  );
}

class LegalDocumentScreen extends StatelessWidget {
  const LegalDocumentScreen({super.key, required this.document});

  final LegalDocument document;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundCream,
      // Figma: 35 規約・プライバシー表示（中央見出し＋右上の閉じる、下に細線）。
      appBar: AppBar(
        automaticallyImplyLeading: false,
        centerTitle: true,
        title: Text(document.title, style: AppTypography.titleL),
        actions: [
          IconButton(
            tooltip: '閉じる',
            icon: const DesignIcon(
              Symbols.close_rounded,
              size: 22,
              color: AppColors.iconMuted,
            ),
            onPressed: () => Navigator.of(context).pop(),
          ),
          const SizedBox(width: 4),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: AppColors.borderSubtle),
        ),
      ),
      body: SafeArea(
        child: FutureBuilder<String>(
          future: rootBundle.loadString(document.assetPath),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Center(child: Text('書類を読み込めませんでした'));
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            return LegalHtmlView(
              html: snapshot.data!,
              onOpenDocument: (next) {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    fullscreenDialog: true,
                    builder: (_) => LegalDocumentScreen(document: next),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
