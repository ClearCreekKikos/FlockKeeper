import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:local_notifier/local_notifier.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app/app.dart';
import 'app/config.dart';
import 'shared/utils/path_resolver.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await PathResolver.initialize();

  // Load .env file for Supabase credentials
  try {
    await dotenv.load(fileName: '.env');
    debugPrint('✅ .env file loaded successfully');
  } catch (e) {
    debugPrint('⚠️ Could not load .env file: $e');
  }
  if (Platform.isWindows || Platform.isLinux) {
    // Initialize FFI
    sqfliteFfiInit();
    // Change the default factory for desktop platforms
    databaseFactory = databaseFactoryFfi;
  }

  if (!kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
    try {
      await localNotifier.setup(
        appName: 'FlockKeeper',
        shortcutPolicy: ShortcutPolicy.requireCreate,
      );
    } catch (e) {
      debugPrint('Failed to initialize local notifier: $e');
    }
  }

  // Initialize Supabase on startup asynchronously to prevent blocking runApp()
  try {
    if (AppConfig.supabaseUrl.isNotEmpty &&
        AppConfig.supabaseUrl != 'YOUR_SUPABASE_PROJECT_URL' &&
        AppConfig.supabaseAnonKey.isNotEmpty &&
        AppConfig.supabaseAnonKey != 'YOUR_SUPABASE_ANON_KEY') {
      Supabase.initialize(
        url: AppConfig.supabaseUrl,
        publishableKey: AppConfig.supabaseAnonKey,
      ).catchError((e) {
        debugPrint('Supabase initialization failed asynchronously: $e');
        throw e;
      });
    }
  } catch (e) {
    debugPrint('Supabase initialization failed on startup: $e');
  }

  runApp(const ProviderScope(child: FlockKeeperApp()));
}
