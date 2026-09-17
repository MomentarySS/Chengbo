import 'package:chengbo/core/network/system_http_proxy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(SystemHttpProxy.resetCache);

  test('parseWindowsProxyServer reads host:port and per-scheme lists', () {
    expect(SystemHttpProxy.parseWindowsProxyServer('127.0.0.1:7897'), '127.0.0.1:7897');
    expect(
      SystemHttpProxy.parseWindowsProxyServer(
        'http=127.0.0.1:7897;https=127.0.0.1:7897;socks=127.0.0.1:7898',
      ),
      '127.0.0.1:7897',
    );
    expect(SystemHttpProxy.parseWindowsProxyServer('http://127.0.0.1:7897'), '127.0.0.1:7897');
    expect(SystemHttpProxy.parseWindowsProxyServer(''), isNull);
  });

  test('matchesProxyOverride understands localhost globs and <local>', () {
    final override = 'localhost;127.*;192.168.*;<local>';
    expect(
      SystemHttpProxy.matchesProxyOverride(Uri.parse('https://localhost/x'), override),
      isTrue,
    );
    expect(
      SystemHttpProxy.matchesProxyOverride(Uri.parse('https://127.0.0.1/x'), override),
      isTrue,
    );
    expect(
      SystemHttpProxy.matchesProxyOverride(Uri.parse('https://intranet/x'), override),
      isTrue,
    );
    expect(
      SystemHttpProxy.matchesProxyOverride(
        Uri.parse('https://feeds.soundon.fm/x'),
        override,
      ),
      isFalse,
    );
  });

  test('findProxy prefers environment then Windows IE proxy', () {
    expect(
      SystemHttpProxy.findProxy(
        Uri.parse('https://feeds.soundon.fm/podcasts/x.xml'),
        environment: const {},
        windowsProxy: const WindowsIeProxy(enabled: false),
        localHttpProxy: '',
      ),
      'DIRECT',
    );
    expect(
      SystemHttpProxy.findProxy(
        Uri.parse('https://feeds.soundon.fm/podcasts/x.xml'),
        environment: const {},
        windowsProxy: const WindowsIeProxy(
          enabled: true,
          server: '127.0.0.1:7897',
        ),
      ),
      'PROXY 127.0.0.1:7897',
    );
    expect(
      SystemHttpProxy.findProxy(
        Uri.parse('https://feeds.soundon.fm/podcasts/x.xml'),
        environment: const {'HTTPS_PROXY': 'http://127.0.0.1:1080'},
        windowsProxy: const WindowsIeProxy(
          enabled: true,
          server: '127.0.0.1:7897',
        ),
      ),
      'PROXY 127.0.0.1:1080',
    );
    expect(
      SystemHttpProxy.findProxy(
        Uri.parse('https://127.0.0.1/health'),
        environment: const {'HTTPS_PROXY': 'http://127.0.0.1:1080'},
        windowsProxy: const WindowsIeProxy(
          enabled: true,
          server: '127.0.0.1:7897',
        ),
      ),
      'DIRECT',
    );
  });

  test('findProxy falls back to local Clash-like HTTP port', () {
    expect(
      SystemHttpProxy.findProxy(
        Uri.parse('https://feeds.soundon.fm/podcasts/x.xml'),
        environment: const {},
        windowsProxy: const WindowsIeProxy(enabled: false),
        localHttpProxy: '127.0.0.1:7897',
      ),
      'PROXY 127.0.0.1:7897',
    );
    expect(
      SystemHttpProxy.statusLabel(
        environment: const {},
        windowsProxy: const WindowsIeProxy(enabled: false),
        localHttpProxy: '127.0.0.1:7897',
      ),
      contains('本机代理 127.0.0.1:7897'),
    );
    expect(
      SystemHttpProxy.statusLabel(
        environment: const {},
        windowsProxy: const WindowsIeProxy(enabled: false),
        localHttpProxy: '',
      ),
      contains('未走代理'),
    );
  });

  test('discoverLocalHttpProxy caches first open port in preference order', () async {
    final seen = <int>[];
    final found = await SystemHttpProxy.discoverLocalHttpProxy(
      probe: (host, port) async {
        seen.add(port);
        return port == 7890 || port == 10808;
      },
    );
    expect(found, '127.0.0.1:7890');
    expect(seen, containsAll(SystemHttpProxy.localHttpProxyPorts));
    expect(
      await SystemHttpProxy.discoverLocalHttpProxy(
        probe: (host, port) async => throw StateError('should use cache'),
      ),
      '127.0.0.1:7890',
    );
  });

  test('parseRegDwordEnabled reads REG_DWORD', () {
    expect(
      SystemHttpProxy.parseRegDwordEnabled(
        '    ProxyEnable    REG_DWORD    0x1',
      ),
      isTrue,
    );
    expect(
      SystemHttpProxy.parseRegDwordEnabled(
        '    ProxyEnable    REG_DWORD    0x0',
      ),
      isFalse,
    );
  });
}
