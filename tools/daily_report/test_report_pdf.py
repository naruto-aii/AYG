import json
import unittest
import warnings
from pathlib import Path

from pypdf import PdfReader

from publish import call_function
from render import bar_points, render_pdf
from slack_post import post_pdf


class ReportPdfTest(unittest.TestCase):
    def test_missing_metrics_are_not_drawn_as_zero(self):
        self.assertIsNone(bar_points([("インストール", None), ("アンインストール", None)]))
        self.assertEqual(bar_points([("新規DL", 0), ("再DL", None)]), [("新規DL", 0)])

    def test_pdf_says_data_missing_and_not_a_zero_install(self):
        payload = {
            "heading": "📊 カロナビ日次レポート｜10/15 16:00〜10/16 16:00（日本時間）",
            "summary": ["新規DL 14、再DL 2。売上は ¥0。", "詳細はPDFです。"],
            "cards": [
                {"label": "新規DL", "value": "14", "delta": "前日 —"},
                {"label": "初回起動", "value": "8", "delta": "前日 +4"},
                {"label": "初回設定完了", "value": "8", "delta": "前日 +4"},
                {"label": "初めての食事記録", "value": "2", "delta": "前日 +1"},
                {"label": "トライアル開始", "value": "0", "delta": "前日 -1"},
                {"label": "売上", "value": "¥0", "delta": "前日 —"},
            ],
            "series": [
                {
                    "label": "10/14",
                    "new_downloads": None,
                    "redownloads": None,
                    "impressions": 7,
                    "page_views": 11,
                    "conversion": None,
                    "asa": 0,
                    "other": 4,
                    "unknown": 0,
                    "first_opens": 4,
                    "onboarding": 4,
                    "meals": 1,
                    "paywall": 2,
                    "sessions": 7,
                    "duration_minutes": 352,
                },
                {
                    "label": "10/15",
                    "new_downloads": 14,
                    "redownloads": 2,
                    "impressions": None,
                    "page_views": None,
                    "conversion": None,
                    "asa": 0,
                    "other": 8,
                    "unknown": 0,
                    "first_opens": 8,
                    "onboarding": 8,
                    "meals": 2,
                    "paywall": 3,
                    "sessions": 23,
                    "duration_minutes": 317,
                },
            ],
            "table": [
                {"section": "インストール", "metric": "インストール", "today": "データなし", "day": "—", "week": "—"},
                {"section": "集客", "metric": "転換率", "today": "データなし", "day": "—", "week": "—"},
            ],
            "notes": [
                "転換率はページ閲覧から新規DLです。表示・ページ閲覧・新規DLは一つのファネルにしていません。",
            ],
        }
        destination = Path(__file__).with_name("_sample_test.pdf")
        with warnings.catch_warnings(record=True) as caught:
            warnings.simplefilter("always", UserWarning)
            render_pdf(payload, destination)
        missing = [str(item.message) for item in caught if "missing from font" in str(item.message)]
        self.assertEqual(missing, [])
        reader = PdfReader(str(destination))
        text = "\n".join(page.extract_text() or "" for page in reader.pages)
        self.assertIn("データなし", text)
        self.assertNotIn("インストール 0", text)
        self.assertEqual(text.count("一つのファネルにしていません"), 1)
        self.assertIn("初回起動", text)
        self.assertFalse(_font_subtypes(reader) & {"/Type3"})
        destination.unlink()

    def test_slack_upload_uses_external_url_and_the_given_channel(self):
        calls = []

        def http(method, url, headers, body):
            calls.append((method, url, headers, body))
            if url.endswith("getUploadURLExternal"):
                return 200, {"ok": True, "upload_url": "https://files.example/upload", "file_id": "F123"}
            if url == "https://files.example/upload":
                return 200, {}
            done = json.loads(body.decode())
            return 200, {"ok": True, "echo": done}

        file_id = post_pdf(
            token="xoxb-test",
            channel_id="C-FROM-ENV",
            filename="report.pdf",
            pdf=b"%PDF",
            comment="まとめ",
            http=http,
        )
        self.assertEqual(file_id, "F123")
        self.assertIn("files.getUploadURLExternal", calls[0][1])
        self.assertEqual(calls[1][1], "https://files.example/upload")
        completed = json.loads(calls[2][3].decode())
        self.assertEqual(completed["channel_id"], "C-FROM-ENV")
        self.assertEqual(completed["initial_comment"], "まとめ")
        self.assertEqual(completed["files"][0]["id"], "F123")
        self.assertNotIn("C0", completed["channel_id"])

    def test_read_endpoint_sends_the_secret_header_and_not_a_database_url(self):
        seen = {}

        def http(method, url, headers, body):
            seen["method"] = method
            seen["url"] = url
            seen["headers"] = headers
            seen["body"] = json.loads(body.decode())
            return 200, {"ok": True, "rows": []}

        call_function("https://example.test/functions/v1/asc-daily-report", "read-secret-for-test", {"op": "outbox"}, http)
        self.assertEqual(seen["headers"]["x-daily-report-secret"], "read-secret-for-test")
        self.assertEqual(seen["body"], {"op": "outbox"})
        self.assertNotIn("postgres", seen["url"])


def _font_subtypes(reader: PdfReader) -> set[str]:
    found: set[str] = set()
    for page in reader.pages:
        resources = page.get("/Resources")
        if resources is None:
            continue
        fonts = resources.get("/Font")
        if fonts is None:
            continue
        for font in fonts.values():
            obj = font.get_object()
            subtype = obj.get("/Subtype")
            if subtype is not None:
                found.add(str(subtype))
            descendants = obj.get("/DescendantFonts")
            if descendants is None:
                continue
            for descendant in descendants:
                kind = descendant.get_object().get("/Subtype")
                if kind is not None:
                    found.add(str(kind))
    return found


if __name__ == "__main__":
    unittest.main()
