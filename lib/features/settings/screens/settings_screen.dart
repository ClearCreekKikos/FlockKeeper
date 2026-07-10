import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import '../../../data/database/database_helper.dart';
import '../../../shared/providers/providers.dart';
import '../../../shared/services/sync_service.dart';
import '../../import/screens/import_home_screen.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../../../shared/utils/path_resolver.dart';
import 'sync_settings_screen.dart';
import 'subscription_paywall_screen.dart';
import '../../../shared/utils/phone_number_formatter.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsStateProvider);
    final primaryColor = Color(
      int.parse(settings['primary_color'] ?? '0xFF4CAF50'),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSection(context, 'Branding'),
          ListTile(
            title: const Text('Farm/Ranch Name'),
            subtitle: Text(settings['farm_name'] ?? 'Not set'),
            trailing: const Icon(Icons.edit),
            onTap: () => _showNameDialog(context, ref, settings['farm_name']),
          ),
          ListTile(
            title: const Text('Ranch Address'),
            subtitle: Text(settings['farm_address'] ?? 'Not set'),
            trailing: const Icon(Icons.edit),
            onTap: () =>
                _showAddressDialog(context, ref, settings['farm_address']),
          ),
          ListTile(
            title: const Text('Ranch Telephone'),
            subtitle: Text(settings['farm_phone'] ?? 'Not set'),
            trailing: const Icon(Icons.edit),
            onTap: () => _showPhoneDialog(context, ref, settings['farm_phone']),
          ),
          ListTile(
            title: const Text('Ranch Owner Name'),
            subtitle: Text(settings['owner_name'] ?? 'Not set'),
            trailing: const Icon(Icons.edit),
            onTap: () =>
                _showOwnerNameDialog(context, ref, settings['owner_name']),
          ),
          ListTile(
            title: const Text('Ranch Email Address'),
            subtitle: Text(settings['farm_email'] ?? 'Not set'),
            trailing: const Icon(Icons.edit),
            onTap: () => _showEmailDialog(context, ref, settings['farm_email']),
          ),
          ListTile(
            title: const Text('NKR Client ID'),
            subtitle: Text(settings['nkr_client_id'] ?? 'Not set'),
            trailing: const Icon(Icons.edit),
            onTap: () =>
                _showNkrClientIdDialog(context, ref, settings['nkr_client_id']),
          ),
          ListTile(
            title: const Text('NKR Herd Prefix'),
            subtitle: Text(settings['nkr_herd_prefix'] ?? 'Not set'),
            trailing: const Icon(Icons.edit),
            onTap: () => _showNkrHerdPrefixDialog(
              context,
              ref,
              settings['nkr_herd_prefix'],
            ),
          ),
          ListTile(
            title: const Text('Ranch Logo'),
            subtitle: const Text('Appears on the home screen'),
            trailing: () {
              final resolvedLogoPath = PathResolver.resolvePath(settings['farm_logo_path']);
              return resolvedLogoPath != null && File(resolvedLogoPath).existsSync()
                  ? Image.file(File(resolvedLogoPath), width: 40)
                  : Image.asset('assets/images/home_logo.png', width: 40);
            }(),
            onTap: () async {
              String? pickedPath;
              if (Platform.isWindows) {
                try {
                  final result = await FilePicker.platform.pickFiles(
                    type: FileType.image,
                    allowMultiple: false,
                  );
                  if (result != null && result.files.single.path != null) {
                    pickedPath = result.files.single.path;
                  }
                } catch (e) {
                  debugPrint('Error picking ranch logo on Windows: $e');
                }
              } else {
                final picker = ImagePicker();
                final img = await picker.pickImage(source: ImageSource.gallery);
                if (img != null) {
                  pickedPath = img.path;
                }
              }

              if (pickedPath != null) {
                // Copy the image to the app's local storage to prevent data loss
                final directory = await getApplicationDocumentsDirectory();
                final fileName = p.basename(pickedPath);
                final localPath = p.join(
                  directory.path,
                  'ranch_logo_${DateTime.now().millisecondsSinceEpoch}${p.extension(fileName)}',
                );

                await File(pickedPath).copy(localPath);

                ref
                    .read(settingsStateProvider.notifier)
                    .updateSetting('farm_logo_path', localPath);
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.restart_alt, color: Colors.red),
            title: const Text('Reset Ranch Profile'),
            subtitle: const Text(
              'Clear ranch name, address, contact, NKR info & logo from this '
              'device and the cloud (herd data is untouched)',
            ),
            onTap: () => _resetRanchProfile(context, ref),
          ),
          const Divider(),
          _buildSection(context, 'Premium Membership'),
          ListTile(
            leading: const Icon(Icons.star, color: Colors.amber),
            title: const Text('FlockKeeper Premium'),
            subtitle: Text(
              settings['is_premium'] == 'true'
                  ? 'Active Premium Member'
                  : 'Unlock Siri Voice Commands & Pedigree Trees',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SubscriptionPaywallScreen()),
              );
            },
          ),
          const Divider(),
          _buildSection(context, 'Theme & Colors'),
          SwitchListTile(
            title: const Text('Dark Mode'),
            value: settings['dark_mode'] == 'true',
            onChanged: (val) => ref
                .read(settingsStateProvider.notifier)
                .updateSetting('dark_mode', val.toString()),
          ),
          const ListTile(title: Text('Primary Theme Color')),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 10,
              children:
                  [
                    Colors.green,
                    Colors.blue,
                    Colors.brown,
                    Colors.orange,
                    Colors.red,
                    Colors.blueGrey,
                  ].map((color) {
                    return GestureDetector(
                      onTap: () => ref
                          .read(settingsStateProvider.notifier)
                          .updateSetting(
                            'primary_color',
                            '0x${color.toARGB32().toRadixString(16)}',
                          ),
                      child: CircleAvatar(
                        backgroundColor: color,
                        child: primaryColor.toARGB32() == color.toARGB32()
                            ? const Icon(Icons.check, color: Colors.white)
                            : null,
                      ),
                    );
                  }).toList(),
            ),
          ),
          const VoiceSettingsWidget(),

          const Divider(),
          _buildSection(context, 'Production Modules'),
          SwitchListTile(
            title: const Text('Enable Milking Records'),
            subtitle: const Text('Track daily milk yield, fat/protein content & SCC quality'),
            value: settings['module_milking_enabled'] == 'true',
            onChanged: (val) => ref
                .read(settingsStateProvider.notifier)
                .updateSetting('module_milking_enabled', val.toString()),
          ),
          SwitchListTile(
            title: const Text('Enable Meat Production'),
            subtitle: const Text('Track slaughter records, carcass weights & cut yields'),
            value: settings['module_meat_enabled'] == 'true',
            onChanged: (val) => ref
                .read(settingsStateProvider.notifier)
                .updateSetting('module_meat_enabled', val.toString()),
          ),

          const Divider(),
          _buildSection(context, 'Data Management'),
          ListTile(
            leading: const Icon(Icons.cloud_upload_outlined),
            title: const Text('Import Herd Data'),
            subtitle: const Text('Upload CSV/Excel spreadsheet records'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ImportHomeScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.picture_as_pdf_outlined),
            title: const Text('Manage Custom Registry Forms'),
            subtitle: const Text(
              'Upload or delete breed registry interactive PDF templates',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const CustomFormsSettingsScreen(),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.backup_outlined),
            title: const Text('Backup Database'),
            subtitle: const Text('Save a copy of your herd database file'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _backupDatabase(context),
          ),
          ListTile(
            leading: const Icon(Icons.settings_backup_restore_outlined),
            title: const Text('Restore Database'),
            subtitle: const Text(
              'Replace all current records with a backup file',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _restoreDatabase(context),
          ),
          ListTile(
            leading: const Icon(Icons.sync),
            title: const Text('Cloud Sync Settings'),
            subtitle: const Text(
              'Sync database between devices using Supabase',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SyncSettingsScreen()),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSection(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  void _showNameDialog(BuildContext context, WidgetRef ref, String? current) {
    final controller = TextEditingController(text: current);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update Ranch Name'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'e.g. Blue Ridge Kikos'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              ref
                  .read(settingsStateProvider.notifier)
                  .updateSetting('farm_name', controller.text);
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showAddressDialog(
    BuildContext context,
    WidgetRef ref,
    String? current,
  ) {
    final controller = TextEditingController(text: current);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update Ranch Address'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'e.g. 123 Goat Lane, Marlow, OK',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              ref
                  .read(settingsStateProvider.notifier)
                  .updateSetting('farm_address', controller.text);
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showPhoneDialog(BuildContext context, WidgetRef ref, String? current) {
    final controller = TextEditingController(text: current);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update Ranch Telephone'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.phone,
          inputFormatters: [PhoneNumberFormatter()],
          decoration: const InputDecoration(hintText: 'e.g. (555)123-4567'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              ref
                  .read(settingsStateProvider.notifier)
                  .updateSetting('farm_phone', controller.text);
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showOwnerNameDialog(
    BuildContext context,
    WidgetRef ref,
    String? current,
  ) {
    final controller = TextEditingController(text: current);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update Ranch Owner Name'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'e.g. Jane Doe'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              ref
                  .read(settingsStateProvider.notifier)
                  .updateSetting('owner_name', controller.text);
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showEmailDialog(BuildContext context, WidgetRef ref, String? current) {
    final controller = TextEditingController(text: current);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update Ranch Email Address'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(hintText: 'e.g. info@ranch.com'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              ref
                  .read(settingsStateProvider.notifier)
                  .updateSetting('farm_email', controller.text);
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showNkrClientIdDialog(
    BuildContext context,
    WidgetRef ref,
    String? current,
  ) {
    final controller = TextEditingController(text: current);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update NKR Client ID'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'e.g. NKR-12345'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              ref
                  .read(settingsStateProvider.notifier)
                  .updateSetting('nkr_client_id', controller.text);
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showNkrHerdPrefixDialog(
    BuildContext context,
    WidgetRef ref,
    String? current,
  ) {
    final controller = TextEditingController(text: current);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update NKR Herd Prefix'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'e.g. ABC'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              ref
                  .read(settingsStateProvider.notifier)
                  .updateSetting('nkr_herd_prefix', controller.text);
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _resetRanchProfile(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Ranch Profile?'),
        content: const Text(
          'This clears the ranch name, address, telephone, owner name, email, '
          'NKR client ID, herd prefix, and logo from this device and your '
          'cloud account. Your animals and records are NOT affected. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    await DatabaseHelper().clearLocalProfileSettings();
    final cloudError = await SyncService().resetCloudProfile();
    await ref.read(settingsStateProvider.notifier).loadSettings();

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            cloudError == null
                ? 'Ranch profile reset.'
                : 'Profile reset on this device. Cloud cleanup failed: $cloudError',
          ),
        ),
      );
    }
  }

  Future<void> _backupDatabase(BuildContext context) async {
    try {
      final sourcePath = await DatabaseHelper().getDatabasePath();
      final sourceFile = File(sourcePath);
      if (!await sourceFile.exists()) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Error: Local database file not found.'),
            ),
          );
        }
        return;
      }

      final dateStr = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final fileName = 'flockkeeper_backup_$dateStr.db';

      if (Platform.isAndroid || Platform.isIOS) {
        // Mobile: saveFile requires bytes to be provided directly
        final bytes = await sourceFile.readAsBytes();
        final outputFile = await FilePicker.platform.saveFile(
          dialogTitle: 'Save Database Backup',
          fileName: fileName,
          type: FileType.any,
          bytes: bytes,
        );
        if (outputFile != null && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Database backup saved successfully!'),
            ),
          );
        }
      } else {
        // Desktop: saveFile returns a path; copy the source file there
        final outputFile = await FilePicker.platform.saveFile(
          dialogTitle: 'Save Database Backup',
          fileName: fileName,
          type: FileType.any,
        );
        if (outputFile != null) {
          await sourceFile.copy(outputFile);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Database backup saved successfully!'),
              ),
            );
          }
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Backup failed: $e')));
      }
    }
  }

  Future<void> _restoreDatabase(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restore Database?'),
        content: const Text(
          'Warning: This will overwrite and replace all current goat records, weight logs, and ranch settings with the backup file. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Restore & Overwrite'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        final selectedPath = result.files.single.path!;
        final destPath = await DatabaseHelper().getDatabasePath();

        // Close db connection and copy the new file over
        await DatabaseHelper().close();
        await File(selectedPath).copy(destPath);

        if (context.mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              title: const Text('Restore Successful'),
              content: const Text(
                'Database restored successfully! Please restart the FlockKeeper application to load the restored data.',
              ),
              actions: [
                ElevatedButton(
                  onPressed: () => exit(0),
                  child: const Text('Restart Now'),
                ),
              ],
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Restore failed: $e')));
      }
    }
  }
}

class CustomFormsSettingsScreen extends ConsumerStatefulWidget {
  const CustomFormsSettingsScreen({super.key});

  @override
  ConsumerState<CustomFormsSettingsScreen> createState() =>
      _CustomFormsSettingsScreenState();
}

class _CustomFormsSettingsScreenState
    extends ConsumerState<CustomFormsSettingsScreen> {
  List<File> _customForms = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCustomForms();
  }

  Future<void> _loadCustomForms() async {
    setState(() => _isLoading = true);
    try {
      final directory = await getApplicationDocumentsDirectory();
      final customFormsDir = Directory(
        p.join(directory.path, 'custom_registry_forms'),
      );
      if (!await customFormsDir.exists()) {
        await customFormsDir.create(recursive: true);
      }
      final files = customFormsDir.listSync();
      setState(() {
        _customForms = files
            .whereType<File>()
            .where((f) => f.path.toLowerCase().endsWith('.pdf'))
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading custom forms: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _uploadCustomForm() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        final pickedPath = result.files.single.path!;
        final directory = await getApplicationDocumentsDirectory();
        final customFormsDir = Directory(
          p.join(directory.path, 'custom_registry_forms'),
        );
        if (!await customFormsDir.exists()) {
          await customFormsDir.create(recursive: true);
        }

        final fileName = p.basename(pickedPath);
        final destPath = p.join(customFormsDir.path, fileName);
        await File(pickedPath).copy(destPath);

        await _loadCustomForms();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Uploaded custom form: $fileName')),
          );
        }
      }
    } catch (e) {
      debugPrint('Error picking custom form: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to upload form: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteCustomForm(File file) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Custom Form?'),
        content: Text(
          'Are you sure you want to delete ${p.basename(file.path)}? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        if (await file.exists()) {
          await file.delete();
        }
        await _loadCustomForms();
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Deleted custom form.')));
        }
      } catch (e) {
        debugPrint('Error deleting custom form: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete form: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Registry Forms'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Upload Registry Form (PDF)',
            onPressed: _uploadCustomForm,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _customForms.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.picture_as_pdf_outlined,
                    size: 64,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No custom registry forms uploaded yet.',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _uploadCustomForm,
                    icon: const Icon(Icons.upload_file),
                    label: const Text('Upload PDF Form'),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _customForms.length,
              itemBuilder: (context, index) {
                final file = _customForms[index];
                final fileName = p.basename(file.path);
                return Card(
                  child: ListTile(
                    leading: const Icon(
                      Icons.picture_as_pdf,
                      color: Colors.red,
                    ),
                    title: Text(fileName),
                    subtitle: Text(
                      'Path: ${file.path}',
                      style: const TextStyle(fontSize: 11),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _deleteCustomForm(file),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class VoiceSettingsWidget extends ConsumerStatefulWidget {
  const VoiceSettingsWidget({super.key});

  @override
  ConsumerState<VoiceSettingsWidget> createState() =>
      _VoiceSettingsWidgetState();
}

class _VoiceSettingsWidgetState extends ConsumerState<VoiceSettingsWidget> {
  List<Map<String, String>> _availableVoices = [];
  bool _loadingVoices = true;
  final FlutterTts _tts = FlutterTts();
  bool _isSpeaking = false;

  @override
  void initState() {
    super.initState();
    _loadAvailableVoices();
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }

  Future<void> _speakSample({String? voiceName}) async {
    if (_isSpeaking) {
      await _tts.stop();
      setState(() => _isSpeaking = false);
      return;
    }

    final settings = ref.read(settingsStateProvider);
    final rate = double.tryParse(settings['voice_rate'] ?? '0.52') ?? 0.52;
    final pitch = double.tryParse(settings['voice_pitch'] ?? '1.0') ?? 1.0;
    final voice = voiceName ?? settings['voice_name'];

    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(rate);
    await _tts.setPitch(pitch);
    await _tts.setVolume(1.0);

    if (voice != null && voice.isNotEmpty) {
      try {
        final List<dynamic>? voices = await _tts.getVoices;
        if (voices != null) {
          final targetVoice = voices.firstWhere(
            (v) => v['name'] == voice,
            orElse: () => null,
          );
          if (targetVoice != null) {
            await _tts.setVoice(Map<String, String>.from(targetVoice));
          }
        }
      } catch (e) {
        debugPrint('Error setting voice for sample: $e');
      }
    }

    setState(() => _isSpeaking = true);
    _tts.setCompletionHandler(() {
      if (mounted) setState(() => _isSpeaking = false);
    });

    await _tts.speak('Keeko Keeper here, how can I help?');
  }

  Future<void> _loadAvailableVoices() async {
    try {
      final tts = FlutterTts();
      final List<dynamic>? rawVoices = await tts.getVoices;
      if (rawVoices != null) {
        final List<Map<String, String>> allVoices = [];
        for (var voice in rawVoices) {
          if (voice is Map) {
            final name = voice['name']?.toString();
            final locale = voice['locale']?.toString();

            // Only include voices with valid name and locale
            if (name != null &&
                name.isNotEmpty &&
                locale != null &&
                locale.isNotEmpty) {
              // Include all voices, not just English ones
              // To filter by specific languages, uncomment and modify:
              // if (locale.toLowerCase().startsWith('en-') ||
              //     locale.toLowerCase().startsWith('es-') ||
              //     locale.toLowerCase().startsWith('fr-')) {
              allVoices.add({'name': name, 'locale': locale});
              // }
            }
          }
        }
        // Sort voices by locale for better organization
        allVoices.sort((a, b) {
          final localeA = a['locale'] ?? '';
          final localeB = b['locale'] ?? '';
          return localeA.compareTo(localeB);
        });

        setState(() {
          _availableVoices = allVoices;
          _loadingVoices = false;
        });
      } else {
        setState(() {
          _loadingVoices = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading TTS voices: $e');
      setState(() {
        _loadingVoices = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsStateProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            'Voice Assistant Settings',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),

        // Speed Slider
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Speech Speed (Rate)'),
                  Text(
                    '${(double.tryParse(settings['voice_rate'] ?? '0.52') ?? 0.52).toStringAsFixed(2)}x',
                    style: const TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                ],
              ),
              Slider(
                min: 0.1,
                max: 1.0,
                value:
                    double.tryParse(settings['voice_rate'] ?? '0.52') ?? 0.52,
                onChanged: (val) {
                  ref
                      .read(settingsStateProvider.notifier)
                      .updateSetting('voice_rate', val.toStringAsFixed(2));
                },
              ),
            ],
          ),
        ),

        // Pitch Slider
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Speech Pitch'),
                  Text(
                    (double.tryParse(settings['voice_pitch'] ?? '1.0') ?? 1.0)
                        .toStringAsFixed(2),
                    style: const TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                ],
              ),
              Slider(
                min: 0.5,
                max: 2.0,
                value: double.tryParse(settings['voice_pitch'] ?? '1.0') ?? 1.0,
                onChanged: (val) {
                  ref
                      .read(settingsStateProvider.notifier)
                      .updateSetting('voice_pitch', val.toStringAsFixed(2));
                },
              ),
            ],
          ),
        ),

        // Voice Selector
        if (!_loadingVoices && _availableVoices.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Voice Style / Accent'),
                    TextButton.icon(
                      onPressed: _speakSample,
                      icon: Icon(
                        _isSpeaking
                            ? Icons.stop_circle_outlined
                            : Icons.play_circle_outline,
                        size: 18,
                      ),
                      label: Text(_isSpeaking ? 'Stop' : 'Preview'),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  isExpanded: true,
                  initialValue:
                      _availableVoices.any(
                        (v) => v['name'] == settings['voice_name'],
                      )
                      ? settings['voice_name']
                      : null,
                  hint: const Text('Default System Voice'),
                  items: [
                    const DropdownMenuItem<String>(
                      value: '',
                      child: Text('Default System Voice'),
                    ),
                    ..._availableVoices.map((voice) {
                      final voiceName = voice['name'] ?? '';
                      final voiceLocale = voice['locale'] ?? '';
                      final displayName = voiceName
                          .replaceAll('com.apple.ttsbundle.', '')
                          .replaceAll('-compact', '');
                      return DropdownMenuItem<String>(
                        value: voiceName,
                        child: Text('$displayName ($voiceLocale)'),
                      );
                    }),
                  ],
                  onChanged: (val) {
                    ref
                        .read(settingsStateProvider.notifier)
                        .updateSetting('voice_name', val ?? '');
                    _speakSample(voiceName: val ?? '');
                  },
                ),
              ],
            ),
          )
        else if (_loadingVoices)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16.0),
            child: Center(child: CircularProgressIndicator()),
          ),
      ],
    );
  }
}
