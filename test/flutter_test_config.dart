import 'package:ayg/services/ai_data_consent.dart';
import 'package:isar/isar.dart';

Future<void> testExecutable(Future<void> Function() testMain) async {
  await Isar.initializeIsarCore(download: true);
  // 既存のテストは「ログイン画面で同意済み」の端末として動かす。
  // 同意の有無を確かめるテストは、各自で上書きする。
  AiDataConsent.override = MemoryAiDataConsent(granted: true, synced: true);
  await testMain();
}
