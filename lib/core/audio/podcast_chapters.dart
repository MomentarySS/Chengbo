import 'dart:convert';

import 'package:xml/xml.dart';

/// 单集章节：Podlove Simple Chapters 与 Podcasting 2.0 JSON。
class PodcastChapter {
  const PodcastChapter({
    required this.start,
    required this.title,
    this.toc = true,
  });

  final Duration start;
  final String title;
  final bool toc;
}

abstract final class PodcastChapterLogic {
  static String? chaptersUrlFromItem(XmlElement item) {
    for (final element in item.childElements) {
      if (element.name.local != 'chapters') continue;
      final url = element.getAttribute('url')?.trim() ?? '';
      if (url.startsWith('http://') || url.startsWith('https://')) return url;
    }
    return null;
  }

  static List<PodcastChapter> parsePodloveChapters(XmlElement item) {
    final chapters = <PodcastChapter>[];
    for (final parent in item.childElements) {
      if (parent.name.local != 'chapters') continue;
      if ((parent.getAttribute('url') ?? '').trim().isNotEmpty) continue;
      for (final child in parent.childElements) {
        if (child.name.local != 'chapter') continue;
        final start = parseStart(child.getAttribute('start'));
        if (start == null) continue;
        final title = (child.getAttribute('title') ?? child.innerText).trim();
        chapters.add(
          PodcastChapter(
            start: start,
            title: title.isEmpty ? '未命名章节' : title,
            toc: _tocValue(child.getAttribute('toc')),
          ),
        );
      }
    }
    return sorted(chapters);
  }

  static List<PodcastChapter> parseJsonChapters(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return const [];
      final list = decoded['chapters'];
      if (list is! List) return const [];
      final chapters = <PodcastChapter>[];
      for (final item in list) {
        if (item is! Map) continue;
        final start = parseStart(item['startTime'] ?? item['start']);
        if (start == null) continue;
        final title = '${item['title'] ?? ''}'.trim();
        chapters.add(
          PodcastChapter(
            start: start,
            title: title.isEmpty ? '未命名章节' : title,
            toc: _tocValue(item['toc']),
          ),
        );
      }
      return sorted(chapters);
    } catch (_) {
      return const [];
    }
  }

  /// JSON 请求成功时用 JSON（即使为空）；失败则用 Podlove。
  static List<PodcastChapter> merge({
    required List<PodcastChapter>? jsonChapters,
    required List<PodcastChapter> podlove,
  }) {
    if (jsonChapters != null) return jsonChapters;
    return podlove;
  }

  static List<PodcastChapter> sorted(List<PodcastChapter> chapters) {
    final copy = [...chapters];
    copy.sort((a, b) => a.start.compareTo(b.start));
    return copy;
  }

  static List<PodcastChapter> tocOf(List<PodcastChapter> chapters) {
    return [for (final chapter in chapters) if (chapter.toc) chapter];
  }

  static PodcastChapter? atPosition({
    required List<PodcastChapter> chapters,
    required Duration position,
  }) {
    PodcastChapter? current;
    for (final chapter in chapters) {
      if (chapter.start <= position) {
        current = chapter;
      } else {
        break;
      }
    }
    return current;
  }

  static Duration? parseStart(Object? raw) {
    if (raw is num) {
      if (raw.isNegative) return null;
      return Duration(milliseconds: (raw * 1000).round());
    }
    if (raw is! String) return null;
    final text = raw.trim();
    if (text.isEmpty) return null;
    if (text.contains(':')) {
      final parts = text.split(':');
      if (parts.length < 2 || parts.length > 3) return null;
      final nums = <double>[];
      for (final part in parts) {
        final value = double.tryParse(part);
        if (value == null) return null;
        nums.add(value);
      }
      final seconds = nums.length == 3
          ? nums[0] * 3600 + nums[1] * 60 + nums[2]
          : nums[0] * 60 + nums[1];
      if (seconds.isNegative) return null;
      return Duration(milliseconds: (seconds * 1000).round());
    }
    final seconds = double.tryParse(text);
    if (seconds == null || seconds.isNegative) return null;
    return Duration(milliseconds: (seconds * 1000).round());
  }

  static bool _tocValue(Object? raw) {
    if (raw == null) return true;
    if (raw is bool) return raw;
    final text = raw.toString().trim().toLowerCase();
    return text != 'false' && text != '0';
  }
}
