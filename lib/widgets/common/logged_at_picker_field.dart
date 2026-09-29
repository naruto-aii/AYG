import 'package:flutter/material.dart';

import '../../theme/app_spacing.dart';

/// 記録日時（日付＋時刻）の選択フィールド。
class LoggedAtPickerField extends StatelessWidget {
  const LoggedAtPickerField({
    super.key,
    required this.loggedAt,
    required this.onChanged,
    this.label = '記録日時',
  });

  final DateTime loggedAt;
  final ValueChanged<DateTime> onChanged;
  final String label;

  Future<void> _pick(BuildContext context) async {
    final local = loggedAt.toLocal();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: local,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (pickedDate == null || !context.mounted) {
      return;
    }

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(local),
    );
    if (pickedTime == null) {
      return;
    }

    onChanged(
      DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      ),
    );
  }

  String _format(DateTime value) {
    final local = value.toLocal();
    return '${local.year}/${local.month}/${local.day} '
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(label),
        subtitle: Text(_format(loggedAt)),
        trailing: const Icon(Icons.calendar_today_outlined),
        onTap: () => _pick(context),
      ),
    );
  }
}
