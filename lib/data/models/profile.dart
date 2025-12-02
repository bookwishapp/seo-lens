class Profile {
  final String id;
  final DateTime createdAt;
  final String? displayName;
  final String? primaryDomainId;

  Profile({
    required this.id,
    required this.createdAt,
    this.displayName,
    this.primaryDomainId,
  });

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      id: json['id'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      displayName: json['display_name'] as String?,
      primaryDomainId: json['primary_domain_id'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'created_at': createdAt.toIso8601String(),
      'display_name': displayName,
      'primary_domain_id': primaryDomainId,
    };
  }

  Profile copyWith({
    String? id,
    DateTime? createdAt,
    String? displayName,
    String? primaryDomainId,
  }) {
    return Profile(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      displayName: displayName ?? this.displayName,
      primaryDomainId: primaryDomainId ?? this.primaryDomainId,
    );
  }
}
