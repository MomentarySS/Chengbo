import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/category/station_category_resolver.dart';
import '../radio/radio_providers.dart';

/// 分类设置：系统默认分类、自定义分类列表、添加输入框。
class CategoryScreen extends ConsumerStatefulWidget {
  const CategoryScreen({super.key});

  @override
  ConsumerState<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends ConsumerState<CategoryScreen> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _addCategory(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return;
    ref.read(customCategoriesProvider.notifier).add(value);
    _controller.clear();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('已添加分类「$value」')));
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final customCategories = ref.watch(customCategoriesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('电台分类')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 96),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              '这里可增删自定义分类；央广、地方台为系统默认分类，不可修改',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Text(
              '系统默认（不可删除）',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(StationCategoryResolver.lockedCategoryNames.join('、')),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              '自定义分类',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          customCategories.when(
            data: (categories) {
              if (categories.isEmpty) {
                return const ListTile(
                  dense: true,
                  title: Text('暂无自定义分类'),
                );
              }
              return Column(
                children: categories
                    .map(
                      (name) => ListTile(
                        dense: true,
                        leading: const Icon(Icons.label_outline),
                        title: Text(name),
                        trailing: IconButton(
                          tooltip: '删除分类',
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () =>
                              ref.read(customCategoriesProvider.notifier).remove(name),
                        ),
                      ),
                    )
                    .toList(),
              );
            },
            loading: () => const LinearProgressIndicator(),
            error: (error, _) => ListTile(title: Text('加载分类失败: $error')),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      labelText: '新建自定义分类',
                      hintText: '例如：通勤、睡前',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: _addCategory,
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () => _addCategory(_controller.text),
                  child: const Text('添加'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}