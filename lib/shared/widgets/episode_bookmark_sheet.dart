import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/podcast/episode_bookmark.dart';
import '../../core/providers/app_providers.dart';
import '../../core/providers/podcast_bookmark_provider.dart';

Future<void> showEpisodeBookmarkSheet({
  required BuildContext context,
  required String episodeGuid,
  required String episodeTitle,
  String feedId = '',
  String podcastTitle = '',
  String streamUrl = '',
  String? artworkUrl,
  Duration? Function()? currentPosition,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) => _EpisodeBookmarkSheet(
      episodeGuid: episodeGuid,
      episodeTitle: episodeTitle,
      feedId: feedId,
      podcastTitle: podcastTitle,
      streamUrl: streamUrl,
      artworkUrl: artworkUrl,
      currentPosition: currentPosition,
    ),
  );
}

class _EpisodeBookmarkSheet extends ConsumerWidget {
  const _EpisodeBookmarkSheet({
    required this.episodeGuid,
    required this.episodeTitle,
    required this.feedId,
    required this.podcastTitle,
    required this.streamUrl,
    this.artworkUrl,
    this.currentPosition,
  });

  final String episodeGuid;
  final String episodeTitle;
  final String feedId;
  final String podcastTitle;
  final String streamUrl;
  final String? artworkUrl;
  final Duration? Function()? currentPosition;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = EpisodeBookmarkLogic.forEpisode(
      ref.watch(podcastBookmarksProvider).value ?? const [],
      episodeGuid,
    );
    final maxHeight = MediaQuery.sizeOf(context).height * 0.7;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text('书签', style: Theme.of(context).textTheme.titleLarge),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: FilledButton.tonalIcon(
                  onPressed: () => _add(context, ref),
                  icon: const Icon(Icons.add),
                  label: const Text('添加当前进度'),
                ),
              ),
              if (items.isEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  child: Text(
                    '还没有书签。听到想记的地方，点「添加当前进度」。',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                )
              else
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return ListTile(
                        leading: const Icon(Icons.bookmark_outline),
                        title: Text(EpisodeBookmarkLogic.formatPosition(item.position)),
                        subtitle: item.note.isEmpty ? null : Text(item.note),
                        trailing: IconButton(
                          tooltip: '删除',
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () =>
                              ref.read(podcastBookmarksProvider.notifier).remove(item.id),
                        ),
                        onTap: () async {
                          Navigator.pop(context);
                          await ref.read(podcastBookmarksProvider.notifier).jumpTo(item);
                        },
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final live = currentPosition?.call();
    final handler = ref.read(audioHandlerProvider).value;
    final playing = ref.read(currentPlaybackProvider);
    final position = live ??
        (handler != null && playing?.episodeGuid == episodeGuid
            ? handler.player.position
            : Duration.zero);
    final note = await showDialog<String>(
      context: context,
      builder: (dialogContext) => _BookmarkNoteDialog(position: position),
    );
    if (note == null) return;
    await ref.read(podcastBookmarksProvider.notifier).add(
          EpisodeBookmark(
            id: '',
            episodeGuid: episodeGuid,
            positionMs: position.inMilliseconds,
            createdAtMs: 0,
            feedId: feedId,
            episodeTitle: episodeTitle,
            podcastTitle: podcastTitle,
            streamUrl: streamUrl,
            artworkUrl: artworkUrl,
            note: note,
          ),
        );
  }
}

class _BookmarkNoteDialog extends StatefulWidget {
  const _BookmarkNoteDialog({required this.position});

  final Duration position;

  @override
  State<_BookmarkNoteDialog> createState() => _BookmarkNoteDialogState();
}

class _BookmarkNoteDialogState extends State<_BookmarkNoteDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('书签 ${EpisodeBookmarkLogic.formatPosition(widget.position)}'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: EpisodeBookmarkLogic.maxNoteChars,
        decoration: const InputDecoration(
          labelText: '笔记（可留空）',
        ),
        textInputAction: TextInputAction.done,
        onSubmitted: (value) => Navigator.pop(context, value),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
        FilledButton(
          onPressed: () => Navigator.pop(context, _controller.text),
          child: const Text('保存'),
        ),
      ],
    );
  }
}
