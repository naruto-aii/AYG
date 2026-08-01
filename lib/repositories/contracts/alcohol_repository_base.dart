import '../../models/alcohol_entry.dart';

abstract class AlcoholRepositoryBase {
  Future<void> save(AlcoholEntry entry);

  Future<void> saveAll(List<AlcoholEntry> entries);

  Future<List<AlcoholEntry>> loadAll();

  Future<void> delete(String entryId);

  Future<void> clearAll();
}
