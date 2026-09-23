# 移动端 v2.1 P0 —— 实施计划

> 范围：Android 移动端。**不修改 Windows 端任何代码。**
> **状态：v1.2 — 实施就绪（三项全含）**。§8 全部 11 项待核验已完成（含 B2 三项），无遗留未知项。
> 起草：2026-09-22
> 前置：[移动端 UX 升级研究（2026-09）](mobile-research-2026-09.md)

**执行顺序**：本计划排在 v2.2 桌面侧栏窗口之前（理由见 [desktop-sidebar-window-plan.md](desktop-sidebar-window-plan.md) §0）。

---

## 0. 范围修正（重要）

此前 ROADMAP 记的 v2.1 P0 是**三类**（通知封面 / mini player / widget 重做）。勘察后变化如下：

- **「通知 / 锁屏封面不用 favicon.ico」→ 已在 1.6.x 实现，从范围移除**（证据见下）
- **「widget 重做」→ 拆为 B1（视觉）与 B2（待听模式）**，两项**同版合入**

最终范围 = **A + B1 + B2，共 3 个交付条目**。

### 移除项：「通知 / 锁屏封面不用 favicon.ico」→ ✅ 已在 1.6.x 实现

证据链：

| 证据                          | 位置                                                                                                                                                                                      |
| ----------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 运行时拦截 `.ico` / `favicon` | `lib/core/artwork/artwork_url.dart` — `ArtworkUrlLogic.resolve()` 第 6-8 行返回 `null`                                                                                                    |
| 通知 / 锁屏封面走同一套       | `lib/core/audio/radio_audio_handler.dart:468` `artUri: ArtworkUrlLogic.mediaArtUri(item.artworkUrl)`                                                                                      |
| 列表封面走同一套              | `lib/shared/widgets/station_artwork.dart:49` `resolveArtworkUrl` → 同一个 `ArtworkUrlLogic`                                                                                               |
| 目录数据已重建                | `assets/stations_cn.json`：`.ico` 出现 **0** 次；值为 `pic.qtfm.cn` 的 jpg（379 处）与 `.png`（101 处）。`favicon` 出现 398 次是 **JSON 字段名**（`RadioStation.favicon`），不是 URL 内容 |
| 发布记录                      | `CHANGELOG.md`：「精选电台台标：`stations_cn.json` 补入蜻蜓 `imgUrl` 与央广 `image` 的 jpg/png；**不再用官网 favicon.ico**。通知栏 / 锁屏封面与列表共用同一套 resolve」                   |

**结论**：ROADMAP 的「通知 / 锁屏封面不用 favicon.ico」是陈旧条目，本次一并修正（见 §7 变更记录与 ROADMAP 更新）。

**唯一遗留（顺手清理，非缺陷）**：`ArtworkUrlLogic.resolve()` 第二个 `if` 块（第 9-17 行）两个分支都 `return raw`，是死代码。清理后行为完全不变。

### 最终范围（3 个交付条目）

| 编号      | 内容                                                                | 规模                                                       | 状态                     |
| --------- | ------------------------------------------------------------------- | ---------------------------------------------------------- | ------------------------ |
| **P0-A**  | mini player 播客精确剩余时间                                        | 小                                                         | 做                       |
| **P0-B1** | Android widget 视觉重做（Material You 动态色 + 深色模式 + M3 图标） | 中                                                         | 做                       |
| **P0-B2** | Android widget「Latest Episodes」模式                               | 中（原估「大」，因 `inboxProvider` 已存在而下调，见 §8.2） | **做（已确认同版合入）** |

**✅ 范围决策已定**：P0-B1 与 P0-B2 **同版合入**。三项全部实施，本计划 §0.2 已含完整任务分解。

---

## 0.1 文档地图

| 要做什么                   | 去哪节                        |
| -------------------------- | ----------------------------- |
| 了解范围为什么收窄         | §0                            |
| **照着写代码**             | **§0.2 实施顺序** → §3.1–§3.3 |
| 知道哪些文件能改、哪些不能 | §4                            |
| 提交前自查边界情况         | §5                            |
| 跑验证                     | §6                            |
| 查结论来源                 | §8                            |
| 明确不做的事               | §9                            |

---

## 0.2 实施顺序（任务分解）

按依赖排序。每步独立可编译、可提交。

### 第 1 步：纯逻辑层（可单测）

1. 新建 `lib/core/audio/remaining_time.dart`
   - `RemainingTimeLogic.label({required Duration? duration, required Duration position})` → `String?`
   - 边界见 §5 第 1 条
2. 清理 `lib/core/artwork/artwork_url.dart` 的死代码分支（行为不变）
3. **测试**：`test/remaining_time_test.dart`（§6.5 全部条目）
4. 提交

> ✅ **完成**：PR #3 commit `5e86f65`。`RemainingTimeLogic`（10/10 测试）+ `ArtworkUrlLogic` 死分支清理。

### 第 2 步：mini player 接线（P0-A）

5. `lib/shared/widgets/mini_player.dart`：
   - 标题行改为 `Row([Expanded(Text(title)), if (showRemaining) _RemainingTime(...)])`
   - `showRemaining = isPodcast && !sleepActive && !loading && !hasError`
   - 新增 `_RemainingTime` widget（`StreamBuilder` on `handler.player.positionStream`）
6. 提交

> ✅ **完成**：PR #3 commits `85c27f5`（施工单 `mobile-v2-1-step-2-work-order.md` 入仓）+ `c0f9cae`（mini_player.dart 接线）。117/117 测试通过，analyze 0 issues。

### 第 3 步：widget 视觉（P0-B1）

7. `android/app/src/main/res/values-night/colors.xml`（新建）— widget 深色配色
8. `android/app/src/main/res/values-v31/colors.xml`（新建）— Material You 动态色
9. `android/app/src/main/res/values-night-v31/colors.xml`（新建）
10. 新增 M3 vector drawable（播放 / 暂停 / 下一台 / 续播），替换 `android.R.drawable.ic_media_*`
11. `lib/core/audio/desk_widget.dart`：`DeskWidgetSnapshot` 加 `useDynamicColor` 字段
12. `lib/core/platform/desk_widget_sync.dart`：发布 `widget_use_dynamic_color`
13. `ChengboWidgetProvider.kt`：按 flag + `SDK_INT >= 31` 分支着色；换图标资源
14. 提交

> ✅ **已实施**：[`mobile-v2-1-step-3-work-order.md`](./mobile-v2-1-step-3-work-order.md)。4 个 commit（C1 Dart 契约 / C2 Dart 同步 / C3 Kotlin+资源 / C4 图标切换）已在 `feat/v2-1-widget-b1-impl`，PR #6 合 main（`3e3b2ae` / `9e46161` 等）。⚠️ 施工单 §3.1 (b) `DeskWidgetSnapshot` 字段误写为 `empty`，现场实际为 `hasItem`，C1 已按现场实现。

### 第 4 步：widget「Latest Episodes」（P0-B2）

15. `lib/core/audio/desk_widget.dart`：
    - `DeskWidgetLogic` 加 `episodesAndroidName = 'ChengboWidgetEpisodesProvider'` / `episodesKey = 'widget_episodes'` / `episodesEmptyTitle` 等常量
    - 新增纯函数 `episodesPayload(List<InboxItem>)` → `String`（JSON；见 §3.3）
16. `lib/core/platform/desk_widget_sync.dart`：新增 `publishEpisodes()`，`ref.listen(inboxProvider, ...)` 触发
17. `DeskWidgetAction` 加 `play`；`handleDeskWidgetLaunch` 处理 `chengbo://play?guid=...`（复用 `isDuplicateLaunch`）
18. `android/app/src/main/res/xml/chengbo_widget_episodes_info.xml`（新建）
19. `android/app/src/main/res/layout/chengbo_widget_episodes.xml`（新建，1 标题 + 4 行）
20. `android/app/src/main/kotlin/com/chengbo/chengbo/ChengboWidgetEpisodesProvider.kt`（新建）
21. `AndroidManifest.xml` 加第二个 `<receiver>`
22. `strings.xml` 加新 widget 的 `description`
23. **测试**：`test/desk_widget_episodes_test.dart`（payload 序列化 + 空数据 + `play` URI 解析，§6.6）
24. 提交

> ✅ **已实施**：[`mobile-v2-1-step-4-work-order.md`](./mobile-v2-1-step-4-work-order.md)。4 个 commit（D1 Dart 契约 / D2 Dart 同步 / D3 Kotlin+资源 / D4 测试）已在 `feat/v2-1-widget-b2`，PR #7 合 main（`ca4436f` / `b569cc6` 等）。

### 第 5 步：全量验证

25. 跑 §6.1–§6.4
26. 更新 `CHANGELOG.md`（此时才写，因为已实施）
27. 更新 ROADMAP.md（标记 v2.1 已实施）
28. 更新本文件 §7
29. 提交

> ✅ **已执行**：[`mobile-v2-1-step-5-work-order.md`](./mobile-v2-1-step-5-work-order.md)。第 3 + 4 步合 main 后跑过合并验证（142/142）+ release prep；tag `v2.1.0` 已发布。

**每步验收标准**：编译通过 + 该步新增测试通过 + 前序步骤验证点不回归。

---

## 1. 目标与范围

**目标**：

1. 播客在 mini player 上能一眼看到「还要听多久」
2. Android widget 与 App 视觉语言一致（Material 3 + 跟随 App 的壁纸配色开关 + 深色模式）
3. 桌面 widget 能直接进「待听」内容（未听单集），不必先打开 App

**包含**：

- mini player 播客剩余时间（**仅播客**，电台不做，理由见 §5 第 4 条）
- widget Material You 动态色（尊重 App 的「壁纸 / 系统配色」开关）
- widget 深色模式配色
- widget M3 图标替换系统默认图标
- **新增第二个 widget「待听」（Latest Episodes，4×2 cell）** —— 含数据序列化与 `play?guid=` 动作
- `ArtworkUrlLogic` 死代码清理

**不包含**：

- Windows 端任何改动
- 电台剩余时间 / 已听时长（无意义，见 §5）
- 新 widget 显示单集封面
- 替换现有 4×1 widget
- 主窗口 / 迷你条结构改动
- 歌词、均衡器、音频增强（已 ban）

---

## 2. 状态总览

| 维度                 | 现状（v2.0.2）                                                                    | 目标（v2.1）                                                                                    |
| -------------------- | --------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------- |
| mini player 副文     | `_IcyStatusLine`：ICY 曲名（电台）/ 节目名（播客）/ 状态（缓冲、错误）            | 不变                                                                                            |
| mini player 剩余时间 | 无                                                                                | 播客在标题行右侧显示 `剩余 mm:ss`（**P0-A 已实现**：PR #3 / `5e86f65` + `85c27f5` + `c0f9cae`） |
| 剩余时间数据源       | `_MiniProgressBar` 已用 `current.duration ?? handler.player.duration`             | 复用同一套                                                                                      |
| widget 配色          | 硬编码 `@color/widget_background` = `#0D4F8C`（深澄蓝），**无深色变体、无动态色** | 跟随 App 的壁纸配色开关；深色模式有变体（**B1 已实施**：`3e3b2ae` / `9e46161`，PR #6 已合）     |
| widget 图标          | `android.R.drawable.ic_media_play` / `pause` / `next`（系统默认）                 | 自绘 M3 vector drawable（**B1 同上**）                                                          |
| widget 数据契约      | Dart `DeskWidgetLogic` 常量 ↔ Kotlin 字符串字面量**重复定义**                     | 新增 2 个 key（`widget_use_dynamic_color` / `widget_episodes`）；契约在 §5 第 8 条记录          |
| widget 布局          | `LinearLayout` 单行：标题/副文 + 续 + 播停 + 下一台（4×1）                        | 现有不动；**新增第二个 4×2「待听」widget**（**B2 已实施**：`ca4436f` / `b569cc6`，PR #7 已合）  |
| widget 元数据        | minWidth 250dp / minHeight 40dp / 4×1 cell                                        | 现有不动；新增 4×2 / minHeight 110dp                                                            |
| widget 动作          | open / toggle / next / resume                                                     | 新增 `play?guid=`（仅新 widget 使用）                                                           |

---

## 3. 具体改法

### 3.1 P0-A：mini player 播客精确剩余时间

**文件**：`lib/shared/widgets/mini_player.dart`

**现状结构**（第 110-139 行）：

```dart
Expanded(
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(current.title, maxLines: 1, overflow: TextOverflow.ellipsis, ...),
      const SizedBox(height: 2),
      _IcyStatusLine(handler: handler, current: current, ...),
    ],
  ),
),
```

**改为**：

```dart
final showRemaining = isPodcast && !sleepActive && !loading && !hasError;

Expanded(
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Row(
        children: [
          Expanded(
            child: Text(current.title, maxLines: 1, overflow: TextOverflow.ellipsis, ...),
          ),
          if (showRemaining) ...[
            const SizedBox(width: 6),
            _RemainingTime(handler: handler, current: current),
          ],
        ],
      ),
      const SizedBox(height: 2),
      _IcyStatusLine(handler: handler, current: current, ...),
    ],
  ),
),
```

**新增 `_RemainingTime`**（同文件私有 widget）：

```dart
class _RemainingTime extends StatelessWidget {
  const _RemainingTime({required this.handler, required this.current});
  final RadioAudioHandler handler;
  final PlaybackItem current;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return StreamBuilder<Duration>(
      stream: handler.player.positionStream,
      builder: (context, snapshot) {
        final label = RemainingTimeLogic.label(
          duration: current.duration ?? handler.player.duration,
          position: snapshot.data ?? Duration.zero,
        );
        if (label == null) return const SizedBox.shrink();
        return Text(
          label,
          maxLines: 1,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
        );
      },
    );
  }
}
```

**新建 `lib/core/audio/remaining_time.dart`**：

```dart
abstract final class RemainingTimeLogic {
  /// 返回「剩余 mm:ss / h:mm:ss」；无有效时长时返回 null（调用方不渲染）。
  static String? label({required Duration? duration, required Duration position}) {
    if (duration == null || duration <= Duration.zero) return null;
    final remaining = duration - position;
    final safe = remaining.isNegative ? Duration.zero : remaining;
    final h = safe.inHours;
    final m = safe.inMinutes.remainder(60);
    final s = safe.inSeconds.remainder(60);
    if (h > 0) {
      return '剩余 $h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '剩余 $m:${s.toString().padLeft(2, '0')}';
  }
}
```

**为什么放标题行右侧而不是副文行**：副文行已被 ICY（电台）与状态（缓冲 / 错误）占用，且窄屏（360dp 手机）下文本列仅约 168dp —— 副文再拼时间会挤掉节目名。标题行右侧是独立槽位，睡眠倒计时激活时整块隐藏，不与睡眠倒计时并列。

**为什么 `showRemaining` 要排除 loading / hasError**：这两种状态副文已经变成「正在缓冲…」/ 错误文案，此时剩余时间会与实际位置不一致（位置停在错误点），显示出来是误导。

### 3.2 P0-B1：widget 视觉重做

#### 3.2.1 动态色（尊重 App 的开关）

App 已有「壁纸 / 系统配色」开关（`dynamicColorProvider`），PRODUCT.md 记录「Android 12+ 改用壁纸（Material You）」。widget 必须跟随，否则开关形同虚设。

**Dart 侧**：

- `lib/core/audio/desk_widget.dart`：`DeskWidgetSnapshot` 加 `final bool useDynamicColor;`，`snapshot({... required bool useDynamicColor})`

- `lib/core/platform/desk_widget_sync.dart`：

  ```dart
  await HomeWidget.saveWidgetData<bool>(
    DeskWidgetLogic.useDynamicColorKey,   // 'widget_use_dynamic_color'
    snapshot.useDynamicColor,
  );
  ```

  `publish()` 里从 `ref.read(dynamicColorProvider)` 取值（已有 provider，`app_providers.dart` / `app.dart` 已在使用）

**Kotlin 侧**（`ChengboWidgetProvider.onUpdate`）：

```kotlin
val useDynamic = data.getBoolean("widget_use_dynamic_color", false)
val dynamicOk = useDynamic && Build.VERSION.SDK_INT >= Build.VERSION_CODES.S

views.setInt(
    R.id.widget_root,
    "setBackgroundColor",
    if (dynamicOk) context.getColor(android.R.color.system_accent1_600)
    else context.getColor(R.color.widget_background)
)
val onColor = if (dynamicOk) context.getColor(android.R.color.system_accent1_0)
              else context.getColor(R.color.widget_on_background)
views.setTextColor(R.id.widget_title, onColor)
views.setTextColor(R.id.widget_subtitle, onColor)
views.setTextColor(R.id.widget_resume, onColor)
```

`compileSdk = 36` 已确认（`android/app/build.gradle.kts`），`android.R.color.system_accent1_*` 可编译。

**为什么用程序化而不是纯 `values-v31` 资源限定符**：资源限定符无法感知 App 内的开关（App 开关存在 Flutter 的 SharedPreferences 里）。纯 XML 方案会让 widget 在 API 31+ **永远**用动态色，忽略用户关闭开关的意图。

**回归保护**：`SDK_INT < 31` 时 `dynamicOk` 恒为 false → 走 `R.color.widget_background`，与现状完全一致。

#### 3.2.2 深色模式

当前 `values-night/` 只有 `styles.xml`，**没有 widget 颜色**，所以 widget 在深色模式下仍是 `#0D4F8C`。

**新建 `values-night/colors.xml`**：

```xml
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="widget_background">#0A3A66</color>
    <color name="widget_on_background">#E2E2E9</color>
</resources>
```

`#0A3A66` = 深澄蓝 `#0D4F8C` 的深色变体（与 `DESIGN.md` 的 `surface-dark` 家族同调）；`#E2E2E9` = `DESIGN.md` 的 `on-surface-dark`。

#### 3.2.3 M3 图标

现状用 `android.R.drawable.ic_media_play` / `ic_media_pause` / `ic_media_next`（Android 早期系统的拟物图标，与 Material 3 语言不符）。

**新建 4 个 vector drawable**（`android/app/src/main/res/drawable/`）：

| 文件                   | 用途                   | M3 图标       |
| ---------------------- | ---------------------- | ------------- |
| `ic_widget_play.xml`   | 播放                   | `play_arrow`  |
| `ic_widget_pause.xml`  | 暂停                   | `pause`       |
| `ic_widget_next.xml`   | 下一台                 | `skip_next`   |
| `ic_widget_resume.xml` | 续播（现为文字「续」） | `play_circle` |

**注意**：`widget_resume` 当前是 `TextView` 显示「续」字。改为 `ImageView` 会改变点击热区与无障碍语义 —— 建议**保持 TextView**，仅统一字号与颜色（避免行为回归）。图标替换只针对 `widget_toggle` / `widget_next` 两个 `ImageView`。

**图标着色**：vector 用 `android:fillColor="@color/widget_on_background"`，深色模式下自动跟随 `values-night`。

**API < 21 兼容**：`minSdk = 23`，vector drawable 原生支持，无需 `vectorDrawables.useSupportLibrary`。

### 3.3 P0-B2：widget「Latest Episodes」模式

**已确认同版合入。** 三项 B2 待核验已全部解决（见 §8.2）。

#### 3.3.1 设计决策（已定）

| 问题                 | 决定                            | 理由                                                                                                                     |
| -------------------- | ------------------------------- | ------------------------------------------------------------------------------------------------------------------------ |
| 显示几个单集         | **4 个**                        | `targetCellHeight=2`（4×2 cell）的垂直空间在 4 行 × 48dp 附近；`FeedCacheLogic.maxInboxItems = 20` 是上限，widget 取前 4 |
| 与现有 widget 的关系 | **新增第二个，不替换**          | 现有 4×1 widget 是「当前播放控制」，新的是「待听内容入口」，职责不同                                                     |
| 点击单集行           | `chengbo://play?guid=<guid>`    | 复用现有 `chengbo://` 契约与去重机制                                                                                     |
| 空数据文案           | 「暂无未听单集 · 点此打开澄波」 | 与现有 `DeskWidgetSnapshot.empty` 的「点此打开」语气一致                                                                 |
| 整块点击             | `chengbo://open`                | 与现有 widget 的 root 行为一致                                                                                           |

#### 3.3.2 数据源（已确认存在）

```dart
// podcast_providers.dart:823
final inboxProvider = Provider<List<InboxItem>>((ref) {
  return FeedCacheLogic.inbox(
    feeds: ref.watch(subscribedFeedsProvider).value ?? const [],
    cache: ref.watch(feedCacheProvider),
    listened: ref.watch(listenedEpisodeGuidsSetProvider),
  );
});
```

`InboxItem`（`core/podcast/feed_cache.dart:107`）= `{PodcastFeed feed, PodcastEpisode episode}`，字段齐备：

| 需要               | 来源                                          |
| ------------------ | --------------------------------------------- |
| 单集标题           | `item.episode.title`                          |
| 节目名（副文）     | `item.feed.title`                             |
| 点击用 guid        | `item.episode.guid` ✅                         |
| 封面（本版不显示） | `item.episode.imageUrl ?? item.feed.imageUrl` |

`FeedCacheLogic.inbox` 语义：每个订阅取最新一集未听的，按发布时间新到旧。

#### 3.3.3 序列化（Dart → 原生）

**放在 `DeskWidgetLogic` 里做成纯函数，便于单测**：

```dart
// lib/core/audio/desk_widget.dart
static const episodesKey = 'widget_episodes';
static const episodesAndroidName = 'ChengboWidgetEpisodesProvider';
static const episodesEmptyTitle = '暂无未听单集';
static const episodesEmptySubtitle = '点此打开澄波';

/// 序列化为 JSON 字符串。列表为空时返回空数组 `[]`（原生侧据此显示空态）。
static String episodesPayload(List<InboxItem> items, {int max = maxEpisodes}) {
  final rows = items.take(max).map((item) => {
        'title': item.episode.title,
        'subtitle': item.feed.title,
        'guid': item.episode.guid,
      });
  return jsonEncode(rows.toList());
}
```

**为什么用 JSON 字符串而不是多个 key**：`RemoteViews` 无法遍历数组；原生侧解析 JSON 后按行 `setTextViewText`，比发布 `widget_ep0_title` / `widget_ep1_title` … 这类平铺 key 更易维护，且行数可调。

**原生侧解析**（Kotlin，`org.json` 是 Android 内置，无需新依赖）：

```kotlin
val raw = data.getString("widget_episodes", "[]")
val rows = JSONArray(raw)
// rows.length() == 0 → 显示空态（标题 = episodesEmptyTitle）
```

#### 3.3.4 布局（4×2 cell）

```
┌────────────────────────────────────┐
│ 待听                                │   ← 小标题 labelSmall
│ ────────────────────────────────   │
│ 单集标题 1                          │   ← 16sp bold，1 行 ellipsis
│   节目名 1                          │   ← 12sp，1 行 ellipsis
│ 单集标题 2                          │
│   节目名 2                          │
│ 单集标题 3                          │
│   节目名 3                          │
│ 单集标题 4                          │
│   节目名 4                          │
└────────────────────────────────────┘
```

- 根：`LinearLayout(vertical)`，`@color/widget_background`
- 4 行用固定 id：`widget_ep_row_0` … `widget_ep_row_3`（每行是 `LinearLayout(vertical)`，含标题 + 副文两个 `TextView`）
- **行数不足 4 时**：`views.setViewVisibility(R.id.widget_ep_row_N, View.GONE)` 隐藏多余行
- 空态：隐藏全部 4 行，显示单个 `widget_ep_empty` TextView

#### 3.3.5 `play` 动作

`lib/core/audio/desk_widget.dart`：

```dart
enum DeskWidgetAction { open, toggle, next, resume, play, none }
static const playHost = 'play';

// actionForUri 加：
playHost => DeskWidgetAction.play,
```

**URI 契约**：`chengbo://play?guid=<guid>`

`desk_widget_sync.dart` 的 `apply(Uri? uri)` 加分支（`apply` 已接收 `Uri?`，无需改签名）：

```dart
case DeskWidgetAction.play:
  await _playFromWidget(ref, uri?.queryParameters['guid']);
```

**`_playFromWidget` 用 `inboxProvider` 反查，不查 `feedCacheProvider`**：

```dart
Future<void> _playFromWidget(WidgetRef ref, String? guid) async {
  if (guid == null || guid.isEmpty) return;
  final item = ref.read(inboxProvider)
      .where((i) => i.episode.guid == guid)
      .firstOrNull;
  if (item == null) return;   // 见下方边界说明
  await ref.read(playerControllerProvider).play(
    PlaybackItem.fromPodcastEpisode(
      podcastTitle: item.feed.title,
      episodeTitle: item.episode.title,
      audioUrl: item.episode.audioUrl,
      episodeGuid: item.episode.guid,
      artworkUrl: item.episode.imageUrl ?? item.feed.imageUrl,
      duration: item.episode.duration,
      feedId: item.feed.id,
    ),
  );
}
```

**为什么用 `inboxProvider` 而不是 `feedCacheProvider`**：

- widget 显示的就是 inbox 项，所以 guid 命中 inbox 是**主路径**
- `InboxItem` 同时带 `feed.title`（`podcastTitle`）与 `feed.id`（`feedId`），一次查表拿全所需字段
- 若走 `feedCacheProvider`，需遍历 `Map<String, CachedFeedSnapshot>`，且 `CachedEpisode` **不含 `feedId`**（在 snapshot 上），还要另查 `subscribedFeedsProvider` 拿节目名 —— 多两次查表

**边界**：guid 查不到时（例如 widget 发布后、用户点击前该集被标记已听，或 feed cache 已刷新）→ **静默返回**。此时 App 仍会打开（PendingIntent 目标是 `MainActivity`），只是不自动播放 —— 可接受的降级，不是错误。

**去重**：`chengbo://play?guid=xxx` 每次点击 URI 相同 → 现有 `isDuplicateLaunch`（800ms 窗口）会**正确拦截双击**，但**不会**拦截「先播 A、后播 A」的正常重播（间隔 > 800ms）。这是期望行为。

#### 3.3.6 Manifest 与元数据

```xml
<!-- AndroidManifest.xml，现有 receiver 之后 -->
<receiver
    android:name=".ChengboWidgetEpisodesProvider"
    android:exported="true">
    <intent-filter>
        <action android:name="android.appwidget.action.APPWIDGET_UPDATE"/>
    </intent-filter>
    <meta-data
        android:name="android.appwidget.provider"
        android:resource="@xml/chengbo_widget_episodes_info"/>
</receiver>
```

`chengbo_widget_episodes_info.xml`：

```xml
<appwidget-provider xmlns:android="http://schemas.android.com/apk/res/android"
    android:description="@string/widget_episodes_description"
    android:initialLayout="@layout/chengbo_widget_episodes"
    android:minWidth="250dp"
    android:minHeight="110dp"
    android:resizeMode="vertical"
    android:targetCellWidth="4"
    android:targetCellHeight="2"
    android:updatePeriodMillis="0"
    android:widgetCategory="home_screen" />
```

#### 3.3.7 更新触发

`desk_widget_sync.dart` 新增：

```dart
ref.listen<List<InboxItem>>(inboxProvider, (_, next) => publishEpisodes(next));
```

并在 `publish()` 首次调用时也 publish 一次 episodes（冷启动填充）。

**注意**：`inboxProvider` 依赖 `feedCacheProvider`（最多每 6 小时刷新、12 feeds/run），所以 widget 内容不会高频变化 —— 无需节流。

---

## 4. 技术约束

### 4.1 必须复用

- `lib/core/audio/radio_audio_handler.dart` 的 `handler.player.positionStream` / `handler.player.duration` —— 与 `_MiniProgressBar` 同一数据源
- `lib/core/providers/app_providers.dart` 的 `dynamicColorProvider` —— widget 动态色开关的真相源
- `lib/core/audio/desk_widget.dart` 的 `DeskWidgetLogic` —— widget 键名与动作的唯一声明处
- `lib/core/platform/desk_widget_sync.dart` 的 `publish()` —— 唯一的数据发布路径
- `lib/core/theme.dart` 与 `DESIGN.md` 的颜色角色 —— 深色变体取值
- `ChengboWidgetProvider.kt` 现有 `launch()` helper —— 新增点击行为时复用

### 4.2 新建

- `lib/core/audio/remaining_time.dart`（纯函数，可单测）
- `test/remaining_time_test.dart`
- `android/app/src/main/res/values-night/colors.xml`
- `android/app/src/main/res/drawable/ic_widget_play.xml`
- `android/app/src/main/res/drawable/ic_widget_pause.xml`
- `android/app/src/main/res/drawable/ic_widget_next.xml`
- `test/desk_widget_episodes_test.dart`（B2）
- `android/app/src/main/res/xml/chengbo_widget_episodes_info.xml`（B2）
- `android/app/src/main/res/layout/chengbo_widget_episodes.xml`（B2）
- `android/app/src/main/kotlin/com/chengbo/chengbo/ChengboWidgetEpisodesProvider.kt`（B2）

### 4.3 改动（B2）

- `lib/core/audio/desk_widget.dart`：加 `episodesKey` / `episodesAndroidName` / 空态文案常量 / `episodesPayload()` 纯函数 / `DeskWidgetAction.play` / `playHost`
- `lib/core/platform/desk_widget_sync.dart`：加 `publishEpisodes()` + `ref.listen(inboxProvider, ...)` + `_playFromWidget()`
- `android/app/src/main/AndroidManifest.xml`：加第二个 `<receiver>`
- `android/app/src/main/res/values/strings.xml`：加 `widget_episodes_description`

### 4.4 不动

- Windows 端任何代码（`lib/core/platform/desk_*`、`windows/`）
- `_IcyStatusLine` 的逻辑与文案
- mini player 的封面 / 播放键 / 停止键 / 3px 进度条 / 滑动交互
- **现有 4×1 widget 的布局结构、尺寸、元数据**（B1 不动；B2 也不动 —— 新 widget 是新增，不替换）
- widget 现有 4 个动作（open / toggle / next / resume）的 URI 契约
- `dynamic_color` 包的版本约束（`pubspec.yaml` 注释已说明 1.9.0 编不过）
- `inboxProvider` / `FeedCacheLogic.inbox` 的逻辑（只读订阅）

---

## 5. 语义边界与风险（提交前自查）

1. **剩余时间的格式边界**

   - `duration == null` → 返回 `null`，调用方不渲染（**不要显示 `剩余 0:00`**）
   - `duration == Duration.zero` → 同上（直播流可能给 0）
   - `position > duration`（拖到末尾、或流报的 duration 偏小）→ clamp 到 `0:00`，**不要出现负数**
   - `remaining >= 1h` → `剩余 1:02:03`；`< 1h` → `剩余 12:34`（分钟不补零，秒补零）
   - `remaining` 恰好 `1h` → `剩余 1:00:00`（不能退化成 `60:00`）
   - 暂停时：位置不变，剩余时间不变 → **保持显示**（不闪烁、不清空）

2. **与睡眠倒计时并存**

   - 睡眠倒计时激活时，`showRemaining` 为 false → 剩余时间整块隐藏
   - 理由：同一行并列两个时间（一个倒计时、一个剩余）在窄屏必然溢出，且语义容易混淆
   - 睡眠倒计时结束后（`sleepActive` 变 false）→ 剩余时间自动恢复显示

3. **`showRemaining` 的四个条件必须全部满足**

   - `isPodcast`：电台无剩余时长语义
   - `!sleepActive`：见第 2 条
   - `!loading`：缓冲中位置不可信
   - `!hasError`：错误时位置停在出错点，显示剩余是误导
   - **注意**：`loading` 变量已存在（`PlaybackLogic.shouldShowBufferingUi`），直接复用，不要新写判断

4. **电台为什么不做**

   - 直播流没有「总时长」概念，`PlaybackItem.duration` 对电台恒为 `null`
   - `handler.player.duration` 对直播流要么是 `null`，要么是不断增长的已缓冲长度 —— 后者拿来做「剩余」是**错误语义**
   - 「已听时长」对电台是纯信息，无行动价值，且与 `收听` tab 的统计功能重复
   - **结论：电台保持现状**（ICY 曲名 + 播放时的 3px 主色条）。此前 ROADMAP 写的「电台累计」是不成立的，本次一并修正

5. **widget 动态色与 App 开关的一致性**

   - App 的「壁纸 / 系统配色」关闭 → widget 必须用品牌深澄蓝，**不能**用系统动态色
   - App 开关切换后，widget 需要重新 `publish()` 才能更新 → `desk_widget_sync.dart` 需 `ref.listen(dynamicColorProvider, ...)` 触发 publish（**当前只监听 `currentPlaybackProvider` 与 `handler.playbackState`，需新增**）
   - `SDK_INT < 31` → 无论开关如何都走品牌色（系统资源不存在）

6. **widget 深色模式**

   - `values-night` 只在系统深色时生效，与 App 内的「外观」设置（跟随系统 / 浅色 / 深色）**可能不一致**
   - 现状即如此（widget 从来只跟系统），本次不改变这一层级 —— 若要做到与 App 设置一致，需要再发布一个 flag，属于 P2
   - **明确记录为已知不一致**，不在本版修复

7. **widget 图标替换的回归风险**

   - `widget_resume` 保持 `TextView`（「续」字），**不改 ImageView** —— 避免点击热区（40dp×48dp）与 `contentDescription` 语义变化
   - 只替换 `widget_toggle` / `widget_next` 两个 `ImageView` 的 `android:src`
   - 新 vector 的 `fillColor` 必须走 `@color/widget_on_background`，否则深色模式下不可见
   - vector 尺寸：保持现有 `android:padding="8dp"`（48dp 容器内 32dp 图标），不调

8. **widget 数据契约（跨语言，最容易踩）**

   - Kotlin 侧 `"widget_title"` / `"widget_subtitle"` / `"widget_playing"` 是**字符串字面量**，与 Dart 的 `DeskWidgetLogic.titleKey` 等常量重复定义
   - 新增 `widget_use_dynamic_color` 时必须**两处同步改**，否则 widget 静默读不到 → 退化为品牌色（不崩，但功能失效）
   - **本次不重构这个契约**（属于独立改动）；只在 `DeskWidgetLogic` 的常量旁加注释标明「改这里必须同步 `ChengboWidgetProvider.kt`」
   - 验证方式：见 §6.1 的「动态色开关生效」条目

9. **`ArtworkUrlLogic` 死代码清理**

   - 第 9-17 行的 `if` 块与第 18 行的 `return raw` 结果相同 → 删掉整个 `if` 块
   - 行为完全不变（所有非 `.ico` / 非 `favicon` 的输入都返回 `raw`）
   - 必须跑一次 §6.4 的封面回归

10. **回归风险汇总**

    - mini player 标题行改 `Row` → 长标题的 `ellipsis` 行为可能变化（原来占满整行，现在要让位给时间标签）→ 验证长标题不溢出、不被裁切
    - `_RemainingTime` 用 `positionStream` → 已有 `_MiniProgressBar` 也在订阅同一 stream，**两个 `StreamBuilder` 是允许的**（广播流，已在 §8.1 第 4 项确认）
    - widget Kotlin 改动 → 必须验证 `SDK_INT < 31` 路径不崩（可用 API 30 模拟器）

11. **B2：新 widget 的 guid 反查失败路径**

    - widget 发布后、用户点击前，该集可能被标记已听（inbox 不再包含它）→ `inboxProvider` 查不到 → **静默返回**，App 仍打开但不自动播放
    - 这是**可接受的降级**，不是错误；不要为此加 SnackBar（用户此时刚打开 App，弹提示反而突兀）
    - 不要退化为「播放 inbox 第一条」—— 那是错误的内容

12. **B2：空数据与部分数据**

    - `inboxProvider` 为空（无订阅 / 全部已听 / feed cache 未建立）→ widget 显示空态文案，**不显示空行**
    - inbox 只有 1–3 条 → 隐藏多余的 3 行（`setViewVisibility(GONE)`），**不要留空白占位**
    - `episode.title` 为空串 → 该行标题为空但行仍显示（原生侧不崩）；副文照常
    - **注意**：`inboxProvider` 依赖 `feedCacheProvider`，而后者「最多每 6 小时刷新、12 feeds/run」→ 新订阅的节目可能**不在** inbox 里直到下次刷新。这是既有语义，widget 只是如实反映

13. **B2：两个 widget 的独立性**

    - 现有 4×1 widget 与新的 4×2 widget **互不影响**：`updateWidget(name:)` 只触发对应 Provider 的 `onUpdate`
    - 但两者**共享同一份 SharedPreferences**（`HomeWidgetPlugin.getData`）→ 新增 key 时确保不与现有 key 冲突（`widget_episodes` / `widget_use_dynamic_color` 均为新名）
    - 用户只添加其中一个 → 另一个的 `publish` 仍会写数据（无害，只是 SharedPreferences 里多几个 key）
    - `getAppWidgetIds` 对未添加的 widget 返回空数组 → `onUpdate` 不会执行 → 无崩溃风险

14. **B2：`play` 动作不污染现有动作**

    - `DeskWidgetAction` 加 `play` 后，现有 4 个 URI 的映射必须**逐字不变**（§6.6 有回归条目）
    - `initialLaunchUri` / `isDuplicateLaunch` 的现有逻辑不改，只新增分支
    - 冷启动时若 `play` URI 命中且 guid 有效 → 会直接开始播放（与 `resume` 行为同级）。这与 PRODUCT.md「冷启动不自动播放」的约定**冲突吗？** —— 不冲突：那条约定针对「恢复上次收听」（`restoreLastSession` 只填迷你条不播放）。**用户显式点击 widget 单集 = 显式播放意图**，等同于点列表里的单集

---

## 6. 验证清单

### 6.1 功能（手动，真机 Android）

- [x] 播客播放中 → mini player 标题右侧显示 `剩余 mm:ss`
- [x] 剩余时间随播放递减（约每秒刷新）
- [x] 剩余时间超过 1 小时 → 显示 `剩余 h:mm:ss`
- [x] 播客暂停 → 剩余时间保持显示且不变
- [x] 播客缓冲中 → 剩余时间隐藏，副文显示「正在缓冲…」
- [x] 播客播放出错 → 剩余时间隐藏，副文显示错误
- [x] 电台播放中 → **不显示**剩余时间（保持 ICY 曲名 + 3px 主色条）
- [x] 睡眠定时激活 → 剩余时间隐藏，只显示睡眠倒计时
- [ ] 睡眠定时取消 → 剩余时间恢复
- [x] 超长单集标题 → 标题 ellipsis 正常，时间标签不被挤掉
- [x] widget 动态色开关开启（API 31+）→ widget 背景跟随壁纸配色
- [x] widget 动态色开关关闭 → widget 背景为品牌深澄蓝
- [x] 系统深色模式 → widget 使用深色变体配色
- [ ] widget 图标为 M3 风格（非系统拟物图标）
- [ ] widget 四个动作（打开 / 续播 / 播停 / 下一台）全部仍可用
- [ ] widget「续」字按钮仍可点、语义不变
- [ ] **（B2）** 把「待听」widget 加到桌面 → 显示最多 4 条未听单集（标题 + 节目名）
- [ ] **（B2）** 点击某条单集 → App 打开并开始播放该集
- [ ] **（B2）** 播放后该集被标记已听 → widget 下次刷新后该条消失（下一条顶上）
- [ ] **（B2）** 无未听单集（或未订阅任何播客）→ widget 显示「暂无未听单集 · 点此打开澄波」
- [ ] **（B2）** inbox 只有 2 条 → 只显示 2 行，其余 3 行隐藏（无空白占位）
- [ ] **（B2）** 点击 widget 空白区域 / 「待听」标题 → 打开 App，不自动播放
- [ ] **（B2）** 两个 widget 可同时存在，互不干扰
- [ ] **（B2）** 只添加「待听」widget（不添加 4×1）→ 正常工作

### 6.2 视觉

- [ ] 剩余时间字号 / 颜色与副文层级协调（`labelSmall` + `onSurfaceVariant`）
- [ ] 剩余时间用等宽数字，数字变化时不抖动
- [ ] 360dp 窄屏下标题 + 时间不溢出
- [x] 三个致敬氛围包（废土终端 / 第三新东京 / 夜之城）下 mini player 正常
- [x] widget 在浅色 / 深色系统下都可读（对比度足够）
- [ ] **（B2）** 「待听」widget 的 4 行在 4×2 cell 内不溢出、不裁切
- [ ] **（B2）** 单集标题超长 → 1 行 ellipsis；节目名超长 → 1 行 ellipsis
- [ ] **（B2）** 「待听」widget 配色与 4×1 widget 一致（同一套 `widget_background` / `widget_on_background`）
- [ ] **注意**：widget 根背景当前是纯色 `@color/widget_background`（无圆角 drawable）。改为 `setBackgroundColor` 后仍无圆角 —— **本版不改变这一状态**（不引入圆角，避免与启动器行为叠加）。若后续要圆角，需单独评估 `system_app_widget_background_radius`

### 6.3 边界

- [ ] 无时长单集（RSS 未给 `itunes:duration`）→ 不显示剩余时间，不崩
- [ ] 位置超过时长（手动拖到末尾）→ 显示 `剩余 0:00`，不显示负数
- [ ] 从 Android Auto 启动的播客（`auto_browse.dart` 不带 duration）→ 走 `handler.player.duration` 兜底，正常显示
- [ ] 从书签启动的播客（`episode_bookmark.dart` 不带 duration）→ 同上
- [ ] API 30 设备 → widget 不崩，用品牌色
- [ ] API 33+ 设备 → widget 动态色正常
- [ ] **（B2）** widget 发布后该集被标记已听 → 点击 → App 打开但不播放（不崩、不弹错）
- [ ] **（B2）** 新订阅的节目在 feed cache 刷新前 → 不出现在 widget（既有语义，非缺陷）
- [ ] **（B2）** `episode.title` 为空 → 该行标题空白但行仍显示，不崩
- [ ] **（B2）** 单集标题含引号 / emoji / 中文 → JSON 往返正确显示

### 6.4 回归（最重要）

- [ ] Windows 端**任何**代码无变化（`git diff --stat` 确认 `lib/core/platform/desk_*`、`windows/` 为空）
- [ ] mini player 播放 / 暂停 / 停止 / 左右滑切台 / 左右滑跳秒 无回归
- [ ] mini player 封面 / 3px 进度条 无回归
- [ ] 列表封面渲染无回归（`ArtworkUrlLogic` 清理后）
- [ ] 通知栏 / 锁屏封面无回归（`.ico` 仍被拦截）
- [ ] widget 原有 3 个数据键读取正常
- [ ] widget 在 widget 未添加到桌面时不报错
- [ ] **（B2）** 现有 4×1 widget 的动作与显示无回归（`DeskWidgetAction` 加 `play` 后）
- [ ] **（B2）** `initialLaunchUri` / `isDuplicateLaunch` 现有行为无回归
- [ ] **（B2）** 「收听」tab 的未听 inbox 显示与 widget 一致（同一 `inboxProvider`，不应出现分歧）

### 6.5 自动化测试

新增 `test/remaining_time_test.dart`（纯函数）：

- [ ] `duration == null` → `null`
- [ ] `duration == Duration.zero` → `null`
- [ ] `duration` 为负 → `null`
- [ ] `position == Duration.zero`, `duration == 45s` → `剩余 0:45`
- [ ] `position == 0`, `duration == 12m34s` → `剩余 12:34`
- [ ] `position == 0`, `duration == 1h` → `剩余 1:00:00`
- [ ] `position == 0`, `duration == 1h2m3s` → `剩余 1:02:03`
- [ ] `position == duration` → `剩余 0:00`
- [ ] `position > duration` → `剩余 0:00`（不出现负数）
- [ ] `position == duration - 1s` → `剩余 0:01`

### 6.6 自动化测试（B2）

新增 `test/desk_widget_episodes_test.dart`（纯函数，无需原生）：

**`DeskWidgetLogic.episodesPayload`**：

- [ ] 空列表 → `[]`（不是 `null`，不是 `""`）
- [ ] 1 个 item → 1 元素数组，含 `title` / `subtitle` / `guid` 三个键
- [ ] 超过 `maxEpisodes` 个 → 截断到 4 个（`take` 语义）
- [ ] 含特殊字符的标题（引号、emoji、中文）→ `jsonEncode` 正确转义，`jsonDecode` 可还原
- [ ] `episode.title` 为空串 → 仍输出该行（不崩；原生侧显示空标题）

**`DeskWidgetLogic.actionForUri`**：

- [ ] `chengbo://play?guid=abc` → `DeskWidgetAction.play`
- [ ] `chengbo://play`（无 guid）→ `DeskWidgetAction.play`（guid 为 null 时由 handler 静默跳过）
- [ ] `chengbo://play?guid=`（空 guid）→ `DeskWidgetAction.play`（同上）
- [ ] 现有 4 个 URI（open / toggle / next / resume）映射不变（**回归**）
- [ ] 未知 host → `none`
- [ ] `null` → `none`

**`DeskWidgetLogic.isDuplicateLaunch`**（`play` 场景）：

- [ ] 同 guid、间隔 100ms → 判重（双击拦截）
- [ ] 同 guid、间隔 2000ms → 不判重（允许重播）
- [ ] 不同 guid、间隔 100ms → 不判重

---

## 7. 变更记录

| 日期       | 版本    | 变更                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   |
| ---------- | ------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 2026-09-23 | **1.6** | **v2.1.1 补丁**（分支 `fix/v2-1-1-radio-mini-bar`，PR #8）。三处修复：① `lib/core/brand.dart` 版本常量停在 `2.0.2`（v2.1.0 release prep 漏 bump；影响关于页 / 隐私说明 / 备份 JSON / 全部网络 UA）② 移除电台迷你条底部 3px 主色条（无信息量 + 圆角裁切后像残留色带）③ 播客 Now Playing「已下载」chip 被抬高 4px（它是唯一的 `VisualDensity.compact`，`Wrap` 默认顶对齐）→ 改 `WrapCrossAlignment.center`。版本 bump 到 `2.1.1+40`。同时把 §0.2 / §2 的「代码待实施」过期标记改为已实施 |
| 2026-09-23 | **1.5** | **v2.1 完成**。第 3 步（P0-B1 widget Material You + 深色 + M3 图标；PR #6 合）+ 第 4 步（P0-B2 widget Latest Episodes；PR #7 合）+ 第 5 步（release prep；main + tag v2.1.0）。§0.2 全部加 ✅ 标记；§2 状态总览「widget 数据契约」「widget 布局」更新；§9 不做清单保持。                                                                                                                                                                                                                |
| 2026-09-22 | 1.0     | 初稿。勘察发现 P0-1 已实现（范围从 3 项收窄为 2 项）；建议拆分 P0-B1 / P0-B2；含 §0.2 实施顺序与全部语义边界                                                                                                                                                                                                                                                                                                                                                                           |
| 2026-09-22 | 1.1     | §8 八项待核验全部完成（§8.1）；额外发现 `inboxProvider` 已存在，B2 规模由「大」下调为「中」（§8.2）；§3.3 / §6.2 相应更正                                                                                                                                                                                                                                                                                                                                                              |
| 2026-09-22 | **1.2** | **实施就绪（三项全含）**。B2 确认同版合入；§3.3 重写为完整实施规格（设计决策 / 数据源 / 序列化 / 布局 / `play` 动作 / Manifest / 触发时机）；§8.2 三项 B2 待核验全部解决；新增 §6.6 测试；§0.2 扩为 5 步                                                                                                                                                                                                                                                                               |
| 2026-09-22 | **1.3** | **P0-A 落地**。第 1 步（`RemainingTimeLogic` + 死代码清理）+ 第 2 步（mini_player 接线）合并入 PR #3；施工单 `mobile-v2-1-step-2-work-order.md` 入仓；§0.2 加 ✅ 标记；§2 状态总览「mini player 剩余时间」标注已实现。剩余：第 3 步（P0-B1 widget Material You + 深色模式）+ 第 4 步（P0-B2 widget Latest Episodes）+ 第 5 步（全量验证）                                                                                                                                               |
| 2026-09-22 | **1.4** | **设计就绪，代码待实施**。第 3 / 4 / 5 步施工单全部入仓（commits `4919bae` / `1fe68e7` / `99a6ff5` on `feat/v2-1-widget-b1`）；§0.2 加 🟡 标记 + 触发条件；§2 状态总览 widget 行加「施工单就绪」引用；release tracker `v2-1-release-tracker.md` 入仓作为 single source of truth。⚠️ Step 3 工单 §3.1 (b) `DeskWidgetSnapshot` 字段名 `empty` 与现场 `hasItem` 不符，动手 C1 时按现场 `hasItem` 改。剩余：B1 + B2 代码实施 + v2.1 release prep                                            |

---

## 8. 待核验（执行前回到代码确认）

- [x] `lib/core/providers/app_providers.dart` 的 `dynamicColorProvider` 精确名称与类型（`app.dart` 第 20 行在用 `ref.watch(dynamicColorProvider).value ?? true`，推测为 `AsyncValue<bool>`，需确认声明处）
- [x] `desk_widget_sync.dart` 的 `publish()` 是否方便新增 `ref.listen(dynamicColorProvider, ...)`（当前在 `Provider<void>` 体内）
- [x] `handler.player` 是否为 public（`mini_player.dart:277` 已在用 `handler.player.duration`，确认无 getter 封装差异）
- [x] `handler.player.positionStream` 是否 broadcast stream（两个 `StreamBuilder` 同时订阅）
- [x] `android/app/build.gradle.kts` 的 `kotlinOptions.jvmTarget` 是否支持 `when` 表达式的新语法（当前 Kotlin 2.1.20，OK，仅确认无 lint 阻塞）
- [x] `values-night/colors.xml` 新建后是否与现有 `values-night/styles.xml` 冲突（不应冲突，不同文件）
- [x] 现有 `widget_resume` 的 40dp×48dp 触控尺寸是否满足 Android 无障碍 48dp 建议（当前宽度 40dp，**疑似不足**；若是既有问题，本版不修，仅记录）
- [x] `feedCacheProvider` 的结构（仅 B2 需要）

### 8.1 勘察结果（2026-09-22 已核完）

| #   | 问题                              | 结论                                                                                                                                                                                                                                   | 行动                                                                                                                                                                                |
| --- | --------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1   | `dynamicColorProvider` 声明       | `app_providers.dart:881` — `StateNotifierProvider<DynamicColorNotifier, AsyncValue<bool>>`                                                                                                                                             | **按计划用 `.value ?? true`** 取值，与 `app.dart:20` 一致                                                                                                                           |
| 2   | `publish()` 内能否加 `ref.listen` | `desk_widget_sync.dart` 的 `publish()` 定义在 `Provider<void>` 体内（第 20-52 行），**已经**在体内用了两处 `ref.listen`（`currentPlaybackProvider`、`audioHandlerProvider`）                                                           | **可直接加** `ref.listen<AsyncValue<bool>>(dynamicColorProvider, ...)`；注意需在 `publish()` 外、`Provider` 体内注册（与现有两处同层）                                              |
| 3   | `handler.player` 可见性           | `radio_audio_handler.dart:162` — `AudioPlayer get player => _player;` **public getter**                                                                                                                                                | 直接可用，无需改 handler                                                                                                                                                            |
| 4   | `positionStream` 是否 broadcast   | **是**。证据：`radio_audio_handler.dart:40` 自身在 `_player.positionStream.listen(...)`，同时 `mini_player.dart:277` 的 `_MiniProgressBar` 也在 `StreamBuilder(stream: handler.player.positionStream)` —— 两处并发订阅已在生产环境工作 | 新增第三个订阅安全；**无需改动**                                                                                                                                                    |
| 5   | Kotlin 工具链                     | `android/app/build.gradle.kts`：`jvmTarget = JavaVersion.VERSION_11`、`sourceCompatibility/targetCompatibility = VERSION_11`、`isCoreLibraryDesugaringEnabled = true`；Kotlin 2.1.20 / AGP 8.9.1 / compileSdk 36                       | 计划中的 Kotlin 代码（`when`、`Build.VERSION`、`context.getColor`）均兼容。**`android.R.color.system_accent1_*` 存在性由编译期保证**（compileSdk 36 含 API 31+ 资源），无需额外核验 |
| 6   | `values-night/colors.xml` 冲突    | `values-night/` 当前**只有** `styles.xml`，其中 `<color>` 出现 **0** 次                                                                                                                                                                | 新建 `colors.xml` 无冲突。**注意**：`styles.xml` 只管启动主题，与 widget 无关                                                                                                       |
| 7   | `widget_resume` 触控尺寸          | `chengbo_widget.xml` 第 42-43 行确认：`layout_width="40dp"` / `layout_height="48dp"` —— **宽度低于 Android 无障碍建议的 48dp**                                                                                                         | **既有问题，本版不修**，仅记录（§9 不做）。若后续要修，需同时评估 4 键总宽是否超出 4×1 cell                                                                                         |
| 8   | `feedCacheProvider` 结构          | `podcast_providers.dart:783` — `StateNotifierProvider<FeedCacheNotifier, Map<String, CachedFeedSnapshot>>`；`CachedFeedSnapshot`（`core/podcast/feed_cache.dart:73`）含 `feedId` / `fetchedAt` / `episodes`                            | 见下方 §8.2 —— **B2 的数据源比预想简单得多**                                                                                                                                        |

### 8.2 额外发现：B2 的数据源已存在

B2 需要的「每订阅最新未听单集」**已经有现成 provider**：

```dart
// podcast_providers.dart:823
final inboxProvider = Provider<List<InboxItem>>((ref) {
  return FeedCacheLogic.inbox(
    feeds: ref.watch(subscribedFeedsProvider).value ?? const [],
    cache: ref.watch(feedCacheProvider),
    listened: ref.watch(listenedEpisodeGuidsSetProvider),
  );
});
```

**这显著降低了 B2 的规模** —— 不需要新写「未听」计算逻辑，只需订阅 `inboxProvider` 并序列化。

**修正后的 B2 工作量评估**：

| 环节                             | 原估   | 修正后                                                           |
| -------------------------------- | ------ | ---------------------------------------------------------------- |
| 未听数据计算                     | 需新写 | **复用 `inboxProvider`**                                         |
| Dart→原生序列化                  | 需设计 | `InboxItem` → JSON 字符串（`HomeWidget.saveWidgetData<String>`） |
| 新 widget 类型 / 布局 / metadata | 需新建 | 不变                                                             |
| `play?guid=` 动作                | 需新增 | 不变（`DeskWidgetAction` 加 `play`）                             |
| Kotlin provider                  | 需新建 | 不变                                                             |

**结论**：B2 从「大」降为「中」，**已确认同版合入**（§0）。

**B2 三项待核验 —— 已全部解决**：

| #   | 问题                                          | 结论                                                                                                                                                                                                                                                                                      | 行动                                                                                                                                                                                                  |
| --- | --------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1   | `InboxItem` 字段结构                          | `core/podcast/feed_cache.dart:107` — `class InboxItem { final PodcastFeed feed; final PodcastEpisode episode; }`；`PodcastFeed`（`core/models/podcast.dart:6`）含 `id` / `title` / `feedUrl` / `imageUrl?`；`PodcastEpisode` 含 `guid` / `title` / `audioUrl` / `duration?` / `imageUrl?` | **序列化用 `episode.title` / `feed.title` / `episode.guid`**；格式见 §3.3.3                                                                                                                           |
| 2   | `InboxItem` 是否带 guid                       | **带**。`item.episode.guid` 直接可用                                                                                                                                                                                                                                                      | `chengbo://play?guid=<item.episode.guid>` 可行，无需回查 `feedCacheProvider`                                                                                                                          |
| 3   | 第二个 widget 是否需在 `home_widget` 包侧注册 | **不需要**。插件实现（`home_widget-0.8.0/android/.../HomeWidgetPlugin.kt`）为：`val className = call.argument<String>("android") ?: call.argument<String>("name")` → `Class.forName(qualifiedName ?: "${context.packageName}.${className}")`。即传任何类名都会被解析为 `<包名>.<类名>`    | **直接 `HomeWidget.updateWidget(name: DeskWidgetLogic.episodesAndroidName)`**，与现有 widget 调用方式一致。**但 Manifest 的 `<receiver>` 必须注册**（否则 `getAppWidgetIds` 返回空、launcher 找不到） |

**额外记录**：`FeedCacheLogic.maxInboxItems = 20`（inbox 上限），`maxEpisodesPerFeed = 40`（每 feed 缓存上限）。widget 取前 4（§3.3.1）。

---

## 9. 不做（重申 ban）

- Windows 端任何改动
- 电台剩余时间 / 已听时长（§5 第 4 条）
- **新 widget 显示单集封面**（4×2 cell 放 4 行 + 封面会挤压文字；留待后续评估）
- **替换现有 4×1 widget**（两个 widget 并存，职责不同）
- widget 与 App「外观」设置的深色一致性（§5 第 6 条，P2）
- 重构 Dart ↔ Kotlin 的键名契约（§5 第 8 条，独立改动）
- `widget_resume` 的 40dp 触控宽度（既有问题，见 §8.1 第 7 项）
- 歌词 / 高能进度条 / 评论时间戳 / Enhance Dialogue（已 ban）
- 卡片瀑布首页
