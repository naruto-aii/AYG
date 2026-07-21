import '../../../models/health_profile_data.dart';

class WebHealthWorkoutStore {
  final List<HealthWorkoutRecord> _records = [];

  Future<void> saveWorkoutRecords(List<HealthWorkoutRecord> records) async {
    if (records.isEmpty) {
      return;
    }
    _records.addAll(records);
  }

  Future<List<HealthWorkoutRecord>> loadWorkoutRecords() async {
    final records = List<HealthWorkoutRecord>.from(_records);
    records.sort((a, b) => b.startTime.compareTo(a.startTime));
    return records;
  }

  Future<void> clearAll() async {
    _records.clear();
  }
}
