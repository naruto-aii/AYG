import 'package:flutter/material.dart';

import '../../services/share_card_content.dart';
import '../../services/share_sheet_client.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_typography.dart';
import '../design/design_button.dart';
import 'share_card_view.dart';

typedef ShareCardRequest =
    Future<ShareResult> Function(
      ShareCardContent content,
      GlobalKey boundaryKey,
    );

Future<void> showShareComposer({
  required BuildContext context,
  required List<ShareCardKind> kinds,
  required ShareCardKind initialKind,
  required bool showsWeightPrivacy,
  required ShareCardContent Function({
    required ShareCardKind kind,
    required ShareCardFormat format,
    required WeightPrivacy privacy,
  })
  build,
  required ShareCardRequest onShare,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.bgSurface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
    ),
    builder: (context) {
      return ShareComposer(
        kinds: kinds,
        initialKind: initialKind,
        showsWeightPrivacy: showsWeightPrivacy,
        build: build,
        onShare: onShare,
      );
    },
  );
}

class ShareComposer extends StatefulWidget {
  const ShareComposer({
    super.key,
    required this.kinds,
    required this.initialKind,
    required this.showsWeightPrivacy,
    required this.build,
    required this.onShare,
  });

  final List<ShareCardKind> kinds;
  final ShareCardKind initialKind;
  final bool showsWeightPrivacy;
  final ShareCardContent Function({
    required ShareCardKind kind,
    required ShareCardFormat format,
    required WeightPrivacy privacy,
  })
  build;
  final ShareCardRequest onShare;

  @override
  State<ShareComposer> createState() => _ShareComposerState();
}

class _ShareComposerState extends State<ShareComposer> {
  late ShareCardKind _kind = widget.initialKind;
  ShareCardFormat _format = ShareCardFormat.square;
  WeightPrivacy _privacy = WeightPrivacy.blurred;
  var _busy = false;
  final _boundaryKey = GlobalKey();

  ShareCardContent get _content {
    return widget.build(kind: _kind, format: _format, privacy: _privacy);
  }

  Future<void> _send() async {
    if (_busy) {
      return;
    }
    setState(() => _busy = true);
    final result = await widget.onShare(_content, _boundaryKey);
    if (!mounted) {
      return;
    }
    switch (result) {
      case ShareResult.sent:
        Navigator.of(context).pop();
      case ShareResult.cancelled:
        setState(() => _busy = false);
      case ShareResult.failed:
        setState(() => _busy = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('送れませんでした。もう一度試してください。')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = _content;
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: SingleChildScrollView(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.bgTrack,
                      borderRadius: BorderRadius.circular(AppRadius.full),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text('共有', style: AppTypography.headingS),
                const SizedBox(height: 2),
                Text(
                  '画像と文章とリンクを、まとめて送れます。',
                  style: AppTypography.bodyS.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 12),
                Center(
                  child: SizedBox(
                    height: 180,
                    child: FittedBox(
                      fit: BoxFit.contain,
                      child: SizedBox(
                        width: content.format.width,
                        height: content.format.height,
                        child: RepaintBoundary(
                          key: _boundaryKey,
                          child: ShareCardView(content: content),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (widget.kinds.length > 1) ...[
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final kind in widget.kinds)
                        _Choice(
                          label: shareKindLabel(kind),
                          selected: kind == _kind,
                          onTap: () => setState(() => _kind = kind),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _Choice(
                      label: '正方形',
                      selected: _format == ShareCardFormat.square,
                      onTap: () =>
                          setState(() => _format = ShareCardFormat.square),
                    ),
                    _Choice(
                      label: '縦長',
                      selected: _format == ShareCardFormat.story,
                      onTap: () =>
                          setState(() => _format = ShareCardFormat.story),
                    ),
                  ],
                ),
                if (widget.showsWeightPrivacy) ...[
                  const SizedBox(height: 8),
                  Text(
                    '体重の数字',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _Choice(
                        label: 'ぼかす',
                        selected: _privacy == WeightPrivacy.blurred,
                        onTap: () =>
                            setState(() => _privacy = WeightPrivacy.blurred),
                      ),
                      _Choice(
                        label: '隠す',
                        selected: _privacy == WeightPrivacy.hidden,
                        onTap: () =>
                            setState(() => _privacy = WeightPrivacy.hidden),
                      ),
                      _Choice(
                        label: '増減を出す',
                        selected: _privacy == WeightPrivacy.shown,
                        onTap: () =>
                            setState(() => _privacy = WeightPrivacy.shown),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '出すのは、選んだ期間の増減だけです。今の体重は入れません。',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  '画像が送れない相手にも、文章とリンクが届きます。',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 12),
                DesignButton(
                  label: 'この内容で送る',
                  height: 52,
                  showTrailingIcon: false,
                  loading: _busy,
                  onPressed: _busy ? null : _send,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Choice extends StatelessWidget {
  const _Choice({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = selected
        ? AppColors.textOnPrimary
        : AppColors.textSecondary;
    return Material(
      color: selected ? AppColors.bgPrimary : AppColors.bgSecondary,
      borderRadius: BorderRadius.circular(AppRadius.full),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.full),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Text(
            label,
            style: AppTypography.labelM.copyWith(color: foreground),
          ),
        ),
      ),
    );
  }
}
