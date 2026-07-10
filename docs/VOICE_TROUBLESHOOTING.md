# Speech Recognition Troubleshooting Guide

## Overview

FlockKeeper uses the `speech_to_text` package for voice commands. If speech recognition is not working, follow this guide to diagnose and fix the issue.

## Quick Checks

### ✅ Permissions Verified
- **Android**: `RECORD_AUDIO` permission is declared in [`android/app/src/main/AndroidManifest.xml`](../android/app/src/main/AndroidManifest.xml:3)
- **iOS**: Microphone and Speech Recognition permissions are declared in [`ios/Runner/Info.plist`](../ios/Runner/Info.plist:69-72)

### ✅ Dependencies Installed
Verify in [`pubspec.yaml`](../pubspec.yaml):
```yaml
dependencies:
  speech_to_text: ^7.3.0
  flutter_tts: ^4.0.2
```

## Common Issues & Solutions

### 1. Permission Not Granted at Runtime

**Symptom**: Speech recognition fails immediately or shows "not available" error.

**Solution**:
1. **Android**: Go to Settings → Apps → FlockKeeper → Permissions → Enable Microphone
2. **iOS**: Settings → FlockKeeper → Enable Microphone & Speech Recognition
3. **First Run**: The app should request permissions automatically. If not, uninstall and reinstall.

**Test**:
```dart
// Run this in debug mode to see detailed error messages
flutter run --verbose
```

### 2. Speech Recognition Not Available on Device

**Symptom**: Error message "Speech recognition is not available on this device."

**Common Causes**:
- **Emulator**: Speech recognition may not work on emulators
- **iOS Simulator**: Does not support speech recognition
- **Older devices**: Check device supports speech recognition

**Solution**:
- Test on a physical device
- For Android emulator: Some newer Android emulators support speech with proper setup
- Check device API level (Android 21+ required)

### 3. No Internet Connection

**Symptom**: Speech recognition initializes but fails during listening.

**Cause**: Speech recognition requires internet connection for processing (Google Cloud Speech API on Android, Apple's servers on iOS).

**Solution**:
- Ensure device has active internet connection (Wi-Fi or cellular data)
- Check if device can reach Google/Apple services
- Try on different network if corporate firewall may be blocking

### 4. Microphone in Use by Another App

**Symptom**: Speech recognition fails to start listening.

**Solution**:
- Close other apps using the microphone
- Restart the device
- Check no other apps have exclusive microphone access

### 5. Language/Locale Issues

**Symptom**: Speech not being recognized or immediate stop.

**Check**:
```dart
// In voice_controller.dart, verify locale settings
await _speech.listen(
  localeId: 'en_US',  // Ensure this matches your device language
  // ...
);
```

**Solution**:
- Check device language settings match supported speech recognition languages
- English (US) is default; change if needed in code

## Debugging Steps

### Step 1: Enable Verbose Logging

Run the app with detailed logs:
```bash
flutter run --verbose
```

### Step 2: Check Console for Errors

Look for error messages in the debug console from [`voice_controller.dart:475-489`](../lib/features/breeding/providers/voice_controller.dart:475):

```dart
void _handleSpeechError(String errorMsg) {
  debugPrint('Speech Error: $errorMsg');  // Check console for this
  // ...
}

void _handleSpeechStatus(String status) {
  debugPrint('Speech Status: $status');  // Check console for  this
  // ...
}
```

### Step 3: Test Speech Recognition Initialization

Add temporary debug code to check if speech is available:

```dart
final speech = SpeechToText();
final available = await speech.initialize();
debugPrint('Speech available: $available');

if (available) {
  final locales = await speech.locales();
  debugPrint('Available locales: $locales');
  
  final systemLocale = await speech.systemLocale();
  debugPrint('System locale: $systemLocale');
}
```

### Step 4: Check Device Logs

**Android**:
```bash
adb logcat | grep -i speech
adb logcat | grep -i audio
```

**iOS**:
Use Xcode Console to view system logs while running the app.

## Platform-Specific Issues

### Android

#### Issue: Permission Denied Despite Grant
**Solution**:
1. Uninstall the app completely
2. Clear app data: `adb shell pm clear com.clearcreekforge.flockkeeper`
3. Rebuild and install: `flutter run`

#### Issue: Works on One Device, Not Another
**Cause**: Google Play Services may be outdated or missing.

**Solution**:
- Update Google Play Services
- Check if device has Google services (some Chinese phones don't)

#### Issue: Emulator Not Working
**Solution**:
- Use Android Studio AVD with Google APIs
- Enable microphone in emulator settings
- Or test on physical device (recommended)

### iOS

#### Issue: "Speech Recognition Not Authorized"
**Solution**:
1. Settings → Privacy & Security → Speech Recognition
2. Enable for FlockKeeper
3. May need to delete and reinstall app

#### Issue: Works in Debug, Not in Release
**Cause**: Entitlements or provisioning profile issue.

**Solution**:
- Check `ios/Runner/Release.entitlements` exists
- Verify App ID capabilities in Apple Developer Console
- Check Speech Recognition is enabled in capabilities

### Windows/macOS/Linux

**Status**: Speech recognition support varies by platform.

**Windows**:
- Windows 10+ with Speech Recognition enabled in Settings
- May require additional setup

**macOS**:
- Should work out of the box with proper permissions
- System Preferences → Security & Privacy → Microphone

**Linux**:
- Limited support, depends on system speech services
- May need to install speech recognition packages

## Error Message Reference

| Error Message | Meaning | Solution |
|---------------|---------|----------|
| "Speech recognition is not available" | Initialize failed | Check permissions, internet, or use physical device |
| "error_audio_error" | Microphone access issue | Check permissions, restart app |
| "error_network_timeout" | No internet or slow connection | Check internet connectivity |
| "error_no_match" | Speech not understood | Speak clearly, check microphone |
| "error_busy" | Microphone in use | Close other apps |
| "error_speech_timeout" | No speech detected | Check microphone is working |

## Testing Checklist

Before reporting a bug, verify:

- [ ] Running on physical device (not emulator)
- [ ] Microphone permission granted in device settings
- [ ] Internet connection active and working
- [ ] No other apps using microphone
- [ ] Device volume up and not muted
- [ ] Microphone hardware working (test with another app)
- [ ] Latest version of the app installed
- [ ] Device restart attempted
- [ ] Checked debug console for error messages

## Code References

### Voice Controller
- Main implementation: [`lib/features/breeding/providers/voice_controller.dart`](../lib/features/breeding/providers/voice_controller.dart:1)
- Error handling: Lines 475-489
- Initialization: Lines 76-109

### Voice Command Overlay
- UI implementation: [`lib/features/breeding/screens/voice_command_overlay.dart`](../lib/features/breeding/screens/voice_command_overlay.dart:1)

### Voice Parser
- Command parsing: [`lib/shared/services/voice_parser.dart`](../lib/shared/services/voice_parser.dart:1)

## Improving Error Visibility

If errors are not visible to users, consider enhancing the error handling:

```dart
void _handleSpeechError(String errorMsg) {
  debugPrint('Speech Error: $errorMsg');
  state = state.copyWith(
    status: VoiceState.error,
    errorMessage: 'Speech recognition error: $errorMsg\n\n'
        'Please check:\n'
        '• Microphone permissions are granted\n'
        '• Internet connection is active\n'
        '• No other apps are using the microphone',
  );
}
```

## Getting Help

If issues persist after following this guide:

1. **Check logs**: Run with `flutter run --verbose` and capture console output
2. **Test on different device**: Confirm if device-specific
3. **Test voice_controller.dart directly**: Create minimal test to isolate issue
4. **Check speech_to_text package issues**: Visit [package GitHub](https://github.com/csdcorp/speech_to_text)

## Related Documentation

- [Setup Guide](SETUP.md)
- [Critical Fixes](CRITICAL_FIXES.md)
- [Code Review Report](../plans/code-review-report.md)

---

**Last Updated**: June 24, 2026
