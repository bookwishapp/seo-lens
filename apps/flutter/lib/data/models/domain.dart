class Domain {
  final String id;
  final String userId;
  final String domainName;
  final String? label;
  final String? projectTag;
  final String? registrarName;
  final DateTime? expiryDate;
  final String? notes;
  final String? preferredUrl;
  final String? preferredRedirectProvider;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Health score and summary fields
  final int? healthScore;
  final int? totalPagesScanned;
  final int? pagesMissingTitle;
  final int? pagesMissingMeta;
  final int? pagesMissingH1;
  final int? pages2xx;
  final int? pages4xx;
  final int? pages5xx;
  final DateTime? lastScanAt;

  Domain({
    required this.id,
    required this.userId,
    required this.domainName,
    this.label,
    this.projectTag,
    this.registrarName,
    this.expiryDate,
    this.notes,
    this.preferredUrl,
    this.preferredRedirectProvider,
    required this.createdAt,
    required this.updatedAt,
    this.healthScore,
    this.totalPagesScanned,
    this.pagesMissingTitle,
    this.pagesMissingMeta,
    this.pagesMissingH1,
    this.pages2xx,
    this.pages4xx,
    this.pages5xx,
    this.lastScanAt,
  });

  factory Domain.fromJson(Map<String, dynamic> json) {
    return Domain(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      domainName: json['domain_name'] as String,
      label: json['label'] as String?,
      projectTag: json['project_tag'] as String?,
      registrarName: json['registrar_name'] as String?,
      expiryDate: json['expiry_date'] != null
          ? DateTime.parse(json['expiry_date'] as String)
          : null,
      notes: json['notes'] as String?,
      preferredUrl: json['preferred_url'] as String?,
      preferredRedirectProvider: json['preferred_redirect_provider'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      healthScore: json['health_score'] as int?,
      totalPagesScanned: json['total_pages_scanned'] as int?,
      pagesMissingTitle: json['pages_missing_title'] as int?,
      pagesMissingMeta: json['pages_missing_meta'] as int?,
      pagesMissingH1: json['pages_missing_h1'] as int?,
      pages2xx: json['pages_2xx'] as int?,
      pages4xx: json['pages_4xx'] as int?,
      pages5xx: json['pages_5xx'] as int?,
      lastScanAt: json['last_scan_at'] != null
          ? DateTime.parse(json['last_scan_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'domain_name': domainName,
      'label': label,
      'project_tag': projectTag,
      'registrar_name': registrarName,
      'expiry_date': expiryDate?.toIso8601String().split('T')[0],
      'notes': notes,
      'preferred_url': preferredUrl,
      'preferred_redirect_provider': preferredRedirectProvider,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'health_score': healthScore,
      'total_pages_scanned': totalPagesScanned,
      'pages_missing_title': pagesMissingTitle,
      'pages_missing_meta': pagesMissingMeta,
      'pages_missing_h1': pagesMissingH1,
      'pages_2xx': pages2xx,
      'pages_4xx': pages4xx,
      'pages_5xx': pages5xx,
      'last_scan_at': lastScanAt?.toIso8601String(),
    };
  }

  Domain copyWith({
    String? id,
    String? userId,
    String? domainName,
    String? label,
    String? projectTag,
    String? registrarName,
    DateTime? expiryDate,
    String? notes,
    String? preferredUrl,
    String? preferredRedirectProvider,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? healthScore,
    int? totalPagesScanned,
    int? pagesMissingTitle,
    int? pagesMissingMeta,
    int? pagesMissingH1,
    int? pages2xx,
    int? pages4xx,
    int? pages5xx,
    DateTime? lastScanAt,
  }) {
    return Domain(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      domainName: domainName ?? this.domainName,
      label: label ?? this.label,
      projectTag: projectTag ?? this.projectTag,
      registrarName: registrarName ?? this.registrarName,
      expiryDate: expiryDate ?? this.expiryDate,
      notes: notes ?? this.notes,
      preferredUrl: preferredUrl ?? this.preferredUrl,
      preferredRedirectProvider: preferredRedirectProvider ?? this.preferredRedirectProvider,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      healthScore: healthScore ?? this.healthScore,
      totalPagesScanned: totalPagesScanned ?? this.totalPagesScanned,
      pagesMissingTitle: pagesMissingTitle ?? this.pagesMissingTitle,
      pagesMissingMeta: pagesMissingMeta ?? this.pagesMissingMeta,
      pagesMissingH1: pagesMissingH1 ?? this.pagesMissingH1,
      pages2xx: pages2xx ?? this.pages2xx,
      pages4xx: pages4xx ?? this.pages4xx,
      pages5xx: pages5xx ?? this.pages5xx,
      lastScanAt: lastScanAt ?? this.lastScanAt,
    );
  }

  /// Check if domain expiry is within the given number of days
  bool expiresWithinDays(int days) {
    if (expiryDate == null) return false;
    final daysUntilExpiry = expiryDate!.difference(DateTime.now()).inDays;
    return daysUntilExpiry >= 0 && daysUntilExpiry <= days;
  }

  /// Check if domain is expired
  bool get isExpired {
    if (expiryDate == null) return false;
    return expiryDate!.isBefore(DateTime.now());
  }

  /// Helper to get the display name (label or domain name)
  String get displayName => label ?? domainName;

  /// Get health score color
  HealthScoreLevel get healthScoreLevel {
    if (healthScore == null) return HealthScoreLevel.unknown;
    if (healthScore! >= 80) return HealthScoreLevel.good;
    if (healthScore! >= 60) return HealthScoreLevel.warning;
    return HealthScoreLevel.poor;
  }

  /// Get percentage of pages with title
  double get titlePercentage {
    if (totalPagesScanned == null || totalPagesScanned == 0) return 1.0;
    final missing = pagesMissingTitle ?? 0;
    return (totalPagesScanned! - missing) / totalPagesScanned!;
  }

  /// Get percentage of pages with meta description
  double get metaPercentage {
    if (totalPagesScanned == null || totalPagesScanned == 0) return 1.0;
    final missing = pagesMissingMeta ?? 0;
    return (totalPagesScanned! - missing) / totalPagesScanned!;
  }

  /// Get percentage of pages with H1
  double get h1Percentage {
    if (totalPagesScanned == null || totalPagesScanned == 0) return 1.0;
    final missing = pagesMissingH1 ?? 0;
    return (totalPagesScanned! - missing) / totalPagesScanned!;
  }

  /// Get total error pages (4xx + 5xx)
  int get totalErrorPages => (pages4xx ?? 0) + (pages5xx ?? 0);
}

enum HealthScoreLevel {
  good,
  warning,
  poor,
  unknown,
}
