class SitePage {
  final String id;
  final String domainId;
  final String url;
  final int? httpStatus;
  final String? title;
  final String? metaDescription;
  final String? canonicalUrl;
  final String? robotsDirective;
  final String? h1;
  final String? contentHash;
  final DateTime firstSeenAt;
  final DateTime lastScannedAt;

  SitePage({
    required this.id,
    required this.domainId,
    required this.url,
    this.httpStatus,
    this.title,
    this.metaDescription,
    this.canonicalUrl,
    this.robotsDirective,
    this.h1,
    this.contentHash,
    required this.firstSeenAt,
    required this.lastScannedAt,
  });

  factory SitePage.fromJson(Map<String, dynamic> json) {
    return SitePage(
      id: json['id'] as String,
      domainId: json['domain_id'] as String,
      url: json['url'] as String,
      httpStatus: json['http_status'] as int?,
      title: json['title'] as String?,
      metaDescription: json['meta_description'] as String?,
      canonicalUrl: json['canonical_url'] as String?,
      robotsDirective: json['robots_directive'] as String?,
      h1: json['h1'] as String?,
      contentHash: json['content_hash'] as String?,
      firstSeenAt: DateTime.parse(json['first_seen_at'] as String),
      lastScannedAt: DateTime.parse(json['last_scanned_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'domain_id': domainId,
      'url': url,
      'http_status': httpStatus,
      'title': title,
      'meta_description': metaDescription,
      'canonical_url': canonicalUrl,
      'robots_directive': robotsDirective,
      'h1': h1,
      'content_hash': contentHash,
      'first_seen_at': firstSeenAt.toIso8601String(),
      'last_scanned_at': lastScannedAt.toIso8601String(),
    };
  }

  /// Check if page has SEO issues
  bool get hasSeoIssues {
    return (title == null || title!.isEmpty) ||
        (metaDescription == null || metaDescription!.isEmpty) ||
        (robotsDirective != null && robotsDirective!.contains('noindex'));
  }

  /// Get list of SEO issues
  List<String> get seoIssues {
    final issues = <String>[];
    if (title == null || title!.isEmpty) {
      issues.add('Missing title tag');
    }
    if (metaDescription == null || metaDescription!.isEmpty) {
      issues.add('Missing meta description');
    }
    if (robotsDirective != null && robotsDirective!.contains('noindex')) {
      issues.add('Page is set to noindex');
    }
    if (canonicalUrl != null && !canonicalUrl!.contains(domainId)) {
      issues.add('Canonical URL points to external domain');
    }
    return issues;
  }
}
