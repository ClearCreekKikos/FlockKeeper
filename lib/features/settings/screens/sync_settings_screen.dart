import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../data/database/database_helper.dart';
import '../../../shared/services/sync_service.dart';
import '../../../shared/providers/animal_providers.dart';
import '../../splash/screens/splash_screen.dart';
import '../../auth/screens/login_screen.dart';
import '../../../shared/providers/providers.dart';
import '../../../shared/providers/dashboard_providers.dart';
import '../../finances/providers/financial_providers.dart';
import '../../breeding/providers/breeding_providers.dart';

class SyncSettingsScreen extends ConsumerStatefulWidget {
  const SyncSettingsScreen({super.key});

  @override
  ConsumerState<SyncSettingsScreen> createState() => _SyncSettingsScreenState();
}

class _SyncSettingsScreenState extends ConsumerState<SyncSettingsScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  bool _syncEnabled = false;
  String _lastSyncTime = 'Never';
  bool _isTestingConnection = false;
  bool _isSyncing = false;
  bool _isDeletingAccount = false;
  String? _userEmail;

  late AnimationController _rotationController;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      duration: const Duration(seconds: 15),
      vsync: this,
    );
    _loadSettings();
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final db = DatabaseHelper();
    final enabled = await db.getSetting('sync_enabled') == 'true';
    final lastSync = await db.getSetting('sync_last_time');

    String lastSyncText = 'Never';
    if (lastSync != null) {
      try {
        final dt = DateTime.parse(lastSync).toLocal();
        lastSyncText = DateFormat.yMd().add_jm().format(dt);
      } catch (e) {
        debugPrint('Failed to parse last sync date "$lastSync": $e');
        lastSyncText = 'Invalid date';
      }
    }

    String? userEmail;
    if (enabled) {
      final client = await SyncService().getClient();
      userEmail = client?.auth.currentUser?.email;
    }

    if (mounted) {
      setState(() {
        _syncEnabled = enabled;
        _lastSyncTime = lastSyncText;
        _userEmail = userEmail;
      });
    }
  }

  Future<void> _logOut() async {
    final confirm = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log Out'),
        content: const Text(
          'Are you sure you want to log out? Disabling sync will prevent this device from syncing. '
          'Choose how to handle local data on this device:',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'cancel'),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.orange),
            onPressed: () => Navigator.pop(ctx, 'keep'),
            child: const Text('Keep Local Data'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, 'clear'),
            child: const Text('Clear Local Data'),
          ),
        ],
      ),
    );

    if (confirm == null || confirm == 'cancel') return;

    final db = DatabaseHelper();

    // Sign out from Supabase (clears in-memory session) and reset local auth state
    await SyncService().signOut();
    await db.setSetting('sync_enabled', 'false');
    await db.setSetting('sync_supabase_session', '');
    await db.setSetting('sync_last_time', '1970-01-01T00:00:00.000Z');

    if (confirm == 'clear') {
      setState(() => _isSyncing = true);
      await db.clearAllData();
      ref.invalidate(animalsProvider);
      ref.invalidate(activeAnimalsProvider);
      ref.invalidate(searchedAnimalsProvider);
      setState(() => _isSyncing = false);
    }

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Logged out successfully.')));

      // Clear navigation history and restart from SplashScreen to redirect to Login
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const SplashScreen()),
        (route) => false,
      );
    }
  }

  Future<void> _deleteAccount() async {
    // First confirmation
    final firstConfirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
            SizedBox(width: 8),
            Text('Delete Account?'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'This will permanently delete your account and ALL associated data '
                'from our servers, including:\n\n'
                '• All animal records\n'
                '• Breeding, kidding, and health logs\n'
                '• Weight records and financial data\n'
                '• Pasture and inventory data\n'
                '• Uploaded photos and files\n'
                '• Ranch profile and settings\n',
              ),
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  border: Border.all(color: Colors.amber.shade400, width: 1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.payment_rounded, color: Colors.amber.shade800, size: 24),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Active Subscription Alert',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.amber.shade900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Deleting your account does NOT cancel your paid subscription. You must manually cancel it in your Apple App Store or Google Play Store settings to avoid future charges.',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.amber.shade900,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Text(
                'This action CANNOT be undone. Data on all synced devices will be lost.',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );

    if (firstConfirm != true || !mounted) return;

    // Second confirmation — type DELETE
    final controller = TextEditingController();
    final secondConfirm = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: const Text('Type DELETE to confirm'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'To confirm permanent deletion of your account '
                    '(${_userEmail ?? ""}), type DELETE below:',
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: controller,
                    autofocus: true,
                    decoration: const InputDecoration(
                      hintText: 'Type DELETE here',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => setDialogState(() {}),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: controller.text.trim().toUpperCase() == 'DELETE'
                      ? () => Navigator.pop(ctx, true)
                      : null,
                  child: const Text('Permanently Delete'),
                ),
              ],
            );
          },
        );
      },
    );
    controller.dispose();

    if (secondConfirm != true || !mounted) return;

    setState(() => _isDeletingAccount = true);

    final error = await SyncService().deleteAccount();

    if (!mounted) return;

    setState(() => _isDeletingAccount = false);

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Account deletion failed: $error'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Invalidate all providers
    ref.invalidate(animalsProvider);
    ref.invalidate(activeAnimalsProvider);
    ref.invalidate(searchedAnimalsProvider);
    ref.invalidate(dashboardProvider);
    ref.invalidate(financialRecordsProvider);
    ref.invalidate(breedingListProvider);
    ref.invalidate(kiddingRecordsListProvider);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Your account and all associated data have been permanently deleted.',
          ),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const SplashScreen()),
        (route) => false,
      );
    }
  }

  Future<void> _saveSettings() async {
    final db = DatabaseHelper();
    await db.setSetting('sync_enabled', _syncEnabled.toString());
    SyncService().resetClient();
  }

  Future<void> _testConnection() async {
    setState(() => _isTestingConnection = true);

    final success = await SyncService().testConnection();

    if (mounted) {
      setState(() => _isTestingConnection = false);
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(success ? 'Connection Successful' : 'Connection Failed'),
          content: Text(
            success
                ? 'FlockKeeper has successfully connected to the Cloud Database!'
                : 'Could not connect to Supabase. Check your internet connection.',
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _triggerSync() async {
    if (_isSyncing) return;

    await _saveSettings();
    setState(() {
      _isSyncing = true;
    });
    _rotationController.repeat();

    final error = await SyncService().syncNow();

    _rotationController.stop();
    if (!mounted) return;

    setState(() {
      _isSyncing = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          error == null
              ? 'Cloud Sync Completed Successfully!'
              : 'Sync failed: $error',
        ),
        backgroundColor: error == null ? Colors.green : Colors.red,
      ),
    );

    if (error == null) {
      ref.read(settingsStateProvider.notifier).loadSettings();
      ref.invalidate(animalsProvider);
      ref.invalidate(activeAnimalsProvider);
      ref.invalidate(searchedAnimalsProvider);
      ref.invalidate(dashboardProvider);
      ref.invalidate(financialRecordsProvider);
      ref.invalidate(breedingListProvider);
      ref.invalidate(kiddingRecordsListProvider);
    }

    await _loadSettings();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('Cloud Sync Settings')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              color: isDark ? Colors.green[900]?.withValues(alpha: 0.3) : Colors.green[50],
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Cross-Platform Synchronization',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Sync your goat data in real-time between your phone and your PC using a private database in Supabase.',
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.4,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'All data remains stored locally so the app works 100% offline, and syncs automatically when online.',
                      style: TextStyle(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (_userEmail != null) ...[
              Card(
                elevation: 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.person)),
                  title: const Text('Connected Account'),
                  subtitle: Text(_userEmail!),
                  trailing: SizedBox(
                    width: 110,
                    child: TextButton.icon(
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.red,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      onPressed: _logOut,
                      icon: const Icon(Icons.logout, size: 18),
                      label: const Text(
                        'Log Out',
                        style: TextStyle(fontSize: 13),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // Delete Account button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: _isDeletingAccount
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(12),
                          child: Column(
                            children: [
                              CircularProgressIndicator(color: Colors.red),
                              SizedBox(height: 8),
                              Text(
                                'Deleting account...',
                                style: TextStyle(color: Colors.red, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      )
                    : TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.red[700],
                        ),
                        onPressed: _deleteAccount,
                        icon: const Icon(Icons.delete_forever, size: 18),
                        label: const Text(
                          'Delete Account & All Data',
                          style: TextStyle(fontSize: 13),
                        ),
                      ),
              ),
              const SizedBox(height: 16),
            ] else ...[
              Card(
                elevation: 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.cloud_off_outlined),
                  ),
                  title: const Text('Account Disconnected'),
                  subtitle: const Text(
                    'Log in to connect your database to Supabase.',
                  ),
                  trailing: SizedBox(
                    width: 90,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                      ),
                      onPressed: () {
                        Navigator.of(context)
                            .push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    const LoginScreen(fromSettings: true),
                              ),
                            )
                            .then((_) => _loadSettings());
                      },
                      child: const Text('Log In'),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            SwitchListTile(
              title: const Text('Enable Cloud Sync'),
              subtitle: const Text('Toggle cloud synchronization on or off'),
              value: _syncEnabled,
              onChanged: (val) async {
                setState(() {
                  _syncEnabled = val;
                });
                // Capture the navigator before the async gap so we don't use
                // BuildContext across it.
                final navigator = Navigator.of(context);
                await _saveSettings();

                if (val && _userEmail == null && mounted) {
                  navigator
                      .push(
                        MaterialPageRoute(
                          builder: (_) =>
                              const LoginScreen(fromSettings: true),
                        ),
                      )
                      .then((_) => _loadSettings());
                }
              },
            ),
            const Divider(),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isTestingConnection ? null : _testConnection,
                    icon: _isTestingConnection
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.private_connectivity),
                    label: const Text('Test Connection'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Manual Database Sync',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Last Sync: $_lastSyncTime',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
                RotationTransition(
                  turns: _rotationController,
                  child: FloatingActionButton(
                    onPressed: (_syncEnabled && !_isSyncing)
                        ? _triggerSync
                        : null,
                    backgroundColor: _syncEnabled
                        ? Colors.green
                        : Colors.grey[300],
                    foregroundColor: _syncEnabled
                        ? Colors.white
                        : Colors.grey[600],
                    mini: true,
                    child: const Icon(Icons.sync),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
