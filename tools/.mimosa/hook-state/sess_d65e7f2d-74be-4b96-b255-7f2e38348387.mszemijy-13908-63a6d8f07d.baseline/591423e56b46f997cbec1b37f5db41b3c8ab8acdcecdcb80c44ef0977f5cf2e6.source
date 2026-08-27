"""Probe every stream in assets/stations_cn.json and drop the dead ones.

One-off maintenance: keeps only stations a real player would play. The probe
mimics playback (plain GET with gzip support, Range only as fallback) instead
of the app's Range-first probe, because some CDNs (qtfm) answer 404 to Range
requests while serving audio fine on a plain GET.

Dead stations are removed without replacement. Run with --apply to write the
pruned list back; without it, dry run. Safety guard: abort the write if more
than half of stations would be dropped, which usually means a probe outage.

The probe refuses non-http(s) schemes, private/loopback/link-local targets and
caps redirects, so a poisoned stations list can never reach local services.
"""

from __future__ import annotations

import argparse
import gzip
import ipaddress
import json
import socket
import urllib.error
import urllib.parse
import urllib.request
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path

from stream_content import (
    UA,
    PREVIEW_MAX_BYTES,
    evaluate,
    looks_like_hls,
    playback_referer,
)

ROOT = Path(__file__).resolve().parents[1]
STATIONS_FILE = ROOT / "assets" / "stations_cn.json"
MAX_REDIRECTS = 8


def _target_blocked(url: str) -> str | None:
    parsed = urllib.parse.urlparse(url)
    if parsed.scheme not in ("http", "https"):
        return f"非法协议 {parsed.scheme}"
    host = parsed.hostname
    if not host:
        return "地址缺少主机名"
    try:
        infos = socket.getaddrinfo(host, parsed.port or (443 if parsed.scheme == "https" else 80))
    except OSError as error:
        return f"域名解析失败: {error}"
    for info in infos:
        ip = ipaddress.ip_address(info[4][0])
        if (
            ip.is_private
            or ip.is_loopback
            or ip.is_link_local
            or ip.is_multicast
            or ip.is_reserved
            or ip.is_unspecified
        ):
            return f"目标指向非公网地址 {ip}"
    return None


class _NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, request, fp, code, msg, headers, newurl):
        return None


def _fetch(url: str, timeout: int, headers: dict) -> tuple[int | None, str, bytes, str]:
    current = url
    opener = urllib.request.build_opener(_NoRedirect)
    for _ in range(MAX_REDIRECTS + 1):
        blocked = _target_blocked(current)
        if blocked:
            return None, "", b"", blocked
        request = urllib.request.Request(current, headers=headers)
        try:
            response = opener.open(request, timeout=timeout)
        except urllib.error.HTTPError as error:
            # _NoRedirect makes urllib raise for 3xx instead of following;
            # follow the Location ourselves so redirect targets are validated.
            if error.code in (301, 302, 303, 307, 308):
                location = error.headers.get("Location")
                if location:
                    current = urllib.parse.urljoin(current, location)
                    continue
            return error.code, "", b"", f"HTTP {error.code}"
        except Exception as error:
            return None, "", b"", f"连接失败: {error}"
        with response:
            status = response.status
            content_type = response.headers.get("Content-Type", "")
            encoding = response.headers.get("Content-Encoding", "")
            raw = response.read(PREVIEW_MAX_BYTES)
        if status in (301, 302, 303, 307, 308):
            location = response.headers.get("Location")
            if not location:
                return status, content_type, raw, f"HTTP {status}"
            current = urllib.parse.urljoin(current, location)
            continue
        if "gzip" in encoding.lower():
            try:
                raw = gzip.decompress(raw)
            except Exception:
                pass
        return status, content_type, raw, ""
    return None, "", b"", "重定向次数过多"


def _probe_url(url: str, timeout: int, range_header: bool) -> tuple[bool, str]:
    headers = {"User-Agent": UA, "Accept-Encoding": "gzip"}
    referer = playback_referer(url)
    if referer:
        headers["Referer"] = referer
    if range_header:
        headers["Range"] = f"bytes=0-{PREVIEW_MAX_BYTES - 1}"
    status, content_type, raw, error = _fetch(url, timeout, headers)
    if error:
        return False, error
    preview = raw.decode("latin1", "replace")[:PREVIEW_MAX_BYTES]
    return evaluate(
        url=url, status_code=status, content_type=content_type, preview=preview
    )


def probe_playable(url: str, timeout: int = 12) -> tuple[bool, str]:
    """Plain GET first (like a real player), Range only as fallback."""
    ok, message = _probe_url(url, timeout, range_header=False)
    if not ok:
        ok, message = _probe_url(url, timeout, range_header=False)
    if not ok and not looks_like_hls(url):
        ok, message = _probe_url(url, timeout, range_header=True)
    return ok, message


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--apply",
        action="store_true",
        help="write the pruned list back to stations_cn.json",
    )
    args = parser.parse_args()

    stations: list[dict] = json.loads(STATIONS_FILE.read_text(encoding="utf-8"))

    def probe_with_retry(item: dict) -> tuple[bool, str]:
        return probe_playable(str(item.get("url") or ""))

    rows: list[tuple[dict, bool, str]] = []
    with ThreadPoolExecutor(max_workers=16) as pool:
        futures = {pool.submit(probe_with_retry, item): item for item in stations}
        done = 0
        for future in as_completed(futures):
            item = futures[future]
            ok, message = future.result()
            rows.append((item, ok, message))
            done += 1
            if done % 40 == 0:
                print(f"progress {done}/{len(stations)}", flush=True)

    by_id = {str(item.get("id") or ""): (ok, message) for item, ok, message in rows}
    dead = [
        (item, by_id[str(item.get("id") or "")][1])
        for item in stations
        if not by_id[str(item.get("id") or "")][0]
    ]
    kept = [item for item in stations if by_id[str(item.get("id") or "")][0]]

    print(f"\ntotal\t{len(stations)}")
    print(f"playable\t{len(kept)}")
    print(f"dead\t{len(dead)}")
    print("\n--- dead ---")
    for item, message in sorted(
        dead, key=lambda row: (row[0].get("name") or "", row[0].get("id") or "")
    ):
        print(f"{message}\t{item.get('name')}\t{item.get('id')}\t{item.get('url')}")

    if not args.apply:
        print("\n(dry run; pass --apply to prune stations_cn.json)")
        return 0

    if len(kept) < max(40, len(stations) // 2):
        print("abort write: too many stations would be dropped (possible probe outage)")
        return 2

    STATIONS_FILE.write_text(
        json.dumps(kept, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    print(f"\nwrote {STATIONS_FILE} ({len(kept)} stations)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
