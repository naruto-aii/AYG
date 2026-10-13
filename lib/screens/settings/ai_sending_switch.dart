import 'dart:async';

import 'package:flutter/material.dart';

import '../../services/ai_data_consent.dart';
import '../../theme/app_typography.dart';

/// 設定の「AIへの送信」。オフのときは写真で登録、外食・コンビニ、AIで探すを送らない。
class AiSendingSwitch extends StatefulWidget {
  const AiSendingSwitch({super.key});

  @override
  State<AiSendingSwitch> createState() => _AiSendingSwitchState();
}

class _AiSendingSwitchState extends State<AiSendingSwitch> {
  bool? _enabled;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final enabled = await AiDataConsent.isSendingEnabled();
    if (!mounted) {
      return;
    }
    setState(() => _enabled = enabled);
  }

  Future<void> _set(bool value) async {
    setState(() => _busy = true);
    final saved = await AiDataConsent.saveSendingEnabled(value);
    if (!mounted) {
      return;
    }
    setState(() {
      _busy = false;
      if (saved) {
        _enabled = value;
      }
    });
    if (!saved) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('AIへの送信の設定を保存できませんでした。通信できるときにもう一度試してください。'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      key: const Key('settings-ai-sending'),
      contentPadding: EdgeInsets.zero,
      title: Text('AIへの送信', style: AppTypography.titleS),
      subtitle: Text(
        'オフにすると、写真で登録、外食・コンビニ、AIで探すはAnthropic, PBC（米国）に送りません。手入力の記録はそのまま使えます。',
        style: AppTypography.bodyS,
      ),
      value: _enabled ?? true,
      onChanged: _enabled == null || _busy ? null : _set,
    );
  }
}
