import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/radio_station.dart';
import '../../core/network/stream_url_tester.dart';
import '../../core/station/playlist_resolver.dart';
import '../../core/station/station_patch.dart';
import '../../core/theme.dart';
import '../radio/radio_providers.dart';

class ReplaceStreamScreen extends ConsumerStatefulWidget {
  const ReplaceStreamScreen({super.key, required this.station});

  final RadioStation station;

  @override
  ConsumerState<ReplaceStreamScreen> createState() => _ReplaceStreamScreenState();
}

class _ReplaceStreamScreenState extends ConsumerState<ReplaceStreamScreen> {
  final _urlController = TextEditingController();
  final _tester = StreamUrlTester();
  final _playlistResolver = PlaylistResolver();
  bool _testing = false;
  bool _saving = false;
  String? _testMessage;
  bool? _testOk;

  @override
  void initState() {
    super.initState();
    _urlController.text = widget.station.streamUrl;
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _testUrl() async {
    if (_testing) return;
    setState(() {
      _testing = true;
      _testMessage = null;
      _testOk = null;
    });
    final resolved = await _playlistResolver.resolve(_urlController.text);
    if (!resolved.ok) {
      if (!mounted) return;
      setState(() {
        _testing = false;
        _testOk = false;
        _testMessage = resolved.message ?? '无法解析地址';
      });
      return;
    }
    final result = await _tester.test(resolved.streamUrl);
    if (!mounted) return;
    setState(() {
      _testing = false;
      _testOk = result.ok;
      _testMessage = result.message;
      if (resolved.resolvedFromPlaylist) {
        _urlController.text = resolved.streamUrl;
      }
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    final resolved = await _playlistResolver.resolve(_urlController.text);
    if (!resolved.ok) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(resolved.message ?? '无法解析地址')),
      );
      return;
    }
    final error = await ref.read(stationPatchesProvider.notifier).replaceUrl(
          station: widget.station,
          streamUrl: resolved.streamUrl,
        );
    if (!mounted) return;
    setState(() => _saving = false);
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已更换流地址，可直接播放')),
    );
    Navigator.of(context).pop();
  }

  Future<void> _restore() async {
    await ref.read(stationPatchesProvider.notifier).restore(widget.station.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已恢复精选原址')),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final patches = ref.watch(stationPatchesProvider).value ?? {};
    final patched = StationPatchLogic.isPatched(widget.station.id, patches);
    final original = patches[widget.station.id]?.originalStreamUrl ?? widget.station.streamUrl;

    return Scaffold(
      appBar: AppBar(title: const Text('更换流地址')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, ChengboTheme.listBottomPadding),
        children: [
          Text(widget.station.name, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            '精选和网络发现的台也可以在这里改地址，不用等发版。改动只存在本机。',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          if (patched) ...[
            const SizedBox(height: 12),
            Text('原址', style: Theme.of(context).textTheme.labelLarge),
            SelectableText(original, style: Theme.of(context).textTheme.bodySmall),
          ],
          const SizedBox(height: 16),
          TextField(
            controller: _urlController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: '流地址',
              hintText: 'https://… 或 .m3u / .pls',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              OutlinedButton(
                onPressed: _testing ? null : _testUrl,
                child: Text(_testing ? '测试中…' : '测试连接'),
              ),
              const SizedBox(width: 12),
              if (_testMessage != null)
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
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: const Icon(Icons.save_outlined),
            label: Text(_saving ? '保存中…' : '保存'),
          ),
          if (patched) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: _restore,
              child: const Text('恢复精选原址'),
            ),
          ],
        ],
      ),
    );
  }
}
