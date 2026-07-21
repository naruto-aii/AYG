#!/bin/sh
# Configure iOS Google Sign-In URL scheme and run Flutter on a device/simulator.
#
# Preferred: create tool/dart_defines.local.json from dart_defines.local.json.example
# Or export env vars: SUPABASE_URL, SUPABASE_ANON_KEY, GOOGLE_WEB_CLIENT_ID,
# GOOGLE_IOS_CLIENT_ID, OFF_CONTACT_EMAIL

set -eu

ROOT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
cd "$ROOT_DIR"
LOCAL_DEFINES="${ROOT_DIR}/tool/dart_defines.local.json"

chmod +x "${ROOT_DIR}/tool/configure_google_signin_ios.sh"
"${ROOT_DIR}/tool/configure_google_signin_ios.sh"

if [ -f "$LOCAL_DEFINES" ]; then
  exec flutter run "$@" --dart-define-from-file="$LOCAL_DEFINES"
fi

if [ -z "${SUPABASE_URL:-}" ] || [ -z "${SUPABASE_ANON_KEY:-}" ] || \
   [ -z "${GOOGLE_WEB_CLIENT_ID:-}" ] || [ -z "${GOOGLE_IOS_CLIENT_ID:-}" ]; then
  echo "error: tool/dart_defines.local.json not found and required env vars are missing." >&2
  echo "Copy tool/dart_defines.local.json.example to tool/dart_defines.local.json and fill values." >&2
  exit 1
fi

DART_DEFINES=(
  "--dart-define=SUPABASE_URL=${SUPABASE_URL}"
  "--dart-define=SUPABASE_ANON_KEY=${SUPABASE_ANON_KEY}"
  "--dart-define=GOOGLE_WEB_CLIENT_ID=${GOOGLE_WEB_CLIENT_ID}"
  "--dart-define=GOOGLE_IOS_CLIENT_ID=${GOOGLE_IOS_CLIENT_ID}"
)

if [ -n "${OFF_CONTACT_EMAIL:-}" ]; then
  DART_DEFINES+=("--dart-define=OFF_CONTACT_EMAIL=${OFF_CONTACT_EMAIL}")
fi

exec flutter run "$@" "${DART_DEFINES[@]}"
