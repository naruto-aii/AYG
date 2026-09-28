import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../constants/official_food_copy.dart';
import '../../services/official_food_link.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import 'official_food_attribution_line.dart';

/// 短い出典。タップで全文と、外部ブラウザへのリンクを出す。
class OfficialFoodAttribution extends StatefulWidget {
  const OfficialFoodAttribution({
    super.key,
    this.initiallyExpanded = false,
    this.launch,
  });

  final bool initiallyExpanded;
  final Future<bool> Function(Uri uri, LaunchMode mode)? launch;

  @override
  State<OfficialFoodAttribution> createState() => _OfficialFoodAttributionState();
}

class _OfficialFoodAttributionState extends State<OfficialFoodAttribution> {
  late bool _expanded = widget.initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          key: const ValueKey('official_food_attribution'),
          onTap: () => setState(() => _expanded = !_expanded),
          child: _expanded
              ? Text(
                  OfficialFoodCopy.fullAttribution,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textMuted,
                  ),
                )
              : OfficialFoodAttributionLine(
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
        ),
        if (_expanded) ...[
          const SizedBox(height: 8),
          TextButton(
            key: const ValueKey('official_food_mext_link'),
            onPressed: () => openMextFoodCompositionPage(launch: widget.launch),
            child: const Text(OfficialFoodCopy.externalLinkLabel),
          ),
        ],
      ],
    );
  }
}
