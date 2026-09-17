import 'package:flutter/material.dart';

import '../../core/audio/now_playing_indicator.dart';

/// 台标 / 封面右下角叠静态播放图标。不订阅进度流。
class NowPlayingLeading extends StatelessWidget {
  const NowPlayingLeading({
    super.key,
    required this.child,
    required this.active,
    this.size = 48,
  });

  final Widget child;
  final bool active;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (!active) return child;
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          child,
          Positioned(
            right: 0,
            bottom: 0,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: scheme.primary,
                shape: BoxShape.circle,
              ),
              child: Icon(
                NowPlayingIndicatorLogic.icon,
                size: 14,
                color: scheme.onPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
