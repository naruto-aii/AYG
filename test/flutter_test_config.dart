import 'package:isar/isar.dart';

Future<void> testExecutable(Future<void> Function() testMain) async {
  await Isar.initializeIsarCore(download: true);
  await testMain();
}
