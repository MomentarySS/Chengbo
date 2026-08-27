"""Rebuild the curated station list (assets/stations_cn.json) from 4 sources.

Sources:
  qtfm    - https://www.qtfm.cn/radiopage/217/1 (GraphQL radioPage per region)
  tingfm  - https://tingfm.net/#m=index&play=751   (wnd_posts + wndt_streams)
  radio.cn- https://www.radio.cn/pc-portal/erji/radioStation.html (signed appBroadcast/list)
  radio5  - https://radio5.cn/fm/radio-type         (listing pages + api/play/play)

Pipeline: collect candidates -> multi-pass probe -> dedup by URL and by
normalized name (keep the most stable URL) -> write stations_cn.json.

All requests are http/https only; private/loopback/link-local hosts are refused
before any connection (see _safe_fetch). Run from tools/ so stream_content is
importable. Cached raw data lives in tools/_scrape_cache/ for resumable runs.
"""

from __future__ import annotations

import argparse
import gzip
import hashlib
import ipaddress
import json
import re
import socket
import time
import urllib.error
import urllib.parse
import urllib.request
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path

from stream_content import UA, PREVIEW_MAX_BYTES, evaluate, looks_like_hls

ROOT = Path(__file__).resolve().parents[1]
STATIONS_FILE = ROOT / "assets" / "stations_cn.json"
CACHE_DIR = Path(__file__).resolve().parent / "_scrape_cache"
MAX_REDIRECTS = 8
CONCURRENCY = 10
COLLECT_CONCURRENCY = 5  # gentler: scrape targets rate-limit aggressive crawlers


# ---------------------------------------------------------------- safe fetch

class _NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, request, fp, code, msg, headers, newurl):
        return None


def _blocked_target(url: str) -> str | None:
    parsed = urllib.parse.urlparse(url)
    if parsed.scheme not in ("http", "https"):
        return f"非法协议 {parsed.scheme}"
    host = parsed.hostname
    if not host:
        return "地址缺少主机名"
    try:
        infos = socket.getaddrinfo(
            host, parsed.port or (443 if parsed.scheme == "https" else 80)
        )
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


def _open_with_retry(opener, request, timeout: int, retries: int = 2):
    # Fail fast on 429: sleeping only makes rate limits worse and stalls the
    # whole crawl; a throttled response counts as a miss for this request.
    for attempt in range(retries + 1):
        try:
            return opener.open(request, timeout=timeout)
        except urllib.error.HTTPError as error:
            if error.code == 429 and attempt < retries:
                continue
            raise
    raise ConnectionError("重试次数过多")


def http_get(url: str, headers: dict | None = None, timeout: int = 20):
    """GET with redirects followed manually, gzip decoded, 429 backoff.

    Returns (status, content_type, bytes_body) or raises on blocked target.
    """
    current = url
    headers = {"User-Agent": UA, "Accept-Encoding": "gzip", **(headers or {})}
    opener = urllib.request.build_opener(_NoRedirect)
    for _ in range(MAX_REDIRECTS + 1):
        blocked = _blocked_target(current)
        if blocked:
            raise ValueError(blocked)
        request = urllib.request.Request(current, headers=headers)
        try:
            response = _open_with_retry(opener, request, timeout)
        except urllib.error.HTTPError as error:
            if error.code in (301, 302, 303, 307, 308):
                location = error.headers.get("Location")
                if location:
                    current = urllib.parse.urljoin(current, location)
                    continue
            raise
        except Exception as error:
            raise ConnectionError(f"连接失败: {error}") from error
        with response:
            status = response.status
            content_type = response.headers.get("Content-Type", "")
            encoding = response.headers.get("Content-Encoding", "")
            raw = response.read()
        if status in (301, 302, 303, 307, 308):
            location = response.headers.get("Location")
            if not location:
                return status, content_type, raw
            current = urllib.parse.urljoin(current, location)
            continue
        if "gzip" in encoding.lower():
            try:
                raw = gzip.decompress(raw)
            except Exception:
                pass
        return status, content_type, raw
    raise ConnectionError("重定向次数过多")


def http_get_preview(
    url: str,
    headers: dict | None = None,
    timeout: int = 12,
    max_bytes: int = PREVIEW_MAX_BYTES,
):
    """GET like http_get but read only max_bytes (live streams never end)."""
    current = url
    headers = {"User-Agent": UA, "Accept-Encoding": "gzip", **(headers or {})}
    opener = urllib.request.build_opener(_NoRedirect)
    for _ in range(MAX_REDIRECTS + 1):
        blocked = _blocked_target(current)
        if blocked:
            raise ValueError(blocked)
        request = urllib.request.Request(current, headers=headers)
        try:
            response = _open_with_retry(opener, request, timeout)
        except urllib.error.HTTPError as error:
            if error.code in (301, 302, 303, 307, 308):
                location = error.headers.get("Location")
                if location:
                    current = urllib.parse.urljoin(current, location)
                    continue
            raise
        except Exception as error:
            raise ConnectionError(f"连接失败: {error}") from error
        with response:
            status = response.status
            content_type = response.headers.get("Content-Type", "")
            encoding = response.headers.get("Content-Encoding", "")
            raw = response.read(max_bytes + 1)
        if status in (301, 302, 303, 307, 308):
            location = response.headers.get("Location")
            if not location:
                return status, content_type, raw
            current = urllib.parse.urljoin(current, location)
            continue
        if "gzip" in encoding.lower():
            try:
                raw = gzip.decompress(raw)
            except Exception:
                pass
        return status, content_type, raw[:max_bytes]
    raise ConnectionError("重定向次数过多")


def http_json(url: str, headers: dict | None = None, timeout: int = 20):
    status, content_type, raw = http_get(url, headers, timeout)
    if status != 200:
        raise ConnectionError(f"HTTP {status} {url}")
    return json.loads(raw.decode("utf-8", "replace"))


def http_post_json(url: str, payload: dict, timeout: int = 20):
    current = url
    opener = urllib.request.build_opener(_NoRedirect)
    for _ in range(MAX_REDIRECTS + 1):
        blocked = _blocked_target(current)
        if blocked:
            raise ValueError(blocked)
        body = json.dumps(payload, ensure_ascii=False).encode("utf-8")
        request = urllib.request.Request(
            current,
            data=body,
            headers={"User-Agent": UA, "Content-Type": "application/json"},
        )
        try:
            response = _open_with_retry(opener, request, timeout)
        except urllib.error.HTTPError as error:
            if error.code in (301, 302, 303, 307, 308):
                location = error.headers.get("Location")
                if location:
                    current = urllib.parse.urljoin(current, location)
                    continue
            raise
        except Exception as error:
            raise ConnectionError(f"连接失败: {error}") from error
        with response:
            raw = response.read()
        return json.loads(raw.decode("utf-8", "replace"))
    raise ConnectionError("重定向次数过多")


# ---------------------------------------------------------------- collectors

def collect_qtfm() -> list[dict]:
    """radioPage(cid, page){contents} for every region."""
    out: list[dict] = []
    region_query = "{radioPage(cid:432, page:1){regions}}"
    regions_data = http_post_json(
        "https://webbff.qtfm.cn/www", {"query": region_query}
    )
    region_list = (regions_data.get("data") or {}).get("radioPage", {}).get("regions", [])
    for region in region_list:
        cid = region.get("id")
        title = region.get("title")
        page = 1
        while page <= 200:
            query = (
                "{radioPage(cid:%d, page:%d){contents}}" % (cid, page)
            )
            try:
                data = http_post_json("https://webbff.qtfm.cn/www", {"query": query})
            except Exception:
                break
            items = (data.get("data") or {}).get("radioPage", {}).get("contents", {})
            channels = items.get("items") or []
            for ch in channels:
                cid = ch.get("id")
                out.append(
                    {
                        "name": ch.get("title"),
                        "id": cid,
                        # 播放用 https mp3；探测用快而不限速的 m3u8 端点
                        "url": f"https://lhttp.qtfm.cn/live/{cid}/64k.mp3",
                        "probe_url": f"http://ls.qingting.fm/live/{cid}.m3u8",
                        "source": "qtfm",
                        "region": title,
                    }
                )
            total = items.get("count") or 0
            if page * 12 >= total or not channels:
                break
            page += 1
    return out


def collect_tingfm(max_posts: int = 1500) -> list[dict]:
    """wnd_posts (post_type=radio) + wndt_streams per post (parallel)."""
    posts: list[dict] = []
    page = 1
    while len(posts) < max_posts:
        url = (
            "https://tingfm.net/wp-json/query/wnd_posts?"
            "post_status=publish&post_type=radio&per_page=50&paged=%d" % page
        )
        try:
            data = http_json(url)
        except Exception:
            break
        results = (data.get("data") or {}).get("results") or []
        if not results:
            break
        posts.extend(results)
        page += 1
    posts = posts[:max_posts]

    out: list[dict] = []

    def fetch_stream(post: dict) -> None:
        post_id = post.get("ID")
        if not post_id:
            return
        try:
            stream = http_json(
                "https://tingfm.net/wp-json/query/wndt_streams?"
                "post_id=%s&in_web=true" % post_id,
                timeout=15,
            )
        except Exception:
            return
        streams = (stream.get("data") or {}).get("streams") or []
        if not streams:
            return
        url = streams[0].get("url")
        if not url:
            return
        region = ""
        terms = post.get("terms") or {}
        for term in terms.get("region") or terms.get("country") or []:
            region = term.get("name", "")
            break
        out.append(
            {
                "name": post.get("post_title"),
                "url": url,
                "source": "tingfm",
                "region": region,
            }
        )

    with ThreadPoolExecutor(max_workers=COLLECT_CONCURRENCY) as pool:
        for item in pool.map(fetch_stream, posts):
            time.sleep(0.05)
    return out


def _radio_cn_sign(province_code: str = "0") -> dict:
    # radio.cn requires this exact MD5 signing scheme; the hash is a request
    # signature mandated by the vendor API, not integrity protection we choose.
    key = "f0fc4c668392f9f9a447e48584c214ee"
    tm = int(time.time() * 1000)
    params = {"categoryId": "0", "provinceCode": province_code}
    sign_text = (
        "&".join(f"{k}={params[k]}" for k in sorted(params))
        + f"&timestamp={tm}&key={key}"
    )
    sign = hashlib.md5(sign_text.encode()).hexdigest().upper()
    return {
        "Content-Type": "application/json",
        "equipmentId": "0000",
        "platformCode": "WEB",
        "timestamp": str(tm),
        "sign": sign,
    }


def collect_radio_cn() -> list[dict]:
    """Signed appBroadcast/list for every province + the national list."""
    out: list[dict] = []
    provinces = http_json(
        "https://ytmsout.radio.cn/web/appProvince/list/all", _radio_cn_sign()
    )
    prov_codes = ["0"]
    for p in provinces.get("data") or []:
        prov_codes.append(str(p.get("provinceCode") or p.get("code") or ""))
    for code in prov_codes:
        url = (
            "https://ytmsout.radio.cn/web/appBroadcast/list?"
            "categoryId=0&provinceCode=%s" % urllib.parse.quote(code)
        )
        try:
            data = http_json(url, _radio_cn_sign(code))
        except Exception:
            continue
        for item in data.get("data") or []:
            title = item.get("title")
            if not title:
                continue
            for field in ("playUrlLow", "mp3PlayUrlLow", "mp3PlayUrlHigh", "playUrlMulti"):
                stream = item.get(field)
                if stream:
                    break
            else:
                continue
            out.append(
                {
                    "name": title,
                    "url": stream,
                    "source": "radio_cn",
                    "region": "",
                }
            )
    return out


def collect_radio5() -> list[dict]:
    """Listing pages (level/*, area/*) -> data-id -> api/play/play/{id}."""
    slugs: dict[int, str] = {}
    for page_url in (
        "https://radio5.cn/level/g",
        "https://radio5.cn/level/s",
        "https://radio5.cn/level/c",
        "https://radio5.cn/level/hk",
        "https://radio5.cn/level/x",
        "https://radio5.cn/level/net",
    ):
        try:
            _, _, raw = http_get(page_url)
        except Exception:
            continue
        html = raw.decode("utf-8", "replace")
        for sid, surl in re.findall(
            r'data-id="(\d+)"[^>]*data-url="(https://radio5\.cn/play/radio/[^"]+)"', html
        ):
            slugs.setdefault(int(sid), surl)

    out: list[dict] = []

    def fetch_station(sid: int) -> None:
        try:
            data = http_json("https://radio5.cn/api/play/play/%d" % sid, timeout=15)
        except Exception:
            return
        stream = data.get("stream_url")
        title = data.get("title")
        if not stream or not title:
            return
        out.append(
            {
                "name": title,
                "url": stream,
                "source": "radio5",
                "region": "",
            }
        )

    with ThreadPoolExecutor(max_workers=COLLECT_CONCURRENCY) as pool:
        for _ in pool.map(fetch_station, slugs):
            time.sleep(0.05)
    return out


COLLECTORS = {
    "qtfm": collect_qtfm,
    "tingfm": collect_tingfm,
    "radio_cn": collect_radio_cn,
    "radio5": collect_radio5,
}


def collect_all(sources: list[str]) -> list[dict]:
    all_candidates: list[dict] = []
    for source in sources:
        cached = CACHE_DIR / f"{source}.json"
        if cached.exists():
            items = json.loads(cached.read_text(encoding="utf-8"))
            print(f"{source}: {len(items)} from cache", flush=True)
            all_candidates.extend(items)
            continue
        try:
            items = COLLECTORS[source]()
        except Exception as error:
            print(f"{source}: FAILED {error}", flush=True)
            continue
        if items:
            CACHE_DIR.mkdir(exist_ok=True)
            cached.write_text(
                json.dumps(items, ensure_ascii=False, indent=1), encoding="utf-8"
            )
        else:
            print(f"{source}: empty result (rate limited?), not cached", flush=True)
        print(f"{source}: {len(items)}", flush=True)
        all_candidates.extend(items)
    return all_candidates


# ---------------------------------------------------------------- probe & dedup

def probe_candidate(url: str) -> bool:
    hls = looks_like_hls(url)
    try:
        status, content_type, raw = http_get_preview(url, timeout=12)
    except Exception:
        return False
    preview = raw[:PREVIEW_MAX_BYTES].decode("latin1", "replace")
    ok, _ = evaluate(
        url=url, status_code=status, content_type=content_type, preview=preview
    )
    if not ok and not hls:
        # Range fallback, mirrors the app's probe
        try:
            status2, content_type2, raw2 = http_get_preview(
                url, headers={"Range": f"bytes=0-{PREVIEW_MAX_BYTES - 1}"}, timeout=12
            )
            preview2 = raw2[:PREVIEW_MAX_BYTES].decode("latin1", "replace")
            ok, _ = evaluate(
                url=url, status_code=status2, content_type=content_type2, preview=preview2
            )
        except Exception:
            ok = False
    return ok


def normalize_name(name: str) -> str:
    text = name or ""
    text = re.sub(r"[（(【\[].*?[)）】\]]", "", text)
    text = re.sub(r"FM\s*\d+(\.\d+)?", "", text, flags=re.I)
    text = re.sub(r"AM\s*\d+", "", text, flags=re.I)
    for suffix in ("调频", "广播", "电台", "频率", "之声", "之声广播", "综合频道", "频道", "台", "广播电台"):
        text = text.replace(suffix, "")
    text = re.sub(r"[\s·•-]", "", text)
    return text.lower()


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--sources",
        default="qtfm,tingfm,radio_cn,radio5",
        help="comma-separated sources to collect",
    )
    parser.add_argument("--probe-rounds", type=int, default=2)
    parser.add_argument("--apply", action="store_true", help="write stations_cn.json")
    args = parser.parse_args()

    sources = [s.strip() for s in args.sources.split(",") if s.strip()]
    candidates = collect_all(sources)
    print(f"total candidates: {len(candidates)}", flush=True)

    # probe every unique URL (use fast probe_url when provided), N rounds;
    # when the fast probe_url fails, fall back to probing the real stream URL
    # (qtfm's m3u8 host only serves a subset of channels; mp3-only channels
    # 404 there but play fine on lhttp).
    def probe_target(c: dict) -> str:
        return (c.get("probe_url") or c.get("url") or "").strip()

    def fallback_target(c: dict) -> str:
        primary = probe_target(c)
        real = (c.get("url") or "").strip()
        return real if real and real != primary else ""

    unique_targets: list[str] = []
    seen_targets: set[str] = set()
    fallbacks: dict[str, str] = {}
    for c in candidates:
        primary = probe_target(c)
        if primary and primary not in seen_targets:
            seen_targets.add(primary)
            unique_targets.append(primary)
        fb = fallback_target(c)
        if fb and fb not in seen_targets:
            seen_targets.add(fb)
            unique_targets.append(fb)
        if primary and fb:
            fallbacks[primary] = fb
    print(f"unique urls: {len(unique_targets)}", flush=True)

    passes: dict[str, int] = {u: 0 for u in unique_targets}
    for round_no in range(args.probe_rounds):
        done = 0
        with ThreadPoolExecutor(max_workers=CONCURRENCY) as pool:
            futures = {pool.submit(probe_candidate, u): u for u in unique_targets}
            for future in as_completed(futures):
                target = futures[future]
                if future.result():
                    passes[target] += 1
                elif target in fallbacks:
                    fb = fallbacks[target]
                    if probe_candidate(fb):
                        passes[fb] += 1
                done += 1
                if done % 200 == 0:
                    print(
                        f"probe round {round_no + 1}/{args.probe_rounds}: {done}/{len(unique_targets)}",
                        flush=True,
                    )

    stable_targets = {u for u in unique_targets if passes[u] == args.probe_rounds}
    print(f"stable urls (all rounds): {len(stable_targets)}", flush=True)

    # dedup by normalized name, prefer https + qtfm
    def rank(c: dict) -> tuple:
        url = c.get("url") or ""
        return (
            url.startswith("https"),
            c.get("source") == "qtfm",
            c.get("source") == "radio_cn",
            c.get("source") == "tingfm",
        )

    chosen: dict[str, dict] = {}
    for c in sorted(candidates, key=rank, reverse=True):
        if probe_target(c) not in stable_targets and fallback_target(c) not in stable_targets:
            continue
        key = normalize_name(c.get("name") or "")
        if not key:
            continue
        if key not in chosen:
            chosen[key] = c
    print(f"after name dedup: {len(chosen)}", flush=True)

    # final pass: the stored stream URL must itself play (m3u8-verified qtfm
    # channels can still have a broken mp3 link); drop any that fail.
    stored_ok: set[str] = set()
    with ThreadPoolExecutor(max_workers=CONCURRENCY) as pool:
        futures = {pool.submit(probe_candidate, c.get("url") or ""): key for key, c in chosen.items()}
        for future in futures:
            if future.result():
                stored_ok.add(futures[future])
    dropped = [k for k in chosen if k not in stored_ok]
    for k in dropped:
        print(f"drop stored-url dead: {chosen[k].get('name')} {chosen[k].get('url')}", flush=True)
    chosen = {k: v for k, v in chosen.items() if k in stored_ok}
    print(f"after stored-url verify: {len(chosen)}", flush=True)

    if not args.apply:
        print("(dry run; pass --apply to write stations_cn.json)")
        return 0

    if len(chosen) < 100:
        print("abort write: too few stable stations (possible outage)")
        return 2

    stations = []
    for i, (key, c) in enumerate(sorted(chosen.items(), key=lambda kv: kv[1].get("name") or "")):
        name = c.get("name") or ""
        region = c.get("region") or ""
        tags = [c.get("source")]
        category = "地方台" if c.get("source") in ("qtfm", "tingfm", "radio5") else "央广"
        if region:
            tags.append(region)
        station = {
            "id": f"src-{c.get('source')}-{i + 1}",
            "name": name,
            "url": c.get("url"),
            "tags": tags,
            "category": category,
            "bitrate": 64,
            "codec": "AAC" if ".mp3" in (c.get("url") or "") else "HLS",
            "homepage": {"qtfm": "https://www.qtfm.cn/", "tingfm": "https://tingfm.net/", "radio_cn": "https://www.radio.cn/", "radio5": "https://radio5.cn/"}.get(c.get("source"), ""),
        }
        stations.append(station)

    STATIONS_FILE.write_text(
        json.dumps(stations, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    print(f"wrote {STATIONS_FILE} ({len(stations)} stations)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
