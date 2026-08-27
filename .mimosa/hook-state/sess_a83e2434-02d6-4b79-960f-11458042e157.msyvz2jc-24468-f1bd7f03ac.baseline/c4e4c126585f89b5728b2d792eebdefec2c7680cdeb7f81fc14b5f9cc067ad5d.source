"""Collect and test Guangdong radio stream URLs."""
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
RADIO_TXT = ROOT / "tools" / "radio_gd_source.txt"

GD_KEYWORDS = (
    "广东", "广州", "深圳", "佛山", "东莞", "珠海", "惠州", "汕头", "湛江",
    "江门", "中山", "肇庆", "茂名", "韶关", "梅州", "清远", "潮州", "揭阳",
    "阳江", "河源", "汕尾", "云浮", "羊城", "南粤", "广通-",
)

# Extra candidates from qingting channel IDs / known mirrors (name -> [urls])
EXTRA_CANDIDATES: dict[str, list[str]] = {
    "潮州综合频率": [
        "http://ls.qingting.fm/live/4596.m3u8",
        "https://lhttp.qtfm.cn/live/4596/64k.mp3",
    ],
    "潮州交通音乐广播": [
        "http://ls.qingting.fm/live/4597.m3u8",
        "https://lhttp.qtfm.cn/live/4597/64k.mp3",
    ],
    "揭阳综合广播": [
        "http://ls.qingting.fm/live/4598.m3u8",
        "https://lhttp.qtfm.cn/live/4598/64k.mp3",
    ],
    "揭阳交通音乐广播": [
        "http://ls.qingting.fm/live/4599.m3u8",
        "https://lhttp.qtfm.cn/live/4599/64k.mp3",
    ],
    "汕头综合广播": [
        "http://ls.qingting.fm/live/4600.m3u8",
        "https://lhttp.qtfm.cn/live/4600/64k.mp3",
        "http://ls.qingting.fm/live/1280.m3u8",
        "https://lhttp.qtfm.cn/live/1280/64k.mp3",
    ],
    "汕头交通音乐广播": [
        "http://ls.qingting.fm/live/1281.m3u8",
        "https://lhttp.qtfm.cn/live/1281/64k.mp3",
    ],
    "肇庆综合广播": [
        "http://ls.qingting.fm/live/1284.m3u8",
        "https://lhttp.qtfm.cn/live/1284/64k.mp3",
    ],
    "肇庆交通音乐广播": [
        "http://ls.qingting.fm/live/1285.m3u8",
        "https://lhttp.qtfm.cn/live/1285/64k.mp3",
    ],
    "韶关综合广播": [
        "http://ls.qingting.fm/live/1286.m3u8",
        "https://lhttp.qtfm.cn/live/1286/64k.mp3",
    ],
    "韶关交通音乐广播": [
        "http://ls.qingting.fm/live/1287.m3u8",
        "https://lhttp.qtfm.cn/live/1287/64k.mp3",
    ],
    "茂名综合广播": [
        "http://ls.qingting.fm/live/1289.m3u8",
        "https://lhttp.qtfm.cn/live/1289/64k.mp3",
    ],
    "茂名交通音乐广播": [
        "http://ls.qingting.fm/live/1290.m3u8",
        "https://lhttp.qtfm.cn/live/1290/64k.mp3",
    ],
    "河源综合广播": [
        "http://ls.qingting.fm/live/1291.m3u8",
        "https://lhttp.qtfm.cn/live/1291/64k.mp3",
    ],
    "河源交通音乐广播": [
        "http://ls.qingting.fm/live/1292.m3u8",
        "https://lhttp.qtfm.cn/live/1292/64k.mp3",
    ],
    "汕尾综合广播": [
        "http://ls.qingting.fm/live/1293.m3u8",
        "https://lhttp.qtfm.cn/live/1293/64k.mp3",
    ],
    "汕尾交通音乐广播": [
        "http://ls.qingting.fm/live/1294.m3u8",
        "https://lhttp.qtfm.cn/live/1294/64k.mp3",
    ],
    "佛山综合广播": [
        "http://ls.qingting.fm/live/1263.m3u8",
        "https://lhttp.qtfm.cn/live/1263/64k.mp3",
    ],
    "佛山三水台": [
        "http://ls.qingting.fm/live/1264.m3u8",
        "https://lhttp.qtfm.cn/live/1264/64k.mp3",
    ],
    "佛山交通广播": [
        "http://ls.qingting.fm/live/1265.m3u8",
        "https://lhttp.qtfm.cn/live/1265/64k.mp3",
    ],
    "东莞阳光1008": [
        "http://ls.qingting.fm/live/1276.m3u8",
        "https://lhttp.qtfm.cn/live/1276/64k.mp3",
    ],
    "东莞畅享1075": [
        "http://ls.qingting.fm/live/1288.m3u8",
        "https://lhttp.qtfm.cn/live/1288/64k.mp3",
    ],
    "东莞FM104": [
        "http://ls.qingting.fm/live/93619.m3u8",
        "https://lhttp.qtfm.cn/live/93619/64k.mp3",
    ],
    "惠州交通988": [
        "http://ls.qingting.fm/live/5017.m3u8",
        "https://lhttp.qtfm.cn/live/5017/64k.mp3",
    ],
    "惠州音乐907": [
        "http://ls.qingting.fm/live/2212959.m3u8",
        "https://lhttp.qtfm.cn/live/5021523/64k.mp3",
    ],
    "珠海活力915": [
        "http://ls.qingting.fm/live/2473319.m3u8",
        "https://lhttp.qingting.fm/live/5021725/64k.mp3",
    ],
    "深圳缤纷1043": [
        "http://ls.qingting.fm/live/267.m3u8",
        "http://live.xmcdn.com/live/267/64.m3u8",
    ],
    "深圳星光991": [
        "http://ls.qingting.fm/live/28132.m3u8",
        "https://lhttp.qtfm.cn/live/28132/64k.mp3",
    ],
    "清远农村广播": [
        "http://lhttp.qingting.fm/live/15318679/64k.mp3",
    ],
    "清远交通音乐广播": [
        "http://lhttp.qingting.fm/live/20500067/64k.mp3",
    ],
    "湛江交通音乐广播": [
        "http://lhttp.qingting.fm/live/20472/64k.mp3",
    ],
    "湛江经济广播": [
        "http://lhttp.qingting.fm/live/5069/64k.mp3",
    ],
    "云浮综合广播": [
        "http://lhttp.qingting.fm/live/5022442/64k.mp3",
    ],
    "云浮交通音乐广播": [
        "http://lhttp.qingting.fm/live/5022441/64k.mp3",
    ],
    "阳江综合广播": [
        "https://live.yjtvw.com:8081/live/fm916.stream_audio/playlist.m3u8",
    ],
    "阳江旅游环保广播": [
        "https://live.yjtvw.com:8081/live/fm895.stream_audio/playlist.m3u8",
    ],
}


def fetch_radio_txt() -> None:
    url = "https://raw.githubusercontent.com/gaotianliuyun/gao/master/radio.txt"
    with urllib.request.urlopen(url, timeout=30) as resp:
        RADIO_TXT.write_bytes(resp.read())


def parse_radio_txt() -> dict[str, list[str]]:
    candidates: dict[str, list[str]] = {}
    if not RADIO_TXT.exists():
        fetch_radio_txt()
    for line in RADIO_TXT.read_text(encoding="utf-8", errors="ignore").splitlines():
        if "," not in line:
            continue
        name, url = line.split(",", 1)
        name = name.strip()
        url = url.strip()
        if not any(k in name for k in GD_KEYWORDS):
            continue
        if name.startswith("广通-"):
            name = name.replace("广通-", "")
        candidates.setdefault(name, [])
        if url not in candidates[name]:
            candidates[name].append(url)
    for name, urls in EXTRA_CANDIDATES.items():
        candidates.setdefault(name, [])
        for url in urls:
            if url not in candidates[name]:
                candidates[name].append(url)
    return candidates


def fetch_radio_browser() -> dict[str, list[str]]:
    mirrors = [
        "https://de1.api.radio-browser.info",
        "https://fi1.api.radio-browser.info",
        "https://nl1.api.radio-browser.info",
    ]
    queries = ["广东", "广州", "深圳", "佛山", "东莞", "珠海", "惠州", "汕头",
               "湛江", "江门", "中山", "肇庆", "茂名", "韶关", "梅州", "清远",
               "潮州", "揭阳", "阳江", "河源", "汕尾", "云浮"]
    candidates: dict[str, list[str]] = {}
    headers = {"User-Agent": UA}
    for mirror in mirrors:
        ok = True
        for q in queries:
            url = f"{mirror}/json/stations/search?countrycode=CN&name={urllib.parse.quote(q)}&hidebroken=true&limit=30"
            try:
                req = urllib.request.Request(url, headers=headers)
                with urllib.request.urlopen(req, timeout=20) as resp:
                    data = json.loads(resp.read().decode("utf-8"))
                for item in data:
                    name = item.get("name", "").strip()
                    stream = (item.get("url_resolved") or item.get("url") or "").strip()
                    if not name or not stream:
                        continue
                    if not any(k in name for k in GD_KEYWORDS):
                        continue
                    candidates.setdefault(name, [])
                    if stream not in candidates[name]:
                        candidates[name].append(stream)
            except Exception:
                ok = False
                break
        if ok:
            break
    return candidates


def normalize_name(name: str) -> str:
    n = re.sub(r"\s+", "", name)
    n = re.sub(r"FM[\d.]+", "", n, flags=re.I)
    n = re.sub(r"AM\d+", "", n, flags=re.I)
    n = n.replace("·", "").replace("(", "").replace(")", "")
    n = n.replace("电台", "").replace("广播", "")
    return n.lower()


def test_url(url: str) -> tuple[str, str]:
    try:
        result = subprocess.run(
            ["curl.exe", "-s", "-o", "NUL", "-w", "%{http_code}", "--max-time", "10", url],
            capture_output=True,
            text=True,
            timeout=15,
        )
        return url, result.stdout.strip()
    except Exception:
        return url, "ERR"


def pick_city(name: str) -> str | None:
    cities = ["广州", "深圳", "佛山", "东莞", "珠海", "惠州", "汕头", "湛江",
              "江门", "中山", "肇庆", "茂名", "韶关", "梅州", "清远", "潮州",
              "揭阳", "阳江", "河源", "汕尾", "云浮"]
    for c in cities:
        if c in name:
            return c
    if "广东" in name or "羊城" in name or "南粤" in name or "珠江" in name:
        return None
    return None


def infer_tags(name: str) -> list[str]:
    tags = ["地方台", "广东"]
    city = pick_city(name)
    if city:
        tags.append(city)
    if any(k in name for k in ("新闻", "先锋", "综合")):
        tags.append("新闻")
    elif any(k in name for k in ("交通", "畅行", "1075", "1062", "875")):
        tags.append("交通")
    elif any(k in name for k in ("音乐", "MYFM", "飞扬", "971", "888", "915", "104")):
        tags.append("音乐")
    elif any(k in name for k in ("经济", "珠江", "财经", "股市")):
        tags.append("财经")
    elif any(k in name for k in ("生活", "私家车")):
        tags.append("生活")
    else:
        tags.append("综合")
    return tags


def canonical_display_name(name: str) -> str:
    name = re.sub(r"\s+", " ", name).strip()
    name = name.replace("SunFM爱车", "").replace("(南粤)", "").strip()
    replacements = {
        "梅州广播电视台综合广播": "梅州新闻广播",
        "江门新闻综合台": "江门新闻综合",
        "江门旅游音乐台": "江门旅游音乐",
        "惠州新闻综合广播": "惠州新闻100",
        "惠州环保交通广播": "惠州交通988",
        "惠州经济环保广播": "惠州交通988",
        "惠州音乐广播": "惠州音乐907",
        "中山电台新锐967": "中山新锐967",
        "中山电台快乐888": "中山快乐888",
        "中山综合广播·新锐967": "中山新锐967",
        "中山环保旅游之声·快乐888": "中山快乐888",
        "珠海电台先锋951": "珠海先锋951",
        "珠海电台交通音乐875": "珠海交通音乐875",
        "珠海电台活力915": "珠海活力915",
        "珠海活力915·音乐调频": "珠海活力915",
        "深圳先锋898(新闻广播)": "深圳先锋898",
        "深圳快乐1062(交通广播)": "深圳快乐1062",
        "深圳私家车广播": "深圳私家车942",
        "深圳飞扬音乐971": "深圳飞扬971",
        "深圳缤纷": "深圳缤纷1043",
        "东莞畅享1075交通广播": "东莞畅享1075",
        "东莞阳光1008新闻综合": "东莞阳光1008",
        "广东优悦广播(南粤)": "广东优悦广播",
        "广东城市之声SunFM爱车": "广东城市之声",
        "广东羊城交通广播": "广东羊城交通广播",
        "广州 MYFM 88.0 (都市生活)": "广州MYFM",
        "MYFM全国音乐频道·广州": "广州MYFM",
    }
    return replacements.get(name, name)


def main() -> None:
    existing = json.loads(STATIONS_FILE.read_text(encoding="utf-8"))
    existing_gd = [s for s in existing if "广东" in s.get("tags", [])]
    existing_norm = {normalize_name(s["name"]) for s in existing_gd}
    existing_urls = {s["url"] for s in existing_gd}

    all_candidates: dict[str, list[str]] = {}
    for src in (parse_radio_txt(), fetch_radio_browser()):
        for name, urls in src.items():
            all_candidates.setdefault(name, [])
            for u in urls:
                if u not in all_candidates[name]:
                    all_candidates[name].append(u)

    # Test all unique URLs
    unique_urls = sorted({u for urls in all_candidates.values() for u in urls})
    url_status: dict[str, str] = {}
    with ThreadPoolExecutor(max_workers=12) as pool:
        futures = {pool.submit(test_url, u): u for u in unique_urls}
        for fut in as_completed(futures):
            url, code = fut.result()
            url_status[url] = code

    working: dict[str, str] = {}
    for raw_name, urls in sorted(all_candidates.items()):
        display = canonical_display_name(raw_name)
        norm = normalize_name(display)
        best = None
        for url in urls:
            if url_status.get(url) == "200":
                best = url
                if ".m3u8" in url:
                    break
        if best:
            # Prefer shorter canonical names; keep first good mapping per norm key
            if norm not in working:
                working[norm] = (display, best)

    new_entries = []
    updated_existing = []
    for norm, (display, url) in sorted(working.items(), key=lambda x: x[1][0]):
        if norm in existing_norm:
            # update URL if existing one differs and new works
            for s in existing_gd:
                if normalize_name(s["name"]) == norm and s["url"] != url:
                    updated_existing.append((s["name"], s["url"], url))
            continue
        new_entries.append({
            "norm": norm,
            "name": display,
            "url": url,
        })

    report = {
        "tested_urls": len(unique_urls),
        "working_stations": len(working),
        "existing_gd": len(existing_gd),
        "new_to_add": len(new_entries),
        "url_status_summary": {
            code: sum(1 for v in url_status.values() if v == code)
            for code in sorted(set(url_status.values()))
        },
        "updated_existing": updated_existing,
        "new_entries": new_entries,
        "working_all": [{"name": d, "url": u} for _, (d, u) in sorted(working.items())],
    }
    out = ROOT / "tools" / "gd_station_test_report.json"
    out.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps({
        "tested_urls": report["tested_urls"],
        "working_stations": report["working_stations"],
        "existing_gd": report["existing_gd"],
        "new_to_add": report["new_to_add"],
        "report": str(out),
    }, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
