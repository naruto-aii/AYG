/// ストアの加入と、課金ではない付与を合わせた機能の入口。
///
/// 購入の成否は [storePlus] だけを見る。付与を足しても、購入・復元の結果は変わらない。
bool calonaviPlusAccess({
  required bool storePlus,
  required bool complimentary,
}) {
  return storePlus || complimentary;
}

/// `current_complimentary_plus` の本文。true 以外は付与なし。
bool complimentaryPlusFromRpc(Object? data) {
  return data == true;
}

/// 通信失敗のあと、課金ではない付与を端末に残す時間。
///
/// これを過ぎたら付与は無しにする。ストアの加入はこの時間を見ない。
const Duration complimentaryPlusFailureTtl = Duration(minutes: 15);

/// 通信失敗（[rpc] が null）のとき、確認から [ttl] 以内だけ付与を残す。
///
/// true / false はサーバの答え。確認時刻が無い失敗は、付与を残さない。
bool complimentaryGrantAfterRefresh({
  required bool? rpc,
  required bool active,
  required DateTime? confirmedAt,
  required DateTime now,
  Duration ttl = complimentaryPlusFailureTtl,
}) {
  if (rpc != null) {
    return rpc;
  }
  if (!active || confirmedAt == null) {
    return false;
  }
  final age = now.difference(confirmedAt);
  if (age.isNegative) {
    return false;
  }
  return age <= ttl;
}
