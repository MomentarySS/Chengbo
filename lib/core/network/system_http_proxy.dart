import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';

/// Windows 系统代理（IE/WinINET）快照。Clash「系统代理」写的是这里，不是 WinHTTP。
class WindowsIeProxy {
  const WindowsIeProxy({
    required this.enabled,
    this.server = '',
    this.override = '',
  });

  final bool enabled;
  final String server;
  final String override;

  String? get hostPort => SystemHttpProxy.parseWindowsProxyServer(server);

  bool shouldBypass(Uri url) =>
      SystemHttpProxy.matchesProxyOverride(url, override);
}

/// Dart [HttpClient] 默认不读 Windows「Internet 选项」代理。
/// 澄波在桌面直连境外 RSS（如 SoundOn）时会因此连接超时。
abstract final class SystemHttpProxy {
  static WindowsIeProxy? Function()? debugWindowsProxyLoader;
  static WindowsIeProxy? _cachedWindows;
  static var _windowsLoaded = false;
  static String? _cachedLocalHttpProxy;

  /// Clash / Clash Verge / v2rayN / NekoBox 常见 HTTP 混合端口。
  static const localHttpProxyPorts = [7897, 7890, 10808, 6152, 2080, 20171, 7891, 10809];

  static void resetCache() {
    _cachedWindows = null;
    _windowsLoaded = false;
    _cachedLocalHttpProxy = null;
  }

  /// PAC 风格结果，可直接赋给 [HttpClient.findProxy]。
  static String findProxy(
    Uri url, {
    Map<String, String>? environment,
    WindowsIeProxy? windowsProxy,
    String? localHttpProxy,
  }) {
    if (isLoopback(url)) return 'DIRECT';

    final fromEnv = HttpClient.findProxyFromEnvironment(
      url,
      environment: environment,
    );
    if (fromEnv != 'DIRECT') return fromEnv;

    final ie = windowsProxy ?? _windowsIeProxy();
    if (ie != null && ie.enabled) {
      if (ie.shouldBypass(url)) return 'DIRECT';
      final hostPort = ie.hostPort;
      if (hostPort != null && hostPort.isNotEmpty) return 'PROXY $hostPort';
    }

    final local = localHttpProxy ?? _cachedLocalHttpProxy;
    if (local != null && local.isNotEmpty) return 'PROXY $local';
    return 'DIRECT';
  }

  /// 给设置页看的一句话。不探测端口，只用当前缓存。
  static String statusLabel({
    Map<String, String>? environment,
    WindowsIeProxy? windowsProxy,
    String? localHttpProxy,
  }) {
    final result = findProxy(
      Uri.parse('https://feeds.soundon.fm/status'),
      environment: environment,
      windowsProxy: windowsProxy,
      localHttpProxy: localHttpProxy ?? _cachedLocalHttpProxy,
    );
    if (result == 'DIRECT') {
      return '未走代理。被墙的境外 RSS 需要 Clash 系统代理、VPN/TUN，或本机混合端口';
    }
    final hostPort = result.startsWith('PROXY ') ? result.substring(6) : result;
    final ie = windowsProxy ?? _windowsIeProxy();
    if (ie != null && ie.enabled && ie.hostPort == hostPort) {
      return '已使用系统代理 $hostPort';
    }
    if ((localHttpProxy ?? _cachedLocalHttpProxy) == hostPort) {
      return '已检测到本机代理 $hostPort（Clash / NekoBox 等）';
    }
    return '已使用代理 $hostPort';
  }

  /// 并行探测本机常见 HTTP 代理端口，结果写入缓存供 [findProxy] 使用。
  static Future<String?> discoverLocalHttpProxy({
    Future<bool> Function(String host, int port)? probe,
  }) async {
    if (_cachedLocalHttpProxy != null) {
      return _cachedLocalHttpProxy!.isEmpty ? null : _cachedLocalHttpProxy;
    }
    final check = probe ?? _tcpOpen;
    final opened = <int>{};
    try {
      await Future.wait(
        localHttpProxyPorts.map((port) async {
          if (await check('127.0.0.1', port)) opened.add(port);
        }),
      );
    } catch (_) {
      // 探测失败时不阻塞启动流程。
    }
    for (final port in localHttpProxyPorts) {
      if (opened.contains(port)) {
        _cachedLocalHttpProxy = '127.0.0.1:$port';
        return _cachedLocalHttpProxy;
      }
    }
    _cachedLocalHttpProxy = '';
    return null;
  }

  static Future<bool> _tcpOpen(String host, int port) async {
    try {
      final socket = await Socket.connect(
        host,
        port,
        timeout: const Duration(milliseconds: 200),
      );
      socket.destroy();
      return true;
    } catch (_) {
      return false;
    }
  }

  static bool isLoopback(Uri url) {
    final host = url.host.toLowerCase();
    return host == 'localhost' ||
        host == '127.0.0.1' ||
        host == '::1';
  }

  /// `127.0.0.1:7897` 或 `http=127.0.0.1:7897;https=127.0.0.1:7897`。
  static String? parseWindowsProxyServer(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    if (!trimmed.contains('=')) {
      return _normalizeHostPort(trimmed);
    }
    String? https;
    String? http;
    String? socks;
    String? any;
    for (final part in trimmed.split(';')) {
      final idx = part.indexOf('=');
      if (idx <= 0) continue;
      final scheme = part.substring(0, idx).trim().toLowerCase();
      final value = _normalizeHostPort(part.substring(idx + 1));
      if (value == null) continue;
      any ??= value;
      switch (scheme) {
        case 'https':
          https = value;
        case 'http':
          http = value;
        case 'socks':
        case 'socks5':
          socks = value;
      }
    }
    return https ?? http ?? any ?? socks;
  }

  static bool matchesProxyOverride(Uri url, String override) {
    if (override.trim().isEmpty) return false;
    final host = url.host.toLowerCase();
    for (final raw in override.split(';')) {
      final token = raw.trim().toLowerCase();
      if (token.isEmpty) continue;
      if (token == '<local>') {
        if (!host.contains('.')) return true;
        continue;
      }
      if (_wildcardMatch(host, token)) return true;
    }
    return false;
  }

  static bool parseRegDwordEnabled(String stdout) {
    final match =
        RegExp(r'ProxyEnable\s+REG_DWORD\s+0x([0-9a-fA-F]+)', caseSensitive: false)
            .firstMatch(stdout);
    if (match == null) return false;
    return int.parse(match.group(1)!, radix: 16) != 0;
  }

  static String? parseRegSz(String stdout, String name) {
    final match =
        RegExp('$name\\s+REG_SZ\\s+(.+)', caseSensitive: false).firstMatch(stdout);
    return match?.group(1)?.trim();
  }

  static WindowsIeProxy? readWindowsIeProxyFromRegistry() {
    if (!Platform.isWindows) return null;
    try {
      final enabled = parseRegDwordEnabled(_regQuery('ProxyEnable'));
      if (!enabled) return const WindowsIeProxy(enabled: false);
      return WindowsIeProxy(
        enabled: true,
        server: parseRegSz(_regQuery('ProxyServer'), 'ProxyServer') ?? '',
        override: parseRegSz(_regQuery('ProxyOverride'), 'ProxyOverride') ?? '',
      );
    } catch (_) {
      return null;
    }
  }

  static void installHttpOverrides() {
    HttpOverrides.global = _SystemProxyHttpOverrides();
  }

  static Dio createDio([BaseOptions? options]) {
    final dio = Dio(options);
    attachToDio(dio);
    return dio;
  }

  static void attachToDio(Dio dio) {
    final adapter = dio.httpClientAdapter;
    if (adapter is! IOHttpClientAdapter) return;
    final previous = adapter.createHttpClient;
    adapter.createHttpClient = () {
      final client = previous?.call() ?? HttpClient();
      client.findProxy = findProxy;
      return client;
    };
  }

  static String? _normalizeHostPort(String value) {
    var v = value.trim();
    if (v.isEmpty) return null;
    v = v.replaceFirst(RegExp(r'^https?://', caseSensitive: false), '');
    final slash = v.indexOf('/');
    if (slash >= 0) v = v.substring(0, slash);
    if (v.isEmpty) return null;
    return v.contains(':') ? v : '$v:80';
  }

  static bool _wildcardMatch(String host, String pattern) {
    final escaped = RegExp.escape(pattern)
        .replaceAll(r'\*', '.*')
        .replaceAll(r'\?', '.');
    return RegExp('^$escaped\$').hasMatch(host);
  }

  static WindowsIeProxy? _windowsIeProxy() {
    if (debugWindowsProxyLoader != null) {
      return debugWindowsProxyLoader!();
    }
    if (_windowsLoaded) return _cachedWindows;
    _windowsLoaded = true;
    _cachedWindows = readWindowsIeProxyFromRegistry();
    return _cachedWindows;
  }

  static String _regQuery(String value) {
    final result = Process.runSync(
      'reg',
      [
        'query',
        r'HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings',
        '/v',
        value,
      ],
    );
    return result.stdout.toString();
  }
}

class _SystemProxyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = super.createHttpClient(context);
    client.findProxy = SystemHttpProxy.findProxy;
    return client;
  }
}
