import 'package:flutter/material.dart';

import '../../theme/app_spacing.dart';
import '../../utils/saved_food_base_serving_format.dart';
import '../common/app_section_header.dart';
import '../common/app_text_field.dart';

/// 基準数量・基準単位の入力欄。
class ServingAmountFields extends StatelessWidget {
  const ServingAmountFields({
    super.key,
    required this.quantityController,
    required this.unitController,
    this.sectionTitle = '基準量',
    this.quantityLabel = '数量',
    this.unitLabel = '単位',
    this.quantityPlaceholder = '例：100',
    this.unitPlaceholder = '例：g、食、個、缶',
  });

  final TextEditingController quantityController;
  final TextEditingController unitController;
  final String sectionTitle;
  final String quantityLabel;
  final String unitLabel;
  final String quantityPlaceholder;
  final String unitPlaceholder;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppSectionHeader(title: sectionTitle),
        const SizedBox(height: AppSpacing.sm),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 2,
              child: AppTextField(
                controller: quantityController,
                label: quantityLabel,
                hint: quantityPlaceholder,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: (value) =>
                    SavedFoodBaseServingFormat.validateQuantity(value),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              flex: 2,
              child: AppTextField(
                controller: unitController,
                label: unitLabel,
                hint: unitPlaceholder,
                validator: (value) =>
                    SavedFoodBaseServingFormat.validateUnit(value),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
