# FlockKeeper

Kiko Goat Herd Management Application

## 🚀 Quick Start

### Prerequisites
- Flutter SDK 3.12.2 or higher
- Dart SDK
- Supabase account (for cloud sync features)

### Setup Instructions

⚠️ **IMPORTANT: Environment Configuration Required**

Before running the application, you must configure your Supabase credentials:

#### Option 1: Create .env file (Recommended for Development)

1. A `.env` file has been created from the template
2. **Edit `.env` and add your actual Supabase credentials**:
   ```env
   SUPABASE_URL=https://yourprojectid.supabase.co
   SUPABASE_ANON_KEY=your_actual_anon_key_here
   ```
3. Get these values from your [Supabase Dashboard](https://supabase.com/dashboard)

#### Option 2: Use --dart-define flags

Run the app with credentials directly:
```bash
flutter run \
  --dart-define=SUPABASE_URL=https://yourproject.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your_anon_key_here
```

### Installation

1. **Clone the repository** (if not already done):
   ```bash
   git clone <repository-url>
   cd flockkeeper
   ```

2. **Install dependencies**:
   ```bash
   flutter pub get
   ```

3. **Configure environment** (see above)

4. **Run the application**:
   ```bash
   # Using --dart-define
   flutter run --dart-define=SUPABASE_URL=your_url --dart-define=SUPABASE_ANON_KEY=your_key
   
   # Or if you set up .env with flutter_dotenv (future enhancement)
   flutter run
   ```

### Building for Production

```bash
# Android
flutter build apk --dart-define=SUPABASE_URL=$SUPABASE_URL --dart-define=SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY

# iOS
flutter build ios --dart-define=SUPABASE_URL=$SUPABASE_URL --dart-define=SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY

# Windows
flutter build windows --dart-define=SUPABASE_URL=$SUPABASE_URL --dart-define=SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY
```

## 📱 Features

- **Animal Management**: Track individual goats with detailed records
- **Weight Tracking**: Monitor growth and health metrics
- **Breeding Management**: Track breeding events and kidding records
- **Health Records**: Vaccinations, dewormings, and health treatments
- **Financial Tracking**: Income and expenses per animal
- **Pasture Rotation**: Manage grazing areas and rotation schedules
- **Voice Commands**: Record data using voice input
- **PDF Generation**: Fill NKR (National Kiko Registry) forms
- **Cloud Sync**: Sync data across devices via Supabase
- **Multi-Platform**: Android, iOS, Windows, macOS, Linux, Web

## 📚 Documentation

- **[Setup Guide](docs/SETUP.md)** - Detailed configuration instructions
- **[Critical Fixes](docs/CRITICAL_FIXES.md)** - Recent security and bug fixes
- **[Code Review Report](plans/code-review-report.md)** - Comprehensive code analysis

## 🏗️ Project Structure

```
lib/
├── app/                    # App configuration and routing
├── data/                   # Data layer
│   ├── database/          # SQLite database
│   ├── models/            # Data models
│   └── repositories/      # Data access layer
├── features/              # Feature modules
│   ├── animals/          # Animal management
│   ├── breeding/         # Breeding & kidding
│   ├── health/           # Health records
│   ├── weights/          # Weight tracking
│   ├── pasture/          # Pasture rotation
│   ├── finances/         # Financial tracking
│   ├── export/           # PDF generation
│   └── import/           # Data import
└── shared/               # Shared utilities
    ├── providers/        # Riverpod providers
    ├── services/         # Business logic
    └── widgets/          # Reusable widgets
```

## 🔐 Security

**⚠️ Never commit real credentials to version control!**

- `.env` files are gitignored
- Use environment variables or --dart-define flags
- See [Setup Guide](docs/SETUP.md) for secure configuration

## 🧪 Testing

Run tests:
```bash
flutter test
```

Run specific test:
```bash
flutter test test/animal_model_test.dart
```

## 📝 Recent Updates

### Critical Fixes Applied (June 2026)
- ✅ Fixed invalid nullable syntax in pasture repository
- ✅ Removed hardcoded Supabase credentials (now uses environment variables)
- ✅ Fixed 5 instances of empty catch blocks
- ✅ Added comprehensive error logging
- ✅ Created setup documentation

See [CRITICAL_FIXES.md](docs/CRITICAL_FIXES.md) for details.

## 🤝 Contributing

1. Follow the existing code structure
2. Add tests for new features
3. Never commit sensitive credentials
4. Update documentation as needed

## 📄 License

This project is for Kiko goat herd management.

## 🆘 Troubleshooting

### "Supabase URL or Anon Key is not configured"
**Solution**: Follow the [Setup Guide](docs/SETUP.md) to configure credentials.

### Build errors related to missing environment variables
**Solution**: Pass credentials via --dart-define flags (see above).

### Sync not working
**Solution**: 
1. Check credentials are correct
2. Enable sync in Settings → Sync Settings
3. Log in to your Supabase account

For more help, see the [Setup Guide](docs/SETUP.md).

---

**Made with ❤️ for Kiko goat farmers**
