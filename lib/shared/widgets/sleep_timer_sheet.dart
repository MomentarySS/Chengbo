import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/audio/sleep_timer.dart';
import '../../core/models/radio_station.dart';
import '../../core/providers/app_providers.dart';
import '../../core/theme.dart';

Future<void> showSleepTimerSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => const _SleepTimerSheet(),
  );
}

class SleepTimerCountdown extends ConsumerWidget {
  const SleepTimerCountdown({
    super.key,
    this.style,
    this.compact = false,
  });

  final TextStyle? style;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timer = ref.watch(sleepTimerProvider);
    if (!timer.isActive) return const SizedBox.shrink();

    return StreamBuilder<DateTime>(
      stream: Stream<DateTime>.periodic(
        const Duration(seconds: 1),
        (_) => DateTime.now(),
      ),
      initialData: DateTime.now(),
      builder: (context, snapshot) {
        final now = snapshot.data ?? DateTime.now();
        final text = SleepTimerLogic.statusLabel(timer, now: now) ?? '';
        final fadeLabel = SleepTimerLogic.fadeOutLabel(timer, now: now);

        if (compact) {
          return Text(fadeLabel ?? text, style: style);
        }

        String display;
        Color? textColor;
        if (fadeLabel != null) {
          display = '淡出中 $fadeLabel';
          textColor = Theme.of(context).colorScheme.tertiary;
        } else if (timer.remainingEpisodes != null) {
          display = SleepTimerLogic.remainingEpisodesText(timer.remainingEpisodes!);
        } else if (timer.untilEpisodeEnd) {
          display = '到$text';
        } else {
          display = '剩余 $text';
        }

        return Text(
          display,
          style: style?.copyWith(color: textColor) ??
              TextStyle(color: textColor),
        );
      },
    );
  }
}

/// 睡眠定时的「光圈」：贴着内容外沿画一圈，随时间流逝逐渐消失。
///
/// 只在**有连续时钟**时按比例收缩（分钟型 / 小睡 —— 模型里有 `startedAt` +
/// `total`）。「本集结束」「再听 N 集」没有时钟，画一圈静态细描边表示「定时
/// 开着」，不去假装进度。
///
/// 不占用布局：描边画在 child 的盒子**外面**（封面本来就有外投影，说明这里
/// 不会被裁）。
class SleepTimerRing extends ConsumerWidget {
  const SleepTimerRing({
    super.key,
    required this.radius,
    required this.child,
    this.gap = 10,
    this.strokeWidth = 2.5,
  });

  /// child 的圆角，描边沿用同一个值，保证与内容贴合。
  final double radius;
  final Widget child;
  /// 描边离 child 外沿的距离。
  final double gap;
  final double strokeWidth;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timer = ref.watch(sleepTimerProvider);
    if (!timer.isActive) return child;
    final colorScheme = Theme.of(context).colorScheme;
    return StreamBuilder<DateTime>(
      stream: Stream<DateTime>.periodic(
        const Duration(seconds: 1),
        (_) => DateTime.now(),
      ),
      initialData: DateTime.now(),
      builder: (context, snapshot) {
        final now = snapshot.data ?? DateTime.now();
        return CustomPaint(
          painter: _SleepRingPainter(
            fraction: SleepTimerLogic.ringFraction(timer, now: now),
            radius: radius + gap,
            strokeWidth: strokeWidth,
            color: colorScheme.primary,
            trackColor: colorScheme.primary.withValues(alpha: 0.16),
          ),
          child: child,
        );
      },
    );
  }
}

class _SleepRingPainter extends CustomPainter {
  const _SleepRingPainter({
    required this.fraction,
    required this.radius,
    required this.strokeWidth,
    required this.color,
    required this.trackColor,
  });

  /// `null` = 没有连续时钟 → 只画静态环。
  final double? fraction;
  final double radius;
  final double strokeWidth;
  final Color color;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(
      -strokeWidth,
      -strokeWidth,
      size.width + strokeWidth * 2,
      size.height + strokeWidth * 2,
    );
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(radius));
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = trackColor;
    canvas.drawRRect(rrect, track);

    final left = fraction;
    if (left == null) {
      // 没有进度可画：静态环就够了。
      canvas.drawRRect(
        rrect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..color = color,
      );
      return;
    }
    if (left <= 0) return;

    final metric = Path()..addRRect(rrect);
    final pathMetric = metric.computeMetrics().first;
    final total = pathMetric.length;
    if (total <= 0) return;
    // 从**顶部中点**开始顺时针消失（RRect 的路径起点在左上圆角之后）。
    final topCenter = (rect.width / 2 - radius + strokeWidth).clamp(0.0, total);
    final sweep = (total * left).clamp(0.0, total);
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = color;
    if (topCenter + sweep <= total) {
      canvas.drawPath(pathMetric.extractPath(topCenter, topCenter + sweep), arc);
    } else {
      canvas.drawPath(pathMetric.extractPath(topCenter, total), arc);
      canvas.drawPath(pathMetric.extractPath(0, topCenter + sweep - total), arc);
    }
  }

  @override
  bool shouldRepaint(covariant _SleepRingPainter oldDelegate) {
    return oldDelegate.fraction != fraction ||
        oldDelegate.radius != radius ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.color != color ||
        oldDelegate.trackColor != trackColor;
  }
}

class _SleepTimerSheet extends ConsumerWidget {
  const _SleepTimerSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timer = ref.watch(sleepTimerProvider);
    final last = ref.watch(lastSleepValueProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('睡眠定时', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              timer.remainingEpisodes != null
                  ? '再听 ${timer.remainingEpisodes} 集后停止'
                  : timer.untilEpisodeEnd
                      ? '当前单集播完后停止'
                      : timer.isSnoozed
                          ? '小睡中，到点后继续播放'
                          : timer.isActive
                              ? '到点后停止播放'
                              : '选择时长，或播完当前单集后停止',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
            if (timer.isActive) ...[
              const SizedBox(height: 12),
              Center(
                child: SleepTimerCountdown(
                  style: context.chengboSkin.countdownStyle(
                    Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
                    colorScheme.primary,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),

            // Preset duration chips.
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final minutes in SleepTimerLogic.presetMinutes)
                  ActionChip(
                    label: Text('$minutes 分钟'),
                    side: last?.matchesMinutes(minutes) == true
                        ? BorderSide(color: colorScheme.primary)
                        : null,
                    onPressed: () {
                      ref.read(sleepTimerProvider.notifier).start(
                            Duration(minutes: minutes),
                          );
                      Navigator.pop(context);
                    },
                  ),
                ActionChip(
                  avatar: const Icon(Icons.tune, size: 18),
                  label: const Text('自定义'),
                  side: last?.kind == SleepLastKind.minutes &&
                          last?.minutes != null &&
                          !SleepTimerLogic.presetMinutes.contains(last!.minutes)
                      ? BorderSide(color: colorScheme.primary)
                      : null,
                  onPressed: () => _pickCustom(context, ref, last),
                ),
                ActionChip(
                  avatar: const Icon(Icons.skip_next_outlined, size: 18),
                  label: const Text('本集结束'),
                  side: last?.isUntilEnd == true
                      ? BorderSide(color: colorScheme.primary)
                      : null,
                  onPressed: () => _startUntilEpisodeEnd(context, ref),
                ),
                for (final count in SleepTimerLogic.episodeCountOptions)
                  ActionChip(
                    avatar: const Icon(Icons.queue_music_outlined, size: 18),
                    label: Text('再听 $count 集'),
                    side: last?.matchesEpisodes(count) == true
                        ? BorderSide(color: colorScheme.primary)
                        : null,
                    onPressed: () => _startRemainingEpisodes(context, ref, count),
                  ),
              ],
            ),

            // Active timer actions: snooze and cancel.
            if (timer.isActive) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        ref.read(sleepTimerProvider.notifier).snooze();
                        Navigator.pop(context);
                      },
                      icon: const Icon(Icons.snooze),
                      label: const Text('小睡 ${SleepTimerLogic.snoozeMinutes} 分钟'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextButton(
                      onPressed: () {
                        ref.read(sleepTimerProvider.notifier).cancel();
                        Navigator.pop(context);
                      },
                      child: const Text('关闭定时'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _startUntilEpisodeEnd(BuildContext context, WidgetRef ref) {
    final current = ref.read(currentPlaybackProvider);
    if (!SleepTimerLogic.canStartUntilEpisodeEnd(
      isPodcast: current?.kind == PlaybackKind.podcast,
    )) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先播放一集播客，直播没有「本集结束」')),
      );
      return;
    }
    ref.read(sleepTimerProvider.notifier).startUntilEpisodeEnd();
    Navigator.pop(context);
  }

  void _startRemainingEpisodes(BuildContext context, WidgetRef ref, int count) {
    final current = ref.read(currentPlaybackProvider);
    if (!SleepTimerLogic.canStartUntilEpisodeEnd(
      isPodcast: current?.kind == PlaybackKind.podcast,
    )) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先播放一集播客，直播没有「再听 N 集」')),
      );
      return;
    }
    ref.read(sleepTimerProvider.notifier).startRemainingEpisodes(count);
    Navigator.pop(context);
  }

  Future<void> _pickCustom(
    BuildContext context,
    WidgetRef ref,
    SleepLastValue? last,
  ) async {
    final duration = await showDialog<Duration>(
      context: context,
      builder: (dialogContext) => _CustomSleepTimerDialog(
        initialMinutes: last?.kind == SleepLastKind.minutes ? last?.minutes : null,
      ),
    );
    if (duration == null || !context.mounted) return;
    ref.read(sleepTimerProvider.notifier).start(duration);
    Navigator.pop(context);
  }
}

class _CustomSleepTimerDialog extends StatefulWidget {
  const _CustomSleepTimerDialog({this.initialMinutes});

  final int? initialMinutes;

  @override
  State<_CustomSleepTimerDialog> createState() => _CustomSleepTimerDialogState();
}

class _CustomSleepTimerDialogState extends State<_CustomSleepTimerDialog> {
  late final TextEditingController _hoursController;
  late final TextEditingController _minutesController;
  String? _error;

  @override
  void initState() {
    super.initState();
    final total = widget.initialMinutes ?? 30;
    _hoursController = TextEditingController(text: '${total ~/ 60}');
    _minutesController = TextEditingController(text: '${total % 60}');
  }

  @override
  void dispose() {
    _hoursController.dispose();
    _minutesController.dispose();
    super.dispose();
  }

  void _submit() {
    final hours = int.tryParse(_hoursController.text.trim()) ?? -1;
    final minutes = int.tryParse(_minutesController.text.trim()) ?? -1;
    final duration = SleepTimerLogic.durationFromCustom(
      hours: hours,
      minutes: minutes,
    );
    if (duration == null) {
      setState(() => _error = '请输入 1 分钟到 12 小时之间的时长');
      return;
    }
    Navigator.pop(context, duration);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('自定义定时'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _hoursController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(2),
                  ],
                  decoration: const InputDecoration(
                    labelText: '小时',
                    hintText: '0–12',
                  ),
                  onSubmitted: (_) => _submit(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _minutesController,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(2),
                  ],
                  decoration: const InputDecoration(
                    labelText: '分钟',
                    hintText: '0–59',
                  ),
                  onSubmitted: (_) => _submit(),
                ),
              ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('开始'),
        ),
      ],
    );
  }
}
