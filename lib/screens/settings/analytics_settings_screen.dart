import 'package:flutter/material.dart';

import '../../services/analytics/analytics.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';

/// 設定の「規約とポリシー」→「利用状況の記録」。切ると送信待ちを消す。
class AnalyticsSettingsScreen extends StatefulWidget {
  const AnalyticsSettingsScreen({super.key});

  @override
  State<AnalyticsSettingsScreen> createState() =>
      _AnalyticsSettingsScreenState();
}

class _AnalyticsSettingsScreenState extends State<AnalyticsSettingsScreen> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final service = Analytics.service;
    final granted = service?.consented ?? false;
    return Scaffold(
      backgroundColor: AppColors.backgroundCream,
      appBar: AppBar(title: const Text('利用状況の記録')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Text(
            'アプリの利用状況などのデータは、サービス改善のための分析に使う場合があります（プライバシーポリシー 3-2）。オフにすると、この端末の送信待ちを消して、以後は送りません。',
            style: AppTypography.bodyM,
          ),
          const SizedBox(height: AppSpacing.md),
          SwitchListTile(
            key: const Key('analytics-consent-switch'),
            contentPadding: EdgeInsets.zero,
            title: const Text('利用状況を記録する'),
            value: granted,
            onChanged: service == null || _busy
                ? null
                : (value) async {
                    setState(() => _busy = true);
                    if (value) {
                      await service.grantConsent(surface: 'settings');
                    } else {
                      await service.revokeConsent();
                    }
                    if (mounted) {
                      setState(() => _busy = false);
                    }
                  },
          ),
          const SizedBox(height: AppSpacing.sm),
          TextButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  settings: const RouteSettings(name: 'external_transmission'),
                  builder: (context) => const ExternalTransmissionScreen(),
                ),
              );
            },
            child: const Text('外部送信について'),
          ),
        ],
      ),
    );
  }
}

/// 電気通信事業法の外部送信の規律に合わせた一覧。
class ExternalTransmissionScreen extends StatelessWidget {
  const ExternalTransmissionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundCream,
      appBar: AppBar(
        title: const Text(
          '外部送信について',
          style: TextStyle(fontFamily: AppTypography.fontFamily),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: const [
          Text(
            '保存先はシンガポールです（Supabase, Inc. のデータベース。Amazon Web Services のシンガポール地域）。',
            style: AppTypography.bodyM,
          ),
          SizedBox(height: AppSpacing.md),
          _SendRow(
            what: '操作の記録、端末の機種と版、ランダムな番号',
            who: 'Supabase, Inc.（データの保管を委託。保存先はシンガポール）',
            why: '使いにくい所を見つけて直すため、有料機能の設計のため',
          ),
          _SendRow(
            what: '広告から入れたかを確かめるための一時的な札',
            who: 'Apple Inc.',
            why: 'Apple の広告の効果を確かめるため',
          ),
          _SendRow(
            what: 'ログインの情報',
            who: 'Apple Inc.、Google LLC',
            why: 'ログインのため',
          ),
          _SendRow(what: '購入の情報', who: 'Apple Inc.', why: '購入の手続きのため'),
          _SendRow(what: 'バーコードの番号', who: 'Open Food Facts', why: '商品を探すため'),
          _SendRow(
            what: '食事の写真と、入力した料理名、量、補足',
            who: 'Anthropic, PBC（米国）',
            why: 'カロリーとPFCの推定のため。カロナビは写真、料理名、量、補足の文面を保存しません',
          ),
          _SendRow(
            what: 'AIで探すの検索語',
            who: 'Anthropic, PBC（米国）',
            why: 'カロリーとPFCの推定のため。食品データベースには保存しません。推定は同じ利用者が再利用するために残し、アカウントを削除すると消します',
          ),
          _SendRow(
            what: '自炊コーチの、手元にある食材と、この食事の条件のメモ',
            who: 'Anthropic, PBC（米国）',
            why: '献立の推定のため。食材の一覧とメモの原文は食品データベースに保存しません。献立は再利用するために残します。利用者の識別子は入れないので、アカウントを削除しても消えません',
          ),
        ],
      ),
    );
  }
}

class _SendRow extends StatelessWidget {
  const _SendRow({required this.what, required this.who, required this.why});

  final String what;
  final String who;
  final String why;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(what, style: AppTypography.titleS),
          const SizedBox(height: 4),
          Text('送り先: $who', style: AppTypography.bodyM),
          Text('目的: $why', style: AppTypography.bodyM),
        ],
      ),
    );
  }
}
