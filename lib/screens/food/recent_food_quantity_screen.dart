import 'package:flutter/material.dart';

import '../../models/food_entry.dart';
import '../../models/food_unit_type.dart';
import '../../services/recent_foods.dart';
import '../../state/app_controller.dart';
import '../../widgets/design/design_button.dart';
import '../../widgets/design/design_page.dart';

/// 前回と違う量だけを入れる。
class RecentFoodQuantityScreen extends StatefulWidget {
  const RecentFoodQuantityScreen({
    super.key,
    required this.controller,
    required this.source,
    required this.loggedAt,
  });

  final AppController controller;
  final FoodEntry source;
  final DateTime loggedAt;

  @override
  State<RecentFoodQuantityScreen> createState() =>
      _RecentFoodQuantityScreenState();
}

class _RecentFoodQuantityScreenState extends State<RecentFoodQuantityScreen> {
  late final TextEditingController _amount = TextEditingController(
    text: _initialAmount(widget.source.consumedAmount),
  );
  bool _saving = false;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DesignPage(
      bottomBar: DesignButton(
        label: 'この量で登録',
        loading: _saving,
        showTrailingIcon: false,
        onPressed: _saving ? null : _save,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DesignTitleBlock(
            title: '量を入力',
            subtitle:
                '${widget.source.name}の前回は${formatFoodAmount(widget.source)}です。',
          ),
          TextField(
            controller: _amount,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: '量',
              suffixText: widget.source.unitType.label,
              border: const OutlineInputBorder(),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final amount = double.tryParse(_amount.text.trim());
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('量は0より大きい値を入力してください')));
      return;
    }
    setState(() => _saving = true);
    final added = await widget.controller.repeatRecentFood(
      widget.source,
      consumedAmount: amount,
      loggedAt: widget.loggedAt,
    );
    if (!mounted) {
      return;
    }
    setState(() => _saving = false);
    if (!added) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('登録できませんでした')));
      return;
    }
    Navigator.of(context).pop(true);
  }
}

String _initialAmount(double amount) {
  if (amount == amount.roundToDouble()) {
    return amount.toStringAsFixed(0);
  }
  return amount.toString();
}
