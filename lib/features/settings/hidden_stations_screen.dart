import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../radio/radio_providers.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/station_artwork.dart';

class HiddenStationsScreen extends ConsumerWidget {
  const HiddenStationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hidden = ref.watch(hiddenStationsProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('已隐藏的电台')),
      body: hidden.isEmpty
          ? const AppEmptyState(
              icon: Icons.visibility_off_outlined,
              message: '还没有隐藏的台',
              detail: '主页电台长按可隐藏。听不了或不想听的都可以藏起来，以后再在这里恢复。',
            )
          : ListView.separated(
              padding: const EdgeInsets.only(bottom: ChengboTheme.listBottomPadding),
              itemCount: hidden.length + 1,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Text(
                      '共 ${hidden.length} 个。恢复后重新出现在主页。',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                    ),
                  );
                }
                final station = hidden[index - 1];
                return ListTile(
                  leading: StationArtwork(
                    url: station.favicon,
                    name: station.name,
                    tags: station.tags,
                    size: 40,
                  ),
                  title: Text(station.name),
                  subtitle: Text(station.streamUrl),
                  trailing: TextButton(
                    onPressed: () =>
                        ref.read(hiddenStationIdsProvider.notifier).unhide(station.id),
                    child: const Text('恢复'),
                  ),
                );
              },
            ),
    );
  }
}
