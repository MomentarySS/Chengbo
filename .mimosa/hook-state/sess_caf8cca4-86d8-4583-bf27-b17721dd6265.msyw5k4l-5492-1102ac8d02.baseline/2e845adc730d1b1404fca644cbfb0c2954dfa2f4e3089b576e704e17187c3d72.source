"""Probe assets/stations_cn.json with the same body rules as the app.

Replace dead URLs from Radio Browser when the GET body is a real stream.
Otherwise delete the station. Never bulk-add unverified stations.
"""

from __future__ import annotations

import argparse
import json
import urllib.parse
import urllib.request
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path

from stream_content import UA, is_token_url, probe_url

ROOT = Path(__file__).resolve().parents[1]
STATIONS_FILE = ROOT / "assets" / "stations_cn.json"
RB_MIRRORS = (
    "https://de1.api.radio-browser.info",
    "https://fi1.api.radio-browser.info",
    "https://nl1.api.radio-browser.info",
)


def radio_browser_candidates(name: str) -> list[str]:
    query = urllib.parse.urlencode(
        {
            "name": name,
            "countrycode": "CN",
            "hidebroken": "true",
            "order": "votes",
            "reverse": "true",
            "limit": "8",
        }
    )
    for mirror in RB_MIRRORS:
        req = urllib.request.Request(
            f"{mirror}/json/stations/search?{query}",
            headers={"User-Agent": UA},
        )
        try:
            with urllib.request.urlopen(req, timeout=20) as resp:
                data = json.loads(resp.read().decode("utf-8", "replace"))
        except Exception:
            continue
        urls: list[str] = []
        if not isinstance(data, list):
            return urls
        for item in data:
            if not isinstance(item, dict):
                continue
            stream = str(item.get("url_resolved") or item.get("url") or "").strip()
            if not stream or is_token_url(stream):
                continue
            if stream not in urls:
                urls.append(stream)
        return urls
    return []


def find_replacement(name: str, current: str) -> str | None:
    seen = {current}
    for url in radio_browser_candidates(name):
        if url in seen:
            continue
        seen.add(url)
        ok, _ = probe_url(url)
        if ok:
            return url
    return None


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--apply", action="store_true", help="write replacements/deletes to stations_cn.json")
    args = parser.parse_args()

    stations: list[dict] = json.loads(STATIONS_FILE.read_text(encoding="utf-8"))
    rows: list[tuple[dict, bool, str]] = []
    with ThreadPoolExecutor(max_workers=6) as pool:
        futures = {pool.submit(probe_url, str(item.get("url") or "")): item for item in stations}
        done = 0
        for future in as_completed(futures):
            item = futures[future]
            ok, message = future.result()
            if not ok:
                ok, message = probe_url(str(item.get("url") or ""))
            rows.append((item, ok, message))
            done += 1
            if done % 40 == 0:
                print(f"progress {done}/{len(stations)}", flush=True)

    by_id = {str(item.get("id") or ""): (ok, message) for item, ok, message in rows}
    live = [(item, by_id[str(item.get("id") or "")][1]) for item in stations if by_id[str(item.get("id") or "")][0]]
    dead = [(item, by_id[str(item.get("id") or "")][1]) for item in stations if not by_id[str(item.get("id") or "")][0]]
    print(f"total\t{len(stations)}")
    print(f"playable\t{len(live)}")
    print(f"dead\t{len(dead)}")

    print("\n--- dead ---")
    for item, message in dead:
        print(f"{message}\t{item.get('name')}\t{item.get('id')}\t{item.get('url')}")

    replacements: list[tuple[str, str, str]] = []
    deletions: list[tuple[str, str, str]] = []
    kept: list[dict] = []
    live_urls = {str(item.get("url") or "") for item, _ in live}

    print("\n--- replacements ---", flush=True)
    for item in stations:
        station_id = str(item.get("id") or "")
        ok, message = by_id[station_id]
        if ok:
            kept.append(item)
            continue
        name = str(item.get("name") or "")
        current = str(item.get("url") or "")
        replacement = find_replacement(name, current)
        if replacement and replacement not in live_urls:
            updated = dict(item)
            updated["url"] = replacement
            kept.append(updated)
            live_urls.add(replacement)
            replacements.append((name, current, replacement))
            print(f"replace\t{name}\t{replacement}", flush=True)
        else:
            deletions.append((station_id, name, message))
            print(f"delete\t{name}\t{message}", flush=True)
    print(f"\nkept\t{len(kept)}")
    print(f"replaced\t{len(replacements)}")
    print(f"deleted\t{len(deletions)}")

    if not args.apply:
        print("\n(dry run; pass --apply to write stations_cn.json)")
        return 0

    if len(kept) < max(40, len(stations) // 2):
        print("abort write: too many stations would be dropped (possible probe outage)")
        return 2

    STATIONS_FILE.write_text(
        json.dumps(kept, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    print(f"wrote {STATIONS_FILE}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
