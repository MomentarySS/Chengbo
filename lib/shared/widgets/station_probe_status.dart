import 'package:flutter/material.dart';

import '../../core/network/station_probe.dart';
import '../../core/network/stream_url_tester.dart';
import '../../core/theme.dart';

/// 检测直播源或更新目录时的进度。探测中可取消，已测到的台可先听。
class StationProbeStatus extends StatelessWidget {
  const StationProbeStatus({
    super.key,
    required this.progress,
    this.onCancel,
    this.compact = false,
  });

  final StationProbeProgress progress;
  final VoidCallback? onCancel;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final copy = context.chengboSkin.copy;
    final fraction = progress.fraction;
    final probing = progress.probing;
    final title = probing ? copy.probing : copy.updatingCatalog;
    final detail = probing
        ? '${StationProbeLogic.progressLabel(done: progress.done, total: progress.total)}'
            ' · ${StationProbeLogic.listenEarlyHint(found: progress.found)}'
        : '重新拉取精选和发现目录';

    if (compact) {
      return Material(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: textTheme.labelLarge),
                    const SizedBox(height: 2),
                    Text(
                      detail,
                      style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(value: fraction),
                  ],
                ),
              ),
              if (onCancel != null)
                TextButton(
                  onPressed: onCancel,
                  child: const Text(StationProbeLogic.cancelLabel),
                ),
            ],
          ),
        ),
      );
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                probing ? Icons.wifi_find : Icons.refresh,
                size: 40,
                color: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                detail,
                textAlign: TextAlign.center,
                style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              LinearProgressIndicator(value: fraction),
              if (onCancel != null) ...[
                const SizedBox(height: 12),
                TextButton(
                  onPressed: onCancel,
                  child: const Text(StationProbeLogic.cancelLabel),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
