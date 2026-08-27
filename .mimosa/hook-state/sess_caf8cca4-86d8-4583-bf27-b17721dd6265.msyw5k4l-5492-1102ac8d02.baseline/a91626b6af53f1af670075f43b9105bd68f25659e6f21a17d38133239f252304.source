"""Merge tested Guangdong stations into assets/stations_cn.json.

Do not grow the curated list for coverage. Only write a station back when
GET body is a real playlist/audio stream (not JSON/HTML 200). Prefer deleting
dead URLs over adding unverified replacements.
"""
from __future__ import annotations

import json
import re
import subprocess
import urllib.parse
import urllib.request
from pathlib import Path

from stream_content import UA

ROOT = Path(__file__).resolve().parents[1]
STATIONS_FILE = ROOT / "assets" / "stations_cn.json"
FAVICON_GD = "https://www.gdtv.cn/favicon.ico"
FAVICON_SZ = "https://www.szradio.com.cn/favicon.ico"
HOMEPAGE_GD = "https://www.gdtv.cn/"


def test_url(url: str) -> bool:
    """GET a prefix and require a real playlist/audio body, not JSON/HTML 200."""
    try:
        result = subprocess.run(
            [
                "curl.exe",
                "-sL",
                "--max-time",
                "12",
                "-A",
                UA,
                "--max-filesize",
                "2048",
                "-w",
                "\nCODE:%{http_code} CTYPE:%{content_type}",
                url,
            ],
            capture_output=True,
            timeout=18,
        )
        raw = (result.stdout or b"").decode("utf-8", errors="replace")
        body, _, meta = raw.rpartition("\nCODE:")
        code = "000"
        ctype = ""
        if meta:
            parts = meta.strip().split(" CTYPE:", 1)
            code = parts[0].strip()
            ctype = parts[1].strip().lower() if len(parts) > 1 else ""
        if code not in {"200", "206"}:
            return False
        text = body.lstrip()
        if "json" in ctype or text.startswith("{") or text.startswith("["):
            return False
        if "text/html" in ctype or text.lower().startswith("<!doctype html") or text.lower().startswith("<html"):
            return False
        path = url.split("?", 1)[0].lower()
        if ".m3u8" in path or "#EXTM3U" in text:
            if "#EXTM3U" not in text:
                return False
            has_entry = any(
                line.strip() and not line.strip().startswith("#")
                for line in text.splitlines()
            )
            if not has_entry:
                return False
        return True
    except Exception:
        return False


def fetch_dongguan_urls() -> dict[str, str]:
    stable = {
        "dg-1": "https://stream.sun0769.com/dgrtv1/mp4tv10/index.m3u8",
        "dg-2": "https://stream.sun0769.com/dgrtv1/mp4tv11/index.m3u8",
    }
    q = urllib.parse.quote("东莞")
    url = f"https://de1.api.radio-browser.info/json/stations/search?countrycode=CN&name={q}&hidebroken=true&limit=10"
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    out: dict[str, str] = dict(stable)
    try:
        with urllib.request.urlopen(req, timeout=20) as resp:
            data = json.loads(resp.read().decode())
        for item in data:
            name = item.get("name", "")
            stream = item.get("url_resolved") or item.get("url") or ""
            stream = stream.split("?", 1)[0] if "stream.sun0769.com" in stream else stream
            if "1008" in name and test_url(stream):
                out["dg-1"] = stream
            elif "1075" in name and test_url(stream):
                out["dg-2"] = stream
    except Exception:
        pass
    return out


def stream_id(url: str) -> str:
    m = re.search(r"/live/(\d+)", url)
    return m.group(1) if m else url


def infer_tags(name: str) -> list[str]:
    tags = ["地方台", "广东"]
    for city in (
        "广州", "深圳", "佛山", "东莞", "珠海", "惠州", "汕头", "湛江", "江门",
        "中山", "肇庆", "茂名", "韶关", "梅州", "清远", "潮州", "揭阳", "阳江",
        "河源", "汕尾", "云浮", "普宁", "廉江", "怀集", "梅县", "番禺", "增城",
    ):
        if city in name:
            tags.append("揭阳" if city == "普宁" else city)
            break
    if any(k in name for k in ("新闻", "先锋", "综合")):
        tags.append("新闻")
    elif any(k in name for k in ("交通", "1075", "1062", "875", "988")):
        tags.append("交通")
    elif any(k in name for k in ("音乐", "MYFM", "飞扬", "971", "888", "915", "104", "金曲")):
        tags.append("音乐")
    elif any(k in name for k in ("经济", "珠江", "财经", "股市")):
        tags.append("财经")
    elif any(k in name for k in ("生活", "私家", "戏曲", "旅游")):
        tags.append("生活")
    else:
        tags.append("综合")
    return tags


def make_station(
    station_id: str,
    name: str,
    url: str,
    *,
    bitrate: int = 64,
    homepage: str = HOMEPAGE_GD,
    favicon: str = FAVICON_GD,
) -> dict:
    return {
        "id": station_id,
        "name": name,
        "url": url,
        "favicon": favicon,
        "tags": infer_tags(name),
        "category": "地方台",
        "bitrate": bitrate,
        "codec": "AAC",
        "homepage": homepage,
    }


# Curated list: id, name, url, bitrate (optional 4th)
CURATED: list[tuple] = [
    # 省级
    ("gd-1", "广东珠江经济台", "https://lhttp.qtfm.cn/live/1259/64k.mp3", 64),
    ("gd-2", "广东音乐之声", "https://lhttp.qtfm.cn/live/1260/64k.mp3", 128),
    ("gd-3", "广东新闻频道", "http://ls.qingting.fm/live/1254.m3u8", 64),
    ("gd-4", "广东羊城交通广播", "http://ls.qingting.fm/live/1262.m3u8", 64),
    ("gd-5", "广东南方生活广播", "http://ls.qingting.fm/live/468.m3u8", 64),
    ("gd-6", "广东文体广播", "http://ls.qingting.fm/live/471.m3u8", 64),
    ("gd-7", "广东城市之声", "http://ls.qingting.fm/live/469.m3u8", 64),
    ("gd-8", "广东优悦广播", "http://ls.qingting.fm/live/470.m3u8", 64),
    ("gd-9", "广东股市广播", "http://ls.qingting.fm/live/4847.m3u8", 64),
    # 广州
    ("gz-1", "广州新闻电台", "http://ls.qingting.fm/live/4848.m3u8", 64),
    ("gz-2", "广州交通电台", "http://ls.qingting.fm/live/4955.m3u8", 64),
    ("gz-3", "广州汽车音乐电台", "http://ls.qingting.fm/live/52710.m3u8", 128),
    ("gz-4", "广州MYFM", "http://ls.qingting.fm/live/52712.m3u8", 128),
    ("gz-5", "广州金曲音乐广播", "http://lhttp.qingting.fm/live/20192/64k.mp3", 128),
    ("gz-6", "增城人民广播电台", "http://lhttp.qingting.fm/live/20211702/64k.mp3", 64),
    ("gz-7", "番禺区广播电台", "https://lhttp.qtfm.cn/live/20212427/64k.mp3", 64),
    # 深圳
    ("sz-1", "深圳先锋898", "http://ls.qingting.fm/live/1270.m3u8", 64),
    ("sz-2", "深圳飞扬971", "http://ls.qingting.fm/live/1271.m3u8", 128),
    ("sz-3", "深圳快乐1062", "http://ls.qingting.fm/live/1272.m3u8", 64),
    ("sz-4", "深圳私家车942", "http://ls.qingting.fm/live/1273.m3u8", 64),
    ("sz-5", "深圳缤纷1043", "http://ls.qingting.fm/live/267.m3u8", 64),
    ("sz-6", "深圳星光991", "http://ls.qingting.fm/live/28132.m3u8", 64),
    ("sz-7", "深圳龙岗频道", "http://lhttp.qingting.fm/live/20160/64k.mp3", 64),
    # 佛山
    ("fs-1", "佛山综合广播", "http://ls.qingting.fm/live/1263.m3u8", 64),
    ("fs-2", "佛山南海广播", "https://radiopull.radiofoshan.com.cn/live/1400820947_BSID_42_audio.m3u8", 64),
    ("fs-3", "佛山顺德广播", "https://radiopull.radiofoshan.com.cn/live/1400820947_BSID_44_audio.m3u8", 64),
    # 珠海
    ("zh-1", "珠海先锋951", "http://ls.qingting.fm/live/1274.m3u8", 64),
    ("zh-2", "珠海交通音乐875", "http://ls.qingting.fm/live/1275.m3u8", 64),
    # 惠州
    ("hz-1", "惠州新闻100", "http://ls.qingting.fm/live/5016.m3u8", 64),
    ("hz-3", "惠州音乐907", "http://ls.qingting.fm/live/2212959.m3u8", 128),
    # 汕头
    ("st-1", "汕头综合广播", "https://stream.zeno.fm/fjsl1teq6vjuv", 64),
    # 江门
    ("jm-1", "江门新闻综合", "http://ls.qingting.fm/live/1282.m3u8", 64),
    ("jm-2", "江门旅游音乐", "http://ls.qingting.fm/live/1283.m3u8", 64),
    ("jm-3", "江门新会电台", "https://lhttp-hw.qtfm.cn/live/5061/64k.mp3", 64),
    # 肇庆
    ("zq-1", "肇庆综合广播", "https://live.ximalaya.com/radio-first-page-app/live/2892/64.m3u8?transcode=ts", 64),
    ("zq-3", "肇庆高新之声", "https://lhttp-hw.qtfm.cn/live/20500213/64k.mp3", 64),
    ("zq-4", "怀集音乐之声", "http://lhttp.qingting.fm/live/4804/64k.mp3", 64),
    # 梅州
    ("mz-1", "梅州新闻948", "http://ls.qingting.fm/live/24173.m3u8", 64),
    ("mz-2", "梅州交通1058", "http://ls.qingting.fm/live/24195.m3u8", 64),
    ("mz-3", "梅州综合广播", "https://lhttp-hw.qtfm.cn/live/1257/64k.mp3", 64),
    ("mz-4", "梅县人民广播电台", "http://lhttp.qingting.fm/live/5021942/64k.mp3", 64),
    # 湛江
    ("zj-1", "湛江综合广播", "http://lhttp.qingting.fm/live/20617/64k.mp3", 64),
    ("zj-2", "廉江广播", "https://lhttp-hw.qtfm.cn/live/20211578/64k.mp3", 64),
    # 茂名
    ("mm-1", "茂名综合广播", "http://lhttp.qingting.fm/live/20500088/64k.mp3", 64),
    ("mm-2", "茂名交通广播", "https://lhttp.qingting.fm/live/20211574/64k.mp3", 64),
    # 韶关
    ("sg-1", "韶关综合广播", "https://lhttp-hw.qtfm.cn/live/5022074/64k.mp3", 64),
    # 河源
    ("hy-1", "河源综合广播", "http://ls.qingting.fm/live/1291.m3u8", 64),
    ("hy-2", "河源旅游广播", "http://tmpstream.hyrtv.cn/lygb/sd/live.m3u8", 64),
    # 清远
    ("qy-1", "清远综合广播", "http://lhttp.qingting.fm/live/15318668/64k.mp3", 64),
    ("qy-2", "清远交通音乐广播", "http://lhttp.qingting.fm/live/20500067/64k.mp3", 64),
    # 潮州
    ("cz-1", "潮州综合频率", "http://ls.qingting.fm/live/4596.m3u8", 64),
    ("cz-2", "潮州交通音乐广播", "https://lhttp.qingting.fm/live/4594/64k.mp3", 64),
    ("cz-3", "潮州戏曲广播", "http://ls.qingting.fm/live/4595.m3u8", 64),
    # 揭阳
    ("jy-1", "普宁人民广播电台", "http://lhttp.qingting.fm/live/5022527/64k.mp3", 64),
    # 云浮
    ("yf-1", "云浮综合广播", "http://lhttp.qingting.fm/live/5022442/64k.mp3", 64),
    # 阳江
    ("yj-1", "阳江综合广播", "https://lhttp.qtfm.cn/live/15318429/64k.mp3", 64),
    # 中山
    ("zs-1", "中山新锐967", "http://ls.qingting.fm/live/1277.m3u8", 64),
    ("zs-2", "中山快乐888", "http://ls.qingting.fm/live/1278.m3u8", 64),
]


def main() -> None:
    dongguan = fetch_dongguan_urls()
    curated = list(CURATED)
    if dongguan.get("dg-1"):
        curated.append(("dg-1", "东莞阳光1008", dongguan["dg-1"], 64))
    if dongguan.get("dg-2"):
        curated.append(("dg-2", "东莞畅享1075", dongguan["dg-2"], 64))

    passed: list[dict] = []
    failed: list[tuple[str, str, str]] = []
    seen_streams: set[str] = set()

    for station_id, name, url, bitrate in curated:
        sid = stream_id(url)
        if sid in seen_streams:
            continue
        if test_url(url):
            seen_streams.add(sid)
            favicon = FAVICON_SZ if station_id.startswith("sz-") else FAVICON_GD
            homepage = "https://www.szradio.com.cn/" if station_id.startswith("sz-") else HOMEPAGE_GD
            passed.append(make_station(station_id, name, url, bitrate=bitrate, favicon=favicon, homepage=homepage))
        else:
            failed.append((station_id, name, url))

    all_stations = json.loads(STATIONS_FILE.read_text(encoding="utf-8"))
    non_gd = [s for s in all_stations if "广东" not in s.get("tags", [])]

    # Insert GD block before music-1 / first non-gd after sh-2 area - actually append after last local before music
    # Find insertion point: after last 广东 station in original or before music-1
    insert_idx = next((i for i, s in enumerate(all_stations) if s["id"] == "music-1"), len(all_stations))
    # Rebuild: everything before gd-1 + passed + everything from music-1 that's not gd
    start_idx = next((i for i, s in enumerate(all_stations) if s["id"] == "gd-1"), insert_idx)
    before = [s for s in all_stations[:start_idx] if "广东" not in s.get("tags", [])]
    after = [s for s in all_stations[insert_idx:] if "广东" not in s.get("tags", [])]
    merged = before + passed + after

    STATIONS_FILE.write_text(json.dumps(merged, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    report = {
        "added_gd_count": len(passed),
        "failed_count": len(failed),
        "failed": [{"id": a, "name": b, "url": c} for a, b, c in failed],
        "total_stations": len(merged),
    }
    report_path = ROOT / "tools" / "gd_merge_report.json"
    report_path.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps(report, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
