"""投稿待ちの集計を関数から読み、PDF を作って Slack に出す。データベースへはつながない。"""

from __future__ import annotations

import json
import os
import sys
import tempfile
import urllib.request
from pathlib import Path

from render import render_pdf
from slack_post import post_pdf


def main() -> int:
    function_url = os.environ.get("DAILY_REPORT_FUNCTION_URL", "").strip()
    secret = os.environ.get("DAILY_REPORT_READ_SECRET", "").strip()
    token = os.environ.get("SLACK_DAILY_REPORT_BOT_TOKEN", "").strip()
    channel_id = os.environ.get("SLACK_DAILY_REPORT_CHANNEL_ID", "").strip()
    if not function_url or not secret or not token or not channel_id:
        print("daily-report pdf: settings are missing", file=sys.stderr)
        return 2
    only = os.environ.get("DAILY_REPORT_DATA_DATE", "").strip()
    listed = call_function(function_url, secret, {"op": "outbox"})
    rows = listed.get("rows") if isinstance(listed.get("rows"), list) else []
    posted = 0
    for row in rows:
        if not isinstance(row, dict):
            continue
        data_date = str(row.get("data_date", ""))[:10]
        if only and data_date != only:
            continue
        payload = row.get("payload")
        if not isinstance(payload, dict):
            print(f"daily-report pdf: skip {data_date}", file=sys.stderr)
            continue
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / f"calonavi-daily-{data_date}.pdf"
            render_pdf(payload, path)
            try:
                post_pdf(
                    token=token,
                    channel_id=channel_id,
                    filename=path.name,
                    pdf=path.read_bytes(),
                    comment=str(row.get("slack_text", "")),
                )
            except Exception:
                call_function(function_url, secret, {"op": "finish", "data_date": data_date, "status": "failed"})
                print(f"daily-report pdf: failed {data_date}", file=sys.stderr)
                return 1
        finished = call_function(function_url, secret, {"op": "finish", "data_date": data_date, "status": "posted"})
        if finished.get("ok") is not True:
            print(f"daily-report pdf: finish skipped {data_date}", file=sys.stderr)
            return 1
        posted += 1
    print(f"daily-report pdf: posted {posted}")
    return 0


def call_function(url: str, secret: str, body: dict, http=None) -> dict:
    data = json.dumps(body).encode()
    headers = {
        "content-type": "application/json",
        "x-daily-report-secret": secret,
    }
    if http is not None:
        status, payload = http("POST", url, headers, data)
    else:
        request = urllib.request.Request(url, data=data, headers=headers, method="POST")
        with urllib.request.urlopen(request, timeout=60) as response:
            status = response.status
            payload = json.loads(response.read().decode() or "{}")
    if status >= 300 or not isinstance(payload, dict):
        raise RuntimeError(f"daily-report function status {status}")
    return payload


if __name__ == "__main__":
    raise SystemExit(main())
