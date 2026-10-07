import 'package:flutter/material.dart';

import '../../config/official_foods_flag.dart';
import '../../theme/app_icons.dart';
import '../../widgets/design/design_page.dart';
import '../../widgets/design/settings_row.dart';
import 'calculation_references_screen.dart';
import 'data_source_screen.dart';

/// 計算根拠とデータの出典。中身はそれぞれの画面のまま。
class SettingsReferenceScreen extends StatelessWidget {
  const SettingsReferenceScreen({super.key});

  void _push(BuildContext context, Widget screen) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(
      settings: const RouteSettings(name: 'settings_reference_screen_MaterialPageRoute_0'),builder: (context) => screen));
  }

  @override
  Widget build(BuildContext context) {
    final showDataSource = OfficialFoodsFlag.enabled;
    return DesignPage(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const DesignTitleBlock(
            title: '計算とデータについて',
            subtitle: 'カロリーの決め方と、食品の数値の出どころです。',
          ),
          SettingsRow(
            icon: AppIcons.calculator,
            title: '計算根拠',
            subtitle: 'カロリー・栄養素の算出方法について',
            onTap: () => _push(context, const CalculationReferencesScreen()),
          ),
          if (showDataSource) ...[
            const SizedBox(height: 8),
            SettingsRow(
              icon: AppIcons.document,
              title: 'データの出典',
              subtitle: '100gあたりの数値と表示名',
              onTap: () => _push(context, const DataSourceScreen()),
            ),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
