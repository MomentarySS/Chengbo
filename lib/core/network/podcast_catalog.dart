import 'dart:convert';

import 'podcast_discovery.dart';

/// GetPodcast 目录里的一条节目。只留搜索与订阅用得到的字段。
class PodcastCatalogEntry {
  const PodcastCatalogEntry({
    required this.title,
    required this.rssUrl,
    this.author = '',
    this.cover,
    this.tags = const [],
  });

  factory PodcastCatalogEntry.fromJson(Map<String, dynamic> json) {
    final rawTags = json['tags'];
    return PodcastCatalogEntry(
      title: json['title'] as String? ?? '',
      rssUrl: json['rssUrl'] as String? ?? '',
      author: json['author'] as String? ?? '',
      cover: json['cover'] as String?,
      tags: [
        if (rawTags is List)
          for (final tag in rawTags)
            if (tag is String && tag.trim().isNotEmpty) tag.trim(),
      ],
    );
  }

  final String title;
  final String rssUrl;
  final String author;
  final String? cover;
  final List<String> tags;

  bool get isUsable => title.trim().isNotEmpty && rssUrl.trim().isNotEmpty;

  Map<String, dynamic> toJson() => {
        'title': title,
        'rssUrl': rssUrl,
        if (author.isNotEmpty) 'author': author,
        if (cover != null && cover!.isNotEmpty) 'cover': cover,
        if (tags.isNotEmpty) 'tags': tags,
      };

  PodcastDiscoveryHit toHit() => PodcastDiscoveryHit(
        title: title,
        feedUrl: rssUrl,
        author: author,
        artworkUrl: cover,
        genre: tags.isEmpty ? '' : tags.first,
      );
}

/// 本机播客目录（GetPodcast / getpodcast.xyz）。
///
/// 为什么要它：iTunes 搜索接口在境内常连不上（实测手机浏览器能开、应用里常失败），
/// 而 Podcast Index 需要用户自己申请密钥。这个站国内直连可拉，页面里内嵌了
/// `window.__INITIAL_DATA__`（约 250 条中文节目，带 `rssUrl` / `tags` / `isPaid`），
/// 拉一次存本机后**搜索完全走本机**，不依赖任何搜索 API。
///
/// 已知代价：只覆盖它收录的两百多个中文节目（冷门/新节目搜不到），而且它是第三方
/// 页面 —— 结构变了就解析不出来，此时按「目录为空」处理，搜索退回上两级。
abstract final class PodcastCatalogLogic {
  static const catalogUrl = 'https://getpodcast.xyz/';
  static const storageKey = 'podcast_catalog_json';
  static const maxAge = Duration(days: 7);

  /// 从页面里抠出 `window.__INITIAL_DATA__ = {...}` 的 JSON 片段（按花括号配对，
  /// 且跳过字符串里的括号与转义）。找不到返回 null。纯函数，便于测试。
  static String? extractInitialData(String html) {
    const marker = 'window.__INITIAL_DATA__';
    final start = html.indexOf(marker);
    if (start < 0) return null;
    final open = html.indexOf('{', start);
    if (open < 0) return null;

    var depth = 0;
    var inString = false;
    var escaped = false;
    for (var i = open; i < html.length; i++) {
      final char = html[i];
      if (inString) {
        if (escaped) {
          escaped = false;
        } else if (char == '\\') {
          escaped = true;
        } else if (char == '"') {
          inString = false;
        }
        continue;
      }
      if (char == '"') {
        inString = true;
      } else if (char == '{') {
        depth++;
      } else if (char == '}') {
        depth--;
        if (depth == 0) return html.substring(open, i + 1);
      }
    }
    return null;
  }

  /// 把 `__INITIAL_DATA__` 解出来的 map 转成目录条目。
  ///
  /// 合并 `featured` / `rightNow` / `promoted` 三个列表，按 `rssUrl` 去重；
  /// **跳过付费专辑**（`isPaid`）—— 它们的 RSS 通常只给试听片段，订了也听不全。
  static List<PodcastCatalogEntry> parseInitialData(Object? decoded) {
    if (decoded is! Map) return const [];
    final out = <PodcastCatalogEntry>[];
    final seen = <String>{};
    for (final key in const ['featured', 'rightNow', 'promoted']) {
      final raw = decoded[key];
      if (raw is! List) continue;
      for (final item in raw) {
        if (item is! Map) continue;
        final json = Map<String, dynamic>.from(item);
        if (json['isPaid'] == true) continue;
        final entry = PodcastCatalogEntry.fromJson(json);
        if (!entry.isUsable) continue;
        if (!seen.add(entry.rssUrl)) continue;
        out.add(entry);
      }
    }
    return out;
  }

  /// 本机搜索：标题精确 > 标题前缀 > 标题包含 > 作者 > 标签，同分保持目录顺序。
  static List<PodcastCatalogEntry> search(
    List<PodcastCatalogEntry> catalog,
    String query, {
    int limit = 30,
  }) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const [];
    final scored = <({PodcastCatalogEntry entry, int score})>[];
    for (final entry in catalog) {
      final title = entry.title.toLowerCase();
      final author = entry.author.toLowerCase();
      final int score;
      if (title == q) {
        score = 100;
      } else if (title.startsWith(q)) {
        score = 80;
      } else if (title.contains(q)) {
        score = 60;
      } else if (author.contains(q)) {
        score = 40;
      } else if (entry.tags.any((tag) => tag.toLowerCase().contains(q))) {
        score = 20;
      } else {
        score = 0;
      }
      if (score > 0) scored.add((entry: entry, score: score));
    }
    scored.sort((a, b) => b.score.compareTo(a.score));
    return [for (final item in scored.take(limit)) item.entry];
  }

  static String encode(List<PodcastCatalogEntry> entries, DateTime fetchedAt) {
    return jsonEncode({
      'fetchedAtMs': fetchedAt.millisecondsSinceEpoch,
      'entries': [for (final entry in entries) entry.toJson()],
    });
  }

  /// 解析本机缓存；结构不对或为空都返回 null。
  static ({List<PodcastCatalogEntry> entries, DateTime fetchedAt})? decode(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final rawEntries = decoded['entries'];
      if (rawEntries is! List) return null;
      final entries = [
        for (final item in rawEntries)
          if (item is Map) PodcastCatalogEntry.fromJson(Map<String, dynamic>.from(item)),
      ]..removeWhere((entry) => !entry.isUsable);
      if (entries.isEmpty) return null;
      final ms = decoded['fetchedAtMs'];
      return (
        entries: entries,
        fetchedAt: ms is int
            ? DateTime.fromMillisecondsSinceEpoch(ms)
            : DateTime.fromMillisecondsSinceEpoch(0),
      );
    } catch (_) {
      return null;
    }
  }

  static bool isStale(DateTime fetchedAt, DateTime now) =>
      now.difference(fetchedAt) >= maxAge;
}
