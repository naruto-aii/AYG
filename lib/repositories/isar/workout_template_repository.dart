import 'package:isar/isar.dart';

import '../../database/entity_mapper.dart';
import '../../database/entity_enum_codec.dart';
import '../../database/schemas.dart';
import '../../models/workout_template.dart';
import '../../utils/food_name_normalizer.dart';
import '../contracts/workout_template_repository_base.dart';

class WorkoutTemplateRepository implements WorkoutTemplateRepositoryBase {
  WorkoutTemplateRepository(this._isar);

  final Isar _isar;

  @override
  Future<void> saveWithItems({
    required WorkoutTemplate template,
    required List<WorkoutTemplateItem> items,
  }) async {
    await _isar.writeTxn(() async {
      await _isar.workoutTemplateEntitys.put(
        EntityMapper.toWorkoutTemplateEntity(template),
      );

      final existing = await _isar.workoutTemplateItemEntitys
          .filter()
          .templateIdEqualTo(template.templateId)
          .ownerUserIdEqualTo(template.ownerUserId)
          .findAll();
      if (existing.isNotEmpty) {
        await _isar.workoutTemplateItemEntitys.deleteAll(
          existing.map((e) => e.id).toList(),
        );
      }

      if (items.isNotEmpty) {
        await _isar.workoutTemplateItemEntitys.putAll(
          items
              .map(
                (item) => EntityMapper.toWorkoutTemplateItemEntity(
                  item: item,
                  templateId: template.templateId,
                  ownerUserId: template.ownerUserId,
                ),
              )
              .toList(),
        );
      }
    });
  }

  @override
  Future<WorkoutTemplate?> getById({
    required String ownerUserId,
    required String templateId,
  }) async {
    final entity = await _isar.workoutTemplateEntitys
        .filter()
        .templateIdEqualTo(templateId)
        .ownerUserIdEqualTo(ownerUserId)
        .findFirst();
    if (entity == null) {
      return null;
    }
    final status = EntityEnumCodec.workoutTemplateStatusFromIndex(
      entity.statusIndex,
    );
    if (status != WorkoutTemplateStatus.active) {
      return null;
    }
    return EntityMapper.fromWorkoutTemplateEntity(entity);
  }

  @override
  Future<List<WorkoutTemplate>> getAll(String ownerUserId) async {
    final entities = await _isar.workoutTemplateEntitys
        .filter()
        .ownerUserIdEqualTo(ownerUserId)
        .statusIndexEqualTo(
          EntityEnumCodec.workoutTemplateStatusIndex(
            WorkoutTemplateStatus.active,
          ),
        )
        .findAll();
    entities.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return entities.map(EntityMapper.fromWorkoutTemplateEntity).toList();
  }

  @override
  Future<List<WorkoutTemplate>> search({
    required String ownerUserId,
    required String query,
  }) async {
    final normalizedQuery = FoodNameNormalizer.normalize(query);
    if (normalizedQuery.isEmpty) {
      return getAll(ownerUserId);
    }

    final entities = await _isar.workoutTemplateEntitys
        .filter()
        .ownerUserIdEqualTo(ownerUserId)
        .statusIndexEqualTo(
          EntityEnumCodec.workoutTemplateStatusIndex(
            WorkoutTemplateStatus.active,
          ),
        )
        .normalizedNameContains(normalizedQuery, caseSensitive: false)
        .findAll();
    entities.sort((a, b) => a.normalizedName.compareTo(b.normalizedName));
    return entities.map(EntityMapper.fromWorkoutTemplateEntity).toList();
  }

  @override
  Future<void> softDelete({
    required String ownerUserId,
    required String templateId,
    required DateTime deletedAt,
  }) async {
    await _isar.writeTxn(() async {
      final entity = await _isar.workoutTemplateEntitys
          .filter()
          .templateIdEqualTo(templateId)
          .ownerUserIdEqualTo(ownerUserId)
          .findFirst();
      if (entity == null) {
        return;
      }
      entity
        ..statusIndex = EntityEnumCodec.workoutTemplateStatusIndex(
          WorkoutTemplateStatus.deleted,
        )
        ..deletedAt = deletedAt
        ..updatedAt = deletedAt;
      await _isar.workoutTemplateEntitys.put(entity);
    });
  }

  @override
  Future<List<WorkoutTemplateItem>> getItems({
    required String ownerUserId,
    required String templateId,
  }) async {
    final entities = await _isar.workoutTemplateItemEntitys
        .filter()
        .templateIdEqualTo(templateId)
        .ownerUserIdEqualTo(ownerUserId)
        .findAll();
    entities.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return entities.map(EntityMapper.fromWorkoutTemplateItemEntity).toList();
  }

  @override
  Future<List<WorkoutTemplate>> loadAllOwnIncludingDeleted(
    String ownerUserId,
  ) async {
    final entities = await _isar.workoutTemplateEntitys
        .filter()
        .ownerUserIdEqualTo(ownerUserId)
        .findAll();
    return entities.map(EntityMapper.fromWorkoutTemplateEntity).toList();
  }

  @override
  Future<void> clearAll() async {
    await _isar.writeTxn(() async {
      await _isar.workoutTemplateItemEntitys.clear();
      await _isar.workoutTemplateEntitys.clear();
    });
  }

  @override
  Future<void> clearForOwner(String ownerUserId) async {
    await _isar.writeTxn(() async {
      final items = await _isar.workoutTemplateItemEntitys
          .filter()
          .ownerUserIdEqualTo(ownerUserId)
          .findAll();
      if (items.isNotEmpty) {
        await _isar.workoutTemplateItemEntitys.deleteAll(
          items.map((e) => e.id).toList(),
        );
      }

      final templates = await _isar.workoutTemplateEntitys
          .filter()
          .ownerUserIdEqualTo(ownerUserId)
          .findAll();
      if (templates.isNotEmpty) {
        await _isar.workoutTemplateEntitys.deleteAll(
          templates.map((e) => e.id).toList(),
        );
      }
    });
  }

  @override
  Future<void> reassignOwnerUserId({
    required String fromOwnerUserId,
    required String toOwnerUserId,
  }) async {
    if (fromOwnerUserId == toOwnerUserId) {
      return;
    }

    await _isar.writeTxn(() async {
      final templates = await _isar.workoutTemplateEntitys
          .filter()
          .ownerUserIdEqualTo(fromOwnerUserId)
          .findAll();
      for (final entity in templates) {
        entity.ownerUserId = toOwnerUserId;
        await _isar.workoutTemplateEntitys.put(entity);
      }

      final items = await _isar.workoutTemplateItemEntitys
          .filter()
          .ownerUserIdEqualTo(fromOwnerUserId)
          .findAll();
      for (final entity in items) {
        entity.ownerUserId = toOwnerUserId;
        await _isar.workoutTemplateItemEntitys.put(entity);
      }
    });
  }
}
