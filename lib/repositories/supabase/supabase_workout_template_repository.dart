import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/workout_template.dart';
import 'supabase_error_mapper.dart';

class SupabaseWorkoutTemplateRepository {
  SupabaseWorkoutTemplateRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<List<WorkoutTemplate>> pullAllOwn(String userId) async {
    try {
      final rows = await _client
          .from('workout_templates')
          .select()
          .eq('user_id', userId);
      return rows.map(_templateFromRow).toList();
    } catch (error) {
      throw SupabaseErrorMapper.map(error, context: 'workout_templates pull');
    }
  }

  Future<Map<String, List<WorkoutTemplateItem>>> pullAllItems(
    String userId,
  ) async {
    try {
      final rows = await _client
          .from('workout_template_items')
          .select()
          .eq('user_id', userId)
          .order('sort_order');
      final grouped = <String, List<WorkoutTemplateItem>>{};
      for (final row in rows) {
        final item = _itemFromRow(row);
        grouped.putIfAbsent(row['template_id'] as String, () => []).add(item);
      }
      return grouped;
    } catch (error) {
      throw SupabaseErrorMapper.map(
        error,
        context: 'workout_template_items pull all',
      );
    }
  }

  Future<void> pushTemplateWithItems({
    required String userId,
    required WorkoutTemplate template,
    required List<WorkoutTemplateItem> items,
  }) async {
    try {
      await _client
          .from('workout_templates')
          .upsert(
            _templateToRow(template, userId: userId),
            onConflict: 'user_id,template_id',
          );

      if (items.isEmpty) {
        await _client
            .from('workout_template_items')
            .delete()
            .eq('user_id', userId)
            .eq('template_id', template.templateId);
        return;
      }

      await _client
          .from('workout_template_items')
          .upsert(
            items
                .map(
                  (item) => _itemToRow(
                    item,
                    userId: userId,
                    templateId: template.templateId,
                  ),
                )
                .toList(),
            onConflict: 'user_id,item_id',
          );

      final keepIds = items.map((item) => item.itemId).toSet();
      final existingRows = await _client
          .from('workout_template_items')
          .select('item_id')
          .eq('user_id', userId)
          .eq('template_id', template.templateId);
      for (final row in existingRows) {
        final itemId = row['item_id'] as String;
        if (!keepIds.contains(itemId)) {
          await _client
              .from('workout_template_items')
              .delete()
              .eq('user_id', userId)
              .eq('item_id', itemId);
        }
      }
    } catch (error) {
      throw SupabaseErrorMapper.map(
        error,
        context: 'workout_templates push with items',
      );
    }
  }

  Future<void> pushAllOwn({
    required String userId,
    required List<WorkoutTemplate> templates,
    required Map<String, List<WorkoutTemplateItem>> itemsByTemplateId,
  }) async {
    for (final template in templates) {
      await pushTemplateWithItems(
        userId: userId,
        template: template,
        items: itemsByTemplateId[template.templateId] ?? const [],
      );
    }
  }

  static WorkoutTemplate _templateFromRow(Map<String, dynamic> row) {
    return WorkoutTemplate(
      templateId: row['template_id'] as String,
      ownerUserId: row['user_id'] as String,
      name: row['name'] as String,
      normalizedName: row['normalized_name'] as String,
      status:
          WorkoutTemplateStatusX.tryParse(row['status'] as String?) ??
          WorkoutTemplateStatus.active,
      useCount: (row['use_count'] as num?)?.toInt() ?? 0,
      lastUsedAt: row['last_used_at'] == null
          ? null
          : DateTime.parse(row['last_used_at'] as String),
      createdAt: DateTime.parse(row['created_at'] as String),
      updatedAt: DateTime.parse(row['updated_at'] as String),
      deletedAt: row['deleted_at'] == null
          ? null
          : DateTime.parse(row['deleted_at'] as String),
    );
  }

  static WorkoutTemplateItem _itemFromRow(Map<String, dynamic> row) {
    return WorkoutTemplateItem(
      itemId: row['item_id'] as String,
      name: row['name'] as String,
      activityId: row['activity_id'] as String?,
      categoryKey: row['category_key'] as String?,
      intensity: row['intensity'] as String?,
      durationMin: row['duration_min'] as int,
      sets: (row['sets'] as num?)?.toInt(),
      reps: (row['reps'] as num?)?.toInt(),
      liftWeightKg: (row['lift_weight_kg'] as num?)?.toDouble(),
      sortOrder: (row['sort_order'] as num?)?.toInt() ?? 0,
      notes: row['notes'] as String?,
      metValue: (row['met_value'] as num?)?.toDouble(),
      sourceKey: row['source_key'] as String?,
    );
  }

  static Map<String, dynamic> _templateToRow(
    WorkoutTemplate template, {
    required String userId,
  }) {
    return {
      'user_id': userId,
      'template_id': template.templateId,
      'name': template.name,
      'normalized_name': template.normalizedName,
      'status': template.status.storageValue,
      'use_count': template.useCount,
      'last_used_at': template.lastUsedAt?.toIso8601String(),
      'created_at': template.createdAt.toIso8601String(),
      'updated_at': template.updatedAt.toIso8601String(),
      'deleted_at': template.deletedAt?.toIso8601String(),
    };
  }

  static Map<String, dynamic> _itemToRow(
    WorkoutTemplateItem item, {
    required String userId,
    required String templateId,
  }) {
    return {
      'user_id': userId,
      'item_id': item.itemId,
      'template_id': templateId,
      'name': item.name,
      'activity_id': item.activityId,
      'category_key': item.categoryKey,
      'intensity': item.intensity,
      'duration_min': item.durationMin,
      'sets': item.sets,
      'reps': item.reps,
      'lift_weight_kg': item.liftWeightKg,
      'sort_order': item.sortOrder,
      'notes': item.notes,
      'met_value': item.metValue,
      'source_key': item.sourceKey,
    };
  }
}
