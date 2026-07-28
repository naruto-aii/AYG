import '../../../models/health_profile_data.dart';

/// Web向けインメモリ Health workout ストア。
class WebHealthWorkoutStore {
  final List<HealthWorkoutRecord> _records = [];

  Future<void> saveWorkoutRecords(List<HealthWorkoutRecord> records) async {
    if (records.isEmpty) {
      return;
    }
    _records.addAll(records);
  }

  Future<List<HealthWorkoutRecord>> loadWorkoutRecords() async {
    final copy = List<HealthWorkoutRecord>.from(_records);
    copy.sort((a, b) => b.startTime.compareTo(a.startTime));
    return copy;
  }

  Future<void> clearAll() async {
    _records.clear();
  }
}
