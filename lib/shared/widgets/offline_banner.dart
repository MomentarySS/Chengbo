import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/network_status.dart';
import '../../core/providers/app_providers.dart';

/// 断网时钉在内容区顶部，不打断正在看的列表。
class OfflineBanner extends ConsumerWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offline = ref.watch(isOfflineProvider).value ?? false;
    if (!offline) return const SizedBox.shrink();

    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Row(
          children: [
            Icon(Icons.wifi_off, size: 18, color: colorScheme.onErrorContainer),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                NetworkStatusLogic.banner,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onErrorContainer,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
