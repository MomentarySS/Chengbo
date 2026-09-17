import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/category/station_category_resolver.dart';
import '../../core/models/radio_station.dart';
import 'radio_providers.dart';

Future<void> showStationCategoryPicker(
  BuildContext context,
  WidgetRef ref,
  RadioStation station,
) async {
  if (StationCategoryResolver.isLocked(station)) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('央广和地方台分类为系统默认，不可修改')),
    );
    return;
  }

  final filters = ref.read(stationFilterCategoriesProvider);
  final overrides = ref.read(stationCategoryOverridesProvider).value ?? {};
  final current = effectiveStationCategory(station, overrides);
  final options = filters
      .where((item) => item != StationCategoryResolver.all)
      .where((item) => !StationCategoryResolver.lockedCategoryNames.contains(item))
      .toList();

  if (!context.mounted) return;

  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                '设置分类 · ${station.name}',
                style: Theme.of(sheetContext).textTheme.titleMedium,
              ),
            ),
            ...options.map(
              (category) => RadioListTile<String>(
                value: category,
                groupValue: current,
                title: Text(category),
                onChanged: (value) async {
                  if (value == null) return;
                  await ref.read(stationCategoryOverridesProvider.notifier).setOverride(
                        station,
                        value,
                      );
                  if (sheetContext.mounted) Navigator.pop(sheetContext);
                },
              ),
            ),
            if (overrides.containsKey(station.id))
              TextButton(
                onPressed: () async {
                  await ref.read(stationCategoryOverridesProvider.notifier).clearOverride(station.id);
                  if (sheetContext.mounted) Navigator.pop(sheetContext);
                },
                child: const Text('恢复自动分类'),
              ),
            const SizedBox(height: 8),
          ],
        ),
      );
    },
  );
}
