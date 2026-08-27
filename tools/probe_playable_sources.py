"""Probe curated streams: playlist/file status, and first HLS segment when present."""
from __future__ import annotations

import json
import subprocess
from collections import Counter, defaultdict
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path
from urllib.parse import urljoin, urlparse

from stream_content import UA

ROOT = Path(__file__).resolve().parents[1]
STATIONS_FILE = ROOT / "assets" / "stations_cn.json"
OK_CODES = {"200", "206"}


def curl_code(url: str) -> str:
    if not url:
        return "EMPTY"
    try:
        result = subprocess.run(
            [
                "curl.exe",
                "-sL",
                "-o",
                "NUL",
                "-w",
                "%{http_code}",
                "--max-time",
                "10",
                "-A",
                UA,
                url,
            ],
            capture_output=True,
            timeout=14,
        )
        code = (result.stdout or b"").decode("ascii", errors="ignore").strip()
        return code or "ERR"
    except Exception:
        return "ERR"


def curl_text(url: str, max_bytes: int = 8192) -> str:
    try:
        result = subprocess.run(
            [
                "curl.exe",
                "-sL",
                "--max-time",
                "10",
                "-A",
                UA,
                "--max-filesize",
                str(max_bytes),
                url,
            ],
            capture_output=True,
            timeout=14,
        )
        return (result.stdout or b"").decode("utf-8", errors="replace")
    except Exception:
        return ""


def first_hls_segment(playlist_url: str, body: str) -> str | None:
    for line in body.splitlines():
        text = line.strip()
        if not text or text.startswith("#"):
            continue
        return urljoin(playlist_url, text)
    return None


def host_family(host: str) -> str:
    host = host.lower()
    if host.endswith("cnr.cn") or host.endswith("radio.cn"):
        return "cnr"
    if "qingting.fm" in host or "qtfm.cn" in host:
        return "qingting"
    if host.endswith("cri.cn"):
        return "cri"
    if "xmcdn.com" in host or "ximalaya.com" in host:
        return "ximalaya-cdn"
    if "vojs.cn" in host:
        return "vojs"
    if "rbc.cn" in host:
        return "brtv"
    return host or "unknown"


def probe(item: dict) -> dict:
    url = str(item.get("url") or "").strip()
    parsed = urlparse(url)
    host = parsed.netloc.lower()
    path = parsed.path.lower()
    kind = "m3u8" if ".m3u8" in path else ("mp3" if ".mp3" in path else "other")
    playlist_code = curl_code(url)
    body = curl_text(url, 8192) if kind == "m3u8" and playlist_code in OK_CODES else ""
    segment_url = ""
    segment_code = ""
    playlist_looks_hls = "#EXTM3U" in body
    if kind == "m3u8" and playlist_code in OK_CODES:
        segment_url = first_hls_segment(url, body) or ""
        if segment_url:
            segment_code = curl_code(segment_url)
        else:
            segment_code = "NOSEG"
    playlist_ok = playlist_code in OK_CODES
    segment_ok = (not segment_code) or segment_code in OK_CODES
    return {
        "id": str(item.get("id") or ""),
        "name": str(item.get("name") or ""),
        "url": url,
        "host": host,
        "family": host_family(host),
        "kind": kind,
        "playlist_code": playlist_code,
        "segment_code": segment_code,
        "segment_url": segment_url,
        "hls": playlist_looks_hls,
        "playlist_ok": playlist_ok,
        "playable": playlist_ok and segment_ok,
        "false_live": playlist_ok and bool(segment_code) and segment_code not in OK_CODES,
    }


def main() -> None:
    stations = json.loads(STATIONS_FILE.read_text(encoding="utf-8"))
    rows: list[dict] = []
    with ThreadPoolExecutor(max_workers=16) as pool:
        futures = [pool.submit(probe, item) for item in stations]
        for i, future in enumerate(as_completed(futures), start=1):
            rows.append(future.result())
            if i % 40 == 0:
                print(f"progress {i}/{len(stations)}", flush=True)

    playable = [r for r in rows if r["playable"]]
    dead = [r for r in rows if not r["playlist_ok"]]
    false_live = [r for r in rows if r["false_live"]]
    hls = [r for r in rows if r["kind"] == "m3u8" and r["playlist_ok"]]

    print(f"total\t{len(rows)}")
    print(f"playlist_ok\t{sum(1 for r in rows if r['playlist_ok'])}")
    print(f"playable\t{len(playable)}")
    print(f"dead_playlist\t{len(dead)}")
    print(f"false_live\t{len(false_live)}")
    print(f"hls_playlist_ok\t{len(hls)}")

    print("\n--- family playlist_ok / playable / false_live / dead ---")
    families = sorted({r["family"] for r in rows})
    for family in families:
        group = [r for r in rows if r["family"] == family]
        print(
            f"{len(group):3}  {family:20}  "
            f"ok={sum(1 for r in group if r['playlist_ok']):3}  "
            f"playable={sum(1 for r in group if r['playable']):3}  "
            f"false={sum(1 for r in group if r['false_live']):3}  "
            f"dead={sum(1 for r in group if not r['playlist_ok']):3}"
        )

    print("\n--- false live (playlist 200, segment fail) ---")
    for row in sorted(false_live, key=lambda r: (r["family"], r["name"])):
        print(
            f"{row['playlist_code']}/{row['segment_code']}\t"
            f"{row['family']}\t{row['name']}\t{row['id']}\t{row['url']}"
        )

    print("\n--- dead playlist ---")
    by_code: dict[str, list[dict]] = defaultdict(list)
    for row in dead:
        by_code[row["playlist_code"]].append(row)
    for code, group in sorted(by_code.items(), key=lambda item: (-len(item[1]), item[0])):
        print(f"[{code} x{len(group)}]")
        for row in sorted(group, key=lambda r: r["name"])[:12]:
            print(f"  {row['family']}\t{row['name']}\t{row['id']}\t{row['url']}")
        if len(group) > 12:
            print(f"  ... {len(group) - 12} more")

    kind_ok = Counter()
    kind_all = Counter()
    for row in rows:
        kind_all[row["kind"]] += 1
        if row["playable"]:
            kind_ok[row["kind"]] += 1
    print("\n--- format playable/total ---")
    for kind, total in kind_all.items():
        print(f"{kind}\t{kind_ok[kind]}/{total}")


if __name__ == "__main__":
    main()
