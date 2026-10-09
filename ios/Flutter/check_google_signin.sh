#!/bin/sh
# Sourced from enable_official_foods_define.sh (Xcode Flutter build phase).
#
# iOS の Google Sign-In SDK は、Info.plist に逆順クライアント ID の URL スキームが
# 無い・GIDClientID と Dart 側のクライアント ID が違うと、ログインを押した瞬間に
# 例外でアプリごと落ちる（build 9 はこれで落ちた）。Release（Archive）では、
# 落ちるビルドを作る前にここで止める。
#
# 直し方: ./tool/prepare_ios_release.sh を実行してから Archive する。

google_define_value() {
  # $1 = key. DART_DEFINES は base64 のカンマ区切り。
  _key="$1"
  _old_ifs=$IFS
  IFS=,
  for _part in ${DART_DEFINES:-}; do
    [ -z "$_part" ] && continue
    _decoded="$(printf %s "$_part" | base64 --decode 2>/dev/null || true)"
    case "$_decoded" in
      "${_key}="*)
        IFS=$_old_ifs
        printf %s "${_decoded#"${_key}="}"
        return 0
        ;;
    esac
  done
  IFS=$_old_ifs
  printf ''
}

google_signin_problem() {
  _web="$(google_define_value GOOGLE_WEB_CLIENT_ID)"
  _ios="$(google_define_value GOOGLE_IOS_CLIENT_ID)"
  # Web ID が無ければ Google ボタンは失敗表示になるだけで落ちない。
  [ -z "$_web" ] && return 0
  if ! printf %s "$_ios" | grep -Eq '^[0-9]+-[0-9a-z]+\.apps\.googleusercontent\.com$'; then
    echo "GOOGLE_IOS_CLIENT_ID が Google の iOS クライアント ID の形ではありません（例: 123-abc.apps.googleusercontent.com）"
    return 0
  fi
  _expected_reversed="com.googleusercontent.apps.${_ios%.apps.googleusercontent.com}"
  if [ "${GID_CLIENT_ID:-}" != "$_ios" ] ||
    [ "${GOOGLE_REVERSED_CLIENT_ID:-}" != "$_expected_reversed" ]; then
    echo "ios/Flutter/GoogleSignIn.generated.xcconfig が無いか、GOOGLE_IOS_CLIENT_ID と合っていません（URL スキーム未設定だと Google ログインで落ちます）"
    return 0
  fi
  if [ "${GID_SERVER_CLIENT_ID:-}" != "$_web" ]; then
    echo "GoogleSignIn.generated.xcconfig の GID_SERVER_CLIENT_ID が GOOGLE_WEB_CLIENT_ID と合っていません"
    return 0
  fi
  return 0
}

if [ "${CONFIGURATION:-}" = "Release" ]; then
  _google_problem="$(google_signin_problem)"
  if [ -n "$_google_problem" ]; then
    echo "error: Google ログイン設定: ${_google_problem}" >&2
    echo "error: ./tool/prepare_ios_release.sh を実行してから、もう一度 Archive してください。" >&2
    exit 1
  fi
fi
