import json
import unittest
from pathlib import Path

from pypdf import PdfReader

from render import bar_points, render_pdf
from slack_post import post_pdf


class ReportPdfTest(unittest.TestCase):
    def test_missing_metrics_are_not_drawn_as_zero(self):
        self.assertIsNone(bar_points([("インストール", None), ("アンインストール", None)]))
        self.assertEqual(bar_points([("新規DL", 0), ("再DL", None)]), [("新規DL", 0)])

    def test_pdf_says_data_missing_and_not_a_zero_install(self):
        payload = {
            "lines": [
                "📊 カロナビ日次レポート｜10/15 16:00〜10/16 16:00（日本時間）",
                "インストール データなし",
                "転換率 データなし（ページ閲覧→新規DL / 前日 — / 前週 —）",
            ],
            "charts": {
                "downloads": {"new": 14, "re": 2},
                "acquisition": {"impressions": None, "page_views": None, "new_downloads": 14},
                "first_opens": {"asa": 0, "other": 8, "unknown": 0},
                "plans": [{"label": "月額", "paid": 0}],
                "crashes_by_version": None,
            },
        }
        destination = Path(__file__).with_name("_sample_test.pdf")
        render_pdf(payload, destination)
        text = "\n".join(page.extract_text() or "" for page in PdfReader(str(destination)).pages)
        self.assertIn("データなし", text)
        self.assertNotIn("インストール 0", text)
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


if __name__ == "__main__":
    unittest.main()
