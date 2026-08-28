---
name: 澄波
description: 听国内广播 — Material 3 列表与 Spotify 式迷你播放条（对应产品 1.5.3）
colors:
  chengbo-blue: "#1565C0"
  deep-chengbo: "#0D4F8C"
  primary: "#405F90"
  on-primary: "#FFFFFF"
  primary-container: "#D6E3FF"
  on-primary-container: "#001B3D"
  inverse-primary: "#A9C7FF"
  secondary: "#555F71"
  on-secondary: "#FFFFFF"
  secondary-container: "#DAE2F9"
  on-secondary-container: "#121C2B"
  error: "#BA1A1A"
  on-error: "#FFFFFF"
  error-container: "#FFDAD6"
  on-error-container: "#410002"
  surface: "#F9F9FF"
  on-surface: "#191C20"
  on-surface-variant: "#44474E"
  surface-container-high: "#E7E8EE"
  surface-container-highest: "#E2E2E9"
  outline: "#74777F"
  outline-variant: "#C4C6CF"
  ink: "#121212"
  paper: "#FFFFFF"
  primary-dark: "#A9C7FF"
  on-primary-dark: "#08305F"
  surface-dark: "#111318"
  on-surface-dark: "#E2E2E9"
  surface-container-high-dark: "#282A2F"
  surface-container-highest-dark: "#33353A"
  error-dark: "#FFB4AB"
  error-container-dark: "#93000A"
  on-error-container-dark: "#FFDAD6"
typography:
  headline:
    fontFamily: "Roboto, \"Segoe UI\", sans-serif"
    fontSize: "24px"
    fontWeight: 700
    lineHeight: 1.33
  title:
    fontFamily: "Roboto, \"Segoe UI\", sans-serif"
    fontSize: "16px"
    fontWeight: 600
    lineHeight: 1.5
  body:
    fontFamily: "Roboto, \"Segoe UI\", sans-serif"
    fontSize: "14px"
    fontWeight: 400
    lineHeight: 1.43
  label:
    fontFamily: "Roboto, \"Segoe UI\", sans-serif"
    fontSize: "12px"
    fontWeight: 500
    lineHeight: 1.33
    letterSpacing: "0.4px"
rounded:
  xs: "2px"
  sm: "4px"
  md: "8px"
  lg: "12px"
  xl: "16px"
  pill: "999px"
  full: "50%"
spacing:
  xs: "4px"
  sm: "8px"
  md: "12px"
  lg: "16px"
  xl: "20px"
  2xl: "24px"
  3xl: "28px"
  4xl: "32px"
  list-bottom: "16px"
components:
  button-primary:
    backgroundColor: "{colors.primary}"
    textColor: "{colors.on-primary}"
    typography: "{typography.label}"
    rounded: "{rounded.pill}"
    padding: "10px 24px"
    height: "40px"
  button-secondary:
    backgroundColor: "transparent"
    textColor: "{colors.primary}"
    typography: "{typography.label}"
    rounded: "{rounded.pill}"
    padding: "10px 24px"
    height: "40px"
  chip-filter:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.on-surface-variant}"
    typography: "{typography.label}"
    rounded: "{rounded.md}"
    height: "32px"
  chip-filter-selected:
    backgroundColor: "{colors.secondary-container}"
    textColor: "{colors.on-secondary-container}"
    typography: "{typography.label}"
    rounded: "{rounded.md}"
    height: "32px"
  input-outlined:
    backgroundColor: "{colors.surface-container-highest}"
    textColor: "{colors.on-surface}"
    typography: "{typography.body}"
    rounded: "{rounded.sm}"
    padding: "16px"
    height: "56px"
  mini-player:
    backgroundColor: "{colors.surface-container-high}"
    textColor: "{colors.on-surface}"
    typography: "{typography.title}"
    rounded: "{rounded.lg}"
    padding: "8px 4px 8px 10px"
  play-button:
    backgroundColor: "{colors.primary}"
    textColor: "{colors.on-primary}"
    rounded: "{rounded.full}"
    size: "44px"
    height: "44px"
    width: "44px"
  nav-bar:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.on-surface-variant}"
    typography: "{typography.label}"
    height: "80px"
---

# Design System: 澄波

对应产品版本 **1.5.3**。底部导航「收藏」已改为「收听」三段式 tab（收藏 / 最近 / 统计）；播放器控制行改为 `spaceEvenly`（电台：睡眠 / 上一台 / 播放 / 下一台 / 列表）；睡眠定时预设为 5–60 分钟，含 30 秒淡出与小睡 10 分钟后续播；播客倍速含 0.5× / 0.6×，可跳过片头片尾；桌面迷你窗仅 Windows；收听统计页展示总时长、电台 vs 播客占比、最常收听 Top 5（热力图已于 1.4.8 移除）；外观切换带 200ms AnimatedTheme 过渡；Chromecast 投屏默认关闭，仅 Android 外观页可手动开启；播客主页顶部展示「继续收听」卡片，订阅列表项改为长按菜单，单集 tile 右侧可直接打开 Show Notes；设置页「源」改名为「电台管理」；Now Playing 顶部无「电台/播客」标题；桌面迷你窗修复无边框窗口下首次点击穿透问题。

## Overview

**Creative North Star: "静水电波"**

澄波把整座应用铺成一盆静水。电台、播客、收藏、设置都在同一层冷蓝表面上滑动，没有卡片堆、没有装饰插画、没有第二套皮肤。水纹只出现在正在听的东西上：底部迷你条是一块被抬起的圆角石；Now Playing 从封面色里渗出一层暖水面。品牌名里的「澄」是透亮与安静，「波」既是水纹也是电波。气质是温暖的伴听，不是冷工具说明书，也不是舞台灯光秀。

密度跟一份认真的 Material 3 应用走。目的地是可扫的列表：顶上搜索、横滑 FilterChip、行间 1px 分割。设置仍是同一套 ListTile，用主色分组标题切开「关于与外观 / 存储 / 播客 / 电台管理 / 分类」；「电台管理」里检测与刷新是带 TextButton 的操作行，不是另一套控制台。个性只靠三件事：种子色生成的蓝调表面、无台标时的二字渐变封面、以及那条始终在听的迷你条。深色模式是一等公民，由同一颗种子生成，不是浅色取反。

明确拒绝：复古全屏收音机、调频刻度、旋钮拟物、Cupertino 控件、Windows Fluent 分叉、以及把省份/类型渐变刷到导航和按钮上。

**Key Characteristics:**
- 列表是静水，播放器是唯一浮起的波
- Material 3 组件与类型角色，不自造字体
- 种子色生成角色色；启动器保留更深的澄蓝
- 温暖伴听：封面取色、圆形主播放键、睡眠定时用主色倒计时
- Android 与 Windows 同一语言；≥900px 改 NavigationRail

## Colors

一套由种子生成的蓝调 Material 角色色。品牌记忆落在种子与启动底；屏幕上的按钮、播放键、选中强调走生成后的 `primary`。打开「壁纸 / 系统配色」时，Android 12+ 改用壁纸（Material You），Windows 改用系统强调色；拿不到平台色或关掉开关，仍回澄波蓝。外观默认跟随系统，不要再做成只能浅/深二选一。

### Primary
- **澄波蓝**：主题种子与启动器叙事色，也出现在上海台标占位里。不要把它当每个 Filled 按钮的填色。
- **深澄蓝**：启动画面与图标底。只在系统外壳出现，不进 App 内按钮。
- **浅色 primary / 深色 inverse-primary**：组件实际涂的主色。Filled 按钮、播放键、直播指示条、来源标签、设置分组标题都走这个角色。

### Secondary
- **灰蓝 secondary**：FilterChip 选中容器、NavigationBar 指示。比主色更静，用来标记「当前筛选 / 当前目的地」，不是「正在播放」。

### Neutral
- **浅色 surface / 深色 surface-dark**：整页底。带一点冷蓝，不是纯白或纯黑。
- **on-surface / on-surface-variant**：标题与辅助文案。列表副文、码率、缓冲、设置说明用 variant。
- **surface-container-high**：迷你条的石面。
- **surface-container-highest**：音量槽、进度轨道、描边输入框的浅填。
- **outline / outline-variant**：输入框描边与列表分割线。
- **error**：连不上的台数、测试失败、已改址仍失败的副文。播放失败用 `error-container` 条。

### Named Rules
**The Seed-Is-Not-the-Paint Rule.** 澄波蓝是种子，不是按钮填色。组件必须用 ColorScheme 角色（浅色 `primary`，深色 `primary-dark`）。把种子 hex 直接刷上控件，浅色会过饱和、深色会过暗。

**The Placeholder-Not-Brand Rule.** 央广红、广东青绿、北京紫、交通橙等渐变只填无台标封面。导航、按钮、芯片、列表底禁止借用这些色。

## Typography

**Display Font:** 无（本系统不使用 Display 角色）
**Body Font:** Roboto（Android）/ Segoe UI（Windows），系统无衬线回退
**Label/Mono Font:** 与正文同一家族；睡眠倒计时加表格数字 `tnum`

**Character:** 不请一套「品牌字体」。温暖来自字重与颜色（Now Playing 标题加粗、倒计时用主色），不是来自衬线或手写。中文界面走系统默认中西混排。

### Hierarchy
- **Headline**（Bold，headlineSmall 24 / 行高 32）：Now Playing 台名；睡眠定时剩余时间。App 内最大的字。
- **Title**（titleLarge 22 用于分区头如「收藏」；titleMedium 16 w600 用于表单小节与空状态主句；titleSmall 14 w600 用于迷你条台名）：列表与播放器的可读层。
- **Body**（bodyLarge 16 用于 Now Playing 副标题；bodyMedium 14 用于说明；bodySmall 12 用于列表副文、设置分组说明、进度时间）：信息密度的主力。
- **Label**（labelLarge 14 w600 用于设置分组标题与倒计时；labelSmall 11 用于迷你条上的紧凑倒计时）：控件与状态，倒计时必须等宽数字。

### Named Rules
**The Platform Face Rule.** 禁止引入独立 Display 字体或装饰性中文字库。品牌识别走颜色与封面，不走字标。

## Layout

操作型应用：纵向列表 + 持久底部播放器。页面左右节奏是 16；区块内 12；Now Playing 内边距 24。迷你条本身左右下各 8，让圆角石浮在导航之上，而不是贴边。

紧凑宽度（<900）：四目的 NavigationBar（电台 / 播客 / 收听 / 设置）+ 底栏之上的迷你条。展开宽度（≥900）：左侧 NavigationRail（`labelType: all`）+ 1px 竖分割 + 同一套页面。桌面迷你窗是无边框浮条，不是缩小后的完整窗口。不要把手机底栏原样搬到宽屏。

列表统一为 `ListView` + `Divider(height: 1)`。电台页：顶上搜索，下面一条可横滑的 FilterChip。收藏页用 `titleLarge` 分区头，收藏与最近之间用间距 + 分割线分开。统计页展示总时长卡片、电台/播客占比条、最常收听列表；设置页用主色 `labelLarge` 分组标题（首组上 16，其后上 24，下 8）；分组顺序：播客管理 → 电台管理 → 播放与收听 → 外观 → 数据管理 → 电台分类 → 关于。「电台管理」组在标题下用一行 `bodySmall` 说明检测与刷新的差别，检测/刷新与后面的开关之间用一条分割线。

迷你条是 shell 里 Column 的一部分，不是叠在列表上。列表底部只留 16px，不要再预留 96px 假空隙。紧凑目的地没有 AppBar，内容必须 `SafeArea(bottom: false)`，避免搜索框顶进状态栏。推送页（连不上的台、更换地址、隐私）才用左对齐 AppBar。

**The Shell Holds the Player Rule.** 播放器占位由 HomeShell 负责。目的地列表只留 16px 底边。空状态与探测进度都是居中短句加一句说明，需要时给一个主操作，不要插画英雄区。

## Elevation & Depth

混合：列表与设置几乎是平的，深度只为「正在听」服务。迷你条是一块被抬起的石（Material elevation 6，阴影色为 `shadow` 的 22% 透明）。Now Playing 不是再抬一层卡片，而是从封面主色 55% 叠到 `surface` 的纵向渐变，在 45% 高度淡出；封面本身带同色光晕（blur 32、下偏 16）。音量槽是半透明的 `surface-container-highest`，没有投影。对话框走 Material 默认 28 半径色调表面；SnackBar 悬浮，不另加品牌阴影。

### Shadow Vocabulary
- **迷你条抬起**（Material elevation 6，`shadow` @ 22%）：底部播放条唯一的结构阴影。
- **封面光晕**（`0 16px 32px`，封面主色 @ 35%）：只用于 Now Playing 大封面。
- **其余**：无。卡片、列表、芯片、设置行走色调表面，不另加阴影。

### Named Rules
**The Listening Surface Rule.** 没在播放，就不要抬。新屏幕默认平坦；只有播放中的对象可以有 elevation 或有色光晕。

## Shapes

按钮是体育馆形（Filled / Outlined / Text 全是 pill）。主播放键是正圆：迷你条 44、Now Playing 72。列表封面默认 8；迷你条封面 8；Now Playing 大封面 12，与迷你条外壳同一「温石头」半径。描边输入框保持 Material 默认 4。Now Playing 拖动手柄 40×4、半径 2。「直播中」是 20 的胶囊。卡片 12；对话框 28。IconButton 最小触控 48。

**The Warm Stone Rule.** 12px 半径留给听的物件（迷你条、大封面、错误提示条）。不要把卡片半径改成 24 去「更时尚」，也不要把播放键改成方的。

## Components

### Buttons
柔软而明确。主操作 Filled，次操作 Text 或 Outlined，破坏性确认仍是 Filled 主色（清除缓存、删除）配「取消」TextButton。

- **Shape:** 体育馆形（pill）。Now Playing 主播放为正圆 72；迷你条播放为 Filled IconButton 最小 52。
- **Primary:** `primary` 底 + `on-primary` 字。用于添加、重试、保存、空状态「检测可播放的源」。
- **Secondary:** TextButton 用于取消、关闭定时、列表内「清除 / 检测 / 刷新」。Outlined IconButton 用于 Now Playing 的停止、睡眠；Android 另有投屏（Cast）。
- **Hover / Focus:** 跟随 Material 状态层；不要加描边光晕或位移。忙碌时整行 `enabled: false`，转圈放在 trailing，不要替换 leading 图标。

### Chips
- **FilterChip:** 电台分类横滑。未选走表面，选中走 `secondary-container`（静的灰蓝，不是主色高亮）。
- **ActionChip:** 睡眠定时预设（5/10/15/20/25/30/45/60）、「自定义」与「本集结束」。选时长或本集即关 sheet。定时进行中可「小睡 10 分钟」（暂停，到点后续播）或「关闭定时」。
- **直播中:** 仅 Now Playing。半透明对比色底、半径 20、字 13 w600。这是状态徽章，不是 FilterChip。

### Cards / Containers
- **Corner Style:** 默认 Card 12。
- **Background:** `surfaceContainerLow`，elevation 0。
- **Shadow Strategy:** 跟随 Elevation；不要给列表行加阴影。
- **Internal Padding:** 卡内 12；Now Playing 错误条 12。

### Inputs / Fields
- **Style:** `OutlineInputBorder`，半径 4。浅填 `surface-container-highest` 55% 透明。标签 + 提示（搜索「搜索电台名称或标签」；添加台「例如：佛山音乐广播」）。
- **Focus:** 主色描边加到 2px。未聚焦描边走 `outline-variant`。
- **Error:** 校验红字走 `error`；播放失败用 `error-container` 条，不是输入框。

### Navigation
- **紧凑:** NavigationBar，四项目，系统图标（radio / podcasts / 收听 / settings），中文标签。指示与选中图标走 `secondary-container` / `on-secondary-container`。
- **展开 (≥900):** NavigationRail，`labelType: all`，右侧 1px 竖分割。
- **迷你条**在内容底部、导航之上。Now Playing 铺满屏幕（edge-to-edge 模态，可下拉关闭），不要做成半高卡片。

### Mini player（签名）
底部圆角石。`surface-container-high`、半径 12、elevation 6。左 48 封面，中台名 `titleSmall` w600 + 副文 `bodySmall`，右：睡眠倒计时（主色）→ 播放/暂停 Filled → 停止。直播副文是 ICY 曲名或分类；曲名一行放不下才横向慢滚（约 6s + 溢出/40），分类不滚。直播时底边 3px 主色条；播客改为 3px 线性进度。无当前播放时整条消失（`SizedBox.shrink`），不要占位空壳。冷启动若「记住上次收听」打开，迷你条回填上次电台/单集，处于暂停，点播放才出声。

### Desk mini window（签名）
仅 Windows。无系统标题栏，窗口贴着一条 456×100 的浮条。条本身 64 高、半径 32、`surface` 底、阴影 `0 8 22`（`shadow` @ 22%）。左侧 72 圆封面探出条外，带 2px `outline-variant` 描边。条内：台名 + 副文，然后收藏、上一台/下一台（播客为 ±15 秒）、正圆主播放 52、× 回到完整窗口。可拖动整条。颜色走当前 ColorScheme，不要抄别的播放器绿。未在播放时仍显示浮条（「未在播放」），不要留一块空窗。

### Station artwork（签名）
有图则圆角裁切，200ms 淡入；`.ico` / favicon 当低清，改走占位。无图则二字白字 + 斜向渐变，极淡白图标印在字下。渐变按标签选功能色（央广红、广东青绿、上海用种子蓝、北京紫、江苏青、音乐紫、新闻蓝、交通橙）；否则由名称哈希出 HSL（饱和 0.52、明度 0.42→0.55）。这些色不是品牌主色。

### Now Playing sheet（签名）
铺满屏幕，无顶圆角卡片感。背景：封面主色叠 `surface`，在 45% 高度淡出。大封面最大 340，放在 `Expanded` 里，标题变长时封面变矮，控制键钉在底部。标题 headlineSmall 加粗居中，最多 5 行。副标题同样：ICY 过长跑马灯，否则分类。音量在半径 16 的半透明槽里，轨道 4px、滑块半径 7。控制键用 `MainAxisAlignment.spaceEvenly` 均分间距，按钮保持固定大小不压缩。电台：睡眠定时 | 上一台 | 圆形主播放 72 | 下一台 | 播放列表。播客：倍速 | −15 | 圆形主播放 72 | +15 | 播放列表；进度条下另有简介 / 下载（未下可下、下载中可取消、已下载为徽章） / 睡眠 / 跳过片头尾 / 停止芯片。Outlined 辅助键固定 48–60 正圆，主播放 72 正圆。宽窗保持设计尺寸居中，窄窗只压缩间距不压缩按钮。播放列表弹出当前队列：电台为筛选/收藏/可见台，播客为这档节目的单集。Android 再跟一个线性投屏图标（外观开关默认关）。投屏只在 Android 出现，不要为 Windows 做假按钮。

### Settings station group（签名）
设置「电台管理」与存储组同一套词汇：操作行左侧图标固定，右侧 TextButton（检测 / 刷新 / 清除）；忙碌时按钮禁用，trailing 换 24 的细转圈。**收听范围** 用 ListTile 进全屏编辑页（与首次启动同一界面）：类型 FilterChip、省份 FilterChip、「加载全部精选」Switch；首次启动无预选，须至少选一项才能继续。有连不上的台时，副文改 `error`。空的「连不上的电台」页与探测进度共用居中短句；空页主操作是「检测可播放的源」。不要把源管理做成仪表盘或第二套导航。

### First-launch catalog setup（签名）
全屏模态，不可返回跳过。AppBar 标题「选择想听的电台」，无返回键。正文 `bodyMedium` variant 说明须至少选一项。区块：**加载全部精选** SwitchListTile；**类型** 横滑 FilterChip（央广 / 音乐 / 新闻 / 交通 / 财经 / 生活 / 文艺 / 综合），右上 TextButton「仅央广」；**省份 / 地区** Wrap FilterChip（34 区），右上「清空 / 全选」。底部 SafeArea 内 FilledButton「开始检测并进入」。选中态走 `FilterChip` 默认 selected 样式（与电台页分类芯片同一词汇）。设置里复用同一页，标题改「收听范围」，按钮改「保存并重新检测」，带返回键。

## Do's and Don'ts

### Do:
- **Do** 用 ColorScheme 角色色（种子或壁纸动态色），并同时交付浅色与深色；默认 `ThemeMode.system`。
- **Do** 把迷你条当持久控制；新目的地是列表，不是新的播放器皮肤。
- **Do** 列表底留 16（迷你条已在 shell 占位），宽屏用 NavigationRail。
- **Do** 正在收听的电台/单集用 `primaryContainer` 选中底，不要用分类芯片的 secondary。
- **Do** 主操作 Filled、取消 Text、播放正圆；设置里的检测/刷新/清除用同一套 TextButton。
- **Do** 倒计时用主色 + 等宽数字。
- **Do** ICY 曲名一行放不下再跑马灯；分类名、错误、缓冲状态保持静止省略。

### Don't:
- **Don't** 做复古收音机、调频刻度、旋钮、天线或拟物机身。
- **Don't** 为 Windows 换成 Fluent，为「更苹果」换成 Cupertino。
- **Don't** 引入 Display 字体或把澄波两字做成字标标题。
- **Don't** 把省份/类型占位渐变用到导航、FAB 或按钮。
- **Don't** 给普通列表行加阴影或大圆角卡片化整页。
- **Don't** 在未播放时仍显示空迷你条。
- **Don't** 把设置「电台管理」做成独立仪表盘，或让不能点的说明行看起来像可点入口。
