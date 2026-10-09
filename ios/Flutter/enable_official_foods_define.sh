#!/bin/sh
# Source this from the Xcode Flutter build phase. It appends
# officialFoodsEnabled=true to DART_DEFINES for Debug, Profile,
# and Release (Archive). Other defines are kept.
#
# ./tool/run_ios.sh (flutter run) writes its defines into Generated.xcconfig,
# including the device-test purchase switch. An Xcode Archive (ACTION=install)
# reuses that file, so drop the switch there: a store build must never have it.

official="${OFFICIAL_FOODS_DART_DEFINE:-b2ZmaWNpYWxGb29kc0VuYWJsZWQ9dHJ1ZQ==}"
# Base64 of the device-test purchase define (=true and =false).
device_test_true="Q0FMT05BVklfVEVTVF9QVVJDSEFTRT10cnVl"
device_test_false="Q0FMT05BVklfVEVTVF9QVVJDSEFTRT1mYWxzZQ=="
defines=""
old_ifs=$IFS
IFS=,
for part in ${DART_DEFINES:-}; do
  if [ -z "$part" ]; then
    continue
  fi
  if [ "${ACTION:-}" = "install" ] &&
    { [ "$part" = "$device_test_true" ] || [ "$part" = "$device_test_false" ]; }; then
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
