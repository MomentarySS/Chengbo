# 中文成人向音频 / Podcast RSS

给澄波维护者用的**人工清单**：集合站、节目地址、内容说明、核对状态。

- 须满 18 岁。
- **不是**应用内目录。澄波不预装、不做「成人专区」、不做推荐榜。产品约定见 [SOURCES.md](SOURCES.md) 第 6 节。
- 只记**公开 RSS**（或明确标成发现-only）。不拆喜马拉雅 / 蜻蜓 / Spotify 私有播放地址。
- 核对日期：2026-08-16。失效后用第 2 节集合站重查 `feedUrl`。
- 清单不收以 BL / 耽美 / 男男为核心的节目。入库前看简介和最近几集标题，不要只看「女性向」四个字。

听：播客页粘贴 RSS。设置里的 Podcast Index 默认滤 explicit，要听成人向先关掉过滤。澄波 1.1.1 起，Windows 拉 SoundOn 等境外 RSS 走系统代理，并探测本机 Clash 常见端口。

---

## 1. 状态与字段

不要只存节目名。一条源至少：

```json
{
  "title": "【女性向】秘密日記",
  "language": "zh",
  "explicit": true,
  "category": "erotic_audio",
  "source_type": "podcast_rss",
  "rss_url": "https://feed.firstory.me/rss/user/ckf0zxee8rw490839m0gz57ae",
  "status": "verified",
  "rights": "unknown",
  "last_verified": "2026-08-16"
}
```

| status          | 含义                                           |
| --------------- | ---------------------------------------------- |
| `verified`      | GET 能打开 RSS，且至少 1 条 `<enclosure>` 音频 |
| `discovered`    | 目录里看得到节目，还没有稳定公开 RSS           |
| `broken`        | RSS 在，但没有 enclosure / 音频播不了          |
| `dead`          | 停更或 Feed 失效                               |
| `blocked`       | 作者公布了 RSS，本机请求被拒（如 HTTP 402）    |
| `manual_review` | 版权或内容需要人工看，不要当默认源             |

播放器真正用的是 enclosure，不是 Apple / Spotify 网页：

```
RSS → item → enclosure url → HEAD/GET → 加入播放队列
```

文档里的分类（小说 / 情色音频 / 谈话 / 科普）只方便维护，**不要做成应用里的成人频道树**。喜马拉雅 album XML、只有 Apple 页没有 enclosure 的节目不进本清单。

---

## 2. 集合站（只当搜索）

没有「中文成人播客总站」。能批量拿到 `feedUrl` 的是这些：

| 集合站                                                       | 入口                                                                            | 怎么拿到 RSS                                   |
| ------------------------------------------------------------ | ------------------------------------------------------------------------------- | ---------------------------------------------- |
| iTunes Search API                                            | `https://itunes.apple.com/search?term=關鍵詞&media=podcast&country=tw&limit=25` | 结果里的 `feedUrl`                             |
| iTunes lookup                                                | `https://itunes.apple.com/lookup?id={collectionId}&entity=podcast`              | 同上                                           |
| [Podcast Index](https://podcastindex.org/)                   | 网页搜；API `search/byterm`（关掉 `clean=1`）                                   | 节目页 Feed URL。澄波设置里已接                |
| [Listen Notes](https://www.listennotes.com/)                 | 搜中文节目名                                                                    | 再拿 Apple id 走 lookup                        |
| [Firstory](https://firstory.me/zh)                           | 创作者主页 → Platforms                                                          | `https://feed.firstory.me/rss/user/{userId}`   |
| [SoundOn](https://www.soundon.fm/)                           | `https://player.soundon.fm/p/{uuid}`                                            | `https://feeds.soundon.fm/podcasts/{uuid}.xml` |
| 小宇宙公开 RSS                                               | 创作者若开启对外订阅                                                            | `https://feed.xyzfm.space/{slug}`              |
| [Podscan](https://podscan.fm/) / [Grep.FM](https://grep.fm/) | 搜节目名                                                                        | 看托管商，再回原站抄 RSS                       |

关键词：`性愛` `Sex Chat` `女性向` `ASMR` `乙女` `男友音` `性教育` `親密關係` `愛愛`。排除：`BL` `耽美` `男男` `腐向`。

RSS 长什么样：`.../feed`、`feed.firstory.me/rss/user/...`、`feeds.soundon.fm/podcasts/{uuid}.xml`、`feeds.captivate.fm/{slug}/`、`feed.xyzfm.space/...`。浏览器打开能看到 `<item>`。不是 App 分享短链。

---

## 3. 总表

| 节目                             | 分类     | 内容                             | RSS                                                                          | 状态          | 集数（约）          |
| -------------------------------- | -------- | -------------------------------- | ---------------------------------------------------------------------------- | ------------- | ------------------- |
| 【女性向】秘密日記               | 情色音频 | 男友 RP / 情欲故事，公开多为试听 | `https://feed.firstory.me/rss/user/ckf0zxee8rw490839m0gz57ae`                | verified      | 270                 |
| 長毛象邦邦【女性向成人asmr】     | 情色音频 | 男友音 / 情境 ASMR，部分会员     | `https://feed.firstory.me/rss/user/clu2hsput1dsr01w14x0x0lxh`                | verified      | 66                  |
| 大人的晚安故事                   | 情色音频 | 女性向 ASMR，会员墙后有完整档    | `https://feed.firstory.me/rss/user/cmlw3vmzl03zi01z19fw2dght`                | verified      | 32                  |
| 香水百合的親密電話               | 情色音频 | 陪伴系 ASMR，全性向              | `https://feeds.soundon.fm/podcasts/4354edf3-f3c5-4eb5-aee4-a0b6ab20ff32.xml` | verified      | 48                  |
| 步非烟asmr                       | 情色音频 | Firstory 原创音声（ling389）     | `https://feed.firstory.me/rss/user/ckqi6uc7m9oe00930cgqefz37`                | verified      | 195                 |
| 實用色素                         | 情色音频 | 女性向成人音声                   | `https://feed.firstory.me/rss/user/ckzxyheh815pk0886klenhsf8`                | verified      | 16                  |
| CV小喵喵 ASMR                    | 情色音频 | 奶狗男友等，几乎停更             | `https://feed.firstory.me/rss/user/ckir1x7xgnnqn0807m5wrqetx`                | verified      | 1                   |
| 女性向音频（有声恋人）           | 情色音频 | 乙女 / 男友音，2021 停更         | `https://feeds.redcircle.com/4282576a-eaf9-40de-b19c-7bdd054d1943`           | manual_review | 312                 |
| 暗液喃聲                         | 情色音频 | 喃声 / RP                        | `https://anchor.fm/s/10ce02420/podcast/rss`                                  | verified      | —                   |
| Sex Chat 談性說愛                | 谈话     | 听众投稿性爱故事                 | `https://feed.firstory.me/rss/user/cjyqpf4a72q6v0743tfjdxhbg`                | verified      | 580+                |
| 海鮮CHILL CHILL 愛愛特調         | 谈话     | 不遮脸性爱对谈                   | `https://feeds.soundon.fm/podcasts/b5000f83-e6a0-4d89-8974-4efc88a2a21a.xml` | verified      | 240+                |
| 慾望琦姬                         | 谈话     | 情欲话题对谈                     | `https://feed.firstory.me/rss/user/cl9k4ebqr01uf01uz86dzdkce`                | verified      | 310+                |
| Shout Out Sex                    | 谈话     | 性与爱访谈                       | `https://feed.firstory.me/rss/user/ckaccvb0y972r0873zcrki0u1`                | verified      | 340                 |
| 性愛誠引                         | 谈话     | 性爱谈话，explicit               | `https://feeds.soundon.fm/podcasts/c895d5c8-0b23-48a1-9a6f-3523e62ea349.xml` | verified      | 590                 |
| GOSH                             | 谈话     | 台湾性爱闲聊                     | `https://feed.firstory.me/rss/user/ckiuki7w83bfr08999hl3so7p`                | verified      | 220                 |
| Peggy Fo Show                    | 谈话     | 同类谈话                         | `https://feed.firstory.me/rss/user/clsbl44tc09l601utgv00hqo7`                | verified      | 130                 |
| 三交製作                         | 谈话     | 情色闲聊 / 喜剧                  | `https://feeds.soundon.fm/podcasts/7a1705f2-d2d7-4b54-8fcc-d6d11a610671.xml` | verified      | 200                 |
| 非必要不                         | 谈话     | 开放关系                         | `https://anchor.fm/s/dec34ea0/podcast/rss`                                   | verified      | 12                  |
| 婊酱 / 鸟声鸟气 FM               | 谈话     | 大陆情欲访谈                     | `https://biaojiangfm.typlog.io/episodes/feed.xml`                            | blocked       | —                   |
| 卡卡老師性教育                   | 科普     | 性知识 / 女性自主                | `https://feed.firstory.me/rss/user/cknfd4z0tu49m0a49iatwyazf`                | verified      | 155                 |
| 卿聽性教育                       | 科普     | 全年龄段性教育（成人也可听）     | `https://feeds.soundon.fm/podcasts/54266a88-a707-4f23-8580-acf7999b3384.xml` | verified      | 127                 |
| 性諮商特調 Sex Café              | 科普     | 性咨询师对谈                     | `https://feed.firstory.me/rss/user/ckaxgw864zhsa0873oxcdt3ti`                | verified      | 60                  |
| 性事誰人知                       | 科普     | 泌尿科医生谈性                   | `https://feeds.soundon.fm/podcasts/8254a835-f157-480a-a0b3-a9c52bf5e379.xml` | verified      | 49                  |
| LoveMatters 中文                 | 科普     | 谈性说爱中文网                   | `https://anchor.fm/s/e76988d0/podcast/rss`                                   | verified      | 41                  |
| 呂如中談情說愛                   | 科普     | 情感 / 亲密关系                  | `https://feed.firstory.me/rss/user/ckexk9n9oinzg0839ylzibtjn`                | verified      | 370+                |
| 万象更新 Women's Health          | 科普     | 女性健康，偶有亲密关系           | `https://feed.xyzfm.space/7vr4h9dgettq`                                      | verified      | 206                 |
| 当个事儿                         | 科普     | 身体 / 两性单集                  | `https://feed.xyzfm.space/myefm33b8n77`                                      | verified      | 243                 |
| 宛平北路600号                    | 科普     | 社会观察里谈性                   | `https://feed.xyzfm.space/h7dxm93ya6vj`                                      | verified      | 106                 |
| 嗨咻                             | 科普     | 关系 / 脑科学                    | `https://feed.xyzfm.space/e864f8kmynb9`                                      | verified      | 102                 |
| 药不能停                         | 科普     | 女性身体与亲密                   | `https://feed.xyzfm.space/9lhwdlgl7vk4`                                      | verified      | 72                  |
| Captivate `chengxu*` 马甲        | 小说搬运 | 笔趣阁署名，版权不清             | `https://feeds.captivate.fm/chengxu308/` 等                                  | manual_review | 数十到上百          |

---

## 4. 情色小说 / 朗读

### 4.1 Captivate「笔趣阁」批量号 — manual_review

Spotify / Apple 上最容易搜到的中文 H 小说，**不是 Spotify 自制**。有人把网文朗读传到 [Captivate](https://www.captivate.fm/)，再分发到目录。

- 作者栏几乎都写「笔趣阁」
- 简介互相复制
- 节目名带 `。。`、`(私密)`、`(打手枪)`、`(限制)`
- RSS：`https://feeds.captivate.fm/chengxuNNN/`

已核仍活（有 enclosure）：

| 马甲                           | RSS                                      | 集数 |
| ------------------------------ | ---------------------------------------- | ---- |
| 欲火成人情色小说精读。。(私密) | `https://feeds.captivate.fm/chengxu308/` | 88   |
| 步非烟情色小说合集。。(私密)   | `https://feeds.captivate.fm/chengxu296/` | 93   |

Spotify 例：[黄色小说故事会剧场](https://open.spotify.com/show/7m7aMDF2bb5W5UkNK25gRT)、[成人18禁小说精读](https://open.spotify.com/show/4oPiaLz0jiItvjZhzEygNJ)。

版权来源不清。用户自己贴可以播；**不要写进默认目录**，也不要去拆笔趣阁网页。

从 Spotify 反查：记下节目名 → iTunes search → 看 `feedUrl` 主机名。有声书（Audiobook）没有播客 RSS，订不了。

---

## 5. 情色音频 / ASMR

公开 RSS 多为试听。完整 R18 常在 Firstory 会员或 Patreon 后，澄波订不了付费墙。点心工作室 / 步非烟付费站没有公开 RSS，不接。

| 节目               | 内容                   | RSS                                                                          | 备注                                                                                   |
| ------------------ | ---------------------- | ---------------------------------------------------------------------------- | -------------------------------------------------------------------------------------- |
| 【女性向】秘密日記 | 情欲故事、男友 RP      | `https://feed.firstory.me/rss/user/ckf0zxee8rw490839m0gz57ae`                | Apple `1531608148`。完整档 Patreon                                                     |
| 長毛象邦邦         | 女性向成人 ASMR / 男友音 | `https://feed.firstory.me/rss/user/clu2hsput1dsr01w14x0x0lxh`                | Apple `1637335353`。2025-05 起订阅制，公开 RSS 仍有 66 条 enclosure                    |
| CV小喵喵 ASMR      | 奶狗男友等短音声       | `https://feed.firstory.me/rss/user/ckir1x7xgnnqn0807m5wrqetx`                | Apple `1545290206`。仅 1 集，当不了主源                                                |
| 女性向音频（有声恋人） | 乙女向 / 催眠 / 男友音 | `https://feeds.redcircle.com/4282576a-eaf9-40de-b19c-7bdd054d1943`           | Apple `1583739317`。312 集有 enclosure，作者栏写笔趣阁，2021-11 停更，`manual_review` |
| 大人的晚安故事     | 女性向 ASMR / 深夜剧情 | `https://feed.firstory.me/rss/user/cmlw3vmzl03zi01z19fw2dght`                | Apple `1526360048`                                                                     |
| 香水百合的親密電話 | 陪伴、撒娇、色色       | `https://feeds.soundon.fm/podcasts/4354edf3-f3c5-4eb5-aee4-a0b6ab20ff32.xml` | Apple `1738272783`                                                                     |
| 步非烟asmr         | 成人有声 / ASMR        | `https://feed.firstory.me/rss/user/ckqi6uc7m9oe00930cgqefz37`                | Spotify [4goO9bHBYZ57wPCjW0DzOr](https://open.spotify.com/show/4goO9bHBYZ57wPCjW0DzOr) |
| 實用色素           | 女性向成人音声         | `https://feed.firstory.me/rss/user/ckzxyheh815pk0886klenhsf8`                | Spotify [6HuWSkbZPqxLfC0gs4d5ny](https://open.spotify.com/show/6HuWSkbZPqxLfC0gs4d5ny) |
| 暗液喃聲           | 喃声、NTR 等 RP        | `https://anchor.fm/s/10ce02420/podcast/rss`                                  | Spotify [4d2o0GDWbo2gjnFBfqQSsP](https://open.spotify.com/show/4d2o0GDWbo2gjnFBfqQSsP) |

---

## 6. 谈话向

尺度开，对谈 / 投稿 / 床事经验。台湾 Firstory / SoundOn 最多。

| 节目                      | 内容                   | RSS                                                                          | Apple / 备注 |
| ------------------------- | ---------------------- | ---------------------------------------------------------------------------- | ------------ |
| Sex Chat 談性說愛         | 听众投稿性爱故事、技巧 | `https://feed.firstory.me/rss/user/cjyqpf4a72q6v0743tfjdxhbg`                | `1460651216` |
| 海鮮CHILL CHILL 愛愛特調  | 生理到实战，不遮脸     | `https://feeds.soundon.fm/podcasts/b5000f83-e6a0-4d89-8974-4efc88a2a21a.xml` | `1526444576` |
| 慾望琦姬                  | 情欲作家对谈           | `https://feed.firstory.me/rss/user/cl9k4ebqr01uf01uz86dzdkce`                | `1653128997` |
| Shout Out Sex \| 無性不談 | 性与爱访谈             | `https://feed.firstory.me/rss/user/ckaccvb0y972r0873zcrki0u1`                | `1514053882` |
| 性愛誠引                  | 性爱谈话               | `https://feeds.soundon.fm/podcasts/c895d5c8-0b23-48a1-9a6f-3523e62ea349.xml` | `1547115698` |
| GOSH                      | 台湾性爱闲聊           | `https://feed.firstory.me/rss/user/ckiuki7w83bfr08999hl3so7p`                | `1534481431` |
| Peggy Fo Show             | 同类谈话               | `https://feed.firstory.me/rss/user/clsbl44tc09l601utgv00hqo7`                | `1729749924` |
| 三交製作                  | 情色闲聊 / 喜剧        | `https://feeds.soundon.fm/podcasts/7a1705f2-d2d7-4b54-8fcc-d6d11a610671.xml` | `1707366669` |
| 非必要不                  | 开放关系               | `https://anchor.fm/s/dec34ea0/podcast/rss`                                   | `1681617106` |

婊酱 / 鸟声鸟气：**先留着，等后续再核。** 作者公布 `https://biaojiangfm.typlog.io/episodes/feed.xml`（301 到 `/feed/audio.xml`），说明页 https://biaojiangfm.typlog.io/2020/20200807 。2026-08-16 本机 **HTTP 402**，澄波现在订不了。Feed 恢复后再改状态，不要拆小宇宙网页。

---

## 7. 科普向

性教育、性健康、亲密关系。多数**不是**整档成人向，只是有相关单集。澄波按整份 Feed 订。

| 节目                    | 内容                       | RSS                                                                          | 备注                                 |
| ----------------------- | -------------------------- | ---------------------------------------------------------------------------- | ------------------------------------ |
| 卡卡老師性教育          | 性知识、女性自主、避孕     | `https://feed.firstory.me/rss/user/cknfd4z0tu49m0a49iatwyazf`                | Apple `1562790775`                   |
| 卿聽性教育              | 亲密关系、性沟通、长者需求 | `https://feeds.soundon.fm/podcasts/54266a88-a707-4f23-8580-acf7999b3384.xml` | `1589369330`                         |
| 性諮商特調 Sex Café     | 性咨询师坐诊               | `https://feed.firstory.me/rss/user/ckaxgw864zhsa0873oxcdt3ti`                | `1516423600`                         |
| 性事誰人知              | 泌尿科医生谈性             | `https://feeds.soundon.fm/podcasts/8254a835-f157-480a-a0b3-a9c52bf5e379.xml` | `1752279667`                         |
| LoveMatters 中文        | 生殖健康 / 亲密关系        | `https://anchor.fm/s/e76988d0/podcast/rss`                                   | [matters.love](https://matters.love) |
| 呂如中談情說愛          | 情感谈话                   | `https://feed.firstory.me/rss/user/ckexk9n9oinzg0839ylzibtjn`                | `1531439955`                         |
| 万象更新 Women's Health | 女性健康 + 亲密关系专访    | `https://feed.xyzfm.space/7vr4h9dgettq`                                      | 小宇宙公开 RSS                       |
| 当个事儿                | 身体、避孕、两性谎言等单集 | `https://feed.xyzfm.space/myefm33b8n77`                                      | 同上                                 |
| 宛平北路600号           | 「性贫困」、无性婚姻等     | `https://feed.xyzfm.space/h7dxm93ya6vj`                                      | 同上                                 |
| 嗨咻                    | 关系、脑科学               | `https://feed.xyzfm.space/e864f8kmynb9`                                      | 同上                                 |
| 药不能停                | 女性身体感受、亲密         | `https://feed.xyzfm.space/9lhwdlgl7vk4`                                      | 同上                                 |

---

## 8. 澄波怎么用

1. 精选 JSON、Radio Browser 默认查询都不收成人台；**收听范围**只过滤精选 JSON 与发现层，不替用户决定内容偏好。`CatalogContentPolicy` 会丢掉带成人标签的发现台。
2. 用户手动添加电台、播客页粘贴 RSS：不受上述过滤。
3. 本文件只给维护者找地址。不要预装、不要做应用内成人分类。
4. 商店：国内 Android 与 Google Play 对色情目录都敏感。默认列表带上成人源，审核风险远大于多几个台。
5. 版权：订阅并从原始 enclosure 播放，和缓存转码、再托管、公开聚合不是同一回事。Captivate「笔趣阁」号尤其不要当官方内容库。
