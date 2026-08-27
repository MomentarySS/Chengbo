import 'package:flutter/material.dart';

import 'cast_button.dart';
import '../../core/audio/cast_session.dart';

/// Now Playing 顶部栏：下箭头返回 + 右侧投屏（仅 Android 有），无居中标题。
class NowPlayingTopBar extends StatelessWidget {
  const NowPlayingTopBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 40,
          height: 40,
          child: IconButton(
            tooltip: '关闭',
            icon: const Icon(Icons.keyboard_arrow_down_rounded),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ),
        const Spacer(),
        CastSessionLogic.offered ? const CastButton(outlined: false) : const SizedBox(width: 40),
      ],
    );
  }
}
