"""投稿待ちの集計を読み、PDF を作って Slack に出す。表の中身は変えない。"""

from __future__ import annotations

import os
import sys
import tempfile
from pathlib import Path

import psycopg

from render import render_pdf
from slack_post import post_pdf


def main() -> int:
    database_url = os.environ.get("DAILY_REPORT_DB_URL", "").strip()
    token = os.environ.get("SLACK_DAILY_REPORT_BOT_TOKEN", "").strip()
    channel_id = os.environ.get("SLACK_DAILY_REPORT_CHANNEL_ID", "").strip()
    if not database_url or not token or not channel_id:
        print("daily-report pdf: settings are missing", file=sys.stderr)
        return 2
    only = os.environ.get("DAILY_REPORT_DATA_DATE", "").strip()
    with psycopg.connect(database_url) as connection:
        with connection.cursor() as cursor:
            cursor.execute("select data_date::text, content_hash, slack_text, payload from kpi.daily_report_outbox()")
            rows = cursor.fetchall()
        posted = 0
        for data_date, content_hash, slack_text, payload in rows:
            if only and data_date != only:
                continue
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
                        comment=str(slack_text),
                    )
                except Exception:
                    _finish(connection, data_date, "failed")
                    print(f"daily-report pdf: failed {data_date}", file=sys.stderr)
                    return 1
            if not _finish(connection, data_date, "posted"):
                print(f"daily-report pdf: finish skipped {data_date} {content_hash}", file=sys.stderr)
                return 1
            posted += 1
    print(f"daily-report pdf: posted {posted}")
    return 0


def _finish(connection, data_date: str, status: str) -> bool:
    with connection.cursor() as cursor:
        cursor.execute(
            "select kpi.finish_daily_report_delivery(%s::date, %s)",
            (data_date, status),
        )
        row = cursor.fetchone()
    connection.commit()
    return bool(row and row[0])


if __name__ == "__main__":
    raise SystemExit(main())
