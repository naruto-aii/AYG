import '../../../models/exercise_entry.dart';
import '../../../repositories/contracts/exercise_repository_base.dart';

class WebExerciseRepository implements ExerciseRepositoryBase {
  final List<ExerciseEntry> _entries = [];

  @override
  Future<void> save(ExerciseEntry entry) async {
    final index = _entries.indexWhere((item) => item.id == entry.id);
    if (index == -1) {
      _entries.add(entry);
      return;
    }
    _entries[index] = entry;
  }

  @override
  Future<void> saveAll(List<ExerciseEntry> entries) async {
    for (final entry in entries) {
      await save(entry);
    }
  }

  @override
  Future<List<ExerciseEntry>> loadAll() async {
    final entries = List<ExerciseEntry>.from(_entries);
    entries.sort((a, b) => b.loggedAt.compareTo(a.loggedAt));
    return entries;
  }

  @override
  Future<void> delete(String entryId) async {
    _entries.removeWhere((item) => item.id == entryId);
  }

  @override
  Future<void> clearAll() async {
    _entries.clear();
  }
}
