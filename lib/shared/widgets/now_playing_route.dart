import 'package:flutter/material.dart';

import '../../core/audio/now_playing_hero.dart';
import 'mini_player.dart';

/// 全屏 Now Playing 路由：支持封面 Hero，并可下拉关闭。
class NowPlayingPageRoute extends PageRoute<void> {
  NowPlayingPageRoute() : super(fullscreenDialog: true);

  @override
  bool get opaque => false;

  @override
  bool get barrierDismissible => true;

  @override
  Color? get barrierColor => Colors.black38;

  @override
  String? get barrierLabel => '关闭正在播放';

  @override
  Duration get transitionDuration => const Duration(milliseconds: NowPlayingHero.flightMs);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 280);

  @override
  bool get maintainState => true;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return const NowPlayingDismissible(child: NowPlayingSheet());
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.06),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      ),
    );
  }
}

class NowPlayingDismissible extends StatelessWidget {
  const NowPlayingDismissible({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: GestureDetector(
            onVerticalDragEnd: (details) {
              final velocity = details.primaryVelocity ?? 0;
              if (velocity > 420) {
                Navigator.of(context).maybePop();
              }
            },
            child: const SizedBox(height: 120),
          ),
        ),
      ],
    );
  }
}
