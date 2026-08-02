enum WorkoutTemplateStatus { active, deleted }

extension WorkoutTemplateStatusX on WorkoutTemplateStatus {
  String get storageValue => name;

  static WorkoutTemplateStatus? tryParse(String? raw) {
    if (raw == null) {
      return null;
    }
    return switch (raw) {
      'active' => WorkoutTemplateStatus.active,
      'deleted' => WorkoutTemplateStatus.deleted,
      _ => null,
    };
  }
}

class WorkoutTemplate {
  WorkoutTemplate({
    required this.templateId,
    required this.ownerUserId,
    required this.name,
    required this.normalizedName,
    this.status = WorkoutTemplateStatus.active,
    this.useCount = 0,
    this.lastUsedAt,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  final String templateId;
  final String ownerUserId;
  final String name;
  final String normalizedName;
  final WorkoutTemplateStatus status;
  final int useCount;
  final DateTime? lastUsedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  WorkoutTemplate copyWith({
    String? templateId,
    String? ownerUserId,
    String? name,
    String? normalizedName,
    WorkoutTemplateStatus? status,
    int? useCount,
    DateTime? lastUsedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
  }) {
    return WorkoutTemplate(
      templateId: templateId ?? this.templateId,
      ownerUserId: ownerUserId ?? this.ownerUserId,
      name: name ?? this.name,
      normalizedName: normalizedName ?? this.normalizedName,
      status: status ?? this.status,
      useCount: useCount ?? this.useCount,
      lastUsedAt: lastUsedAt ?? this.lastUsedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }
}

class WorkoutTemplateItem {
  WorkoutTemplateItem({
    required this.itemId,
    required this.name,
    this.activityId,
    this.categoryKey,
    this.intensity,
    required this.durationMin,
    this.sets,
    this.reps,
    this.liftWeightKg,
    required this.sortOrder,
    this.notes,
    this.metValue,
    this.sourceKey,
  });

  final String itemId;
  final String name;
  final String? activityId;
  final String? categoryKey;
  final String? intensity;
  final int durationMin;
  final int? sets;
  final int? reps;
  final double? liftWeightKg;
  final int sortOrder;
  final String? notes;
  final double? metValue;
  final String? sourceKey;

  WorkoutTemplateItem copyWith({
    String? itemId,
    String? name,
    String? activityId,
    String? categoryKey,
    String? intensity,
    int? durationMin,
    int? sets,
    int? reps,
    double? liftWeightKg,
    int? sortOrder,
    String? notes,
    double? metValue,
    String? sourceKey,
  }) {
    return WorkoutTemplateItem(
      itemId: itemId ?? this.itemId,
      name: name ?? this.name,
      activityId: activityId ?? this.activityId,
      categoryKey: categoryKey ?? this.categoryKey,
      intensity: intensity ?? this.intensity,
      durationMin: durationMin ?? this.durationMin,
      sets: sets ?? this.sets,
      reps: reps ?? this.reps,
      liftWeightKg: liftWeightKg ?? this.liftWeightKg,
      sortOrder: sortOrder ?? this.sortOrder,
      notes: notes ?? this.notes,
      metValue: metValue ?? this.metValue,
      sourceKey: sourceKey ?? this.sourceKey,
    );
  }
}

class WorkoutTemplateWithItems {
  const WorkoutTemplateWithItems({required this.template, required this.items});

  final WorkoutTemplate template;
  final List<WorkoutTemplateItem> items;
}

class WorkoutTemplateDraft {
  WorkoutTemplateDraft({required this.name, required this.items});

  final String name;
  final List<WorkoutTemplateItem> items;
}

class WorkoutTemplateApplyDraft {
  WorkoutTemplateApplyDraft({
    required this.name,
    required this.durationMin,
    required this.loggedAt,
    this.intensity,
    this.sets,
    this.reps,
    this.liftWeightKg,
    this.metValue,
    this.grossKcal,
    this.netKcal,
    this.notes,
    this.activityId,
    this.categoryKey,
    this.sourceKey,
  });

  final String name;
  final int durationMin;
  final DateTime loggedAt;
  final String? intensity;
  final int? sets;
  final int? reps;
  final double? liftWeightKg;
  final double? metValue;
  final double? grossKcal;
  final double? netKcal;
  final String? notes;
  final String? activityId;
  final String? categoryKey;
  final String? sourceKey;
}
