import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';

class EntryListTile extends StatelessWidget {
  const EntryListTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onTap,
    required this.onDelete,
    this.leadingIcon,
  });

  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final IconData? leadingIcon;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: ListTile(
        leading: leadingIcon == null
            ? null
            : CircleAvatar(
                backgroundColor: Theme.of(
                  context,
                ).colorScheme.secondaryContainer,
                child: Icon(
                  leadingIcon,
                  color: Theme.of(context).colorScheme.onSecondaryContainer,
                ),
              ),
        title: Text(title),
        subtitle: Text(subtitle),
        onTap: onTap,
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline),
          onPressed: onDelete,
        ),
      ),
    );
  }
}
