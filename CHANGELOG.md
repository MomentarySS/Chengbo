# CHANGELOG

All notable changes to **澄波 (Chengbo)** are documented here.

Format follows [Keep a Changelog](https://keepachangelog.com/zh-CN/), and the project follows [Semantic Versioning](https://semver.org/lang/zh-CN/).

---

## 1.4.8 / 2026-08-19

- **移除收听统计页热力图**：近 26 周 GitHub 风格热力图整体移除；统计页保留累计收听、今日/本周、电台 vs 播客占比条、最常收听 Top 5，表达收听时长信息不丢失，界面更清爽。

---

## 1.4.7 / 2026-08-19

- **内置电台列表重建为 413 台**：`assets/stations_cn.json` 从 265 台重建为 **413 台**（蜻蜓省市级 + 央广官方 19 + 广东本地补充 东莞等）。来源从 4 个网站抓取：蜻蜓 FM `radiopage` 各省级频道（GraphQL `radioPage(cid, page){contents}`，流地址统一为 `https://lhttp.qtfm.cn/live/{id}/64k.mp3`，31 省全覆盖）、央广网官方 `appBroadcast/list`（签名 API，含中国之声/经济之声/大湾区之声等 19 套央广频率）。每台经两轮全量探测 + 最终存储 URL 复验（含 gzip 解压、重定向跟随、普通 GET 优先），按 URL 与规范化台名去重，只保留两轮全过且存储链接可播的台。
- **电台探测逻辑修正**：`StreamUrlTester` 与 `tools/stream_content.py` 原为 Range 请求优先，蜻蜓等 CDN 对 Range 回 404 导致误杀；现改为普通 GET 优先（等价真实播放），Range 仅兜底，并支持 gzip 解压（新城电台等源的 m3u8 带 gzip 压缩）。探测语义同步更新。
- **新增电台目录维护工具**：`tools/rebuild_curated_stations.py` 从蜻蜓 / 央广 / tingfm / radio5 四源收集、探测、去重并重建精选 JSON，带断点缓存（`tools/_scrape_cache/`）；`tools/prune_dead_stations.py` 按需清理死链。
- 遗留：tingfm（港澳台/网络台）与 radio5 因目标站限流暂未并入，脚本可在限流解除后补跑合并。

对应版本：`1.4.7+27`（Android `versionCode` 27）。

- **广东电台列表补充东莞**：运行 `tools/merge_gd_stations.py` 恢复东莞阳光 1008 与东莞畅享 1075 两台，流地址经 HLS 播放列表验证可用。广东精选列表从 56 台恢复为 58 台，21 个地级市全覆盖。

---

## 1.4.6 / 2026-08-18

- **Windows 电台卡住修复**：`just_audio_windows` 的事件回调原来把 `PlaybackStateChanged` 等事件 Post 到 UI 线程再发 `EventSink`，导致 Dart 端永远收不到播放状态更新——MF 其实已在播放但 UI 一直停在「正在缓冲」，18 秒后看门狗重试陷入循环。修复为与官方实现一致：直接在 Media Foundation 回调线程发送事件，保留 `mutex_` 与 `disposed_` 线程安全保护。另移除播放前对 `mediaPlayer.Play()` 的重复调用与 load 末尾的 `broadcastState()`（会用过期的 None/Opening 状态覆盖 Playing 事件），恢复 `loadSource` 开头的 `Pause()` + `Source(nullptr)` 换源清理。
- **「未听」分页移除**：收听 tab 的「未听」分页因跨订阅逐个拉取 RSS 导致加载很慢，直接删除；inbox 相关 provider 与逻辑（`inboxProvider`、`PodcastInboxLogic`、`EpisodeWithFeed`）一并清理。收听 tab 恢复为 收藏 / 最近 / 统计 三段。
- **长按菜单统一替换列表常驻按钮**：电台列表、播客订阅列表、播客单集列表均移除右侧常驻 hide/favorite / 下载 / 简介按钮，改为长按弹出底部菜单，菜单包含播放、收藏/取消收藏、复制地址、分享、删除，列表更清爽。
- **电台长按菜单补回收藏**：用户反馈去掉收藏入口后不便使用，现重新加入长按菜单，并根据当前是否已收藏动态显示「收藏」或「取消收藏」。
- **播客订阅列表长按菜单**：新增长按底部菜单，支持播放最新、复制 RSS 地址、分享、删除订阅；列表项 trailing 删除按钮同步移除。
- **播客单集长按菜单**：长按单集弹出底部菜单，支持查看简介、加入播放队列、下载到本机 / 删除下载、复制音频地址、分享；列表项 trailing 下载 / 简介按钮同步移除。
- **设置页「源」改名为「电台管理」**：入口名称与图标同步更新，更清晰表达该页负责电台相关内容。
- **收听 tab 曾短暂增加「未听」分页后移除**：播客主页的「未听单集 inbox」先移到「收听」tab，因加载慢最终整体删除。
- **Now Playing 顶部栏标题精简**：电台与播客两款播放器顶部去掉「电台」「播客」标题文字，保留返回按钮与投屏按钮。

对应版本：`1.4.6+26`（Android `versionCode` 26）。

---

## 1.2.13 / 2026-08-18

- **播客进度跨单集污染修复**：`RadioAudioHandler._currentItem` 原来在 `playItem` 开头就换成新单集，早于 `_safeStop()` 执行，切换窗口内旧单集的实时位置会被写进新单集的进度 key，导致新一期"不是从最开始播放"。修复后 `_currentItem` 赋值延迟到 `_safeStop()` 之后，且 `_emitPlayError` 改为显式传入目标单集，避免错误报告对象。
- **已听完单集重播修复**：播完后的进度等于完整时长，重播时 seek 到结尾会立即触发 completed → 自动跳到下一集，导致无法从头重听。seek 前用 `PodcastPlaybackLogic.isFinished` 判断，已听完的单集从头开始。
- **自动推进只在真正播完时触发**：原来 `onPositionTick` 在播到 95%（或剩余 ≤15 秒）就提前标记已听并推进队列下一集，长节目尾段被截断，且与 feed 自动下一集竞争。现在提前推进逻辑全部移除，只在 `processingState == completed` 时统一处理：标记已听 → 检查睡眠定时 → 手动队列优先 → feed 自动下一集。
- **播客单集自然排序**：国内 RSS 常缺发布日期，标题 fallback 改用自然序比较（数字段按数值比），避免 `#1 → #10 → #100 → #2` 的字典序错乱，且排序方向跟随「最新在前 / 最早在前」模式。
- **Now Playing 顶部栏统一**：两款播放器去掉顶部的「电台」「播客」标题文字，间距统一为 8，节目名和播客名/台名改为居中对齐。
- **进度写盘节流**：播客进度从每 200ms 写一次 SharedPreferences 改为最多每秒一次，暂停、停止、播完时强制落盘，减少平台通道调用次数。
- **版本号同步修复**：`lib/core/brand.dart` 版本号与 `pubspec.yaml` 不同步的问题修正。

对应版本：`1.2.13+25`（Android `versionCode` 25）。

---

## 1.2.12 / 2026-08-18

- **搜索播客移到播客管理页**：设置里「搜索播客（Podcast Index）」入口从「关于」页移到「播客管理」页，与添加 RSS、导入/导出 OPML 并列；关于页移除该入口。
- **设置页重新排序**：新顺序为 播客管理 → 电台管理 → 播放与收听 → 外观 → 数据管理 → 电台分类 → 关于；关于副文改为「版本、隐私说明」。
- **热力图空数据修复**：`_HeatCell._computeLevel` 在 `maxValue == 0` 时从返回 `1`（浅色模式下近透明绿）改为返回 `0`（空单元格灰），避免无数据时全部格子看起来失效。
- **收听统计持久化修复**：`ListeningStatsLogic.compact` 日期 key 解析从 `DateTime.tryParse(key.replaceAll('-', ''))` 改为 `DateTime.tryParse(key)`，因为 `dayKey` 生成标准 `YYYY-MM-DD`，去掉横杠后 Dart 不认，导致历史天数被静默丢掉。
- **Now Playing 标题居中修复**：`NowPlayingTopBar` 左侧 `IconButton` 加 `SizedBox(40×40)` 约束，消除隐形触控区，使「电台」「播客」标题视觉居中。
- **桌面迷你窗点击穿透修复**：`DeskMiniBar` 两个 `GestureDetector`（主条区域 + 圆形封面）加 `onTapDown` 消费点击，避免无边框窗口下首次点击穿透到下层 Scaffold 触发导航。

对应版本：`1.2.12+24`（Android `versionCode` 24）。


## 1.2.10 / 2026-08-17

- **播客管理进入设置页**：设置新增「播客管理」入口，集中放置「添加 RSS 订阅」「从剪贴板导入 OPML」「导出 OPML 到剪贴板」三项操作；入口副文为「RSS 订阅、OPML 导入导出」。
- **订阅数量实时展示**：播客管理页顶部监听 `subscribedFeedsProvider`，加载态、空态、出错态均有占位，数据就绪后显示「共 N 个订阅」。
- **播客页去除三项操作**：订阅列表内的「添加 RSS」「导入 OPML」「导出 OPML」三个 `ListTile` 移除，仅在设置「播客管理」操作；不再被调用的 `_exportOpml` 静态方法一并清除。
- **空状态引导保留**：没有订阅时的空状态仍保留「添加 RSS」和「导入 OPML」两个按钮，作为首次使用的引导入口。

对应版本：`1.2.10+22`（Android `versionCode` 22）。

---

## 1.2.9 / 2026-08-17

- （见 DEVELOPMENT.md 历史记录）

---

## 1.2.8 / 2026-08-17

- 播客主页增加搜索框，按订阅标题搜索，搜索时隐藏继续收听卡片和 inbox。

---

更早版本记录见 [DEVELOPMENT.md](DEVELOPMENT.md)。
