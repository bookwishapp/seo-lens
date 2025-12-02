enum SuggestionSeverity {
  low,
  medium,
  high;

  String get label => name[0].toUpperCase() + name.substring(1);
}

enum SuggestionStatus {
  open,
  inProgress,
  resolved,
  ignored;

  String get label {
    switch (this) {
      case SuggestionStatus.inProgress:
        return 'In Progress';
      default:
        return name[0].toUpperCase() + name.substring(1);
    }
  }

  static SuggestionStatus fromString(String value) {
    switch (value) {
      case 'in_progress':
        return SuggestionStatus.inProgress;
      case 'resolved':
        return SuggestionStatus.resolved;
      case 'ignored':
        return SuggestionStatus.ignored;
      default:
        return SuggestionStatus.open;
    }
  }

  String toDbString() {
    switch (this) {
      case SuggestionStatus.inProgress:
        return 'in_progress';
      default:
        return name;
    }
  }
}

class Suggestion {
  final String id;
  final String userId;
  final String? domainId;
  final String? pageId;
  final String suggestionType;
  final String title;
  final String? description;
  final SuggestionSeverity severity;
  final SuggestionStatus status;
  final DateTime createdAt;
  final DateTime? resolvedAt;

  Suggestion({
    required this.id,
    required this.userId,
    this.domainId,
    this.pageId,
    required this.suggestionType,
    required this.title,
    this.description,
    required this.severity,
    required this.status,
    required this.createdAt,
    this.resolvedAt,
  });

  factory Suggestion.fromJson(Map<String, dynamic> json) {
    return Suggestion(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      domainId: json['domain_id'] as String?,
      pageId: json['page_id'] as String?,
      suggestionType: json['suggestion_type'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      severity: SuggestionSeverity.values.firstWhere(
        (s) => s.name == json['severity'],
        orElse: () => SuggestionSeverity.low,
      ),
      status: SuggestionStatus.fromString(json['status'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      resolvedAt: json['resolved_at'] != null
          ? DateTime.parse(json['resolved_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'domain_id': domainId,
      'page_id': pageId,
      'suggestion_type': suggestionType,
      'title': title,
      'description': description,
      'severity': severity.name,
      'status': status.toDbString(),
      'created_at': createdAt.toIso8601String(),
      'resolved_at': resolvedAt?.toIso8601String(),
    };
  }

  Suggestion copyWith({
    String? id,
    String? userId,
    String? domainId,
    String? pageId,
    String? suggestionType,
    String? title,
    String? description,
    SuggestionSeverity? severity,
    SuggestionStatus? status,
    DateTime? createdAt,
    DateTime? resolvedAt,
  }) {
    return Suggestion(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      domainId: domainId ?? this.domainId,
      pageId: pageId ?? this.pageId,
      suggestionType: suggestionType ?? this.suggestionType,
      title: title ?? this.title,
      description: description ?? this.description,
      severity: severity ?? this.severity,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      resolvedAt: resolvedAt ?? this.resolvedAt,
    );
  }
}
