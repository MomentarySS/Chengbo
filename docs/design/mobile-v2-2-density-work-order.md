# v2.2 实施工单 — 播客详情页 + 播客播放器页瘦身（8 条）

> 范围：播客**详情页**与播客**播放器页**的高度瘦身，共 8 条（用户已逐条批准）。
> 上游效果图：[`podcast-density-design.html`](./podcast-density-design.html)（before/after + 逐条取舍，浏览器打开）
> 关联设计：[`mobile-v2-1-plan.md`](./mobile-v2-1-plan.md) §9「不做」清单
> 状态总览：[`v2-1-release-tracker.md`](./v2-1-release-tracker.md)
> 前置：PR #9（`feat/radio-page`：两页共享规格 + 电台页三处）、PR #10（`fix/podcast-episode-menu`）**均已合 main**，main = `dd8990c`
> **不在本工单**：版本 bump / CHANGELOG / ROADMAP / tag / `gh release` / `pack.ps1` 重建产物 —— v2.2.0 收尾另起，动前先问用户

---

## 1. 目标

两个页面都不缺功能，缺的是**层级**：低频设置与重复入口占了最高频的位置。

| 页面 | 指标 | 现状 | 目标 | 收益 |
|---|---|---|---|---|
| 详情页 | 头部 chrome 高度 | 394px（52% 屏高）| 228px（30%）| 首屏 2.5 条 → 4–5 条单集 |
| 播放器页 | 内容高度 | 754px（99%，刚好塞满）| 573px（75%）| 余量 ~25%，矮屏不再挤 |

（760dp 屏估算，见效果图「首屏高度账」）

### 8 条一览

| # | 页面 | 改动 | 省 | 取舍 |
|---|---|---|---|---|
| D1 | 详情页 | 三个下载开关 → 一行「下载设置」入口 + bottom sheet | ~145px | 低频项从常驻变一次点击 |
| D2 | 详情页 | 单集标题 `maxLines: 2` | ~24px/行 | 长标题要长按看全（菜单里有完整标题）|
| D3 | 详情页 | `仅WiFi下载` 移到设置 | ~48px | 全局开关不再挂在本页 |
| D4 | 详情页 | 顶栏去掉「选择多项」图标 | — | 批量下载：1 次点击 → 长按 + 1 次点击 |
| P1 | 播放器 | 5–6 个 chip → 一行纯图标按钮 | ~72px | 可发现性下降，靠 tooltip + Semantics 兜 |
| P2 | 播放器 | `跳过片头/尾` 移出 → 详情页「下载设置」面板 | — | 入口变远；已设值不丢 |
| P3 | 播放器 | `停止` 去掉 | — | 全屏页少一个停止入口（迷你条 ✕ 覆盖）|
| P4 | 播放器 | 封面限高 | 已由 PR #9 覆盖 | 是否更激进（屏高 38%）→ 待拍板 |

---

## 2. 起点与基线（已在本机核实）

| 项 | 值 | 核实方式 |
|---|---|---|
| main | `dd8990c`（PR #9 + #10 已合）| `git log --oneline -3 origin/main` |
| 新分支 | `feat/podcast-density`（已从 main 开）| `git branch --show-current` |
| `flutter test` | **143/143 通过** | `flutter test` |
| `flutter analyze` | **23 info**（全仓，0 warning / 0 error）| `flutter analyze` |

23 条 info 分布（**全部为既有基线，不是本工单的修复目标**）：

- `test/layer_test.dart` 13 条（`prefer_const_constructors`）
- `lib/shared/widgets/podcast_skip_sheet.dart` 4 条（`unnecessary_brace_in_string_interps`）
- `test/key_screens_test.dart` 1 条、`lib/core/audio/playback_session.dart` 1 条、`lib/core/providers/app_providers.dart` 1 条、`lib/core/storage/device_backup.dart` 1 条、`lib/features/radio/radio_screen.dart` 1 条、`lib/shared/widgets/sleep_timer_sheet.dart` 1 条

**本工单目标：改到的文件 0 issue；全仓 ≤ 23 info（不许涨）。**

---

## 3. 逐条改法

### 3.1 D1 —— 三个下载开关收成一行「下载设置」入口

**现状**（`lib/features/podcast/podcast_screen.dart`）：

- `_DownloadAllTile`（:653–800）在 ListView 里占 **1 个 item**，内部是 `Column`：
  - `SwitchListTile 全部下载`（:682–708）
  - `SwitchListTile 自动下载最新一集`（:709–727）
  - 一行 `仅WiFi下载 开关 + 最近几集 下拉`（:729–796）
- 挂载点：:583–585；`leadingCount`（:552–553）已按「1 个 item」计数 → **改后计数不变**

**改法**：

1. `_DownloadAllTile` → `_DownloadSettingsTile`，只渲染**一行** `ListTile`：
   - `leading: Icon(Icons.download_for_offline_outlined)`（沿用现有图标）
   - `title: Text('下载设置')`
   - `subtitle:` 一行状态摘要（见下），`maxLines: 1, overflow: TextOverflow.ellipsis` —— **必须单行**，否则吃回省下的高度
   - `trailing: Icon(Icons.chevron_right)`
   - `onTap: () => showPodcastDownloadSettingsSheet(context, feed: feed, episodes: episodes)`

2. 新建 `lib/shared/widgets/podcast_download_settings_sheet.dart`：
   - `showModalBottomSheet(..., showDragHandle: true, isScrollControlled: true, builder: (ctx) => SafeArea(child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, ...))))`
   - **必守**（见 §7 已知坑）：① 内容**不能有 flex 子项**（`Expanded` / `Flexible`），否则撑满全屏；② 必须 `isScrollControlled: true` + 自带滚动容器，否则尾部被屏高 9/16 上限**静默裁掉**
   - 条目（4 条，顺序固定）：

     | 条目 | 控件 | 说明 |
     |---|---|---|
     | 全部下载 | `SwitchListTile` | 沿用 :682–708 的文案与逻辑；打开前 `ensureCanDownload(context, ref)` **不能丢** |
     | 自动下载最新一集 | `SwitchListTile` | 沿用 :709–727；打开前同样过 `ensureCanDownload` |
     | 最近几集 | `ListTile` + `trailing: DropdownButton<int>`（3 / 5 / 10）| 沿用 :746–793 的 `recentPendingForDownload` 与两条 SnackBar 文案；同样过 `ensureCanDownload` |
     | 跳过片头/尾 | `ListTile`（副文显示当前值）| 点开现有 `showPodcastSkipSheet`，见 §3.6 |

   - **`仅WiFi下载` 不进这个面板** —— D3 把它挪到设置

3. 状态摘要用**纯函数**（新增到 `lib/core/audio/podcast_download.dart` 的 `PodcastDownloadLogic`，便于 `layer_test` 守卫）：

```dart
/// 「下载设置」入口行的一行摘要。默认态给「按需下载」，非默认态逐项追加；
/// 任何状态组合下都保持**单行**可读，且不显示未发生的状态。
static String downloadSettingsSummary({
  required int total,
  required int ready,
  required int downloading,
  required bool allEnabled,
  required bool latestEnabled,
  required int skipIntroSeconds,
  required int skipOutroSeconds,
}) {
  final parts = <String>[
    if (downloading > 0) '正在下载 ${ready + downloading}/$total',
    if (downloading == 0 && ready > 0) '已下载 $ready/$total 集',
    if (allEnabled) '全部下载 开',
    if (latestEnabled) '自动下载最新 开',
    if (skipIntroSeconds > 0) '跳过片头 ${PodcastPlaybackLogic.skipDurationLabel(skipIntroSeconds)}',
    if (skipOutroSeconds > 0) '跳过片尾 ${PodcastPlaybackLogic.skipDurationLabel(skipOutroSeconds)}',
  ];
  return parts.isEmpty ? '按需下载' : parts.join(' · ');
}
```

   - `skipDurationLabel(int seconds)` 是**新增**的纯函数（放在 `PodcastPlaybackLogic`，`lib/core/audio/podcast_playback.dart`，与 `skipDurationOptions` :41 相邻）：`0 → '0:00'`、`30 → '0:30'`、`90 → '1:30'`、`120 → '2:00'`。与 `podcast_skip_sheet.dart` 的私有 `_formatSeconds` 口径一致，但**不改那个文件**（见 §9 冲突面）

**语义边界**：

- 摘要必须**随状态实时变** → `_DownloadSettingsTile` 要 `ref.watch` 全部 4 个来源：`podcastDownloadAllFeedsProvider` / `podcastDownloadLatestFeedsProvider` / `podcastDownloadsProvider`（仅 `select(records)`）/ 跳过片头尾存储值
- 下载进度 tick 会高频重绘：沿用 :519–521 的既有约定 —— 只 `select((s) => s.records)`，**不要** watch 整个 `podcastDownloadsProvider`，否则每块进度都重排整页列表
- `_selecting == true` 时该行仍不渲染（`showDownloadBar = !_selecting`，:552 不变）
- 跳过片头尾值来自 `AppStorage`（异步）→ 摘要用 `appStorageProvider.future` 读取；读取完成前显示不含跳过段的摘要（**不要**整行消失）

### 3.2 D2 —— 单集标题 `maxLines: 2`

**现状**：`_EpisodeTile` 的 `title: Row(...)`（:873–891）里 `Text(episode.title, ...)` **无 maxLines** → 长标题占 3 行。

**改法**：给该 `Text` 加 `maxLines: 2, overflow: TextOverflow.ellipsis`（:876–879）。`Row` + `Expanded` + 星标结构不动。

**语义边界**：

- 长按菜单第 1 行是 `Text(episode.title)`（:1037，无 maxLines）→ **完整标题仍可见**，这是本条的取舍前提
- `紧凑列表`（`listDensityCompactProvider`，:859–861）必须继续生效；2 行标题 + `visualDensity.compact` 下 `ListTile` **不得溢出**（用 §6 守卫测试断言 `tester.takeException()` 为 null）
- 副标题（:892–922）含进度条，`ListTile` 高度本来就随内容增长 → 多 1 行标题不会触发 `isThreeLine` 类断言

### 3.3 D3 —— `仅WiFi下载` 移到设置

**现状**：只出现在 :729–745（读 `downloadWifiOnlyProvider`，定义在 `lib/features/podcast/podcast_providers.dart:426`）。它是**全局**开关 —— 全局设置挂在「某个节目」页里 = 语义错位。

**改法**：

1. 删除详情页 :729–745 的 `仅WiFi下载` 开关（`最近几集` 迁入下载设置面板，见 §3.1）
2. 在 `lib/features/settings/playback_screen.dart` 的「播客」section（:166 起）**首条**插入：

```dart
ref.watch(downloadWifiOnlyProvider).when(
      data: (enabled) => SwitchListTile(
        secondary: const Icon(Icons.wifi_outlined),
        title: const Text('仅WiFi下载'),
        subtitle: const Text('蜂窝网络下不自动开始下载'),
        value: enabled,
        onChanged: (value) => ref.read(downloadWifiOnlyProvider.notifier).set(value),
      ),
      loading: () => const ListTile(
        leading: Icon(Icons.wifi_outlined),
        title: Text('仅WiFi下载'),
        trailing: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (error, _) => ListTile(
        leading: const Icon(Icons.wifi_outlined),
        title: const Text('仅WiFi下载'),
        subtitle: Text('加载失败: $error'),
      ),
    ),
```

   - `playback_screen.dart` 已 import `../podcast/podcast_providers.dart`（:16）→ **无需新增 import**
   - 三态写法与同页其它开关一致（:186–231 为范式）

**语义边界**（**这条最容易做漏**）：

- `ensureCanDownload`（:54–77）读的就是 `downloadWifiOnlyProvider` → **「全部下载」打开时仍然遵守它**。D3 只搬 UI，**不改校验**。搬到设置后，用户在蜂窝网下开「全部下载」会收到既有 SnackBar（`NetworkStatusLogic.wifiOnlyBlocked`）—— 行为与今天一致
- 播客播放器页的下载图标走同一个 `ensureCanDownload` → 不受影响
- `podcast_providers.dart` 的 `downloadLatestIfEnabled` / 后台自动下载也读同一个 provider（:472）→ 不受影响

### 3.4 D4 —— 顶栏去掉「选择多项」图标

**现状**：:459–464 的 `IconButton(tooltip: '选择多项', icon: Icons.checklist, onPressed: _enterSelect)`。

**改法**：删除该 `IconButton`；非选择态的 `else ...[` 分支只留 `PopupMenuButton<_DetailMoreAction>`。

**语义边界**：

- 长按菜单第 4 项就是 `选择多项`（:1069–1076，调 `onEnterSelect()`）→ **入口仍存在**，`_enterSelect` 不会变死代码
- 选择态（`_selecting == true`）下的 `全选 / 下载所选` 两个按钮（:431–458）**不动**
- Windows 端鼠标右键也能开菜单（`GestureDetector.onSecondaryTap`，:856）→ 桌面端批量下载仍可达

### 3.5 P1 —— chips 收成一行纯图标按钮

**现状**：`_EpisodeChips`（`lib/shared/widgets/podcast_now_playing.dart:271–396`）是 `Wrap`，两行 ~120px，最多 6 个 `ActionChip`：简介 / 已下载 / 取消下载 / 下载 / 睡眠定时 / 跳过片头尾 / 书签 / 停止。

**改法**：`Wrap` → 一行 `Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly)`，纯图标：

| 原 chip | 新图标 | 交互 | 无障碍 |
|---|---|---|---|
| 简介（`hasNotes`）| `Icons.notes_outlined` | `IconButton` → `showPlaybackNotesSheet` | `tooltip: '简介'` |
| 下载 / 重新下载 | `Icons.download_outlined` | `IconButton` → `startDownload`（保留 `ensureCanDownload`）| `tooltip: '下载'` / `'重新下载'` |
| 取消下载（downloading）| `Icons.cancel_outlined` | `IconButton` → `cancel(guid)` | `tooltip: '取消下载'` |
| 已下载（ready）| `Icons.download_done` | **静态 `Icon`**（现状也是不可点的 `Chip`）+ `Tooltip` + `Semantics(label: '已下载')` | 不引入「可点但无动作」的假按钮 |
| 睡眠定时 | `Icons.bedtime_outlined` / `Icons.bedtime`（active 时主色）| `IconButton` → `showSleepTimerSheet` | `tooltip: '睡眠定时'` / `'关闭睡眠定时'` |
| 书签 | `Icons.bookmark_outline` | `IconButton` → `showEpisodeBookmarkSheet`（`guid == null` 时 `onPressed: null`）| `tooltip: '书签'` / `'书签 · N'` |

**语义边界**：

- **每个图标必须保留 `tooltip`**；`:322–325` 那条「已下载 chip 与兄弟标签中心对齐」的长注释随 `Wrap` 一起删（新布局不再有 `WrapCrossAlignment` 问题）
- 书签数 `bookmarkCount > 0` 时用 badge 小点或 `IconButton.isSelected` 表达；**不要**在图标旁塞文字（会破坏单行）
- 图标数量随状态在 **2–4 个**之间浮动（简介 / 下载态 / 书签）→ `Row` 用 `spaceEvenly`，**不要** `Expanded`（数量变化时不会互相拉扯）
- 移除「停止」后本文件不再调 `playerControllerProvider.stop()`；`playerControllerProvider` 仍被 `_TransportRow.onToggle` 使用 → **import 保留**

### 3.6 P2 —— `跳过片头/尾` 移出播放器

**现状**：`podcast_now_playing.dart:364–369` 的 chip → `showPodcastSkipSheet(context, feedId: current.feedId!)`。它是**按节目**的持久设置（`AppStorage.getPodcastSkipIntro/Outro`，key 前缀 `podcast_skip_intro_` / `podcast_skip_outro_`，`lib/core/storage/app_storage.dart:482–495`），不是播放动作。

**改法**：

1. 删除播放器里的该 chip（:364–369）**及** `podcast_skip_sheet.dart` 的 import（否则 analyze 报 unused import）
2. 在「下载设置」面板里加一条 `ListTile`：
   - `leading: Icon(Icons.skip_next_outlined)`、`title: Text('跳过片头/尾')`
   - 副文显示当前值（如 `片头 0:30 · 片尾 0:00`；都未设时 `未设置`）
   - `onTap:` `await showPodcastSkipSheet(context, feedId: feed.id);` **返回后重新读存储刷新副文**
3. 存储层与 `showPodcastSkipSheet` 本体**不改** → 已设值天然不丢

**语义边界**：

- 副文需在嵌套 sheet 关闭后刷新 → 面板做成 `ConsumerStatefulWidget`：`_load()` 读 `appStorageProvider.future`，`await` 嵌套 sheet 后再次 `_load()`
- **嵌套 sheet** 是本次唯一的交互取舍（面板之上再 push 一个 sheet）。备选：把两组 `ChoiceChip` 直接嵌进面板（复用 `PodcastPlaybackLogic.skipDurationOptions`）→ 面板变高，靠 `SingleChildScrollView` 兜住。见 §10 待拍板 #2
- 移出后播放器**不再**有跳过片头尾入口；**自动跳过行为完全不变**（`radio_audio_handler.dart:46–56`、`:302`、`:479–488`）

### 3.7 P3 —— `停止` 去掉

**现状**：`podcast_now_playing.dart:387–392` 的 chip → `playerControllerProvider.stop()`。

**改法**：删除该 chip。

**语义边界**：

- **迷你条 ✕ 就是同一个动作**：`lib/shared/widgets/mini_player.dart:195–199`，`tooltip: '停止'`，`onPressed: playerControllerProvider.stop()` —— 语义完全一致，且迷你条常驻 home shell（`home_shell.dart:163`）
- 电台播放器控制行本来就没有停止键（`radio_now_playing.dart:425–479`：睡眠定时 / 上一台 / 播放 / 下一台 / 播放列表）→ 去掉后**两页一致**，这正是本次的既定目标
- 播放器页是全屏路由，迷你条被盖住 → 想停止需**先关播放器页再按 ✕**（两步）。这是用户已知并接受的取舍，列入 §6.4 真机确认清单

### 3.8 P4 —— 封面限高（**已由 PR #9 覆盖**）

**现状**：`_Cover`（`podcast_now_playing.dart:151–186`）已是 `math.min(min(maxWidth, maxHeight), ChengboSkinTheme.anchorMaxSide)`，`anchorMaxSide = 300`（`lib/core/theme/app_skin.dart:307`）→ 随可用高度收缩，两页共用同一规格。

**本工单动作**：**不改代码**。是否再收一档（效果图写的「屏高 38%」≈ 290px）留 §10 待拍板 —— 若做，**必须只改 `anchorMaxSide` 一处**（两页同生效），**不允许**在播客页单独写 `maxHeight`（那正是 PR #9 之前的分叉方式）。

---

## 4. 必须守住的不变量

| # | 不变量 | 落点 |
|---|---|---|
| I1 | 两页视觉规格一律走 `ChengboSkinTheme.anchorMaxSide` / `anchorRadius` / `nowPlayingBackdrop()`，**不再各写一套** | `app_skin.dart:304–328`；`podcast_now_playing.dart:150–155`；`radio_now_playing.dart:166–172` |
| I2 | 刻意保留的两页差异**不要顺手统一**：中部（电台音量滑条 vs 播客进度条+时间）、控制行（电台切台 vs 播客跳秒）、锚点内容（生成式台名卡 vs 真封面）、Hero（播客有、电台无）| — |
| I3 | `紧凑列表`（`listDensityCompactProvider`）继续对单集行生效 | `podcast_screen.dart:859–861` |
| I4 | 不碰：Windows 端任何代码、`_IcyStatusLine`、`_MiniProgressBar`、`widget_resume` 触控尺寸、widget 圆角、widget 与 App「外观」开关联动 | — |
| I5 | ROADMAP ban 清单不做：复古刻度 UI / 均衡器频谱 / 歌词 / 逐字稿 | — |
| I6 | `ensureCanDownload` 是**唯一**下载前置校验入口，全部调用点（详情页 4 处 + 播放器 1 处）都必须保留 | `podcast_screen.dart:54` |

---

## 5. 语义边界自查表（提交前逐条勾）

| # | 场景 | 期望 |
|---|---|---|
| 1 | 「全部下载」打开 + `仅WiFi` 开 + 蜂窝网 | 弹既有 `wifiOnlyBlocked` SnackBar，开关**不**打开 |
| 2 | 「最近几集」下载，同上 | 同上（前置校验不丢）|
| 3 | 设置里改「仅WiFi下载」| 详情页 / 播放器的下载行为立即跟随（同一 provider）|
| 4 | 播放器下载图标（蜂窝网 + wifiOnly 开）| 同样被拦，SnackBar 文案不变 |
| 5 | 面板在 640dp 矮屏 / 大字号下打开 | 4 条**全部可见或可滚到**，无静默裁尾 |
| 6 | 面板 4 条的状态 | 与详情页入口行摘要、与开关实际值**三者一致** |
| 7 | 设置过跳过片头 0:30 → 打开面板 | 副文显示 `片头 0:30`；改完返回后**立即刷新** |
| 8 | 已设跳过片头/尾的老用户升级后 | 值仍在，自动跳过行为不变（存储 key 未动）|
| 9 | 每个图标 | `tooltip` 存在；`Semantics` 可读；`已下载` 不被读成按钮 |
| 10 | 书签数为 0 / >0 | 图标行不换行、不错位 |
| 11 | 无简介（`hasNotes == false`）| 不渲染「简介」图标，行内其余图标仍居中 |
| 12 | 播放器去掉「停止」后 | 关闭播放器页 → 迷你条 ✕ 仍在、tooltip 为 `停止`、点击行为不变 |
| 13 | 长按单集 → 菜单 | 第 1 行是**完整标题**；`选择多项` 项仍在且可进入选择态 |
| 14 | 顶栏（非选择态）| 只剩「更多」菜单；选择态仍是 `全选 + 下载所选` |
| 15 | 单集标题 3 行长度 | 渲染 2 行 + 省略号，**无溢出异常**；`紧凑列表` 开 / 关都不溢出 |
| 16 | 详情页在 `_selecting` 态 | 「下载设置」行不渲染（沿用 `showDownloadBar`）|
| 17 | 下载中（进度 tick）| 详情页列表**不**因每块进度重排（仍只 `select(records)`）|
| 18 | 面板打开时点「跳过片头/尾」 | 嵌套 sheet 正常打开；关闭后回到面板（面板未被一起 pop）|

---

## 6. 验证清单

### 6.1 自动化（必过）

```powershell
flutter analyze   # 改到的文件 0 issue；全仓 ≤ 23 info
flutter test      # 基线 143/143；本工单新增后总数 = 143 + 新增
```

### 6.2 新增守卫测试

**`test/layer_test.dart`（纯逻辑，追加）** —— `PodcastDownloadLogic.downloadSettingsSummary` 取值矩阵：

| 输入 | 期望 |
|---|---|
| 全默认（无下载、两开关关、无跳过）| `按需下载` |
| `allEnabled: true` | `全部下载 开` |
| `latestEnabled: true` | `自动下载最新 开` |
| `ready: 3, total: 12` | `已下载 3/12 集` |
| `downloading: 2, ready: 1, total: 12` | `正在下载 3/12` |
| `skipIntroSeconds: 30, skipOutroSeconds: 45` | `跳过片头 0:30 · 跳过片尾 0:45` |
| 组合（下载中 + 两开关开 + 跳过片头）| 四段以 ` · ` 连接，顺序固定 |

（同时覆盖新增的 `PodcastPlaybackLogic.skipDurationLabel`：`0 / 30 / 90 / 120`）

**`test/podcast_density_test.dart`（新增，widget 层）** —— 复用 `key_screens_test.dart:88–109` 的骨架（`SharedPreferences.setMockInitialValues({})` + `appStorageProvider` / `networkMonitorProvider` / `isOfflineProvider` / `podcastDownloadStoreProvider` override + `_app()`），并 override `podcastDetailProvider(feed)` 返回固定 `PodcastDetail`：

1. 详情页：存在「下载设置」行；点击后面板出现，含 `全部下载` / `自动下载最新一集` / `最近几集` / `跳过片头/尾` 四项，且 `tester.takeException()` 为 null
2. 详情页：**面板不裁尾** —— 断言最后一条「跳过片头/尾」的 `dy` 小于屏高（守卫 9/16 静默裁切回归）
3. 详情页：长标题（>2 行）单集渲染无异常；`tester.widget<Text>(标题).maxLines == 2`
4. 详情页：非选择态 `find.byTooltip('选择多项')` 为 `findsNothing`；长按单集后菜单里 `find.text('选择多项')` 为 `findsOneWidget`
5. 播放器：辅助行无 `ActionChip` 文本（`睡眠定时` / `书签` / `停止` / `跳过片头/尾` 均 `findsNothing`）；`find.byTooltip('睡眠定时')` / `find.byTooltip('书签')` 各 `findsOneWidget`
6. 迷你条：`find.byTooltip('停止')` 仍在（守卫「停止仍有入口」）

> **实施结果（1.1）**：播放器页与迷你条**已降级为源码结构断言** —— 两者都要 `audioHandlerProvider` 给一个真的 `RadioAudioHandler`，而它的构造会起 just_audio 平台通道，widget 测试里拿不到（全仓测试都没有实例化过它）。详情页 5 条 + 播放器 2 条，共 7 条，全部落地在 `test/podcast_density_test.dart`。

### 6.3 「测试有牙」验证（**必做，不许跳过**）

按既有约定：**把实现改坏 → 重跑 → 确认以「预期理由」失败**；并**逐条检查仍通过的用例**，判断它是「真守卫」还是「参数化维度选漏」（漏掉的维度往往正是现场默认路径）。

| 故意改坏 | 期望失败 |
|---|---|
| 面板去掉 `isScrollControlled` + 滚动容器 | 测试 2（尾部条目跑出屏外）|
| 摘要 `parts.join(' · ')` 改成 `join(' ')` | layer_test 组合用例 |
| 标题去掉 `maxLines: 2` | 测试 3 |
| 某个图标去掉 `tooltip` | 测试 5 |

### 6.4 真机 / 模拟器手动（交用户；本机 `mobile_list_available_devices` 返回空）

1. 详情页首屏：订阅一个多单集播客 → 首屏能看到 4–5 条单集；头部只剩 简介 + 筛选行 + 下载设置
2. 点「下载设置」→ 4 条齐全；**小屏 / 大字号**下最后一条都能看到
3. 面板里开「全部下载」→ 关面板 → 入口行摘要变 `全部下载 开`
4. 设置 → 播放与收听 → 「仅WiFi下载」在；蜂窝网下开「全部下载」被拦（SnackBar）
5. 设置里设 跳过片头 0:30 → 回详情页 → 下载设置 → 副文显示 `片头 0:30`
6. 长按一条长标题单集 → 菜单第 1 行是完整标题；`选择多项` 可进入选择态；批量下载可用
7. 播放器页：辅助行是**一行图标**（无文字 chip）；每个图标长按 / 悬停有 tooltip
8. 播放器页**没有**「停止」与「跳过片头/尾」；关闭播放器页 → 迷你条 ✕ 能停止
9. 开 `设置 → 外观 → 紧凑列表` → 单集行仍变密（不回归）
10. 深色模式 / 换氛围包 → 封面圆角与背景渐变与电台页仍**同规格**
11. Windows 端：右击单集 → 菜单可达；批量下载可达

### 6.5 回归红线

- `git diff --stat` 中 **`windows/`、`android/` 为空**
- `radio_now_playing.dart`、`app_skin.dart`、`mini_player.dart`、`_IcyStatusLine`、`_MiniProgressBar` **未被本工单改动**

---

## 7. 已知坑（本仓库已踩过，别再踩）

1. **Flutter 底部 sheet 两个反向高度坑**
   - ① `Column(mainAxisSize: min)` 含 `Expanded` / `Flexible` → 撑满全屏
   - ② 不设 `isScrollControlled` 时高度上限是屏高 **9/16**，内容又不带滚动 → 尾部条目**静默裁掉**（不报错；release 下就是「那一条不见了」）
   - 改 sheet 前自查三问：**有 flex 子项吗？条目数会随数据变多吗？内容有自己的滚动容器吗？**
2. **Dart test 抓不住 Kotlin 编译错**：`flutter test` 只跑 Dart。本工单不动 Kotlin，但若顺手改了 Android 侧，类型 / import 错必须 `flutter build apk` 才暴露
3. **版本号 bump 要同步多处**（本工单**不做**，v2.2.0 收尾时用）：`pubspec.yaml` / `lib/core/brand.dart`（有 `test/layer_test.dart` 版本守卫 → **bump 后必须跑完整 `flutter test`**）/ `scripts/chengbo-windows.iss`（写死 `AppVersion` + `OutputBaseFilename`）/ README + PRODUCT + PRIVACY 的版本与 User-Agent 引用

---

## 8. 提交策略

分支 `feat/podcast-density`（已从 `dd8990c` 开）。**小颗粒独立 commit，不 amend、不 squash**。

| # | commit | 内容 | 可独立编译 |
|---|---|---|---|
| C0 | `docs: add the v2.2 podcast density work order` | 本工单 + tracker 补 v2.2 段（PR #9 / #10 + 本工单）| ✅ |
| C1 | `refactor(podcast): collapse the three download switches into a settings row` | D1 + 面板 + `downloadSettingsSummary` + `skipDurationLabel` + layer_test 用例 | ✅ |
| C2 | `feat(podcast): move wifi-only download into playback settings` | D3（详情页删开关 + 设置页新增）| ✅ |
| C3 | `feat(podcast): move skip intro/outro into the download settings sheet` | P2（播放器删 chip + 面板加条目）| ✅ |
| C4 | `refactor(player): shrink the podcast episode chips into one icon row` | P1 + P3（chips → 图标行，去停止）| ✅ |
| C5 | `fix(podcast): cap the episode title at two lines` | D2 | ✅ |
| C6 | `refactor(podcast): drop the duplicate multi-select icon from the detail app bar` | D4 | ✅ |
| C7 | `test(podcast): guard the density changes` | `podcast_density_test.dart` + 有牙验证记录 | ✅ |

> C4 把 P1 + P3 合成一个 commit（同一段代码、同一视觉目标；拆开会留下「两行图标 + 还有停止」的无意义中间态）。若要更细可拆 C4a / C4b。

---

## 9. 与已有代码的冲突面

| 文件 | 冲突面 | 处置 |
|---|---|---|
| `podcast_screen.dart` | `_DownloadAllTile` → `_DownloadSettingsTile` | 私有类，全仓无第二处引用 |
| `podcast_screen.dart` | `leadingCount` / `showDownloadBar` | **不改**（仍是 1 个 item）|
| `podcast_now_playing.dart` | 删 `podcast_skip_sheet.dart` import | 否则 analyze 报 unused_import |
| `podcast_providers.dart` | 无改动 | `downloadWifiOnlyProvider` 定义不动 |
| `playback_screen.dart` | 「播客」section 插入 1 条 | 已有 `podcast_providers.dart` import（:16）|
| `podcast_download.dart` / `podcast_playback.dart` | 各新增 1 个 static 纯函数 | 纯新增，无调用点破坏 |
| `podcast_skip_sheet.dart` | **不改** | 它自带 4 条 `unnecessary_brace_in_string_interps` info —— **不动就不用管**；若确实要动，顺手清掉（总数 23→19）并在 commit 里说明 |
| `now_playing_queue_sheet.dart` | 无改动 | — |

---

## 10. 待拍板的 6 件事

| # | 问题 | 我的默认 | 备选 / 反方 |
|---|---|---|---|
| 1 | `仅WiFi下载` 落点 | **播放与收听 → 播客**（该 section 已有「自动清理下载 / 清理天数」，同为下载策略）| 数据管理 → 存储（与「播客下载」相邻，但那是空间管理，语义偏）|
| 2 | 面板里 跳过片头/尾 的形态 | **一条 `ListTile` → 嵌套打开现有 `showPodcastSkipSheet`**（复用、面板不膨胀）| 两组 `ChoiceChip` 直接嵌进面板（少一次点击，但面板变高、需滚动兜，且与独立 sheet 形成两套 UI）|
| 3 | 入口行摘要文案 | **`按需下载` / `全部下载 开` / `已下载 3/12 集 · 全部下载 开`，并追加 `跳过片头 0:30`**（只显示非默认态，保证单行）| 效果图写的 `全部下载 · 关`（始终显示开关态，但 360dp 窄屏 + 中文下易挤成省略号）|
| 4 | P4 封面是否再收一档 | **不改**（`anchorMaxSide = 300` 已随高度收缩；38% ≈ 290px 只多省 ~10px）| 改成 38%：**只改 `anchorMaxSide` 一处、两页同生效**；矮屏收益更大，但封面视觉权重下降 |
| 5 | 效果图里出现、但**不在 8 条内**的一项：简介收起（`展开`）| **本次不做**（不在已批准的 8 条里）| 做：详情页头部再省 ~2 行（约 48px），代价是多一个展开态与状态保持 |
| 6 | 可选：单集行尾 `≡ 查看备注`（:924–935）与长按菜单「查看简介」重复，每行吃掉 ~40px | **本次不做** | 做：行内更宽（标题可读性↑），代价是「查看备注」少一个直达入口 |

> 1 / 3 无偏好时我按「我的默认」执行；2 / 4 / 5 / 6 我按默认**不做**处理，点头后再动。

---

## 11. 真机评审后的追加改动

> 这两条**不在最初的 8 条内**，是用户在真机上看过 v2.2 测试包之后提的，做法已确认。

### 11.1 「下载设置」→「节目设置」+ 分组

- **起因**：`跳过片头/尾` 是按节目的**播放**设置，放在名为「下载设置」的面板里读起来错位（用户在真机上直接指出）。
- **做法**：入口行与面板都改名「节目设置」，面板内加两个分组标题「下载」/「播放」（样式沿用 `设置 → 播放与收听` 的分节标题）。文件与函数一并改名：`podcast_settings_sheet.dart` / `showPodcastSettingsSheet`。
- **代价**：无（高度收益不变）。
- **当时的漏判**：§10 第 2 项只问了「跳过片头/尾 用哪种形态放进这个面板」，没问「面板的名字还成立吗」—— 名字与内容一起看才自洽。

### 11.2 睡眠定时：倒计时移到封面之上（封面光圈已按反馈取消）

- **起因**：定时开启后倒计时压在控制行下面，多出一行在最底部，视觉上很难看。
- **保留的做法**：倒计时移到**封面之上**（`NowPlayingTopBar` 与 `_Cover` 之间），底部那份删除。
- **已取消**（commit `0350a72`）：曾在封面外沿加过一圈随时间消失的 `SleepTimerRing`，用户看过真机后认为「读起来是干扰而不是计时」，**已整体移除** —— 连带 `SleepTimerState.startedAt` / `total` 与纯函数 `SleepTimerLogic.ringFraction` 一起删掉（不留死代码）。想要回来可以从 `379fde5` 取。
- **两页差异（已知）**：电台页的倒计时仍在控制行下面 —— 本次只动播客页（`radio_now_playing.dart` 是本 PR 的红线外）。要统一得另开改动。
- **守卫**：播放器侧是源码结构断言（「倒计时只有一处且在封面之前」）。

### 11.3 跳过片头/尾面板：裁切 + 首帧崩溃（commit `b1e2390`）

真机反馈「跳过片头/尾的栏显示不完整」，查下去是**两个独立故障**：

1. **静默裁切**：`showPodcastSkipSheet` 既没设 `isScrollControlled`、也没有滚动容器。两组各 10 个 chip 在窄屏上要换 3 行，内容约 600px，而 9/16 高度上限在 360×800 上是 450px → 底部「保存」被裁掉且**滚不到**。
2. **首帧崩溃**：`_introSeconds` / `_outroSeconds` 是 `late int`，却由异步 `_load()` 赋值 —— **首帧 build 跑在 await 之前**，读未初始化的 late 字段会抛 `LateInitializationError`，面板先闪一个错误块。更糟的是若存储慢、用户在加载完成前点「保存」，会把已设的值写成 0。现在改成可空 + 加载中转圈 + 未加载完时 `_save()` 空操作。

守卫：`test/podcast_density_test.dart` 新增 widget 测试（360×800 下打开面板 → 「保存」必须在屏内 + `takeException()` 为 null）。两处都做了有牙验证：关掉 `isScrollControlled` → 「保存」落在 938px（屏高 800）失败；恢复 `late int` → 以 `LateInitializationError` 失败。

### 11.4 仅WiFi下载：在节目设置面板里露一行**只读**状态（commit `732131f`）

- **起因**：用户找不到它 —— 它在 `设置 → 播放与收听 →「播客」分组`（D3 的落点，正确：它是**全局**开关）。但它在下载路径上完全不可见，用户在移动网络下点下载只会被拦一下、事先没有任何提示。
- **做法**：`_WifiOnlyStatusTile` —— 一行不可点的 `ListTile`：`仅WiFi下载` + 副文「在 设置 → 播放与收听 里修改」+ 右侧 `开`/`关`。**故意不可点**：不把全局开关复制进按节目的面板。
- **同一类坑的复用**：值没加载完时显示 `…` 而不是「关」—— 就是 §11.3 那个 `AsyncLoading` 误判的同一形状。
- **副作用与补偿**：这一行 `watch` 了 `downloadWifiOnlyProvider`，等于把它预热了 → 原来那条「竞态」widget 测试（靠「此前没人 watch 过它」制造 AsyncLoading）**失去牙齿**。补偿：新增直接测 `resolveDownloadWifiOnly(AsyncLoading, …)` 的单元测试（改坏实现 → 以「AsyncLoading 被当成『没开』了」失败），widget 测试降级为端到端行为守卫并在注释里写明分工。

### 11.5 订阅拦截收窄：只留 RSSHub（commit `74f3349`）

**真机反馈**：「有些订阅现在不能听了，以前都能听」—— 用户给的截图是打开「肥话连篇」整页报「RSS 解析失败 / 无法在澄波订阅。这是版权点播库或转接源，请用作者公开的 RSS」。

**根因**：`PodcastFeedLogic.isDeniedCatalogFeed` 拒 `rsshub.app` / `*.lizhi.fm` / `ximalaya.com` 含 `/album`，而且 `resolveUrl()` **每次拉取都过** → 用户**已订阅**的 3 个喜马拉雅 + 1 个荔枝节目打开即整页报错，缓存里的单集也够不着。

**实测（四家平台的真实地址）**：

| 平台 | 地址形态 | 返回 | 旧规则 |
|---|---|---|---|
| 喜马拉雅 | `www.ximalaya.com/album/<id>.xml` | 200 · `application/xml` · `<rss version="2.0">` | ❌ 拦 |
| 荔枝 | `rss.lizhi.fm/rss/<id>.xml` | 200 · `text/xml` · `<rss>` | ❌ 拦 |
| 蜻蜓 | `c.qingting.fm/podcast/v1/vchannels/<id>` | 200 · `application/xml` · `<rss version="2.0">` | ✅ 放行 |
| 小宇宙 | `feed.xyzfm.space/<token>` | 200 · `application/xml` · `<rss>` | ✅ 放行 |

四家**都是平台自己提供的标准 RSS 2.0**，没有一家是第三方转接。旧规则只匹配 `host` + `path.contains('/album')`、**从不看返回内容** —— 于是「最像 feed 的荔枝（`rss.*.xml`）被拦、最不像 feed 的蜻蜓（看着像后端 API）反而放行」。

**改法**：
1. 拦截名单**只留 `rsshub.app`**（唯一真正的第三方转接源）。
2. **拦截不再作用于读取路径**：`resolveUrl(raw, {enforceCatalogPolicy})`，只有**新增订阅**的调用点传 true（`PodcastService.fetchFeed(feed, {forNewSubscription})`）。读取路径（详情刷新、后台查新、播放下一集）一律不拦 —— 否则已订阅的节目会变成死链。
3. 喜马拉雅**裸专辑页自动补 `.xml`**（`rewrite()`），避免放开后粘网页地址变成「解析失败」。
4. 文案：`catalogDeniedMessage` 与发现页标签改成「第三方转接源」，不再说「版权点播库或转接源」（对平台自建 feed 不准确）。
5. `ROADMAP.md` 边界同步：「版权点播（喜马拉雅/蜻蜓）」→「第三方转接源（RSSHub）」。

**守卫**（`layer_test` + `key_screens_test`）：喜马/荔枝/蜻蜓/小宇宙 均 `isDeniedCatalogFeed == false`；rsshub 为 true；`resolveUrl(rsshub, enforceCatalogPolicy: true)` 抛 `catalogDeniedMessage` 且 `saveAddress == false`，而**不带 flag 时不抛**；喜马裸页 → `.xml`；发现页只把转接源标成无法订阅（喜马那条可订阅）。有牙验证：把 `resolveUrl` 改回「总是拦」→ 读取路径那条断言以 `无法在澄波订阅。RSSHub 是第三方转接源…` 失败。

---

## 12. 变更记录

| 日期 | 版本 | 变更 |
|---|---|---|
| 2026-09-23 | 1.7 | **§11.5 订阅拦截收窄到只剩 RSSHub**（commit `74f3349`）：实测喜马拉雅 / 荔枝 / 蜻蜓 / 小宇宙四家返回的**都是平台自己的标准 RSS 2.0**，旧规则只看 host+path 从不看内容，导致已订阅的 3 个喜马拉雅 + 1 个荔枝节目打开即整页报错。改法：名单只留 `rsshub.app`；拦截**不再作用于读取路径**（`resolveUrl` 只在新增订阅时施加）；喜马裸专辑页自动补 `.xml`；文案与发现页标签改成「第三方转接源」；`ROADMAP.md` 边界同步。`flutter test` **157/157**、`flutter analyze` **16 info**（比基线低 7）。有牙验证：把 `resolveUrl` 改回「总是拦」→ 读取路径断言失败 |
| 2026-09-23 | 1.6 | **§11.4 仅WiFi下载只读状态行**（commit `732131f`）：在「节目设置」面板的「下载」分组末尾加一行不可点的 `仅WiFi下载 · 开/关`，副文指向设置页 —— 开关本身仍在 `设置 → 播放与收听`（全局开关不复制进按节目面板），但下载路径上终于看得见它的状态。值未加载完显示 `…`（不显示「关」）。副作用：该行 `watch` 了 provider → 原竞态 widget 测试失去牙齿，改用 `resolveDownloadWifiOnly(AsyncLoading, …)` 单元测试顶上（已做有牙验证）。`flutter test` **157/157**、`flutter analyze` **17 info** |
| 2026-09-23 | 1.5 | **真机第二轮反馈的两处改动**：`0350a72` 取消封面光圈（连带 `startedAt`/`total`/`ringFraction` 一并删掉，不留死代码；倒计时保留在封面之上）；`b1e2390` 修跳过片头/尾面板的**静默裁切**（缺 `isScrollControlled` + 无滚动容器，「保存」被裁且滚不到）与**首帧 `LateInitializationError`**（`late int` 由异步 `_load()` 赋值）。`flutter test` **156/156**、`flutter analyze` **17 info**（比基线低 6：本次改到的 `podcast_skip_sheet.dart` 的 4 条 + 之前两个文件各 1 条 + 光圈代码移除）。两处新守卫都做过有牙验证。另新增 `scripts/git-proxy.ps1`（探测本地代理端口再执行 git/gh）|
| 2026-09-23 | 1.4 | **追加两条真机评审后的改动**（§11）：`653922d`… 之后的 `ee20dbd`（「下载设置」→「节目设置」+ 下载/播放分组，文件与函数同步改名）与 `379fde5`（倒计时移到封面之上 + 封面外沿随时间消失的 `SleepTimerRing`，`SleepTimerState` 加 `startedAt`/`total` + 纯函数 `ringFraction`）。`flutter test` **157/157**、`flutter analyze` **21 info**（比基线**低 2**：顺手清掉了 `app_providers.dart` 与 `sleep_timer_sheet.dart` 里既有的 `prefer_const_constructors`，因为本次改到了这两个文件）。三条新守卫都做过有牙验证：`ringFraction` 无时钟返回 `1.0` → layer_test 失败；底部倒计时加回来 → 「只有一处」失败；封面去掉光圈 → 光圈守卫失败 |
| 2026-09-23 | 1.3 | **修一处 D3 引入的回归**（commit `653922d`）：`downloadWifiOnlyProvider` 是**懒创建**的 `AsyncValue` —— 第一次读它才现场创建，那一刻是 `AsyncLoading`、`.value == null`。详情页原先那个常驻的「仅WiFi下载」开关在 `watch` 它，顺手把 provider 预热了；D3 把开关搬去设置后**没人预热**，于是 `ensureCanDownload` 读到 null → 当成「没开」→ **移动网络下「全部下载」照下不误、也没有提示**。修法：新增 `resolveDownloadWifiOnly()`，provider 没加载完时直接问存储（存储就是它的数据源）；`ensureCanDownload` 与 `PodcastDownloadsNotifier.download()`（自动下载那条路有同样的潜在竞态）都改用它。守卫：新增 widget 测试「在移动网络下点『全部下载』且此前没人 watch 过该 provider」→ 旧代码以预期理由失败。`flutter test` **154/154**、`flutter analyze` 23 info 持平。**又是真机测试抓出来的** —— §5 自查表第 1 条预测了这个场景，但自动化测不出真实网络状态，我也没设备 |
| 2026-09-23 | 1.2 | **修一处 P1 引入的缺陷**（commit `d3fb718`）：图标行把电台页的**视觉**（实心月亮 + `关闭睡眠定时` tooltip）搬了过来，却没搬**行为** —— `onPressed` 永远只是打开面板，于是 tooltip 在说谎、关闭要多点一次。现在与电台页一致：定时开着时点一下直接 `cancel()`（想改时长再点一次开面板）。守卫加在 `test/podcast_density_test.dart`，并把电台页钉为基准。`flutter test` **153/153**、`flutter analyze` 23 info 持平。**这是真机测试抓出来的，自动化没覆盖到** —— 该行为在播放器页，而播放器页的守卫是源码结构断言（见 §6.2），挡不住「逻辑写错」只挡得住「文案/结构被删」|
| 2026-09-23 | 1.1 | **8 条已实施**（分支 `feat/podcast-density`，7 个 commit：`9238f2d` D1 / `c6cb813` D3 / `5156e50` P2 / `fa8ac30` P1+P3 / `7aa62f1` D2 / `316039d` D4 / `e6de631` 守卫测试）。验证：`flutter test` **152/152**（143 基线 + 2 纯逻辑 + 7 widget），`flutter analyze` **23 info**（与基线持平，改到的文件 0 issue）。§10 待拍板项按「我的默认」执行：1 → 播放与收听；2 → 嵌套打开现有 skip sheet；3 → 只显示非默认态；4 / 5 / 6 → **不做**。§6.3 有牙验证 6 处改坏全部以预期理由失败（面板 `isScrollControlled` 关掉 → 尾部跑出屏外；摘要分隔符改空格 → layer_test；`maxLines` 去掉 → 标题守卫；睡眠定时 tooltip 去掉 → 图标守卫；「选择多项」图标加回 → 顶栏守卫；设置页文案改掉 → D3 守卫）。§6.2 的播放器 2 条按预案降级为源码结构断言（理由见该节）|
| 2026-09-23 | 1.0 | 初稿。基于效果图 `docs/design/podcast-density-design.html` 的 8 条已批准改动落成可施工工单。起点 main = `dd8990c`；基线 `flutter test` 143/143、`flutter analyze` 23 info（均已本机核实）|
