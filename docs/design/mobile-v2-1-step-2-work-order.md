# v2.1 Step 2 实施工单 — `mini_player.dart` 接线 P0-A

> 范围：仅 P0-A。P0-B1 / B2 不在本工单内。
> 上游：[`mobile-v2-1-plan.md` §3.1](./mobile-v2-1-plan.md)（实施就绪 v1.2）
> 前置：Step 1（`RemainingTimeLogic` 纯逻辑 + 死代码清理 + 10 测试）已合并

---

## 1. 目标

把 Step 1 的 `RemainingTimeLogic.label()` 接到 `MiniPlayer` 的**标题行右侧**，
并按计划 §5 的 4 个条件门控显示。电台不显示、缓冲不显示、出错不显示、睡眠激活
不显示。

---

## 2. 前置（已就绪，不需要做）

| 依赖 | 现状 | 来源 |
|---|---|---|
| `RemainingTimeLogic.label` | 已实现 + 10/10 测试 | Step 1 commit `5e86f65` |
| `isPodcast` | `current.kind == PlaybackKind.podcast`，line 48 | 现有 |
| `loading` | `PlaybackLogic.shouldShowBufferingUi(...)`，line 42 | 现有，**直接用，不新写** |
| `hasError` | `state?.processingState == AudioProcessingState.error`，line 47 | 现有 |
| `sleepActive` | `ref.watch(sleepTimerProvider).isActive`，line 52 | 现有 |
| `handler.player.positionStream` | broadcast，第 3 个订阅安全 | 计划 §8 待核验 #4 已确认 |

---

## 3. 改法逐条

### 3.1 `lib/shared/widgets/mini_player.dart`

#### (a) 新增 import

第 1 行 `import 'dart:async';` 之后加：

```dart
import 'package:chengbo/core/audio/remaining_time.dart';
```

> `FontFeature` 已被 `flutter/material.dart` 间接导出（项目里
> `podcast_now_playing.dart` 也在用），无需新增 `dart:ui` import。

#### (b) 计算 `showRemaining` —— 紧跟 line 52 之后

在 line 52 (`final sleepActive = ref.watch(sleepTimerProvider).isActive;`)
后插入：

```dart
final showRemaining =
    isPodcast && !sleepActive && !loading && !hasError;
```

**4 个条件必须全部满足**（计划 §5 第 3 条）。任何 1 个为假 → 整块不渲染。

#### (c) 标题行改造 —— line 110-139

**before**（line 110-139，`Expanded(child: Column(...))` 内的标题 Text）：

```dart
Expanded(
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        current.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
      ),
      const SizedBox(height: 2),
      _IcyStatusLine(...),
    ],
  ),
),
```

**after**：

```dart
Expanded(
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Row(
        children: [
          Expanded(
            child: Text(
              current.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          if (showRemaining) ...[
            const SizedBox(width: 6),
            _RemainingTime(handler: handler, current: current),
          ],
        ],
      ),
      const SizedBox(height: 2),
      _IcyStatusLine(...),
    ],
  ),
),
```

**改动要点**：

- 标题 `Text` 包一层 `Row` + `Expanded`：原 `Text` 移入 `Expanded`，保留原
  `maxLines / ellipsis / style` 不变
- 右侧 `if (showRemaining) ...[`：`SizedBox(width: 6)` + `_RemainingTime`
  widget
- 副文行 `_IcyStatusLine` **不动**

#### (d) 新增 `_RemainingTime` widget —— 追加在 `_MiniProgressBar` 之后

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

> 数据源复用 `_MiniProgressBar` 的同一套（计划 §2 状态总览已确认）。
> **不**加自己的 `player.duration` 取值入口。

### 3.2 范围外（**不要做**）

- ❌ `mini_player.dart` 副文行 `_IcyStatusLine` 改造
- ❌ `mini_player.dart` 进度条 `_MiniProgressBar` 改造
- ❌ `podcast_now_playing.dart`（全屏播放页）改造 —— 后续单独步骤
- ❌ NowPlayingSheet 内的剩余时间显示
- ❌ 任何电台侧的剩余时间（计划 §9 明确不做）

---

## 4. 语义边界自查（提交前）

| # | 场景 | 期望 |
|---|---|---|
| 1 | 播客播放中，`duration` 已知 | 标题右侧显示 `剩余 mm:ss`，每秒递减 |
| 2 | 播客播放中，`duration >= 1h` | 显示 `剩余 h:mm:ss` |
| 3 | 播客**暂停** | label **保持显示不变**（位置不变 → 剩余不变） |
| 4 | 播客**缓冲中** | label **隐藏**（副文显示「正在缓冲…」） |
| 5 | 播客**出错** | label **隐藏**（副文显示错误文案） |
| 6 | **电台**播放 | label **不渲染**（`isPodcast == false`） |
| 7 | **睡眠定时激活** | label **隐藏**，右侧仅剩 `SleepTimerCountdown` |
| 8 | **睡眠定时取消** | label 自动恢复 |
| 9 | 无时长单集（`itunes:duration` 缺失） | label 不渲染，不崩 |
| 10 | 位置追上时长（手动拖到末尾） | 显示 `剩余 0:00`，**不**负数 |
| 11 | 从 Android Auto / 书签启动 | `current.duration == null` 时回退 `handler.player.duration` |
| 12 | **360dp 窄屏** + 长标题 | 标题 `Expanded` + ellipsis，label `tabularFigures` 不抖动；不应挤出按钮区 |
| 13 | 三个 skin（废土终端 / 第三新东京 / 夜之城） | `labelSmall` + `onSurfaceVariant` 与 skin 主色协调，**不**改 skin |

---

## 5. 视觉位（提交后真机核对用）

**正常态**（播客播放中 + 无睡眠）：

```
┌──────────────────────────────────────────────────────────┐
│ [封面48]  单集标题（标题行右侧）...   剩余 12:34   ▶ ✕  │
│          ICY 曲名（副文行）                              │
│ ────────── 进度条 3px ────────────────────────────── │
└──────────────────────────────────────────────────────────┘
```

**睡眠激活态**（`sleepActive == true`，`showRemaining == false`）：

```
┌──────────────────────────────────────────────────────────┐
│ [封面48]  单集标题                                     🛏  ▶ ✕ │
│          ICY 曲名                            22:34      │
│ ────────── 进度条 ──────────────────────────────     │
└──────────────────────────────────────────────────────────┘
```

→ `SleepTimerCountdown`（现有）占右侧，label 不渲染，二者**不**并列。

**缓冲态**（`loading == true`，`showRemaining == false`）：

```
┌──────────────────────────────────────────────────────────┐
│ [封面48]  单集标题                          ⏳ 旋转 ✕  │
│          正在缓冲…                                       │
│ ────────── 进度条 indeterminate 视觉 ──────────────     │
└──────────────────────────────────────────────────────────┘
```

→ 右侧主按钮变 spinner（line 162-170 现有行为），label 不渲染。

---

## 6. 验证清单

### 自动化（必跑）

```bash
flutter test test/remaining_time_test.dart   # 10/10 仍然通过（无新增逻辑）
flutter test test/layer_test.dart            # 74/74（盯住 ArtworkUrlLogic 相关回归）
flutter analyze lib/shared/widgets/mini_player.dart   # 0 issues
flutter analyze                              # 全仓，看 23 个既有 info 是否新增
```

### 真机手动（计划 §6.1 全部条目）

按 §4 表格 13 条逐条过；特别是 **#7 / #8 睡眠切换**、**#12 窄屏不溢出**。

### 截图位（建议留 4 张供 PR 评论）

- 播客播放中（正常态）
- 播客暂停中（label 不变）
- 睡眠定时激活（仅倒计时、无 label）
- 360dp 窄屏 + 长标题（不溢出）

---

## 7. 提交策略

| 项 | 决策 |
|---|---|
| 分支 | `feat/v2-1-mobile`（继续，不开新分支） |
| 提交数 | 2 个：先 docs 存盘（`docs/design/mobile-v2-1-step-2-work-order.md`），再代码 |
| 标题（代码） | `feat(mobile): wire remaining-time label into mini player` |
| 标题（文档） | `docs: add step 2 work order for mini player wiring` |
| 关联 | 引用 `mobile-v2-1-plan.md` §3.1，PR 描述里点回 §6.1 验证清单 |

---

## 8. 与已有代码的冲突面

- `mini_player.dart` 自身无其他进行中改动 → 无冲突
- `_RemainingTime` 与 `_MiniProgressBar` 都订阅 `positionStream`，计划 §8 #4
  已确认 broadcast + 安全
- 不改 `_IcyStatusLine`、不改 `NowPlayingSheet`、不改任何皮肤变量

---

## 9. 变更记录

| 日期 | 版本 | 变更 |
|---|---|---|
| 2026-09-22 | 1.0 | 初稿。基于 `mobile-v2-1-plan.md` v1.2 §3.1 落地为可施工的工单 |