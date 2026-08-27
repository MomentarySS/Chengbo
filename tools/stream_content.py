"""Match lib/core/network/stream_content.dart StreamContentLogic.evaluate."""

from __future__ import annotations

import re
import subprocess
from pathlib import Path
from urllib.parse import urlparse


def _user_agent() -> str:
    pubspec = Path(__file__).resolve().parents[1] / "pubspec.yaml"
    version = "0.0.0"
    try:
        for line in pubspec.read_text(encoding="utf-8").splitlines():
            if line.startswith("version:"):
                version = line.split(":", 1)[1].strip().split("+", 1)[0]
                break
    except OSError:
        pass
    return f"Chengbo/{version} (Flutter; chengbo radio)"


UA = _user_agent()
PREVIEW_MAX_BYTES = 2048
TOKEN_RE = re.compile(r"[?&](t|token|key|auth|sign|timestamp)=", re.I)


def looks_like_hls(url: str) -> bool:
    path = url.split("?", 1)[0].lower()
    return ".m3u8" in path


def is_token_url(url: str) -> bool:
    return bool(TOKEN_RE.search(url))


def playback_referer(url: str) -> str | None:
    host = (urlparse(url).hostname or "").lower()
    if host == "cnr.cn" or host.endswith(".cnr.cn") or host == "radio.cn" or host.endswith(".radio.cn"):
        return "https://www.cnr.cn/"
    return None


def evaluate(*, url: str, status_code: int | None, content_type: str | None, preview: str) -> tuple[bool, str]:
    if status_code not in {200, 206}:
        return False, f"HTTP {status_code if status_code is not None else '无响应'}"

    ctype = (content_type or "").lower()
    text = preview.lstrip()
    if "json" in ctype or text.startswith("{") or text.startswith("["):
        return False, "不是直播流（返回了 JSON）"
    if "text/html" in ctype or _looks_like_html(text):
        return False, "不是直播流（返回了网页）"

    hls = looks_like_hls(url) or "#EXTM3U" in text
    if hls:
        if "#EXTM3U" not in text:
            return False, "不是有效的 HLS 播放列表"
        if not _has_playlist_entry(text):
            return False, "播放列表没有可播地址"
    return True, f"连接正常 (HTTP {status_code})"


def _looks_like_html(text: str) -> bool:
    head = text.lower()
    return (
        head.startswith("<!doctype html")
        or head.startswith("<html")
        or ("<html" in head and "<head" in head)
    )


def _has_playlist_entry(playlist: str) -> bool:
    for line in playlist.splitlines():
        item = line.strip()
        if item and not item.startswith("#"):
            return True
    return False


def probe_url(url: str, timeout: int = 12) -> tuple[bool, str]:
    url = (url or "").strip()
    if not url:
        return False, "请输入流地址"
    if not url.startswith("http://") and not url.startswith("https://"):
        return False, "地址需以 http:// 或 https:// 开头"
    if is_token_url(url):
        return False, "短期 token 流"

    # 先按真实播放方式（普通 GET）探测：部分 CDN（蜻蜓）对 Range 请求回 404，
    # 普通 GET 却正常出音频。Range 只在普通 GET 失败时作兜底。
    hls = looks_like_hls(url)
    ok, message = _curl_probe(url, timeout=timeout, range=False)
    if not ok:
        ok, message = _curl_probe(url, timeout=timeout, range=False)
    if not ok and not hls:
        ok, message = _curl_probe(url, timeout=timeout, range=True)
    return ok, message


def _curl_probe(url: str, timeout: int, range: bool) -> tuple[bool, str]:
    cmd = [
        "curl.exe",
        "-sL",
        "--compressed",
        "--max-redirs",
        "8",
        "--max-time",
        str(timeout),
        "-A",
        UA,
        "--max-filesize",
        str(PREVIEW_MAX_BYTES),
        "-w",
        "\nCODE:%{http_code} CTYPE:%{content_type}",
    ]
    referer = playback_referer(url)
    if referer:
        cmd.extend(["-e", referer])
    if range:
        cmd.extend(["-r", f"0-{PREVIEW_MAX_BYTES - 1}"])
    cmd.append(url)

    try:
        result = subprocess.run(cmd, capture_output=True, timeout=timeout + 6)
    except Exception as error:
        return False, f"连接失败: {error}"

    raw = (result.stdout or b"").decode("latin1", errors="replace")
    body, _, meta = raw.rpartition("\nCODE:")
    status_code: int | None = None
    content_type = ""
    if meta:
        parts = meta.strip().split(" CTYPE:", 1)
        try:
            status_code = int(parts[0].strip())
        except ValueError:
            status_code = None
        content_type = parts[1].strip() if len(parts) > 1 else ""
    preview = body[:PREVIEW_MAX_BYTES]
    return evaluate(url=url, status_code=status_code, content_type=content_type, preview=preview)
