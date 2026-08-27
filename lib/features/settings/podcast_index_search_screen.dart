import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/network/network_status.dart';
import '../../core/network/podcast_index.dart';
import '../../core/network/podcast_index_client.dart';
import '../../core/providers/app_providers.dart';
import '../../core/theme.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/station_artwork.dart';
import '../podcast/podcast_providers.dart';

class PodcastIndexSearchScreen extends ConsumerStatefulWidget {
  const PodcastIndexSearchScreen({super.key});

  @override
  ConsumerState<PodcastIndexSearchScreen> createState() =>
      _PodcastIndexSearchScreenState();
}

class _PodcastIndexSearchScreenState extends ConsumerState<PodcastIndexSearchScreen> {
  final _queryController = TextEditingController();
  final _keyController = TextEditingController();
  final _secretController = TextEditingController();
  var _searching = false;
  var _subscribingUrl = '';
  String? _error;
  List<PodcastIndexHit> _hits = const [];

  @override
  void dispose() {
    _queryController.dispose();
    _keyController.dispose();
    _secretController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _queryController.text.trim();
    if (query.isEmpty || _searching) return;
    final settings = ref.read(podcastIndexSettingsProvider).value;
    if (settings == null || !settings.hasCredentials) {
      setState(() => _error = '请先填写 Podcast Index 的 API Key 和 Secret');
      return;
    }
    if (await ref.read(networkMonitorProvider).isOffline) {
      if (!mounted) return;
      setState(() => _error = NetworkStatusLogic.banner);
      return;
    }
    setState(() {
      _searching = true;
      _error = null;
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
        _hits = hits;
        _error = hits.isEmpty ? '没有找到匹配的公开 RSS' : null;
      });
    } on PodcastIndexAuthException {
      if (!mounted) return;
      setState(() {
        _searching = false;
        _error = '请先填写 Podcast Index 的 API Key 和 Secret';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _searching = false;
        _error = '搜索失败，请检查密钥或稍后再试';
      });
    }
  }

  Future<void> _subscribe(PodcastIndexHit hit) async {
    if (_subscribingUrl.isNotEmpty) return;
    setState(() => _subscribingUrl = hit.feedUrl);
    try {
      final feed = await ref.read(subscribedFeedsProvider.notifier).subscribeFromUrl(
            feedUrl: hit.feedUrl,
            title: hit.title,
            homepage: hit.homepage,
            imageUrl: hit.artworkUrl,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已订阅「${feed.title}」')),
      );
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
      appBar: AppBar(title: const Text('搜索播客')),
      body: settings.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => AppEmptyState(
          icon: Icons.error_outline,
          message: '无法读取密钥',
          detail: '$error',
        ),
        data: (value) {
          if (_keyController.text.isEmpty && value.apiKey.isNotEmpty) {
            _keyController.text = value.apiKey;
          }
          if (_secretController.text.isEmpty && value.apiSecret.isNotEmpty) {
            _secretController.text = value.apiSecret;
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              Text(
                '只在设置里提供。结果是公开 RSS，订阅后仍走澄波自己的播放器。默认不显示标了 explicit 的节目。',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 12),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: const Text('API 密钥'),
                subtitle: Text(value.hasCredentials ? '已保存到本机' : '免费申请后填在这里'),
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
                        onPressed: () => _openDocs(context),
                        child: const Text('去申请密钥'),
                      ),
                      const Spacer(),
                      FilledButton(
                        onPressed: _saveKeys,
                        child: const Text('保存'),
                      ),
                    ],
                  ),
                ],
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('隐藏不适宜内容'),
                subtitle: const Text('默认打开，对应 Podcast Index 的 explicit'),
                value: value.hideExplicit,
                onChanged: (hide) =>
                    ref.read(podcastIndexSettingsProvider.notifier).setHideExplicit(hide),
              ),
              const SizedBox(height: 8),
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
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 8),
              for (final hit in _hits)
                ListTile(
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
                      if (hit.explicit) '可能含不适宜内容',
                      hit.feedUrl,
                    ].join(' · '),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: subscribedUrls.contains(hit.feedUrl)
                      ? const Text('已订阅')
                      : _subscribingUrl == hit.feedUrl
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : TextButton(
                              onPressed: () => _subscribe(hit),
                              child: const Text('订阅'),
                            ),
                ),
              const SizedBox(height: ChengboTheme.listBottomPadding),
            ],
          );
        },
      ),
    );
  }

  Future<void> _openDocs(BuildContext context) async {
    final uri = Uri.parse('https://api.podcastindex.org/');
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('无法打开申请页')),
      );
    }
  }
}
