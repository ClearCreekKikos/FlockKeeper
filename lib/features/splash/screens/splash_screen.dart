import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import '../../../data/database/database_helper.dart';
import '../../../data/repositories/kidding_repository.dart';
import '../../animals/screens/animal_list_screen.dart';
import '../../auth/screens/login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    );

    _fadeController.forward();

    Timer(const Duration(seconds: 3), _navigateToHome);
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _navigateToHome() async {
    if (!mounted) return;

    final db = DatabaseHelper();

    // Run kidding record scan asynchronously in the background to prevent splash screen freeze
    Future(() async {
      try {
        await KiddingRepository().scanAndCreateKiddingRecords();
      } catch (e) {
        debugPrint('Startup background tasks failed: $e');
      }
    });
    // If the user did not opt into "Remember Me", drop any saved session so the
    // login screen won't offer a one-tap "Continue as ..." for them.
    final rememberMe = await db.getSetting('sync_remember_me') != 'false';
    if (!rememberMe) {
      await db.setSetting('sync_supabase_session', '');
    }

    if (!mounted) return;

    // Always land on the login screen on startup so the signed-in user is
    // explicit and the different-user data clear always runs. Widget tests
    // skip this gate and go straight to the app.
    final isTest = Platform.environment.containsKey('FLUTTER_TEST');
    final Widget nextScreen =
        isTest ? const AnimalListScreen() : const LoginScreen();

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => nextScreen,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 600),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SizedBox.expand(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Image.asset(
            'assets/images/splash.jpg',
            fit: BoxFit.contain,
            alignment: Alignment.center,
          ),
        ),
      ),
    );
  }
}
