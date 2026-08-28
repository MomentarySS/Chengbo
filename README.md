# 澄波（Chengbo）

听国内广播。支持 **Android** 与 **Windows**。可收听直播电台、订阅 RSS 播客。播放器为 Spotify 式底部迷你条 + 上滑 Now Playing。

工程包名为 `chengbo`，Windows 可执行文件为 `Chengbo.exe`，Android 应用 ID 为 `com.chengbo.chengbo`。

当前版本：`1.5.3+32`（2026-08-28）。相对 1.5.2：下载自动清理不再冲掉进行中进度；删除订阅会取消正在下载的任务。

功能清单见 [DEVELOPMENT.md](DEVELOPMENT.md)：P0–P5 已完成。源扩充仍可排后的项见 [SOURCES.md](SOURCES.md)。成人向公开 RSS 的人工清单见 [ADULT_SOURCES.md](ADULT_SOURCES.md)（不预装）。

## 功能

- 直播电台：首次启动自选想听的**类型**（央广、音乐、新闻等）和/或**省份**，也可选「加载全部精选」；之后可在设置「电台管理 → 收听范围」修改。默认只显示中国大陆电台；港澳台等境外台需在设置「电台管理」中打开「显示境外电台」
- 确认收听范围后才探测直播源，之后沿用那次能播的台；探测会读取少量正文，JSON/网页即使 HTTP 200 也不算能播。主页每台可点隐藏；听不了或不想听的都会从列表拿掉，设置「电台管理 → 已隐藏的电台」可恢复。本机点播后一直缓冲或播放失败也会按隐藏处理。下拉或「检测可播放的源」才会重新探测；「刷新电台列表」只更新目录。断网时顶部提示，列表与播放失败会说明是没有网络
- 收藏、最近播放与收听统计统一在底部「收听」tab：收藏段保留收藏电台；最近段合并播客收听历史与电台最近播放，各自可清除；统计段展示今日 / 本周 / 总时长、电台 vs 播客占比、最常收听，本机记录可清除；播客收听历史支持导出 JSON（含历史 + 统计）
- **本地精选**（`assets/stations_cn.json`，约 413 个已测流，2026-08-19 重建：蜻蜓省市级 + 央广官方 + 广东本地补充）+ **手动添加** + **Radio Browser 发现**（可开关；按所选省份与标签并行拉，同名跳过）；实际加载范围由首次启动或设置里的「收听范围」决定；境外台默认隐藏
- 播客 RSS 播客：自行添加订阅、删除、下拉刷新、单集简介、播放进度、按需下载离线听（长按或右键单集下载 / 取消 / 重试；详情页可全部下载、最近 3/5/10 集、或勾选多集；下载中在该行显示进度）。Now Playing 可 ±15 秒与倍速（0.5–2×）。播完按当前排序自动下一集。可用剪贴板导入/导出 OPML。不自带默认播客。「最近」段记录最近 30 集，显示听到哪里，可点继续收听或清除；单集列表支持直接查看 Show Notes
- 后台播放（Android 通知栏控制；13+ 首次启动会请求通知权限）
- Spotify 式播放器：迷你条点开 Now Playing 时封面有 Hero 动画；**电台与播客为同一套极简布局**（跟随系统深浅色，顶部有播放内容取色的柔和渐变）：顶部返回 + 投屏（仅 Android）、大圆角封面（无图时占位图标）、**居中**标题、细调节条（播客为进度、电台为音量）、加大底部控制行——播客：倍速 / ±15 秒 / 大播放键 / 播放列表；电台：睡眠定时 / 上一台 / 下一台 / 播放列表；简介、已下载、睡眠定时、跳过片头/尾、停止在标题下；睡眠定时（5–60 分钟多档 + 自定义，或播客「本集结束」），支持 30 秒淡出与小睡 10 分钟（暂停，到点后续播）；右侧播放列表可切换电台或单集，手动队列可查看全部条目；直播流若带 ICY 元数据，迷你条与 Now Playing 会显示正在播放曲名，过长则跑马灯
- Android Auto / 车机：可浏览收藏、最近播放和电台，通知栏可切台
- Windows 桌面迷你窗：设置里打开后变成可拖动的无边框浮条（圆封面 + 播放控制），点 × 回到完整窗口
- Android：桌面小组件（台名 + 播放/暂停）、摇一摇延长睡眠（默认关，再加 5 分钟）、Now Playing 投屏到 Chromecast（默认接收器，无 Play 服务时提示不可用）
- 设置：外观（跟随系统 / 浅色 / 深色；Android 可开 Chromecast）、壁纸/系统配色、记住上次收听、桌面迷你窗（仅 Windows）、摇一摇延长睡眠（仅 Android）、新一集通知（默认关，最少 6 小时，首次只记进度）、自动清理下载（播放与收听）、清除封面缓存 / 清除播客下载（数据管理可点开已下载清单）、Podcast Index 搜索（设置 → 播客管理）、播客管理（RSS 订阅、OPML 导入导出、订阅数量）、电台管理（收听范围、检测可播放的源、刷新电台列表、连不上的电台、Radio Browser、境外、手动添加）、[隐私说明](PRIVACY.md)。电台页搜索区可按码率过滤（64k+ / 128k+ / 256k+）。播客节目详情「全部下载」下可开「仅 WiFi 下载」，并可「下载最近 N 集」或勾选多集。单集列表在有 Show Notes 时右侧显示备注图标
- Material 3：默认跟随系统深浅；Android 12+ 可按壁纸取色，Windows 可用系统强调色，也可关回澄波蓝

## 技术栈

| 用途     | 依赖                                                  |
| -------- | ----------------------------------------------------- |
| UI       | Flutter 3.x、Material 3                               |
| 状态     | Riverpod 2.x                                          |
| 音频     | `just_audio` + `audio_service` + 仓库内 `just_audio_windows`（UI 线程回调） |
| 网络     | `dio`、`connectivity_plus`                            |
| 图片     | `cached_network_image` / `flutter_cache_manager`      |
| 本地存储 | `shared_preferences`                                  |
| 分享     | `share_plus`（电台详情分享流地址）                      |
| 动态色   | `dynamic_color`（Android 壁纸）+ `system_theme`（强调色） |
| 哈希     | `crypto`（Podcast Index 鉴权）                          |
| 权限     | `permission_handler`（Android 13+ 通知）              |
| 传感器   | `sensors_plus`（摇一摇延长睡眠）                        |
| 小组件   | `home_widget`（Android 桌面）                          |
| 通知     | `flutter_local_notifications` + `workmanager`         |
| 投屏     | `flutter_chrome_cast`（仅 Android）                    |

## 首次设置

若平台目录不完整，安装 Flutter 后运行：

```powershell
.\scripts\setup.ps1
# 或手动:
flutter create . --platforms=android,windows --org com.chengbo --project-name chengbo
flutter pub get
```

## 运行

推荐用脚本（会带上国内镜像与 JDK 17）：

```powershell
.\scripts\flutter.ps1 run -d windows   # Windows 桌面
.\scripts\flutter.ps1 run -d android   # Android 设备/模拟器
.\scripts\flutter.ps1 test             # 单元测试
```

改 `assets/` 下的 JSON 后需 **完全重启** App（热重载不会重新打包资源）。新写入的精选台如果还没探测过，会出现在设置「电台管理 → 连不上的电台」；点「检测可播放的源」才会重新探测全部源。

## 打包

```powershell
.\scripts\pack.ps1
```

`pack.ps1` / `flutter.ps1` 会加载 [scripts/china-mirrors.ps1](scripts/china-mirrors.ps1)，构建流量走国内镜像：

| 用途                         | 镜像                                          |
| ---------------------------- | --------------------------------------------- |
| Dart 包 / Flutter SDK 资源   | `pub.flutter-io.cn`、`storage.flutter-io.cn`  |
| Gradle 发行包                | 腾讯云 `mirrors.cloud.tencent.com/gradle`     |
| Maven / Google / Gradle 插件 | 阿里云、华为云 Maven                          |
| Android SDK 目录表与 NDK     | 腾讯云 `mirrors.cloud.tencent.com/AndroidSDK` |
| Windows NuGet                | 华为云 NuGet                                  |

产物在 `dist/`，文件名跟 `pubspec.yaml` 的 `x.y.z` 走（当前为 `chengbo-1.5.3.apk`、`chengbo-windows-1.5.3.zip`、`chengbo-windows-1.5.3.exe`）。改版本后需重新 `.\scripts\pack.ps1`。本机有 `android/key.properties` 时 APK 用正式密钥签名；没有则回退 debug 签名。`minSdk` 23。Windows 双击 `.exe` 安装包安装，安装后从开始菜单启动；安装包支持卸载（控制面板 / 设置 → 应用）。

正式密钥在 `android/upload-keystore.jks`，密码在 `android/key.properties`，两份都已被 git 忽略。请复制到仓库外备份；丢了就无法再发「同一个 App」的更新。以前用 debug 签名装过的手机，不能直接覆盖安装，需先卸载（收藏等本机数据会清掉）。

首次打 APK 会从腾讯云拉取 NDK（约 700 MB）到本机 Android SDK，之后会跳过。Android 打包需要 **JDK 17**。Windows 需要 Visual Studio 2022 生成工具，并勾选 **C++ ATL**（`flutter_local_notifications_windows` 要 `atlbase.h`）。

Android 13+ 真机已核对：首次启动通知权限、后台播放、通知栏/锁屏控制。拒绝通知权限时前台仍能播放。

## 数据来源与优先级

合并后的电台列表顺序：

1. **手动添加**（设置 → 电台管理 → 手动添加电台，存在本机 SharedPreferences）
2. **本地精选** `assets/stations_cn.json`（人工维护的国内台）
3. **Radio Browser API**（默认开启；按所选省份、投票、中文语言、新闻/音乐/交通标签并行拉取，另含港澳台发现台；与本地同名则跳过）

首次启动会先让你选收听范围（类型 / 省份 / 全部精选），**确认后**才对合并后的列表做并行连通性检测，并把能播的台记在本机。之后启动不再探测，按这份名单播放。修改「收听范围」会重新检测。港澳台等境外台默认不出现在列表里，设置 → **电台管理** → **显示境外电台** 打开后才会显示，且排在境内台后面。

| 来源          | 列表标注       |
| ------------- | -------------- |
| Radio Browser | 来源：网络发现 |
| 手动添加      | 来源：手动添加 |
| 本地精选      | 不标注         |

- API 文档：[Radio Browser](https://docs.radio-browser.info/)
- 播客：不自带订阅，在应用内添加公开 RSS

商业平台（喜马拉雅、蜻蜓 FM 的版权点播）需要官方合作，本项目只播公开直播流与公开 RSS。

## 缓存说明

- **直播音频**：流式播放，不落盘；仅内存缓冲
- **播客音频**：默认在线播放并记住进度；可按需下载到应用私有目录，设置里可清除
- **台标图片**：`cached_network_image` 写入临时目录；设置里可查看占用并清除

## 添加电台

### 在 App 内（推荐日常使用）

设置 → **电台管理** → **手动添加电台** → 填名称 + 流地址（`.m3u8` / `.mp3`，或 `.m3u` / `.pls` 播放列表）→ 可先「测试连接」再保存。贴播放列表时会取出第一条可用流。已添加的台可编辑；右上角可把 JSON 复制到剪贴板或从剪贴板导入。长按电台可复制或分享流地址。

精选或网络发现的台坏了，不必等发版：长按 → **更换地址**，或设置 → **电台管理** → **连不上的电台**。新地址只存在本机，可「恢复精选原址」。稳定可播的替换仍建议写回 `assets/stations_cn.json`。

### 写入精选 JSON（推荐稳定可播的台）

在 `assets/stations_cn.json` 追加对象：

```json
{
  "id": "fs-music-1",
  "name": "佛山音乐广播",
  "url": "http://example.com/live.m3u8",
  "favicon": "https://example.com/logo.png",
  "tags": ["地方台", "广东", "佛山", "音乐"],
  "category": "地方台",
  "bitrate": 64,
  "codec": "AAC",
  "homepage": "https://example.com/"
}
```

添加前必须 GET 正文，不要只看 HTTP 200。HLS 要有 `#EXTM3U` 和至少一条非注释地址；返回 JSON 或网页的不要入库。宁缺毋滥，不要为覆盖面堆台。

```powershell
curl.exe -sL --max-time 12 "流地址" | more
```

带 `?t=` / `key=` 的 token 链接会过期，优先用不带 token 的地址。

广东台批量测试 / 合并：

```powershell
python tools/test_gd_stations.py
python tools/merge_gd_stations.py
```

## 项目结构

```
lib/
├── main.dart
├── app.dart
├── core/
│   ├── audio/          # 播放器、ICY、睡眠、摇一摇、Cast 逻辑、小组件快照、队列
│   ├── category/       # 分类规则
│   ├── models/
│   ├── network/        # Radio Browser、RSS、系统代理、新一集检查、离线
│   ├── station/        # 收听范围选择、隐藏、补丁、自定义台
│   ├── platform/       # 通知、Cast、桌面小组件同步、迷你窗
│   ├── podcast/        # 收听历史、OPML、已听标记
│   ├── stats/          # 收听时长统计
│   ├── privacy.dart    # 与 PRIVACY.md 共用的文案
│   ├── providers/      # Riverpod providers、storage providers
│   └── storage/        # SharedPreferences、封面缓存、播客下载
├── features/
│   ├── home/           # 底栏 / 侧栏
│   ├── radio/          # 电台列表、分类、首次收听范围设置
│   ├── podcast/
│   ├── listening/      # 收听 tab：收藏 / 最近 / 统计
│   └── settings/       # 设置、手动添加电台、Podcast Index、隐私说明
└── shared/widgets/     # MiniPlayer、Now Playing、跑马灯、Cast、摇一摇、队列
android/                # 含 ChengboWidgetProvider 桌面小组件
assets/
└── stations_cn.json
scripts/                # setup / flutter / pack / 国内镜像
test/                   # widget_test + layer_test
tools/                  # 广东台测流、合并脚本
```

## 注意事项

- 部分第三方流会失效，优先改 JSON 或在 App 内手动添加替代源
- Radio Browser 会动态解析镜像；User-Agent 为 `Chengbo/1.5.3 (Flutter; chengbo radio)`
- Windows 订阅境外 RSS（如 SoundOn）会走系统代理，并探测本机 Clash 常见端口；手机请用 Clash / NekoBox 的 VPN/TUN，并把澄波加入代理名单
- Android 后台播放需通知权限（Android 13+）；系统要求 `minSdk` 23
- Windows 需 `just_audio_windows`；中文路径编译已在 CMake 加 `/utf-8`
- 摇一摇、桌面小组件、Chromecast 只在 Android；Windows 不显示这些入口
- 隐私说明见设置页与 [PRIVACY.md](PRIVACY.md)

## 已知限制

- HLS（`.m3u8`）和 Windows 播放引擎通常没有 ICY 曲名，迷你条会回退显示分类；有 ICY 且一行放不下才跑马灯
- Chromecast 需要 Google Play 服务，以及和手机同一网络上的投屏设备
- 新一集通知默认关；打开后最少隔 6 小时查一次订阅，第一次只记 guid

完整清单与同类 App 对照见 [DEVELOPMENT.md](DEVELOPMENT.md)。仍可排后的源扩充见 [SOURCES.md](SOURCES.md)；成人向 RSS 清单见 [ADULT_SOURCES.md](ADULT_SOURCES.md)。

## 许可证

MIT，见仓库根目录 [LICENSE](LICENSE)。
