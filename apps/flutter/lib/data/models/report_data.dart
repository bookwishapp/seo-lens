// lib/data/models/report_data.dart
// Models for public report data

class ReportData {
  final DomainSummary domain;
  final OwnerSummary owner;
  final List<ReportPage> pages;
  final List<ReportSuggestion> suggestions;

  ReportData({
    required this.domain,
    required this.owner,
    required this.pages,
    required this.suggestions,
  });

  factory ReportData.fromJson(Map<String, dynamic> json) {
    return ReportData(
      domain: DomainSummary.fromJson(json['domain'] as Map<String, dynamic>),
      owner: OwnerSummary.fromJson(json['owner'] as Map<String, dynamic>),
      pages: (json['pages'] as List<dynamic>)
          .map((p) => ReportPage.fromJson(p as Map<String, dynamic>))
          .toList(),
      suggestions: (json['suggestions'] as List<dynamic>)
          .map((s) => ReportSuggestion.fromJson(s as Map<String, dynamic>))
          .toList(),
    );
  }

  /// Get issue count by severity
  int get highSeverityCount =>
      suggestions.where((s) => s.severity == 'high').length;
  int get mediumSeverityCount =>
      suggestions.where((s) => s.severity == 'medium').length;
  int get lowSeverityCount =>
      suggestions.where((s) => s.severity == 'low').length;

  /// Group suggestions by type
  Map<String, List<ReportSuggestion>> get suggestionsByType {
    final map = <String, List<ReportSuggestion>>{};
    for (final s in suggestions) {
      map.putIfAbsent(s.type, () => []).add(s);
    }
    return map;
  }
}

class DomainSummary {
  final String id;
  final String domainName;
  final String? displayName;
  final DateTime? lastScannedAt;
  final int? healthScore;
  final int? totalPagesScanned;
  final int? pagesMissingTitle;
  final int? pagesMissingMeta;
  final int? pagesMissingH1;
  final int? pages2xx;
  final int? pages4xx;
  final int? pages5xx;
  final double? uptime24hPercent;
  final double? uptime7dPercent;
  final DateTime? lastUptimeCheckedAt;
  final int? lastResponseTimeMs;

  DomainSummary({
    required this.id,
    required this.domainName,
    this.displayName,
    this.lastScannedAt,
    this.healthScore,
    this.totalPagesScanned,
    this.pagesMissingTitle,
    this.pagesMissingMeta,
    this.pagesMissingH1,
    this.pages2xx,
    this.pages4xx,
    this.pages5xx,
    this.uptime24hPercent,
    this.uptime7dPercent,
    this.lastUptimeCheckedAt,
    this.lastResponseTimeMs,
  });

  factory DomainSummary.fromJson(Map<String, dynamic> json) {
    return DomainSummary(
      id: json['id'] as String,
      domainName: json['domainName'] as String,
      displayName: json['displayName'] as String?,
      lastScannedAt: json['lastScannedAt'] != null
          ? DateTime.parse(json['lastScannedAt'] as String)
          : null,
      healthScore: json['healthScore'] as int?,
      totalPagesScanned: json['totalPagesScanned'] as int?,
      pagesMissingTitle: json['pagesMissingTitle'] as int?,
      pagesMissingMeta: json['pagesMissingMeta'] as int?,
      pagesMissingH1: json['pagesMissingH1'] as int?,
      pages2xx: json['pages2xx'] as int?,
      pages4xx: json['pages4xx'] as int?,
      pages5xx: json['pages5xx'] as int?,
      uptime24hPercent: (json['uptime24hPercent'] as num?)?.toDouble(),
      uptime7dPercent: (json['uptime7dPercent'] as num?)?.toDouble(),
      lastUptimeCheckedAt: json['lastUptimeCheckedAt'] != null
          ? DateTime.parse(json['lastUptimeCheckedAt'] as String)
          : null,
      lastResponseTimeMs: json['lastResponseTimeMs'] as int?,
    );
  }

  String get name => displayName ?? domainName;
}

class OwnerSummary {
  final String id;
  final String? referralCode;

  OwnerSummary({
    required this.id,
    this.referralCode,
  });

  factory OwnerSummary.fromJson(Map<String, dynamic> json) {
    return OwnerSummary(
      id: json['id'] as String,
      referralCode: json['referralCode'] as String?,
    );
  }

  /// Get referral signup URL
  String? get referralSignupUrl {
    if (referralCode == null) return null;
    return 'https://seolens.io/app/#/signup?ref=$referralCode';
  }
}

class ReportPage {
  final String id;
  final String url;
  final String path;
  final String? title;
  final int? statusCode;
  final int issueCount;

  ReportPage({
    required this.id,
    required this.url,
    required this.path,
    this.title,
    this.statusCode,
    required this.issueCount,
  });

  factory ReportPage.fromJson(Map<String, dynamic> json) {
    return ReportPage(
      id: json['id'] as String,
      url: json['url'] as String,
      path: json['path'] as String,
      title: json['title'] as String?,
      statusCode: json['statusCode'] as int?,
      issueCount: json['issueCount'] as int? ?? 0,
    );
  }

  bool get hasIssues => issueCount > 0;
  bool get isError => statusCode != null && statusCode! >= 400;
}

class ReportSuggestion {
  final String id;
  final String scope;
  final String type;
  final String title;
  final String? message;
  final String? severity;
  final String? pageId;
  final String? pagePath;

  ReportSuggestion({
    required this.id,
    required this.scope,
    required this.type,
    required this.title,
    this.message,
    this.severity,
    this.pageId,
    this.pagePath,
  });

  factory ReportSuggestion.fromJson(Map<String, dynamic> json) {
    return ReportSuggestion(
      id: json['id'] as String,
      scope: json['scope'] as String? ?? 'page',
      type: json['type'] as String,
      title: json['title'] as String,
      message: json['message'] as String?,
      severity: json['severity'] as String?,
      pageId: json['pageId'] as String?,
      pagePath: json['pagePath'] as String?,
    );
  }

  /// Get human-readable type name
  String get typeName {
    switch (type) {
      case 'missing_or_short_title':
        return 'Missing/Short Title';
      case 'title_too_long':
        return 'Title Too Long';
      case 'missing_meta_description':
        return 'Missing Meta Description';
      case 'short_meta_description':
        return 'Short Meta Description';
      case 'long_meta_description':
        return 'Long Meta Description';
      case 'missing_h1':
        return 'Missing H1';
      case 'canonical_points_elsewhere':
        return 'Canonical Issue';
      case 'invalid_canonical':
        return 'Invalid Canonical';
      case 'noindex_set':
        return 'Noindex Set';
      case 'page_error_status':
        return 'Page Error';
      default:
        return type.replaceAll('_', ' ').split(' ').map((w) =>
            w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : w
        ).join(' ');
    }
  }
}
