import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';

/// FAB から表示する追加アクションシート。
Future<void> showAddActionSheet(
  BuildContext context, {
  required VoidCallback onAddFood,
  required VoidCallback onAddWorkout,
  required VoidCallback onRecordWeight,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.restaurant),
              title: const Text('食事を追加'),
              onTap: () {
                Navigator.of(context).pop();
                onAddFood();
              },
            ),
            ListTile(
              leading: const Icon(Icons.directions_run),
              title: const Text('運動を追加'),
              onTap: () {
                Navigator.of(context).pop();
                onAddWorkout();
              },
            ),
            ListTile(
              leading: const Icon(Icons.monitor_weight_outlined),
              title: const Text('体重を記録'),
              onTap: () {
                Navigator.of(context).pop();
                onRecordWeight();
              },
            ),
          ],
        ),
      ),
    ),
  );
}
