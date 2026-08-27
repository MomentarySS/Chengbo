# 澄波收录源对接

给 Chengbo（澄波）用的目录与订阅源清单。只对接**公开直播流**和**公开 RSS**，不对接喜马拉雅 / 蜻蜓 / 小宇宙等版权点播库。

产品原则见 [PRODUCT.md](PRODUCT.md)：可播优先于数量；默认国内精选；发现层可关；播客不预装。

---

## 1. 澄波现在怎么收源

合并顺序（`StationRepository` + 设置里的手动台）：

1. **手动添加** — 本机 SharedPreferences，设置页创建 / 编辑 / 剪贴板 JSON
2. **本地精选** — `assets/stations_cn.json`，约 413 个已测流（2026-08-19 重建：蜻蜓省市级 + 央广官方 + 广东本地补充）
3. **Radio Browser** — 默认开；按用户在「收听范围」里选的省份（及「全部精选」时的完整查询）并行拉；`countrycode=CN`，另含投票、`news`/`music`/`traffic`/`新闻`/`音乐`/`交通`、中文/普通话语言；TW/HK/MO 另拉（列表里仍要打开「显示境外电台」才出现）。同名跳过。语言查询不限 CN，但合并时丢掉新加坡等其它国家，不当成全球目录。

播客：应用内粘贴 RSS，`PodcastService` 抓标题/封面/单集。不读打包默认订阅。

**首次启动**会弹出全屏「选择想听的电台」：勾选类型和/或省份（并集），或「加载全部精选」；**无默认预选**，至少选一项后才能开始检测。旧版若已在设置里选过加载范围，升级后不重复引导。

| 源 | 代码入口 | 列表标注 |
| --- | --- | --- |
| 手动台 | 设置 → 电台管理 → 手动添加电台 | 来源：手动添加 |
| 精选 JSON | `CuratedStationsRepository` + `StationCatalogSelectionLogic.apply()` | 不标注 |
| Radio Browser | `RadioBrowserClient.fetchChinaCatalog(selection: …)` | 来源：网络发现 |
| 用户 RSS | `PodcastService.fetchFeed()` | 播客页订阅 |

确认收听范围后（或设置「电台管理 → 检测可播放的源」/下拉刷新）会并行探测直播 URL，并把能播的 id 记在本机；之后按这份名单播放。不能播的从主页隐藏，进设置「电台管理」更换地址。修改「收听范围」会重置并重探测。「刷新电台列表」只更新目录，不重测。境外台（港澳台）默认隐藏，设置「电台管理」打开后排在境内后面。央广香港之声、CRI 仍算境内。

---

## 2. 能对接、不能对接

**能对接**

- 公开 HTTP(S) 直播：`.m3u8` / `.mp3` / AAC，无短期 `t=` / `key=` token
- 公开 RSS 2.0（可带 iTunes / Podcasting 2.0 扩展）
- 社区目录 API：Radio Browser、Podcast Index（只取元数据 + 流/Feed 地址）

**不能对接**

- 喜马拉雅、蜻蜓 FM、荔枝、网易云、QQ 音乐、小宇宙的站内点播库（需官方授权）
- 需要登录、DRM、付费墙的音频
- 把直播整段录成文件（产品禁止）

国内平台可以当**听众发现入口**，不能当澄波的默认目录后端。用户若从这些平台拿到公开 RSS，可自己在播客页粘贴。

---

## 3. 电台源（直播）

### 3.1 已接：Radio Browser

- 文档：<https://docs.radio-browser.info/>
- 镜像发现：`https://all.api.radio-browser.info/json/servers`
- 回退：`de1` / `fi1` / `nl1`
- 现用查询：投票 / 新闻 / 音乐 / 交通 / `language=chinese|mandarin` / 约 20 个省份 / `countrycode=TW|HK|MO`；`hidebroken=true&order=votes`。语言结果只保留 CN/TW/HK/MO。
- User-Agent：`Chengbo/1.4.7 (Flutter; chengbo radio)`
- 数据许可：目录元数据按 Radio Browser 声明为公共域；音频版权仍在各台

后续可加、但不要写进默认精选：

| 查询 | 用途 | 现状 |
| --- | --- | --- |
| `language=chinese` / `language=mandarin` | 补中文台，不限 CN，合并时只留 CN/TW/HK/MO | 已做 |
| `countrycode=TW\|HK\|MO` | 仅在「显示境外电台」打开时出现在列表 | 已做 |
| `tag=traffic` / `tag=交通` | 交通台 | 已做 |
| `tag=adult` 等 | 见第 6 节与 [ADULT_SOURCES.md](ADULT_SOURCES.md)，默认不要拉 | 不做 |

点击播放可继续打 `GET /json/url/{stationuuid}`（已有 `reportClick`）。

### 3.2 可人工采编进 `stations_cn.json`

优先写稳定、能过连通性探测的国内台。字段约定：

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

测流必须看正文，不能只看 HTTP 200：

```powershell
curl.exe -sL --compressed --max-time 12 -A "Chengbo/1.4.7 (Flutter; chengbo radio)" "流地址"
```

探测语义与 App 一致：普通 GET 优先（等价真实播放），Range 仅兜底；响应带 gzip 压缩先解压再判断。HLS 正文要有 `#EXTM3U` 和至少一条非注释地址。JSON / HTML 即使 200 也不入库。精选 JSON **宁缺毋滥**：坏台删除，不要用未核对的源凑数量。批量导入脚本只用于找替换，不用于把目录堆大。

`200` / `206` 一般可用。重建精选列表：`tools/rebuild_curated_stations.py`（蜻蜓 / 央广 / tingfm / radio5 四源收集 + 探测 + 去重，缓存于 `tools/_scrape_cache/`）；清理死链：`tools/prune_dead_stations.py`。改 JSON 后必须完全重启 App。

已对接的精选来源（2026-08-19 重建）：

| 来源 | 入口 | 说明 |
| --- | --- | --- |
| 蜻蜓 FM 直播页 | <https://www.qtfm.cn/radiopage/217/1> | GraphQL `POST webbff.qtfm.cn/www`，`radioPage(cid, page){contents}` 按 31 省拉频道；流地址 `https://lhttp.qtfm.cn/live/{id}/64k.mp3`（已实测稳定，无短期 token） |
| 央广网电台页 | <https://www.radio.cn/pc-portal/erji/radioStation.html> | 签名 API `ytmsout.radio.cn/web/appBroadcast/list`（MD5 sign，key 从前端 js 取）；19 套央广官方频率（ytlive 签名 m3u8，实测长效） |
| tingfm | <https://tingfm.net/> | `wp-json/query/wnd_posts` 列台 + `query/wndt_streams` 取流；港澳台/网络台补充源，目标站限流时跳过 |
| radio5 | <https://radio5.cn/fm/radio-type> | `/api/play/play/{id}` 取流（ytcast2 签名）；发现/对照用，play 接口对单 IP 有限流 |

可参考的公开直播入口（人工核对后再写入，不要整站爬进精选）：

| 来源 | 地址 | 怎么用 |
| --- | --- | --- |
| 央广网 / 云听公开页 | <https://www.cnr.cn/> | 个别频道有公开 HLS，写入前测活 |
| 各省台官网「在线收听」 | 各台站点 | 优先无 token 的 m3u8 |
| RadioTune 式列表 | <https://www.radiotune.fm/> | 底层多半是 Radio Browser，可用 `tools/import_radiotune_stations.py` 对照，不要当唯一真相 |
| TuneIn 网页 | <https://tunein.com/> | 可发现，流地址常变，不适合当精选主源 |

### 3.3 不要当默认后端的电台目录

| 平台 | 原因 |
| --- | --- |
| TuneIn / iHeart / Amazon Music | 目录可用，流常走 CDN 鉴权，不稳定 |
| 喜马拉雅直播页 | 页面有听，直链常带签名，易失效且有版权风险；不作精选主源 |
| 商业聚合 App 的私有 API | 未授权、易封、和「公开流播放器」定位冲突 |

蜻蜓 FM 的直播直链（`lhttp.qtfm.cn/live/{id}/64k.mp3`）在 2026-08 重建中经两轮探测验证稳定，已列为精选主源；其 radiopage 页面直链带签名、易失效，不作为长期存储格式。

用户自己有稳定 URL，走手动添加即可。精选或发现台后来失效时，也可在客户端「更换地址」，覆盖只存在本机；稳定替换仍应写回 `stations_cn.json`。

---

## 4. 播客源（RSS）

澄波只认 Feed 地址。对接目录的目标是：**给用户可粘贴的 RSS**，以及设置里已接的「搜索 → 一键订阅」，而不是预装订阅列表。

### 4.1 已接能力

- 用户粘贴 `http(s)://...xml` / `.../feed`
- 解析 `channel/title`、封面、`item` 音频 enclosure
- 简介取 `content:encoded` / `itunes:summary` / `description` 最长一段
- 剪贴板导入 / 导出 OPML（`outline xmlUrl`，含嵌套文件夹）
- 设置里的 Podcast Index 搜索（`search/byterm`，默认 `clean=1`）；密钥本机保存，播客页不展示入口
- 「新一集通知」默认关；打开后最少隔 6 小时拉已订阅 RSS，首次只记最新 guid
- 不自带默认 Feed（旧设备会清掉曾经预装的央广网 / RTHK）

RSS 最低要求：公网可打开、至少 1 集、enclosure 是音频 URL。

### 4.2 适合做「搜索/导入」的免费目录

按澄波适配程度排序。上架费均为免费；有的 API 要申请 key。

| 目录 | 提交 / API | 适配澄波 | 说明 |
| --- | --- | --- | --- |
| [Podcast Index](https://podcastindex.org/) | [Add Feed](https://podcastindex.org/add)、[API](https://api.podcastindex.org/developer_docs) | **首选发现层** | 开放、可搜中文、有 `explicit` 字段；可下载全库 SQLite |
| [Listen Notes](https://www.listennotes.com/) | [提交](https://www.listennotes.com/zh-hans/submit/)、Listen API | 搜索体验好 | 免费档有配额；适合「帮用户找 RSS」 |
| [Apple Podcasts](https://podcastsconnect.apple.com/) | 创作者提交 RSS；目录可被第三方引用 | 只作索引 | 很多中文节目在这里；澄波不要解析 Apple 私有播放地址 |
| [Podchaser](https://www.podchaser.com/) | 站内 Add Podcast | 可选 | 资料库 / 评论，不是播放后端 |
| [Pocket Casts](https://pocketcasts.com/submit) | 提交 RSS 或 Apple 链接 | 不必接 | 听众端；提交后用户仍用原 RSS |
| [Castbox](https://castbox.fm/creator/channels) | Creator Studio 认领 | 不必接 | 同上 |
| [Podcast Addict](https://podcastaddict.com/submit) | 提交 RSS | 不必接 | 同上 |

国内听众常用、但**不要当 API 后端**：

| 平台 | 对澄波的用法 |
| --- | --- |
| 小宇宙 | 创作者后台可导出 RSS（形如 `https://feed.xyzfm.space/...`）。用户把该地址贴进澄波即可。不要爬小宇宙网页当目录。 |
| Apple 播客 | 节目页有 RSS 时让用户复制；或先上 Podcast Index / Listen Notes 再取 feed。 |
| 网易云 / QQ 音乐 | 部分节目有 RSS 入驻；没有公开 Feed 的不要硬接。 |
| 喜马拉雅 / 荔枝 | 个别账号在「Apple 播客托管」里有 RSS；没有就当版权库，不接。 |

华语托管（用户从那边拿到 RSS 再订阅）：[Firstory](https://firstory.me/zh)、[声湃](https://wav.pub/)、[SoundOn](https://www.soundon.fm/)、[RSS.com](https://rss.com/)。

听众发现入口（只用来找节目名，再回原站或 iTunes `feedUrl` 抄 RSS；不要当澄波 API 后端）：

| 集合站 | 地址 | 怎么用 |
| --- | --- | --- |
| GetPodcast | <https://getpodcast.xyz/> | 把小宇宙节目转成可订阅 RSS；站点有 Cloudflare，应用内不要爬 |
| 小宇宙排行榜 | <https://xyzrank.com/> | 看热度与分类，再去创作者页或 Podcast Index 拿 Feed |
| Typlog 中文独立播客 | <https://typlog.com/podlist/> | 独立节目目录；多数自带 `…/feed/audio.xml` 或 `…/episodes/feed.xml` |
| Chinese-Podcasts | <https://github.com/alaskasquirrel/Chinese-Podcasts> | 人工索引。里面大量 `rsshub.app/xiaoyuzhou`、`ximalaya.com/album/*.xml`，那些不要贴进澄波 |

### 4.3 播客发现（已接一层）

只接 Podcast Index，入口在设置，不进播客页：

1. `search/byterm`（默认 `clean=1`）
2. 结果只保存 `url`（RSS）到本机订阅，播放仍走 `PodcastService`
3. 默认过滤 explicit；设置里可关
4. 中文检索可搜节目名；不要预装热门榜
5. API Key / Secret 由用户申请后填在搜索页，只存在本机

Listen Notes 适合做备选搜索，注意 API 配额和商标展示要求。

### 4.4 可粘贴的公开 RSS（睡前 / 新闻 / 粤语 / 科技 / 鬼故事）

给维护者和听众抄进播客页用。**不预装、不做应用内推荐榜。**

核对：2026-08-18。User-Agent `Chengbo/1.4.6` 拉取 Feed，要求 HTTP 200、至少 1 条 `<enclosure>` 音频。来源是 iTunes `feedUrl`、节目官网，以及创作者自己打开的 `feed.xyzfm.fm`。Windows 拉境外 Feed 走系统代理，并探测本机 Clash 常见端口。

没写进表的：`rsshub.app`、喜马拉雅 `album/*.xml`、荔枝 `rss.lizhi.fm`（版权库转接，不是作者公开 Feed）。《读首诗再睡觉》《睡前消息》《试当真》当时找不到稳定公开 RSS，故不收录。港台电台空壳（如 RTHK《視點31》《Naked Cantonese》items=0）也不写。

听：播客页粘贴 RSS，或设置里 Podcast Index 搜节目名后一键订阅。

| 分类 | 节目 | 说明 | RSS | 集数（约） |
| --- | --- | --- | --- | --- |
| 睡前 | 故事FM | 用别人的声音讲故事 | `https://feeds.storyfm.cn/storyfm.xml` | 983 |
| 睡前 | 不丧 | 夜间文化闲谈 | `https://busangpodcast.com/feed/audio.xml` | 188 |
| 睡前 | 得意忘形 | 深夜谈话 | `https://feed.xyzfm.space/klaak6nmc3ux` | 74 |
| 睡前 | 无聊斋 | 故事与闲聊，适合伴睡 | `https://feed.xyzfm.space/njwyhpcjqn9t` | 605 |
| 睡前 | 新增一首詩 | 读诗；接近「读首诗再睡觉」 | `https://feeds.soundon.fm/podcasts/6f24d404-1505-4307-bceb-1d65a04a2078.xml` | 84 |
| 睡前 | 睡前短资讯 | 短讯，听完再睡 | `https://feed.xyzfm.space/rkue48tfd8yk` | 170 |
| 睡前 | SLEEP with Elena | 催眠师陪睡（国语） | `https://feeds.soundon.fm/podcasts/d1f3b2ca-769c-431e-9100-371a883a54c2.xml` | 47 |
| 新闻 | 声东击西 | 时事与国际观察 | `https://feeds.fireside.fm/shengdongjixi/rss` | 426 |
| 新闻 | 声动早咖啡 | 商业科技轻解读 | `https://feeds.fireside.fm/sheng-espresso/rss` | 370 |
| 新闻 | 新闻酸菜馆 | 聊新闻、寻开心 | `https://wzzgg.com/feed/wasai` | 70 |
| 新闻 | 东谈西论 | 《联合早报》国际时事 | `https://www.omnycontent.com/d/playlist/d9486183-3dd4-4ad6-aebe-a4c1008455d5/d14a562d-2c6f-465d-80d2-ae44009af53e/77c8885e-9b24-4fb4-a01c-ae44009bc0f1/podcast.rss` | 210 |
| 新闻 | 端聞 | 端传媒新闻播客 | `https://feeds.acast.com/public/shows/66b07190af99592b5329f43a` | 259 |
| 新闻 | 实验室 Newslab | 新闻实验室 | `https://feed.xyzfm.space/xxkgbvrglujv` | 54 |
| 粤语 | 好青年荼毒室 | 香港哲学清谈 | `https://anchor.fm/s/3f94b8a0/podcast/rss` | 100 |
| 粤语 | 港識多史 | 香港历史社会 | `https://anchor.fm/s/10568fa50/podcast/rss` | 219 |
| 粤语 | 香港不是大商场 | 香港城市观察 | `https://feeds.fireside.fm/curiouspodcast/rss` | 13 |
| 粤语 | 講東講西 | 香港电台时事 | `https://podcast.rthk.hk/podcast/Free_as_the_wind.xml` | 40 |
| 粤语 | 古今風雲人物 | 香港电台人物 | `https://podcast.rthk.hk/podcast/people.xml` | 6 |
| 粤语 | One Night Talk | 温哥华广东话夜谈 | `https://anchor.fm/s/f54a63ac/podcast/rss` | 1084 |
| 科技 | 内核恐慌 | IT 硬核闲聊 | `https://pan.icu/feed` | 72 |
| 科技 | 硅谷101 | 科技与创投 | `https://feeds.fireside.fm/sv101/rss` | 257 |
| 科技 | 科技乱炖 | 津津乐道科技点评 | `https://feeds.daopub.com/ld.xml` | 213 |
| 科技 | What's Next｜科技早知道 | 科技新闻评论 | `https://feeds.fireside.fm/guiguzaozhidao/rss` | 426 |
| 科技 | 枫言枫语 | 科技与人文 | `https://justinyan.me/feed/podcast` | 170 |
| 科技 | 牛油果烤面包 | 硅谷视角聊科技 | `https://avocadotoast.typlog.io/feed/audio.xml` | 153 |
| 科技 | 乱翻书 | 科技与商业访谈 | `https://feed.xyzfm.space/yxuruh3f9mc4` | 278 |
| 科技 | 少数派播客 | 效率与数码 | `https://sspai.typlog.io/feed/audio.xml` | 154 |
| 鬼故事 | 怪談深淵 | 长篇怪谈与心理恐怖 | `https://feed.firstory.me/rss/user/cmd7n060l00e401w659nwhk51` | 27 |
| 鬼故事 | 米娜怪談朗讀 | 听众投稿与各国怪谈朗读 | `https://feed.firstory.me/rss/user/ckh9gh5i09wlz0892wkgf0hnb` | 85 |
| 鬼故事 | 台灣鬼故事-靈異麵攤 | 都市传说与真实灵异 | `https://feed.firstory.me/rss/user/cleebhwcn00b101v32735gux1` | 42 |
| 鬼故事 | 棉被先蓋好 | 电梯、出租车一类短篇怪谈 | `https://feed.firstory.me/rss/user/cmlmbk95o03rr01wn50eeerw1` | 14 |
| 鬼故事 | 馬麗莎的黑盒子 | 都市传说与惊悚短篇 | `https://anchor.fm/s/1122840c0/podcast/rss` | 14 |
| 鬼故事 | 幽語夜話的深夜怪談 | 日本怪谈睡前向 | `https://feeds.soundon.fm/podcasts/d3f6656c-070b-4c04-9885-b8a6e2830aa7.xml` | 10 |
| 鬼故事 | 陳為民的鬼王怪談 | 台湾灵异见闻，集数多 | `https://feeds.soundon.fm/podcasts/e0f0197c-ec4e-43ed-9642-3193f59f7f99.xml` | 113 |
| 鬼故事 | 馬修靈異怪談鬼故 | 广东话香港鬼故，宜睡前 | `https://anchor.fm/s/31f11b1c/podcast/rss` | 190 |
| 鬼故事 | 談鬼說怪 | 广东话，茅山师傅闲聊灵异 | `https://rss.buzzsprout.com/2231784.rss` | 175 |
| 鬼故事 | 灵异特辑 | 每期一个短篇，声湃托管 | `https://s1.proxy.wavpub.com/yeeloklytj.xml` | 147 |
| 鬼故事 | 岛语奇谈 | 灵异、悬疑、奇人异事 | `https://feed.xyzfm.space/vxb9prbtkwc3` | 115 |
| 鬼故事 | 睡前鬼故事 | 把鬼故事放慢，当白噪音 | `https://feeds.megaphone.fm/DDAIM2144283639` | 17 |

大陆「民间鬼故事」「九黎怪谈」「零点诡话」「坊间奇谈」等在 Apple 上能搜到，Feed 几乎全是 `ximalaya.com/album/*.xml`，澄波不收。GitHub Chinese-Podcasts 里的 `rsshub.app/xiaoyuzhou` 也不要贴。

同批测过、能播、但没挤进上表（需要时再补）：Anyway.FM `https://Anyway.FM/rss.xml`、捕蛇者说 `https://pythonhunter.org/feed/audio.xml`、二分电台 `https://binary.2bab.me/episodes/feed.xml`、日谈物语 `https://feed.xyzfm.space/87x9n4x77fpy`、天才捕手FM `https://s1.proxy.wavpub.com/storyhunting.xml`、大範的怪談酒館 `https://feed.firstory.me/rss/user/cml2420zl066i012mcqm81ff2`、鬼眼妹妹 `https://feed.firstory.me/rss/user/ckxlaq2fmaz670810gpp1lagg`。

失效后：用第 4.2 节集合站或 iTunes Search `feedUrl` 重查，不要用 RSSHub 顶上。

---

## 5. 推荐落地顺序

| 优先级 | 做什么 | 现状 |
| --- | --- | --- |
| P0 | 精选 JSON 测活、替换失效国内流 | 已有流程 |
| P0 | 用户手动台 + 用户 RSS | 已做 |
| P1 | Radio Browser 保持可关；境外开关与 CN 查询分离 | 已做 |
| P4 | 记住上次收听（不自动播）、播客播完下一集 | 已做 |
| P4 | 播客 OPML 导入导出；添加台认 M3U/PLS；详情复制/分享流地址 | 已做 |
| P5 | 播客搜索：Podcast Index → 一键订阅 RSS（默认滤 explicit） | 已做，只在设置里 |
| P5 | 摇一摇延长睡眠、ICY 跑马灯、Android 小组件、新一集通知、Chromecast | 已做 |
| P5 | Radio Browser 按语言/省份再补；仍不去重版权库 | 已做；只留 CN/TW/HK/MO |
| 不做 | 预装成人台、预装商业点播、预装默认播客榜 | 产品禁止 |

---

## 6. 网上有没有成人台？

有。主要在**境外互联网电台和公开 RSS**里，不是国内省级广播的正式频道。

**节目地址、内容说明、核对状态**只维护在 [ADULT_SOURCES.md](ADULT_SOURCES.md)，不要再往本文件堆 RSS 表。旧稿 `中文成人向音频_Podcast_RSS清单.md` 已并入那一份。

### 6.1 电台

[Radio Browser](https://www.radio-browser.info/) 能搜到 `tag=adult` / `erotic` / `sensual`。不要写进默认 `fetchChinaCatalog`：

```
GET /json/stations/search?tag=adult&hidebroken=true&order=votes
```

中国大陆**没有**可写入 `stations_cn.json` 的官方成人频率。港澳台 / 境外中文网台若有，走现有「显示境外电台」开关。

### 6.2 播客

公开 RSS 里成人谈话、性教育、情色音频、小说朗读都有，标记是 `<itunes:explicit>`。没有官方「中文成人播客总站」。大陆 App 会审；能稳定订的多在 Firstory / SoundOn / Anchor / Captivate。

听：播客页贴 RSS。Podcast Index 搜索默认滤 explicit，要听成人向先关掉。集合站和节目表见 [ADULT_SOURCES.md](ADULT_SOURCES.md)。

### 6.3 澄波怎么处理（约定）

1. **精选 JSON 不收录**成人向直播台。2026-08 核对 `assets/stations_cn.json`：分类只有央广 / 地方台 / 音乐 / 新闻。唯一命中 “love” 的是「上海Love Radio」，不是成人台。
2. **Radio Browser 默认查询不加** `adult` / `erotic`。拉取后仍用 `CatalogContentPolicy` 丢掉带成人标签或站名的条目。用户手动添加不受此过滤。
3. **不要做「成人」分类或预装榜。** 用户有公开流或公开 RSS，自行添加即可。
4. Podcast Index 搜索只在设置里：默认排除 `explicit`，搜索页可关。
5. 商店：国内 Android、Google Play 对色情目录都敏感。默认列表带上成人源，审核风险远大于多几个台。
6. 只播用户或公开目录给出的流/RSS；不爬付费站、不绕过登录、不收录违法内容。

一句话：**网上有成人台和成人播客；澄波只当通用播放器，清单放在 ADULT_SOURCES.md，不做成收录源。**
