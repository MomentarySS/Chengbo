import '../audio/podcast_chapters.dart';

export '../audio/podcast_chapters.dart' show PodcastChapter;

/// 播客与 RSS 单集模型。
class PodcastFeed {

  factory PodcastFeed.fromJson(Map<String, dynamic> json) {
    return PodcastFeed(
      id: json['id'] as String,
      title: json['title'] as String,
      feedUrl: json['feedUrl'] as String,
      description: json['description'] as String?,
      homepage: json['homepage'] as String?,
      imageUrl: json['imageUrl'] as String?,
    );
  }
  const PodcastFeed({
    required this.id,
    required this.title,
    required this.feedUrl,
    this.description,
    this.homepage,
    this.imageUrl,
  });

  final String id;
  final String title;
  final String feedUrl;
  final String? description;
  final String? homepage;
  final String? imageUrl;
}

class PodcastEpisode {
  const PodcastEpisode({
    required this.guid,
    required this.title,
    required this.audioUrl,
    this.description,
    this.publishedAt,
    this.duration,
    this.imageUrl,
    this.chaptersUrl,
    this.chapters = const [],
  });

  final String guid;
  final String title;
  final String audioUrl;
  final String? description;
  final DateTime? publishedAt;
  final Duration? duration;
  final String? imageUrl;
  final String? chaptersUrl;
  final List<PodcastChapter> chapters;
}

class PodcastDetail {
  const PodcastDetail({
    required this.feed,
    required this.episodes,
  });

  final PodcastFeed feed;
  final List<PodcastEpisode> episodes;
}
