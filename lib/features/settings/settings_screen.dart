import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import 'about_screen.dart';
import 'appearance_screen.dart';
import 'category_screen.dart';
import 'data_management_screen.dart';
import 'playback_screen.dart';
import 'podcast_management_screen.dart';
import 'source_screen.dart';

/// 设置主页：分组导航，每个分类点进去进子页面。
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.only(bottom: ChengboTheme.listBottomPadding),
      children: [
        _Entry(
          icon: Icons.podcasts_outlined,
          title: '播客管理',
          subtitle: 'RSS 订阅、OPML 导入导出',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const PodcastManagementScreen()),
          ),
        ),
        _Entry(
          icon: Icons.radio_outlined,
          title: '电台管理',
          subtitle: '收听范围、检测、刷新、Radio Browser、手动添加',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const SourceSettingsScreen()),
          ),
        ),
        _Entry(
          icon: Icons.play_circle_outline,
          title: '播放与收听',
          subtitle: '记住上次收听、迷你窗、摇一摇、新一集通知',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const PlaybackSettingsScreen()),
          ),
        ),
        _Entry(
          icon: Icons.contrast,
          title: '外观',
          subtitle: '主题、配色、投屏',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const AppearanceScreen()),
          ),
        ),
        _Entry(
          icon: Icons.storage_outlined,
          title: '数据管理',
          subtitle: '封面缓存、播客下载',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const DataManagementScreen()),
          ),
        ),
        _Entry(
          icon: Icons.category_outlined,
          title: '电台分类',
          subtitle: '自定义分类',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const CategoryScreen()),
          ),
        ),
        _Entry(
          icon: Icons.info_outline,
          title: '关于',
          subtitle: '版本、隐私说明',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const AboutScreen()),
          ),
        ),
      ],
    );
  }
}

class _Entry extends StatelessWidget {
  const _Entry({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}