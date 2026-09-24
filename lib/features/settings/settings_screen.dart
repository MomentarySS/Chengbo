import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../core/audio/cast_session.dart';
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
        _sectionLabel(context, '内容与来源'),
        _Entry(
          icon: Icons.podcasts_outlined,
          title: '播客管理',
          subtitle: '管理订阅、导入和导出 OPML',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const PodcastManagementScreen()),
          ),
        ),
        _Entry(
          icon: Icons.radio_outlined,
          title: '电台管理',
          subtitle: '收听范围、源检测和手动添加',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const SourceSettingsScreen()),
          ),
        ),
        _Entry(
          icon: Icons.category_outlined,
          title: '电台分类',
          subtitle: '管理自定义分类',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const CategoryScreen()),
          ),
        ),
        _sectionLabel(context, '播放与外观'),
        _Entry(
          icon: Icons.play_circle_outline,
          title: '播放与收听',
          subtitle: '播放偏好、设备选项与通知',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const PlaybackSettingsScreen()),
          ),
        ),
        _Entry(
          icon: Icons.contrast,
          title: '外观',
          subtitle: CastSessionLogic.offered ? '氛围、主题、配色和投屏' : '氛围、主题和配色',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const AppearanceScreen()),
          ),
        ),
        _sectionLabel(context, '数据与应用'),
        _Entry(
          icon: Icons.storage_outlined,
          title: '数据管理',
          subtitle: '封面缓存、播客下载、本机备份',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const DataManagementScreen()),
          ),
        ),
        _Entry(
          icon: Icons.info_outline,
          title: '关于',
          subtitle: '版本信息与隐私说明',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const AboutScreen()),
          ),
        ),
      ],
    );
  }

  Widget _sectionLabel(BuildContext context, String label) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
      ),
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
