import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/station/station_catalog_selection.dart';
import 'radio_providers.dart';

/// 首次启动或设置里调整「想听哪些台」。
class StationCatalogSetupScreen extends ConsumerStatefulWidget {
  const StationCatalogSetupScreen({
    super.key,
    this.firstLaunch = false,
    this.initial,
  });

  final bool firstLaunch;
  final StationCatalogSelection? initial;

  @override
  ConsumerState<StationCatalogSetupScreen> createState() =>
      _StationCatalogSetupScreenState();
}

class _StationCatalogSetupScreenState extends ConsumerState<StationCatalogSetupScreen> {
  late Set<String> _themes;
  late Set<String> _provinces;
  late bool _allCurated;
  var _saving = false;

  @override
  void initState() {
    super.initState();
    final seed = widget.initial ?? const StationCatalogSelection();
    _themes = {...seed.themes};
    _provinces = {...seed.provinces};
    _allCurated = seed.allCurated;
  }

  StationCatalogSelection get _selection => StationCatalogSelection(
        themes: _themes,
        provinces: _provinces,
        allCurated: _allCurated,
      );

  Future<void> _save() async {
    if (_selection.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请至少选择一种类型或一个省份')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(stationCatalogSelectionProvider.notifier).applySelection(_selection);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _toggleTheme(String theme, bool selected) {
    setState(() {
      _allCurated = false;
      if (selected) {
        _themes.add(theme);
      } else {
        _themes.remove(theme);
      }
    });
  }

  void _toggleProvince(String province, bool selected) {
    setState(() {
      _allCurated = false;
      if (selected) {
        _provinces.add(province);
      } else {
        _provinces.remove(province);
      }
    });
  }

  void _selectAllProvinces() {
    setState(() {
      _allCurated = false;
      _provinces = {...StationCatalogSelectionLogic.provinceOptions};
    });
  }

  void _clearProvinces() {
    setState(() => _provinces.clear());
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return PopScope(
      canPop: !widget.firstLaunch,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.firstLaunch ? '选择想听的电台' : '收听范围'),
          automaticallyImplyLeading: !widget.firstLaunch,
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            Text(
            widget.firstLaunch
                ? '首次使用请先勾选想听的类型或省份，至少选一项。之后可在「设置 → 电台管理」里修改。'
                : '修改后会重新检测所选范围内的直播源。',
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('加载全部精选'),
              subtitle: const Text('约 413 台，首次检测较慢'),
              value: _allCurated,
              onChanged: _saving
                  ? null
                  : (value) => setState(() {
                        _allCurated = value;
                        if (value) {
                          _themes.clear();
                          _provinces.clear();
                        }
                      }),
            ),
            if (!_allCurated) ...[
              _SectionHeader(
                title: '类型',
                trailing: TextButton(
                  onPressed: _saving
                      ? null
                      : () => setState(() {
                            _themes = {StationCatalogSelectionLogic.cnrTheme};
                          }),
                  child: const Text('仅央广'),
                ),
              ),
              _ChipWrap(
                children: [
                  for (final theme in StationCatalogSelectionLogic.themeOptions)
                    FilterChip(
                      label: Text(theme),
                      selected: _themes.contains(theme),
                      onSelected: _saving ? null : (v) => _toggleTheme(theme, v),
                    ),
                ],
              ),
              _SectionHeader(
                title: '省份 / 地区',
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton(
                      onPressed: _saving ? null : _clearProvinces,
                      child: const Text('清空'),
                    ),
                    TextButton(
                      onPressed: _saving ? null : _selectAllProvinces,
                      child: const Text('全选'),
                    ),
                  ],
                ),
              ),
              _ChipWrap(
                children: [
                  for (final province in StationCatalogSelectionLogic.provinceOptions)
                    FilterChip(
                      label: Text(province),
                      selected: _provinces.contains(province),
                      onSelected: _saving ? null : (v) => _toggleProvince(province, v),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            Text(
              StationCatalogSelectionLogic.detail(_selection),
              style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
            ),
          ],
        ),
        bottomNavigationBar: SafeArea(
          minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(widget.firstLaunch ? '开始检测并进入' : '保存并重新检测'),
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class _ChipWrap extends StatelessWidget {
  const _ChipWrap({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Wrap(spacing: 8, runSpacing: 4, children: children);
  }
}
