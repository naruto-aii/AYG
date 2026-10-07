/// まとめて送った結果。成功したときだけキューから消す。
/// 表が無いときの再送間隔。同じ flush では繰り返さない。
const analyticsTableMissingHold = Duration(hours: 12);

/// 表が無い応答をこの回数まで保留し、それ以降は隔離する。
const analyticsTableMissingAttemptCap = 6;

class AnalyticsSendResult {
  const AnalyticsSendResult({this.statusCode, this.timedOut = false});

  const AnalyticsSendResult.success() : statusCode = 200, timedOut = false;

  final int? statusCode;
  final bool timedOut;

  bool get succeeded => statusCode != null && statusCode! >= 200 && statusCode! < 300;

  bool get unauthorized => statusCode == 401;

  /// app_events か insert_app_events がまだ無い
  /// （PGRST202 / PGRST205 / 42P01 / 42883 / 404）。無限に再送しない。
  bool get tableMissing => statusCode == 404;

  /// 通信できない、時間切れ、500 番台、429、401 は残して後で送る。
  bool get retryLater =>
      !succeeded &&
      !tableMissing &&
      (timedOut ||
          statusCode == null ||
          statusCode! >= 500 ||
          statusCode == 429 ||
          statusCode == 401);

  /// 400 番台のデータの誤り。401、404、429 は除く。
  bool get dataError =>
      statusCode != null &&
      statusCode! >= 400 &&
      statusCode! < 500 &&
      statusCode != 401 &&
      statusCode != 404 &&
      statusCode != 429;
}

abstract class AnalyticsTransport {
  Future<AnalyticsSendResult> send(List<Map<String, dynamic>> rows);
}

/// テスト用。スクリプトした応答を順に返す。
class ScriptedAnalyticsTransport implements AnalyticsTransport {
  ScriptedAnalyticsTransport(this.script);

  final List<AnalyticsSendResult> script;
  final List<Map<String, dynamic>> delivered = [];
  var calls = 0;

  @override
  Future<AnalyticsSendResult> send(List<Map<String, dynamic>> rows) async {
    final result = calls < script.length
        ? script[calls]
        : const AnalyticsSendResult.success();
    calls += 1;
    if (result.succeeded) {
      delivered.addAll(rows);
    }
    return result;
  }
}
