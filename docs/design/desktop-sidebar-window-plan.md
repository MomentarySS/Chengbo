# 桌面侧栏窗口 —— 实施计划

> 在研究文档 `docs/design/mobile-research-2026-09.md` 与方向 C 判断的基础上，对 P0 首项「桌面侧栏窗口」做实施计划。
> 范围：Windows-only 新增，不修改 Android 端任何代码。
> **状态：v1.0 — 实施就绪（implementation-ready）**。所有勘察已完成（12 项），无遗留未知项。
> 起草：2026-09-22

**执行前提**：本计划排在 v2.1 移动端 P0 三件（通知封面 / mini player 剩余时间 / widget 重做）之后。理由见 §0。

---

## 0. 执行顺序与依赖

| 版本 | 内容 | 状态 |
|---|---|---|
| **v2.1** | 移动端 P0 三件（通知 / 锁屏封面不用 favicon；mini player 加精确剩余时间；Android widget 重做） | 计划待写 |
| **v2.2** | **本计划**（桌面侧栏窗口）+ P1（桌面 hover 态、键盘导航面板） | 本文档 |

**为什么桌面在后**：
1. 用户当前以手机为主，v2.1 ROI 更高
2. 侧栏的「当前播放区」若显示剩余时长，依赖 v2.1 在 `PlaybackItem` / handler 侧暴露的 duration 字段 —— 先做 v2.1 可避免侧栏回炉
3. 两者代码面几乎不重叠（v2.1 动 `mini_player.dart` / `local_notifications.dart` / Android widget；v2.2 动 `desk_*`），但 `app_providers.dart` 是共享的只读依赖

**不冲突的验证**：v2.1 的字段变化必须是 additive（新增字段，不改现有字段语义），这样 v2.2 的只读订阅不会被打断。

---

## 0.1 文档地图

| 要做什么 | 去哪节 |
|---|---|
| 了解目标和边界 | §1 §2 |
| **照着写代码** | **§0.2 实施顺序** → §3.1–§3.11 |
| 知道哪些文件能改、哪些不能 | §4 |
| 提交前自查边界情况 | §5 |
| 跑验证 | §6（§6.4 手动 / §6.5 自动） |
| 查"这个结论是怎么来的" | §8（12 项勘察，全部已核完） |
| 查启动时序 / 为什么不在 main.dart 里 apply | §11 |
| 明确不做的事 | §9 |

---

## 0.2 实施顺序（任务分解）

按依赖排序。每步独立可编译、可提交。

### 第 1 步：纯逻辑层（可单测，无副作用）

1. `lib/core/platform/desk_window_mode.dart`
   - `enum DeskWindowMode { miniBar, sidebar, main }`
   - `DeskWindowModeLogic.resolveOnLaunch(...)`（§3.8 的 6 行表格）
   - 枚举名 ↔ storage 字符串映射（含非法值回退）
2. `lib/core/platform/desk_compact.dart`：加 `sidebarWidth = 720` / `sidebarHeight = 540` / `sidebarSize` / `snapThreshold = 16.0`
3. `lib/core/platform/desk_sidebar_window_controller.dart`：**只写纯函数部分** `snapTarget({window, workArea, threshold})`
4. `lib/core/platform/desk_tray.dart`：`DeskTrayAction` 加 3 个枚举值 + `actionForMenuKey` 映射 + 菜单 label 常量
5. **测试**：`test/desk_window_mode_test.dart` + `test/desk_sidebar_snap_test.dart`（§6.5 全部条目）
6. 提交（此时 UI 未变，纯新增）

### 第 2 步：storage + provider

7. `lib/core/storage/app_storage.dart`：加 `desk_window_mode` / `desk_sidebar_position` 两个 key 的 getter/setter
8. `lib/core/providers/app_providers.dart`：新增 `deskWindowModeProvider`（`DeskWindowModeNotifier`，照 §3.8 骨架）
9. 提交

### 第 3 步：窗口层（`desk_window.dart` 三态化）

10. `apply({required bool compact})` → `apply({required DeskWindowMode mode})`；旧签名保留为私有 helper 转发
11. 加 `_currentMode` 静态字段（互斥 invariant，§3.6）
12. 加 `_lastSidebarPosition`（§3.11 位置持久化）
13. **验证点**：此时浮条 / 主窗口行为必须与改动前**完全一致**（跑 §6.4 的浮条相关项）
14. 提交

### 第 4 步：侧栏 widget

15. `lib/shared/widgets/desk_sidebar_window.dart`：三栏布局（§3.5）
16. `desk_sidebar_window_controller.dart`：补副作用部分 `snapIfNearEdge()` / `clampToWorkArea()` / `_animateTo()`
17. `pubspec.yaml` 加 `screen_retriever: ^0.2.2` 显式依赖
18. 提交

### 第 5 步：接线（4 个入口）

19. `home_shell.dart`：加 `if (windowMode == sidebar) return DeskSidebarWindow();` 分支（§8.3）
20. `desk_mini_bar.dart`：加 `onExpandSidebar` 可选回调 + [□] 按钮（插在 `×` 之前）
21. `desk_tray_sync.dart`：菜单插动态项；mode 变化时 `refreshChrome(force: true)`
22. `desk_hotkey.dart`：加 `Ctrl+Shift+S`
23. 提交

### 第 6 步：设置项 + 全量验证

24. `playback_screen.dart`：插「桌面窗口形态」三选一（在「开机启动」之后、「关闭窗口最小化到托盘」之前）
25. 跑 §6.1–§6.3 + §6.4 全量
26. 更新 `CHANGELOG.md`（此时才写，因为已实施）
27. 更新本文件 §7 变更记录
28. 提交

**每步的验收标准**：编译通过 + 该步新增的测试通过 + 前序步骤的验证点不回归。

---

## 1. 目标与范围

**目标**：为 Windows 用户提供「侧栏窗口」形态（720×540，无边框，可贴屏幕边），让桌面端**不再感觉是手机 app 放大版**，同时**不破坏** Android 体验、不引入 Fluent / Mica / Acrylic 控件。

**包含**：
- 720×540 无边框窗口
- 三栏布局：当前播放 / 队列 / 收藏
- 与现有桌面浮条、托盘、快捷键的形态切换
- 设置项「桌面窗口形态」（浮条 / 侧栏 / 完整窗口，三选一）
- 启动即上次形态
- 托盘菜单新增切换项
- Ctrl+Shift+S 切换浮条 ↔ 侧栏

**不包含**：
- Android 端任何改动
- 主窗口重做（NavigationRail 保留）
- Fluent / WinUI 控件
- Win11 任务栏小组件（已 ban）
- 多屏 / DPI 自适应（P2 阶段）
- 自动磁吸动画细节优化（P2 阶段）

---

## 2. 状态总览

| 维度 | 现状（v2.0.2） | 目标（v2.1+） |
|---|---|---|
| 桌面专属 surface | 桌面浮条（456×100，无边框） | 浮条 + 侧栏窗口（720×540）双形态 |
| 窗口互斥 | 仅浮条与主窗口互斥 | 浮条 / 侧栏 / 主窗口三者互斥，**任一时刻仅一个可见** |
| 窗口状态持久化 | 浮条状态由 `deskCompactProvider` 存 | 增加 `deskWindowModeProvider`：枚举 `miniBar` / `sidebar` / `main` |
| 内容来源 | `app_providers.dart` 的 `currentPlaybackProvider` / `playQueueProvider`（单一真相源） | 不变；侧栏订阅同一 provider |
| 窗口生命周期 | `desk_window.dart` 的 `apply(compact: bool)` 二态 | 扩展为 `apply(mode)` 三态；保留旧 API 向后兼容 |
| 触发入口 | 设置 → 桌面迷你窗开关；启动即迷你窗开关；托盘 / 快捷键 | 在「播放与收听」设置页新增「桌面窗口形态」三选一 |
| 与播放协同 | 浮条与主窗口切换不打断播放 | 同上：侧栏 / 浮条 / 主窗口切换不打断播放 |

---

## 3. 具体改法

### 3.1 新增枚举与 provider

- `lib/core/platform/desk_window_mode.dart`（新文件）
  - `enum DeskWindowMode { miniBar, sidebar, main }`
  - `final deskWindowModeProvider = NotifierProvider<...>(...)` 持久化到 `SharedPreferences`
  - 默认值：与现有 `deskCompactProvider` 一致 —— 桌面首次启动 = `main`

### 3.2 `desk_window.dart` 扩展

当前 `apply({required bool compact})` 改为：
```dart
static Future<void> apply({required DeskWindowMode mode}) async {
  if (!DeskCompactLogic.offeredOnThisPlatform) return;

  switch (mode) {
    case DeskWindowMode.miniBar:
      // 现有 compact = true 分支（不动）
      break;
    case DeskWindowMode.sidebar:
      // 新增：无边框 + 720×540 + alwaysOnTop + 不可最大化
      await windowManager.setAsFrameless();
      await windowManager.setBackgroundColor(const Color(0x00000000));
      await windowManager.setHasShadow(true);
      await windowManager.setAlwaysOnTop(true);
      await windowManager.setResizable(false);
      await windowManager.setMaximizable(false);
      await windowManager.setMinimumSize(DeskCompactLogic.sidebarSize);
      await windowManager.setMaximumSize(DeskCompactLogic.sidebarSize);
      await windowManager.setSize(DeskCompactLogic.sidebarSize);
      // 恢复上次侧栏位置（磁吸后）
      break;
    case DeskWindowMode.main:
      // 现有 compact = false 分支（不动）
      break;
  }
}
```

**保留向后兼容**：保留旧 `apply({required bool compact})` 私有 helper 转发到三态版本，避免一次性改动所有调用方。

### 3.3 `desk_compact.dart` 扩展

- 新增 `static const Size sidebarSize = Size(720, 540);`
- 新增 `static const double snapThreshold = 16.0;`（磁吸距离）

### 3.4 新建 `desk_sidebar_window.dart`

`lib/shared/widgets/desk_sidebar_window.dart`：
- 顶层 `ConsumerWidget`，订阅 `app_providers.dart` 的 `currentPlaybackProvider` / `playQueueProvider` / `playerControllerProvider`，以及 `radio_providers.dart` 的 `favoriteStationsProvider`
- 三栏布局（详见 §3.5）
- 暴露根 widget 的 `onCloseRequested`、`onExpandToMainRequested`、`onSwitchToMiniBarRequested` 回调

### 3.5 三栏布局规格

```
┌──────────────────────────────────────┐
│  当前播放（340 高）                    │
│  ├─ 大封面 200×200 圆角 12           │
│  ├─ 台名 titleMedium w600            │
│  ├─ 副文（ICY / 节目名）              │
│  ├─ 进度条（podcast）/ 音量条（radio）│
│  ├─ Outlined IconButton: 收藏 / 队列 │
│  └─ Filled IconButton 44: 主播放     │
│  ── 分割线 1px outline-variant ──   │
│  队列（120 高）                        │
│  ├─ Compact ListTile 列表            │
│  └─ 复用 now_playing_queue_sheet 样式 │
│  ── 分割线 ──                         │
│  收藏（剩余高度）                      │
│  ├─ ListView 滚动                     │
│  └─ ListTile compact                  │
│  ── 分割线 ──                         │
│  底栏 56 高                            │
│  [⛶ 主窗口] [□ 浮条] [× 关窗]         │
└──────────────────────────────────────┘
```

**复用**：
- 当前播放封面 / 标题 / 副文 → `lib/core/audio/now_playing_indicator.dart`
- 进度条 / 音量条 → 现有 Now Playing 组件
- 队列列表 → `lib/shared/widgets/now_playing_queue_sheet.dart`（去掉 sheet 容器，仅保留 ListView）
- 收藏列表 → 现有 station ListTile，与主窗口统一
- ColorScheme / 圆角 / 间距 → 现有 `core/theme.dart` 的 tokens

### 3.6 与现有 surface 协同（互斥规则）

| 关系 | 行为 | 实现位置 |
|---|---|---|
| 浮条 → 侧栏 | 双击浮条 / 浮条 [□] 按钮 / 托盘「切换到侧栏」 / Ctrl+Shift+S | `desk_mini_bar.dart` 加回调；`desk_tray.dart` 加菜单 |
| 侧栏 → 浮条 | 侧栏 [□ 浮条] 按钮 / 托盘「切换到浮条」 / Ctrl+Shift+S | 新 widget 内部 |
| 侧栏 → 主窗口 | 侧栏 [⛶ 主窗口] 按钮 / 托盘「打开主窗口」 | 新 widget 内部 |
| 主窗口 → 侧栏 | 设置项 / 托盘菜单 | 现有「桌面迷你窗」开关旁加「窗口形态」三选一 |

**互斥 invariant**：在 `DeskWindow` controller 层加 `_currentMode` 静态变量。任何 `apply()` 调用前检查并 `await windowManager.hide()` 当前窗口（如果可见）。widget 层**不维护**这一状态。

### 3.7 设置项 UI

在 `lib/features/settings/playback_screen.dart` 的桌面迷你窗 / 启动即迷你窗开关旁，新增：
- ListTile `secondary: Icon(Icons.desktop_windows_outlined)`
- `title: const Text('桌面窗口形态')`（窗口切换 / Window mode）
- `subtitle: Text('浮条 / 侧栏窗口 / 完整窗口')`
- 点击弹出底部 sheet：`miniBar / sidebar / main` 单选列表，当前选中态高亮

**位置**：紧跟在「启动即迷你窗」之后、「开机启动」之前，保持"播放与收听"组的桌面相关项连续。

### 3.8 启动即上次形态

**⚠️ 与 §11 初稿不同 —— 已修正为跟随现有架构。**

现有 `DeskCompactNotifier._load()`（`app_providers.dart` 第 658-673 行）就是"启动即恢复窗口形态"的实现位置：

```dart
Future<void> _load() async {
  final storage = await _ref.read(appStorageProvider.future);
  final compact = await storage.getDeskCompactEnabled();
  final launchCompact = await storage.getDeskLaunchCompactEnabled();
  final catalogConfigured = await storage.getStationCatalogConfigured();
  final enabled = DeskLaunchLogic.compactOnLaunch(...);
  if (enabled && !compact) await storage.setDeskCompactEnabled(true);
  state = AsyncData(enabled);
  await DeskWindow.apply(compact: enabled);   // ← 在这里 apply
}
```

新的 `DeskWindowModeNotifier._load()` 照抄这个骨架：

```dart
Future<void> _load() async {
  final storage = await _ref.read(appStorageProvider.future);
  final mode = await storage.getDeskWindowMode();          // 新增，默认 main
  final launchCompact = await storage.getDeskLaunchCompactEnabled();
  final catalogConfigured = await storage.getStationCatalogConfigured();
  // 保留旧行为：启动即迷你窗 + 首次选收听范围时仍用完整窗口
  final resolved = DeskWindowModeLogic.resolveOnLaunch(
    mode: mode,
    launchCompact: launchCompact,
    catalogConfigured: catalogConfigured,
  );
  state = AsyncData(resolved);
  await DeskWindow.apply(mode: resolved);
}
```

`DeskWindowModeLogic.resolveOnLaunch` 的规则（纯函数，可单测）：

| mode | launchCompact | catalogConfigured | 结果 |
|---|---|---|---|
| `main` | `false` | 任意 | `main` |
| `main` | `true` | `true` | `miniBar`（旧行为兼容） |
| `main` | `true` | `false` | `main`（首次选收听范围需完整窗口） |
| `miniBar` | 任意 | 任意 | `miniBar` |
| `sidebar` | 任意 | `true` | `sidebar` |
| `sidebar` | 任意 | `false` | `main`（首次选收听范围需完整窗口） |

**时序说明**：provider 在 HomeShell 首次 `ref.watch` 时（`home_shell.dart` 第 143 行附近）才 `_load()`，即首帧之后。这与现有浮条行为**完全一致**——窗口会先以 runner 默认尺寸（`windows/runner/main.cpp` 的 1280×720）出现，再 resize 到目标形态。这是既有行为，不新增回归。

### 3.9 托盘菜单扩展

`lib/core/platform/desk_tray.dart`：
- 在「播放 / 暂停」与「退出」之间插入分组：
  - 「当前窗口：浮条 / 侧栏 / 完整」（仅显示当前）
  - 「切换到浮条」「切换到侧栏」「打开主窗口」（互斥显示另外两个）

### 3.10 快捷键

`lib/core/platform/desk_hotkey.dart`：
- 新增 `Ctrl+Shift+S`：在 `miniBar ↔ sidebar` 间切换；如果是 `main`，切到 `miniBar`（默认最小形态）

### 3.11 磁吸 + 任务栏避让（实现路径）

**依赖决策：不需要 raw Win32。**

`screen_retriever` 0.2.2 已在 `pubspec.lock`（`window_manager` 的 transitive dep），其 `Display` 类型直接给出工作区：

```dart
class Display {
  final Size size;              // 全屏尺寸（含任务栏区域）
  final Offset visiblePosition; // 工作区左上角
  final Size visibleSize;       // 工作区尺寸（已排除任务栏）
}
```

→ `visiblePosition` + `visibleSize` 就是 `SPI_GETWORKAREA` 的结果，**无需 FFI**。

**动作项**：把 `screen_retriever: ^0.2.2` 从 transitive 提升为 `pubspec.yaml` 的**显式依赖**（`import` 需要）。

**新建 `lib/core/platform/desk_sidebar_window_controller.dart`**：

```dart
abstract final class DeskSidebarWindowController {
  static const snapThreshold = 16.0;
  static const snapDuration = Duration(milliseconds: 150);

  /// 拖动结束后调用：判断是否吸附到工作区边缘。
  static Future<void> snapIfNearEdge() async {
    if (!DeskCompactLogic.offeredOnThisPlatform) return;
    try {
      final display = await screenRetriever.getPrimaryDisplay();
      final work = Rect.fromLTWH(
        display.visiblePosition.dx,
        display.visiblePosition.dy,
        display.visibleSize.width,
        display.visibleSize.height,
      );
      final pos = await windowManager.getPosition();
      final size = await windowManager.getSize();

      // 左 / 右 / 上 / 下 四个方向，取最小距离
      final targets = <Offset, double>{
        Offset(work.left, pos.dy): (pos.dx - work.left).abs(),
        Offset(work.right - size.width, pos.dy): (work.right - (pos.dx + size.width)).abs(),
        Offset(pos.dx, work.top): (pos.dy - work.top).abs(),
        Offset(pos.dx, work.bottom - size.height): (work.bottom - (pos.dy + size.height)).abs(),
      };
      final best = targets.entries.reduce((a, b) => a.value <= b.value ? a : b);
      if (best.value > snapThreshold) return;
      await _animateTo(pos, best.key, snapDuration);
    } catch (_) {}
  }

  /// window_manager.setPosition 是瞬时的，需要自己插值出动画。
  static Future<void> _animateTo(Offset from, Offset to, Duration duration) async {
    const steps = 9; // 150ms / 9 ≈ 17ms ≈ 60fps
    for (var i = 1; i <= steps; i++) {
      final t = Curves.easeOutCubic.transform(i / steps);
      await windowManager.setPosition(Offset.lerp(from, to, t)!);
      await Future<void>.delayed(duration ~/ steps);
    }
  }
}
```

**接线点**：`desk_sidebar_window.dart` 的拖动区 `onPanEnd` 回调 → `DeskSidebarWindowController.snapIfNearEdge()`。**浮条不受影响**（浮条是自由拖动，不吸附）。

**边界处理**（对应 §5 第 5 条的三个问题）：

| 场景 | 处理 |
|---|---|
| 任务栏在底部 | `work.bottom` 已排除任务栏高度 → 侧栏贴 `work.bottom` 即为任务栏上沿 |
| 任务栏在右侧（罕见） | 同上，`work.right` 已排除；四方向都基于 work area 计算，天然正确 |
| 任务栏自动隐藏 | `visibleSize` 反映**当前**状态；自动隐藏时等于全屏 → 吸附到屏幕边缘。用户唤出任务栏时窗口会被压住 —— 接受（P2 再做 `WM_SETTINGCHANGE` 监听） |
| 多显示器 | 用 `getPrimaryDisplay()`（主屏）。拖到副屏不吸附 —— P2 再做（需 `getAllDisplays()` + 命中测试） |
| 拔掉外接屏 | 窗口可能落在屏幕外 → 启动时 `resolveOnLaunch` 后加一次"工作区内钳制"（clamp），见下方 |

**位置钳制（启动时）**：
```dart
static Future<void> clampToWorkArea() async {
  // 恢复的 _lastSidebarPosition 若不在当前工作区内，拉回工作区中央
  // 判定：窗口矩形与 work area 无交集 → 视为丢失
}
```

**位置持久化**：`desk_window.dart` 新增 `_lastSidebarPosition`（`Offset?`），在 `apply(mode: sidebar)` 时若为 null 则计算默认位置（工作区右侧、垂直居中）；窗口移动结束时写回。持久化到 `SharedPreferences` key `desk_sidebar_position`（存 `dx,dy` 两个 double，用 `setDoubleList`）。

---

## 4. 技术约束

### 4.1 必须复用
- `lib/core/platform/desk_window.dart`：现有 `window_manager` 调用；扩展为三态
- `lib/core/providers/app_providers.dart`：`currentPlaybackProvider` / `playQueueProvider` / `playerControllerProvider` —— 单一真相源
- `lib/features/radio/radio_providers.dart`：`favoriteStationsProvider` / `visibleStationsProvider` —— 侧栏收藏区订阅
- `lib/core/platform/desk_tray_sync.dart`：`refreshChrome()` 第 107-119 行菜单构建点；mode 变化时需 `force: true`
- `lib/core/platform/desk_tray.dart`：托盘菜单注入新条目
- `lib/core/theme.dart`：所有 ColorScheme / 圆角 / 间距
- `lib/core/audio/now_playing_indicator.dart`：当前播放信息组件
- `lib/shared/widgets/now_playing_queue_sheet.dart`：队列列表样式
- `lib/shared/widgets/desk_mini_bar.dart`：浮条上加 [□] 按钮
- `lib/core/platform/desk_hotkey.dart`：Ctrl+Shift+S 注册

### 4.2 新建 / 新增依赖

- `lib/core/platform/desk_window_mode.dart`：`DeskWindowMode` 枚举 + `DeskWindowModeLogic` 纯函数（`resolveOnLaunch` 等，可单测）
- `lib/shared/widgets/desk_sidebar_window.dart`：侧栏 widget 根
- `lib/core/platform/desk_sidebar_window_controller.dart`：磁吸 + 工作区钳制 + 位置持久化
- **`pubspec.yaml` 新增显式依赖**：`screen_retriever: ^0.2.2`（当前是 `window_manager` 的 transitive dep，`import` 需要提升为直接依赖；无需新增第三方包，`pubspec.lock` 已有 0.2.2）
- **`app_storage.dart` 新增两个 key**：
  - `desk_window_mode`（String，枚举名；默认 `'main'`）
  - `desk_sidebar_position`（`List<double>`，`[dx, dy]`）

### 4.3 不动
- Android 端任何代码
- 主窗口 NavigationRail
- 浮条 widget 主结构（仅加 [□] 按钮）
- 托盘代码结构（仅在菜单加选项）
- ColorScheme / 组件库 / 字体 tokens

---

## 5. 语义边界与风险（提交前自查）

按用户偏好「先列边界情况」：

1. **窗口状态持久化**
   - 用户上次用的是浮条还是侧栏？→ `SharedPreferences` key `desk_window_mode`；默认 `main`
   - 状态丢失时（首次启动）如何回退？→ 回退到 `main`，不假定用户偏好
   - 切换时正在播放会被打断吗？→ 不打断；窗口形态切换只调 `apply()`，不动 playback

2. **多窗口 / 多屏**
   - 用户拖到第二屏怎么算"屏幕边"？→ 仅当前主屏；用 `WidgetsBinding.instance.platformDispatcher.views.first`
   - 两块屏分辨率不同怎么定位？→ 用逻辑坐标（Flutter `Offset`），不存绝对像素
   - 拔掉外接屏后窗口丢失？→ 下次启动重置到主屏中央

3. **DPI 缩放**
   - Windows 125% / 150% 缩放下 720×540 实际像素会变 → Flutter 已用逻辑尺寸
   - 字号 / 触控目标会被缩放影响 → 验证 150% 下 44dp 按钮仍可点；用 `MediaQuery.textScaleFactor` 检查

4. **磁吸 vs 用户意图冲突**
   - 用户想拖到屏幕中，途中触发磁吸，窗口闪一下？→ 阈值 ≤16px 才吸附；吸附用 150ms 缓动，不要瞬移
   - 拖动方向（左右）不对称？→ 左右对称吸附，但保留底部贴边吸附（任务栏可能在底部）
   - 二次拖出磁吸区后是否保留记忆？→ 保留 `_lastManualPosition`，下次拖动优先用

5. **任务栏避让**
   - 用户侧栏贴右边，任务栏在底部（自动隐藏）→ 当任务栏显示时窗口应上移（P2 做 `WM_SETTINGCHANGE` 监听；P0 接受被压住）
   - 当任务栏在屏幕右侧（罕见但存在）→ 应贴底部而不是右侧
   - 多显示器不同任务栏位置？→ 用 `screen_retriever` 的 `getPrimaryDisplay().visibleSize`（工作区，已排除任务栏），**不需要 `SPI_GETWORKAREA`**。详见 §3.11

6. **与浮条的互斥**
   - 同时存在的 bug 历史？→ `desk_window.dart` 必须有 invariant：任一时刻只允许一个 surface 持有焦点
   - 互斥逻辑放在 controller 还是 widget？→ controller（`DeskSidebarWindowController`）持有 `_currentMode`；widget 只读不写
   - 浮条 visible 状态被 race 改写？→ 用 `apply()` 互斥串行化，所有调用 await 同一锁

7. **关闭语义**
   - 点 [×] 是关到托盘还是退出？→ 与浮条一致：保留音频播放，只隐藏窗口
   - 第二次点 [×] 才退出？→ 与 Win 习惯一致；设置里给「双击关闭 = 退出」开关（P2 暂不做）
   - 关闭窗口 vs 切换窗口是不同的概念 → 明确：[×] = 隐藏并保留后台；[□ 浮条] = 切换形态

8. **键盘焦点**
   - 侧栏打开时 Space 应该切换播放吗？→ 是（沿用现有快捷键语义）
   - 但 Space 必须不被侧栏内部按钮吃掉 → 侧栏根节点不响应 Space，由 `desk_hotkey.dart` 层处理
   - Tab 键焦点顺序？→ 当前播放 → 队列 → 收藏 → 底栏按钮，自上而下

9. **辅助功能**
   - Narrator 看到侧栏内容？→ ListTile 自带 Semantics；自定义 widget 加 `Semantics(label: '当前播放 XX 电台')`
   - 高对比度模式 → 跟随系统（与主窗口一致）
   - 屏幕阅读器朗读「底栏 56 高」区域 → 整组 Semantics label='窗口控制'

10. **回归风险（最容易踩）**
    - 改了 `apply()` 影响现有浮条 / 主窗口切换 → 保留旧 `compact` 路径作为私有 helper
    - 启动时 `deskLaunchCompactProvider` 与新 `deskWindowModeProvider` 互打架 → 见 §3.8 兼容规则
    - 托盘菜单加了选项导致菜单高度变化，鼠标位置错位 → 用菜单 popup 而不是固定坐标
    - 切换窗口时桌面图标短暂闪烁 → `setSkipTaskbar(true)` 后再 `show()`

---

## 6. 验证清单

### 6.1 功能
- [ ] 浮条 → 侧栏（双击浮条 / [□] 按钮 / 托盘菜单 / Ctrl+Shift+S）四条路径
- [ ] 侧栏 → 浮条 / 主窗口（三条路径）
- [ ] 三种形态切换时不打断播放
- [ ] 启动即上次形态
- [ ] 退出后音频继续（与浮条行为一致）
- [ ] 关闭最小化到托盘时音频不中断
- [ ] 设置项切换形态立即生效
- [ ] 托盘菜单显示当前形态

### 6.2 视觉
- [ ] 720×540 标准尺寸
- [ ] 125% / 150% DPI 下不破版（按钮可点、字号不溢出）
- [ ] 浅色 / 深色 / 三个致敬氛围包下都一致
- [ ] 磁吸动画顺滑（150ms）
- [ ] 当前播放封面光晕与主窗口一致

### 6.3 边界
- [ ] 多屏切换不丢窗口
- [ ] 任务栏位置变化时自动避让
- [ ] 拖动到非磁吸区正常悬浮
- [ ] Narrator 朗读语义正确
- [ ] 长时间运行（≥4h）窗口位置不漂移

### 6.4 回归（最重要）—— 手动 checklist

**必须在真机 Windows 上手动跑。** 原因：窗口形态 / 磁吸 / 托盘 / DPI 都依赖真实窗口管理器，Flutter widget test 无法覆盖。

- [ ] Android 端**任何**代码无变化（`git diff` 确认 `lib/` 下无 Android-only 文件改动；`git diff --stat` 检查 `android/` 目录为空）
- [ ] 浮条交互无回归（双击、单击、拖动、× 关闭）
- [ ] 托盘菜单无回归（原有播放 / 退出 / 收藏等）
- [ ] Space / ←→ 快捷键无回归
- [ ] 主窗口 NavigationRail 无回归
- [ ] 设置项「桌面迷你窗」「启动即迷你窗」「开机启动」行为无回归
- [ ] 首次启动（清空 storage）走完整窗口，不被新 mode 逻辑干扰
- [ ] 首次选收听范围时仍是完整窗口（`catalogConfigured == false` 例外）

### 6.5 自动化测试

新增 `test/desk_window_mode_test.dart`（纯逻辑，无需真窗口）：

- [ ] `DeskWindowModeLogic.resolveOnLaunch` 的 6 种组合（见 §3.8 表格）全覆盖
- [ ] `DeskWindowMode` 枚举名 ↔ storage 字符串的双向映射（含非法值回退 `main`）
- [ ] `DeskTrayLogic.actionForMenuKey` 对新 key（`switchToSidebar` / `switchToMiniBar` / `switchToMain`）的映射
- [ ] `DeskTrayLogic.actionForMenuKey(null)` / 未知 key → `DeskTrayAction.none`（不崩）

扩展 `test/desk_sidebar_snap_test.dart`（把吸附算法抽为纯函数后）：

- [ ] 四个方向的吸附判定（左 / 右 / 上 / 下）
- [ ] 超出 `snapThreshold` 不吸附
- [ ] 恰好等于 `snapThreshold` 吸附（边界）
- [ ] 多方向同时接近时选最近的
- [ ] 窗口尺寸等于工作区尺寸时的退化（距离为 0，不应除零）

**接线点**：`_animateTo` 的插值逻辑**不测**（依赖真实窗口）；只测"从哪个位置吸附到哪个位置"的**决策**。为此 `snapIfNearEdge` 需拆为：

```dart
// 纯函数，可测
static Offset? snapTarget({
  required Rect window,
  required Rect workArea,
  double threshold = snapThreshold,
});

// 副作用，不测
static Future<void> snapIfNearEdge() async { /* 读窗口 → 调 snapTarget → 动画 */ }
```

---

## 7. 变更记录

| 日期 | 版本 | 变更 |
|---|---|---|
| 2026-09-22 | 0.1 | 初稿。基于 `docs/design/mobile-research-2026-09.md` 方向 C 落地 |
| 2026-09-22 | 0.2 | §8.1：第一轮勘察结果（8 项 + 4 个新增待勘察项）。修正 §4.1 中 `playback_session.dart` 文件名错误 |
| 2026-09-22 | 0.3 | §8.2–8.3：第二轮勘察结果（4 个新增项均完成）+ 派生设计决策 5 条。新增 §11 启动时序草案 |
| 2026-09-22 | 0.4 | §3.8 重写（改为 provider `_load()` 模式）；§3.11 新增（磁吸 + 任务栏避让实现路径，确认用 `screen_retriever` 而非 raw Win32）；§4.2 补依赖与 storage key；§8.2/§8.3 修正 `main.dart` 结论；§11 重写并移位；§6.4 拆分 |
| 2026-09-22 | **1.0** | **实施就绪**。§6.4 拆为手动 checklist + §6.5 自动化测试（含 `snapTarget` 纯函数抽取要求）；§11 补逃生舱；变更记录合并去重；3 处遗留的 `playback_session.dart` 引用全部修正 |
| 2026-09-22 | **1.1** | 新增 §0 执行顺序与依赖、§0.1 文档地图、§0.2 实施顺序（6 步任务分解 + 每步验收标准）。ROADMAP.md 加入口指向本计划 |

---

## 8. 待核验（执行前回到代码确认）

> **8 项，不是 9 项。** 原 §8 写"9"是口误，已修正。

- [ ] `desk_window.dart` 第 8-10 行的 `_restoredSize / _restoredPosition` 是否要拆分为 `_lastSidebarPosition` 单独保存侧栏位置
- [ ] `desk_compact.dart` 当前 `compactSize` 是 456×100 还是其他值 → 用于推断 sidebar 尺寸的相对比例
- [ ] `playback_session.dart` 暴露给 widget 的接口是否够用（侧栏订阅 currentStation / queue / favorites）
- [ ] `desk_tray.dart` 菜单的扩展点（如何加分组和动态选项）
- [ ] `desk_hotkey.dart` 是否已有 Ctrl+Shift 系列快捷键避免冲突
- [ ] `playback_screen.dart` 中「桌面迷你窗」开关的精确位置（已读到 53 行附近），用于插入新设置项
- [ ] `desk_mini_bar.dart` 当前的回调 API（如何加 [□] 按钮而不破坏现有交互）
- [ ] `windows/runner/` 是否有 dpiAwareness 配置需要同步

### 8.1 勘察结果（2026-09-22 已核完）

| # | 问题 | 结论 | 行动 |
|---|---|---|---|
| 1 | `desk_window.dart` 状态字段 | 第 8-10 行有 `_restoredSize / _restoredPosition / _compactApplied` 三个静态字段。`apply()` 当前是二态；侧栏需独立位置 | **改**：拆为 `_mainRestoredSize / _mainRestoredPosition` + `_lastSidebarPosition`（Offset），保留旧字段向旧 API 兼容 |
| 2 | `compactSize` 数值 | `lib/core/platform/desk_compact.dart` 第 6-7 行确认：`compactWidth = 456`、`compactHeight = 100`、`compactSize = Size(456, 100)`；另有 `artSize = 72`、`barHeight = 64`、`playSize = 52` | **直接用现值**；侧栏新增 `sidebarWidth = 720`、`sidebarHeight = 540` 到同一文件 |
| 3 | 真正的 widget 订阅接口 | **`playback_session.dart` 文件名错了**——它是 Android 音频会话（music/speech）配置，与 widget 无关。真正的接口在 `lib/core/providers/app_providers.dart`：`audioHandlerProvider`（handler + 流）、`currentPlaybackProvider`（当前台）、`playQueueProvider`（队列）、`playerControllerProvider`（控制）、`sleepTimerProvider`、`podcastSkipStepProvider`、`podcastSpeedProvider`。**电台列表**（收藏 / 筛选 / 可见）在 `lib/features/radio/radio_providers.dart`，侧栏需另外勘察该文件 | **改 plan §4.1**：把 `playback_session.dart` 替换为 `app_providers.dart`；新增勘察 `radio_providers.dart` |
| 4 | 托盘菜单扩展点 | `desk_tray.dart` 是**纯逻辑层**（无原生调用），`DeskTrayAction` 枚举只有 `restore / toggle / quit / none`。真实原生实现在 `desk_tray_sync.dart`（**未勘察**） | **新增勘察**：`desk_tray_sync.dart`；扩展 `DeskTrayAction` 加 `switchToSidebar / switchToMiniBar / switchToMain` 三个枚举值 |
| 5 | Ctrl+Shift 冲突 | `desk_hotkey.dart` 第 40-56 行的 `actionForKey` 只处理 `LogicalKeyboardKey.space / arrowLeft / arrowRight`。**没有任何 Ctrl 组合**，也没有 Shift 组合 | **直接用 Ctrl+Shift+S**，无冲突 |
| 6 | 设置页插入点 | 已读到 `playback_screen.dart` 第 50-150 行附近。当前桌面项顺序：① 桌面迷你窗 ② 启动即迷你窗 ③ 开机启动 ④ 关闭窗口最小化到托盘（纯 ListTile，无开关） ⑤ 键盘快捷键（纯 ListTile，无开关）。新「桌面窗口形态」三选一应插入 **③ 之后、④ 之前** | **修改 playback_screen.dart**：在 ③ 和 ④ 之间插入新 ListTile，弹出底部 sheet |
| 7 | 浮条回调 API | `desk_mini_bar.dart` 第 21-23 行：`const DeskMiniBar({super.key, required this.onExit})`，只有 `final VoidCallback onExit` 一个回调，对应 [×] 按钮。**没有 [□] / [⛶] 类侧栏入口** | **改 DeskMiniBar 构造**：新增 `final VoidCallback? onExpandSidebar` 可选回调；父级（`HomeShell`）拿到时转发到 `DeskWindow.apply(mode: sidebar)` |
| 8 | DPI 感知 | `windows/runner/runner.exe.manifest` 第 5 行：`<dpiAwareness>PerMonitorV2</dpiAwareness>`。**已配置最高级别** | **不动**，125% / 150% 缩放下 Flutter 已正确处理 |

**新增需勘察项（执行前必看）**：

- [x] `lib/features/radio/radio_providers.dart`：收藏 / 筛选 / 可见电台的 provider 命名（侧栏收藏区要订阅）
- [x] `lib/core/platform/desk_tray_sync.dart`：托盘菜单的真实实现入口（原生 `Menu` 构建）
- [x] `lib/features/home/home_shell.dart`：浮条在哪个父级，`DeskMiniBar.onExit` 当前如何处理（决定新 `onExpandSidebar` 怎么接进去）
- [x] `lib/main.dart` 启动路径：现有 `DeskWindow.ensureReady()` 之后是否能立即读取 `deskWindowModeProvider` 并应用

### 8.2 第二轮勘察结果（2026-09-22 已核完）

| 文件 | 关键发现 | 对侧栏的意义 |
|---|---|---|
| `radio_providers.dart` | 所有需要的 provider 都在此文件：<br>• `stationsProvider`（StateNotifierProvider，AsyncValue&lt;List&lt;RadioStation&gt;&gt;，主列表）<br>• `catalogStationsProvider`（StateProvider&lt;List&lt;RadioStation&gt;&gt;，catalog 全量）<br>• `visibleStationsProvider`（Provider，AsyncValue&lt;List&lt;RadioStation&gt;&gt;，**已过滤可播**）<br>• `filteredStationsProvider`（Provider，AsyncValue&lt;List&lt;RadioStation&gt;&gt;，**搜索+分类+码率筛选后**）<br>• `favoriteIdsProvider`（StateNotifierProvider，AsyncValue&lt;Set&lt;String&gt;&gt;）<br>• `favoriteStationsProvider`（Provider，AsyncValue&lt;List&lt;RadioStation&gt;&gt;） | 侧栏**收藏区**直接订阅 `favoriteStationsProvider` 即可；**队列区**复用 `playQueueProvider`（在 `app_providers.dart`） |
| `desk_tray_sync.dart` | • 用 `tray_manager` 包<br>• 菜单在 `refreshChrome()` 第 107-119 行硬编码：`[MenuItem(show), MenuItem(toggle), separator, MenuItem(quit)]`<br>• `DeskTrayBinding` 是 `Provider<void>`，由 HomeShell 第 139 行 `ref.watch(deskTraySyncProvider)` 触发初始化<br>• **没有 mode 变化时自动重建菜单** —— 必须显式调 `binding.refreshChrome(force: true)`<br>• `DeskTrayAction` 枚举需扩展（plan §3.9 提到的 `switchToSidebar / switchToMiniBar / switchToMain`） | **改 `desk_tray.dart`** 加枚举值；**改 `desk_tray_sync.dart` 第 109-117 行**的 `Menu(items: [...])` 插入动态选项；**改 HomeShell 第 139 行附近**当 mode 变化时调 `refreshChrome(force: true)` |
| `home_shell.dart` | • 第 143 行：`final deskCompact = ref.watch(deskCompactProvider).value ?? false;` 决定渲染 DeskMiniBar 还是 Scaffold<br>• 第 171-182 行：当 `deskCompact == true` 直接渲染 `DeskMiniBar(onExit: ...)`，**没有 Scaffold 父级**<br>• `onExit` 当前只调 `ref.read(deskCompactProvider.notifier).setEnabled(false)`<br>• 第 144 行：`useRail = MediaQuery.sizeOf(context).width >= ChengboTheme.railBreakpoint`（900px）<br>• **注意**：侧栏 720 &lt; 900，所以走 `useRail == false` 路径 —— 但侧栏**不应该**渲染 NavigationBar | 新决策树：<br>`if (windowMode == sidebar) return DeskSidebarWindow();`<br>`if (deskCompact) return DeskMiniBar(...);`<br>`else 走原逻辑`<br>新 `onExpandSidebar` 回调：调 `DeskWindow.apply(mode: sidebar)` + 切 `deskWindowModeProvider` 到 sidebar |
| `main.dart` | • 第 22-28 行 `Future.wait` 平行启动 5 个首帧前任务：`SystemHttpProxy.discover / preload / DeskWindow.ensureReady / _loadSystemAccent / _configureStartupAudioSession`<br>• 第 29 行 `runApp(const ProviderScope(child: ChengboApp()));`<br>• **没有现成"读 mode 后 apply"hook** | **❌ 初稿建议的 `_applyDeskWindowMode()` 加到 `Future.wait` 已被推翻**（见 §11）：首帧前没有 `ProviderScope`，只能用裸 `SharedPreferences` 绕过 `appStorageProvider`，且与现有 `DeskCompactNotifier` 模式不一致。**正确做法是在 provider 的 `_load()` 里 apply**（与 `DeskCompactNotifier` 第 672 行一致） |

### 8.3 派生的设计决策

| 决策 | 选择 | 理由 |
|---|---|---|
| 侧栏模式时 HomeShell 渲染什么 | 整棵 `DeskSidebarWindow` widget（不是 Scaffold + NavigationBar） | 720 &lt; 900 不能走 rail；侧栏不应该出现 4 个 tab 入口（侧栏是"专注正在播放 + 队列 + 收藏"，不是另一个目的地） |
| 模式切换的触发点 | HomeShell 的 build（`ref.watch(deskWindowModeProvider)`）+ 显式调 `DeskWindow.apply()` | `apply()` 内部已有 `_compactApplied` 模式可借鉴；新增 `_currentMode` 字段 |
| 启动即上次形态的实现时机 | **provider 的 `_load()` 内**（与 `DeskCompactNotifier` 完全一致） | 首帧前没有 `ProviderScope`；现有浮条已用这个模式且可接受。详见 §11 |
| 托盘菜单新增选项的触发 | mode provider 变化时调 `binding.refreshChrome(force: true)` | 当前 `refreshChrome` 只看播放/标题变化，不看 mode —— 需要扩展 |
| 浮条加 [□] 按钮的位置 | 浮条右侧 `×` 按钮**之前**（现有 Row 的 children 末位插入新 IconButton） | 与现有 `× 回到完整窗口` 语义连贯；不要破坏左右滑动切台的手势 |

---

## 9. 不做（重申 ban）

- Win11 任务栏小组件（已 ban）
- Fluent / WinUI / Mica / Acrylic（设计原则禁）
- Android 端任何改动
- 主窗口重做
- 卡片瀑布首页（已在 research 文档 P3）
- 歌词 inline（无源数据）
- 高能进度条 / 评论时间戳（社交）
- Enhance Dialogue / 均衡器 / 音量增强（已 ban）

---

## 10. 后续路径

- 完成侧栏后，P1 候选：
  - 桌面 hover 态（list 行 hover 显示次操作）
  - 键盘导航面板（设置页内）
- 完成 P0+P1 后评估 P2：
  - 磁吸动画细节优化
  - 「双击关闭 = 退出」开关
  - 多屏智能定位

**完成本计划前不开下一项。**

---

## 11. 启动时序与窗口形态应用时机（修正版）

### 11.1 现有架构事实（勘察所得）

| 事实 | 来源 |
|---|---|
| runner 初始窗口 1280×720 @ (10,10) | `windows/runner/main.cpp` |
| 窗口形态的 apply **发生在 provider 的 `_load()` 里**，不是 `main.dart` | `app_providers.dart` 第 672 行 `await DeskWindow.apply(compact: enabled)` |
| provider 首次被读是在 HomeShell 的 build（首帧之后） | `home_shell.dart` 第 143 行 `ref.watch(deskCompactProvider)` |
| 「启动即迷你窗」的完整逻辑（含首次选收听范围的例外）在 `DeskLaunchLogic.compactOnLaunch` | `desk_launch.dart` 第 26-31 行 |
| `main.dart` 首帧前只做基础设施：HTTP 代理 / `DeskWindow.ensureReady()` / 系统色 / 音频会话 | `main.dart` 第 22-28 行 |

**结论**：现有浮条在启动时**会**经历"先以 1280×720 出现 → 首帧后 resize 到 456×100"。这是既有行为，用户已接受。

### 11.2 初稿建议（已推翻）

初稿建议在 `main.dart` 的 `Future.wait` 里加 `_applyDeskWindowMode()`，理由是不闪。**否决原因**：

1. **首帧前没有 `ProviderScope`** —— 只能用裸 `SharedPreferences` 绕过 `appStorageProvider`，引入第二个 storage 访问路径
2. **与现有模式不一致** —— `DeskCompactNotifier` 已经用 `_load()` 模式且工作正常
3. **重复解析逻辑** —— mode 的解析规则（含 `catalogConfigured` 例外）要在两处实现
4. **成本收益不成立** —— 换来的是消除一个既有的、已接受的闪烁

### 11.3 采用方案

**在 `DeskWindowModeNotifier._load()` 里 apply**，完全对齐 `DeskCompactNotifier`（详见 §3.8）。

启动时序（不变）：

1. `WidgetsFlutterBinding.ensureInitialized()`
2. `SystemHttpProxy.installHttpOverrides()`
3. **parallel**：`SystemHttpProxy.discoverLocalHttpProxy` / `preloadWindowsProxy` / `DeskWindow.ensureReady()` / `_loadSystemAccent()` / `_configureStartupAudioSession()`
4. `runApp(const ProviderScope(child: ChengboApp()))`
5. 首帧 → HomeShell build → `ref.watch(deskWindowModeProvider)` → `_load()` → `DeskWindow.apply(mode: resolved)` ← **窗口在这里变形**

**`main.dart` 完全不改。**

### 11.4 逃生舱（仅当闪烁被证实不可接受）

如果侧栏形态的闪烁（1280×720 → 720×540，且伴随 frameless 切换）比浮条更明显，且用户反馈强烈，才考虑：

- 新建 `lib/core/storage/raw_prefs.dart`：一个最小 facade，提供 `getString/setString`，与 `AppStorage` 共用同一 `SharedPreferences` 实例的 key 命名
- `main.dart` 的 `Future.wait` 加 `_applyDeskWindowMode()`，用该 facade
- mode 解析规则抽成 `DeskWindowModeLogic.resolveOnLaunch` 纯函数，两处共用（`_load()` 与 `main.dart` 都调它）

**触发条件**：实测闪烁可见 + 用户反馈。**不预先实现。**
