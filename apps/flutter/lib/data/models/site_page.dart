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
  final String? primaryKeyword;

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
    this.primaryKeyword,
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
      primaryKeyword: json['primary_keyword'] as String?,
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
      'primary_keyword': primaryKeyword,
    };
  }

  /// Create a copy with updated fields
  SitePage copyWith({
    String? id,
    String? domainId,
    String? url,
    int? httpStatus,
    String? title,
    String? metaDescription,
    String? canonicalUrl,
    String? robotsDirective,
    String? h1,
    String? contentHash,
    DateTime? firstSeenAt,
    DateTime? lastScannedAt,
    String? primaryKeyword,
  }) {
    return SitePage(
      id: id ?? this.id,
      domainId: domainId ?? this.domainId,
      url: url ?? this.url,
      httpStatus: httpStatus ?? this.httpStatus,
      title: title ?? this.title,
      metaDescription: metaDescription ?? this.metaDescription,
      canonicalUrl: canonicalUrl ?? this.canonicalUrl,
      robotsDirective: robotsDirective ?? this.robotsDirective,
      h1: h1 ?? this.h1,
      contentHash: contentHash ?? this.contentHash,
      firstSeenAt: firstSeenAt ?? this.firstSeenAt,
      lastScannedAt: lastScannedAt ?? this.lastScannedAt,
      primaryKeyword: primaryKeyword ?? this.primaryKeyword,
    );
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

  /// Check if a primary keyword is set
  bool get hasPrimaryKeyword =>
      primaryKeyword != null && primaryKeyword!.trim().isNotEmpty;

  /// Check if keyword appears in text (case-insensitive)
  static bool containsKeyword(String? text, String? keyword) {
    if (text == null || text.isEmpty || keyword == null || keyword.isEmpty) {
      return false;
    }
    return text.toLowerCase().contains(keyword.toLowerCase());
  }

  /// Check if keyword appears in title
  bool get keywordInTitle => containsKeyword(title, primaryKeyword);

  /// Check if keyword appears in meta description
  bool get keywordInMeta => containsKeyword(metaDescription, primaryKeyword);

  /// Check if keyword appears in H1
  bool get keywordInH1 => containsKeyword(h1, primaryKeyword);

  /// Check if keyword appears in URL
  bool get keywordInUrl => containsKeyword(url, primaryKeyword);

  /// Get keyword alignment score (0-4 based on title, meta, h1, url)
  int get keywordAlignmentScore {
    if (!hasPrimaryKeyword) return 0;
    int score = 0;
    if (keywordInTitle) score++;
    if (keywordInMeta) score++;
    if (keywordInH1) score++;
    if (keywordInUrl) score++;
    return score;
  }

  /// Get keyword alignment issues
  List<String> get keywordIssues {
    if (!hasPrimaryKeyword) return [];
    final issues = <String>[];
    if (!keywordInTitle) {
      issues.add('Primary keyword not in title');
    }
    if (!keywordInMeta) {
      issues.add('Primary keyword not in meta description');
    }
    if (!keywordInH1) {
      issues.add('Primary keyword not in H1');
    }
    return issues;
  }
}
