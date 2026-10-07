/// `maintain_app_events` が集計する月かどうか。
/// 月の終わり（翌月1日 0:00 UTC）が、今から 90 日以上前なら集計済み。
/// データベースの `app_event_month_is_aggregated` と同じ式。
bool appEventMonthIsAggregated(DateTime occurredAt, DateTime now) {
  final utc = occurredAt.toUtc();
  final monthEnd = DateTime.utc(utc.year, utc.month + 1, 1);
  final cutoff = now.toUtc().subtract(const Duration(days: 90));
  return !monthEnd.isAfter(cutoff);
}

/// `insert_app_events` の戻り値から、集計済みとして弾いた event_id を読む。
List<String> rejectedEventIdsFromInsert(Object? raw) {
  if (raw is! Map) {
    return const [];
  }
  final ids = raw['rejected_event_ids'];
  if (ids is! List) {
    return const [];
  }
  return [for (final id in ids) id.toString()];
}
