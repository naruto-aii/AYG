#!/bin/bash
# Double-click on Mac. Creates tool/dart_defines.local.json if missing, then opens it.
set -eu
cd "$(dirname "$0")/.."
DEST="tool/dart_defines.local.json"

if [ ! -f "$DEST" ]; then
  cat > "$DEST" <<'EOF'
{
  "SUPABASE_URL": "https://vdzzusqisymtejcjnikb.supabase.co",
  "SUPABASE_ANON_KEY": "PASTE_ANON_KEY_HERE",
  "GOOGLE_WEB_CLIENT_ID": "PASTE_WEB_CLIENT_ID.apps.googleusercontent.com",
  "GOOGLE_IOS_CLIENT_ID": "",
  "OFF_CONTACT_EMAIL": "calonavi.ayg.support@gmail.com",
  "SUPPORT_EMAIL": "calonavi.ayg.support@gmail.com"
}
EOF
fi

open -e "$DEST"
echo "Opened $DEST in TextEdit. Fill SUPABASE_ANON_KEY, GOOGLE_WEB_CLIENT_ID, and GOOGLE_IOS_CLIENT_ID, save, then close."
echo "GOOGLE_IOS_CLIENT_ID は Google Cloud の iOS OAuth クライアントです。空のままだと端末の Google ログインは Safari 経由になります。"
