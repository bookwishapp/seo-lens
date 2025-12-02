import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase configuration
///
/// IMPORTANT: Replace these values with your actual Supabase credentials
/// Get these from your Supabase project settings: https://app.supabase.com
class SupabaseConfig {
  // TODO: Replace with your Supabase project URL
  static const String supabaseUrl = 'YOUR_SUPABASE_URL_HERE';

  // TODO: Replace with your Supabase anon/public key
  static const String supabaseAnonKey = 'YOUR_SUPABASE_ANON_KEY_HERE';

  /// Initialize Supabase
  static Future<void> initialize() async {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
      ),
    );
  }
}

/// Global Supabase client instance
final supabase = Supabase.instance.client;
