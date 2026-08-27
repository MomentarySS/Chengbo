import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/category/station_category_resolver.dart';
import '../../core/models/radio_station.dart';
import '../../core/network/network_status.dart';
import '../../core/network/stream_url_tester.dart';
import '../../core/providers/app_providers.dart';
import '../../core/station/custom_stations_backup.dart';
import '../../core/station/playlist_import.dart';
import '../../core/station/playlist_resolver.dart';
import '../radio/radio_providers.dart';
import '../../shared/widgets/station_artwork.dart';

class CustomStationsScreen extends ConsumerStatefulWidget {
  const CustomStationsScreen({super.key, this.editing});

  final RadioStation? editing;

  @override
  ConsumerState<CustomStationsScreen> createState() => _CustomStationsScreenState();
}

class _CustomStationsScreenState extends ConsumerState<CustomStationsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _urlController = TextEditingController();
  final _faviconController = TextEditingController();
  final _tagsController = TextEditingController();
  final _tester = StreamUrlTester();
  final _playlistResolver = PlaylistResolver();

  String _category = '综合';
  bool _testing = false;
  bool _saving = false;
  String? _testMessage;
  bool? _testOk;
  late String? _editingId;

  @override
  void initState() {
    super.initState();
    _editingId = widget.editing?.id;
    final editing = widget.editing;
    if (editing != null) {
      _nameController.text = editing.name;
      _urlController.text = editing.streamUrl;
      _faviconController.text = editing.favicon ?? '';
      _category = editing.category.isEmpty ? '综合' : editing.category;
      _tagsController.text = editing.tags
          .where((tag) => tag != '自定义' && tag != _category)
          .join(', ');
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _urlController.dispose();
    _faviconController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  List<String> _categoryOptions() {
    final custom = ref.watch(customCategoriesProvider).value ?? [];
    final base = StationCategoryResolver.defaultFilterCategories
        .where(
          (c) =>
              c != StationCategoryResolver.all &&
              !StationCategoryResolver.lockedCategoryNames.contains(c),
        )
        .toList();
    return [...base, ...custom.where((c) => !base.contains(c))];
  }

  Future<void> _testUrl() async {
    if (_testing) return;
    setState(() {
      _testing = true;
      _testMessage = null;
      _testOk = null;
    });
    if (await ref.read(networkMonitorProvider).isOffline) {
      if (!mounted) return;
      setState(() {
        _testing = false;
        _testMessage = NetworkStatusLogic.testFailed;
        _testOk = false;
      });
      return;
    }
    final resolved = await _resolvePlaylist();
    if (!mounted) return;
    if (resolved == null) {
      setState(() {
        _testing = false;
        _testOk = false;
      });
      return;
    }
    final result = await _tester.test(resolved.streamUrl);
    if (!mounted) return;
    setState(() {
      _testing = false;
      _testMessage = result.message;
      _testOk = result.ok;
    });
  }

  Future<PlaylistResolveResult?> _resolvePlaylist() async {
    final resolved = await _playlistResolver.resolve(_urlController.text);
    if (!resolved.ok) {
      if (mounted) {
        setState(() => _testMessage = resolved.message);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(resolved.message ?? '无法解析播放列表')),
        );
      }
      return null;
    }
    if (resolved.resolvedFromPlaylist && mounted) {
      _urlController.text = resolved.streamUrl;
      if (_nameController.text.trim().isEmpty && (resolved.title ?? '').isNotEmpty) {
        _nameController.text = resolved.title!;
      }
      setState(() {
        _testMessage = resolved.message;
        _testOk = true;
      });
    }
    return resolved;
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final resolved = await _resolvePlaylist();
    if (resolved == null) {
      if (mounted) setState(() => _saving = false);
      return;
    }

    final extraTags = _tagsController.text
        .split(RegExp(r'[,，、\s]+'))
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();

    final notifier = ref.read(customStationsProvider.notifier);
    final error = _editingId == null
        ? await notifier.add(
            name: _nameController.text,
            streamUrl: resolved.streamUrl,
            favicon: _faviconController.text,
            category: _category,
            extraTags: extraTags,
          )
        : await notifier.update(
            id: _editingId!,
            name: _nameController.text,
            streamUrl: resolved.streamUrl,
            favicon: _faviconController.text,
            category: _category,
            extraTags: extraTags,
          );

    if (!mounted) return;
    setState(() => _saving = false);

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      return;
    }

    _nameController.clear();
    _urlController.clear();
    _faviconController.clear();
    _tagsController.clear();
    setState(() {
      _editingId = null;
      _testMessage = null;
      _testOk = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(widget.editing != null ? '电台已更新' : '电台已添加，可在电台列表中搜索播放')),
    );
    if (widget.editing != null && mounted) {
      unawaited(Navigator.of(context).maybePop());
    }
  }

  Future<void> _confirmDelete(String id, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除电台'),
        content: Text('确定删除「$name」？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('删除')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await ref.read(customStationsProvider.notifier).remove(id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('已删除「$name」')));
  }

  Future<void> _exportStations() async {
    final stations = ref.read(customStationsProvider).value ?? [];
    if (stations.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('还没有可导出的手动电台')),
      );
      return;
    }
    await Clipboard.setData(ClipboardData(text: CustomStationsBackup.encode(stations)));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已复制 ${stations.length} 个手动电台到剪贴板')),
    );
  }

  Future<void> _importStations() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final parsed = CustomStationsBackup.decode(data?.text ?? '');
    if (parsed == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('剪贴板里没有可导入的电台 JSON')),
      );
      return;
    }
    final result = await ref.read(customStationsProvider.notifier).importStations(parsed);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('导入完成：新增 ${result.added} 个，跳过 ${result.skipped} 个')),
    );
  }

  void _startEdit(RadioStation station) {
    setState(() {
      _editingId = station.id;
      _nameController.text = station.name;
      _urlController.text = station.streamUrl;
      _faviconController.text = station.favicon ?? '';
      _category = station.category.isEmpty ? '综合' : station.category;
      _tagsController.text = station.tags
          .where((tag) => tag != '自定义' && tag != _category)
          .join(', ');
      _testMessage = null;
      _testOk = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final customStations = ref.watch(customStationsProvider);
    final categories = _categoryOptions();
    if (!categories.contains(_category)) {
      _category = categories.first;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_editingId == null ? '手动添加电台' : '编辑电台'),
        actions: [
          IconButton(
            tooltip: '导出到剪贴板',
            onPressed: _exportStations,
            icon: const Icon(Icons.ios_share),
          ),
          IconButton(
            tooltip: '从剪贴板导入',
            onPressed: _importStations,
            icon: const Icon(Icons.file_download_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          Text(
            _editingId == null ? '添加直播流' : '修改直播流',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            _editingId == null
                ? '填写电台名称和流地址（.m3u8 / .mp3，或 .m3u / .pls 播放列表）。保存后会出现在电台列表最前面。可用右上角导入/导出备份。'
                : '修改后会同步到电台列表。',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 16),
          Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: '电台名称',
                    hintText: '例如：佛山音乐广播',
                    border: OutlineInputBorder(),
                  ),
                  textInputAction: TextInputAction.next,
                  validator: (value) =>
                      value == null || value.trim().isEmpty ? '请输入电台名称' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _urlController,
                  decoration: const InputDecoration(
                    labelText: '流地址',
                    hintText: 'https://example.com/live.m3u8 或 playlist.m3u',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.url,
                  textInputAction: TextInputAction.next,
                  validator: (value) {
                    final trimmed = value?.trim() ?? '';
                    if (trimmed.isEmpty) return '请输入流地址';
                    if (PlaylistImportLogic.looksLikePlaylistText(trimmed)) return null;
                    if (!trimmed.startsWith('http://') && !trimmed.startsWith('https://')) {
                      return '地址需以 http:// 或 https:// 开头';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _faviconController,
                  decoration: const InputDecoration(
                    labelText: '台标地址（可选）',
                    hintText: 'https://example.com/logo.png',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.url,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _category,
                  decoration: const InputDecoration(
                    labelText: '分类',
                    border: OutlineInputBorder(),
                  ),
                  items: categories
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) setState(() => _category = value);
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _tagsController,
                  decoration: const InputDecoration(
                    labelText: '额外标签（可选）',
                    hintText: '广东, 佛山（逗号分隔）',
                    border: OutlineInputBorder(),
                  ),
                ),
                if (_testMessage != null) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(
                        _testOk == true ? Icons.check_circle_outline : Icons.error_outline,
                        size: 18,
                        color: _testOk == true
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.error,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _testMessage!,
                          style: TextStyle(
                            color: _testOk == true
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: _testing ? null : _testUrl,
                      icon: _testing
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.link),
                      label: const Text('测试连接'),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _saving ? null : _save,
                        icon: _saving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Icon(_editingId == null ? Icons.add : Icons.save_outlined),
                        label: Text(_editingId == null ? '保存电台' : '保存修改'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 40),
          Text(
            '已添加的电台',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          customStations.when(
            data: (stations) {
              if (stations.isEmpty) {
                return const ListTile(
                  title: Text('暂无手动添加的电台'),
                  subtitle: Text('保存后会显示在这里，并同步到电台列表'),
                );
              }
              return Column(
                children: stations
                    .map(
                      (station) => ListTile(
                        leading: StationArtwork(
                          url: station.favicon,
                          name: station.name,
                          tags: station.tags,
                        ),
                        title: Text(station.name),
                        subtitle: Text(
                          station.streamUrl,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () async {
                          await ref.read(recentIdsProvider.notifier).add(station.id);
                          await ref
                              .read(playerControllerProvider)
                              .play(PlaybackItem.fromStation(station));
                        },
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: '编辑',
                              icon: const Icon(Icons.edit_outlined),
                              onPressed: () => _startEdit(station),
                            ),
                            IconButton(
                              tooltip: '删除',
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () => _confirmDelete(station.id, station.name),
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              );
            },
            loading: () => const Center(child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            ),),
            error: (error, _) => ListTile(title: Text('加载失败: $error')),
          ),
        ],
      ),
    );
  }
}
