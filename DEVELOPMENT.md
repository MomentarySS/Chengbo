# 开发清单与同类案例

后续功能按本文开发，做完一项就把状态勾成完成。  
产品名：**澄波**。定位：**国内精选流 + 可开关的 Radio Browser + 手动添加**；播放器保持 Spotify 式迷你条，不再做复古全屏收音机。

**当前：** P0–P5 已完成。P5 含睡眠到本集结束、摇一摇延长睡眠、ICY 跑马灯、Android 小组件、新一集通知、Podcast Index 搜索、Chromecast。

---

## 一、同类案例可借鉴点

| 产品 / 仓库                                                                           | 借鉴什么                                                                 | 对本项目的落地                                   |
| ------------------------------------------------------------------------------------- | ------------------------------------------------------------------------ | ------------------------------------------------ |
| [RadioDroid](https://github.com/segler-alex/RadioDroid)                               | 睡眠定时、闹钟开播、ICY 正在播放、Radio Browser 目录、录音               | 睡眠定时 + ICY 已做；录音不做；闹钟不做独立闹铃 |
| [BearWave](https://github.com/spalencsar/bearwave-android)                            | DNS 动态选 Radio Browser 镜像、恢复上次电台/音量、手动添加、Android Auto、Cast | 镜像、音量、手动添加、Android Auto、Cast 已做 |
| [Labhouse FM / flutter-radio-tuner](https://github.com/vicajilau/flutter-radio-tuner) | `all.api.radio-browser.info` 解析服务器、可测试架构                      | 动态镜像已做 |
| [Radio Hangi / radio_bude](https://github.com/NikTsanka/radio_bude)                   | 搜索防抖、长按详情、封面取色、ICY 跑马灯、桌面小组件                     | 已做 |
| [radio_app](https://github.com/lolalalol/radio_app)                                   | ICY 滚动字幕、手动添加与 RB 双数据源、播放历史                           | 已做（曲名过长走跑马灯） |
| [Open Android Radio](https://github.com/TypicalNerds/Open-Android-Radio)              | 添加后可编辑、剪贴板导入导出电台                                         | 已做 |
| [Transistor](https://f-droid.org/en/packages/org.y20k.transistor/)                     | 贴 M3U/PLS、分享流地址、极简加台                                         | 已做 |
| iHeartRadio / TuneIn                                                                  | 扫台、按城市/类型发现；迷你条为主                                        | 上一台/下一台已做；不要再做拟物收音机 |
| Spotify / Apple Music                                                                 | 底部迷你条 + 上滑 Now Playing、封面取色                                  | 已采用；Hero 已做 |
| Apple Podcasts / Pocket Casts / AntennaPod                                            | ±15 秒、倍速、简介、下载、OPML、播完下一集、睡眠到本集结束               | 已做 |

**明确不做（除非需求变更）**

- 复古全屏收音机 / 调频刻度整机 UI
- 对接蜻蜓 FM / 喜马拉雅版权点播（需官方授权）
- 把直播音频整段缓存成录音文件（默认定时器除外）
- 独立闹钟开播（失败代价大；最多以后做「到点通知」）
- 均衡器 / 静音裁剪 / 逐字稿
- 做成全球 Radio Browser 浏览器（保持国内精选差异）
- 爬蜻蜓 / 云听当官方实时节目单
- Win11 小组件板、iOS（未列入产品范围）

---

## 二、已完成（排查修复）

- [x] Radio Browser 启动时请求 `all.api.radio-browser.info/json/servers`，失败回退 de1/fi1/nl1
- [x] User-Agent 为可识别的 `Chengbo/1.1.9 (Flutter; chengbo radio)`，去掉 `contact@example.com`
- [x] 手动添加与精选/已加载列表查重（同名、同 URL）
- [x] `StationSource.custom`；旧数据靠 tag「自定义」兼容
- [x] 设置页拆到 `lib/features/settings/settings_screen.dart`
- [x] 分类规则、合并、来源标签、镜像解析、URL 格式校验的单元测试
- [x] 根目录 `LICENSE`（MIT）
- [x] Spotify 式播放器、封面缓存清除、Radio Browser 开关、来源标注
- [x] 确认收听范围后并行检测直播源，列表只展示当前能连上的台；二次打开沿用首次结果，设置「电台管理」里检测或改「收听范围」才再探测
- [x] 设置「电台管理」大类：收听范围、检测可播放的源、刷新电台列表（只更新目录）、连不上的电台、Radio Browser、境外、手动添加
- [x] 外观跟随系统（浅色/深色/跟随系统三选）；Android 12+ 壁纸配色，Windows 系统强调色

---

## 三、开发清单（按优先级往下做）

做每一项时：改代码 → 能测则补测试 → 把本项勾成完成 → 必要时更新 README。

### P0 体验

- [x] **睡眠定时器**：15/30/45/60 分钟倒计时后 `stop()`；Now Playing 入口；支持自定义 1 分钟–12 小时
- [x] **ICY / 正在播放曲名**：`just_audio` 的 ICY metadata 显示在迷你条副标题与 Now Playing；HLS 不强制加 ICY 请求头；Windows 不支持 ICY 时回退分类名
- [x] **记住上次音量**：冷启动恢复音量，不自动播放
- [x] **境外电台开关**：默认只显示中国大陆；设置「电台管理」里打开「显示境外电台」后才出现港澳台，且境内台排在前面
- [x] **断网提示**：`connectivity_plus`；顶部横条；列表/播客失败与播放失败改成「当前没有网络」；离线时跳过直播源探测和 Radio Browser
- [x] **二次打开不探测**：首次须先选收听范围再测源；之后只在设置「电台管理 → 检测可播放的源」/下拉刷新或修改「收听范围」时重测；「刷新电台列表」只更新目录。平时按首次能播的 id 列表播放，坏了去设置「电台管理」换地址

### P1 电台与发现

- [x] **手动台编辑**：改名称、URL、分类、台标，而不是只能删重建
- [x] **长按电台详情**：码率、编码、来源、官网、投票（Radio Hangi）
- [x] **上一台 / 下一台**：在当前分类或收藏中切换
- [x] **搜索防抖**：输入 300ms 后再过滤
- [x] **Radio Browser 按城市/标签拉取**：不只固定 80 条中国区
- [x] **导入导出**：剪贴板或 JSON 备份手动电台（Open Android Radio）
- [x] **本机更换精选/发现台流地址**：连不上的台进设置「电台管理」；长按也可换。不改安装包 JSON，可恢复原址

### P1 播客收听

- [x] **±15 秒 / 倍速**：Now Playing 与通知栏快进快退；0.8 / 1 / 1.25 / 1.5 / 2×，本机记住
- [x] **单集简介**：RSS `content:encoded` / `itunes:summary` / `description` 取最长一段，去掉 HTML
- [x] **订阅管理**：添加时抓取 RSS 标题与封面；删除订阅；不自带默认播客（已安装设备会清掉旧的央广网 / RTHK）；下拉刷新单集
- [x] **按需下载**：单集保存到应用私有目录，离线可听；设置里可看占用并清除；直播仍不落盘

### P2 工程与发布

- [x] Android 真机验证后台播放、通知栏、Android 13+ 通知权限（见下方清单）
- [x] Windows 安装包 / Android APK（`scripts/pack.ps1` 按 pubspec 写出 `dist/chengbo-1.2.0.apk`、`dist/chengbo-windows-1.2.0.zip`；本机有 `android/key.properties` 时用正式签名）
- [x] 播放器与网络层再补测试（`test/layer_test.dart`：handler 重试、discovery 开关、隐私文案）
- [x] 隐私说明：直播不落盘、播客可按需下载、不收集收听内容（设置页 + [PRIVACY.md](PRIVACY.md)）
- [x] 不提供节目单：不爬蜻蜓 / 云听，不编 EPG，底栏不设节目单页
- [x] 国内镜像打包：`scripts/china-mirrors.ps1`（Flutter 中国镜像、阿里云/华为 Maven、腾讯云 Gradle 与 Android SDK/NDK）

真机验证清单（Android 13+ 已测）：

- [x] 首次启动弹出通知权限；允许后通知栏出现播放控制
- [x] 切到后台 / 锁屏后仍能播，通知栏可暂停、停止
- [x] 拒绝通知权限时应用仍能前台播放，并说明后台可能被系统限制

### P3 可选 / 低优先级

- [x] **迷你条 ↔ Now Playing Hero 动画**：封面共用 Hero；全屏路由淡入上滑，可下拉关闭
- [x] **Android Auto / 车载**：MediaBrowser 浏览收藏 / 最近 / 电台；通知栏与车机可上一台/下一台
- [x] **桌面迷你窗**：Windows 设置里可开，无边框浮条（可拖动；不是 Win11 小组件板）
- [x] **录音**：不做。与产品禁令冲突（直播不落盘）；播客仍走用户按需下载

### P4 先做（听完之后更省事）

对照 BearWave / Transistor / AntennaPod / Pocket Casts，只吸收不碰版权目录的能力。

- [x] **记住上次收听**：冷启动回填迷你条（电台或播客），点播放才出声；设置可关。不自动播。
- [x] **播客播完下一集**：按当前排序接下一条；睡眠定时到点仍停；没有下一集则停。
- [x] **播客 OPML 导入导出**：和电台 JSON 备份并列，方便换机。
- [x] **添加电台认 M3U / PLS**：从播放列表取出第一条可用流再保存。`.m3u8` 仍当直播，不拆。
- [x] **电台详情复制 / 分享流地址**：坏链时用户能自己修或发给别人。

### P5 已完成

- [x] 睡眠到「本集结束」（AntennaPod；直播不可用）
- [x] 摇一摇延长睡眠，默认关（Pocket Casts；仅 Android）
- [x] ICY 曲名跑马灯（Radio Hangi；Windows 无 ICY 时仍回退分类）
- [x] Android 桌面小组件：台名 + 播放/暂停（`home_widget`）
- [x] 订阅节目新一集通知（默认关；最少 6 小时；首次只记 guid）
- [x] Podcast Index 搜索 → 一键订阅（只在设置里；默认滤 explicit；密钥本机保存）
- [x] Chromecast（仅 Android；默认接收器 CC1AD845；无 Play Services 时静默失败）

### 1.1.0（2026-08-16）

- [x] 工程包名 `chengbo`，Android `com.chengbo.chengbo`，Windows `Chengbo.exe`（旧 `com.cnradio.cn_radio` 不能覆盖安装）
- [x] Windows / 桌面 HTTP 读取系统代理，SoundOn 等境外公开 RSS 可订
- [x] 版本 `1.1.0+2`（Android `versionCode` 2）

### 1.1.1（2026-08-16）

- [x] RSS HTTP 400 改为中文说明；SoundOn / Firstory 节目页自动改成 Feed；Apple / Spotify / 小宇宙网页会提示不是 RSS
- [x] 启动时探测本机 Clash / NekoBox 常见端口；设置「电台管理 → 网络代理」显示状态
- [x] 版本 `1.1.1+3`（Android `versionCode` 3）

### 1.1.2（2026-08-16）

- [x] Android release 用 `android/key.properties` + `upload-keystore.jks` 正式签名；缺文件时回退 debug
- [x] 节目单页顶部说明可点 × 关掉并记住，或 3 秒后收起；设置「电台管理 → 节目单来源说明」可再打开
- [x] 版本 `1.1.2+4`（Android `versionCode` 4）

### 1.1.3（2026-08-16）

- [x] 直播电台 `setUrl` 不再预加载；超时重试，避免央广等 HLS 卡在「正在缓冲…」
- [x] 央广 / radio.cn 播放请求带 Referer
- [x] 精选目录去掉 6 个喜马拉雅假活源（HTTP 200 实为 JSON「电台流获取失败」）：惠州交通988、肇庆旅游之声、宁夏都市广播、山东新闻广播、甘肃交通广播、甘肃经济广播
- [x] 版本 `1.1.3+5`（Android `versionCode` 5）

### 1.1.4（2026-08-16）

- [x] 探测 GET 正文：HLS 必须有 `#EXTM3U` 和可播地址；JSON / HTML 即使 HTTP 200 也不算能播
- [x] 精选目录宁缺毋滥：不往 `stations_cn.json` 堆未核对的台；坏台删除，合并/导入脚本同样认正文
- [x] 探测只读约 2KB 前缀就断开，并行不超过 4 路，避免把无限直播流一直拉着把进程撑崩
- [x] Windows 换台先停稳再加载；`setUrl` 超时先停播放器，避免 just_audio_windows 原生崩溃
- [x] 版本 `1.1.4+6`（Android `versionCode` 6）

### 1.1.5（2026-08-16）

- [x] 电台列表与长按详情可隐藏不想听或听不了的台；设置「电台管理 → 已隐藏的电台」恢复
- [x] 本机一直缓冲或播失败按同一份隐藏名单处理，不从精选 JSON 删除
- [x] 长按详情点隐藏先记本机再关弹层，避免点了没藏上
- [x] 版本 `1.1.5+7`（Android `versionCode` 7）

### 1.1.6（2026-08-16）

- [x] Now Playing 左侧返回、右侧播放列表；播客切单集，电台切当前队列
- [x] 控制键整排同一 FittedBox（只缩小不放大），拉窗口比例一致
- [x] 版本 `1.1.6+8`（Android `versionCode` 8）

### 1.1.7（2026-08-16）

- [x] Radio Browser 发现补中文语言、交通标签、更多省份，以及 TW/HK/MO（只进发现层；港澳台仍要打开境外开关）
- [x] 发现结果只保留 CN/TW/HK/MO，不当成全球 Radio Browser
- [x] 精选 JSON 正文测活：删除失效的成都交通文艺广播（HTTP 404，无可用替换）
- [x] 探测遇到 Range 回 JSON / 302 / 416 时去掉 Range 再试
- [x] 版本 `1.1.7+9`（Android `versionCode` 9）

### 1.1.8（2026-08-16）

- [x] Windows：`just_audio_windows` 回调切回 UI 线程再发 EventSink，避免非平台线程 channel 崩溃
- [x] Windows 换台先停清源，HLS/DASH 开 RealTimePlayback；不发 ICY 头、换台不加 setSpeed
- [x] 版本 `1.1.8+10`（Android `versionCode` 10）

### 1.2.0（2026-08-17）

- [x] 首次启动全屏「选择想听的电台」：类型与/或省份并集，或「加载全部精选」；无默认预选，确认后才探测
- [x] 设置 → 电台管理 → 收听范围：复用同一界面，保存后重新检测
- [x] 旧版「电台加载范围」迁移为本机收听范围；已配置或已探测过的升级用户不重复引导
- [x] 版本 `1.2.0+12`（Android `versionCode` 12）

### 1.2.1（2026-08-17）

- [x] 播客收听历史：播客页顶部「收听历史」，记录最近 30 集（去重、显示听到哪里、点条目从断点继续、可清除）；播放/自动下一集都会记录
- [x] 播客 Now Playing 按参考图重设计：极简布局（顶部返回+「播客」标题、大圆角封面、左对齐标题、细进度条、加大控制按钮），跟随系统深浅色，顶部有节目取色渐变
- [x] 电台播放器移植同一布局；电台控制行 `−15/+15` 改为上一台/下一台（睡眠定时 / 上一台 / 大播放键 / 下一台 / 播放列表）；音量条占播客进度条位置；无相邻台时切台按钮置灰
- [x] 播放器顶部投屏按钮改线性图标（去掉圆形描边，`CastButton.outlined` 参数）
- [x] 添加 RSS 对话框崩溃修复：对话框自持 TextEditingController，避免退出动画期间访问已 dispose 控制器触发 `_dependents.isEmpty` 断言
- [x] 睡眠定时到点 / 停止时自动关闭 Now Playing 页，不再停留在「没有正在播放的内容」占位；停止按钮去掉手动 pop，避免双重关闭
- [x] 版本 `1.2.1+13`（Android `versionCode` 13）

### 1.2.3（2026-08-17）

- [x] 底部导航「收藏」tab 改为「收听」，内部用收藏 / 最近 / 统计三段聚合收藏电台、播客与电台的最近播放、以及收听时长统计
- [x] 播客页顶部「收听历史」tile 与设置页「收听统计」「最近播放」入口移除，数据模型、provider、存储键均保持不变
- [x] 版本 `1.2.3+15`（Android `versionCode` 15）

### 1.4.6（2026-08-18）

- [x] **Windows 电台卡住修复**：`just_audio_windows` 事件回调原来 Post 到 UI 线程再发 `EventSink`，Dart 端永远收不到播放状态更新，UI 卡在「正在缓冲」并触发看门狗重试循环。改为在 Media Foundation 回调线程直接发送事件（与官方一致，保留 mutex/disposed 保护）；去掉 load 末尾 `broadcastState()`（用过期 None/Opening 覆盖 Playing）与 load 后重复 `Play()`；恢复 loadSource 的 `Pause()` + `Source(nullptr)` 换源清理
- [x] **「未听」分页移除**：收听 tab 的「未听」分页因跨订阅逐个拉取 RSS 加载很慢，直接删除；`inboxProvider`、`PodcastInboxLogic`、`EpisodeWithFeed` 一并清理，收听 tab 恢复为 收藏 / 最近 / 统计 三段
- [x] **长按菜单统一替换列表常驻按钮**：电台列表、播客订阅列表、播客单集列表均移除右侧常驻 hide/favorite / 下载 / 简介按钮，改为长按弹出底部菜单，菜单包含播放、收藏/取消收藏、复制地址、分享、删除，列表更清爽
- [x] **电台长按菜单补回收藏**：用户反馈去掉收藏入口后不便使用，现重新加入长按菜单，并根据当前是否已收藏动态显示「收藏」或「取消收藏」
- [x] **播客订阅列表长按菜单**：新增长按底部菜单，支持播放最新、复制 RSS 地址、分享、删除订阅；列表项 trailing 删除按钮同步移除
- [x] **播客单集长按菜单**：长按单集弹出底部菜单，支持查看简介、加入播放队列、下载到本机 / 删除下载、复制音频地址、分享；列表项 trailing 下载 / 简介按钮同步移除
- [x] **设置页「源」改名为「电台管理」**：入口名称与图标同步更新，更清晰表达该页负责电台相关内容
- [x] **Now Playing 顶部栏标题精简**：电台与播客两款播放器顶部去掉「电台」「播客」标题文字，保留返回按钮与投屏按钮
- [x] 版本 `1.4.6+26`（Android `versionCode` 26）

### 1.2.12（2026-08-18）

- [x] **搜索播客移到播客管理页**：设置里「搜索播客（Podcast Index）」入口从「关于」页移到「播客管理」页，与添加 RSS、导入/导出 OPML 并列；关于页移除该入口
- [x] **设置页重新排序**：新顺序为 播客管理 → 电台管理 → 播放与收听 → 外观 → 数据管理 → 电台分类 → 关于；关于副文改为「版本、隐私说明」
- [x] **热力图空数据修复**：`_HeatCell._computeLevel` 在 `maxValue == 0` 时从返回 `1`（浅色模式下近透明绿）改为返回 `0`（空单元格灰），避免无数据时全部格子看起来失效
- [x] **收听统计持久化修复**：`ListeningStatsLogic.compact` 日期 key 解析从 `DateTime.tryParse(key.replaceAll('-', ''))` 改为 `DateTime.tryParse(key)`，因为 `dayKey` 生成标准 `YYYY-MM-DD`，去掉横杠后 Dart 不认，导致历史天数被静默丢掉
- [x] **Now Playing 标题居中修复**：`NowPlayingTopBar` 左侧 `IconButton` 加 `SizedBox(40×40)` 约束，消除隐形触控区，使「电台」「播客」标题视觉居中
- [x] **桌面迷你窗点击穿透修复**：`DeskMiniBar` 两个 `GestureDetector`（主条区域 + 圆形封面）加 `onTapDown` 消费点击，避免无边框窗口下首次点击穿透到下层 Scaffold 触发导航
- [x] 版本 `1.2.12+24`（Android `versionCode` 24）

### 1.2.11（2026-08-18）

- [x] **热力图修复**：`_HeatCell._computeLevel` 在 `maxValue == 0` 时从返回 `1`（浅色模式下近透明的绿色）改为返回 `0`（正确的空单元格灰），避免无数据时所有格子看起来全部失效
- [x] **收听统计持久化修复**：`ListeningStatsLogic.compact` 日期 key 解析从 `DateTime.tryParse(key.replaceAll('-', ''))` 改为 `DateTime.tryParse(key)`，因为 `dayKey` 生成的是标准 `YYYY-MM-DD` 格式，去掉横杠后 Dart 不认，导致从 SharedPreferences 加载时静默丢掉所有历史天数
- [x] 版本 `1.2.11+23`（Android `versionCode` 23）

### 1.2.10（2026-08-17）

- [x] **播客管理进入设置页**：设置新增「播客管理」入口，集中放置「添加 RSS 订阅」「从剪贴板导入 OPML」「导出 OPML 到剪贴板」三项操作；入口副文为「RSS 订阅、OPML 导入导出」
- [x] **订阅数量实时展示**：播客管理页顶部监听 `subscribedFeedsProvider`，加载态、空态、出错态均有占位，数据就绪后显示「共 N 个订阅」
- [x] **播客页去除三项操作**：订阅列表内的「添加 RSS」「导入 OPML」「导出 OPML」三个 `ListTile` 移除，仅在设置「播客管理」操作；不再被调用的 `_exportOpml` 静态方法一并清除
- [x] **空状态引导保留**：没有订阅时的空状态仍保留「添加 RSS」和「导入 OPML」两个按钮，作为首次使用的引导入口
- [x] 版本 `1.2.10+22`（Android `versionCode` 22）

### 1.2.8（2026-08-17）

- [x] 播客主页增加搜索框，按订阅标题搜索，搜索时隐藏继续收听卡片和 inbox
- [x] 版本 `1.2.8+20`（Android `versionCode` 20）

### 1.2.7（2026-08-17）

- [x] **逐节目记忆倍速**：每个播客订阅独立记忆播放速度，换节目自动恢复上次设的倍速
- [x] **下载自动清理**：设置「播放与收听」新增开关，可设置已听完的下载单集在 N 天后自动删除（默认 30 天），启动时自动清理
- [x] **手动播放队列**：播客单集长按可「加入播放队列」，队列顺序可拖拽调整，当前集播完后自动播队列里的内容，支持 ReorderableListView。播放列表（Now Playing → 队列）顶部增加队列段
- [x] 版本 `1.2.7+19`（Android `versionCode` 19）

### 1.2.6（2026-08-17）

- [x] **「继续收听」卡片**：播客页顶部显示最近未听完的单集，显示进度条，点按续播
- [x] **跨订阅未听单集聚合（inbox）**：各订阅最新一集按发布时间排成一列，播客主页顶部展示，点按直接播放
- [x] **单集自动标记已听并过滤**：播放到结尾时自动标记为已听完；播客详情页右上角眼睛图标可切换「隐藏已听完」，过滤后显示「都已听完」空状态
- [x] 版本 `1.2.6+18`（Android `versionCode` 18）

### 1.2.5（2026-08-17）

- [x] 外观切换添加 200ms AnimatedTheme 过渡，修复主题切换卡顿并恢复页面动画
- [x] 电台 Now Playing 的「直播中」与「停止」统一为 ActionChip，修复两个 chip 高度不统一
- [x] Chromecast 投屏默认关闭，设置「外观」页新增开关，按需启用
- [x] 版本 `1.2.5+17`（Android `versionCode` 17）

### 1.2.4（2026-08-17）

- [x] 收听统计页新增近 26 周收听热力图（GitHub 贡献图风格），按日显示收听强度，支持深浅色主题，可横向滚动查看更早记录
- [x] 版本 `1.2.4+16`（Android `versionCode` 16）

### 1.2.2（2026-08-17）

- [x] 收听历史改为播放真正出声时才记录（`RadioAudioHandler.onPlaybackStarted` 回调），播放失败的尝试不再进历史
- [x] 迷你条与播放器封面 Hero 圆角统一为 12，展开过渡不再有圆角突变
- [x] 播放器控制行由 FittedBox 压缩改为 `spaceEvenly`，窄屏下按钮保持固定大小（60 / 84）只压缩间距
- [x] 播客单集无时长信息时：进度条禁用拖动，右侧总时长显示 `--:--`
- [x] 版本 `1.2.2+14`（Android `versionCode` 14）

### 1.1.9（2026-08-16）

- [x] 去掉节目单：底栏改为电台 / 播客 / 收藏 / 设置；不再拉央广网表、不再内置荔枝网抄名
- [x] Windows 直播：`preload: false` 时 just_audio 会在原生 `load` 完成前发 `play()`，Media Foundation 换源后被 `Pause` 住；插件在 `load` 后补 `Play()` 并立即 `broadcastState`
- [x] Windows 直播：Dart 侧 `setUrl` 后显式 `load()` 再 `play()`；已在播时不把 MF 的 buffering 显示成「正在缓冲…」
- [x] Windows 直播：Dart 侧在仍 opening 时再补一次 `play()`；请求头只跳过 ICY，央广 Referer 仍保留（供代理路径）
- [x] 电台加载范围改为首次启动自选：类型（央广 / 音乐 / 新闻等）与/或省份并集，或「全部精选」；无默认预选；设置 → 电台管理 → 收听范围 可改并重探测
- [x] 版本 `1.1.9+11`（Android `versionCode` 11）

### 仍可排后

- 功能候选与推进计划见 [ROADMAP.md](ROADMAP.md)（收听时长统计、继续收听、跳过片头等，纯本机增强）。源维护仍按 [SOURCES.md](SOURCES.md) 定期测活，不堆未核对的台。

---

## 四、约定

1. 精选 JSON **宁缺毋滥**。稳定可播的国内台才写入 `assets/stations_cn.json`。添加前必须 GET 正文：HLS 要有 `#EXTM3U` 和至少一条非注释地址；JSON / HTML 即使 HTTP 200 也不入库。不要为了覆盖面堆台。**首次启动**须先选收听范围（类型 / 省份 / 全部精选，至少一项），确认后才探测；之后只在下拉刷新或设置「电台管理 → 检测可播放的源」时测全部源，连不上的不出现在主页。修改「收听范围」会重置探测。用户可隐藏不想听或听不了的台（本机名单，不改 JSON）。本机点播后一直缓冲或播失败也会按隐藏处理。探测不模拟播放。「刷新电台列表」只更新目录。
2. 不要使用带 `t=` / `key=` 的短期 token 流地址。
3. 改 `assets/` 后必须完全重启 App。
4. 分类：名称或 tags 含「音乐/新闻/交通…」进主题类；`央广` / 无主题的 `地方台` 锁定。
5. 新功能优先落在 `features/`，通用逻辑放 `core/`，不要把大页塞回 `home_shell.dart`。
6. 本机构建与打包走 `.\scripts\flutter.ps1` / `.\scripts\pack.ps1`，不要直接打国外源；镜像清单见 `scripts/china-mirrors.ps1`。
7. Android 打包需要 JDK 17（`pack.ps1` 会选用本机 Microsoft OpenJDK 17）。打包前会先 `gradlew --stop`，避免 Groovy DSL 缓存被 daemon 占用后偶发损坏。APK `minSdk` 为 23；release 优先用 `android/key.properties` + `upload-keystore.jks` 正式签名，缺文件时回退 debug。插件钉死：`dynamic_color` 低于 1.9.0（1.9.0 的 Gradle 在 AGP 8.9 上编不过）、`home_widget` 0.8.0；Glance 用 `1.1.1` 强制解析，避免 `1.+` 拉到要 AGP 9 的预览版。子工程 Kotlin/Java 统一 JVM 11。
8. 摇一摇、桌面小组件、Chromecast 只做 Android；Windows 不显示入口，也不要为它们加 Win11 小组件板。
9. Windows 编译需要 VS 2022 生成工具的 **C++ ATL**（`atlbase.h`）。只装 C++ 工具、不装 ATL 时，增量 Release 可能还能过，Debug 全量重编会在 `flutter_local_notifications_windows` 上失败。`just_audio_windows` 用仓库内 `third_party/just_audio_windows`（回调切回 UI 线程），不要改回 pub.dev 的 0.2.3。
