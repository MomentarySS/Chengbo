import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/audio/podcast_playback.dart';
import '../../core/providers/app_providers.dart';

Future<void> showPodcastSkipSheet(BuildContext context, {required String feedId}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    // 两组各 10 个 chip，在窄屏上要换到 3 行，内容约 460px；不设
    // isScrollControlled 时高度上限是屏高的 9/16（760dp 屏约 427px），
    // 底部「保存」会被**静默裁掉**且滚不到。放开上限 + 自带滚动容器兜住。
    isScrollControlled: true,
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
  // 不能用 `late int` + 异步 `_load()`：首帧 build 跑在 await 之前，
  // 读未初始化的 late 字段会抛 LateInitializationError（面板先闪一个错误块）。
  // 也不给 0 当默认值 —— 那样存储还没读完时点「保存」会把已设的值清掉。
  int? _introSeconds;
  int? _outroSeconds;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final storage = await ref.read(appStorageProvider.future);
    if (!mounted) return;
    setState(() {
      _introSeconds = storage.getPodcastSkipIntro(widget.feedId);
      _outroSeconds = storage.getPodcastSkipOutro(widget.feedId);
    });
  }

  Future<void> _save() async {
    final intro = _introSeconds;
    final outro = _outroSeconds;
    if (intro == null || outro == null) return;
    final storage = await ref.read(appStorageProvider.future);
    await storage.setPodcastSkipIntro(widget.feedId, intro);
    await storage.setPodcastSkipOutro(widget.feedId, outro);
  }

  String _formatSeconds(int seconds) {
    if (seconds == 0) return '关闭';
    if (seconds < 60) return '$seconds秒';
    final m = seconds ~/ 60;
    final s = seconds % 60;
    if (s == 0) return '$m分';
    return '$m分$s秒';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final intro = _introSeconds;
    final outro = _outroSeconds;

    return SafeArea(
      child: SingleChildScrollView(
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
            if (intro == null || outro == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: Center(child: CircularProgressIndicator()),
              )
            else ...[
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
                      selected: intro == secs,
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
                      selected: outro == secs,
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
          ],
        ),
      ),
    );
  }
}
