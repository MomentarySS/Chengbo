import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/audio/podcast_download.dart';
import '../../core/storage/artwork_cache_service.dart';
import '../podcast/podcast_providers.dart';

/// 数据管理：存储方式说明、封面缓存、播客下载。
class DataManagementScreen extends ConsumerStatefulWidget {
  const DataManagementScreen({super.key});

  @override
  ConsumerState<DataManagementScreen> createState() => _DataManagementScreenState();
}

class _DataManagementScreenState extends ConsumerState<DataManagementScreen> {
  int? _cacheBytes;
  bool _clearingCache = false;
  bool _clearingPodcasts = false;

  @override
  void initState() {
    super.initState();
    _loadCacheSize();
  }

  Future<void> _loadCacheSize() async {
    final bytes = await ArtworkCacheService.estimateSizeBytes();
    if (mounted) setState(() => _cacheBytes = bytes);
  }

  Future<void> _confirmClearCache() async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('清除封面缓存'),
            content: const Text('将删除已缓存的电台台标图片，不会影响收藏和播放记录。'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
              FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('清除')),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !mounted) return;
    setState(() => _clearingCache = true);
    await ArtworkCacheService.clear();
    await _loadCacheSize();
    if (!mounted) return;
    setState(() => _clearingCache = false);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('封面缓存已清除')));
  }

  Future<void> _confirmClearPodcastDownloads() async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('清除播客下载'),
            content: const Text('将删除已下载的播客音频。直播电台本来就不会保存。订阅和播放进度不受影响。'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
              FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('清除')),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !mounted) return;
    setState(() => _clearingPodcasts = true);
    await ref.read(podcastDownloadsProvider.notifier).clearAll();
    if (!mounted) return;
    setState(() => _clearingPodcasts = false);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('播客下载已清除')));
  }

  @override
  Widget build(BuildContext context) {
    final podcastDownloads = ref.watch(podcastDownloadsProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('数据管理')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 96),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              '存储',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          const ListTile(
            leading: Icon(Icons.storage_outlined),
            title: Text('存储方式'),
            subtitle: Text('直播不落盘；播客可按需下载到本机'),
          ),
          ListTile(
            leading: const Icon(Icons.image_outlined),
            title: const Text('封面缓存'),
            subtitle: Text(
              _cacheBytes == null
                  ? '正在计算…'
                  : '已占用 ${ArtworkCacheService.formatBytes(_cacheBytes!)}',
            ),
            trailing: _clearingCache
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                : TextButton(onPressed: _confirmClearCache, child: const Text('清除')),
          ),
          ListTile(
            leading: const Icon(Icons.podcasts_outlined),
            title: const Text('播客下载'),
            subtitle: Text(
              podcastDownloads.records.isEmpty
                  ? '还没有下载单集'
                  : '已占用 ${PodcastDownloadLogic.formatBytes(podcastDownloads.totalBytes)}',
            ),
            trailing: _clearingPodcasts
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                : TextButton(
                    onPressed: podcastDownloads.records.isEmpty ? null : _confirmClearPodcastDownloads,
                    child: const Text('清除'),
                  ),
          ),
        ],
      ),
    );
  }
}