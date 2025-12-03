import 'package:supabase_flutter/supabase_flutter.dart';
import '../../supabase_config.dart';
import '../models/profile.dart';

class AuthService {
  final SupabaseClient _client = supabase;

  /// Get current user
  User? get currentUser => _client.auth.currentUser;

  /// Check if user is authenticated
  bool get isAuthenticated => currentUser != null;

  /// Listen to auth state changes
  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  /// Sign up with email and password
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    String? displayName,
  }) async {
    final response = await _client.auth.signUp(
      email: email,
      password: password,
      data: displayName != null ? {'display_name': displayName} : null,
    );
    return response;
  }

  /// Sign in with email and password
  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    final response = await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
    return response;
  }

  /// Sign out
  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  /// Get user profile
  Future<Profile?> getProfile(String userId) async {
    final response = await _client
        .from('profiles')
        .select()
        .eq('id', userId)
        .maybeSingle();

    if (response == null) return null;
    return Profile.fromJson(response);
  }

  /// Update user profile
  Future<void> updateProfile({
    required String userId,
    String? displayName,
    String? primaryDomainId,
  }) async {
    await _client.from('profiles').update({
      if (displayName != null) 'display_name': displayName,
      if (primaryDomainId != null) 'primary_domain_id': primaryDomainId,
    }).eq('id', userId);
  }
}
