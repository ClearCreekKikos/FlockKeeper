#!/bin/bash
# Script to clean up cached Windows build paths, update launcher icons, and verify the iOS release build.

# Make script fail if any step fails
set -e

# Load environment variables from .env if it exists and variables aren't already set
if [ -f .env ]; then
  echo "🔑 Loading environment variables from .env file..."
  # Export variables from .env, ignoring commented lines
  export $(grep -v '^#' .env | xargs)
fi

echo "🧹 1. Cleaning project..."
flutter clean

echo "📦 2. Fetching packages..."
flutter pub get

echo "🎨 3. Generating iOS launcher icons..."
flutter pub run flutter_launcher_icons

echo "⚙️ 4. Running static analysis..."
flutter analyze

echo "🏗️ 5. Performing dry build of iOS (Release, no codesign)..."
# Check if Supabase env variables are set, if not, print warning
if [ -z "$SUPABASE_URL" ] || [ -z "$SUPABASE_ANON_KEY" ]; then
  echo "⚠️ Warning: SUPABASE_URL and SUPABASE_ANON_KEY environment variables are not set."
  echo "The build will proceed but will fallback to default credentials or require .env runtime values."
fi

flutter build ios --release --no-codesign --dart-define=SUPABASE_URL="$SUPABASE_URL" --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY"

echo ""
echo "✅ iOS Release preparation complete!"
echo "👉 You can now open 'ios/Runner.xcworkspace' in Xcode to configure signing and archive for the App Store."
