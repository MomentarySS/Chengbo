# 移动端 UX 升级研究（2026-09）

> 研究性输入，**不是待执行计划**。用于在动手前对齐：哪些方向有强证据、哪些只是「听起来好」、哪些会和现有「静水电波」约束打架。
> 适用：澄波 Chengbo 2.0.x → 2.1+ 移动端（Android 优先，Windows 同步考虑）UI 升级。
> 调研日期：2026-09-22。

---

## 状态总览

| 维度 | 现状（v2.0.2） | 研究结论 | 建议优先级 |
|---|---|---|---|
| 迷你条 | Material `surface-container-high` 浮石，elevation 6，固定在导航之上 | Pocket Casts 2026 已把 mini player 与 tab bar 合并为 Liquid Glass 联动件，滚动收拢 | **高**（每次听都看） |
| Now Playing | edge-to-edge 大封面 + 封面色 55% 渐变到 surface | Spotify 2025-26 把歌词/章节内联进 NP；不抄歌词，可借鉴「在 NP 里多承担一层信息」 | **高** |
| 通知 / 锁屏 | 已用 `MediaStyle`，但 favicon.ico 被当封面 | 「通知封面不用 favicon」已是 ROADMAP 待做；Material You 14-15 推荐 large icon 为对专辑色 | **高**（ROADMAP 已有） |
| 播客进度条 | 现状是细线性条 | 小宇宙「高能进度条」是被验证的强互动件；Chengbo 无社交，不必抄 | **中** |
| 主屏 / Tab | 4 项 NavigationBar（电台 / 播客 / 收听 / 设置） | Apple Podcasts Up Next 被认为"密度太低"，iOS 18.4 补课加 widget；Chengbo 4 项是合理的 | **保持不动** |
| 单集列表 | ListTile，密度常规 | 长按菜单 + 行尾笔记入口（喜马拉雅、网易云均验证） | **中** |
| 首页「继续收听」 | 收听 tab 有 resume 卡片 | iOS 18.4 widget 验证：跳过 tab 直达是有效路径 | **中**（依赖 widget 改造） |
| 首页信息密度 | 列表为主 | 「continue + 订阅 + 发现」三段式已被大量国内 app 验证，但 Chengbo 设计规则禁「卡片堆」 | **不抄**，等用户提需求 |
| 单手可达性 | 底栏 + 迷你条都在底部 ≈60% 屏幕 | 拇指热区证据强烈支持底部交互；顶部应只放必要 info | **守住现状** |
| 大屏 / Fold | 未明确支持 | Spotify 2026-04 把 fold/tablet 做成右侧常驻 Now Playing + 主区 | **低**（Windows 已覆盖大屏） |

---

## 一、研究方法

四个轴并行检索 + 浅读：

1. **国内同类移动端**：小宇宙、网易云音乐、Apple Music 中文版（避开复古收音机那一脉）
2. **国际优秀播客/电台**：Pocket Casts（2026 Liquid Glass 改造）、Spotify（2025-26 歌词 + 大屏）、Apple Podcasts（iOS 18.x → 26）
3. **Android 原生音频控件**：MediaSession / NotificationCompat.MediaStyle / 锁屏 / 小组件 / MediaStyle 在 Android 14-15 的现状
4. **单手操作 / 拇指热区**：实测数据 + UX 经验总结

> 注：小宇宙部分材料来自第三方介绍页，不是官方文档；具体细节以官方为准。Chengbo 的真实痛点应回到自己的 telemetry + 用户反馈。

---

## 二、关键发现

### A. Pocket Casts 2026（iOS Liquid Glass 改造，2026-06）

来源：[Pocket Casts meets Liquid Glass](https://blog.pocketcasts.com/2026/06/11/liquid-glass)

**做了什么：**
- mini player 从独立浮条 → 「Liquid Glass accessory attached to the tab bar」，滚动时与 tab bar 一起收拢成紧凑胶囊
- mini player 内显示 **episode title + 精确剩余时间**
- 「Up Next」tab 图标运行时绘制：队列计数从玻璃胶囊中"挖空"，与 tab 着色一致并实时更新
- 添加单集有动画：封面被"拉"进 tab
- 多选模式：tab bar 和 mini player 一起隐藏 → 给多选 footer 完整底部空间
- 自定义 dialog → 改用系统原生 alert；自定义 bottom card → 系统 sheet

**对 Chengbo 的启示（边界）：**
- ✅ mini player 与 tab bar **联动收拢**：滚动时缩小，可加垂直空间给列表——但 Chengbo 现在是反过来（mini player 永远在底，列表在它上面），所以"联动"主要体现在滚动状态切换（紧凑 → 完整），不是真的合并
- ✅ mini player 加上"精确剩余时间"是低成本高收益：现在只有台名 + 副文
- ✅ Up Next tab 计数 badge 是验证过的细节，Chengbo 收听 tab 已有"最近"可以借鉴
- ⚠️ Liquid Glass 是 iOS-only，Chengbo Android + Windows 不能直接抄；精神可学（半透明 + 滚动联动）
- ⚠️ 滚动联动要注意：若 Chengbo mini player 真随滚动收拢，会和"播放中 = 唯一浮起的石"的设计语言冲突；建议**只改密度不改形态**

### B. Spotify Now Playing 歌词化（2025-26）

来源：[Spotify Now Shows Live Lyrics](https://www.amoverview.com/?p=5108), [Spotify tablets & foldables redesign](https://lite.dailyadvent.com/detail/352e5737260417en_ng)

**做了什么：**
- 歌词从 swipe-up 抽屉 → **inline on Now Playing**，紧贴封面下方
- 当前行加粗 + 高亮；上/下行淡出
- 服务端推送（不需要 app 更新）
- 三点菜单可关掉歌词，回退到传统极简视图
- 大屏/fold 改造：右侧常驻 Now Playing 面板，主区浏览，可展开全屏

**对 Chengbo 的启示：**
- ❌ 歌词 Chengbo 没有源数据，不抄
- ✅ **核心精神**：在 NP 里多承担一层信息，让用户少一次跳转
- Chengbo 的 NP 现在有：封面、标题、副标题、控制行。可加但不勉强：
  - **章节名**（已有 chapters support，只是视觉不显）—— 已在 ROADMAP 待做
  - **正在收听节目标签**（IC 芯片，显示当前是播客还是电台 + 节目名）—— 当前显示的是 ICY 曲名，但播客场景下信息密度不够
- ✅ 「关掉就回极简」的可选机制，是验证过的设计哲学：给愿意"重"的用户加密度，给"轻"的用户保留原貌

### C. Apple Podcasts（iOS 18.2 → iOS 18.4 → iOS 26）

来源：[iOS 18.2 improves Apple Podcasts](https://9to5mac.com/2024/12/10/ios-182-improves-apples-podcasts-app-but-my-biggest-complaint-is-unchanged/), [Widgets in iOS 18.4](https://undercodenews.com/apple-podcasts-in-ios-184-new-widgets-for-a-smoother-listening-experience/), [Favorite Categories iOS 18.2](https://podcasters.apple.com/support/5490-news-categories-ios18), [iOS 26 Podcasts guide](https://www.macrumors.com/guide/apple-podcasts)

**做了什么：**
- **iOS 18.2**：新增 Favorite Categories 个性化（Home / Search / Library 联动）；Search 改个性化
- **iOS 18.4**：补 **Library widget**（Saved / Downloaded / Latest Episodes 三档可配）+ Shows widget（XL for iPad）—— 用户从 widget 直达最新单集，**绕过 Up Next 的密度问题**
- **iOS 26**：Liquid Glass 整 App；章节从进度条拖动跳转；倍速细分到 0.25–3×；Enhance Dialogue 语音增强

**对 Chengbo 的启示（强）：**
- ✅ **widget 是 Chengbo 应该重做的关键面**。现在 Android widget「标题 + 播放/暂停 + 续播 + 下一台」已有，但触发动作语义、Latest Episodes 模式、Material You 动态色都还可以再加
- ✅ **绕过 Up Next 这条思路**：Apple 被吐槽"Up Next 密度太低，必须进去才发现有 N 个未听"；Chengbo 的"未听 inbox"也存在类似问题——可以让 Android widget 直接显示"最近 4 个未听单集"
- ✅ 倍速 0.25/0.3 这类细分档，Chengbo 当前是 0.5/0.6/0.8/1/1.25/1.5/2；除非用户反馈强烈，不必扩档
- ⚠️ Enhance Dialogue（语音增强）—— 与「不做均衡器/音量增强」路线冲突；**不抄**
- ⚠️ Categories 个性化是刀尖向自己：Chengbo 用分类做首屏筛选，已经隐含个性化，再加一层会冗余

### D. 小宇宙

来源：[小宇宙产品分析](https://www.toutiao.com/a7493726068541604364)，[小宇宙 APP 介绍](http://www.nipaoa.com/app/147654.html)

**做了什么：**
- 标签页**只有 3 个**（发现 / 订阅 / 我的）—— 把工具属性推到二级页
- **高能点赞 + 柱状进度条**：听众点赞多 → 进度条对应位置柱状图越高，直观显示热门片段
- **评论时间戳跳转**：评论带时间戳，点击跳到对应片段
- 节目详情页**字体与按钮颜色随节目 LOGO 动态变化**
- 创作工具内置（录音 + 多轨编辑 + 降噪 + 发布）—— 不在 Chengbo 范围内
- 评论区"主播领航员互动"

**对 Chengbo 的启示（边界）：**
- ❌ 高能进度条依赖社交数据；Chengbo 不做社交，**不抄**
- ❌ 评论时间戳同样依赖社区，**不抄**
- ❌ 节目详情页主题色随 LOGO 变化：Chengbo 设计原则已禁（"Placeholder-Not-Brand Rule" + seed-driven）
- ✅ **3 个 tab 的精简**：Chengbo 4 个 tab 是合理（电台 / 播客 / 收听 / 设置 4 个目的地语义清晰），不需要合并
- ✅ 把工具属性推到二级页的精神值得学习：Chengbo 设置项已经分层，「外观 / 播放 / 电台管理 / 数据管理」是正确方向
- ⚠️ 极简但蓝白配色 + 自定义主题色 —— 已被 Chengbo 设计语言包含（Material 3 + 种子色），不必额外借鉴

### E. Android MediaSession 通知 / 锁屏

来源：[How to show music on lock screen](https://www.clrn.org/how-to-show-music-on-lock-screen-android/), [ExoPlayer 后台播放指南](https://blog.csdn.net/gitblog_00033/article/details/152710310)

**关键事实：**
- `MediaSessionCompat`（API 21+） + `NotificationCompat.MediaStyle` 是标准做法
- **Android 8.0+ 必须有通知渠道**（CHANNEL_ID）
- 长时间后台播放需要 **前台服务 + `startForegroundService()`**
- 必须正确管理 **Audio Focus**，否则会和别的音频源打架
- 支持蓝牙硬件按键 + 远程控制（耳机上一首/下一首）
- Custom actions 可加：收藏、加入队列、字幕等
- **通知封面不要用 favicon** —— ROADMAP 已识别

**对 Chengbo 的启示：**
- 当前实现是否走 `MediaSessionCompat` + `NotificationCompat.MediaStyle`？需要回到代码核验（`local_notifications.dart` / `podcast_playback.dart`）
- 锁屏封面**用台标 / 节目封面优先**，没有时回退到 station artwork 签名（不是 favicon）
- Android 14+ Material You 大图标可动态染色 —— 是 Material 3 expressive 方向

### F. 单手操作 / 拇指热区

来源：[Thumb-Friendly Design](https://618media.com/en/blog/thumb-friendly-design-optimizing-for-mobile), [手小适合多大屏幕](https://www.sina.cn/news/article/comos_niryquy7953892.html), [Where Your Thumb Can't Reach](https://netwebmedia.com/blog/thumb-zone-button-placement-mobile-forms.html)

**关键事实：**
- 屏幕底部 1/3 ~ 1/2 是拇指舒适区
- 顶部边角单手最难触达，常需换握
- 触控目标建议 **≥48dp**
- FAB 放右下或中下
- 主要操作可在底部固定（粘性元素）
- 卡片可滑动（Tinder 风格）减少触达需求
- 6.1–6.3 英寸 + 宽度 ≤72mm + 重量 ≤180g 是单手黄金区间

**对 Chengbo 的启示：**
- ✅ Chengbo 现状：底栏 + 迷你条都在屏幕底部 ≈60% 区域，**正中下怀**
- ✅ 主操作（播放）放在迷你条右侧的 44dp Filled IconButton，符合触控规范
- ⚠️ 设置页顶部返回箭头 + 标题是「必要」不能去，但应避免把任何**主操作**放在右上角或顶部边角
- ⚠️ 长按菜单（电台行 / 单集行）已经验证，**保持现状**
- ⚠️ 滑动操作（已支持：迷你条左右滑切台/跳秒）已实现，**保持现状**

---

## 三、对照 A–E 五个方向的落点

| 方向 | 与研究证据的关系 | 关键落点 |
|---|---|---|
| **A. 把"静水电波"做深** | 与所有发现都不冲突，是地基级 | 字距、分割线、迷你条 highlight 描边、空状态文案 |
| **B. Now Playing 重做** | 强证据：Spotify 验证"在 NP 里加信息"；Pocket Casts 验证"mini player 改内容物" | 章节名显示在 NP 进度条上方；控制行用 Spacer+flex 重排；mini player 加精确剩余时间 |
| **C. 桌面端深耕** | 与本移动端研究弱相关；可在 Windows 单独做 | （不在本文件范围） |
| **D. 氛围包四套皮肤** | 与移动端研究弱相关 | 字体温度、状态色变体可参照小宇宙/Pocket Casts 的暗色主题细节 |
| **E. 沉静式主屏** | 谨慎：Apple Podcasts Up Next 验证"低密度可能失败"；小宇宙也走 3 tab 而非 3 段卡片 | 若做，必须严守"卡片间距 ≤16、列表仍是主体"；或干脆只加"继续收听"横向卡片，不引入多段 |

---

## 四、跨切面建议（按 ROI 排）

**P0（必须做，证据最强）：**
1. **Android 通知 / 锁屏封面**：用 station / episode artwork，不用 favicon.ico（ROADMAP 已有）
2. **mini player 加精确剩余时间**：电台显示「00:42:18」已播/总时长（若 ICY 给元数据），播客显示「剩余 03:24」；是 Pocket Casts 2026 验证的低成本改进
3. **widget 重做**：增加 Material You 动态色 + Latest Episodes 模式（参照 iOS 18.4）

**P1（可做，证据中性）：**
4. **Now Playing 章节名显示**（已有 chapters 支持）
5. **设置页右上角避免放主操作**（拇指热区证据）
6. **mini player 与 tab bar 滚动联动**（参考 Pocket Casts，但严守"石的形态不变"）

**P2（暂缓）：**
7. Now Playing 加更多信息（被禁的项目要逐一论证）
8. 主屏加「继续收听」卡片 —— 等用户反馈驱动

**P3（不建议做）：**
- 高能进度条、评论时间戳（要做社交）
- Enhance Dialogue（已禁均衡器/音频增强）
- 节目详情页主题色随 LOGO（已禁）

---

## 五、语义边界与风险（提交任何补丁前自查）

按用户偏好「先自查边界情况」逐项列：

1. **mini player 加剩余时间**
   - 电台：ICY 不给时长怎么显示？→ 退化为 "直播中" 或 "缓冲中 + 累计时长"
   - 播客：超过 24h 的节目怎么显示？→ `01:23:45` 不要塞不下，用 `≥1d` 退化
   - 暂停态显示「已暂停 00:42:18」还是「剩余」？→ 选「剩余」（更接近"我还要听多久"的语义）

2. **widget Latest Episodes 模式**
   - 4 个最新单集从哪个订阅取？→ 仅限用户订阅的播客，且必须有 cover
   - 单集正在播放和 widget 显示最新不冲突？→ 正在播放不进入 widget 的 Latest 列表，避免重复
   - 是否消耗流量刷新？→ 与现有"6 小时最低间隔"对齐

3. **Now Playing 章节名**
   - 章节名过长截断策略？→ `Ellipsis` 1 行，下方副标题仍显示完整章节时间码
   - 无章节时怎么显示？→ 不显示，避免留白
   - 与 ICY 曲名冲突？→ 播客显示章节名，电台显示 ICY 曲名，不混

4. **mini player 与 tab bar 滚动联动**
   - 正在播放时滚动会不会失去控制？→ 仅缩小不收起，永远保留播放键
   - 列表为空时联动会不会闪？→ 空列表不联动

5. **字体收紧 / 字距**
   - 中文小字号字距收紧会拥挤 → 仅在 ≥titleLarge 字号做，body/label 不动

---

## 六、不做的事（重申 DESIGN.md + 本研究联合 ban）

- 复古收音机 / 调频刻度 / 拟物旋钮
- Cupertino 控件 / Windows Fluent 分叉
- 高能进度条 / 评论时间戳（社交）
- 节目详情页主题色随 LOGO
- 实时均衡器 / 音量增强 / Enhance Dialogue
- 卡片堆瀑布首页
- 歌词 inline（无源数据）
- Liquid Glass 半透明材质的视觉风格（Chengbo 不走 iOS 平台语言）

---

## 七、变更记录

| 日期 | 版本 | 变更 |
|---|---|---|
| 2026-09-22 | 0.1 | 初稿。研究输入，未到方案阶段 |

---

## 八、待补 / 下一步

- [ ] 回到 `lib/core/platform/local_notifications.dart` 和 `lib/core/audio/podcast_playback.dart`，核验 MediaSession 实现现状
- [ ] 拿到 Chengbo 真实使用数据（哪几个屏幕停留时间最长 / mini player 触发频次）来佐证 mini player 重做的 ROI
- [ ] 用户回看方向 A / B / E 中的哪个，再开新文档落地为「方案计划」（不是研究）
