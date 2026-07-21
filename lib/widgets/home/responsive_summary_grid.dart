import 'package:flutter/material.dart';

import '../../theme/app_spacing.dart';

class ResponsiveSummaryGrid extends StatelessWidget {
  const ResponsiveSummaryGrid({super.key, required this.cards});

  final List<Widget> cards;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 480;
        if (!wide) {
          return Column(
            children: [
              for (var i = 0; i < cards.length; i++) ...[
                cards[i],
                if (i < cards.length - 1) const SizedBox(height: AppSpacing.xs),
              ],
            ],
          );
        }

        return Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: cards
              .map(
                (card) => SizedBox(
                  width: (constraints.maxWidth - AppSpacing.xs) / 2,
                  child: card,
                ),
              )
              .toList(),
        );
      },
    );
  }
}
