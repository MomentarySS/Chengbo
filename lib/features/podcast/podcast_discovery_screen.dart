import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/network/network_status.dart';
import '../../core/network/podcast_discovery.dart';
import '../../core/network/podcast_catalog.dart';
import '../../core/network/podcast_feed_logic.dart';
import '../../core/network/podcast_index_client.dart';
import '../../core/providers/app_providers.dart';
import '../../core/theme.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/station_artwork.dart';
import 'podcast_providers.dart';

class PodcastDiscoveryScreen extends ConsumerStatefulWidget {
  const PodcastDiscoveryScreen({super.key});

  @override
  ConsumerState<PodcastDiscoveryScreen> createState() => _PodcastDiscoveryScreenState();
}

class _PodcastDiscoveryScreenState extends ConsumerState<PodcastDiscoveryScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _queryController = TextEditingController();
  final _keyController = TextEditingController();
  final _secretController = TextEditingController();

  var _searching = false;
  var _subscribingUrl = '';
  String? _searchError;

  /// 结果来自哪个目录（iTunes / Podcast Index / 本机目录），用来在结果上方标明。
  String? _searchSource;
  List<PodcastDiscoveryHit> _searchHits = const [];

  var _rankLoading = false;
  var _rankLoadingMore = false;
  String? _rankError;
  var _rankTotal = 0;
  List<PodcastDiscoveryHit> _rankHits = const [];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _tabs.addListener(() {
      if (_tabs.index == 1 && _rankHits.isEmpty && !_rankLoading) {
        _loadRank();
      }
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    _queryController.dispose();
    _keyController.dispose();
    _secretController.dispose();
    super.dispose();
  }

  /// 搜索按「覆盖优先、可达性兜底」分两级，并把**真实原因**说出来：
  ///
  /// 1. iTunes —— 覆盖最好，但境内常连不上（实测手机浏览器能开、应用里常失败）；
  /// 2. Podcast Index —— 国内可达（api.podcastindex.org 实测可达），需要免费密钥，
  ///    在「高级：Podcast Index」里填过就自动兜底。
  ///
  /// 两级都不行时，报错要能照做（提示去填密钥），而不是笼统的「搜索失败」。
  Future<void> _search() async {
    final query = _queryController.text.trim();
    if (query.isEmpty || _searching) return;
    if (await ref.read(networkMonitorProvider).isOffline) {
      if (!mounted) return;
      setState(() => _searchError = NetworkStatusLogic.banner);
      return;
    }
    setState(() {
      _searching = true;
      _searchError = null;
      _searchSource = null;
    });

    final hideExplicit = ref.read(podcastIndexSettingsProvider).value?.hideExplicit ?? true;
    Object? itunesError;
    try {
      final hits = await ref.read(itunesPodcastClientProvider).search(
            query: query,
            hideExplicit: hideExplicit,
          );
      if (!mounted) return;
      setState(() {
        _searching = false;
        _searchHits = hits;
        _searchSource = hits.isEmpty ? null : 'iTunes';
        _searchError = hits.isEmpty ? '没有找到匹配的公开 RSS' : null;
      });
      return;
    } catch (error) {
      itunesError = error;
    }

    final settings = ref.read(podcastIndexSettingsProvider).value;
    if (settings != null && settings.hasCredentials) {
      try {
        final hits = await ref.read(podcastIndexClientProvider).search(
              query: query,
              apiKey: settings.apiKey,
              apiSecret: settings.apiSecret,
              hideExplicit: hideExplicit,
            );
        if (!mounted) return;
        setState(() {
          _searching = false;
          _searchHits = [for (final hit in hits) PodcastDiscoveryHit.fromIndex(hit)];
          _searchSource = hits.isEmpty ? null : 'Podcast Index';
          _searchError = hits.isEmpty ? '没有找到匹配的公开 RSS' : null;
        });
        return;
      } catch (_) {
        // 落到下面的统一提示。
      }
    }

    // 3) 本机目录（GetPodcast 精选 + xyzrank 榜单前 1000）：国内直连可拉、零配置。
    //    放在最后，但它不需要任何密钥，是「什么都不配也能搜到东西」的那一级。
    //    目录按需刷新（缓存过期时在应用内拉，见 podcastCatalogProvider）。
    final catalog = await ref.read(podcastCatalogProvider.future);
    final catalogHits = PodcastCatalogLogic.search(catalog, query);
    if (catalogHits.isNotEmpty) {
      if (!mounted) return;
      setState(() {
        _searching = false;
        _searchHits = [for (final entry in catalogHits) entry.toHit()];
        _searchSource = '本机目录（收录 ${catalog.length} 个中文节目）';
        _searchError = null;
      });
      return;
    }

    if (!mounted) return;
    // 走到这里说明 iTunes 一定抛过（只有 catch 会给它赋值）。
    final reason = NetworkStatusLogic.humanize(itunesError);
    final hasKeys = settings != null && settings.hasCredentials;
    setState(() {
      _searching = false;
      _searchHits = const [];
      _searchError = [
        reason,
        if (hasKeys) 'Podcast Index 也没有结果' else 'Podcast Index 未填密钥',
        if (catalog.isEmpty)
          '本机目录也没拉到（网络受限）'
        else
          '本机目录的 ${catalog.length} 个中文节目里没有匹配的',
        if (!hasKeys) '可在下方「高级：Podcast Index」填免费密钥',
      ].join('；');
    });
  }

  Future<void> _searchPodcastIndex() async {
    final query = _queryController.text.trim();
    if (query.isEmpty || _searching) return;
    final settings = ref.read(podcastIndexSettingsProvider).value;
    if (settings == null || !settings.hasCredentials) {
      setState(() => _searchError = '请先填写 Podcast Index 的 API Key 和 Secret');
      return;
    }
    if (await ref.read(networkMonitorProvider).isOffline) {
      if (!mounted) return;
      setState(() => _searchError = NetworkStatusLogic.banner);
      return;
    }
    setState(() {
      _searching = true;
      _searchError = null;
    });
    try {
      final hits = await ref.read(podcastIndexClientProvider).search(
            query: query,
            apiKey: settings.apiKey,
            apiSecret: settings.apiSecret,
            hideExplicit: settings.hideExplicit,
          );
      if (!mounted) return;
      setState(() {
        _searching = false;
        _searchHits = [for (final hit in hits) PodcastDiscoveryHit.fromIndex(hit)];
        _searchError = hits.isEmpty ? '没有找到匹配的公开 RSS' : null;
      });
    } on PodcastIndexAuthException {
      if (!mounted) return;
      setState(() {
        _searching = false;
        _searchError = '请先填写 Podcast Index 的 API Key 和 Secret';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _searching = false;
        _searchError = '搜索失败，请检查密钥或稍后再试';
      });
    }
  }

  Future<void> _loadRank({bool more = false}) async {
    if (_rankLoading || _rankLoadingMore) return;
    if (more && _rankHits.length >= _rankTotal && _rankTotal > 0) return;
    if (await ref.read(networkMonitorProvider).isOffline) {
      if (!mounted) return;
      setState(() => _rankError = NetworkStatusLogic.banner);
      return;
    }
    setState(() {
      if (more) {
        _rankLoadingMore = true;
      } else {
        _rankLoading = true;
        _rankError = null;
      }
    });
    try {
      final page = await ref.read(xyzrankCatalogClientProvider).fetchPodcasts(
            offset: more ? _rankHits.length : 0,
          );
      if (!mounted) return;
      setState(() {
        _rankLoading = false;
        _rankLoadingMore = false;
        _rankTotal = page.total;
        _rankHits = more ? [..._rankHits, ...page.items] : page.items;
        _rankError = _rankHits.isEmpty ? '热榜暂时不可用，请稍后重试' : null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _rankLoading = false;
        _rankLoadingMore = false;
        _rankError = _rankHits.isEmpty ? '热榜加载失败，请稍后重试' : '继续加载失败';
      });
    }
  }

  Future<void> _subscribe(PodcastDiscoveryHit hit) async {
    final url = hit.feedUrl?.trim() ?? '';
    if (!hit.canSubscribe || _subscribingUrl.isNotEmpty) return;
    setState(() => _subscribingUrl = url);
    try {
      final feed = await ref.read(subscribedFeedsProvider.notifier).subscribeFromUrl(
            feedUrl: url,
            title: hit.title,
            homepage: hit.homepage,
            imageUrl: hit.artworkUrl,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已订阅「${feed.title}」')),
      );
    } on PodcastFeedException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('订阅失败，可到播客页手动粘贴 RSS')),
      );
    } finally {
      if (mounted) setState(() => _subscribingUrl = '');
    }
  }

  Future<void> _saveKeys() async {
    await ref.read(podcastIndexSettingsProvider.notifier).saveCredentials(
          apiKey: _keyController.text,
          apiSecret: _secretController.text,
        );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('密钥已保存在本机')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(podcastIndexSettingsProvider);
    final subscribed = ref.watch(subscribedFeedsProvider).value ?? const [];
    final subscribedUrls = {for (final feed in subscribed) feed.feedUrl};

    return Scaffold(
      appBar: AppBar(
        title: const Text('发现播客'),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: '搜索'),
            Tab(text: '中文热榜'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          settings.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => AppEmptyState(
              icon: Icons.error_outline,
              message: '无法读取设置',
              detail: '$error',
            ),
            data: (value) => _buildSearchTab(context, value, subscribedUrls),
          ),
          _buildRankTab(context, subscribedUrls),
        ],
      ),
    );
  }

  Widget _buildSearchTab(
    BuildContext context,
    PodcastIndexSettings settings,
    Set<String> subscribedUrls,
  ) {
    if (_keyController.text.isEmpty && settings.apiKey.isNotEmpty) {
      _keyController.text = settings.apiKey;
    }
    if (_secretController.text.isEmpty && settings.apiSecret.isNotEmpty) {
      _secretController.text = settings.apiSecret;
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Text(
          '默认用 iTunes 搜索公开 RSS，免密钥。结果订阅后仍走澄波自己的播放器。',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _queryController,
          decoration: const InputDecoration(
            labelText: '搜索节目名或关键词',
            hintText: '例如：新闻 中文',
            border: OutlineInputBorder(),
          ),
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => _search(),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _searching ? null : _search,
          icon: _searching
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.search),
          label: const Text('搜索'),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('隐藏不适宜内容'),
          subtitle: const Text('默认打开，对应 explicit / 内容分级'),
          value: settings.hideExplicit,
          onChanged: (hide) =>
              ref.read(podcastIndexSettingsProvider.notifier).setHideExplicit(hide),
        ),
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: const Text('高级：Podcast Index'),
          subtitle: Text(settings.hasCredentials ? '已保存到本机' : '可选，免费申请密钥后用目录再搜一次'),
          children: [
            TextField(
              controller: _keyController,
              decoration: const InputDecoration(
                labelText: 'API Key',
                border: OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _secretController,
              decoration: const InputDecoration(
                labelText: 'API Secret',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                TextButton(
                  onPressed: () => _openUrl(context, 'https://api.podcastindex.org/'),
                  child: const Text('去申请密钥'),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: _saveKeys,
                  child: const Text('保存'),
                ),
              ],
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: _searching ? null : _searchPodcastIndex,
                child: const Text('用 Podcast Index 搜索'),
              ),
            ),
          ],
        ),
        if (_searchError != null) ...[
          const SizedBox(height: 8),
          Text(
            _searchError!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
        if (_searchSource != null && _searchHits.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            '来自 $_searchSource',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
        const SizedBox(height: 8),
        for (final hit in _searchHits)
          _DiscoveryHitTile(
            hit: hit,
            subscribed: subscribedUrls.contains(hit.feedUrl),
            subscribing: _subscribingUrl == hit.feedUrl,
            onSubscribe: () => _subscribe(hit),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: () => _openUrl(context, 'https://getpodcast.xyz/'),
            child: const Text('在浏览器打开 GetPodcast'),
          ),
        ),
        const SizedBox(height: ChengboTheme.listBottomPadding),
      ],
    );
  }

  Widget _buildRankTab(BuildContext context, Set<String> subscribedUrls) {
    if (_rankLoading && _rankHits.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_rankHits.isEmpty) {
      return AppEmptyState(
        icon: Icons.wifi_off,
        message: _rankError ?? '还没有热榜',
        detail: '用户主动浏览才请求 xyzrank，不预装订阅',
        actionLabel: '重试',
        onAction: _loadRank,
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: _rankHits.length + 2,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              '中文热榜来自 xyzrank 公开 JSON，点订阅才写入本机。第三方转接源会标成无法订阅。',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          );
        }
        if (index == _rankHits.length + 1) {
          if (_rankError != null && _rankHits.isNotEmpty) {
            return TextButton(onPressed: () => _loadRank(more: true), child: Text(_rankError!));
          }
          if (_rankHits.length >= _rankTotal && _rankTotal > 0) {
            return const SizedBox(height: ChengboTheme.listBottomPadding);
          }
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: _rankLoadingMore
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : TextButton(
                      onPressed: () => _loadRank(more: true),
                      child: const Text('加载更多'),
                    ),
            ),
          );
        }
        final hit = _rankHits[index - 1];
        return _DiscoveryHitTile(
          hit: hit,
          subscribed: subscribedUrls.contains(hit.feedUrl),
          subscribing: _subscribingUrl == hit.feedUrl,
          onSubscribe: () => _subscribe(hit),
        );
      },
    );
  }

  Future<void> _openUrl(BuildContext context, String url) async {
    final ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('无法打开网页')),
      );
    }
  }
}

class _DiscoveryHitTile extends StatelessWidget {
  const _DiscoveryHitTile({
    required this.hit,
    required this.subscribed,
    required this.subscribing,
    required this.onSubscribe,
  });

  final PodcastDiscoveryHit hit;
  final bool subscribed;
  final bool subscribing;
  final VoidCallback onSubscribe;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    Widget trailing;
    if (!hit.canSubscribe) {
      trailing = Text(
        '无法在澄波订阅',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: colorScheme.error),
      );
    } else if (subscribed) {
      trailing = const Text('已订阅');
    } else if (subscribing) {
      trailing = const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    } else {
      trailing = TextButton(onPressed: onSubscribe, child: const Text('订阅'));
    }

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: StationArtwork(
        url: hit.artworkUrl,
        size: 48,
        icon: Icons.podcasts,
      ),
      title: Text(hit.title),
      subtitle: Text(
        [
          if (hit.author.isNotEmpty) hit.author,
          if (hit.genre.isNotEmpty) hit.genre,
          if (hit.explicit) '可能含不适宜内容',
          if (hit.denied) '第三方转接源',
          if (hit.feedUrl != null) hit.feedUrl!,
        ].join(' · '),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: trailing,
    );
  }
}

class PodcastIndexSearchScreen extends StatelessWidget {
  const PodcastIndexSearchScreen({super.key});

  @override
  Widget build(BuildContext context) => const PodcastDiscoveryScreen();
}
