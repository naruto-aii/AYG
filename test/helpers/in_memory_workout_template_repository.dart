import 'package:ayg/models/exercise_category.dart';
import 'package:ayg/models/workout_template.dart';
import 'package:ayg/repositories/contracts/workout_template_repository_base.dart';
import 'package:ayg/utils/food_name_normalizer.dart';

/// DataSync 結合テスト用のインメモリ WorkoutTemplateRepository。
class InMemoryWorkoutTemplateRepository
    implements WorkoutTemplateRepositoryBase {
  final List<WorkoutTemplate> _templates = [];
  final Map<String, List<WorkoutTemplateItem>> _itemsByKey = {};

  String _key(String ownerUserId, String templateId) =>
      '$ownerUserId::$templateId';

  @override
  Future<void> saveWithItems({
    required WorkoutTemplate template,
    required List<WorkoutTemplateItem> items,
  }) async {
    _templates.removeWhere(
      (t) =>
          t.templateId == template.templateId &&
          t.ownerUserId == template.ownerUserId,
    );
    _templates.add(template);
    _itemsByKey[_key(template.ownerUserId, template.templateId)] = List.of(
      items,
    );
  }

  @override
  Future<WorkoutTemplate?> getById({
    required String ownerUserId,
    required String templateId,
  }) async {
    for (final template in _templates) {
      if (template.templateId == templateId &&
          template.ownerUserId == ownerUserId &&
          template.status == WorkoutTemplateStatus.active) {
        return template;
      }
    }
    return null;
  }

  @override
  Future<List<WorkoutTemplate>> getAll(String ownerUserId) async {
    return _templates
        .where(
          (t) =>
              t.ownerUserId == ownerUserId &&
              t.status == WorkoutTemplateStatus.active,
        )
        .toList();
  }

  @override
  Future<List<WorkoutTemplate>> search({
    required String ownerUserId,
    required String query,
  }) async {
    final normalized = FoodNameNormalizer.normalize(query);
    if (normalized.isEmpty) {
      return getAll(ownerUserId);
    }
    return _templates
        .where(
          (t) =>
              t.ownerUserId == ownerUserId &&
              t.status == WorkoutTemplateStatus.active &&
              t.normalizedName.contains(normalized),
        )
        .toList();
  }

  @override
  Future<void> softDelete({
    required String ownerUserId,
    required String templateId,
    required DateTime deletedAt,
  }) async {
    for (var i = 0; i < _templates.length; i++) {
      final t = _templates[i];
      if (t.templateId == templateId && t.ownerUserId == ownerUserId) {
        _templates[i] = t.copyWith(
          status: WorkoutTemplateStatus.deleted,
          deletedAt: deletedAt,
          updatedAt: deletedAt,
        );
      }
    }
  }

  @override
  Future<List<WorkoutTemplateItem>> getItems({
    required String ownerUserId,
    required String templateId,
  }) async {
    return List.of(_itemsByKey[_key(ownerUserId, templateId)] ?? const []);
  }

  @override
  Future<List<WorkoutTemplate>> loadAllOwnIncludingDeleted(
    String ownerUserId,
  ) async {
    return _templates.where((t) => t.ownerUserId == ownerUserId).toList();
  }

  @override
  Future<void> clearAll() async {
    _templates.clear();
    _itemsByKey.clear();
  }

  @override
  Future<void> clearForOwner(String ownerUserId) async {
    _templates.removeWhere((t) => t.ownerUserId == ownerUserId);
    _itemsByKey.removeWhere((key, _) => key.startsWith('$ownerUserId::'));
  }

  @override
  Future<void> reassignOwnerUserId({
    required String fromOwnerUserId,
    required String toOwnerUserId,
  }) async {
    for (var i = 0; i < _templates.length; i++) {
      if (_templates[i].ownerUserId == fromOwnerUserId) {
        final old = _templates[i];
        _templates[i] = old.copyWith(ownerUserId: toOwnerUserId);
      }
    }
    final migratedItems = <String, List<WorkoutTemplateItem>>{};
    for (final entry in _itemsByKey.entries) {
      if (entry.key.startsWith('$fromOwnerUserId::')) {
        final templateId = entry.key.split('::').last;
        migratedItems['$toOwnerUserId::$templateId'] = entry.value;
      } else {
        migratedItems[entry.key] = entry.value;
      }
    }
    _itemsByKey
      ..clear()
      ..addAll(migratedItems);
  }
}

WorkoutTemplate sampleWorkoutTemplate({
  required String ownerUserId,
  required String templateId,
  String name = 'Morning',
}) {
  final now = DateTime(2026, 8, 1);
  return WorkoutTemplate(
    templateId: templateId,
    ownerUserId: ownerUserId,
    name: name,
    normalizedName: FoodNameNormalizer.normalize(name),
    createdAt: now,
    updatedAt: now,
  );
}

List<WorkoutTemplateItem> sampleWorkoutItems({required String templateId}) {
  return [
    WorkoutTemplateItem(
      itemId: '$templateId-item-1',
      name: 'Run',
      categoryKey: ExerciseCategory.aerobic.id,
      durationMin: 30,
      sortOrder: 1,
    ),
    WorkoutTemplateItem(
      itemId: '$templateId-item-2',
      name: 'Stretch',
      durationMin: 10,
      sortOrder: 2,
    ),
  ];
}

/// [DataSyncRepository._pullWorkoutTemplates] と同等の pull 境界。
Future<void> syncPullWorkoutTemplates({
  required String userId,
  required InMemoryWorkoutTemplateRepository local,
  required InMemoryWorkoutTemplateRepository remote,
}) async {
  final templates = await remote.loadAllOwnIncludingDeleted(userId);
  final itemsByTemplate = <String, List<WorkoutTemplateItem>>{};
  for (final template in templates) {
    itemsByTemplate[template.templateId] = await remote.getItems(
      ownerUserId: userId,
      templateId: template.templateId,
    );
  }

  await local.clearForOwner(userId);
  if (templates.isEmpty) {
    return;
  }

  for (final template in templates) {
    await local.saveWithItems(
      template: template,
      items: itemsByTemplate[template.templateId] ?? const [],
    );
  }
}

/// [DataSyncRepository._pushWorkoutTemplates] と同等の push 境界。
Future<void> syncPushWorkoutTemplates({
  required String userId,
  required InMemoryWorkoutTemplateRepository local,
  required InMemoryWorkoutTemplateRepository remote,
}) async {
  final templates = await local.loadAllOwnIncludingDeleted(userId);
  final itemsByTemplate = <String, List<WorkoutTemplateItem>>{};
  for (final template in templates) {
    itemsByTemplate[template.templateId] = await local.getItems(
      ownerUserId: userId,
      templateId: template.templateId,
    );
  }

  for (final template in templates) {
    await remote.saveWithItems(
      template: template,
      items: itemsByTemplate[template.templateId] ?? const [],
    );
  }

  // orphan cleanup mirror
  for (final template in templates) {
    final keepIds = (itemsByTemplate[template.templateId] ?? const [])
        .map((item) => item.itemId)
        .toSet();
    final remoteItems = await remote.getItems(
      ownerUserId: userId,
      templateId: template.templateId,
    );
    final pruned = remoteItems.where((item) => keepIds.contains(item.itemId));
    await remote.saveWithItems(template: template, items: pruned.toList());
  }
}
