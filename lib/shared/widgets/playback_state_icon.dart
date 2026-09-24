import 'package:flutter/material.dart';

/// Shows a brief, reduced-motion-aware transition when playback state changes.
class PlaybackStateIcon extends StatelessWidget {
  const PlaybackStateIcon({
    super.key,
    required this.playing,
    this.size,
    this.color,
  });

  final bool playing;
  final double? size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    Icon buildIcon({Key? key}) => Icon(
          playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
          key: key,
          size: size,
          color: color,
        );

    if (MediaQuery.of(context).disableAnimations) return buildIcon();

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 140),
      reverseDuration: const Duration(milliseconds: 100),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.9, end: 1).animate(animation),
          child: child,
        ),
      ),
      child: buildIcon(key: ValueKey(playing)),
    );
  }
}
