# v2.1 Step 5 实施工单 —— 全量验证 + Release Prep

> 范围：v2.1 release 收尾。**不是代码改动**，是验证清单 + 发布物准备。
> 上游：所有 P0-* 实现已合 main（Step 1+2 ✅ / Step 3 待合 / Step 4 待合）
> 关联：v2.1 整体规划 [`v2-1-release-tracker.md`](./v2-1-release-tracker.md)

---

## 1. 目标

P0-A、B1、B2 全部合入 main 后，跑一遍合并验证（§6.1–§6.6 全部条目），出 CHANGELOG，bump 版本号，准备 release。

---

## 2. 前置

| 依赖 | 状态 |
|---|---|
| P0-A（剩余时间 + mini_player 接线）| ✅ PR #3 已合 |
| P0-B1（widget Material You + 深色 + M3 图标）| 🟡 待合（Step 3 实施中）|
| P0-B2（widget Latest Episodes）| 🟡 待合（Step 4 实施中）|

---

## 3. 验证清单（合并到一次跑）

### 3.1 自动化（一条命令跑齐）

```bash
flutter analyze
flutter test
  # 必须通过：test/remaining_time_test.dart + test/layer_test.dart +
  # test/widget_test.dart + test/key_screens_test.dart +
  # test/desk_widget_episodes_test.dart（B2 引入）
  # 目标：125/125 + B2 新增 11 用例 = 136/136
```

**断言**：
- `flutter analyze`：触到的文件 0 issues
- `flutter test`：全部通过；`widget_episodes_test.dart` 11 条覆盖 §6.6 矩阵

### 3.2 真机手动（§6.1 合并）

逐条勾选 P0-A / B1 / B2 的 §6.1 列表（共 ~28 条）。建议分组：

| 主题 | 条数 | 推荐设备 |
|---|---|---|
| P0-A mini player 剩余时间 | 10 条 | Android 真机 + 360dp 模拟器 |
| P0-B1 widget Material You / 深色 / 图标 | 4 条 | API 30 + API 33 真机各一遍 |
| P0-B2 待听 widget | 9 条 | Android 真机 |
| 回归 | 5 条 | Android 真机 + Windows 桌面 |

### 3.3 视觉（§6.2）

- P0-A：剩余时间与副文层级协调（labelSmall + onSurfaceVariant）
- P0-A：等宽数字，数字变化不抖动
- P0-A：360dp 窄屏不溢出
- P0-A：三个 skin 正常
- P0-B1：浅色 / 深色系统下都可读
- P0-B2：4 行在 4×2 cell 内不溢出 / 不裁切
- P0-B2：单集标题 / 节目名超长 → 1 行 ellipsis
- P0-B2：「待听」配色与 4×1 一致

### 3.4 边界（§6.3）

- P0-A：无时长单集 / 位置超时长 / Auto / 书签启动 / 360dp + 长标题
- P0-B1：API 30 / API 33 行为分叉
- P0-B2：guid 失效静默 / 新订阅未到 / 空 title / 特殊字符 JSON

### 3.5 回归（§6.4，**最重要**）

逐条勾选：

- [ ] Windows 端**任何**代码无变化（`git diff origin/main~1 origin/main -- windows/`）
- [ ] mini player 播放 / 暂停 / 停止 / 左右滑切台 / 左右滑跳秒 无回归
- [ ] mini player 封面 / 3px 进度条 无回归
- [ ] 列表封面渲染无回归（`ArtworkUrlLogic` 清理后）
- [ ] 通知栏 / 锁屏封面无回归（`.ico` 仍被拦截）
- [ ] widget 原有 3 个数据键读取正常
- [ ] widget 在 widget 未添加到桌面时不报错
- [ ] 现有 4×1 widget 的动作与显示无回归
- [ ] `initialLaunchUri` / `isDuplicateLaunch` 现有行为无回归
- [ ] 「收听」tab 的未听 inbox 显示与 widget 一致

### 3.6 截图归档

按主题留 **9 张截图** 归档到 `docs/design/v2-1-screenshots/`（PR 评论附 + 长期归档）：

| # | 文件 | 来源步骤 |
|---|---|---|
| 1 | `mini-player-normal.png` | P0-A 正常态 |
| 2 | `mini-player-pause.png` | P0-A 暂停 |
| 3 | `mini-player-sleep-active.png` | P0-A 睡眠激活 |
| 4 | `widget-4x1-api30-brand.png` | P0-B1 基线 |
| 5 | `widget-4x1-api33-dynamic.png` | P0-B1 动态色开 |
| 6 | `widget-4x1-dark-dynamic-off.png` | P0-B1 深色 + 品牌色 |
| 7 | `widget-4x2-episodes-full.png` | P0-B2 正常 4 行 |
| 8 | `widget-4x2-episodes-partial.png` | P0-B2 部分 2 行 |
| 9 | `widget-4x2-episodes-empty.png` | P0-B2 空态 |

---

## 4. Release 物准备

### 4.1 CHANGELOG.md

新增 `## [v2.1.0] - 2026-XX-XX` 段落。**不要**逐 commit 罗列，按用户视角：

```markdown
## [v2.1.0] - 2026-XX-XX

### Added
- mini player 标题行右侧显示播客单集精确剩余时间（`剩余 mm:ss` / `剩余 h:mm:ss`）
- Android 桌面 widget 跟随系统壁纸配色（Material You 动态色）+ 深色系统配色
- Android 桌面 widget 采用 Material 3 矢量图标（替代旧系统拟物图标）
- 新增 Android「待听」桌面 widget（4×2）：列出 inbox 前 4 个未听单集，点击直接播放
- 关于页展示品牌口号（沿用 tagline 之后的扩展文案）

### Changed
- mini player 剩余时间数据源复用现有 `_MiniProgressBar` 的同一套数据
- widget 颜色与「壁纸 / 系统配色」开关联动（关闭时退回品牌深澄蓝）
- widget 根背景 / 文字色受深色系统模式影响（之前只有浅色变体）

### Fixed
- 清理 `ArtworkUrlLogic.resolve` 中的死分支（jpg/jpeg/png/webp + 3 个 CDN host 的 if 块与 fall-through 等价）
- 修正 ROADMAP 中「电台累计」条目的错误语义（电台直播流没有「总时长」概念）

### Known issues
- widget 续播按钮宽度 40dp 低于 Android 无障碍建议的 48dp（既有问题，本版不修）
- widget 配色跟系统深色模式，不跟 App 内「外观」开关（已知不一致，本版不修）
```

### 4.2 版本号 bump

`pubspec.yaml`：

```yaml
version: 2.1.0+XX
```

`XX` 是新 build 号。具体递增策略：
- 当前 v2.0.2 = `2.0.2+N` → v2.1.0 = `2.1.0+(N+1)`

### 4.3 ROADMAP.md 收尾

把 §2 状态总览的「UI 升级」节标完成：

```markdown
### UI 升级（已发布 v2.1）

- ✅ **v2.1 移动端**（[计划 v1.2](docs/design/mobile-v2-1-plan.md)）—— 2026-09-22 发布
  - mini player 播客精确剩余时间
  - Android widget 视觉重做：Material You 动态色 + 深色模式 + M3 图标
  - 新增 Android「待听」widget（4×2 cell，未听单集列表 + 点击直接播放）
- 🟡 **v2.2 桌面侧栏窗口**（[计划 v1.1](docs/design/desktop-sidebar-window-plan.md)）—— 待实施
```

### 4.4 Tag + Release（GitHub）

```bash
git tag -a v2.1.0 -m "v2.1.0: P0-A (mini player 剩余时间) + P0-B1 (widget Material You) + P0-B2 (widget 待听)"
git push origin v2.1.0
gh release create v2.1.0 --title "v2.1.0" --notes-file CHANGELOG_snippet.md
```

---

## 5. 提交策略

| 项 | 决策 |
|---|---|
| 分支 | 各自实现 PR（Step 3 / Step 4 已合并到 main 之后，**不需要新分支**）|
| 本工单**不产生 commit** | 这是 release 流程，不是代码改动 |

但本工单**之前**需要：

| 项 | 决策 |
|---|---|
| CHANGELOG.md 新增条目 | 跟最后一次实现 PR（Step 4 或 v2.1 plan v1.4）同 PR |
| pubspec.yaml version bump | 单独一个 `chore: bump version to 2.1.0` commit，紧跟实现合 main 之后 |

---

## 6. 顺序与并发

```
Step 3 合 main ─┐
                ├─→ Step 5（本工单）跑合并验证 → 出 CHANGELOG + bump 版本 → tag
Step 4 合 main ─┘
```

Step 3 与 Step 4 可**并发**开发（独立分支、独立文件），都合并后再跑 Step 5。

---

## 7. 范围外（**不要做**）

- ❌ 增量重构（Step 5 是 release 收尾，不引入新代码改动）
- ❌ 优化 `ChengboWidgetProvider.kt` / `ChengboWidgetEpisodesProvider.kt` 公共 helper（建议下一版本做）
- ❌ widget 加圆角（v2.2 或更后）
- ❌ widget 跟 App 内「外观」开关联动（计划 §5 #6 已知不一致）
- ❌ `widget_resume` 触控尺寸修复（计划 §8.1 #7 既有问题）
- ❌ v2.2 桌面侧栏窗口（独立 release）

---

## 8. 变更记录

| 日期 | 版本 | 变更 |
|---|---|---|
| 2026-09-22 | 1.0 | 初稿。基于 `mobile-v2-1-plan.md` v1.2 §0.2 第 5 步落地为可执行的 release 收尾工单 |