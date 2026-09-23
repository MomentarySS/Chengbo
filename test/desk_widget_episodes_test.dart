import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:chengbo/core/audio/desk_widget.dart';
import 'package:chengbo/core/models/podcast.dart';
import 'package:chengbo/core/podcast/feed_cache.dart';

void main() {
  group('DeskWidgetLogic.episodesPayload', () {
    test('空列表 → `[]`', () {
      expect(DeskWidgetLogic.episodesPayload(const []), '[]');
    });

    test('1 个 item → 1 元素数组，含 title / subtitle / guid', () {
      final items = [
        const InboxItem(
          feed: PodcastFeed(
            id: 'f1',
            title: '节目 A',
            feedUrl: 'https://example.com/rss',
          ),
          episode: PodcastEpisode(
            guid: 'g1',
            title: '单集 1',
            audioUrl: 'https://example.com/ep1.mp3',
          ),
        ),
      ];
      final json = DeskWidgetLogic.episodesPayload(items);
      final decoded = jsonDecode(json) as List<dynamic>;
      expect(decoded, hasLength(1));
      final row = decoded.first as Map<String, dynamic>;
      expect(row['title'], '单集 1');
      expect(row['subtitle'], '节目 A');
      expect(row['guid'], 'g1');
    });

    test('超过 maxEpisodes → 截断到 4', () {
      final items = List.generate(
        6,
        (i) => InboxItem(
          feed: PodcastFeed(
            id: 'f$i',
            title: '节目 $i',
            feedUrl: 'https://example.com/rss$i',
          ),
          episode: PodcastEpisode(
            guid: 'g$i',
            title: '单集 $i',
            audioUrl: 'https://example.com/ep$i.mp3',
          ),
        ),
      );
      final json = DeskWidgetLogic.episodesPayload(items);
      final decoded = jsonDecode(json) as List<dynamic>;
      expect(decoded, hasLength(DeskWidgetLogic.maxEpisodes));
      expect(decoded, hasLength(4));
    });

    test('含特殊字符（引号 / emoji / 中文）→ 正确转义 + 还原', () {
      final items = [
        const InboxItem(
          feed: PodcastFeed(
            id: 'f1',
            title: '她说：「再见」👋',
            feedUrl: 'https://example.com/rss',
          ),
          episode: PodcastEpisode(
            guid: 'g"with"quote',
            title: '第 1 集：你好 "世界" 🌍',
            audioUrl: 'https://example.com/ep1.mp3',
          ),
        ),
      ];
      final json = DeskWidgetLogic.episodesPayload(items);
      final decoded = jsonDecode(json) as List<dynamic>;
      final row = decoded.first as Map<String, dynamic>;
      expect(row['title'], '第 1 集：你好 "世界" 🌍');
      expect(row['subtitle'], '她说：「再见」👋');
      expect(row['guid'], 'g"with"quote');
    });

    test('episode.title 为空串 → 仍输出该行（不崩）', () {
      final items = [
        const InboxItem(
          feed: PodcastFeed(
            id: 'f1',
            title: '节目 A',
            feedUrl: 'https://example.com/rss',
          ),
          episode: PodcastEpisode(
            guid: 'g1',
            title: '',
            audioUrl: 'https://example.com/ep1.mp3',
          ),
        ),
      ];
      final json = DeskWidgetLogic.episodesPayload(items);
      final decoded = jsonDecode(json) as List<dynamic>;
      expect(decoded, hasLength(1));
      final row = decoded.first as Map<String, dynamic>;
      expect(row['title'], '');
      expect(row['guid'], 'g1');
    });
  });

  group('DeskWidgetLogic.actionForUri', () {
    test('chengbo://play?guid=abc → play', () {
      expect(
        DeskWidgetLogic.actionForUri(Uri.parse('chengbo://play?guid=abc')),
        DeskWidgetAction.play,
      );
    });

    test('chengbo://play（无 guid）→ play（handler 端静默降级）', () {
      expect(
        DeskWidgetLogic.actionForUri(Uri.parse('chengbo://play')),
        DeskWidgetAction.play,
      );
    });

    test('chengbo://play?guid=（空 guid）→ play（handler 端静默降级）', () {
      expect(
        DeskWidgetLogic.actionForUri(Uri.parse('chengbo://play?guid=')),
        DeskWidgetAction.play,
      );
    });

    test('4 旧 URI 映射不变（回归）', () {
      expect(
        DeskWidgetLogic.actionForUri(Uri.parse('chengbo://open')),
        DeskWidgetAction.open,
      );
      expect(
        DeskWidgetLogic.actionForUri(Uri.parse('chengbo://toggle')),
        DeskWidgetAction.toggle,
      );
      expect(
        DeskWidgetLogic.actionForUri(Uri.parse('chengbo://next')),
        DeskWidgetAction.next,
      );
      expect(
        DeskWidgetLogic.actionForUri(Uri.parse('chengbo://resume')),
        DeskWidgetAction.resume,
      );
    });

    test('未知 host → none', () {
      expect(
        DeskWidgetLogic.actionForUri(Uri.parse('chengbo://unknown')),
        DeskWidgetAction.none,
      );
    });

    test('null → none', () {
      expect(DeskWidgetLogic.actionForUri(null), DeskWidgetAction.none);
    });
  });
}