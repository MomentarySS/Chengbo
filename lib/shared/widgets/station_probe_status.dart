import 'package:flutter/material.dart';

import '../../core/network/stream_url_tester.dart';

/// 检测直播源或更新目录时的进度占位，与空状态同一套居中短句。
class StationProbeStatus extends StatelessWidget {
  const StationProbeStatus({super.key, required this.progress});

  final StationProbeProgress progress;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final fraction = progress.fraction;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                progress.probing ? Icons.wifi_find : Icons.refresh,
                size: 40,
                color: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 12),
              Text(
                progress.probing ? '正在检测可用电台' : '正在更新电台列表',
                style: textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                progress.probing
                    ? (progress.total == 0 ? '准备检测…' : '${progress.done} / ${progress.total}')
                    : '重新拉取精选和发现目录',
                textAlign: TextAlign.center,
                style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              LinearProgressIndicator(value: fraction),
            ],
          ),
        ),
      ),
    );
  }
}
