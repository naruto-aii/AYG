import '../../models/health_profile_data.dart';
import '../../models/weight_entry.dart';

abstract class WeightRepositoryBase {
  Future<void> save(WeightEntry entry);

  Future<List<WeightEntry>> loadAll();

  Future<double?> latestWeight({WeightSource? preferredSource});

  Future<List<WeightRecord>> loadWeightRecords();

  Future<void> saveWeightRecord(WeightRecord record);

  Future<void> clearAll();
}
