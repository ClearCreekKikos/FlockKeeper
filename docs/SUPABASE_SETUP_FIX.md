# Supabase URL and Key Not Loading - Quick Fix

## Problem

`String.fromEnvironment()` requires values to be passed at **compile time** via `--dart-define` flags. The `.env` file alone won't work without additional configuration.

## Quick Solution Options

### Option 1: Use --dart-define Flags (Immediate Fix)

**For Development:**
```bash
flutter run \
  --dart-define=SUPABASE_URL=https://jerayxfpwtdngyljdudk.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImplcmF5eGZwd3Rkbmd5bGpkdWRrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODE4OTA0ODUsImV4cCI6MjA5NzQ2NjQ4NX0.arG4xW2tbhS-OgATmhQfN3f8nxBCFHQ-jqH9Q901hEM
```

**For VS Code:**
Add to `.vscode/launch.json`:
```json
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "flockkeeper",
      "request": "launch",
      "type": "dart",
      "args": [
        "--dart-define=SUPABASE_URL=https://jerayxfpwtdngyljdudk.supabase.co",
        "--dart-define=SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImplcmF5eGZwd3Rkbmd5bGpkdWRrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODE4OTA0ODUsImV4cCI6MjA5NzQ2NjQ4NX0.arG4xW2tbhS-OgATmhQfN3f8nxBCFHQ-jqH9Q901hEM"
      ]
    }
  ]
}
```

### Option 2: Temporary Development Fix (Use Original Values)

For **local development only**, you can temporarily restore the original hardcoded values in `lib/app/config.dart`:

**⚠️ WARNING: Only for local dev, NEVER commit these values to git!**

```dart
class AppConfig {
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://jerayxfpwtdngyljdudk.supabase.co', // TEMP: for local dev
  );

  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImplcmF5eGZwd3Rkbmd5bGpkdWRrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODE4OTA0ODUsImV4cCI6MjA5NzQ2NjQ4NX0.arG4xW2tbhS-OgATmhQfN3f8nxBCFHQ-jqH9Q901hEM', // TEMP: for local dev
  );
  
  static bool get isConfigured => true; // For dev convenience
}
```

### Option 3: Implement flutter_dotenv (Recommended Long-term)

This allows automatic .env file loading at runtime.

**Step 1: Add dependency to `pubspec.yaml`:**
```yaml
dependencies:
  flutter_dotenv: ^5.1.0
```

**Step 2: Add .env to assets in `pubspec.yaml`:**
```yaml
flutter:
  assets:
    - .env
```

**Step 3: Update `lib/main.dart`:**
```dart
import 'package:flutter_dotenv/flutter_dotenv.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Load .env file
  await dotenv.load(fileName: ".env");
  
  // Rest of initialization...
}
```

**Step 4: Update `lib/app/config.dart`:**
```dart
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  static String get supabaseUrl {
    return dotenv.env['SUPABASE_URL'] ?? 'YOUR_SUPABASE_PROJECT_URL';
  }

  static String get supabaseAnonKey {
    return dotenv.env['SUPABASE_ANON_KEY'] ?? 'YOUR_SUPABASE_ANON_KEY';
  }
  
  static bool get isConfigured {
    return supabaseUrl != 'YOUR_SUPABASE_PROJECT_URL' &&
           supabaseUrl.isNotEmpty &&
           supabaseAnonKey != 'YOUR_SUPABASE_ANON_KEY' &&
           supabaseAnonKey.isNotEmpty;
  }
}
```

## Why Isn't .env Working?

`String.fromEnvironment()` is a **compile-time** constant that reads from:
- Command-line `--dart-define` flags
- Build system environment variables
- IDE run configurations

It does **NOT** read from `.env` files at runtime unless you use a package like `flutter_dotenv`.

## Testing the Fix

After applying one of the solutions above, verify:

```dart
// Add temporary debug print in lib/main.dart
debugPrint('Supabase URL: ${AppConfig.supabaseUrl}');
debugPrint('Config valid: ${AppConfig.isConfigured}');
```

You should see your actual Supabase URL in the console, not the placeholder.

## Recommended Approach

For immediate use: **Option 1** (--dart-define flags) or **Option 2** (temporary hardcode for dev)  
For production: **Option 3** (flutter_dotenv package)

## Important Security Notes

- **NEVER commit real credentials** to git (even in defaultValue)
- If using Option 2, **undo it** before committing
- For production builds, always use Option 1 or 3
- Consider rotating your Supabase keys if they were exposed

## Need Help?

Check the debug console output when the app starts. Look for:
- "Supabase initialization failed" errors
- "Supabase URL or Anon Key is not configured" warnings
- The actual URL/key values being used (in debug mode)
