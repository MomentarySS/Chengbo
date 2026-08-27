# 四个高优先级功能实现方案

---

## Feature 1: 跳过片头/片尾 ⏮️

### 现状
- 15s 前进/后退已实现，但片头片尾无法自动跳过
- 每集固定片头（品牌口播）和片尾（引流信息）无法设置

### 改动文件

**`lib/core/audio/podcast_playback.dart`**
- `skipIntro` / `skipOutro` 常量（默认 0 秒）
- `clampSeek` 增加 intro 参数：后退时 clamp 到 `skipIntro` 而不是 0

**`lib/core/storage/app_storage.dart`**
- 新增 `_podcastSkipIntroPrefix` / `_podcastSkipOutroPrefix` key
- `getPodcastSkipIntroSeconds(feedId)` / `setPodcastSkipIntroSeconds(feedId, seconds)`
- `getPodcastSkipOutroSeconds(feedId)` / `setPodcastSkipOutroSeconds(feedId, seconds)`

**`lib/core/audio/radio_audio_handler.dart`**
- `_startPlayback` 加载播客时，从 storage 读取 skip 值，seek 到 `skipIntro` 位置（仅首次播放时）
- 前进/后退按钮用 `skipStep` 替代硬编码的 15 秒

**`lib/shared/widgets/podcast_now_playing.dart`**
- 在 `_EpisodeChips` 添加「跳过片头/尾」ActionChip，打开新的 BottomSheet

**`lib/shared/widgets/podcast_skip_sheet.dart`（新建）**
- BottomSheet：两个 Slider（片头跳过秒数、片尾跳过秒数），每档 [0, 5, 10, 15, 20, 30, 45, 60]
- 按 feedId 记忆，关闭 sheet 时自动保存

---

## Feature 2: 睡眠定时器增强 🌙

### 现状
- 预设 [15, 30, 45, 60] 分钟，无淡出，无小睡

### 改动文件

**`lib/core/audio/sleep_timer.dart`**
- `presetMinutes` 改为 `[5, 10, 15, 20, 25, 30, 45, 60]`（移除 5 分钟限制也可以用自定义）
- `SleepTimerState` 新增 `snoozedUntil` DateTime? 字段
- `SleepTimerLogic` 新增 `fadeOutSeconds = 30`，`snoozeMinutes = 10` 常量
- `SleepTimerNotifier`：
  - `stopBecauseTimer` 前 30 秒开始音量渐降（调用 `audioHandler.setVolume`）
  - 新增 `snooze()` 方法：暂停播放 + 重设定时器 +10 分钟

**`lib/core/audio/radio_audio_handler.dart`**
- 新增 `setVolume(double)` 方法（通过 `_player.setVolume`）
- `stopBecauseTimer` 改为调用 `SleepTimerNotifier.snooze()`（先淡出再停）

**`lib/shared/widgets/sleep_timer_sheet.dart`**
- 预设 chip 增加更多选项
- 定时进行中时，新增「小睡 10 分钟」按钮（暂停 + 延长）
- 时间显示加入「淡出倒计时」提示（最后 30 秒时显示）

**`lib/shared/widgets/mini_player.dart`**
- 睡眠定时激活时，mini player 显示「剩余 X 分钟 + 淡出」提示

---

## Feature 3: 播客下载管理增强 📥

### 现状
- 有总大小显示，有全局自动清理，有按 feed 删除
- 无单集大小、无 WiFi-only、无批量下载

### 改动文件

**`lib/core/audio/podcast_download.dart`**
- `PodcastDownloadRecord` 已有 `bytes` 字段（已支持）

**`lib/features/podcast/podcast_screen.dart`**
- `_EpisodeTile` subtitle 显示已下载文件大小（formatBytes）
- `_DownloadAllTile` 增加下载集数选择（最近 3/5/10 集下拉菜单）

**`lib/core/storage/app_storage.dart`**
- 新增 `_downloadWifiOnlyKey` 布尔设置
- 新增 `_downloadAutoCleanupPerFeedKey` Map（feedId → 保留集数）
- `getDownloadWifiOnly()` / `setDownloadWifiOnly(bool)`

**`lib/features/podcast/podcast_providers.dart`**（`PodcastDownloadsNotifier`）
- 下载前检查：若 `wifiOnly=true` 且非 WiFi 网络，skip 并记录
- 批量下载：新增 `downloadRecent(feed, count)` 方法

**`lib/features/podcast/podcast_detail_screen.dart`**（新建或扩展）
- 显示该 feed 总下载大小
- 每个 episode tile 显示单集文件大小
- Feed 设置弹窗：WiFi-only 开关 + 保留集数

**`lib/features/settings/data_management_screen.dart`**
- 总下载大小拆分为「播客缓存」和「其他」
- 新增「WiFi 下载」开关

---

## Feature 4: 电台搜索增强 🔍

### 现状
- 按 name/tags 搜索，有分类 chip 过滤
- 无 bitrate/codec 过滤、无收藏内搜索、无搜索历史

### 改动文件

**`lib/features/radio/radio_screen.dart`**
- 搜索框右侧新增「收藏」过滤 toggle icon button
- 搜索框下方新增一行 bitrate filter chips：[全部, 64k+, 128k+, 256k+]

**`lib/features/radio/radio_providers.dart`**
- `filteredStationsProvider`：
  - 支持 `bitrateFloor` 过滤（null 表示不限制）
  - 支持 `favoritesOnly` 过滤
  - `stationSearchProvider` 改为 `StationSearchState`（包含 query + bitrateFloor + favoritesOnly）

**`lib/core/storage/app_storage.dart`**
- 新增 `_radioSearchHistoryKey` ListString
- `getRadioSearchHistory()` / `addToRadioSearchHistory(query)` / `clearRadioSearchHistory()`
- 新增 `_lastRadioBitrateFloorKey` int?

**`lib/features/radio/radio_screen.dart`**
- 搜索框获得焦点时显示历史记录下拉列表（最近 5 条，点击清空历史）
- 搜索建议列表：历史 + 空状态提示「在收藏中搜索」

**`lib/shared/widgets/station_list_tile.dart`**
- 电台 tile 显示 bitrate 标签（如果有）

---

## 实施顺序建议

每个 feature 独立改动不同文件，建议按以下顺序实现（相互无依赖）：

1. **Feature 4（电台搜索）** — 最独立，改动最少，适合先做
2. **Feature 2（睡眠定时）** — 逻辑清晰，改动集中
3. **Feature 1（跳过片头/片尾）** — 涉及播放链路，放后面
4. **Feature 3（下载管理）** — UI 改动多，放最后

每个 feature 完成后单独 commit，方便回溯。