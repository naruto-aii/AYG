import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_colors.dart';
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
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(document.title),
        actions: [
          IconButton(
            tooltip: '閉じる',
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
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
