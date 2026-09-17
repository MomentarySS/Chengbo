import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/audio/podcast_download.dart';
import '../../core/brand.dart';
import '../../core/providers/app_providers.dart';
import '../../core/storage/artwork_cache_service.dart';
import '../../core/storage/device_backup.dart';
import '../podcast/podcast_providers.dart';
import 'podcast_downloads_screen.dart';

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

  var _exportingBackup = false;
  var _restoringBackup = false;

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

  Future<void> _exportBackup() async {
    setState(() => _exportingBackup = true);
    try {
      final storage = await ref.read(appStorageProvider.future);
      final json = DeviceBackupLogic.encode(
        prefs: storage.snapshotForBackup(),
        podcastState: await storage.snapshotPodcastEpisodeStateForBackup(),
        exportedAt: DateTime.now(),
        appVersion: AppBrand.version,
      );
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().toIso8601String().replaceAll(RegExp(r'[:.]'), '-');
      final file = File('${tempDir.path}/chengbo-backup-$timestamp.json');
      await file.writeAsString(json, flush: true);
      if (!mounted) return;
      await Share.shareXFiles(
        [XFile(file.path)],
        text: '澄波本机备份',
        subject: 'chengbo-backup-$timestamp.json',
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('导出失败: $error')));
    } finally {
      if (mounted) setState(() => _exportingBackup = false);
    }
  }

  Future<void> _restoreBackup() async {
    final data = await Clipboard.getData('text/plain');
    final decoded = DeviceBackupLogic.decode(data?.text ?? '');
    if (!decoded.isOk) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(decoded.error ?? '剪贴板里没有备份')),
      );
      return;
    }
    if (!mounted) return;
    final backup = decoded.backup!;
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('恢复本机备份'),
            content: Text(
              '将覆盖本机的收藏、订阅、进度、隐藏台、收听范围和外观偏好（${backup.keyCount} 项）。'
              '不含已下载音频和 Podcast Index 密钥。恢复后请完全退出再打开。',
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
              FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('恢复')),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !mounted) return;
    setState(() => _restoringBackup = true);
    try {
      final storage = await ref.read(appStorageProvider.future);
      await storage.restoreBackup(backup);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已恢复。请完全退出澄波后再打开')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('恢复失败: $error')));
    } finally {
      if (mounted) setState(() => _restoringBackup = false);
    }
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
              _cacheBytes == null ? '正在计算…' : '已占用 ${ArtworkCacheService.formatBytes(_cacheBytes!)}',
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
                  : '已占用 ${PodcastDownloadLogic.formatBytes(podcastDownloads.totalBytes)} · 点开查看清单',
            ),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const PodcastDownloadsScreen()),
            ),
            trailing: _clearingPodcasts
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                : TextButton(
                    onPressed: podcastDownloads.records.isEmpty ? null : _confirmClearPodcastDownloads,
                    child: const Text('清除'),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
            child: Text(
              '换机',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.file_upload_outlined),
            title: const Text('导出本机备份'),
            subtitle: const Text('收藏、订阅、进度、隐藏台、收听范围；不含直播和已下载音频'),
            trailing: _exportingBackup
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                : TextButton(onPressed: _exportBackup, child: const Text('导出')),
          ),
          ListTile(
            leading: const Icon(Icons.file_download_outlined),
            title: const Text('从剪贴板恢复'),
            subtitle: const Text('覆盖本机数据；恢复后请完全退出再打开'),
            trailing: _restoringBackup
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                : TextButton(onPressed: _restoreBackup, child: const Text('恢复')),
          ),
        ],
      ),
    );
  }
}
