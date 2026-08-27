"""Import extra China radio streams referenced by radio5.cn / tingfm-style catalogs.

Do not bulk-grow assets/stations_cn.json. This script is for finding replacements,
not for stuffing the default catalog. Only keep token-less URLs whose GET body is
a real playlist/audio stream (not JSON/HTML 200).
"""

from __future__ import annotations

import json
import re
import subprocess
import urllib.request
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path

from stream_content import UA

ROOT = Path(__file__).resolve().parents[1]
STATIONS_FILE = ROOT / "assets" / "stations_cn.json"
RADIO_TXT_URL = "https://raw.githubusercontent.com/gaotianliuyun/gao/master/radio.txt"
RADIO5_SITEMAP = "https://radio5.cn/wp-sitemap-posts-station-1.xml"
HEADERS = {"User-Agent": UA}

PRIORITY_KEYS = (
    "天津", "重庆", "杭州", "宁波", "成都", "长沙", "武汉", "济南", "青岛",
    "郑州", "西安", "福州", "厦门", "合肥", "沈阳", "大连", "哈尔滨", "长春",
    "石家庄", "太原", "南昌", "南宁", "昆明", "贵阳", "海口", "乌鲁木齐",
    "呼和浩特", "兰州", "银川", "西宁", "拉萨", "苏州", "南京", "无锡",
    "香港", "澳门", "浙江", "四川", "湖南", "湖北", "山东", "河南", "陕西",
    "福建", "安徽", "辽宁", "黑龙江", "吉林", "河北", "山西", "江西", "广西",
    "云南", "贵州", "海南", "新疆", "内蒙古", "甘肃", "宁夏", "青海", "西藏",
    "天津", "重庆", "CRI", "国际", "RTHK", "香港电台",
)

SKIP_NAME = (
    "卫视", "电视", "CCTV", "CGTN", "测试", "广播剧", "新加坡", "Singapore",
    "Malaysia", "883Jia", "Warna", "Oli 968", "Power 98", "Astro",
)

TOKEN_RE = re.compile(r"[?&](t|token|key|auth|sign|timestamp)=", re.I)


def fetch_text(url: str) -> str:
    req = urllib.request.Request(url, headers=HEADERS)
    with urllib.request.urlopen(req, timeout=30) as resp:
        return resp.read().decode("utf-8", "replace")


def normalize_name(name: str) -> str:
    n = re.sub(r"\s+", "", name)
    n = re.sub(r"FM[\d.]+", "", n, flags=re.I)
    n = re.sub(r"AM\d+", "", n, flags=re.I)
    n = n.replace("·", "").replace("(", "").replace(")", "")
    n = n.replace("电台", "").replace("广播", "")
    n = n.replace("广通-", "").replace("中国-", "")
    return n.lower()


def is_token_url(url: str) -> bool:
    return bool(TOKEN_RE.search(url))


def should_skip_name(name: str) -> bool:
    if any(k in name for k in ("卫视", "CCTV", "CGTN", "新加坡", "Singapore", "Malaysia", "Astro")):
        return True
    if "电视" in name and "广播" not in name and "电台" not in name:
        return True
    return False


def is_priority(name: str) -> bool:
    return any(k in name for k in PRIORITY_KEYS)


def url_rank(url: str) -> int:
    if "ngcdn" in url or "cnr.cn" in url:
        return 0
    if "sk.cri.cn" in url:
        return 1
    if "rbc.cn" in url or "brtv-radiolive" in url:
        return 2
    if "ls.qingting.fm" in url:
        return 3
    if "qtfm.cn" in url or "qingting.fm" in url:
        return 4
    if ".m3u8" in url:
        return 5
    return 6


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


def infer_tags(name: str) -> list[str]:
    tags = ["地方台"]
    provinces = {
        "北京": "北京", "天津": "天津", "上海": "上海", "重庆": "重庆",
        "河北": "河北", "石家庄": "河北", "山西": "山西", "太原": "山西",
        "辽宁": "辽宁", "沈阳": "辽宁", "大连": "辽宁", "吉林": "吉林", "长春": "吉林",
        "黑龙江": "黑龙江", "哈尔滨": "黑龙江", "江苏": "江苏", "南京": "江苏",
        "苏州": "江苏", "无锡": "江苏", "浙江": "浙江", "杭州": "浙江", "宁波": "浙江",
        "安徽": "安徽", "合肥": "安徽", "福建": "福建", "福州": "福建", "厦门": "福建",
        "江西": "江西", "南昌": "江西", "山东": "山东", "济南": "山东", "青岛": "山东",
        "河南": "河南", "郑州": "河南", "湖北": "湖北", "武汉": "湖北",
        "湖南": "湖南", "长沙": "湖南", "广东": "广东", "广西": "广西", "南宁": "广西",
        "海南": "海南", "海口": "海南", "四川": "四川", "成都": "四川",
        "贵州": "贵州", "贵阳": "贵州", "云南": "云南", "昆明": "云南",
        "西藏": "西藏", "拉萨": "西藏", "陕西": "陕西", "西安": "陕西",
        "甘肃": "甘肃", "兰州": "甘肃", "青海": "青海", "西宁": "青海",
        "宁夏": "宁夏", "银川": "宁夏", "新疆": "新疆", "乌鲁木齐": "新疆",
        "内蒙古": "内蒙古", "呼和浩特": "内蒙古", "香港": "香港", "RTHK": "香港",
        "澳门": "澳门",
    }
    for key, tag in provinces.items():
        if key in name:
            tags.append(tag)
            break
    if name.startswith("CNR") or "中国之声" in name or "央广" in name:
        tags = ["央广"]
    if "CRI" in name or "国际" in name:
        tags.append("国际")
    if any(k in name for k in ("新闻", "综合")):
        tags.append("新闻")
    elif any(k in name for k in ("交通",)):
        tags.append("交通")
    elif any(k in name for k in ("音乐", "经典", "流行", "Love", "HIT", "动听")):
        tags.append("音乐")
    elif any(k in name for k in ("经济", "财经", "都市")):
        tags.append("财经")
    elif any(k in name for k in ("交通", "私家车")):
        tags.append("交通")
    else:
        tags.append("综合")
    # unique preserve order
    seen: set[str] = set()
    out: list[str] = []
    for tag in tags:
        if tag not in seen:
            seen.add(tag)
            out.append(tag)
    return out


def infer_category(tags: list[str]) -> str:
    if "央广" in tags:
        return "央广"
    if "音乐" in tags:
        return "音乐"
    return "地方台"


def clean_display_name(name: str) -> str:
    name = re.sub(r"\s+", " ", name).strip()
    name = name.replace("广通-", "").replace("中国-", "")
    name = re.sub(
        r"^(浙江|江苏|四川|湖南|湖北|山东|河南|陕西|福建|安徽|辽宁|黑龙江|吉林|河北|山西|江西|广西|云南|贵州|海南|新疆|内蒙古|甘肃|宁夏|青海|西藏|交通|新闻|神思)-",
        "",
        name,
    )
    name = re.sub(r"（中波卖药版）|\(中波卖药版\)", "", name)
    name = re.sub(r"（高清音质）|\(高清音质\)", "", name)
    name = re.sub(r"\s*\(2\)|\s*（2）", "", name)
    return name.strip()


def is_junk_name(name: str) -> bool:
    if any(k in name for k in ("卖药", "普兰店", "中波", "高清音质")):
        return True
    if name.endswith("(2)") or name.endswith("（2）"):
        return True
    return False


def parse_radio_txt() -> dict[str, list[str]]:
    text = fetch_text(RADIO_TXT_URL)
    candidates: dict[str, list[str]] = {}
    for line in text.splitlines():
        if "," not in line or line.strip().endswith("#genre#"):
            continue
        name, url = line.split(",", 1)
        name = clean_display_name(name.strip())
        url = url.strip()
        if not url.startswith("http"):
            continue
        if is_token_url(url) or should_skip_name(name) or is_junk_name(name):
            continue
        if not is_priority(name):
            continue
        candidates.setdefault(name, [])
        if url not in candidates[name]:
            candidates[name].append(url)
    for urls in candidates.values():
        urls.sort(key=url_rank)
    return candidates


def radio5_radio_slugs() -> set[str]:
    try:
        xml = fetch_text(RADIO5_SITEMAP)
    except Exception:
        return set()
    slugs = set(re.findall(r"https://radio5\.cn/play/radio/([a-z0-9\-]+)", xml))
    return slugs


def boost_radio5(candidates: dict[str, list[str]], slugs: set[str]) -> set[str]:
    """Return normalize_name keys that look like radio5 featured stations."""
    featured: set[str] = set()
    tokens = set()
    for slug in slugs:
        for part in slug.split("-"):
            if len(part) >= 3 and part not in {"radio", "news", "music", "traffic", "fm"}:
                tokens.add(part.lower())
    for name in candidates:
        lowered = name.lower()
        if any(token in lowered for token in tokens if token.isascii()):
            featured.add(normalize_name(name))
        # Chinese names won't match ascii slugs; keep city-priority instead
    return featured


def main() -> None:
    existing = json.loads(STATIONS_FILE.read_text(encoding="utf-8"))
    existing = [s for s in existing if not str(s.get("id", "")).startswith("ext-")]
    existing_norm = {normalize_name(s["name"]) for s in existing}
    existing_urls = {s["url"] for s in existing}

    candidates = parse_radio_txt()
    slugs = radio5_radio_slugs()
    print(f"radio5 radio slugs: {len(slugs)}")
    print(f"priority candidate names: {len(candidates)}")

    # Keep first 2 URLs per name to test
    to_test: list[tuple[str, str]] = []
    for name, urls in candidates.items():
        if normalize_name(name) in existing_norm:
            continue
        for url in urls[:2]:
            if url not in existing_urls:
                to_test.append((name, url))

    url_status: dict[str, str] = {}
    unique_urls = list(dict.fromkeys(url for _, url in to_test))
    print(f"testing urls: {len(unique_urls)}")
    with ThreadPoolExecutor(max_workers=14) as pool:
        futures = {pool.submit(test_url, url): url for url in unique_urls}
        done = 0
        for fut in as_completed(futures):
            url, code = fut.result()
            url_status[url] = code
            done += 1
            if done % 40 == 0:
                print(f"  tested {done}/{len(unique_urls)}")

    picked: dict[str, tuple[str, str]] = {}
    for name, url in to_test:
        if url_status.get(url) not in {"200", "206"}:
            continue
        if is_junk_name(name):
            continue
        key = normalize_name(name)
        if key in existing_norm or key in picked:
            continue
        picked[key] = (name, url)

    from collections import defaultdict

    by_province: dict[str, list[tuple[str, str]]] = defaultdict(list)
    for name, url in picked.values():
        tags = infer_tags(name)
        province = next(
            (
                tag
                for tag in tags
                if tag not in {"地方台", "新闻", "交通", "音乐", "财经", "综合", "国际", "央广"}
            ),
            "其他",
        )
        by_province[province].append((name, url))

    ordered: list[tuple[str, str]] = []
    for province in sorted(by_province):
        items = by_province[province]

        def station_rank(item: tuple[str, str]) -> tuple[int, str]:
            name = item[0]
            if "新闻" in name:
                return (0, name)
            if "交通" in name:
                return (1, name)
            if "音乐" in name:
                return (2, name)
            return (3, name)

        items.sort(key=station_rank)
        ordered.extend(items[:3])

    start_id = 1
    new_stations = []
    for name, url in ordered:
        if normalize_name(name) in existing_norm:
            continue
        tags = infer_tags(name)
        new_stations.append(
            {
                "id": f"ext-{start_id:03d}",
                "name": name,
                "url": url,
                "tags": tags,
                "category": infer_category(tags),
                "bitrate": 64,
                "codec": "AAC",
            }
        )
        existing_norm.add(normalize_name(name))
        start_id += 1

    insert_idx = next((i for i, s in enumerate(existing) if s["id"] == "music-1"), len(existing))
    merged = existing[:insert_idx] + new_stations + existing[insert_idx:]
    STATIONS_FILE.write_text(json.dumps(merged, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    report = {
        "radio5_radio_slugs": len(slugs),
        "tested_urls": len(unique_urls),
        "status_summary": {
            code: sum(1 for v in url_status.values() if v == code)
            for code in sorted(set(url_status.values()))
        },
        "added": len(new_stations),
        "total": len(merged),
        "names": [s["name"] for s in new_stations],
    }
    report_path = ROOT / "tools" / "national_import_report.json"
    report_path.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps({k: report[k] for k in ("tested_urls", "added", "total", "status_summary")}, ensure_ascii=False, indent=2))
    print("report", report_path)


if __name__ == "__main__":
    main()
