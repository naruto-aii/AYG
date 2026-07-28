import '../../../models/exercise_entry.dart';
import '../../../repositories/contracts/exercise_repository_base.dart';

/// Web向けインメモリ ExerciseRepository。
class ExerciseRepository implements ExerciseRepositoryBase {
  final List<ExerciseEntry> _entries = [];

  @override
  Future<void> save(ExerciseEntry entry) async {
    _entries.removeWhere((item) => item.id == entry.id);
    _entries.add(entry);
  }

  @override
  Future<void> saveAll(List<ExerciseEntry> entries) async {
    for (final entry in entries) {
      await save(entry);
    }
  }

  @override
  Future<List<ExerciseEntry>> loadAll() async {
    final copy = List<ExerciseEntry>.from(_entries);
    copy.sort((a, b) => b.loggedAt.compareTo(a.loggedAt));
    return copy;
  }

  @override
  Future<void> delete(String entryId) async {
    _entries.removeWhere((entry) => entry.id == entryId);
  }

  @override
  Future<void> clearAll() async {
    _entries.clear();
  }
}
