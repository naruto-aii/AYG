import '../../models/workout_template.dart';

abstract class WorkoutTemplateRepositoryBase {
  Future<void> saveWithItems({
    required WorkoutTemplate template,
    required List<WorkoutTemplateItem> items,
  });

  Future<WorkoutTemplate?> getById({
    required String ownerUserId,
    required String templateId,
  });

  Future<List<WorkoutTemplate>> getAll(String ownerUserId);

  Future<List<WorkoutTemplate>> search({
    required String ownerUserId,
    required String query,
  });

  Future<void> softDelete({
    required String ownerUserId,
    required String templateId,
    required DateTime deletedAt,
  });

  Future<List<WorkoutTemplateItem>> getItems({
    required String ownerUserId,
    required String templateId,
  });

  Future<List<WorkoutTemplate>> loadAllOwnIncludingDeleted(String ownerUserId);

  Future<void> clearAll();

  Future<void> clearForOwner(String ownerUserId);

  Future<void> reassignOwnerUserId({
    required String fromOwnerUserId,
    required String toOwnerUserId,
  });
}
