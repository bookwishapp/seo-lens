import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../supabase_config.dart';
import 'models/domain.dart';
import 'models/domain_status.dart';
import 'models/profile.dart';
import 'models/site_page.dart';
import 'models/suggestion.dart';
import 'services/auth_service.dart';
import 'services/billing_service.dart';
import 'services/domain_service.dart';
import 'services/scan_service.dart';
import 'services/suggestion_service.dart';

// ============================================================================
// SERVICE PROVIDERS
// ============================================================================

final authServiceProvider = Provider<AuthService>((ref) => AuthService());

final billingServiceProvider =
    Provider<BillingService>((ref) => BillingService());

final domainServiceProvider =
    Provider<DomainService>((ref) => DomainService());

final suggestionServiceProvider =
    Provider<SuggestionService>((ref) => SuggestionService());

final scanServiceProvider = Provider<ScanService>((ref) => ScanService());

// ============================================================================
// AUTH PROVIDERS
// ============================================================================

/// Current auth state stream
final authStateProvider = StreamProvider<AuthState>((ref) {
  return supabase.auth.onAuthStateChange;
});

/// Current user provider
final currentUserProvider = Provider<User?>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.maybeWhen(
    data: (state) => state.session?.user,
    orElse: () => null,
  );
});

/// Current user profile provider
final currentProfileProvider = FutureProvider<Profile?>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;

  final authService = ref.watch(authServiceProvider);
  return authService.getProfile(user.id);
});

// ============================================================================
// DOMAIN PROVIDERS
// ============================================================================

/// All domains for current user
final domainsProvider = FutureProvider<List<Domain>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return [];

  final domainService = ref.watch(domainServiceProvider);
  return domainService.getDomains();
});

/// Single domain by ID
final domainProvider =
    FutureProvider.family<Domain?, String>((ref, domainId) async {
  final domainService = ref.watch(domainServiceProvider);
  return domainService.getDomain(domainId);
});

/// Domain status by domain ID
final domainStatusProvider =
    FutureProvider.family<DomainStatus?, String>((ref, domainId) async {
  final domainService = ref.watch(domainServiceProvider);
  return domainService.getDomainStatus(domainId);
});

/// Site pages for a domain
final sitePagesProvider =
    FutureProvider.family<List<SitePage>, String>((ref, domainId) async {
  final domainService = ref.watch(domainServiceProvider);
  return domainService.getSitePages(domainId);
});

/// Domain stats summary
final domainStatsProvider = FutureProvider<Map<String, int>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) {
    return {
      'total': 0,
      'live': 0,
      'redirect': 0,
      'broken': 0,
      'unknown': 0,
    };
  }

  final domainService = ref.watch(domainServiceProvider);
  return domainService.getDomainStats(user.id);
});

// ============================================================================
// SUGGESTION PROVIDERS
// ============================================================================

/// All suggestions for current user
final suggestionsProvider = FutureProvider<List<Suggestion>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return [];

  final suggestionService = ref.watch(suggestionServiceProvider);
  return suggestionService.getSuggestions();
});

/// Suggestions filtered by status
final suggestionsByStatusProvider = FutureProvider.family<List<Suggestion>,
    SuggestionStatus?>((ref, status) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return [];

  final suggestionService = ref.watch(suggestionServiceProvider);
  return suggestionService.getSuggestions(status: status);
});

/// Suggestions for a specific domain
final domainSuggestionsProvider =
    FutureProvider.family<List<Suggestion>, String>((ref, domainId) async {
  final suggestionService = ref.watch(suggestionServiceProvider);
  return suggestionService.getSuggestionsForDomain(domainId);
});

/// Suggestion counts by status
final suggestionCountsProvider =
    FutureProvider<Map<String, int>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) {
    return {'open': 0, 'in_progress': 0, 'resolved': 0, 'ignored': 0};
  }

  final suggestionService = ref.watch(suggestionServiceProvider);
  return suggestionService.getSuggestionCounts();
});

// ============================================================================
// UI STATE PROVIDERS
// ============================================================================

/// Pending upgrade plan (persists across navigation during auth flow)
final pendingUpgradePlanProvider = StateProvider<String?>((ref) => null);

/// Search query for domains
final domainSearchQueryProvider = StateProvider<String>((ref) => '');

/// Selected domain status filter
final domainStatusFilterProvider = StateProvider<String?>((ref) => null);

/// Selected suggestion filter
final suggestionFilterProvider = StateProvider<String?>((ref) => null);
