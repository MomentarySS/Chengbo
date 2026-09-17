# 路线图

后续功能按本文推进，做完一项就把状态勾成完成，并在 `DEVELOPMENT.md` 加对应版本变更记录、必要时升版本号。

**边界**：遵守 `DEVELOPMENT.md`「明确不做」清单——复古收音机 UI、版权点播（喜马拉雅/蜻蜓）、直播录音、独立闹钟、均衡器、音量增强、逐字稿、全球浏览器、爬节目单、Win11 小组件、iOS 均不碰。下列候选均为**纯本机数据增强**，符合 `PRIVACY.md` 不收集收听内容的定位。

**复杂度**：低 = 几小时、复用已有数据；中 = 一两天、需新数据结构或新页面；高 = 多天、跨层。

---

## P1 收听统计

- [x] **收听时长统计**（复杂度：中）
  - 播放时按墙钟累计到「今日 / 本周 / 总时长」，电台与播客分开；倍速按实际经过时间算
  - 数据源：`RadioAudioHandler` 的 `positionStream`（已在 `_persistProgress` 写盘，加一个时长累计器）
  - 新增：`lib/core/stats/listening_stats.dart`（模型+逻辑）、`lib/core/providers/listening_stats_provider.dart`、`AppStorage` 读写（键 `listening_stats_json`，按日存）
  - 入口：收听 tab「统计」段（1.2.3 起不再走设置独立页）
- [x] **收听热力图**（复杂度：低，依赖上一项）
  - 1.2.4 落地；**1.4.8 已从统计页移除**，时长数据仍保留

## P2 续播与追新

- [x] **「继续收听」卡片**（复杂度：低）
  - 主页或播客页顶部一张卡：上次没听完的单集 + 进度，一键续播
  - 数据源：已有 `podcast_progress_<guid>` + 播客历史，查询「未听完且最近」
- [x] **跨订阅未听单集聚合（inbox）**（复杂度：中）
  - 1.4.6 **已移除**：跨订阅逐个拉 RSS 太慢；收听 tab 恢复为收藏 / 最近 / 统计。不要再当已交付功能。
- [x] **单集自动标记已听并过滤**（复杂度：低）
  - 播完写入已听 guid；节目详情芯片可筛全部 / 未听 / 已下载 / 收藏（1.5.4；不再用眼睛开关）

## P3 播客增强

- [x] **跳过片头/片尾**（复杂度：低）
  - 每个节目可设「跳过开头 N 秒 / 结尾 N 秒」（对付片头广告）
  - 存 `feedId → 跳秒` 映射，播放到该节目时 seek；1.5.0 已做
- [x] **逐节目记忆倍速**（复杂度：低）
  - 按 `feedId` 存各自倍速；未设过的节目回退上次全局倍速
- [x] **下载自动清理**（复杂度：低）
  - 已听完的下载单集过一段时间自动删，省空间
- [x] **手动播放队列**（复杂度：中）
  - 长按「加入队列」，自定义顺序（现在只能按排序自动下一集）
- [x] **下载入口与进度**（复杂度：低，1.5.2 / 1.5.3）
  - 修「最近 N 集」：不依赖「全部下载」开关，按最新在前取未下载的前 N 集
  - Windows 右键与长按同一份单集/订阅菜单；下载中可取消，失败可重试
  - 单集行显示下载进度与失败；顶栏勾选 + 菜单「选择多项」再下
  - 进度只做在节目详情列表，设置「数据管理」仍只占用 + 清除
  - 1.5.3：reload 不冲进度；删订阅取消 inflight；补并行 / 失败提示 / 勾选测试
- [x] **单集已听 / 收藏筛选**（复杂度：低，1.5.4）
  - 长按标已听/未听、收藏单集；节目详情芯片：全部 / 未听 / 已下载 / 收藏
- [x] **±秒、睡眠记忆、再听 N 集**（复杂度：低，1.5.4）
  - 全局 10/15/30/60；睡眠记住上次；再听 2/3 集
- [x] **单集章节**（复杂度：中，1.5.4）
  - Podlove 随 Feed；Podcasting 2.0 JSON 仅播放或点开时请求

---

## 下一轮（2.0.1 之后）

P0–P5、P6 发现页、P10 护栏、本机备份、车机播客、inbox、按节目自动下载、时间戳书签与 P8 Windows 桌面（含 Android 小组件下一台 / 续播）已完成。**2.0.1** 已发布（含 2.0.0 的稳定版能力，以及暂停后前台服务保留、进度与已听状态独立存储和备份恢复兼容）。下面仍是纯本机增强。源测活不算功能发版：央广 ytlive 探测 403 不要当死链删，签名过期用 `tools/refresh_radio_cn.py`。

**合入规则**：下列未做项每项单独改、单独测、单独勾；不要把缓冲、手势、发现页捆成一次 diff。改播放器构造或 `AudioServiceConfig` 必须真机过一遍「播 → 暂停 → 睡眠淡出 → 换台」。

### P6 发现、换机、目录

- [x] **播客发现：搜索 + 中文热榜**（复杂度：中，1.6.0）
  - `PodcastDiscoveryScreen`：搜索 | 中文热榜；iTunes 免密钥；xyzrank 热榜分页；Podcast Index 高级；GetPodcast 外链
  - 入口：空订阅「搜索节目」、设置「发现播客」、有订阅时「发现节目」。本机订阅搜索仍只滤本机
  - `PodcastFeedLogic.isDeniedCatalogFeed` 拦喜马拉雅 album / RSSHub / 荔枝；发现页、粘贴、OPML 共用
  - 不要用 xyzrank 查询参数当搜索；Listen Notes 仍只作文档备选
- [x] **整机本机备份 / 恢复**（复杂度：中，1.6.0）
  - 设置 → 数据管理：导出 JSON（系统分享）、从剪贴板恢复
  - 含收藏、已听、进度、隐藏台、本机换址、收听范围、订阅、外观等 SharedPreferences
  - 不含直播音频、已下载播客文件、Podcast Index 密钥；恢复后须完全退出再打开
- [x] **精选目录测活**（复杂度：低，持续；1.6.0 去掉 3 个蜻蜓 404 与汕头综合广播，央广 ytlive 换新签，约 409 台。探测 403 不要当死链删）
  - `stations_cn.json` 上次重建 2026-08-19；死链用 `tools/prune_dead_stations.py`；央广换签用 `tools/refresh_radio_cn.py --apply`
  - tingfm / radio5 限流解开后再补港澳台与网络台；宁缺毋滥，不堆未核对的台
- [x] **Android Auto 播客**（复杂度：中，1.6.0）
  - MediaBrowser 增加「继续收听」与「已下载」；电台仍上限 40；已下载同样截到 40
  - 点选走 `playerController.play`；本机文件由 handler 按 guid 解析

### P7 听感（纯本机）

- [x] **Feed 缓存后恢复未听 inbox**（复杂度：中，1.6.0）
  - 1.4.6 因当场拉全部 RSS 太慢已删；不要按旧实现重做
  - 打开应用后 6 小时拉一次，每次最多 12 个订阅，解析结果写入本机缓存；inbox 从缓存拼
  - 入口在播客页顶部（继续收听下方），搜索时隐藏；不另开底栏
  - 缓存不进整机备份；打开节目详情也会写入
- [x] **按节目自动下载最新一集**（复杂度：低，1.6.0）
  - 节目详情「自动下载最新一集」开关，默认关；复用下载队列与仅 Wi-Fi 开关
  - 打开后刷新订阅或 Feed 缓存更新时只下最新一集；删订阅会关掉
- [x] **跨节目搜单集标题**（复杂度：低，1.6.0）
  - 播客页搜索同时滤订阅名与缓存里的单集标题；没有缓存的节目只按订阅名匹配
- [x] **章节上一章 / 下一章**（复杂度：低，1.6.0）
  - 1.5.4 已显示章节与进度打点；控制键与耳机键在有章节时按章跳
- [x] **时间戳书签**（复杂度：低，1.6.0）
  - 某集某秒一条本机笔记；Now Playing「书签」与单集菜单；点按跳转；不上传、不做分享卡片
  - 同一秒覆盖笔记；上限 200；删订阅会清掉该节目书签

### P8 Windows 桌面

产品原则：手机和桌面同一产品。迷你窗已有，作为工作时的背景电台还缺：

- [x] **托盘 + 关窗口不退出**（复杂度：中，1.6.0）
  - 关主窗进托盘，音频继续；托盘可播停 / 还原 / 退出
  - 不是 Win11 小组件板；迷你窗 × 仍回到完整窗口
- [x] **键盘快捷键**（复杂度：低，1.6.0）
  - 空格播停；方向键 ± 秒（跟当前跳秒档；有章节时与屏幕按钮一样按章跳）
  - 搜索等输入框有焦点时不抢键
- [x] **开机启动 / 启动即迷你窗**（复杂度：低，1.6.0）
  - 默认关；设置「播放与收听」里开
  - 开机启动写当前用户 Run 项，登录后打开但不自动播放；启动即迷你窗每次冷启动都进迷你窗
- [x] **Android 小组件补下一台 / 续播**（复杂度：低，仅 Android，1.6.0）
  - 现有播停之外：下一台切当前列表电台；续播未听完单集，没有则播上次收听

### P10 听感与手势（P6 之后，每项单独合入）

对照 RadioDroid / AntennaPod / Pocket Casts / Transistor，只吸收**不碰均衡器、音量增强、静音裁剪、逐字稿**的能力。音质瓶颈多半是 64k 精选流，不要承诺把 MP3 听成 320k。

#### 护栏（改播放器前先读）

- `RadioAudioHandler` 里 `AudioPlayer` **只构造一次**，挂在 `AudioService.init` 上。`AndroidLoadControl`、`AudioPipeline` 只能在这一次构造传入。
- **禁止**为了换缓冲档而 `dispose` 再建播放器：会拆掉 audio_service、睡眠淡出（`setPersistVolume`）、Cast、进度节流、ICY。1.4.6 Windows 卡缓冲就是回调线程改错导致的，同类回归代价大。
- 睡眠淡出走 `handler.setVolume` + `setPersistVolume(false)`（`SleepTimerNotifier._beginFadeOut`）。任何新音效不得把中间音量 0 写成「上次音量」（1.5.0 已修过一次）。
- Windows：`just_audio_windows` 无 LoadControl、无 ICY。这些入口只在 Android 显示；Windows 保持现状。
- 手势：Windows 已有右键 = 长按，**不要**再加滑动（鼠标拖易误触）。桌面迷你窗靠拖动搬家，**禁止**在 `DeskMiniBar` 上滑切台。

#### 推荐合入顺序（低风险 → 易踩坑）

- [x] **通知 / 锁屏封面不用 favicon.ico**（复杂度：低，1.6.0）
  - `ArtworkUrlLogic.resolve` / `mediaArtUri`；列表与 `MediaItem` 共用。无图则 `artUri: null`。ICY 更新不换封面 URI

- [x] **Android 直播缓冲：只改构造默认值，不做运行时档位**（复杂度：低，1.6.0）
  - 仅 Android 构造时传 `AndroidLoadControl`（`PlaybackLogic` 常量）。不要热切换、不要重建播放器、不要改看门狗

- [x] **电台 / 单集滑动手势（仅 Android 列表）**（复杂度：低，1.6.0）
  - 电台左滑隐藏 / 右滑收藏（行不消失）；单集左滑已听 / 右滑下载。选择模式与 Windows 不包 `Dismissible`

- [x] **迷你条左右滑切台 / 跳秒（仅手机完整窗）**（复杂度：低，1.6.0）
  - 仅封面+标题区；阈值 64px、冷却 400ms；加载中忽略。`DeskMiniBar` 与宽屏 Rail 不加

- [x] **播客开播时切 speech 会话（谨慎）**（复杂度：低，易回归，1.6.1）
  - **现状**：`main.dart` 一次 `AudioSessionConfiguration.music()`。
  - **已做**：仅在 `_startPlayback` 停源之后、`setUrl` 之前，按 `item.kind` 且种类变化时 `configure`（电台 music / 播客 speech）。ICY、position、暂停、同类换台/下一集/重试不切。仅 Android。
  - **坑**：部分机型切换会话会暂停当前播放。必须真机：电台→播客、播客→电台、来电打断后恢复。若不稳则整项回滚，只留 music。

- [x] **暂停后是否退出前台服务**（复杂度：低，默认不动）
  - **原状**：`AudioServiceConfig(androidStopForegroundOnPause: true, androidNotificationOngoing: true)`，只在 `AudioService.init` 时生效，**运行时改不了**。
  - **已改**：`androidStopForegroundOnPause: false`，暂停后仍保持前台服务；按 audio_service 约束同步把 `androidNotificationOngoing` 改为 `false`。副作用：暂停时通知还在，用户可能以为在播。改则必须测：暂停、停止（通知应消失）、锁屏、后台。

- [x] **蓝牙连回续播**（复杂度：低，默认关，1.6.1）
  - 用 `audio_session` 的设备事件，不要自己注册广播。默认关。开时仅当 `_userWantsPlayback` 为 true 且当前仍有 item。耳机拔出暂停仍走系统 `becomingNoisy`（just_audio 已听），不要重复 pause。
  - 投屏已连接或睡眠小睡时不恢复。

- [x] **列表密度「紧凑」**（复杂度：低，1.6.1）
  - **不要**改全局 `ThemeData.visualDensity`（会压 NavigationBar / 芯片 / 按钮）。只给电台 `ListTile`、单集 `ListTile`（含未听 inbox、收听历史）设 `visualDensity: compact`。外观开关默认标准。

- [x] **正在播放指示**（复杂度：低，1.6.1）
  - 行已有 `selected` + `primaryContainer`。leading 用静态播放图标（台标角标 / 单集 `play_arrow`）。**禁止** `positionStream` 驱动的频谱/条形动画（迷你条会整页重建）。

#### 明确不做（本段）

运行时热换 `AudioPlayer`、音量增强 / LoudnessEnhancer、用户可调均衡器/静音裁剪、迷你窗滑动切台、Windows 列表滑动、全局 compact 主题、把缓冲失败改成不隐藏电台、为通知栏生成音频文件。

### P9 工程（不急）

- [x] **进度与已听迁出 SharedPreferences**（复杂度：高）
  - 每个 guid 一把 key，订阅多了启动和写盘会慢
  - 已迁到应用支持目录下的 `podcast_episode_state.json`；启动时自动合并旧版 `podcast_progress_<guid>` / `listened_episode_guids`，并保留旧备份恢复兼容
- [x] **首次探测可取消、可先听已测到的**（复杂度：中，1.6.1）
  - 409 台、4 路并行；探测中列表随测通的台增长，顶上进度可「停止检测」。取消保留已测到的并记为完成。
- [x] **关键页面补 widget 测试**（复杂度：中，1.6.1）
  - `test/key_screens_test.dart`：探测进度/取消、首次选台、本机备份、免密钥搜索、紧凑列表默认关、电台筛选空态

### 不要做

热力图（1.4.8 已从统计页拿掉）、无缓存的 inbox、全球 Radio Browser、节目单、录音、独立闹钟、均衡器、音量增强、静音裁剪、逐字稿、成人分类、Win11 小组件、iOS / Web、运行时销毁重建 `AudioPlayer`。

---

## 状态约定

- 未做：`- [ ]`；完成：`- [x]` 并在 `DEVELOPMENT.md` 记录
- 优先级可调；做完高优先项后再动低优先
- 每项实施前先确认数据结构与入口，避免返工
- 改 `RadioAudioHandler` / `AudioServiceConfig` / 睡眠淡出：先补或跑 `layer_test` 里 playback、sleep、hide 相关用例，再真机「播 → 暂停 → 淡出 → 换台」
