import 'dart:convert';

/// 整机本机备份：SharedPreferences 快照。不含直播音频、下载文件、Feed 缓存、Podcast Index 密钥。
class DeviceBackup {
  const DeviceBackup({
    required this.exportedAt,
    required this.appVersion,
    required this.prefs,
    required this.podcastState,
  });

  final DateTime exportedAt;
  final String appVersion;
  final Map<String, DevicePrefValue> prefs;
  final Map<String, dynamic> podcastState;

  int get keyCount => prefs.length;
}

class DevicePrefValue {
  const DevicePrefValue.string(this.value) : kind = DevicePrefKind.string;
  const DevicePrefValue.boolValue(this.value) : kind = DevicePrefKind.boolValue;
  const DevicePrefValue.intValue(this.value) : kind = DevicePrefKind.intValue;
  const DevicePrefValue.doubleValue(this.value) : kind = DevicePrefKind.doubleValue;
  const DevicePrefValue.stringList(this.value) : kind = DevicePrefKind.stringList;

  final DevicePrefKind kind;
  final Object value;

  Map<String, dynamic> toJson() => {
        't': kind.name,
        'v': value,
      };

  static DevicePrefValue? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final map = Map<String, dynamic>.from(raw);
    final type = map['t']?.toString();
    final value = map['v'];
    return switch (type) {
      'string' when value is String => DevicePrefValue.string(value),
      'boolValue' when value is bool => DevicePrefValue.boolValue(value),
      'intValue' when value is int => DevicePrefValue.intValue(value),
      'doubleValue' when value is num => DevicePrefValue.doubleValue(value.toDouble()),
      'stringList' when value is List => DevicePrefValue.stringList(
          [
            for (final item in value)
              if (item is String) item,
          ],
        ),
      _ => null,
    };
  }
}

enum DevicePrefKind { string, boolValue, intValue, doubleValue, stringList }

class DeviceBackupDecode {
  const DeviceBackupDecode._({this.backup, this.error});

  const DeviceBackupDecode.ok(DeviceBackup backup) : this._(backup: backup);
  const DeviceBackupDecode.fail(String error) : this._(error: error);

  final DeviceBackup? backup;
  final String? error;

  bool get isOk => backup != null;
}

/// 备份编解码与密钥过滤。
abstract final class DeviceBackupLogic {
  static const format = 'chengbo.device-backup';
  static const version = 2;

  static const skippedKeys = {
    'podcast_index_api_key',
    'podcast_index_api_secret',
    'podcast_downloads_json',
    'podcast_feed_cache_json',
    // GetPodcast 本机目录：可再拉的缓存，别塞进备份 JSON。
    'podcast_catalog_json',
  };

  static bool includeKey(String key) {
    if (key.startsWith('flutter.')) return false;
    return !skippedKeys.contains(key);
  }

  static DevicePrefValue? wrap(Object? value) {
    return switch (value) {
      final String v => DevicePrefValue.string(v),
      final bool v => DevicePrefValue.boolValue(v),
      final int v => DevicePrefValue.intValue(v),
      final double v => DevicePrefValue.doubleValue(v),
      final List<dynamic> v => DevicePrefValue.stringList([
          for (final item in v)
            if (item is String) item,
        ]),
      _ => null,
    };
  }

  static String encode({
    required Map<String, Object> prefs,
    required Map<String, dynamic> podcastState,
    required DateTime exportedAt,
    required String appVersion,
  }) {
    final body = <String, dynamic>{};
    for (final entry in prefs.entries) {
      if (!includeKey(entry.key)) continue;
      final wrapped = wrap(entry.value);
      if (wrapped == null) continue;
      body[entry.key] = wrapped.toJson();
    }
    return const JsonEncoder.withIndent('  ').convert({
      'format': format,
      'version': version,
      'exportedAt': exportedAt.toUtc().toIso8601String(),
      'appVersion': appVersion,
      'prefs': body,
      'podcastState': podcastState,
    });
  }

  static DeviceBackupDecode decode(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return const DeviceBackupDecode.fail('剪贴板是空的');
    }
    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is! Map) {
        return const DeviceBackupDecode.fail('不是澄波备份文件');
      }
      final map = Map<String, dynamic>.from(decoded);
      if (map['format'] != format) {
        return const DeviceBackupDecode.fail('不是澄波备份文件');
      }
      final version = map['version'];
      if (version is! int || version < 1 || version > DeviceBackupLogic.version) {
        return const DeviceBackupDecode.fail('备份版本无法识别');
      }
      final prefsRaw = map['prefs'];
      if (prefsRaw is! Map) {
        return const DeviceBackupDecode.fail('备份内容不完整');
      }
      final podcastStateRaw = map['podcastState'];
      final podcastState =
          podcastStateRaw is Map ? Map<String, dynamic>.from(podcastStateRaw) : const <String, dynamic>{};
      final prefs = <String, DevicePrefValue>{};
      for (final entry in prefsRaw.entries) {
        final key = entry.key.toString();
        if (!includeKey(key)) continue;
        final value = DevicePrefValue.fromJson(entry.value);
        if (value != null) prefs[key] = value;
      }
      if (prefs.isEmpty && podcastState.isEmpty) {
        return const DeviceBackupDecode.fail('备份里没有可恢复的数据');
      }
      final exportedAt =
          DateTime.tryParse(map['exportedAt']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
      return DeviceBackupDecode.ok(
        DeviceBackup(
          exportedAt: exportedAt,
          appVersion: map['appVersion']?.toString() ?? '',
          prefs: prefs,
          podcastState: podcastState,
        ),
      );
    } catch (_) {
      return const DeviceBackupDecode.fail('备份无法解析');
    }
  }

  static Set<String> keysToClear(Iterable<String> currentKeys) {
    return {
      for (final key in currentKeys)
        if (includeKey(key)) key,
    };
  }
}
