import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import 'legal_document.dart';

/// Renders the subset of legal HTML used in `legal/*.html`.
class LegalHtmlView extends StatelessWidget {
  const LegalHtmlView({
    super.key,
    required this.html,
    required this.onOpenDocument,
  });

  final String html;
  final ValueChanged<LegalDocument> onOpenDocument;

  @override
  Widget build(BuildContext context) {
    final meta = _extractMeta(html);
    final mainHtml = _extractMain(html);
    final blocks = _parseBlocks(mainHtml);
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.xl,
      ),
      children: [
        if (meta != null && meta.isNotEmpty) ...[
          Text(
            meta,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.secondaryText,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        for (final block in blocks) ...[
          _LegalBlockView(
            block: block,
            titleStyle: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
            bodyStyle: theme.textTheme.bodyMedium,
            onOpenDocument: onOpenDocument,
          ),
          const SizedBox(height: AppSpacing.md),
        ],
      ],
    );
  }
}

class _LegalBlock {
  const _LegalBlock(this.kind, this.inner);

  final String kind;
  final String inner;
}

class _LegalBlockView extends StatelessWidget {
  const _LegalBlockView({
    required this.block,
    required this.titleStyle,
    required this.bodyStyle,
    required this.onOpenDocument,
  });

  final _LegalBlock block;
  final TextStyle? titleStyle;
  final TextStyle? bodyStyle;
  final ValueChanged<LegalDocument> onOpenDocument;

  @override
  Widget build(BuildContext context) {
    if (block.kind == 'h2') {
      return Text(_plainText(block.inner), style: titleStyle);
    }
    if (block.kind == 'ul' || block.kind == 'ol') {
      final items = _listItems(block.inner);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < items.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    block.kind == 'ol' ? '${i + 1}. ' : '・ ',
                    style: bodyStyle,
                  ),
                  Expanded(
                    child: _InlineHtmlText(
                      html: items[i],
                      style: bodyStyle,
                      onOpenDocument: onOpenDocument,
                    ),
                  ),
                ],
              ),
            ),
        ],
      );
    }
    return _InlineHtmlText(
      html: block.inner,
      style: bodyStyle,
      onOpenDocument: onOpenDocument,
    );
  }
}

class _InlineHtmlText extends StatelessWidget {
  const _InlineHtmlText({
    required this.html,
    required this.style,
    required this.onOpenDocument,
  });

  final String html;
  final TextStyle? style;
  final ValueChanged<LegalDocument> onOpenDocument;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        style: style,
        children: _parseInline(
          html,
          style,
          onOpenDocument,
          Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}

String? _extractMeta(String html) {
  final match = RegExp(
    r'<p class="meta">([\s\S]*?)</p>',
    caseSensitive: false,
  ).firstMatch(html);
  if (match == null) {
    return null;
  }
  final text = _plainText(match.group(1)!);
  return text.isEmpty ? null : text;
}

String _extractMain(String html) {
  final match = RegExp(
    r'<main[^>]*>([\s\S]*?)</main>',
    caseSensitive: false,
  ).firstMatch(html);
  return match?.group(1) ?? html;
}

List<_LegalBlock> _parseBlocks(String html) {
  final blocks = <_LegalBlock>[];
  final re = RegExp(
    r'<(h2|p|ul|ol)[^>]*>([\s\S]*?)</\1>',
    caseSensitive: false,
  );
  for (final match in re.allMatches(html)) {
    blocks.add(_LegalBlock(match.group(1)!.toLowerCase(), match.group(2)!));
  }
  return blocks;
}

List<String> _listItems(String html) {
  return RegExp(
    r'<li[^>]*>([\s\S]*?)</li>',
    caseSensitive: false,
  ).allMatches(html).map((match) => match.group(1)!.trim()).toList();
}

List<InlineSpan> _parseInline(
  String html,
  TextStyle? style,
  ValueChanged<LegalDocument> onOpenDocument,
  Color linkColor,
) {
  final spans = <InlineSpan>[];
  final re = RegExp(
    r'<a\s+href="([^"]+)"[^>]*>([\s\S]*?)</a>|<br\s*/?>|<strong>([\s\S]*?)</strong>',
    caseSensitive: false,
  );
  var cursor = 0;
  for (final match in re.allMatches(html)) {
    if (match.start > cursor) {
      spans.add(TextSpan(text: _plainText(html.substring(cursor, match.start))));
    }
    final href = match.group(1);
    if (href != null) {
      final label = _plainText(match.group(2) ?? href);
      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
          child: GestureDetector(
            onTap: () => _handleHref(href, onOpenDocument),
            child: Text(
              label,
              style: (style ?? const TextStyle()).copyWith(
                color: linkColor,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ),
      );
    } else if (match.group(0)!.toLowerCase().startsWith('<br')) {
      spans.add(const TextSpan(text: '\n'));
    } else {
      spans.add(
        TextSpan(
          text: _plainText(match.group(3) ?? ''),
          style: (style ?? const TextStyle()).copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }
    cursor = match.end;
  }
  if (cursor < html.length) {
    spans.add(TextSpan(text: _plainText(html.substring(cursor))));
  }
  return spans;
}

void _handleHref(String href, ValueChanged<LegalDocument> onOpenDocument) {
  final document = LegalDocumentInfo.fromHref(href);
  if (document != null) {
    onOpenDocument(document);
    return;
  }
  final uri = Uri.tryParse(href);
  if (uri != null && (uri.isScheme('mailto') || uri.isScheme('https'))) {
    launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

String _plainText(String html) {
  return html
      .replaceAll(RegExp(r'<[^>]+>'), '')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}
