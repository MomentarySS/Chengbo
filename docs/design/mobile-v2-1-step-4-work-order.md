# v2.1 Step 4 实施工单 —— Android widget「Latest Episodes」模式（P0-B2）

> 范围：仅 P0-B2。**新增**第二个桌面 widget（4×2「待听」），**不替换**现有 4×1 widget。
> 上游：[`mobile-v2-1-plan.md` §3.3](./mobile-v2-1-plan.md)（实施就绪 v1.2 §3.3）
> 前置：P0-A 已合（PR #3） + P0-B1 已合（Step 3 实施后）；§8.2 三项 B2 待核验已全部解决
> 关联：§6.1 / §6.2 / §6.3 / §6.4 / §6.6 验证清单对应 B2 条目
> 配套：v2.1 整体规划 [`v2-1-release-tracker.md`](./v2-1-release-tracker.md)

---

## 1. 目标

新增第二个 Android 桌面 widget「待听」（4×2 cell），显示 `inboxProvider` 前 4 个未听单集；点击任一行触发 `chengbo://play?guid=<guid>` 直接开始播放；空数据时显示「暂无未听单集 · 点此打开澄波」。

---

## 2. 设计决策（已定，§3.3.1）

| 问题 | 决定 |
|---|---|
| 显示几个单集 | **4**（4×2 cell 容纳 4 行 × 48dp）|
| 与现有 widget 关系 | **新增**，不替换 |
| 点击单集行 | `chengbo://play?guid=<guid>` |
| 空数据文案 | 「暂无未听单集」+「点此打开澄波」|
| 整块点击 | `chengbo://open` |

---

## 3. 前置（已就绪）

| 依赖 | 现状 |
|---|---|
| `inboxProvider` | 已存在 `podcast_providers.dart:823`，返回 `List<InboxItem>` |
| `InboxItem` | 已存在 `core/podcast/feed_cache.dart:107`，字段 `{feed, episode}` 齐备 |
| `DeskWidgetSnapshot` 实际字段 | **当前为 `hasItem`**（95 行读到的真实字段；B1 工单里我误写为 `empty`，B1 动手 C1 时以现场为准） |
| `desk_widget_sync.dart` 已用 `Provider<void>` 体内多 `ref.listen` 模式 | 计划 §8.1 #2 同款结构 |
| Kotlin 工具链 | Kotlin 2.1.20 / AGP 8.9.1 / JVM 11 / `compileSdk 36` |
| `ChengboWidgetProvider.kt` 现有 `launch()` helper | 复用，不重写 |

---

## 4. 改法逐条

### 4.1 Dart 侧 —— `lib/core/audio/desk_widget.dart`

**(a)** 新增常量（紧跟现有 `resumeHost` 之后）：

```dart
// ----- B2 待听 widget ---------------------------------------------------
/// 改这里必须同步 `ChengboWidgetEpisodesProvider.kt` 第 N 行的字面量
/// (计划 §5 #8 跨语言契约)。
static const episodesKey = 'widget_episodes';
static const episodesAndroidName = 'ChengboWidgetEpisodesProvider';

/// 字面量字符串用于 Kotlin 端空态兜底；正式运行时优先走
/// `R.string.widget_episodes_empty_title` / `widget_episodes_empty_subtitle`
///（Android 端本地化路径）。Dart 常量仅作 fallback / 单测断言用。
static const episodesEmptyTitle = '暂无未听单集';
static const episodesEmptySubtitle = '点此打开澄波';

static const playHost = 'play';

/// 4×2 cell 容纳 4 行；`FeedCacheLogic.maxInboxItems = 20` 是 inbox 上限，
/// widget 取前 4（计划 §3.3.1）。
static const maxEpisodes = 4;
```

**(b)** `DeskWidgetAction` 加 `play`（**末尾追加，不重排已有枚举顺序**）：

```dart
enum DeskWidgetAction { open, toggle, next, resume, play, none }
```

**(c)** `actionForUri` 加 `play` 分支：

```dart
static DeskWidgetAction actionForUri(Uri? uri) {
  return switch (uri?.host) {
    openHost => DeskWidgetAction.open,
    toggleHost => DeskWidgetAction.toggle,
    nextHost => DeskWidgetAction.next,
    resumeHost => DeskWidgetAction.resume,
    playHost => DeskWidgetAction.play,   // 新增
    _ => DeskWidgetAction.none,
  };
}
```

**(d)** 新增纯函数 `episodesPayload`：

```dart
/// 序列化为 JSON 字符串。空列表返回 `[]`（原生侧据此显示空态）。
/// `take(max)` 语义：超过 max 截断。
static String episodesPayload(List<InboxItem> items, {int max = maxEpisodes}) {
  final rows = items.take(max).map((item) => {
        'title': item.episode.title,
        'subtitle': item.feed.title,
        'guid': item.episode.guid,
      });
  return jsonEncode(rows.toList());
}
```

> 顶部 import 加 `dart:convert`（`jsonEncode`）和 `../../core/podcast/feed_cache.dart`（`InboxItem`）。
>
> **注意**：这是 §6.6 测试矩阵的**唯一入口**。把序列化做成纯函数，单测只需构造 `InboxItem` 列表。

### 4.2 Dart 侧 —— `lib/core/platform/desk_widget_sync.dart`

**(a)** `publish()` 体内**新增** `ref.listen<List<InboxItem>>(inboxProvider, ...)`（与现有 `currentPlaybackProvider` / `audioHandlerProvider` / B1 加的 `dynamicColorProvider` 同层）：

```dart
ref.listen<List<InboxItem>>(inboxProvider, (_, next) {
  publishEpisodes(next);
});
```

**(b)** 新增 `publishEpisodes(List<InboxItem> items)` 函数（与现有 `publish()` 平级）：

```dart
Future<void> publishEpisodes(List<InboxItem> items) async {
  await HomeWidget.saveWidgetData<String>(
    DeskWidgetLogic.episodesKey,
    DeskWidgetLogic.episodesPayload(items),
  );
  await HomeWidget.updateWidget(
    name: DeskWidgetLogic.episodesAndroidName,
    androidResourceName: DeskWidgetLogic.episodesAndroidName,
  );
}
```

**(c)** `apply(Uri? uri)` switch 加 `play` 分支：

```dart
case DeskWidgetAction.play:
  await _playFromWidget(ref, uri?.queryParameters['guid']);
```

**(d)** 新增 `_playFromWidget(ref, guid)`：

```dart
Future<void> _playFromWidget(WidgetRef ref, String? guid) async {
  if (guid == null || guid.isEmpty) return; // 计划 §5 #11 边界
  final item = ref.read(inboxProvider)
      .where((i) => i.episode.guid == guid)
      .firstOrNull;
  if (item == null) return;                       // 静默降级
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

**(e)** **冷启动填充**：`publish()` 首次调用时也 `publishEpisodes(ref.read(inboxProvider))`（计划 §3.3.7 末段）。

### 4.3 Kotlin 侧 —— 新建 `ChengboWidgetEpisodesProvider.kt`

路径：`android/app/src/main/kotlin/com/chengbo/chengbo/ChengboWidgetEpisodesProvider.kt`

骨架（基于现有 `ChengboWidgetProvider.kt`，**不重写** `launch()` helper，直接复用）：

```kotlin
package com.chengbo.chengbo

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.view.View
import android.widget.RemoteViews
import org.json.JSONArray

class ChengboWidgetEpisodesProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        val data = HomeWidgetPlugin.getData(context)
        val raw = data.getString("widget_episodes", "[]")
        val rows = JSONArray(raw)

        appWidgetIds.forEach { id ->
            val views = RemoteViews(context.packageName, R.layout.chengbo_widget_episodes)

            if (rows.length() == 0) {
                // 空态
                views.setViewVisibility(R.id.widget_ep_empty, View.VISIBLE)
                views.setTextViewText(R.id.widget_ep_empty_title,
                    context.getString(R.string.widget_episodes_empty_title))
                views.setTextViewText(R.id.widget_ep_empty_subtitle,
                    context.getString(R.string.widget_episodes_empty_subtitle))
                for (i in 0 until 4) {
                    views.setViewVisibility(
                        resources.getIdentifier("widget_ep_row_$i", "id", packageName),
                        View.GONE
                    )
                }
            } else {
                views.setViewVisibility(R.id.widget_ep_empty, View.GONE)
                for (i in 0 until 4) {
                    val rowId = resources.getIdentifier("widget_ep_row_$i", "id", packageName)
                    if (i < rows.length()) {
                        val row = rows.getJSONObject(i)
                        views.setViewVisibility(rowId, View.VISIBLE)
                        views.setTextViewText(
                            resources.getIdentifier("widget_ep_row_${i}_title", "id", packageName),
                            row.optString("title", "")
                        )
                        views.setTextViewText(
                            resources.getIdentifier("widget_ep_row_${i}_subtitle", "id", packageName),
                            row.optString("subtitle", "")
                        )
                        views.setOnClickPendingIntent(
                            rowId,
                            ChengboWidgetProvider.buildLaunchPendingIntent(
                                context,
                                Uri.parse("chengbo://play?guid=${row.optString("guid", "")}")
                            )
                        )
                    } else {
                        views.setViewVisibility(rowId, View.GONE)
                    }
                }
            }

            // 整块点击 = open
            views.setOnClickPendingIntent(
                R.id.widget_ep_root,
                ChengboWidgetProvider.buildLaunchPendingIntent(
                    context,
                    Uri.parse("chengbo://open")
                )
            )

            // 复用 B1 的动态色 + 深色模式着色逻辑（先内联；B1+B2 都合后抽 helper）
            val useDynamic = data.getBoolean("widget_use_dynamic_color", false)
            val dynamicOk = useDynamic && Build.VERSION.SDK_INT >= Build.VERSION_CODES.S
            val bgRes = if (dynamicOk) android.R.color.system_accent1_600
                        else R.color.widget_background
            val onRes = if (dynamicOk) android.R.color.system_accent1_0
                        else R.color.widget_on_background
            views.setInt(R.id.widget_ep_root, "setBackgroundColor", context.getColor(bgRes))
            val onColor = context.getColor(onRes)
            views.setTextColor(R.id.widget_ep_empty_title, onColor)
            views.setTextColor(R.id.widget_ep_empty_subtitle, onColor)
            // 行标题 / 副文颜色也走 onColor（plan §3.3.4 4×2 cell 视觉一致）

            appWidgetManager.updateAppWidget(id, views)
        }
    }
}
```

> **抽公共着色 helper 的取舍**：本工单先**内联**（与 B1 `ChengboWidgetProvider.kt` 重复 6 行）。**B1 与 B2 都合后**再单独抽 helper，不在 B2 工单内做（避免引入未合并依赖）。

### 4.4 Android 资源 —— 新建 3 个文件

#### (a) `android/app/src/main/res/xml/chengbo_widget_episodes_info.xml`

```xml
<?xml version="1.0" encoding="utf-8"?>
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

#### (b) `android/app/src/main/res/layout/chengbo_widget_episodes.xml`

```xml
<?xml version="1.0" encoding="utf-8"?>
<LinearLayout xmlns:android="http://schemas.android.com/apk/res/android"
    android:id="@+id/widget_ep_root"
    android:layout_width="match_parent"
    android:layout_height="match_parent"
    android:orientation="vertical"
    android:padding="12dp"
    android:background="@color/widget_background">

    <TextView
        android:id="@+id/widget_ep_header"
        android:layout_width="wrap_content"
        android:layout_height="wrap_content"
        android:text="@string/widget_episodes_title"
        android:textColor="@color/widget_on_background"
        android:textSize="12sp"
        android:paddingBottom="4dp" />

    <LinearLayout
        android:id="@+id/widget_ep_row_0"
        android:layout_width="match_parent"
        android:layout_height="wrap_content"
        android:orientation="vertical"
        android:paddingTop="4dp" android:paddingBottom="4dp">
        <TextView android:id="@+id/widget_ep_row_0_title"
            android:layout_width="match_parent" android:layout_height="wrap_content"
            android:singleLine="true" android:ellipsize="end"
            android:textColor="@color/widget_on_background"
            android:textSize="14sp" android:textStyle="bold" />
        <TextView android:id="@+id/widget_ep_row_0_subtitle"
            android:layout_width="match_parent" android:layout_height="wrap_content"
            android:singleLine="true" android:ellipsize="end"
            android:textColor="@color/widget_on_background"
            android:textSize="11sp" />
    </LinearLayout>
    <!-- row_1 / row_2 / row_3 同结构，id 递增 -->
    <!-- ★ 落地时复制 3 遍，避免使用 include 引入歧义 -->

    <LinearLayout
        android:id="@+id/widget_ep_empty"
        android:layout_width="match_parent"
        android:layout_height="match_parent"
        android:orientation="vertical"
        android:gravity="center"
        android:visibility="gone">
        <TextView android:id="@+id/widget_ep_empty_title"
            android:layout_width="wrap_content" android:layout_height="wrap_content"
            android:text="@string/widget_episodes_empty_title"
            android:textColor="@color/widget_on_background"
            android:textSize="14sp" android:textStyle="bold" />
        <TextView android:id="@+id/widget_ep_empty_subtitle"
            android:layout_width="wrap_content" android:layout_height="wrap_content"
            android:text="@string/widget_episodes_empty_subtitle"
            android:textColor="@color/widget_on_background"
            android:textSize="12sp" android:paddingTop="2dp" />
    </LinearLayout>
</LinearLayout>
```

> 字符串引用 `@string/widget_episodes_title` / `widget_episodes_empty_title` / `widget_episodes_empty_subtitle` —— **4.4 (c) 集中声明**，避免硬编码中文字符串。

#### (c) `android/app/src/main/res/values/strings.xml` —— 加 4 行

```xml
<!-- B2 待听 widget -->
<string name="widget_episodes_description">澄波 · 待听单集</string>
<string name="widget_episodes_title">待听</string>
<string name="widget_episodes_empty_title">暂无未听单集</string>
<string name="widget_episodes_empty_subtitle">点此打开澄波</string>
```

### 4.5 AndroidManifest —— 加第二个 `<receiver>`

在现有 `ChengboWidgetProvider` receiver 之后追加：

```xml
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

---

## 5. 范围外（**不要做**）

- ❌ 抽 `ChengboWidgetProvider.kt` / `ChengboWidgetEpisodesProvider.kt` 公共着色 helper（B1+B2 都合后再做）
- ❌ 新 widget 显示单集封面（计划 §9 不做；4×2 cell 4 行 × 48dp 放封面会挤压）
- ❌ 替换现有 4×1 widget（计划 §9 不做；两 widget 职责不同）
- ❌ `widget_episodes_info.xml` 加 previewImage（计划 §9 不做；无合适截图）
- ❌ widget 元数据（minWidth / minHeight / targetCell）调整
- ❌ widget 点击行为以外的任何变更（resizeMode / configure activity 等）
- ❌ Windows / Web / macOS 任何改动
- ❌ `inboxProvider` / `FeedCacheLogic.inbox` 的逻辑（只读订阅）
- ❌ `widget_resume` 触控尺寸（40dp×48dp）修复（B1 §3.7 + 计划 §8.1 #7 都不做）

---

## 6. 语义边界自查（提交前）

| # | 场景 | 期望 |
|---|---|---|
| 1 | 添加新 widget，正常 inbox | 4 行可见，行内容正确（标题 + 节目名 + 点击有效）|
| 2 | inbox 只有 2 条 | 仅显示 2 行，其余 2 行 GONE，**无空白占位** |
| 3 | inbox 为空 | 显示「暂无未听单集 · 点此打开澄波」空态，4 行全部 GONE |
| 4 | 系统深色模式 | 跟随 B1 的 `values-night/colors.xml` 配色 |
| 5 | 动态色开关开（API 33+） | widget 背景走 `system_accent1_600` |
| 6 | 点击单集行 | App 打开并播放该集（guid 在 inbox 命中） |
| 7 | 点击单集行，但该集已被标记已听 | App 打开但**不**自动播放（静默降级） |
| 8 | 点击单集行，但 feed cache 刷新后 guid 已不在 inbox | 同 #7，静默降级 |
| 9 | 点击空态 widget | App 打开但不自动播放（`chengbo://open`）|
| 10 | 冷启动时 inbox 已填充 | 首次 `publish()` 时 `publishEpisodes()` 也写一次 |
| 11 | inbox 变化（订阅 / 听标记）| `ref.listen(inboxProvider)` 触发 `publishEpisodes` |
| 12 | `episode.title` 为空 | 该行标题空白但行仍显示，不崩 |
| 13 | 单集标题含引号 / emoji / 中文 | JSON 序列化正确往返 |
| 14 | `chengbo://play?guid=xxx` 800ms 内双击 | `isDuplicateLaunch` 拦截（既有逻辑） |
| 15 | 添加新 widget，4×1 widget 未添加 | 仅新 widget 工作；4×1 无副作用 |
| 16 | 两个 widget 都添加 | 互不干扰，各刷各的 |
| 17 | `guid` 为空 / null | 静默返回 |

---

## 7. 视觉位

**正常态**：
```
┌──────────────────────────────────────┐
│ 待听                                  │
│ ──────────────────────────────────  │
│ 单集标题 1                            │
│   节目名 1                            │
│ 单集标题 2                            │
│   节目名 2                            │
│ 单集标题 3                            │
│   节目名 3                            │
│ 单集标题 4                            │
│   节目名 4                            │
└──────────────────────────────────────┘
```

**部分数据态**（仅 2 条）：
```
┌──────────────────────────────────────┐
│ 待听                                  │
│ ──────────────────────────────────  │
│ 单集标题 1                            │
│   节目名 1                            │
│ 单集标题 2                            │
│   节目名 2                            │
│ │ ← row_2 / row_3 GONE
└──────────────────────────────────────┘
```

**空态**：
```
┌──────────────────────────────────────┐
│         暂无未听单集 │
│           点此打开澄波                  │
└──────────────────────────────────────┘
```

---

## 8. 验证清单

### 自动化

```bash
flutter analyze lib/core/audio/desk_widget.dart lib/core/platform/desk_widget_sync.dart
flutter test test/desk_widget_episodes_test.dart   # 新增，必跑
  # 6.6 矩阵 11 条：
  # - episodesPayload：空 / 1 / 4+（截断）/ 含特殊字符 / 空 title
  # - actionForUri：play正常 / play 无 guid / play 空 guid /
  #                  4 旧 URI 不变 / 未知 host / null
flutter test test/remaining_time_test.dart test/layer_test.dart test/widget_test.dart test/key_screens_test.dart
  # 现有 125/125 不回归
```

### 真机手动（计划 §6.1 / §6.2 / §6.3 / §6.4）

- 添加新 widget → 4 行内容正确显示
- inbox 标记某集已听 → widget 下次刷新该行消失，下一行顶上
- inbox 全空 / 未订阅任何播客 → 空态
- inbox 只有 2 条 → 仅 2 行可见
- 点击某行 → App 打开并播放
- App 关闭后点击 widget 标题区 → 仅打开，不自动播放
- App 内打开某集，听到一半 → widget 行不变（widget 是 inbox 不是 playing）
- 系统深色模式 → widget 配色跟随
- 动态色开关切换 → widget 颜色下次刷新更新
- 两个 widget 并存 → 互不影响
- 单独只添加新 widget（不添加 4×1）→ 正常工作

### 截图位（建议留 5 张）

- 正常 4 行
- 部分 2 行
- 空态
- 系统深色 + 正常
- API 33 动态色开

### 回归（计划 §6.4）

- Windows 端**任何**代码无变化
- 现有 4×1 widget 的动作与显示无回归（`DeskWidgetAction` 加 `play` 后，原 4 枚举值**顺序未变**，switch 兼容）
- `initialLaunchUri` / `isDuplicateLaunch` 现有行为无回归
- 「收听」tab 的未听 inbox 显示与 widget 一致（同一 `inboxProvider`）
- mini player（P0-A）无回归
- widget 4×1（B1）无回归

---

## 9. 提交策略

| 项 | 决策 |
|---|---|
| 分支 | `feat/v2-1-widget-b2`（新分支，从干净 main 开） |
| 提交数 | **4 个**（按依赖顺序） |

```
D1 (Dart 契约)   : DeskWidgetLogic 加 episodesKey / episodesAndroidName /
                   episodesEmptyTitle / episodesEmptySubtitle / maxEpisodes /
                   playHost + DeskWidgetAction 加 play + actionForUri 加 play
                   分支 + episodesPayload 纯函数
D2 (Dart 同步)   : desk_widget_sync.dart 加 publishEpisodes / ref.listen
                   (inboxProvider) / _playFromWidget / apply() 加 play 分支
                   + 冷启动填充
D3 (Kotlin + 资源) : ChengboWidgetEpisodesProvider.kt 新建 + 3 个 Android
                   资源文件 + AndroidManifest receiver + strings.xml
D4 (测试)         : test/desk_widget_episodes_test.dart（11 用例）→ §6.6 矩阵全覆盖
```

| 标题（D1） | `feat(widget): add Latest Episodes payload + play action (B2 step 4)` |
| 标题（D2） | `feat(widget): publish Latest Episodes + handle chengbo://play` |
| 标题（D3） | `feat(widget): Latest Episodes 4x2 widget + Manifest + layout` |
| 标题（D4） | `test(widget): DeskWidgetLogic.episodesPayload + actionForUri matrix` |

| 关联 | 引用 `mobile-v2-1-plan.md` §3.3 / §5 / §6.6；本工单 `mobile-v2-1-step-4-work-order.md` 入仓 |

---

## 10. 与已有代码的冲突面

- `DeskWidgetAction` 加 `play` 枚举值 → switch 兼容性由 Dart 语言保证（旧 switch 不覆盖 `_` 兜底也兼容）
- `desk_widget_sync.dart` 改 → `Provider<void>` 体内已多 `ref.listen`，新增 1 处无风险
- Kotlin 新建 Provider → 与现有 `ChengboWidgetProvider.kt` 互不依赖；只用现有 `launch()` helper
- AndroidManifest 加 `<receiver>` → 与现有 receiver 独立，零冲突
- 新增 layout / info / strings → 全部新增，零修改
- `windows/` 不动

---

## 11. 我建议的执行顺序

| 阶段 | 动作 | 风险 |
|---|---|---|
| A | grep `DeskWidgetAction` / `actionForUri` 全量引用点 | 0 |
| B | D1：DeskWidgetLogic 加常量 + play + episodesPayload | 低 |
| C | D2：desk_widget_sync.dart 加 publishEpisodes + ref.listen + _playFromWidget | 低 |
| D | D3：Kotlin + Android 资源 + Manifest + strings | 中 |
| E | D4：测试 11 用例 | 低 |
| F | 跑 §8 自动化 + 推送 + 开 PR | — |

---

## 12. 待拍板的 3 件事

| # | 问题 | 我的默认 | 备选 |
|---|---|---|---|
| 1 | `chengbo_widget_episodes.xml` 用 `<include>` 复用 4 行模板，还是直接复制 4 遍？ | **复制 4 遍**（简单、不引入 `<include>` 歧义） | `<include>` 抽象 `widget_ep_row.xml` |
| 2 | B1/B2 两 Kotlin Provider 都内联着色逻辑（重复 6 行），是否现在抽 helper？ | **现在不抽**（B1+B2 都合后单独做）| 现在抽 → 多一次重构 commit 风险 |
| 3 | 空态文案：Kotlin 用 `R.string.*` 还是用 Dart `DeskWidgetLogic.episodesEmptyTitle`？ | **Kotlin 走 `R.string.*`**（本地化、可翻译），Dart 常量仅注释说明 | Dart 常量编译期保证 —— 但 Android 端走 R.string 够用 |

---

## 13. 变更记录

| 日期 | 版本 | 变更 |
|---|---|---|
| 2026-09-22 | 1.0 | 初稿。基于 `mobile-v2-1-plan.md` v1.2 §3.3 落地为可施工的工单。前提：P0-A + P0-B1 已合 main |