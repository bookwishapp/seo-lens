enum SuggestionSeverity {
  low,
  medium,
  high;

  String get label => name[0].toUpperCase() + name.substring(1);

  static SuggestionSeverity fromString(String? value) {
    switch (value) {
      case 'high':
        return SuggestionSeverity.high;
      case 'medium':
        return SuggestionSeverity.medium;
      case 'low':
        return SuggestionSeverity.low;
      default:
        return SuggestionSeverity.medium;
    }
  }
}

/// Impact area - what part of SEO does this affect
enum SuggestionImpact {
  visibility,    // Affects search rankings
  clickThrough,  // Affects CTR in search results
  technical,     // Technical SEO issues
  trust,         // Trust signals
  essentials;    // Basic on-page elements

  String get label {
    switch (this) {
      case SuggestionImpact.clickThrough:
        return 'Click-through';
      case SuggestionImpact.visibility:
        return 'Visibility';
      case SuggestionImpact.technical:
        return 'Technical';
      case SuggestionImpact.trust:
        return 'Trust';
      case SuggestionImpact.essentials:
        return 'Essentials';
    }
  }

  static SuggestionImpact fromString(String? value) {
    switch (value) {
      case 'visibility':
        return SuggestionImpact.visibility;
      case 'click_through':
        return SuggestionImpact.clickThrough;
      case 'technical':
        return SuggestionImpact.technical;
      case 'trust':
        return SuggestionImpact.trust;
      case 'essentials':
        return SuggestionImpact.essentials;
      default:
        return SuggestionImpact.technical;
    }
  }

  String toDbString() {
    switch (this) {
      case SuggestionImpact.clickThrough:
        return 'click_through';
      default:
        return name;
    }
  }
}

/// Effort required to fix this issue
enum SuggestionEffort {
  quickWin,     // Easy fix, immediate improvement
  moderate,     // Some work required
  deepChange;   // Significant effort needed

  String get label {
    switch (this) {
      case SuggestionEffort.quickWin:
        return 'Quick win';
      case SuggestionEffort.moderate:
        return 'Moderate';
      case SuggestionEffort.deepChange:
        return 'Deep change';
    }
  }

  static SuggestionEffort fromString(String? value) {
    switch (value) {
      case 'quick_win':
        return SuggestionEffort.quickWin;
      case 'moderate':
        return SuggestionEffort.moderate;
      case 'deep_change':
        return SuggestionEffort.deepChange;
      default:
        return SuggestionEffort.moderate;
    }
  }

  String toDbString() {
    switch (this) {
      case SuggestionEffort.quickWin:
        return 'quick_win';
      case SuggestionEffort.deepChange:
        return 'deep_change';
      default:
        return name;
    }
  }
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
  final SuggestionImpact impact;
  final SuggestionEffort effort;
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
    required this.impact,
    required this.effort,
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
      severity: SuggestionSeverity.fromString(json['severity'] as String?),
      impact: SuggestionImpact.fromString(json['impact'] as String?),
      effort: SuggestionEffort.fromString(json['effort'] as String?),
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
      'impact': impact.toDbString(),
      'effort': effort.toDbString(),
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
    SuggestionImpact? impact,
    SuggestionEffort? effort,
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
      impact: impact ?? this.impact,
      effort: effort ?? this.effort,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      resolvedAt: resolvedAt ?? this.resolvedAt,
    );
  }

  /// Get explanation text for this suggestion type
  String get explanation {
    switch (suggestionType) {
      case 'missing_or_short_title':
        return 'Page titles help search engines and users understand what your page is about. A good title improves click-through rates.';
      case 'title_too_long':
        return 'Long titles get truncated in search results, which can reduce click-through rates.';
      case 'missing_meta_description':
        return 'Meta descriptions appear in search results and can significantly impact click-through rates.';
      case 'short_meta_description':
        return 'Short descriptions may not provide enough context to encourage clicks.';
      case 'long_meta_description':
        return 'Long descriptions get truncated in search results.';
      case 'canonical_points_elsewhere':
        return 'The canonical URL points to a different domain, which may cause indexing issues.';
      case 'invalid_canonical':
        return 'An invalid canonical URL can confuse search engines about the preferred version of this page.';
      case 'missing_h1':
        return 'H1 headings help structure content and signal the main topic to search engines.';
      case 'noindex_set':
        return 'This page is set to noindex, meaning search engines will not include it in results.';
      case 'page_error_status':
        return 'Error pages negatively impact user experience and can hurt SEO.';
      default:
        return 'This issue may affect your site\'s SEO performance.';
    }
  }

  /// Get action text for this suggestion type
  String get actionText {
    switch (suggestionType) {
      case 'missing_or_short_title':
        return 'Add a descriptive title tag between 30-60 characters.';
      case 'title_too_long':
        return 'Shorten your title to under 60 characters.';
      case 'missing_meta_description':
        return 'Add a compelling meta description between 120-160 characters.';
      case 'short_meta_description':
        return 'Expand your meta description to at least 120 characters.';
      case 'long_meta_description':
        return 'Shorten your meta description to under 160 characters.';
      case 'canonical_points_elsewhere':
        return 'Review and update the canonical URL to point to the correct domain.';
      case 'invalid_canonical':
        return 'Fix the canonical URL format to be a valid absolute URL.';
      case 'missing_h1':
        return 'Add a clear H1 heading that describes the page content.';
      case 'noindex_set':
        return 'Remove the noindex directive if you want this page indexed.';
      case 'page_error_status':
        return 'Fix the error or remove links pointing to this page.';
      default:
        return 'Review and fix this issue to improve SEO.';
    }
  }
}
