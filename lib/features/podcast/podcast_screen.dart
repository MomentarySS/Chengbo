import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';

import '../../core/audio/podcast_download.dart';
import '../../core/audio/podcast_playback.dart';
import '../../core/models/podcast.dart';
import '../../core/models/radio_station.dart';
import '../../core/network/network_status.dart';
import '../../core/network/podcast_feed_logic.dart';
import '../../core/podcast/podcast_history.dart';
import '../../core/podcast/podcast_opml.dart';
import '../../core/providers/app_providers.dart';
import '../../core/theme.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/station_artwork.dart';
import 'episode_notes_sheet.dart';
import 'podcast_providers.dart';

String _subscribeFallbackMessage(Object error) {
  final detail = NetworkStatusLogic.humanize(error);
  if (error is PodcastFeedException && !error.saveAddress) {
    return detail;
  }
  return '$detail。已先保存地址，打开后可再刷新';
}

Future<bool> confirmDeletePodcast(BuildContext context, PodcastFeed feed) async {
  return await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('删除播客'),
          content: Text('删除「${feed.title}」？订阅会去掉，已下载的单集也会删掉。'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('删除')),
          ],
        ),
      ) ??
      false;
}

class PodcastScreen extends ConsumerStatefulWidget {
  const PodcastScreen({super.key});

  @override
  ConsumerState<PodcastScreen> createState() => _PodcastScreenState();
}

class _PodcastScreenState extends ConsumerState<PodcastScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final feedsAsync = ref.watch(subscribedFeedsProvider);
    final offline = ref.watch(isOfflineProvider).value ?? false;
    final query = ref.watch(podcastSearchProvider);

    return Column(
      children: [
        if (feedsAsync.value?.isNotEmpty ?? false)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '搜索播客…',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          ref.read(podcastSearchProvider.notifier).state = '';
                        },
                      )
                    : null,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
                ),
              ),
              onChanged: (value) => ref.read(podcastSearchProvider.notifier).state = value,
            ),
          ),
        Expanded(
          child: feedsAsync.when(
            data: (feeds) {
              if (feeds.isEmpty) {
                return AppEmptyState(
                  icon: Icons.podcasts_outlined,
                  message: '还没有订阅播客',
                  detail: '添加公开 RSS，或从剪贴板导入 OPML',
                  actionLabel: '添加 RSS',
                  onAction: () => _showAddFeedDialog(context, ref),
                  secondaryActionLabel: '导入 OPML',
                  onSecondaryAction: () => _importOpml(context, ref),
                );
              }
              final searchIndex = ref.watch(podcastSearchIndexProvider);
              final filtered = query.isEmpty
                  ? feeds
                  : feeds.where((feed) {
                      final title = feed.title.toLowerCase();
                      final q = query.toLowerCase();
                      if (title.contains(q)) return true;
                      final episodeTitles = searchIndex[feed.id];
                      if (episodeTitles != null) {
                        for (final title in episodeTitles) {
                          if (title.contains(q)) return true;
                        }
                      }
                      return false;
                    }).toList();
              if (filtered.isEmpty) {
                return AppEmptyState(
                  icon: Icons.search_off,
                  message: '没有找到「$query」',
                  detail: '试试其他关键词',
                );
              }
              return ResumeAndInboxList(
                feeds: filtered,
                query: query,
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => AppEmptyState(
              icon: offline ? Icons.wifi_off : Icons.error_outline,
              message: NetworkStatusLogic.loadFailureMessage('播客加载失败', offline: offline),
              detail: NetworkStatusLogic.loadFailureDetail(error, offline: offline),
            ),
          ),
        ),
      ],
    );
  }

  static Future<void> _importOpml(BuildContext context, WidgetRef ref) async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final parsed = PodcastOpml.decode(data?.text ?? '');
    if (!context.mounted) return;
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

  static Future<void> _showAddFeedDialog(BuildContext context, WidgetRef ref) async {
    final draft = await showDialog<_FeedDraft>(
      context: context,
      builder: (context) => const _AddFeedDialog(),
    );
    if (draft == null || draft.url.isEmpty) return;
    if (!context.mounted) return;

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
      if (error is! PodcastFeedException || error.saveAddress) {
        await ref.read(subscribedFeedsProvider.notifier).addFeed(feed);
      }
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(content: Text(_subscribeFallbackMessage(error))),
      );
    }
  }
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

class PodcastDetailScreen extends ConsumerWidget {
  const PodcastDetailScreen({super.key, required this.feed});

  final PodcastFeed feed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(podcastDetailProvider(feed));
    final offline = ref.watch(isOfflineProvider).value ?? false;
    final sort = ref.watch(podcastEpisodeSortProvider).value ?? PodcastEpisodeSort.newestFirst;
    ref.listen(podcastDetailProvider(feed), (previous, next) {
      next.whenData((detail) {
        if (!(ref.read(podcastDownloadAllFeedsProvider).value?.contains(feed.id) ?? false)) {
          return;
        }
        ref.read(podcastDownloadsProvider.notifier).downloadAll(detail.feed, detail.episodes);
      });
    });
    return Scaffold(
      appBar: AppBar(
        title: Text(feed.title),
        actions: [
          ref.watch(hideListenedEpisodesProvider).when(
                data: (hide) => IconButton(
                  tooltip: hide ? '显示已听完' : '隐藏已听完',
                  icon: Icon(hide ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                  onPressed: () => ref.read(hideListenedEpisodesProvider.notifier).setHide(!hide),
                ),
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),
          PopupMenuButton<PodcastEpisodeSort>(
            tooltip: '排序',
            icon: const Icon(Icons.sort),
            initialValue: sort,
            onSelected: (value) => ref.read(podcastEpisodeSortProvider.notifier).setSort(value),
            itemBuilder: (context) => [
              for (final value in PodcastEpisodeSort.values)
                PopupMenuItem(
                  value: value,
                  child: Text(value.label),
                ),
            ],
          ),
          IconButton(
            tooltip: '刷新',
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(podcastDetailProvider(feed)),
          ),
          IconButton(
            tooltip: '删除',
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              final confirmed = await confirmDeletePodcast(context, feed);
              if (confirmed != true) return;
              await ref.read(subscribedFeedsProvider.notifier).removeFeed(feed.id);
              if (context.mounted) Navigator.of(context).pop();
            },
          ),
        ],
      ),
      body: detailAsync.when(
        data: (detail) {
          if (detail.episodes.isEmpty) {
            return const AppEmptyState(
              icon: Icons.podcasts_outlined,
              message: '该 RSS 源暂无音频单集',
            );
          }
          final header = PodcastPlaybackLogic.stripHtml(detail.feed.description);
          final episodes = PodcastPlaybackLogic.sortedEpisodes(detail.episodes, sort);
          final listened = ref.watch(listenedEpisodeGuidsSetProvider);
          final hideListened = ref.watch(hideListenedEpisodesProvider).value ?? false;
          final filtered = hideListened
              ? episodes.where((e) => !listened.contains(e.guid)).toList()
              : episodes;
          if (filtered.isEmpty && hideListened) {
            return const AppEmptyState(
              icon: Icons.visibility_outlined,
              message: '都已听完',
              detail: '关闭「隐藏已听完」即可查看全部单集',
            );
          }
          final leadingCount = 1 + (header.isEmpty ? 0 : 1);
          final listEpisodes = filtered;
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(podcastDetailProvider(feed));
              await ref.read(podcastDetailProvider(feed).future);
            },
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(bottom: ChengboTheme.listBottomPadding),
              itemCount: listEpisodes.length + leadingCount,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                if (header.isNotEmpty && index == 0) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Text(
                      header,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                            height: 1.45,
                          ),
                    ),
                  );
                }
                if (index == (header.isEmpty ? 0 : 1)) {
                  return _DownloadAllTile(feed: detail.feed, episodes: listEpisodes);
                }
                final episode = listEpisodes[index - leadingCount];
                return _EpisodeTile(feed: detail.feed, episode: episode);
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => AppEmptyState(
          icon: offline ? Icons.wifi_off : Icons.error_outline,
          message: NetworkStatusLogic.loadFailureMessage('RSS 解析失败', offline: offline),
          detail: NetworkStatusLogic.loadFailureDetail(error, offline: offline),
          actionLabel: '重试',
          onAction: () => ref.invalidate(podcastDetailProvider(feed)),
        ),
      ),
    );
  }
}

class _DownloadAllTile extends ConsumerWidget {
  const _DownloadAllTile({required this.feed, required this.episodes});

  final PodcastFeed feed;
  final List<PodcastEpisode> episodes;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(podcastDownloadAllFeedsProvider).value?.contains(feed.id) ?? false;
    final downloads = ref.watch(podcastDownloadsProvider);
    final wifiOnly = ref.watch(downloadWifiOnlyProvider).value ?? false;
    final offline = ref.watch(isOfflineProvider).value ?? false;
    final ready = episodes.where((item) => downloads.statusFor(item.guid) == EpisodeDownloadStatus.ready).length;
    final downloading =
        episodes.where((item) => downloads.statusFor(item.guid) == EpisodeDownloadStatus.downloading).length;
    // Feed download size.
    int feedBytes = 0;
    for (final ep in episodes) {
      final rec = downloads.records[ep.guid];
      if (rec != null) feedBytes += rec.bytes;
    }

    return Column(
      children: [
        SwitchListTile(
          secondary: const Icon(Icons.download_for_offline_outlined),
          title: const Text('全部下载'),
          subtitle: Text(
            [
              PodcastDownloadLogic.downloadAllSubtitle(
                total: episodes.length,
                ready: ready,
                downloading: downloading,
                enabled: enabled,
              ),
              if (feedBytes > 0) PodcastDownloadLogic.formatBytes(feedBytes),
            ].where((s) => s.isNotEmpty).join(' · '),
          ),
          value: enabled,
          onChanged: (value) async {
            if (value && offline) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('当前没有网络，无法下载')),
              );
              return;
            }
            await ref.read(podcastDownloadAllFeedsProvider.notifier).setEnabled(feed.id, value);
            if (value) {
              await ref.read(podcastDownloadsProvider.notifier).downloadAll(feed, episodes);
            } else {
              await ref.read(podcastDownloadsProvider.notifier).cancelForGuids(
                    episodes.map((item) => item.guid),
                  );
            }
          },
        ),
        // Secondary row: WiFi-only + download recent N.
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '仅WiFi下载',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              Switch(
                value: wifiOnly,
                onChanged: (value) {
                  ref.read(downloadWifiOnlyProvider.notifier).set(value);
                },
              ),
              const SizedBox(width: 16),
              PopupMenuButton<int>(
                tooltip: '下载最近几集',
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    border: Border.all(color: Theme.of(context).colorScheme.outline),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '最近',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const Icon(Icons.arrow_drop_down, size: 18),
                    ],
                  ),
                ),
                onSelected: (count) async {
                  if (offline) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('当前没有网络，无法下载')),
                    );
                    return;
                  }
                  await ref.read(podcastDownloadsProvider.notifier).downloadRecent(feed, episodes, count);
                },
                itemBuilder: (context) => [
                  for (final n in [3, 5, 10])
                    PopupMenuItem(
                      value: n,
                      child: Text('最近 $n 集'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _EpisodeTile extends ConsumerWidget {
  const _EpisodeTile({required this.feed, required this.episode});

  final PodcastFeed feed;
  final PodcastEpisode episode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progressAsync = ref.watch(podcastProgressProvider(episode.guid));
    final current = ref.watch(currentPlaybackProvider);
    final isCurrent = current?.kind == PlaybackKind.podcast && current?.episodeGuid == episode.guid;
    final progress = progressAsync.asData?.value;
    final finished = PodcastPlaybackLogic.isFinished(
      progress: progress,
      duration: episode.duration,
    );
    final fraction = PodcastPlaybackLogic.progressFraction(
      progress: progress,
      duration: episode.duration,
    );
    final hasNotes = PodcastPlaybackLogic.stripHtml(episode.description).isNotEmpty;
    final download = ref.watch(podcastDownloadsProvider);
    final downloadStatus = download.statusFor(episode.guid);
    final downloaded = downloadStatus == EpisodeDownloadStatus.ready;
    return ListTile(
      selected: isCurrent,
      leading: Icon(
        finished
            ? Icons.check_circle_outline
            : isCurrent
                ? Icons.podcasts
                : Icons.play_circle_outline,
      ),
      title: Text(
        episode.title,
        style: isCurrent ? const TextStyle(fontWeight: FontWeight.w600) : null,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            [
              if (episode.publishedAt != null)
                '${episode.publishedAt!.year}-${episode.publishedAt!.month}-${episode.publishedAt!.day}',
              if (episode.duration != null) _formatDuration(episode.duration!),
              if (finished)
                '已听完'
              else if (progress != null && progress > Duration.zero)
                '已播放 ${_formatDuration(progress)}',
              if (downloaded)
                '已下载${_downloadSizeLabel(download, episode.guid)}',
              if (isCurrent) '正在收听',
            ].where((s) => s.isNotEmpty).join(' · '),
          ),
          if (fraction != null && !finished) ...[
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(value: fraction, minHeight: 3),
            ),
          ],
        ],
      ),
      onTap: () async {
        await ref.read(playerControllerProvider).play(
              PlaybackItem.fromPodcastEpisode(
                podcastTitle: feed.title,
                episodeTitle: episode.title,
                audioUrl: episode.audioUrl,
                episodeGuid: episode.guid,
                artworkUrl: episode.imageUrl ?? feed.imageUrl,
                duration: episode.duration,
                description: episode.description,
                feedId: feed.id,
              ),
            );
      },
      onLongPress: () => _showEpisodeMenu(context, ref, feed, episode, hasNotes, downloadStatus),
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  String _downloadSizeLabel(PodcastDownloadState downloads, String guid) {
    final record = downloads.records[guid];
    if (record == null || record.bytes <= 0) return '';
    return ' (${PodcastDownloadLogic.formatBytes(record.bytes)})';
  }
}

void _showEpisodeMenu(BuildContext context, WidgetRef ref, PodcastFeed feed, PodcastEpisode episode, bool hasNotes, EpisodeDownloadStatus downloadStatus) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(episode.title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (hasNotes)
              ListTile(
                leading: const Icon(Icons.description_outlined),
                title: const Text('查看简介'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  showEpisodeNotesSheet(context: context, ref: ref, feed: feed, episode: episode);
                },
              ),
            ListTile(
              leading: const Icon(Icons.playlist_add),
              title: const Text('加入播放队列'),
              onTap: () {
                Navigator.pop(sheetContext);
                ref.read(playQueueProvider.notifier).add(
                      PlaybackItem.fromPodcastEpisode(
                        podcastTitle: feed.title,
                        episodeTitle: episode.title,
                        audioUrl: episode.audioUrl,
                        episodeGuid: episode.guid,
                        artworkUrl: episode.imageUrl ?? feed.imageUrl,
                        duration: episode.duration,
                        feedId: feed.id,
                      ),
                    );
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('已加入播放队列')),
                );
              },
            ),
            if (downloadStatus == EpisodeDownloadStatus.ready)
              ListTile(
                leading: const Icon(Icons.download_done),
                title: const Text('删除下载'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _confirmDeleteDownload(context, ref, feed, episode);
                },
              )
            else if (downloadStatus != EpisodeDownloadStatus.downloading)
              ListTile(
                leading: const Icon(Icons.download_outlined),
                title: const Text('下载到本机'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  final offline = ref.read(isOfflineProvider).value ?? false;
                  if (!offline) {
                    ref.read(podcastDownloadsProvider.notifier).download(feed, episode);
                  }
                },
              ),
            ListTile(
              leading: const Icon(Icons.link),
              title: const Text('复制地址'),
              onTap: () {
                Navigator.pop(sheetContext);
                Clipboard.setData(ClipboardData(text: episode.audioUrl));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('已复制音频地址')),
                  );
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.share),
              title: const Text('分享'),
              onTap: () {
                Navigator.pop(sheetContext);
                Share.shareUri(Uri.parse(episode.audioUrl));
              },
            ),
          ],
        ),
      ),
    ),
  );
}

Future<void> _confirmDeleteDownload(BuildContext context, WidgetRef ref, PodcastFeed feed, PodcastEpisode episode) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('删除下载'),
      content: Text('删除「${episode.title}」的本机音频？之后需要联网才能再听。'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('删除')),
      ],
    ),
  );
  if (confirmed != true) return;
  await ref.read(podcastDownloadsProvider.notifier).delete(episode.guid);
}

/// 播客主页：继续收听卡片 + 订阅列表。
class ResumeAndInboxList extends ConsumerWidget {
  const ResumeAndInboxList({
    super.key,
    required this.feeds,
    this.query = '',
  });

  final List<PodcastFeed> feeds;
  final String query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resumeAsync = ref.watch(resumeListeningProvider);

    return ListView(
      padding: const EdgeInsets.only(bottom: ChengboTheme.listBottomPadding),
      children: [
        // 搜索时隐藏继续收听，只显示订阅列表
        if (query.isEmpty) ...[
          // 继续收听卡片
          resumeAsync.when(
            data: (entry) {
              if (entry == null) return const SizedBox.shrink();
              return _ResumeCard(entry: entry);
            },
            loading: () => const SizedBox(height: 12, child: LinearProgressIndicator()),
            error: (_, __) => const SizedBox.shrink(),
          ),
          const Divider(height: 1),
        ],
        for (final feed in feeds) _FeedItem(feed: feed, context: context, ref: ref),
      ],
    );
  }
}

/// 继续收听卡片：最近播放且未听完的单集，点按续播。
class _ResumeCard extends ConsumerWidget {
  const _ResumeCard({required this.entry});

  final PodcastHistoryEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final progressAsync = ref.watch(podcastProgressProvider(entry.episodeGuid));
    final progress = progressAsync.asData?.value;
    final fraction = PodcastPlaybackLogic.progressFraction(
      progress: progress,
      duration: entry.duration,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Card(
        color: colorScheme.primaryContainer,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            ref.read(playerControllerProvider).play(entry.toPlaybackItem());
          },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(Icons.play_circle_fill_rounded, size: 40, color: colorScheme.onPrimaryContainer),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '继续收听',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: colorScheme.onPrimaryContainer,
                            ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        entry.episodeTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: colorScheme.onPrimaryContainer,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      if (fraction != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(2),
                            child: LinearProgressIndicator(
                              value: fraction,
                              minHeight: 4,
                              color: colorScheme.primary,
                              backgroundColor: colorScheme.surfaceContainerHighest,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 单个订阅项目。
class _FeedItem extends ConsumerWidget {
  const _FeedItem({
    required this.feed,
    required this.context,
    required this.ref,
  });

  final PodcastFeed feed;
  final BuildContext context;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = PodcastPlaybackLogic.stripHtml(feed.description);
    return Dismissible(
      key: ValueKey('podcast-feed-${feed.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Theme.of(context).colorScheme.errorContainer,
        child: Icon(
          Icons.delete_outline,
          color: Theme.of(context).colorScheme.onErrorContainer,
        ),
      ),
      confirmDismiss: (_) => confirmDeletePodcast(context, feed),
      onDismissed: (_) => ref.read(subscribedFeedsProvider.notifier).removeFeed(feed.id),
      child: ListTile(
        leading: StationArtwork(url: feed.imageUrl, size: 48, icon: Icons.podcasts),
        title: Text(feed.title),
        subtitle: Text(
          summary.isEmpty ? feed.feedUrl : summary,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => PodcastDetailScreen(feed: feed),
            ),
          );
        },
        onLongPress: () => _showFeedMenu(context, ref, feed),
      ),
    );
  }

  void _showFeedMenu(BuildContext context, WidgetRef ref, PodcastFeed feed) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        final colorScheme = Theme.of(context).colorScheme;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(feed.title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                ListTile(
                  leading: Icon(Icons.play_arrow_rounded, color: colorScheme.primary),
                  title: const Text('播放最新'),
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    final detail = await ref.read(podcastServiceProvider).fetchFeed(feed);
                    final episodes = PodcastPlaybackLogic.sortedEpisodes(detail.episodes, PodcastEpisodeSort.newestFirst);
                    if (episodes.isEmpty) return;
                    await ref.read(playerControllerProvider).play(
                          PlaybackItem.fromPodcastEpisode(
                            podcastTitle: feed.title,
                            episodeTitle: episodes.first.title,
                            audioUrl: episodes.first.audioUrl,
                            episodeGuid: episodes.first.guid,
                            artworkUrl: episodes.first.imageUrl ?? feed.imageUrl,
                            duration: episodes.first.duration,
                            description: episodes.first.description,
                            feedId: feed.id,
                          ),
                        );
                  },
                ),
                ListTile(
                  leading: Icon(Icons.link, color: colorScheme.onSurfaceVariant),
                  title: const Text('复制地址'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    Clipboard.setData(ClipboardData(text: feed.feedUrl));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('已复制播客地址')),
                      );
                    }
                  },
                ),
                ListTile(
                  leading: Icon(Icons.share, color: colorScheme.onSurfaceVariant),
                  title: const Text('分享'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    Share.shareUri(Uri.parse(feed.feedUrl));
                  },
                ),
                ListTile(
                  leading: Icon(Icons.delete_outline, color: colorScheme.error),
                  title: Text('删除', style: TextStyle(color: colorScheme.error)),
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    final confirmed = await confirmDeletePodcast(context, feed);
                    if (confirmed != true) return;
                    await ref.read(subscribedFeedsProvider.notifier).removeFeed(feed.id);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
