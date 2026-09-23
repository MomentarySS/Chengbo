# v2.1 Release Tracker —— 整体规划 + 状态总览

> **目的**：v2.1 的 single source of truth。一个页面看清「设计 → 工单 → 实施 → release」全链路。
>
> 关联：
> - 设计：[`mobile-v2-1-plan.md`](./mobile-v2-1-plan.md) (v1.4)
> - 工单：Step 2 / 3 / 4 / 5（见下表）
> - 仓库：`MomentarySS/Chengbo`

---

## 1. 范围（v2.1 三大交付）

| 编号 | 名称 | 规模 | 状态 |
|---|---|---|---|
| **P0-A** | mini player 播客精确剩余时间 | 小 | ✅ **已发**（PR #3，2026-09-22 合 main）|
| **P0-B1** | Android widget 视觉重做（Material You + 深色 + M3 图标）| 中 | ✅ **已发**（PR #6，2026-09-23 合 main）|
| **P0-B2** | Android widget「Latest Episodes」模式（4×2 待听）| 中 | ✅ **已发**（PR #7，2026-09-23 合 main）|

**结论**：3/3 已交付。v2.1 release 完成。

---

## 2. 实施进度（按 §0.2 五步）

| 步骤 | 范围 | 工单 | 代码状态 | commit / PR |
|---|---|---|---|---|
| **第 1 步** | 纯逻辑层（`RemainingTimeLogic` + 死代码清理）| （Step 1 与 Step 2 同 PR #3，未单出工单）| ✅ 已合 | PR #3 `5e86f65` |
| **第 2 步** | mini player 接线 | [`mobile-v2-1-step-2-work-order.md`](./mobile-v2-1-step-2-work-order.md) | ✅ 已合 | PR #3 `c0f9cae`（外加工单 `85c27f5`）|
| **第 3 步** | widget 视觉（P0-B1）| [`mobile-v2-1-step-3-work-order.md`](./mobile-v2-1-step-3-work-order.md) | ✅ 已合 | PR #6 `9e46161`（含 C1-C4）|
| **第 4 步** | widget「Latest Episodes」（P0-B2）| [`mobile-v2-1-step-4-work-order.md`](./mobile-v2-1-step-4-work-order.md) | ✅ 已合 | PR #7 `b569cc6`（含 D1-D4）|
| **第 5 步** | 全量验证 + release prep | [`mobile-v2-1-step-5-work-order.md`](./mobile-v2-1-step-5-work-order.md) | ✅ 已合 | main `25a7ff7` + tag v2.1.0 |

> ✅ **v2.1 release 完成**：B1 + B2 + Step 5 全部合 main，main = `17956b2`，tag `v2.1.0` 已发布。

---

## 3. 分支 / PR 总览

| 分支 | 状态 | 内容 |
|---|---|---|
| `main` | 最新 = `17956b2` | v2.1 全部代码 + 文档已合，tag `v2.1.0` 已发布 |
| ~~`docs/brand-slogan`~~ | 已合入 PR #4 后删除 | |
| ~~`feat/v2-1-mobile`~~ | PR #3 已合并后删除 | |
| ~~`feat/v2-1-widget-b1`~~ | docs-only，PR #5 已合并后删除 | |
| ~~`feat/v2-1-widget-b1-impl`~~ | PR #6 已合并后删除 | |
| ~~`feat/v2-1-widget-b2`~~ | PR #7 已合并后删除 | |

> **v2.1 完成**：所有 feature branch 已合并并清理，main 只剩 release 后的微调（CHANGELOG / pubspec / ROADMAP / tracker / plan）。

---

## 4. PR 节奏

（v2.1 全部 PR 已合并；下表为历史档案）

| 编号 | 范围 | commit 数 | 分支 | PR 标题 | 状态 |
|---|---|---|---|---|---|
| Step 3 (B1) | DeskWidget 字段 + 同步 + Kotlin + 资源 | 4 | `feat/v2-1-widget-b1-impl` | `feat(widget): Material You + dark variant + M3 icons (P0-B1)` | ✅ PR #6 已合并 |
| Step 4 (B2) | Dart 契约 + 同步 + Kotlin + 资源 + Manifest + 测试 | 4 | `feat/v2-1-widget-b2` | `feat(widget): Latest Episodes 4x2 widget (P0-B2)` | ✅ PR #7 已合并 |
| v1.4 plan | §0.2 / §2 / §7 更新 | 1 | （与 Step 3/4/5 工单一并入 `feat/v2-1-widget-b1`） | `docs: bump v2.1 plan to v1.4` | ✅ PR #5 已合 |
| 版本 bump | `pubspec.yaml` + CHANGELOG + ROADMAP + tracker + plan | 2 | main | `docs: release v2.1.0 notes` + `chore: bump version to 2.1.0` | ⏸ Step 5 收尾（本次 commit）|

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
| 2026-09-23 | 1.2 | **v2.1.1 补丁**（分支 `fix/v2-1-1-radio-mini-bar`）。两处修复：① `lib/core/brand.dart` 版本常量停在 `2.0.2`（v2.1.0 release prep 漏 bump，`layer_test` 版本守卫一直红；影响关于页 / 隐私说明 / 备份 JSON / 全部网络 UA）② 移除电台迷你条底部 3px 主色条（无信息量 + 圆角裁切后像残留色带）。版本 bump 到 `2.1.1+40`，含 pubspec + brand.dart + .iss |
| 2026-09-23 | 1.1 | v2.1 完成：P0-A + B1 + B2 全部合 main；Step 5 release prep（CHANGELOG + pubspec bump + ROADMAP + tracker + plan）执行中；feature branch 已清理；tag v2.1.0 已发布 |
| 2026-09-22 | 1.0 | 初稿。P0-A 已合 main；P0-B1+B2 工单已入仓（feat/v2-1-widget-b1）；B1+B2 代码待实施；release prep 待 v1.4 plan bump 后启动 |