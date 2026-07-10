import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../data/database/database_helper.dart';
import '../../../shared/services/sync_service.dart';
import '../../home/screens/home_screen.dart';
import '../../../shared/providers/animal_providers.dart';
import '../../../shared/providers/providers.dart';
import '../../../shared/providers/dashboard_providers.dart';
import '../../finances/providers/financial_providers.dart';
import '../../breeding/providers/breeding_providers.dart';

class LoginScreen extends ConsumerStatefulWidget {
  final bool fromSettings;
  const LoginScreen({super.key, this.fromSettings = false});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isSignUp = false;
  bool _isLoading = false;
  bool _isSyncingDatabase = false;
  String? _errorMessage;
  bool _rememberMe = true;
  bool _obscurePassword = true;

  /// When a remembered session exists, holds the email to offer a one-tap
  /// "Continue as ..." sign-in (no password re-entry). Null otherwise.
  String? _continueEmail;

  @override
  void initState() {
    super.initState();
    _loadRememberedCredentials();
  }

  Future<void> _loadRememberedCredentials() async {
    final db = DatabaseHelper();
    final rememberMeStr = await db.getSetting('sync_remember_me');
    final savedEmail = await db.getSetting('sync_email');
    final savedSession = await db.getSetting('sync_supabase_session');

    if (mounted) {
      setState(() {
        _rememberMe = rememberMeStr != 'false';
        if (_rememberMe && savedEmail != null && savedEmail.isNotEmpty) {
          _emailController.text = savedEmail;
          // Offer one-tap continue only when a saved session is also present.
          if (savedSession != null && savedSession.isNotEmpty) {
            _continueEmail = savedEmail;
          }
        }
      });
    }
  }

  /// Clears local herd data + profile when the authenticated user differs from
  /// the one previously stored on this device, so users never see each other's
  /// data. Safe to call on every login (no-op for the same user).
  Future<void> _handleUserSwitch(DatabaseHelper db, String? newUserId) async {
    if (newUserId == null) return;
    final storedUserId = await db.getSetting('logged_in_user_id');
    if (storedUserId != newUserId) {
      await db.clearUserData();
      await db.setSetting('logged_in_user_id', newUserId);
    }
  }

  /// One-tap sign-in using the saved Supabase session (no password re-entry).
  /// Recovers/refreshes the session, runs the different-user clear, then syncs.
  Future<void> _continueAsRemembered() async {
    setState(() {
      _isLoading = true;
      _isSyncingDatabase = false;
      _errorMessage = null;
    });

    final db = DatabaseHelper();
    try {
      await db.setSetting('sync_enabled', 'true');
      SyncService().resetClient();

      // getClient() recovers & refreshes the stored session token internally.
      final client = await SyncService().getClient();
      final session = client?.auth.currentSession;
      final user = client?.auth.currentUser;

      if (client == null || session == null || user == null) {
        // Session is missing/expired — fall back to manual password sign-in.
        if (mounted) {
          setState(() {
            _isLoading = false;
            _continueEmail = null;
            _errorMessage =
                'Your saved session has expired. Please sign in with your password.';
          });
        }
        return;
      }

      await db.setSetting(
        'sync_supabase_session',
        jsonEncode(session.toJson()),
      );
      await db.setSetting('sync_remember_me', 'true');
      await _handleUserSwitch(db, user.id);
      await _triggerInitialSyncAndNavigate();
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isSyncingDatabase = false;
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    setState(() {
      _isLoading = true;
      _isSyncingDatabase = false;
      _errorMessage = null;
    });

    final db = DatabaseHelper();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    // 1. Validation
    if (!_formKey.currentState!.validate()) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      // 2. Enable sync in settings
      await db.setSetting('sync_enabled', 'true');

      // Reset service client to load config credentials
      SyncService().resetClient();

      // 3. Get Supabase client
      final client = await SyncService().getClient();
      if (client == null) {
        final details = SyncService.lastInitError != null
            ? '\nError: ${SyncService.lastInitError}'
            : '';
        throw Exception(
          'Could not initialize connection. Check your Project URL & Key config.$details',
        );
      }

      // 4. Perform Auth Operation
      if (_isSignUp) {
        final response = await client.auth.signUp(
          email: email,
          password: password,
        );

        if (response.session != null) {
          // Auto-logged in
          await db.setSetting(
            'sync_supabase_session',
            jsonEncode(response.session!.toJson()),
          );
          await db.setSetting('sync_remember_me', _rememberMe.toString());
          if (_rememberMe) {
            await db.setSetting('sync_email', email);
          } else {
            await db.setSetting('sync_email', '');
          }
          await db.setSetting('sync_last_time', '1970-01-01T00:00:00.000Z');
          // Clear local data if this is a different user, so they start clean
          await _handleUserSwitch(db, response.user?.id);
          await _triggerInitialSyncAndNavigate();
        } else {
          // Requires email confirmation
          if (mounted) {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Account Created'),
                content: const Text(
                  'Your account was created successfully. '
                  'Please check your email and click the confirmation link to activate your account before logging in.',
                ),
                actions: [
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      setState(() {
                        _isSignUp = false;
                        _isLoading = false;
                        _passwordController.clear();
                      });
                    },
                    child: const Text('Sign In Now'),
                  ),
                ],
              ),
            );
          }
        }
      } else {
        // Sign In
        final response = await client.auth.signInWithPassword(
          email: email,
          password: password,
        );

        if (response.session != null) {
          await db.setSetting(
            'sync_supabase_session',
            jsonEncode(response.session!.toJson()),
          );
          await db.setSetting('sync_remember_me', _rememberMe.toString());
          if (_rememberMe) {
            await db.setSetting('sync_email', email);
          } else {
            await db.setSetting('sync_email', '');
          }
          await db.setSetting('sync_last_time', '1970-01-01T00:00:00.000Z');
          // Clear local data if this is a different user, so they start clean
          await _handleUserSwitch(db, response.user?.id);
          await _triggerInitialSyncAndNavigate();
        } else {
          throw Exception('Sign in failed: Session is null.');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isSyncingDatabase = false;
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  Future<void> _triggerInitialSyncAndNavigate() async {
    setState(() {
      _isLoading = true;
      _isSyncingDatabase = true;
    });

    try {
      await SyncService().syncNow();
    } catch (e) {
      debugPrint('Initial sync failed: $e');
    }

    // Invalidate providers to force UI refresh with new cloud data
    ref.read(settingsStateProvider.notifier).loadSettings();
    ref.invalidate(animalsProvider);
    ref.invalidate(activeAnimalsProvider);
    ref.invalidate(searchedAnimalsProvider);
    ref.invalidate(dashboardProvider);
    ref.invalidate(financialRecordsProvider);
    ref.invalidate(breedingListProvider);
    ref.invalidate(kiddingRecordsListProvider);

    if (mounted) {
      if (widget.fromSettings) {
        Navigator.of(context).pop();
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      }
    }
  }

  Future<void> _handleBypass() async {
    final db = DatabaseHelper();
    // Disable cloud sync so startup bypasses login
    await db.setSetting('sync_enabled', 'false');
    await db.setSetting('sync_supabase_session', '');
    await db.setSetting('sync_remember_me', 'true');
    await db.setSetting('sync_last_time', '1970-01-01T00:00:00.000Z');
    SyncService().resetClient();

    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    }
  }

  Future<void> _signInWithFacebook() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final db = DatabaseHelper();
    try {
      await db.setSetting('sync_enabled', 'true');
      SyncService().resetClient();
      final client = await SyncService().getClient();
      if (client == null) {
        throw Exception('Could not initialize connection.');
      }

      await client.auth.signInWithOAuth(
        OAuthProvider.facebook,
        redirectTo: 'flockkeeper://login-callback',
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final db = DatabaseHelper();
    try {
      await db.setSetting('sync_enabled', 'true');
      SyncService().resetClient();
      final client = await SyncService().getClient();
      if (client == null) {
        throw Exception('Could not initialize connection.');
      }

      await client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: 'flockkeeper://login-callback',
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  /// Generate a cryptographically-secure random nonce for Apple sign-in.
  String _generateNonce([int length = 32]) {
    const charset = '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)]).join();
  }

  /// SHA-256 hash of the nonce for Apple's server verification.
  String _sha256ofString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  Future<void> _signInWithApple() async {
    setState(() {
      _isLoading = true;
      _isSyncingDatabase = false;
      _errorMessage = null;
    });

    final db = DatabaseHelper();
    try {
      await db.setSetting('sync_enabled', 'true');
      SyncService().resetClient();
      final client = await SyncService().getClient();
      if (client == null) {
        throw Exception('Could not initialize connection.');
      }

      // 1. Generate a secure nonce
      final rawNonce = _generateNonce();
      final hashedNonce = _sha256ofString(rawNonce);

      // 2. Request native Apple credential
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: hashedNonce,
      );

      final idToken = appleCredential.identityToken;
      if (idToken == null) {
        throw Exception('Apple Sign-In failed: No identity token received.');
      }

      // 3. Sign in to Supabase using the Apple ID token
      final response = await client.auth.signInWithIdToken(
        provider: OAuthProvider.apple,
        idToken: idToken,
        nonce: rawNonce,
      );

      if (response.session != null) {
        await db.setSetting(
          'sync_supabase_session',
          jsonEncode(response.session!.toJson()),
        );
        await db.setSetting('sync_remember_me', 'true');
        await db.setSetting('sync_email', response.user?.email ?? '');
        await db.setSetting('sync_last_time', '1970-01-01T00:00:00.000Z');
        await _handleUserSwitch(db, response.user?.id);
        await _triggerInitialSyncAndNavigate();
      } else {
        throw Exception('Apple Sign-In succeeded but no session was created.');
      }
    } on SignInWithAppleAuthorizationException catch (e) {
      // User cancelled or Apple returned an error
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.code == AuthorizationErrorCode.canceled
              ? null // User cancelled, no error to show
              : 'Apple Sign-In error: ${e.message}';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Logo Shield & Title
                  Image.asset(
                    'assets/images/splash.jpg',
                    height: 120,
                    width: 120,
                    errorBuilder: (context, error, stackTrace) => Icon(
                      Icons.pets,
                      size: 80,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'FlockKeeper',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Sync your herd data between your devices',
                    style: TextStyle(
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),

                  // One-tap continue for a remembered session (no password).
                  if (_continueEmail != null) ...[
                    ElevatedButton.icon(
                      onPressed: _isLoading ? null : _continueAsRemembered,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor:
                            Theme.of(context).colorScheme.onPrimary,
                      ),
                      icon: const Icon(Icons.login),
                      label: Text(
                        'Continue as $_continueEmail',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Expanded(child: Divider()),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            'or use a different account',
                            style: TextStyle(
                              color: isDark ? Colors.white54 : Colors.black45,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const Expanded(child: Divider()),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],

                  if (_errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.red.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red, fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Email Input
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: 'Email Address',
                      prefixIcon: Icon(Icons.email_outlined),
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Email is required';
                      }
                      if (!v.contains('@') || !v.contains('.')) {
                        return 'Enter a valid email address';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Password Input
                  TextFormField(
                    controller: _passwordController,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                      border: const OutlineInputBorder(),
                    ),
                    obscureText: _obscurePassword,
                    validator: (v) {
                      if (v == null || v.isEmpty) {
                        return 'Password is required';
                      }
                      if (v.length < 6) {
                        return 'Password must be at least 6 characters';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),

                  // Remember Me Option
                  CheckboxListTile(
                    title: const Text('Remember Me'),
                    value: _rememberMe,
                    onChanged: (val) {
                      setState(() {
                        _rememberMe = val ?? true;
                      });
                    },
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: 16),

                  if (_isLoading) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          _isSyncingDatabase
                              ? 'Syncing cloud database...'
                              : 'Authenticating...',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: isDark ? Colors.white70 : Colors.black54,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Action Button
                  ElevatedButton(
                    onPressed: _isLoading ? null : _handleSubmit,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            _isSignUp ? 'Create Account' : 'Sign In',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                  const SizedBox(height: 12),

                  // Toggle Auth mode
                  TextButton(
                    onPressed: _isLoading
                        ? null
                        : () => setState(() {
                             _isSignUp = !_isSignUp;
                             _errorMessage = null;
                           }),
                    child: Text(
                      _isSignUp
                          ? 'Already have an account? Sign In'
                          : 'Need an account? Sign Up',
                    ),
                  ),

                  const SizedBox(height: 8),

                  OutlinedButton.icon(
                    onPressed: _isLoading ? null : _signInWithFacebook,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      side: BorderSide(color: Colors.blue.shade800),
                    ),
                    icon: Icon(Icons.facebook, color: Colors.blue.shade800),
                    label: Text(
                      'Continue with Facebook',
                      style: TextStyle(
                        color: Colors.blue.shade800,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),

                  OutlinedButton.icon(
                    onPressed: _isLoading ? null : _signInWithApple,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      side: BorderSide(color: isDark ? Colors.white70 : Colors.black87),
                    ),
                    icon: Icon(
                      Icons.apple,
                      size: 24,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                    label: Text(
                      'Continue with Apple',
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black87,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),

                  OutlinedButton.icon(
                    onPressed: _isLoading ? null : _signInWithGoogle,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      side: BorderSide(color: Colors.grey.shade400),
                    ),
                    icon: Icon(Icons.g_mobiledata, size: 28, color: Colors.red.shade700),
                    label: Text(
                      'Continue with Google',
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black87,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  const Divider(height: 32),

                  // Continue Offline Button
                  OutlinedButton(
                    onPressed: _isLoading ? null : _handleBypass,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Continue Offline (Guest Mode)'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
