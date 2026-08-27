"""Import RadioTune.fm-style stations (Radio Browser CN/TW/HK/MO).

https://www.radiotune.fm/zh-dj/ lists Greater China stations via Radio Browser.
Skip spam (Tick Tock, Whisperings, Linn, etc.) and token URLs. Keep 200/206 only.
"""

from __future__ import annotations

import json
import re
import subprocess
import urllib.parse
import urllib.request
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path

from stream_content import UA

ROOT = Path(__file__).resolve().parents[1]
STATIONS_FILE = ROOT / "assets" / "stations_cn.json"
HEADERS = {"User-Agent": UA}
MIRRORS = [
    "https://de1.api.radio-browser.info",
    "https://fi1.api.radio-browser.info",
    "https://nl1.api.radio-browser.info",
]
TOKEN_RE = re.compile(r"[?&](t|token|key|auth|sign|timestamp)=", re.I)
JUNK = (
    "tick tock", "ticktock", "whisperings", "linn jazz", "linn radio", "linn classical",
    "radio islam", "hard rock", "metal hammer", "wqxr", "wefunk", "raggakings",
    "capital disko", "radio lbm", "radio lantau", "imc broadcasting", "axr hong",
    "big heart", "bridge classic", "恐怖", "hongkong latino", "hongkonger",
    "ia music", "spg fm", "kiss china", "voa ", "digital radio hong kong",
    "la french radio", "bigbigmix", "classical fm",
)


def fetch_json(url: str) -> list:
    req = urllib.request.Request(url, headers=HEADERS)
    with urllib.request.urlopen(req, timeout=25) as resp:
        data = json.loads(resp.read().decode("utf-8"))
    return data if isinstance(data, list) else []


def fetch_country(code: str, limit: int = 200) -> list[dict]:
    qs = urllib.parse.urlencode(
        {
            "countrycode": code,
            "hidebroken": "true",
            "order": "votes",
            "reverse": "true",
            "limit": str(limit),
        }
    )
    last_error: Exception | None = None
    for mirror in MIRRORS:
        try:
            return fetch_json(f"{mirror}/json/stations/search?{qs}")
        except Exception as exc:
            last_error = exc
    raise RuntimeError(f"Radio Browser failed for {code}: {last_error}")


def normalize_name(name: str) -> str:
    n = re.sub(r"\s+", "", name)
    n = re.sub(r"FM[\d.]+", "", n, flags=re.I)
    n = re.sub(r"AM\d+", "", n, flags=re.I)
    n = n.replace("·", "").replace("(", "").replace(")", "")
    n = n.replace("电台", "").replace("广播", "").replace("電臺", "").replace("廣播", "")
    return n.lower()


def is_junk(name: str) -> bool:
    lowered = name.lower()
    return any(k in lowered for k in JUNK)


def stream_of(item: dict) -> str:
    url = (item.get("url_resolved") or item.get("url") or "").strip()
    return url.split("#", 1)[0]


def test_url(url: str) -> tuple[str, str]:
    try:
        result = subprocess.run(
            ["curl.exe", "-sL", "-o", "NUL", "-w", "%{http_code}", "--max-time", "10", url],
            capture_output=True,
            text=True,
            timeout=15,
        )
        return url, result.stdout.strip()
    except Exception:
        return url, "ERR"


def infer_tags(name: str, country: str) -> list[str]:
    tags = ["地方台"]
    region = {
        "TW": "台湾",
        "HK": "香港",
        "MO": "澳门",
    }.get(country)
    if region:
        tags.append(region)
    else:
        mapping = {
            "北京": "北京", "上海": "上海", "广东": "广东", "广州": "广东",
            "成都": "四川", "四川": "四川", "郑州": "河南", "河南": "河南",
            "长春": "吉林", "吉林": "吉林", "广西": "广西", "南宁": "广西",
            "海南": "海南", "厦门": "福建", "福建": "福建", "南京": "江苏",
            "江苏": "江苏", "杭州": "浙江", "浙江": "浙江", "西安": "陕西",
        }
        for key, tag in mapping.items():
            if key in name:
                tags.append(tag)
                break
    if any(k in name for k in ("新闻", "新聞", "News", "资讯", "資訊")):
        tags.append("新闻")
    elif any(k in name for k in ("交通",)):
        tags.append("交通")
    elif any(k in name for k in ("音乐", "音樂", "Music", "AsiaFM", "HIT", "流行", "经典", "經典")):
        tags.append("音乐")
    elif any(k in name for k in ("财经", "財經", "经济", "經濟", "Finance", "财富")):
        tags.append("财经")
    else:
        tags.append("综合")
    seen: set[str] = set()
    out: list[str] = []
    for tag in tags:
        if tag not in seen:
            seen.add(tag)
            out.append(tag)
    return out


def infer_category(tags: list[str]) -> str:
    if "音乐" in tags:
        return "音乐"
    return "地方台"


def display_name(item: dict) -> str:
    name = re.sub(r"\s+", " ", (item.get("name") or "").strip())
    return name


def keep_item(item: dict) -> bool:
    name = display_name(item)
    if not name or is_junk(name):
        return False
    country = (item.get("countrycode") or "").upper()
    url = stream_of(item)
    if not url.startswith("http") or TOKEN_RE.search(url):
        return False
    if country in {"TW", "HK", "MO"}:
        return True
    # Mainland: prefer Chinese names / well-known brands from RadioTune featured list.
    featured = (
        "文化休闲", "闽南", "国际旅游", "财富", "城市之声", "音乐广播",
        "新闻广播", "交通", "AsiaFM", "亚洲", "Voice of",
    )
    if any(k in name for k in featured):
        return True
    if re.search(r"[\u4e00-\u9fff]", name):
        return True
    return False


def main() -> None:
    existing = json.loads(STATIONS_FILE.read_text(encoding="utf-8"))
    existing_norm = {normalize_name(s["name"]) for s in existing}
    existing_urls = {s["url"] for s in existing}

    raw: list[dict] = []
    for code, limit in (("CN", 150), ("TW", 120), ("HK", 80), ("MO", 40)):
        batch = fetch_country(code, limit=limit)
        print(f"{code}: {len(batch)}")
        raw.extend(batch)

    candidates: list[tuple[str, str, str]] = []  # name, url, country
    seen_norm: set[str] = set()
    for item in raw:
        if not keep_item(item):
            continue
        name = display_name(item)
        url = stream_of(item)
        key = normalize_name(name)
        if key in existing_norm or key in seen_norm or url in existing_urls:
            continue
        seen_norm.add(key)
        candidates.append((name, url, (item.get("countrycode") or "CN").upper()))

    print(f"candidates after filter: {len(candidates)}")
    unique_urls = list(dict.fromkeys(url for _, url, _ in candidates))
    url_status: dict[str, str] = {}
    with ThreadPoolExecutor(max_workers=14) as pool:
        futures = {pool.submit(test_url, url): url for url in unique_urls}
        done = 0
        for fut in as_completed(futures):
            url, code = fut.result()
            url_status[url] = code
            done += 1
            if done % 30 == 0:
                print(f"  tested {done}/{len(unique_urls)}")

    added: list[dict] = []
    start = 1
    for name, url, country in candidates:
        if url_status.get(url) not in {"200", "206"}:
            continue
        tags = infer_tags(name, country)
        added.append(
            {
                "id": f"rt-{start:03d}",
                "name": name,
                "url": url,
                "tags": tags,
                "category": infer_category(tags),
                "bitrate": 64,
                "codec": "AAC",
                "homepage": "https://www.radiotune.fm/zh-dj/",
            }
        )
        start += 1

    insert_idx = next((i for i, s in enumerate(existing) if s["id"] == "music-1"), len(existing))
    # put after existing ext-* block, still before music-1
    merged = existing[:insert_idx] + added + existing[insert_idx:]
    STATIONS_FILE.write_text(json.dumps(merged, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    report = {
        "tested": len(unique_urls),
        "added": len(added),
        "total": len(merged),
        "status_summary": {
            code: sum(1 for v in url_status.values() if v == code)
            for code in sorted(set(url_status.values()))
        },
        "names": [s["name"] for s in added],
        "by_region": {},
    }
    from collections import Counter

    report["by_region"] = dict(
        Counter(
            next((t for t in s["tags"] if t in {"台湾", "香港", "澳门"}), "内地")
            for s in added
        )
    )
    path = ROOT / "tools" / "radiotune_import_report.json"
    path.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps({k: report[k] for k in ("tested", "added", "total", "status_summary", "by_region")}, ensure_ascii=False, indent=2))
    print("report", path)


if __name__ == "__main__":
    main()
