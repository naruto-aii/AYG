import '../../models/exercise_entry.dart';

abstract class ExerciseRepositoryBase {
  Future<void> save(ExerciseEntry entry);

  Future<void> saveAll(List<ExerciseEntry> entries);

  Future<List<ExerciseEntry>> loadAll();

  Future<void> delete(String entryId);

  Future<void> clearAll();
}
