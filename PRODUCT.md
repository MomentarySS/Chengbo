# Product

<!-- impeccable:product-schema 1 -->

## Platform

android

## Users

Primary audiences are treated as equal, not ranked:

- Mainland listeners on phone or PC who want a reliable domestic live station quickly, then keep it playing in the background.
- Overseas Chinese who want mainland and regional stations that local apps do not carry well.
- Desktop workers who use Windows radio as background audio while working.
- Bedtime and commute listeners who need a sleep timer, notification controls, and restore of the last station or episode into the mini player (no autoplay).

The shared job: find a playable Chinese-language live station or public RSS podcast and keep listening with one hand, without entering a copyrighted on-demand catalog.

## Product Purpose

澄波 (Chengbo) plays domestic Chinese live radio and public RSS podcasts on Android and Windows. Success is a station that actually streams, stays playing through app switches and sleep, and can be found again (favorites, recent, last session) without hunting a broken URL.

## Positioning

A curated, tested domestic station list first, plus optional Radio Browser discovery and in-app manual add — not a full internet-radio directory and not a licensed on-demand platform. Neighboring apps can copy Radio Browser; they cannot truthfully claim the same hand-maintained, connectivity-tested mainland/local set as the default catalog.

## Operating Context

- Shipped equally on **Android** and **Windows**. One Material 3 language on both; do not adapt to Fluent or Cupertino per OS. Compact width uses a 4-destination NavigationBar; width ≥ 900px uses NavigationRail.
- Typical scenes: phone in a pocket with notification controls; Windows desktop as a background player; bed with a sleep timer; commute with last-listen restore (mini player filled, tap Play to start).
- Catalog maintenance is part of the product: `assets/stations_cn.json` for stable tested streams; App settings for manual stations; Radio Browser as an optional network layer.
- Live audio is streamed, not downloaded. Podcasts stream online with playback-position memory only. Station artwork may cache to disk; live audio must not.
- Android 13+ needs notification permission for background playback and optional new-episode alerts. Windows uses `just_audio_windows`. Shake-to-extend sleep, the home widget, and Chromecast are Android-only.
- Dart package name is `chengbo`; user-facing name is 澄波 / Chengbo.

## Capabilities and Constraints

Confirmed:

- Live radio: search (300ms debounce, last 5 queries, favorite-only toggle, bitrate chips 64k+/128k+/256k+), category chips (央广 / 地方台 / 音乐 / 新闻 / 交通 and similar), favorites, recent (clearable in settings), long-press detail sheet and category override (央广 / 地方台 locked). Skip previous / next in the current filter or favorites.
- **First launch:** a full-screen onboarding sheet asks which **themes** (央广, 音乐, 新闻, 交通, etc.) and/or **provinces** to load, or「加载全部精选」(~413 stations). Nothing is pre-selected; the user must pick at least one theme or province (or all curated) before probing starts. Settings → 电台管理 → **收听范围** reopens the same editor; saving resets the probe.
- After the catalog scope is confirmed, the app probes live stream URLs concurrently and remembers which station ids played. A probe does a plain GET (like real playback, Range only as fallback) and reads a short body prefix: HLS must contain `#EXTM3U` plus a playable entry; JSON or HTML with HTTP 200 is dead; gzip-compressed responses are decoded first. The home list has a hide button on each station; hidden ids stay on-device and can be restored from Settings → 电台管理 → 已隐藏的电台. If this device keeps buffering or fails to play, that station is hidden the same way. Later launches skip probing and show the reachable set within the chosen scope (plus manual stations and on-device URL replacements), minus hidden ids. Pull-to-refresh or Settings → 电台管理 → 检测可播放的源 forces a full probe; 刷新电台列表 reloads the catalog without re-probing. Offline: connectivity banner, skip probe and Radio Browser, play/list errors say there is no network.
- Station sources in merge order: manual add (create / edit / clipboard JSON import-export; M3U/PLS playlists resolve to the first playable stream) → local curated JSON → Radio Browser (default on; scoped to selected provinces when not「全部精选」; votes, Chinese/Mandarin language, news/music/traffic tags; TW/HK/MO stay hidden until the overseas switch is on; skip name collisions; drop other countries). Theme and province filters are a **union** within the curated JSON. Overseas (港澳台) stations hidden unless the settings switch is on; 央广香港之声 and CRI stay domestic. Long-press detail can copy or share the stream URL. A dead curated or discovered station can have its stream URL replaced on-device (Settings → 电台管理 → 连不上的电台, or long-press → 更换地址) without waiting for an app update; the original URL can be restored. Stable replacements should still go back into `assets/stations_cn.json`.
- RSS podcast subscribe (fetch title/artwork on add), delete, pull-to-refresh, show notes, progress memory, OPML import/export via clipboard, and user-initiated episode download for offline play; Now Playing skip ±15s and speed 0.5–2× (0.5 / 0.6 / 0.8 / 1 / 1.25 / 1.5 / 2, remembered per feed). Per-feed skip intro/outro (0–120s). When an episode ends, play the next one in the current sort unless sleep-until-end-of-episode is on. Optional Wi-Fi-only downloads (skip on cellular). Optional new-episode notifications (off by default; at least 6 hours between RSS checks; first check records GUIDs only). Podcast Index search lives in Settings only (not the podcast tab); default hides explicit; API keys stay on device. No bundled default feeds. Live radio is never written to disk.
- Spotify-style mini player + Now Playing sheet: radio and podcast share one minimal layout (follows system light/dark; soft content-derived gradient at the top; back + Cast top bar, large rounded cover, left-aligned title, thin scrubber — podcast progress / radio volume, enlarged transport row). Podcast row: speed / −15s / play / +15s / queue. Radio row: sleep timer / previous / play / next / queue. Auxiliary chips under the title (podcast: notes / downloaded / sleep / skip intro-outro / stop; radio: live badge / stop). Queue sheet switches podcast episodes or the current station list. Sleep timer (5/10/15/20/25/30/45/60 minutes, custom, or end of the current podcast episode) with a 30-second fade-out and a 10-minute snooze that pauses now and resumes when the snooze ends. Shake-to-extend sleep is off by default (+5 minutes, Android only). ICY stream titles on Android when the live URL is not HLS, with a marquee when the line overflows; Windows has no ICY, does not send Icy-MetaData, and marshals Media Foundation callbacks to the UI thread. Android Now Playing can Cast the current URL to a default Chromecast receiver when the appearance switch is on (off by default; outline-free icon). Listening history lives under the **收听** tab's **最近** section: last 30 episodes with progress, recorded when playback actually starts (failed attempts skipped), tap to resume, exportable as JSON with stats, clearable. The **统计** section shows today / this week / total listening time, radio vs podcast share, and top 5 most-listened sources; all data stays on device and can be cleared.
- Cold start restores volume and, when「记住上次收听」is on (default), fills the mini player with the last station or episode. Playback does not start until the user taps Play.
- Settings: appearance (follow system / light / dark), wallpaper or system accent colors (Android 12+ Material You; Windows accent; Chengbo blue fallback), remember last listen, shake-to-extend sleep, new-episode notifications (off by default; 6-hour minimum; first check records GUIDs only), artwork cache clear, Wi-Fi-only podcast download, clear recents, Podcast Index search, 播客管理（RSS 订阅、OPML 导入导出、订阅数量）, 电台管理 (收听范围, probe playable sources, refresh catalog, unreachable stations, Radio Browser, overseas, manual add), in-app [privacy copy](PRIVACY.md). Android home widget shows title plus play/pause.
- Android 13+ requests notification permission at launch. Current version `1.5.0+29`. Pack with `scripts/pack.ps1` to `dist/chengbo-1.5.0.apk` and `dist/chengbo-windows-1.5.0.zip` (release-signed when `android/key.properties` is present, minSdk 23). Windows builds need Visual Studio 2022 Build Tools with C++ ATL. Desktop HTTP follows the system proxy and common local Clash ports so public RSS hosts such as SoundOn can be fetched.

Binding bans:

- No retro full-screen radio / tuner-scale UI.
- No Ximalaya / Qingting (蜻蜓 FM) copyrighted on-demand catalogs.
- Do not cache live audio to disk as recordings. Podcast episode files are stored only when the user taps download.

Known gaps (not shipped):

- No live radio EPG / program-guide tab. Do not scrape 蜻蜓 / 云听 or invent schedules.
- Radio Browser is CN + Chinese/Mandarin language + votes / news / music / traffic / more provinces, plus TW/HK/MO that stay hidden until the overseas switch is on. It is not a global directory and must not pull copyrighted catalogs.
- Shake-to-extend sleep, the home widget, and Chromecast are Android-only. Windows keeps a frameless floating desk mini bar (not a Win11 widget board).
- iOS and web are out of scope unless the product record changes. Live recording stays out of scope.

## Brand Commitments

- Display name: **澄波**. English slug: **Chengbo**. Tagline: **听国内广播**.
- UI copy is Chinese.
- User-Agent: `Chengbo/1.5.0 (Flutter; chengbo radio)`.
- License: MIT.
- Package/org are `chengbo` / `com.chengbo.chengbo`. Windows binary is `Chengbo.exe`.

## Evidence on Hand

- Curated stations: `assets/stations_cn.json` (about 413 tested streams, rebuilt 2026-08-19 from 蜻蜓省市级 + 央广官方 + 广东本地补充; after first-launch scope selection the app probes within that scope, or on Settings → 电台管理 → 检测可播放的源, and hides unreachable URLs from the home list).
- Podcasts start empty; users add public RSS feeds in the app.
- Branding sources: `assets/branding/app_icon.png`. Launcher assets live under `android/` and `windows/runner/`.
- Product and backlog truth: `README.md`, `DEVELOPMENT.md`.
- No testimonials, press, usage metrics, or paid-customer proof. Future work must not invent them.

## Product Principles

1. **Playable beats plentiful.** Prefer a shorter list of tested domestic streams over an unverified global directory. Do not grow `assets/stations_cn.json` for coverage; delete streams whose GET body is not a playlist or audio (JSON/HTML 200 counts as dead).
2. **Stay a public-radio player.** Live streams and public RSS only; never become a licensed on-demand catalog.
3. **Listening continues while the rest of the app is used.** The mini player is the persistent control; radio, podcasts, and favorites are destinations around it.
4. **Phone and desktop are the same product.** Compact (background, notifications, sleep) and expanded Windows (rail, desk listening) get equal care under one Material language.
5. **The listener can fix a dead stream.** Manual add and curated JSON exist because third-party URLs expire; discovery is optional, not the only path.
