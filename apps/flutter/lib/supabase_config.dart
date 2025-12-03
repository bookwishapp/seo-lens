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
    // Validate configuration
    if (supabaseUrl == 'YOUR_SUPABASE_URL_HERE' || supabaseUrl.isEmpty) {
      throw Exception(
        'SUPABASE_URL is not set. Please set it via --dart-define=SUPABASE_URL=<your-url> '
        'or configure it in Vercel environment variables.',
      );
    }

    if (supabaseAnonKey == 'YOUR_SUPABASE_ANON_KEY_HERE' ||
        supabaseAnonKey.isEmpty) {
      throw Exception(
        'SUPABASE_ANON_KEY is not set. Please set it via --dart-define=SUPABASE_ANON_KEY=<your-key> '
        'or configure it in Vercel environment variables.',
      );
    }

    print('Initializing Supabase...');
    print('URL: ${supabaseUrl.substring(0, 20)}...');

    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
      ),
    );

    print('Supabase initialized successfully');
  }
}

/// Global Supabase client instance
final supabase = Supabase.instance.client;
