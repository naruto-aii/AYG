/// この取得が、まだ手元へ書いてよいか。
///
/// 再試行やログアウトで世代が変わったあとは false。
/// 判定は「1つ進んだとき」ではなく、渡した世代と今の世代が一致しないとき。
typedef LocalWriteGuard = bool Function();

/// ガードが無い呼び出し（画面からの保存や、世代を持たないテスト）は書く。
bool localWriteAllowed(LocalWriteGuard? guard) => guard?.call() ?? true;
