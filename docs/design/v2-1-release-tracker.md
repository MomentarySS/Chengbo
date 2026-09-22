# v2.1 Release Tracker —— 整体规划 + 状态总览

> **目的**：v2.1 的 single source of truth。一个页面看清「设计 → 工单 → 实施 → release」全链路。
>
> 关联：
> - 设计：[`mobile-v2-1-plan.md`](./mobile-v2-1-plan.md) (v1.3)
> - 工单：Step 2 / 3 / 4 / 5（见下表）
> - 仓库：`MomentarySS/Chengbo`

---

## 1. 范围（v2.1 三大交付）

| 编号 | 名称 | 规模 | 状态 |
|---|---|---|---|
| **P0-A** | mini player 播客精确剩余时间 | 小 | ✅ **已发**（PR #3，2026-09-22 合 main）|
| **P0-B1** | Android widget 视觉重做（Material You + 深色 + M3 图标）| 中 | 🟡 **设计完成 + 工单就绪**，代码待实施 |
| **P0-B2** | Android widget「Latest Episodes」模式（4×2 待听）| 中 | 🟡 **设计完成 + 工单就绪**，代码待实施 |

**结论**：1/3 已交付，2/3 等动代码。

---

## 2. 实施进度（按 §0.2 五步）

| 步骤 | 范围 | 工单 | 代码状态 | commit / PR |
|---|---|---|---|---|
| **第 1 步** | 纯逻辑层（`RemainingTimeLogic` + 死代码清理）| （Step 1 与 Step 2 同 PR #3，未单出工单）| ✅ 已合 | PR #3 `5e86f65` |
| **第 2 步** | mini player 接线 | [`mobile-v2-1-step-2-work-order.md`](./mobile-v2-1-step-2-work-order.md) | ✅ 已合 | PR #3 `c0f9cae`（外加工单 `85c27f5`）|
| **第 3 步** | widget 视觉（P0-B1）| [`mobile-v2-1-step-3-work-order.md`](./mobile-v2-1-step-3-work-order.md) | ❌ **代码未动**（工单已 commit 到 `feat/v2-1-widget-b1` 分支，未推 PR）| branch: `feat/v2-1-widget-b1` commit `4919bae` |
| **第 4 步** | widget「Latest Episodes」（P0-B2）| [`mobile-v2-1-step-4-work-order.md`](./mobile-v2-1-step-4-work-order.md) | ❌ **代码未动**（工单已在 `feat/v2-1-widget-b1` 入仓）| 同上 |
| **第 5 步** | 全量验证 + release prep | [`mobile-v2-1-step-5-work-order.md`](./mobile-v2-1-step-5-work-order.md) | ⏸ **待 B1+B2 合 main 后执行** | — |

> ⚠️ 当前 commit 状态：Step 3 / 4 / 5 工单**全部已落到 `feat/v2-1-widget-b1` 分支**（含本 tracker），尚未开 PR。

---

## 3. 分支 / PR 总览

| 分支 | 状态 | 内容 |
|---|---|---|
| `main` | 最新 = `68d91eb` | 已合并 PR #2 + PR #3（含 P0-A 全部代码 + 文档）|
| `docs/brand-slogan` | 最新 = `404e040`（v1.3） | v2.1 plan + 设计文档 + slogan UI（PR #2 已合）；**新 PR 待开**（v1.4） |
| `feat/v2-1-mobile` | 最新 = `c0f9cae` | P0-A 完整代码（PR #3 已合）|
| `feat/v2-1-widget-b1` | 最新 = `4919bae` | Step 3 / 4 / 5 工单 + 本 tracker（**Draft PR 待开**）|

> **本工单落地后状态**：v2.1 全部设计 + 全部工单都入仓了，代码只差 B1 / B2 实施。

---

## 4. PR 节奏（剩余未做的事）

| 编号 | 范围 | commit 数 | 分支 | PR 标题 |
|---|---|---|---|---|
| Step 3 (B1) | DeskWidget 字段 + Designer 同步 + Kotlin + 资源 | 4 | `feat/v2-1-widget-b1`（已存工单）| `feat(widget): Material You + dark variant + M3 icons (P0-B1)` |
| Step 4 (B2) | Dart 契约 + 同步 + Kotlin + 资源 + Manifest + 测试 | 4 | `feat/v2-1-widget-b2`（待建）| `feat(widget): Latest Episodes 4x2 widget (P0-B2)` |
| v1.4 plan | §0.2 / §2 / §7 更新 | 1 | `docs/brand-slogan`（待提交）| `docs: bump v2.1 plan to v1.4 (B1+B2 work orders ready)` |
| 版本 bump | `pubspec.yaml` | 1 | main（实施完后）| `chore: bump version to 2.1.0` |

---

## 5. 验证全景（§6 全量）

| 来源 | 自动化 | 真机手动 |
|---|---|---|
| P0-A | 10/10 `remaining_time_test` + 74/74 `layer_test` + 33/33 `widget_test` + 8/8 `key_screens_test` = **125/125** | 10 条 §6.1 + 4 条 §6.2 + 4 条 §6.3 + 5 条 §6.4 |
| P0-B1 | （B1 不新增测试，复用现有 125/125）| 4 条 §6.1 + 1 条 §6.2 + 2 条 §6.3 |
| P0-B2 | +11 `desk_widget_episodes_test`（§6.6）| 9 条 §6.1 + 3 条 §6.2 + 4 条 §6.3 + 3 条 §6.4 |
| **合计** | **136/136** | **~50 条**（部分与回归共用）|

---

## 6. 风险 / 已知不一致（不修复清单）

来自 v2.1 plan §5 / §8.1 / §9：

| 风险 | 决策 | 来源 |
|---|---|---|
| widget 续播按钮 40dp 宽（< Android 无障碍建议 48dp）| **不修** | §8.1 #7 / §9 |
| widget 配色跟系统深色，不跟 App 内「外观」开关 | **不修**（已知不一致）| §5 #6 |
| widget 加圆角 | **不引入**（避免与启动器行为叠加）| §6.2 #9 |
| 电台累计时长 | **不实现**（直播流 duration 无意义）| §5 #4 |
| 新 widget 显示单集封面 | **不显示**（4×2 4 行放封面会挤压）| §9 |
| 替换现有 4×1 widget | **不替换**（两 widget 职责不同）| §9 |
| `widget_episodes_info.xml` 加 previewImage | **不加**（无合适截图）| §9 |
| 抽 B1/B2 Kotlin 公共着色 helper | **本版不抽**（B1+B2 都合后单独做）| Step 4 工单 §12 |

---

## 7. 变更记录

| 日期 | 版本 | 变更 |
|---|---|---|
| 2026-09-22 | 1.0 | 初稿。P0-A 已合 main；P0-B1+B2 工单已入仓（feat/v2-1-widget-b1）；B1+B2 代码待实施；release prep 待 v1.4 plan bump 后启动 |