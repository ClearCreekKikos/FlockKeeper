# FlockKeeper Setup Guide

## Environment Configuration

FlockKeeper uses environment variables to securely manage sensitive credentials like Supabase API keys.

### Quick Start

1. **Copy the environment template**:
   ```bash
   cp .env.example .env
   ```

2. **Edit `.env` with your actual credentials**:
   ```bash
   # Open in your preferred editor
   nano .env   # or vim, code, etc.
   ```

3. **Add your Supabase credentials**:
   ```env
   SUPABASE_URL=https://yourprojectid.supabase.co
   SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
   ```

   Get these values from your Supabase project dashboard at [https://supabase.com](https://supabase.com).

### Running the Application

#### Option 1: Using --dart-define (Recommended for CI/CD)

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://yourproject.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your_anon_key_here
```

#### Option 2: Using flutter_dotenv Package (Future Enhancement)

To use .env files automatically, add `flutter_dotenv` to `pubspec.yaml`:

```yaml
dependencies:
  flutter_dotenv: ^5.1.0
```

Then update [`lib/app/config.dart`](../lib/app/config.dart) to load from .env:

```dart
import 'package:flutter_dotenv/flutter_dotenv.dart';

// In main():
await dotenv.load(fileName: ".env");

// In AppConfig:
static final String supabaseUrl = dotenv.env['SUPABASE_URL'] ?? '';
```

## Security Best Practices

### ⚠️ NEVER commit these files to version control:
- `.env`
- `.env.local`
- `.env.*.local`
- Any file containing real API keys or passwords

### ✅ DO commit these files:
- `.env.example` (with placeholder values only)
- `.gitignore` (configured to exclude .env files)

### For Production Builds

#### Android
Use build configuration or gradle properties:

```bash
flutter build apk \
  --dart-define=SUPABASE_URL=$SUPABASE_URL \
  --dart-define=SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY
```

#### iOS
Use Xcode schemes or environment variables in build settings.

#### Desktop (Windows, macOS, Linux)
Set environment variables before building or use --dart-define flags.

## Troubleshooting

### Error: "Supabase URL or Anon Key is not configured"

**Cause**: The app is using default placeholder values.

**Solution**: 
1. Verify your `.env` file exists and has valid credentials
2. If using --dart-define, ensure both SUPABASE_URL and SUPABASE_ANON_KEY are provided
3. Check that credentials don't have typos or extra spaces

### Error: "Sync disabled or credentials not configured"

**Cause**: Supabase configuration is not properly set up.

**Solution**:
1. Ensure environment variables are set correctly
2. Enable sync in Settings → Sync Settings
3. Log in to your Supabase account through the app

## Development Workflow

### Local Development
```bash
# Copy template (first time only)
cp .env.example .env

# Edit with your dev credentials
vim .env

# Run normally (if using flutter_dotenv)
flutter run

# Or with --dart-define
flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
```

### Team Development
- Each developer maintains their own `.env` file (gitignored)
- Share the `.env.example` template through version control
- Document any new environment variables in `.env.example`

## Additional Resources

- [Supabase Documentation](https://supabase.com/docs)
- [Flutter Environment Variables](https://docs.flutter.dev/deployment/flavors)
- [Security Best Practices](https://docs.flutter.dev/security)
