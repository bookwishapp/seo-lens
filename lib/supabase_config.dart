import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase configuration
///
/// IMPORTANT: Replace these values with your actual Supabase credentials
/// Get these from your Supabase project settings: https://app.supabase.com
class SupabaseConfig {
  // Supabase project URL
  // Set via --dart-define=SUPABASE_URL=your_url or environment variable
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'YOUR_SUPABASE_URL_HERE',
  );

  // Supabase anon/public key
  // Set via --dart-define=SUPABASE_ANON_KEY=your_key or environment variable
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'YOUR_SUPABASE_ANON_KEY_HERE',
  );

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
