import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/models/podcast.dart';
import '../../core/network/network_status.dart';
import '../../core/network/podcast_feed_logic.dart';
import '../../core/podcast/podcast_opml.dart';
import '../../core/theme.dart';
import 'podcast_index_search_screen.dart';
import '../podcast/podcast_providers.dart';

/// 播客管理：添加 RSS、导入/导出 OPML、查看订阅数量。
class PodcastManagementScreen extends ConsumerStatefulWidget {
  const PodcastManagementScreen({super.key});

  @override
  ConsumerState<PodcastManagementScreen> createState() => _PodcastManagementScreenState();
}

class _PodcastManagementScreenState extends ConsumerState<PodcastManagementScreen> {
  bool _adding = false;

  Future<void> _showAddFeedDialog() async {
    final draft = await showDialog<_FeedDraft>(
      context: context,
      builder: (context) => const _AddFeedDialog(),
    );
    if (draft == null || draft.url.isEmpty) return;
    if (!mounted) return;

    setState(() => _adding = true);
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(const SnackBar(content: Text('正在读取 RSS…')));

    final feed = PodcastFeed(
      id: const Uuid().v4(),
      title: draft.title.isEmpty ? '自定义播客' : draft.title,
      feedUrl: draft.url,
    );
    try {
      final detail = await ref.read(podcastServiceProvider).fetchFeed(feed);
      await ref.read(subscribedFeedsProvider.notifier).addFeed(
            PodcastFeed(
              id: feed.id,
              title: draft.title.isEmpty ? detail.feed.title : draft.title,
              feedUrl: detail.feed.feedUrl,
              description: detail.feed.description,
              homepage: detail.feed.homepage,
              imageUrl: detail.feed.imageUrl,
            ),
          );
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(content: Text('已订阅「${draft.title.isEmpty ? detail.feed.title : draft.title}」')),
      );
    } catch (error) {
      final fallback = _subscribeFallbackMessage(error);
      await ref.read(subscribedFeedsProvider.notifier).addFeed(feed);
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(SnackBar(content: Text(fallback)));
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  Future<void> _importOpml() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final parsed = PodcastOpml.decode(data?.text ?? '');
    if (!mounted) return;
    if (parsed == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('剪贴板里没有可导入的 OPML')),
      );
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(const SnackBar(content: Text('正在导入 OPML…')));
    final result = await ref.read(subscribedFeedsProvider.notifier).importOpml(parsed);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(content: Text('导入完成：新增 ${result.added} 个，跳过 ${result.skipped} 个')),
    );
  }

  Future<void> _exportOpml() async {
    final feeds = ref.read(subscribedFeedsProvider).value ?? [];
    if (feeds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('还没有可导出的订阅')),
      );
      return;
    }
    await Clipboard.setData(ClipboardData(text: PodcastOpml.encode(feeds)));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已复制 ${feeds.length} 个订阅的 OPML')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final feedsAsync = ref.watch(subscribedFeedsProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('播客管理')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: ChengboTheme.listBottomPadding),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              '订阅',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          feedsAsync.when(
            data: (feeds) {
              final count = feeds.length;
              return ListTile(
                leading: const Icon(Icons.podcasts_outlined),
                title: const Text('当前订阅'),
                subtitle: Text('共 $count 个订阅'),
              );
            },
            loading: () => const ListTile(
              leading: SizedBox(
                width: 24,
                height: 24,
                child: Padding(
                  padding: EdgeInsets.all(4.0),
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
              title: Text('当前订阅'),
              subtitle: Text('正在加载…'),
            ),
            error: (_, __) => const ListTile(
              leading: Icon(Icons.error_outline),
              title: Text('当前订阅'),
              subtitle: Text('加载失败'),
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.add),
            title: const Text('添加 RSS 订阅'),
            onTap: _adding ? null : _showAddFeedDialog,
          ),
          ListTile(
            leading: const Icon(Icons.file_download_outlined),
            title: const Text('从剪贴板导入 OPML'),
            onTap: _importOpml,
          ),
          ListTile(
            leading: const Icon(Icons.ios_share),
            title: const Text('导出 OPML 到剪贴板'),
            onTap: _exportOpml,
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.search),
            title: const Text('搜索播客（Podcast Index）'),
            subtitle: const Text('只在设置里提供。用公开目录找 RSS，再订阅到本机'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const PodcastIndexSearchScreen(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _subscribeFallbackMessage(Object error) {
  final detail = NetworkStatusLogic.humanize(error);
  if (error is PodcastFeedException && !error.saveAddress) {
    return detail;
  }
  return '$detail。已先保存地址，打开后可再刷新';
}

class _FeedDraft {
  const _FeedDraft({required this.title, required this.url});

  final String title;
  final String url;
}

/// 添加 RSS 订阅对话框：自行持有并销毁输入控制器，避免退出动画期间
/// 访问已 dispose 的 TextEditingController 导致崩溃。
class _AddFeedDialog extends StatefulWidget {
  const _AddFeedDialog();

  @override
  State<_AddFeedDialog> createState() => _AddFeedDialogState();
}

class _AddFeedDialogState extends State<_AddFeedDialog> {
  final _titleController = TextEditingController();
  final _urlController = TextEditingController();

  @override
  void dispose() {
    _titleController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  void _submit() {
    Navigator.of(context).pop(
      _FeedDraft(
        title: _titleController.text.trim(),
        url: _urlController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('添加 RSS 订阅'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: '播客名称',
              hintText: '可留空，添加后会按 RSS 标题填写',
            ),
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _urlController,
            decoration: const InputDecoration(labelText: 'RSS 地址'),
            keyboardType: TextInputType.url,
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(onPressed: _submit, child: const Text('添加')),
      ],
    );
  }
}
