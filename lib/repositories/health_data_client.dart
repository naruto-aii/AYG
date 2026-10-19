import 'package:health/health.dart';

/// Health プラグインの読み取りと許可だけを扱う。
///
/// テストは実装を差し替える。ウィジェット拡張からは呼ばない。
abstract class HealthDataClient {
  Future<bool?> hasPermissions(List<HealthDataType> types);

  Future<bool> requestAuthorization(List<HealthDataType> types);

  Future<List<HealthDataPoint>> getHealthDataFromTypes({
    required List<HealthDataType> types,
    required DateTime startTime,
    required DateTime endTime,
  });
}

class PluginHealthDataClient implements HealthDataClient {
  PluginHealthDataClient([Health? health]) : _health = health ?? Health();

  final Health _health;

  @override
  Future<bool?> hasPermissions(List<HealthDataType> types) {
    return _health.hasPermissions(types);
  }

  @override
  Future<bool> requestAuthorization(List<HealthDataType> types) {
    return _health.requestAuthorization(types);
  }

  @override
  Future<List<HealthDataPoint>> getHealthDataFromTypes({
    required List<HealthDataType> types,
    required DateTime startTime,
    required DateTime endTime,
  }) {
    return _health.getHealthDataFromTypes(
      types: types,
      startTime: startTime,
      endTime: endTime,
    );
  }
}
