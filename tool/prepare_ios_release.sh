#!/bin/sh
# Archive の前に1回だけ実行する。
#   1. tool/dart_defines.local.json の値を確かめる（値は表示しない）
#   2. Google ログイン用の URL スキーム（GoogleSignIn.generated.xcconfig）を作る
#   3. flutter build ios --config-only で Generated.xcconfig を作る
# この後 Xcode で Product → Archive。

set -eu

ROOT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
cd "$ROOT_DIR"
LOCAL_DEFINES="tool/dart_defines.local.json"

if [ ! -f "$LOCAL_DEFINES" ]; then
  echo "error: $LOCAL_DEFINES がありません。dart_defines.local.json.example をコピーして値を入れてください。" >&2
  exit 1
fi

python3 - "$LOCAL_DEFINES" <<'PY'
import json, re, sys
try:
    data = json.load(open(sys.argv[1], encoding="utf-8"))
except Exception:
    sys.exit("error: dart_defines.local.json が JSON として読めません")
pat = re.compile(r"^([0-9]+)-[0-9a-z]+\.apps\.googleusercontent\.com$")
bad = []
for key in ("SUPABASE_URL", "SUPABASE_ANON_KEY"):
    v = data.get(key)
    if not isinstance(v, str) or not v.strip() or "YOUR_" in v:
        bad.append(f"{key}: 空か見本のまま")
url = str(data.get("SUPABASE_URL", ""))
if url and not url.startswith("https://"):
    bad.append("SUPABASE_URL: https:// で始まっていない")
if url.rstrip("/").endswith("/rest/v1"):
    bad.append("SUPABASE_URL: 末尾の /rest/v1/ を消してください")
web = str(data.get("GOOGLE_WEB_CLIENT_ID", "")).strip()
ios = str(data.get("GOOGLE_IOS_CLIENT_ID", "")).strip()
mw, mi = pat.match(web), pat.match(ios)
if not mw:
    bad.append("GOOGLE_WEB_CLIENT_ID: Web クライアントの「クライアント ID」(数字-英数字.apps.googleusercontent.com) ではない")
if not mi:
    bad.append("GOOGLE_IOS_CLIENT_ID: iOS クライアントの「クライアント ID」(数字-英数字.apps.googleusercontent.com) ではない（バンドル ID や com.googleusercontent.apps.… は不可）")
if mw and mi and mw.group(1) != mi.group(1):
    bad.append("GOOGLE_IOS_CLIENT_ID と GOOGLE_WEB_CLIENT_ID が別の Google Cloud プロジェクト（先頭の数字が違う）。同じプロジェクトの iOS と Web を使ってください")
if mw and mi and web == ios:
    bad.append("GOOGLE_IOS_CLIENT_ID と GOOGLE_WEB_CLIENT_ID が同じ値")
if bad:
    print("error: tool/dart_defines.local.json を直してください:", file=sys.stderr)
    for b in bad:
        print("  - " + b, file=sys.stderr)
    sys.exit(1)
print("OK: dart_defines.local.json")
PY

sh tool/configure_google_signin_ios.sh
flutter build ios --config-only --release \
  --dart-define-from-file="$LOCAL_DEFINES" --dart-define=officialFoodsEnabled=true

GEN="ios/Flutter/Generated.xcconfig"
echo "---- 確認 ----"
grep FLUTTER_BUILD_NAME "$GEN"
grep FLUTTER_BUILD_NUMBER "$GEN"
if grep -q '^DART_DEFINES=' "$GEN"; then echo "DART_DEFINES: OK"; else echo "error: DART_DEFINES がありません" >&2; exit 1; fi
if grep -q '^GOOGLE_REVERSED_CLIENT_ID=com\.googleusercontent\.apps\.' ios/Flutter/GoogleSignIn.generated.xcconfig; then
  echo "Google URL スキーム: OK"
else
  echo "error: Google URL スキームが作られていません" >&2
  exit 1
fi
echo "準備完了。open ios/Runner.xcworkspace → Any iOS Device → Product → Archive"
