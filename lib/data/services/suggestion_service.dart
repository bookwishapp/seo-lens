import 'package:supabase_flutter/supabase_flutter.dart';
import '../../supabase_config.dart';
import '../models/suggestion.dart';

class SuggestionService {
  final SupabaseClient _client = supabase;

  /// Get all suggestions for the current user
  Future<List<Suggestion>> getSuggestions({
    SuggestionStatus? status,
    SuggestionSeverity? severity,
  }) async {
    var query = _client.from('suggestions').select();

    if (status != null) {
      query = query.eq('status', status.toDbString());
    }
    if (severity != null) {
      query = query.eq('severity', severity.name);
    }

    final response = await query.order('created_at', ascending: false);
    return (response as List)
        .map((json) => Suggestion.fromJson(json))
        .toList();
  }

  /// Get suggestions for a specific domain
  Future<List<Suggestion>> getSuggestionsForDomain(String domainId) async {
    final response = await _client
        .from('suggestions')
        .select()
        .eq('domain_id', domainId)
        .order('created_at', ascending: false);

    return (response as List)
        .map((json) => Suggestion.fromJson(json))
        .toList();
  }

  /// Create a new suggestion
  Future<Suggestion> createSuggestion({
    required String userId,
    String? domainId,
    String? pageId,
    required String suggestionType,
    required String title,
    String? description,
    required SuggestionSeverity severity,
  }) async {
    final response = await _client
        .from('suggestions')
        .insert({
          'user_id': userId,
          if (domainId != null) 'domain_id': domainId,
          if (pageId != null) 'page_id': pageId,
          'suggestion_type': suggestionType,
          'title': title,
          if (description != null) 'description': description,
          'severity': severity.name,
        })
        .select()
        .single();

    return Suggestion.fromJson(response);
  }

  /// Update suggestion status
  Future<Suggestion> updateSuggestionStatus({
    required String suggestionId,
    required SuggestionStatus status,
  }) async {
    final response = await _client
        .from('suggestions')
        .update({
          'status': status.toDbString(),
          if (status == SuggestionStatus.resolved)
            'resolved_at': DateTime.now().toIso8601String(),
        })
        .eq('id', suggestionId)
        .select()
        .single();

    return Suggestion.fromJson(response);
  }

  /// Delete a suggestion
  Future<void> deleteSuggestion(String suggestionId) async {
    await _client.from('suggestions').delete().eq('id', suggestionId);
  }

  /// Get suggestion count by status
  Future<Map<String, int>> getSuggestionCounts() async {
    final response = await _client.from('suggestions').select('status');

    final counts = <String, int>{
      'open': 0,
      'in_progress': 0,
      'resolved': 0,
      'ignored': 0,
    };

    for (var item in response as List) {
      final status = item['status'] as String;
      counts[status] = (counts[status] ?? 0) + 1;
    }

    return counts;
  }
}
