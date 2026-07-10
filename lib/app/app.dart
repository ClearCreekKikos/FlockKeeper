import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'dart:async';
import 'package:app_links/app_links.dart';

import '../features/splash/screens/splash_screen.dart';
import '../shared/providers/providers.dart';
import '../features/breeding/screens/voice_command_overlay.dart';
import '../core/services/subscription_service.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class FlockKeeperApp extends ConsumerStatefulWidget {
  const FlockKeeperApp({super.key});

  @override
  ConsumerState<FlockKeeperApp> createState() => _FlockKeeperAppState();
}

class _FlockKeeperAppState extends ConsumerState<FlockKeeperApp> {
  late final AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;

  @override
  void initState() {
    super.initState();
    _initDeepLinks();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await ref.read(notificationServiceProvider).init();
      } catch (e) {
        debugPrint('Failed to initialize notifications: $e');
      }
      ref.read(notificationServiceProvider).startPeriodicChecks();
      
      // Initialize in-app purchase stream
      if (!Platform.environment.containsKey('FLUTTER_TEST')) {
        ref.read(subscriptionServiceProvider);
      }
    });
  }

  void _initDeepLinks() {
    if (Platform.environment.containsKey('FLUTTER_TEST')) return;
    _appLinks = AppLinks();
    
    // Handle cold start deep links
    _appLinks.getInitialLink().then((uri) {
      if (uri != null) {
        _handleDeepLink(uri);
      }
    }).catchError((err) {
      debugPrint('Failed to get initial deep link: $err');
    });

    // Handle warm start deep links
    _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
      _handleDeepLink(uri);
    }, onError: (err) {
      debugPrint('Deep Link error: $err');
    });
  }

  void _handleDeepLink(Uri uri) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (uri.scheme == 'flockkeeper' && (uri.host == 'voice-add' || uri.host == 'voice' || uri.path == '/voice-add' || uri.path == '/voice' || uri.queryParameters['autoStart'] == 'true')) {
        final context = navigatorKey.currentContext;
        if (context != null) {
          final queryText = uri.queryParameters['query'];
          VoiceCommandOverlay.show(context, initialQuery: queryText);
        }
      }
    });
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsStateProvider);
    
    // Convert hex string back to Color
    final primaryColor = Color(int.parse(settings['primary_color'] ?? '0xFF4CAF50'));
    final isDark = settings['dark_mode'] == 'true';
    final isTest = Platform.environment.containsKey('FLUTTER_TEST');

    return MaterialApp(
      navigatorKey: navigatorKey,
      title: settings['farm_name'] ?? 'FlockKeeper',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: primaryColor,
          brightness: isDark ? Brightness.dark : Brightness.light,
        ),
        textTheme: (isTest ? const TextTheme() : GoogleFonts.latoTextTheme()).copyWith(
          // This style controls the color of the text the user types into TextFields
          bodyLarge: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontSize: 16,
          ),
          bodyMedium: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontSize: 14,
          ),
          bodySmall: TextStyle(
            color: isDark ? Colors.white70 : Colors.black54,
            fontSize: 12,
          ),
          titleLarge: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
          titleMedium: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontSize: 16,
          ),
          titleSmall: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontSize: 14,
          ),
          headlineLarge: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontSize: 32,
            fontWeight: FontWeight.bold,
          ),
          headlineMedium: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
          headlineSmall: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
          labelLarge: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
          labelMedium: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontSize: 12,
          ),
          labelSmall: TextStyle(
            color: isDark ? Colors.white60 : Colors.black45,
            fontSize: 10,
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          // Choose a fillColor that contrasts well with text in both modes
          fillColor: isDark ? Colors.grey.shade900 : Colors.grey.shade200, // Made darker for better contrast
          // Ensure label and hint text are visible
          labelStyle: TextStyle(
              color: isDark ? Colors.white70 : Colors.black87, fontSize: 16),
          hintStyle: TextStyle(
              color: isDark ? Colors.white54 : Colors.black54, fontSize: 16),
          // Define consistent borders
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none, // No border when filled
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: primaryColor, width: 2),
          ),
        ),
      ),
      home: const SplashScreen(),
    );
  }
}
