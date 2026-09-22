# v2.1 Step 3 实施工单 — Android widget 视觉重做（P0-B1）

> 范围：仅 P0-B1。P0-B2（Latest Episodes widget）**不在本工单内**，下个工单。
> 上游：[`mobile-v2-1-plan.md` §3.2](./mobile-v2-1-plan.md)（实施就绪 v1.2）
> 前置：P0-A（PR #3 已合）+ v2.1 plan v1.3（PR #2 已合）；§8.1 八项勘察已全部完成
> 关联：§6.1 / §6.2 / §6.3 / §6.4 验证清单对应 B1 条目

---

## 1. 目标

把现有 4×1 widget（`ChengboWidgetProvider` / `chengbo_widget.xml`）从「硬编码深澄蓝 + 系统拟物图标」升级到「**尊重 App 壁纸配色开关** + **深色模式变体** + **M3 vector 图标**」。逻辑层（`DeskWidgetSnapshot` 数据契约 / `desk_widget_sync.dart` 发布路径）同步扩展 1 个字段。

---

## 2. 前置（已就绪）

| 依赖 | 现状 | 来源 |
|---|---|---|
| `dynamicColorProvider` 声明 | `StateNotifierProvider<DynamicColorNotifier, AsyncValue<bool>>`，`app_providers.dart:881` | 计划 §8.1 #1 已确认 |
| `publish()` 体内可加 `ref.listen` | `desk_widget_sync.dart` 的 `publish()` 已在 `Provider<void>` 体内监听 `currentPlaybackProvider` / `audioHandlerProvider` | 计划 §8.1 #2 已确认 |
| `compileSdk = 36`（`android.R.color.system_accent1_*` 可用）| `android/app/build.gradle.kts` 已确认 | 计划 §8.1 #5 已确认 |
| `values-night/colors.xml` 无冲突 | 当前 `values-night/` 只有 `styles.xml`，`<color>` 0 个 | 计划 §8.1 #6 已确认 |
| Kotlin 工具链 | Kotlin 2.1.20 / AGP 8.9.1 / JVM 11 / `compileSdk 36` | 计划 §8.1 #5 已确认 |
| `widget_resume` 40dp×48dp 触控尺寸 | **既有问题**，本版**不修** | 计划 §8.1 #7 已记录为 §9 不做 |

---

## 3. 改法逐条

### 3.1 Dart 侧 —— `lib/core/audio/desk_widget.dart`

**(a)** 新增常量（紧跟现有 `titleKey` / `subtitleKey` / `playingKey` 等常量之后）：

```dart
/// B1 动态色开关的数据键。改这里必须同步 `ChengboWidgetProvider.kt`
/// 第 N 行的字符串字面量（计划 §5 第 8 条）。
static const useDynamicColorKey = 'widget_use_dynamic_color';
```

**(b)** `DeskWidgetSnapshot` 加字段 + `const` 构造器加参数（**必填**，无默认值 —— 强制所有现有调用点显式选择）：

```dart
class DeskWidgetSnapshot {
  const DeskWidgetSnapshot({
    required this.title,
    required this.subtitle,
    required this.playing,
    required this.useDynamicColor,  // 新增
    required this.empty,
  });
  final String title;
  final String subtitle;
  final bool playing;
  final bool useDynamicColor;       // 新增
  final bool empty;
}
```

**(c)** `DeskWidgetSnapshot` 是 immutable value class，加字段后**所有调用点**必须更新。计划 §3.2.1 暗示只 1 处调用（`desk_widget_sync.dart` 的 `publish()`），其他如有需一并改。

> 边界自查点：**先全文 grep `DeskWidgetSnapshot(` 调用**，列清单后再改构造器 ——避免下游编译失败。

### 3.2 Dart 侧 —— `lib/core/platform/desk_widget_sync.dart`

**(a)** `publish()` 体内**新增** `ref.listen<AsyncValue<bool>>(dynamicColorProvider, ...)`（与现有两处 `ref.listen` 同层，紧跟 `currentPlaybackProvider` 之后）：

```dart
ref.listen<AsyncValue<bool>>(dynamicColorProvider, (_, next) {
  publish(...);  // 取 .value ?? true 后作为 useDynamicColor 传入
});
```

**(b)** `publish()` 实现里：

- 从 `ref.read(dynamicColorProvider).value ?? true` 取 `useDynamicColor`（与 `app.dart:20` 现有用法一致）
- 在调用 `HomeWidget.saveWidgetData` 时新增一行：

```dart
await HomeWidget.saveWidgetData<bool>(
  DeskWidgetLogic.useDynamicColorKey,
  useDynamicColor,
);
```

- 构造 `DeskWidgetSnapshot` 时传 `useDynamicColor: useDynamicColor`

### 3.3 Kotlin 侧 —— `ChengboWidgetProvider.kt`

**修改 `onUpdate(context, appWidgetManager, appWidgetIds, widgetType)`** 主体着色逻辑：

```kotlin
val useDynamic = data.getBoolean("widget_use_dynamic_color", false)
val dynamicOk = useDynamic && Build.VERSION.SDK_INT >= Build.VERSION_CODES.S

val bgRes = if (dynamicOk) android.R.color.system_accent1_600
            else            R.color.widget_background
val onRes = if (dynamicOk) android.R.color.system_accent1_0
            else            R.color.widget_on_background

views.setInt(R.id.widget_root, "setBackgroundColor", context.getColor(bgRes))
val onColor = context.getColor(onRes)
views.setTextColor(R.id.widget_title, onColor)
views.setTextColor(R.id.widget_subtitle, onColor)
views.setTextColor(R.id.widget_resume, onColor)
```

**回归保护**：
- `SDK_INT < 31`（无 `Build.VERSION_CODES.S`）→ `dynamicOk = false`，与现状完全一致（品牌深澄蓝）
- `widget_use_dynamic_color` 缺失 → `getBoolean(..., false)` 兜底；用户没开过 App → 走品牌色
- `values-night/colors.xml`（3.4 新建）让深色系统模式自动生效；运行时着色代码不变

### 3.4 Android 资源 —— 新建 `values-night/colors.xml`

新建 `android/app/src/main/res/values-night/colors.xml`：

```xml
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="widget_background">#0A3A66</color>
    <color name="widget_on_background">#E2E2E9</color>
</resources>
```

- `#0A3A66` = 品牌深澄蓝 `#0D4F8C` 的深色变体，与 `DESIGN.md` 的 `surface-dark` 同调
- `#E2E2E9` = `DESIGN.md` 的 `on-surface-dark`
- 与现有 `values/colors.xml` 的同名 color 形成资源限定符对应关系（系统深色模式自动切换）

### 3.5 Android 资源 —— 新建 4 个 M3 vector drawable

在 `android/app/src/main/res/drawable/` 下新建：

| 文件 | M3 图标参考 | 用于 |
|---|---|---|
| `ic_widget_play.xml` | `play_arrow`（实心） | `widget_toggle` 在 `playing=false` 时 |
| `ic_widget_pause.xml` | `pause`（实心） | `widget_toggle` 在 `playing=true` 时 |
| `ic_widget_next.xml` | `skip_next`（实心） | `widget_next` |
| `ic_widget_resume.xml` | `play_circle`（轮廓） | **本版不接**（保留文件，未来 `widget_resume` 改 ImageView 时用） |

每个文件统一格式：

```xml
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="24dp" android:height="24dp"
    android:viewportWidth="24" android:viewportHeight="24"
    android:tint="@color/widget_on_background">
    <path android:fillColor="#FFFFFFFF" android:pathData="..."/>
</vector>
```

> 着色走 `@color/widget_on_background`，深色模式自动跟随 `values-night/colors.xml`。

### 3.6 Android 布局 —— `chengbo_widget.xml`

只改 **2 个 `ImageView` 的 `android:src`**：

| View | 现状 | 改为 |
|---|---|---|
| `widget_toggle` | `android:src="@android:drawable/ic_media_play"` | **运行时按 `playing` 切** `ic_widget_play` / `ic_widget_pause`（在 Kotlin 侧 `onUpdate` 用 `RemoteViews.setImageViewResource` 切换） |
| `widget_next` | `android:src="@android:drawable/ic_media_next"` | `android:src="@drawable/ic_widget_next"`（静态） |

**`widget_toggle` 切换代码**（Kotlin `onUpdate` 内）：

```kotlin
views.setImageViewResource(
    R.id.widget_toggle,
    if (data.getBoolean("widget_playing", false))
        R.drawable.ic_widget_pause
    else
        R.drawable.ic_widget_play
)
```

> XML 的 `android:src` 给一个默认值（建议 `ic_widget_play`），运行时 Kotlin 覆盖。

**`widget_resume` 不动**（计划 §5 #7 明确）：保留 `TextView` + 文字「续」，避免点击热区与 `contentDescription` 语义回归。

### 3.7 范围外（**不要做**）

- ❌ `widget_resume` 改 `ImageView`（计划 §5 #7）
- ❌ widget 加圆角（`setBackgroundColor` 不引入圆角 ——计划 §6.2 #9）
- ❌ widget 跟 App 内的「外观」设置（跟随系统 / 浅色 / 深色）联动 —— 计划 §5 #6 明确记录为「已知不一致，本版不修」
- ❌ widget 元数据（minWidth / minHeight / 4×1 cell）调整
- ❌ widget 任何点击行为改动（`chengbo://` URI 不变）
- ❌ P0-B2 的 Latest Episodes widget（**下个工单**）
- ❌ `DeskWidgetAction` 加 `play`（P0-B2 才加）
- ❌ Windows / Web / macOS 任何改动
- ❌ `widget_resume` 40dp×48dp 触控尺寸修复（计划 §8.1 #7 列为 §9 不做）

---

## 4. 语义边界自查（提交前）

| # | 场景 | 期望 |
|---|---|---|
| 1 | API 30 设备，App 开关开启 | widget 用品牌深澄蓝（`system_accent1_*` 不存在） |
| 2 | API 33+ 设备，App 开关开启 | widget 用壁纸 accent1_600 背景 + accent1_0 文字色 |
| 3 | API 33+ 设备，App 开关关闭 | widget 用品牌深澄蓝背景 + 白色文字 |
| 4 | 系统深色模式 | widget 用 `values-night/colors.xml` 的 `#0A3A66` / `#E2E2E9` |
| 5 | 系统深色模式 + App 开关开 | widget 用 accent1_600 背景 + accent1_0 文字（动态色覆盖深色） |
| 6 | widget 在播放中 → pause 图标；暂停 → play 图标 | 切换无闪烁、无白底 |
| 7 | widget 四个动作（打开 / 续播 / 播停 / 下一台） |全部仍可用，`contentDescription` 不变 |
| 8 | widget「续」字按钮 | 仍为 `TextView`，可点、语义不变 |
| 9 | widget 未添加到桌面 | `onUpdate` 不执行；`publish()` 写数据无害 |
| 10 | App 开关切换（运行中）| widget 下次 `publish()` 重绘（`ref.listen` 触发）|
| 11 | 跨进程（系统 launcher 缓存 widget） | `RemoteViews` 重绘触发 `onUpdate`，无需重启 launcher |
| 12 | Kotlin 字符串字面量与 Dart 常量不同步 | 静默退化为品牌色（不崩）—— 通过 §6.1 「动态色开关开启」验收 |
| 13 | 现有 3 个数据键（`widget_title` / `widget_subtitle` / `widget_playing`）读取 | 不回归 |

---

## 5. 视觉位

**浅色 + 动态色开（API 33+）**：
```
┌──────────────────────────────────────────┐
│ 单集标题（白色）            [▶]  [⏭]  续 │
│ 节目名（白色）                           │
└──────────────────────────────────────────┘
   bg = system_accent1_600 (Material You)
```

**浅色 + 动态色关**（现状）：
```
┌──────────────────────────────────────────┐
│ 单集标题（白色）            [▶]  [⏭]  续 │
│ 节目名（白色）                           │
└──────────────────────────────────────────┘
   bg = #0D4F8C (品牌深澄蓝)
```

**深色 + 动态色关**（新增）：
```
┌──────────────────────────────────────────┐
│ 单集标题（#E2E2E9）         [▶]  [⏭]  续 │
│ 节目名（#E2E2E9）                        │
└──────────────────────────────────────────┘
   bg = #0A3A66 (深色变体)
```

**深色 + 动态色开（API 33+）**：
```
┌──────────────────────────────────────────┐
│ 单集标题（白色）            [▶]  [⏭]  续 │
│ 节目名（白色）                           │
└──────────────────────────────────────────┘
   bg = system_accent1_600 (动态色覆盖深色)
```

---

## 6. 验证清单

### 自动化

```bash
flutter analyze lib/core/audio/desk_widget.dart lib/core/platform/desk_widget_sync.dart
flutter test test/remaining_time_test.dart test/layer_test.dart test/widget_test.dart test/key_screens_test.dart
  # 现有 125/125 不回归（widget 数据契约是新增 1 个 key，不影响旧测试）
```

### 真机 / 模拟器手动（计划 §6.1 / §6.3）

- API 30 模拟器：开关开/关 → 都是品牌深澄蓝（验证 §4 #1）
- API 33 模拟器：开关开 → 壁纸色；开关关 → 品牌色（验证 §4 #2、#3）
- 系统深色模式（API 30、API 33 各一遍）→ 深色变体生效（验证 §4 #4、#5）
- widget 添加 / 移除 / 重新添加 → 颜色与图标正确
- 播放 / 暂停切换 → toggle 图标实时切换（验证 §4 #6）
- 四个按钮全部点一遍 → 行为不变（验证 §4 #7、#8）
- App 内开关切换 → widget 颜色下次发布时更新（验证 §4 #10）

### 截图位（建议留 4 张供 PR 评论）

- API 30 / 品牌色（基线）
- API 33 / 动态色开
- 系统深色 + 动态色关
- 系统深色 + 动态色开

### 回归（计划 §6.4）

- Windows 端**任何**代码无变化（`git diff --stat` 看 `windows/` 为空）
- 通知栏 / 锁屏封面无回归（`.ico` 仍被拦截）
- 列表封面渲染无回归（`ArtworkUrlLogic` 清理后）
- mini player 无回归（PR #3）

---

## 7. 提交策略

| 项 | 决策 |
|---|---|
| 分支 | `feat/v2-1-widget-b1`（新分支，从干净 main 开） |
| 提交数 | **4 个**（按依赖顺序，最小可独立编译）|

```
C1 (Dart 契约)   : DeskWidgetLogic.useDynamicColorKey + DeskWidgetSnapshot
                    加 useDynamicColor 字段 + 调用点更新 → compile error，预期
C2 (Dart 同步)   : desk_widget_sync.dart 写入新 key + ref.listen
                    → compile 通过，widget 仍读不到（Kotlin 未改），功能退化为品牌色
C3 (Kotlin + 资源): ChengboWidgetProvider.kt 着色逻辑
                    + values-night/colors.xml
                    + 4 个 M3 vector drawable
                    + chengbo_widget.xml 的 widget_next src
                    → 运行时整体生效
C4 (Kotlin 图标切换): widget_toggle 的 src 按 playing 切换
                    → 最后一步
```

| 标题（C1） | `feat(widget): add useDynamicColor to DeskWidgetSnapshot` |
| 标题（C2） | `feat(widget): publish widget_use_dynamic_color from App switch` |
| 标题（C3） | `feat(widget): Material You + dark variant + M3 icons` |
| 标题（C4） | `feat(widget): swap toggle icon based on playing state` |

| 关联 | 引用 `mobile-v2-1-plan.md` §3.2 / §5 / §6；本工单 `mobile-v2-1-step-3-work-order.md` 入仓 |

---

## 8. 与已有代码的冲突面

- `DeskWidgetSnapshot` 加必填字段 → **强制 `publish()` 内构造点更新**；其他调用点需 `git grep DeskWidgetSnapshot(` 全量列清单
- `desk_widget_sync.dart` 改 → `Provider<void>` 体内已经 2 处 `ref.listen`，新增 1 处无风险
- Kotlin `onUpdate` 改 → 现有 `widget_*` 读取代码逻辑不变；只在着色分支新增条件
- 资源新建 → 4 个 drawable + 1 个 colors.xml + 1 个 layout 字段，全为新增/局部改，零删除
- `windows/` 不动

---

## 9. 我建议的执行顺序

| 阶段 | 动作 | 风险 |
|---|---|---|
| A | grep `DeskWidgetSnapshot(` 全量调用点 → 落清单 | 0 |
| B | C1：DeskWidgetSnapshot 加字段 + 调用点更新 | 低（编译失败隔离）|
| C | C2：desk_widget_sync.dart 写入新 key + `ref.listen` | 低（widget 静默退化为品牌色）|
| D | C3：Kotlin + 资源 + 布局 | 中（Kotlin + 资源组合）|
| E | C4：toggle 图标按状态切换 | 低（最后一步）|
| F | 跑 §6 自动化 + 推送 + 开 PR | — |

---

## 10. 待拍板的 3 件事

| # | 问题 | 我的默认 | 备选 |
|---|---|---|---|
| 1 | `ic_widget_resume.xml` 是否真的创建（既然 §3.2.3 写要建，§5 #7 又说 `widget_resume` 不接）？ | **建但不接**，留作未来资产，PR 评论里注明 | 不建（少一个 unused drawable，commit 更净）|
| 2 | C1 / C2 是**单独 commit** 还是**合并为 1 个 commit**？ | **2 个独立 commit**（你的偏好：小颗粒独立 commit）| 合并 |
| 3 | Kotlin 里 `Build.VERSION_CODES.S` 是用 `Build.VERSION.SDK_INT >=` 比较还是用 `when`？ | 用 `>=` 简单条件（计划 §3.2.1 就是这样写的）| `when` 更 Dart-like 但本场景没必要 |

---

## 11. 变更记录

| 日期 | 版本 | 变更 |
|---|---|---|
| 2026-09-22 | 1.0 | 初稿。基于 `mobile-v2-1-plan.md` v1.2 §3.2 落地为可施工的工单。前提：v2.1 plan v1.3 已合入 main（PR #2） |