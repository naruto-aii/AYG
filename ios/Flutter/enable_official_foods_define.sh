#!/bin/sh
# Source this from the Xcode Flutter build phase. It appends
# officialFoodsEnabled=true to DART_DEFINES for Debug, Profile,
# and Release (Archive). Other defines are kept.

official="${OFFICIAL_FOODS_DART_DEFINE:-b2ZmaWNpYWxGb29kc0VuYWJsZWQ9dHJ1ZQ==}"
defines=""
old_ifs=$IFS
IFS=,
for part in ${DART_DEFINES:-}; do
  if [ -z "$part" ]; then
    continue
  fi
  if [ -z "$defines" ]; then
    defines="$part"
  else
    defines="${defines},${part}"
  fi
done
IFS=$old_ifs

case ",${defines}," in
  *",${official},"*) ;;
  *)
    if [ -n "$defines" ]; then
      defines="${defines},${official}"
    else
      defines="$official"
    fi
    ;;
esac

export DART_DEFINES="$defines"

# Google ログインの設定が壊れた Release ビルドを作らない。
. "${SRCROOT:-ios}/Flutter/check_google_signin.sh"
