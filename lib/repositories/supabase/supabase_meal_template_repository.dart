import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/meal_template.dart';
import 'food_master_row_mapper.dart';
import 'supabase_error_mapper.dart';

class SupabaseMealTemplateRepository {
  SupabaseMealTemplateRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<List<MealTemplate>> pullAllOwn(String userId) async {
    try {
      final rows = await _client
          .from('meal_templates')
          .select()
          .eq('user_id', userId);
      return rows.map(FoodMasterRowMapper.mealTemplateFromRow).toList();
    } catch (error) {
      throw SupabaseErrorMapper.map(error, context: 'meal_templates pull');
    }
  }

  Future<List<MealTemplateItem>> pullItems({
    required String userId,
    required String templateId,
  }) async {
    try {
      final rows = await _client
          .from('meal_template_items')
          .select()
          .eq('user_id', userId)
          .eq('template_id', templateId)
          .order('sort_order');
      return rows.map(FoodMasterRowMapper.mealTemplateItemFromRow).toList();
    } catch (error) {
      throw SupabaseErrorMapper.map(error, context: 'meal_template_items pull');
    }
  }

  Future<Map<String, List<MealTemplateItem>>> pullAllItems(
    String userId,
  ) async {
    try {
      final rows = await _client
          .from('meal_template_items')
          .select()
          .eq('user_id', userId)
          .order('sort_order');
      final grouped = <String, List<MealTemplateItem>>{};
      for (final row in rows) {
        final item = FoodMasterRowMapper.mealTemplateItemFromRow(row);
        final templateId = row['template_id'] as String;
        grouped.putIfAbsent(templateId, () => []).add(item);
      }
      return grouped;
    } catch (error) {
      throw SupabaseErrorMapper.map(
        error,
        context: 'meal_template_items pull all',
      );
    }
  }

  Future<void> pushTemplateWithItems({
    required String userId,
    required MealTemplate template,
    required List<MealTemplateItem> items,
  }) async {
    try {
      await _client
          .from('meal_templates')
          .upsert(
            FoodMasterRowMapper.mealTemplateToRow(template, userId: userId),
            onConflict: 'user_id,template_id',
          );

      await _client
          .from('meal_template_items')
          .delete()
          .eq('user_id', userId)
          .eq('template_id', template.templateId);

      if (items.isEmpty) {
        return;
      }

      await _client
          .from('meal_template_items')
          .insert(
            items
                .map(
                  (item) => FoodMasterRowMapper.mealTemplateItemToRow(
                    item,
                    userId: userId,
                    templateId: template.templateId,
                  ),
                )
                .toList(),
          );
    } catch (error) {
      throw SupabaseErrorMapper.map(
        error,
        context: 'meal_templates push with items',
      );
    }
  }

  Future<void> pushAllOwn({
    required String userId,
    required List<MealTemplate> templates,
    required Map<String, List<MealTemplateItem>> itemsByTemplateId,
  }) async {
    for (final template in templates) {
      await pushTemplateWithItems(
        userId: userId,
        template: template,
        items: itemsByTemplateId[template.templateId] ?? const [],
      );
    }
  }
}
