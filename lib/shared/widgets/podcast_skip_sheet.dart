import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/audio/podcast_playback.dart';
import '../../core/providers/app_providers.dart';

Future<void> showPodcastSkipSheet(BuildContext context, {required String feedId}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => _PodcastSkipSheet(feedId: feedId),
  );
}

class _PodcastSkipSheet extends ConsumerStatefulWidget {
  const _PodcastSkipSheet({required this.feedId});

  final String feedId;

  @override
  ConsumerState<_PodcastSkipSheet> createState() => _PodcastSkipSheetState();
}

class _PodcastSkipSheetState extends ConsumerState<_PodcastSkipSheet> {
  late int _introSeconds;
  late int _outroSeconds;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final storage = await ref.read(appStorageProvider.future);
    setState(() {
      _introSeconds = storage.getPodcastSkipIntro(widget.feedId);
      _outroSeconds = storage.getPodcastSkipOutro(widget.feedId);
    });
  }

  Future<void> _save() async {
    final storage = await ref.read(appStorageProvider.future);
    await storage.setPodcastSkipIntro(widget.feedId, _introSeconds);
    await storage.setPodcastSkipOutro(widget.feedId, _outroSeconds);
  }

  String _formatSeconds(int seconds) {
    if (seconds == 0) return '关闭';
    if (seconds < 60) return '${seconds}秒';
    final m = seconds ~/ 60;
    final s = seconds % 60;
    if (s == 0) return '${m}分';
    return '${m}分${s}秒';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('跳过片头/尾', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              '设置后，每次播放该播客将自动跳过指定片段',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 24),

            // Skip intro.
            Text('跳过片头', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final secs in PodcastPlaybackLogic.skipDurationOptions)
                  ChoiceChip(
                    label: Text(_formatSeconds(secs)),
                    selected: _introSeconds == secs,
                    onSelected: (_) => setState(() => _introSeconds = secs),
                  ),
              ],
            ),

            const SizedBox(height: 20),

            // Skip outro.
            Text('跳过片尾', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final secs in PodcastPlaybackLogic.skipDurationOptions)
                  ChoiceChip(
                    label: Text(_formatSeconds(secs)),
                    selected: _outroSeconds == secs,
                    onSelected: (_) => setState(() => _outroSeconds = secs),
                  ),
              ],
            ),

            const SizedBox(height: 24),
            FilledButton(
              onPressed: () async {
                await _save();
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
  }
}
