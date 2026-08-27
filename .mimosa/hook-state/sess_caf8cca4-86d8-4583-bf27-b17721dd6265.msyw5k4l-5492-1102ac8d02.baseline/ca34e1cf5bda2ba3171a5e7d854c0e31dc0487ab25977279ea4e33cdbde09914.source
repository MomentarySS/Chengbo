"""Probe every stream in assets/stations_cn.json."""
from __future__ import annotations

import json
import subprocess
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path

from stream_content import UA

ROOT = Path(__file__).resolve().parents[1]
STATIONS_FILE = ROOT / "assets" / "stations_cn.json"
OK_CODES = {"200", "206"}


def test_url(url: str) -> str:
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
            text=True,
            timeout=15,
        )
        code = (result.stdout or "").strip()
        return code or "ERR"
    except Exception:
        return "ERR"


def main() -> None:
    stations = json.loads(STATIONS_FILE.read_text(encoding="utf-8"))
    ok: list[tuple[str, str, str, str]] = []
    bad: list[tuple[str, str, str, str]] = []

    with ThreadPoolExecutor(max_workers=16) as pool:
        futures = {
            pool.submit(test_url, str(item.get("url") or "").strip()): item
            for item in stations
        }
        for future in as_completed(futures):
            item = futures[future]
            code = future.result()
            row = (
                str(item.get("id") or ""),
                str(item.get("name") or ""),
                str(item.get("url") or ""),
                code,
            )
            if code in OK_CODES:
                ok.append(row)
            else:
                bad.append(row)

    print(f"total\t{len(stations)}")
    print(f"ok\t{len(ok)}")
    print(f"fail\t{len(bad)}")
    print("--- fail ---")
    for station_id, name, url, code in sorted(bad, key=lambda row: (row[1], row[0])):
        print(f"{code}\t{name}\t{station_id}\t{url}")


if __name__ == "__main__":
    main()
