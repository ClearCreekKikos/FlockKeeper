// lib/app/config.dart
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Application configuration for external services.
///
/// Credentials are loaded from the `.env` file in the project root.
/// The `.env` file is listed as an asset in pubspec.yaml so it is
/// bundled with the app at build time.
///
/// To configure:
/// 1. Edit the `.env` file in the project root
/// 2. Fill in your actual Supabase URL and Anon Key:
///    SUPABASE_URL=https://yourproject.supabase.co
///    SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
///
/// Alternatively, you can still pass them via --dart-define at build time:
///    flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
class AppConfig {
  /// The Supabase Project URL.
  /// Reads from .env file first, then falls back to --dart-define, then placeholder.
  static String get supabaseUrl {
    // Try .env file first
    final envVal = dotenv.maybeGet('SUPABASE_URL');
    if (envVal != null &&
        envVal.isNotEmpty &&
        envVal != 'YOUR_SUPABASE_PROJECT_URL') {
      return envVal;
    }
    // Fall back to --dart-define compile-time constant
    const dartDefine = String.fromEnvironment(
      'SUPABASE_URL',
      defaultValue: 'YOUR_SUPABASE_PROJECT_URL',
    );
    return dartDefine;
  }

  /// The Supabase Anon API Key.
  /// Reads from .env file first, then falls back to --dart-define, then placeholder.
  static String get supabaseAnonKey {
    // Try .env file first
    final envVal = dotenv.maybeGet('SUPABASE_ANON_KEY');
    if (envVal != null &&
        envVal.isNotEmpty &&
        envVal != 'YOUR_SUPABASE_ANON_KEY') {
      return envVal;
    }
    // Fall back to --dart-define compile-time constant
    const dartDefine = String.fromEnvironment(
      'SUPABASE_ANON_KEY',
      defaultValue: 'YOUR_SUPABASE_ANON_KEY',
    );
    return dartDefine;
  }

  /// Check if configuration is valid (not using default placeholder values)
  static bool get isConfigured {
    return supabaseUrl != 'YOUR_SUPABASE_PROJECT_URL' &&
        supabaseUrl.isNotEmpty &&
        supabaseAnonKey != 'YOUR_SUPABASE_ANON_KEY' &&
        supabaseAnonKey.isNotEmpty;
  }
}
