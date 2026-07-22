import 'package:isar/isar.dart';

import '../database/entity_mapper.dart';
import '../database/entity_enum_codec.dart';
import '../database/schemas.dart';
import '../models/meal_template.dart';
import '../utils/food_name_normalizer.dart';
import 'contracts/meal_template_repository_base.dart';

class MealTemplateRepository implements MealTemplateRepositoryBase {
  MealTemplateRepository(this._isar);

  final Isar _isar;

  @override
  Future<void> save(MealTemplate template) async {
    await _isar.writeTxn(() async {
      await _isar.mealTemplateEntitys.put(
        EntityMapper.toMealTemplateEntity(template),
      );
    });
  }

  @override
  Future<void> saveAll(List<MealTemplate> templates) async {
    await _isar.writeTxn(() async {
      await _isar.mealTemplateEntitys.putAll(
        templates.map(EntityMapper.toMealTemplateEntity).toList(),
      );
    });
  }

  @override
  Future<MealTemplate?> getById({
    required String ownerUserId,
    required String templateId,
  }) async {
    final entity = await _isar.mealTemplateEntitys
        .filter()
        .templateIdEqualTo(templateId)
        .ownerUserIdEqualTo(ownerUserId)
        .findFirst();
    if (entity == null) {
      return null;
    }
    return EntityMapper.fromMealTemplateEntity(entity);
  }

  @override
  Future<List<MealTemplate>> getAll(String ownerUserId) async {
    final entities = await _isar.mealTemplateEntitys
        .filter()
        .ownerUserIdEqualTo(ownerUserId)
        .statusIndexEqualTo(
          EntityEnumCodec.templateStatusIndex(TemplateStatus.active),
        )
        .findAll();
    entities.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return entities.map(EntityMapper.fromMealTemplateEntity).toList();
  }

  @override
  Future<List<MealTemplate>> search({
    required String ownerUserId,
    required String query,
  }) async {
    final normalizedQuery = FoodNameNormalizer.normalize(query);
    if (normalizedQuery.isEmpty) {
      return getAll(ownerUserId);
    }

    final entities = await _isar.mealTemplateEntitys
        .filter()
        .ownerUserIdEqualTo(ownerUserId)
        .statusIndexEqualTo(
          EntityEnumCodec.templateStatusIndex(TemplateStatus.active),
        )
        .normalizedNameContains(normalizedQuery, caseSensitive: false)
        .findAll();
    entities.sort((a, b) => a.normalizedName.compareTo(b.normalizedName));
    return entities.map(EntityMapper.fromMealTemplateEntity).toList();
  }

  @override
  Future<void> update(MealTemplate template) async {
    await save(template);
  }

  @override
  Future<void> softDelete({
    required String ownerUserId,
    required String templateId,
    required DateTime deletedAt,
  }) async {
    await _isar.writeTxn(() async {
      final entity = await _isar.mealTemplateEntitys
          .filter()
          .templateIdEqualTo(templateId)
          .ownerUserIdEqualTo(ownerUserId)
          .findFirst();
      if (entity == null) {
        return;
      }
      entity
        ..statusIndex = EntityEnumCodec.templateStatusIndex(
          TemplateStatus.deleted,
        )
        ..deletedAt = deletedAt
        ..updatedAt = deletedAt;
      await _isar.mealTemplateEntitys.put(entity);
    });
  }

  @override
  Future<void> replaceItems({
    required String ownerUserId,
    required String templateId,
    required List<MealTemplateItem> items,
  }) async {
    await _isar.writeTxn(() async {
      final existing = await _isar.mealTemplateItemEntitys
          .filter()
          .templateIdEqualTo(templateId)
          .ownerUserIdEqualTo(ownerUserId)
          .findAll();
      if (existing.isNotEmpty) {
        await _isar.mealTemplateItemEntitys.deleteAll(
          existing.map((e) => e.id).toList(),
        );
      }

      if (items.isEmpty) {
        return;
      }

      await _isar.mealTemplateItemEntitys.putAll(
        items
            .map(
              (item) => EntityMapper.toMealTemplateItemEntity(
                item: item,
                templateId: templateId,
                ownerUserId: ownerUserId,
              ),
            )
            .toList(),
      );
    });
  }

  @override
  Future<List<MealTemplateItem>> getItems({
    required String ownerUserId,
    required String templateId,
  }) async {
    final entities = await _isar.mealTemplateItemEntitys
        .filter()
        .templateIdEqualTo(templateId)
        .ownerUserIdEqualTo(ownerUserId)
        .findAll();
    entities.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return entities.map(EntityMapper.fromMealTemplateItemEntity).toList();
  }

  @override
  Future<void> clearAll() async {
    await _isar.writeTxn(() async {
      await _isar.mealTemplateItemEntitys.clear();
      await _isar.mealTemplateEntitys.clear();
    });
  }
}
