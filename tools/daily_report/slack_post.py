"""Slack の外部アップロード。channel_id は呼び出し側が渡す。"""

from __future__ import annotations

import json
from typing import Callable
from urllib.error import HTTPError
from urllib.request import Request, urlopen

Http = Callable[[str, str, dict | None, bytes | None], tuple[int, dict]]


def post_pdf(
    *,
    token: str,
    channel_id: str,
    filename: str,
    pdf: bytes,
    comment: str,
    http: Http | None = None,
) -> str:
    if not token or not channel_id:
        raise ValueError("missing slack settings")
    send = http or _http
    status, meta = send(
        "POST",
        "https://slack.com/api/files.getUploadURLExternal",
        {
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/x-www-form-urlencoded",
        },
        f"filename={_form(filename)}&length={len(pdf)}".encode(),
    )
    if status != 200 or not meta.get("ok") or not meta.get("upload_url") or not meta.get("file_id"):
        raise RuntimeError("slack upload url failed")
    upload_status, _ = send("POST", str(meta["upload_url"]), {"Content-Type": "application/octet-stream"}, pdf)
    if upload_status < 200 or upload_status >= 300:
        raise RuntimeError("slack upload failed")
    done_status, done = send(
        "POST",
        "https://slack.com/api/files.completeUploadExternal",
        {
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json; charset=utf-8",
        },
        json.dumps({
            "files": [{"id": meta["file_id"], "title": filename}],
            "channel_id": channel_id,
            "initial_comment": comment,
        }).encode(),
    )
    if done_status != 200 or not done.get("ok"):
        raise RuntimeError("slack complete failed")
    return str(meta["file_id"])


def _form(value: str) -> str:
    return value.replace("%", "%25").replace("&", "%26").replace("=", "%3D").replace(" ", "%20")


def _http(method: str, url: str, headers: dict | None, body: bytes | None) -> tuple[int, dict]:
    request = Request(url, data=body, headers=headers or {}, method=method)
    try:
        with urlopen(request, timeout=60) as response:
            raw = response.read()
            status = response.status
    except HTTPError as error:
        raw = error.read()
        status = error.code
    if not raw:
        return status, {}
    try:
        parsed = json.loads(raw.decode())
    except json.JSONDecodeError:
        return status, {}
    return status, parsed if isinstance(parsed, dict) else {}
