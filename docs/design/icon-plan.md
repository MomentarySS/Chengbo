# 澄波 App Icon 重新设计 — 长期计划

状态：进行中（候选稿评审中）　对应产品版本：2.0.2+38

## 背景

当前 icon（`assets/branding/app_icon.png`）为双波浪线条 + 澄波蓝（#1565C0）底。设计意图覆盖「水波/电波/声波」三重隐喻，但落到 launcher 上：

- 偏通用化，与其他音频/天气/系统应用的图标容易混
- 在小尺寸（16–32 px）下两条波浪容易糊成一团
- adaptive icon foreground 的那条波浪靠近底部，被系统 mask 切掉后形态断裂

本次重新设计的目标是：在保持澄波蓝与 Material 3 语言的前提下，给 icon 一个更明确的「广播/音频播放器」语义，同时让小尺寸下依然清晰。

## 决策（2026-09-22 锁定）

| 维度 | 决策 |
| --- | --- |
| 方向 | 全新概念（不再沿用双波浪骨架） |
| 核心隐喻 | 声波 / 波形（替代「水波+电波」叠加） |
| 视觉风格 | Material 3 圆润扁平（柔渐变 + 圆角 + 微立体） |
| 配色 | 沿用澄波蓝不变；不改动 `DESIGN.md` 中 `chengbo-blue` / `deep-chengbo` |
| 平台 | Android + Windows（项目无 iOS / macOS / Linux / Web 平台） |

## 与 DESIGN.md 的对齐

- 澄波蓝（#1565C0）继续作为种子色；icon 底色走 `deep-chengbo`（#0D4F8C），与启动画面一致
- 主体白色 + 浅蓝渐变收尾，单一冷蓝表面，避免「The Placeholder-Not-Brand Rule」被打破
- 不引入第二套字体、不自造组件、不做复古拟物

## 候选方向

### 候选 A：涟漪信号
- 中心实心圆点（信号源 / 水滴意象），右侧 3 道大小递增的同心弧
- 极简、留白多；视觉像 Wi-Fi 信号的反向发射
- 小尺寸下圆点 + 三道弧依然清晰
- Material 3 细节：圆点带柔光内高光，弧线由浅到深的同色渐变，圆头收尾

### 候选 B：Waveform 频谱
- 9 条圆头频谱条，居中排列
- 中央柱最高，向两侧阶梯式渐低，形成山形剖面
- 静态化（不模拟动画），保留「正在发声」的语义
- Material 3 细节：胶囊端点，主体白色 + 浅蓝半透明叠加做层次

### 候选 C：声波扬声器
- 左侧扬声器剪影（圆角矩形机身 + 锥形喇叭口）
- 右侧 2–3 道声波弧向右扩散
- 具象、直接；通用识别度高
- Material 3 细节：扬声器柔光描边、弧线由近到远渐淡

> 备选 D（暂留）：等响度曲线（Heartbeat 单条起伏线）。与现有双波浪视觉过近，除非 A/B/C 都不接受再启用。

## 视觉规范（所有候选共享）

### 颜色
| 用途 | 色值 |
| --- | --- |
| 背景底 | `#0D4F8C`（deep-chengbo，launcher 专用） |
| 主体主色 | `#FFFFFF` 白 |
| 渐变收尾 / 微立体 | `#90CAF9` 浅澄蓝（与主色明度差 ≤ 15%） |
| 内高光 / 描边 | `rgba(255,255,255,0.18)` 白色柔光 |

### 几何
- viewBox：512 × 512
- 主体居中，安全区 ≤ 80% × 80%（410 × 410 区域内）
- 元素端点一律圆头（`stroke-linecap="round"` 或胶囊形端点）
- 元素之间留白 ≥ 主体宽度的 8%

### Adaptive icon 安全区
- Android foreground（432×432 等比）必须把主体收进中心 50% × 50% 区域
- 系统 mask（圆形 / 圆角矩形 / 水滴 / 圆矩形）会裁掉约外侧 25%
- 主体中心点必须落在 viewBox 正中心

## 文件清单（最终交付）

### 主源图
- `assets/branding/app_icon.png` — 1024 × 1024 PNG，含背景

### Android adaptive icon（5 档）
| 目录 | ic_launcher.png | ic_launcher_foreground.png |
| --- | --- | --- |
| mipmap-mdpi | 48 × 48 | 108 × 108 |
| mipmap-hdpi | 72 × 72 | 162 × 162 |
| mipmap-xhdpi | 96 × 96 | 216 × 216 |
| mipmap-xxhdpi | 144 × 144 | 324 × 324 |
| mipmap-xxxhdpi | 192 × 192 | 432 × 432 |

### Windows
- `windows/runner/resources/app_icon.ico` — 多尺寸 ICO（16 / 32 / 48 / 64 / 128 / 256）

### Flutter assets
- `assets/branding/app_icon.ico` — ICO 备份
- `assets/branding/app_icon_foreground.png` — Android foreground 备份

合计 **13 个目标文件**（1 master PNG + 5 × 2 Android + 1 ICO + 1 备份 ICO + 1 备份 foreground = 14 个文件中，master 与备份 PNG 共享源）。

## 实施步骤

1. **方向选型**：从 A / B / C 选一个；如需微调，描述调整点（弧度粗细、柱数等）
2. **SVG 主稿**：选定方向后出 1024 × 1024 SVG，作为 PNG master 源
3. **派生 PNG**：
   - `app_icon.png`（1024，含背景）
   - 5 档 `ic_launcher.png`（缩放）
4. **派生 foreground**：从 master 抠出主体（去背景），缩放到 5 档尺寸
5. **派生 ICO**：用 ImageMagick 从 1024 master 生成多尺寸 ICO
6. **覆盖文件**：写入全部 13 个目标位置
7. **验证**：见下方「验证清单」

## 验证清单

- [ ] 1024 master 缩到 32 × 32 / 16 × 16 后主体仍可辨
- [ ] foreground 主体全部落在中心 50% × 50% 内（不被 launcher mask 切掉）
- [ ] ICO 包含 6 个尺寸（16 / 32 / 48 / 64 / 128 / 256），`magick identify app_icon.ico` 可列出
- [ ] `scripts/flutter.ps1 build windows` 成功（Windows 资源加载 .ico）
- [ ] `scripts/flutter.ps1 build apk` 成功；解压 APK 后 `mipmap-xxxhdpi/ic_launcher_foreground.png` 是新文件
- [ ] 与 `DESIGN.md` 中的 `#0D4F8C` / `#1565C0` 一致，未引入新色

## 风险与回退

| 风险 | 回退方案 |
| --- | --- |
| foreground 被系统 mask 切掉 | 主体收进中心 50%；必要时改方案 C 的扬声器位置 |
| ICO 多尺寸合成失败 | `magick 1024.png -define icon:auto-resize=256,128,64,48,32,16 app_icon.ico` |
| 16 × 16 缩小后看不清 | master 设计阶段就用 32 × 32 缩略图自检 |
| 颜色与 DESIGN.md 冲突 | 严格用 `#0D4F8C` / `#FFFFFF` / `#90CAF9` 三色 |

## 变更记录

| 日期 | 变更 |
| --- | --- |
| 2026-09-22 | 新增计划文档；锁定决策（声波 / 全新 / Material 3 / 沿用蓝） |
| 2026-09-22 | 出候选稿 A / B / C 等待选型 |