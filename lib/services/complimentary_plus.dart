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
