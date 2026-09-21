#!/bin/bash
# Double-click on Mac. Rewrites tool/dart_defines.local.json into valid JSON.
set -eu
cd "$(dirname "$0")/.."
python3 tool/repair_local_defines.py tool/dart_defines.local.json
open -e tool/dart_defines.local.json
osascript -e 'display dialog "設定ファイルの形を直しました。\n\nすでに入っている値はそのままです。GOOGLE_IOS_CLIENT_ID は空で問題ありません。\n\nTextEdit で中身を見て、Command+S で保存して閉じてください。\nそのあと Terminal に戻って ./tool/run_ios.sh を実行します。" buttons {"OK"} default button "OK" with title "カロナビ 実機起動"'
