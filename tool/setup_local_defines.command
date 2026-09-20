#!/bin/bash
# Double-click on Mac. Creates tool/dart_defines.local.json if missing, then opens it.
set -eu
cd "$(dirname "$0")/.."
DEST="tool/dart_defines.local.json"

if [ ! -f "$DEST" ]; then
  cat > "$DEST" <<'EOF'
{
  "SUPABASE_URL": "https://vdzzuoqsymetlejcnkeb.supabase.co",
  "SUPABASE_ANON_KEY": "PASTE_ANON_KEY_HERE",
  "GOOGLE_WEB_CLIENT_ID": "PASTE_WEB_CLIENT_ID.apps.googleusercontent.com",
  "GOOGLE_IOS_CLIENT_ID": "PASTE_IOS_CLIENT_ID.apps.googleusercontent.com",
  "OFF_CONTACT_EMAIL": "calonavi.ayg.support@gmail.com",
  "SUPPORT_EMAIL": "calonavi.ayg.support@gmail.com"
}
EOF
fi

open -e "$DEST"
echo "Opened $DEST in TextEdit. Fill the three PASTE_ fields, save, then close."
