/// 对外品牌。工程包名为 `chengbo`。版本与 `pubspec.yaml` 的 `x.y.z` 对齐。
abstract final class AppBrand {
  static const displayName = '澄波';
  static const englishSlug = 'Chengbo';

  /// 产品描述（"做什么"）：README 顶头、商店副标题用这一条。
  static const tagline = '听国内广播';

  /// 品牌口号（"气质是什么"）：关于页用这一条。
  /// 与 [tagline] 并列，不要互相替换 —— 见 PRODUCT.md 的 Brand Commitments。
  static const slogan = '静水之上，波声不息';

  static const version = '2.0.2';
  static const userAgent = 'Chengbo/$version (Flutter; chengbo radio)';
  static const podcastUserAgent = 'Chengbo/$version PodcastReader';
  static const podcastFallbackUserAgent =
      'Mozilla/5.0 (compatible; Chengbo/$version; +rss)';
}
