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
}
