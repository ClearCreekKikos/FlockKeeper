import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/database/database_helper.dart';
import '../utils/path_resolver.dart';

import '../../app/config.dart';

class SyncService {
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  SyncService._internal();

  Future<String?> _uploadFile(
    SupabaseClient client,
    String userId,
    String remoteFolder,
    String localPath,
    String fileName,
  ) async {
    final file = File(localPath);
    if (!await file.exists()) return null;

    final remotePath = '$userId/$remoteFolder/$fileName';
    try {
      final bytes = await file.readAsBytes();
      await client.storage
          .from('flockkeeper')
          .uploadBinary(
            remotePath,
            bytes,
            fileOptions: const FileOptions(upsert: true),
          );
      return remotePath;
    } catch (e) {
      debugPrint('Error uploading file $localPath to $remotePath: $e');
      return null;
    }
  }

  Future<String?> _downloadFile(
    SupabaseClient client,
    String remotePath,
    String localFolder,
    String fileName,
  ) async {
    try {
      final docDir = await getApplicationDocumentsDirectory();
      final localDir = Directory(
        p.join(docDir.path, 'flockkeeper_media', localFolder),
      );
      if (!await localDir.exists()) {
        await localDir.create(recursive: true);
      }
      final localFilePath = p.join(localDir.path, fileName);
      final file = File(localFilePath);

      // Download bytes from storage
      final bytes = await client.storage
          .from('flockkeeper')
          .download(remotePath);
      await file.writeAsBytes(bytes);
      return localFilePath;
    } catch (e) {
      debugPrint('Error downloading file $remotePath: $e');
      return null;
    }
  }

  SupabaseClient? _client;
  static String? lastInitError;

  Future<SupabaseClient?> getClient() async {
    if (_client != null) return _client;

    final db = DatabaseHelper();
    final enabled = await db.getSetting('sync_enabled');

    if (enabled != 'true') {
      lastInitError = 'Sync is not enabled in local settings.';
      return null;
    }

    if (AppConfig.supabaseUrl.isEmpty ||
        AppConfig.supabaseUrl == 'YOUR_SUPABASE_PROJECT_URL' ||
        AppConfig.supabaseAnonKey.isEmpty ||
        AppConfig.supabaseAnonKey == 'YOUR_SUPABASE_ANON_KEY') {
      lastInitError =
          'Supabase URL or Anon Key is not configured in config.dart.';
      return null;
    }

    try {
      final client = Supabase.instance.client;
      final sessionJson = await db.getSetting('sync_supabase_session');
      if (sessionJson != null && sessionJson.isNotEmpty) {
        try {
          final res = await client.auth.recoverSession(sessionJson);
          if (res.session != null) {
            await db.setSetting(
              'sync_supabase_session',
              jsonEncode(res.session!.toJson()),
            );
          }
        } catch (e) {
          debugPrint('Failed to recover session on getClient: $e');
        }
      }
      _client = client;
      lastInitError = null;
      return _client;
    } catch (e, stack) {
      lastInitError = '$e\n$stack';
      debugPrint('SyncService Client init failed: $e');
      return null;
    }
  }

  void resetClient() {
    _client = null;
  }

  /// Signs out from Supabase and clears the cached client so
  /// the next getClient() call starts a fresh session.
  Future<void> signOut() async {
    try {
      final client = Supabase.instance.client;
      await client.auth.signOut();
    } catch (e) {
      debugPrint('SyncService signOut error: $e');
    } finally {
      _client = null;
      try {
        final db = DatabaseHelper();
        // Clear all user database tables (animals, weight logs, pastures, dewormings, etc.)
        // and delete user-profile settings (including 'is_premium').
        await db.clearUserData();
        
        // Reset auth and synchronization settings to defaults to prevent data leakage.
        await db.setSetting('sync_enabled', 'false');
        await db.setSetting('sync_supabase_session', '');
        await db.setSetting('sync_email', '');
        await db.setSetting('sync_remember_me', 'false');
        await db.setSetting('sync_last_time', '1970-01-01T00:00:00.000Z');
        await db.setSetting('logged_in_user_id', '');
      } catch (dbError) {
        debugPrint('SyncService signOut DB clear error: $dbError');
      }
    }
  }

  Future<bool> testConnection() async {
    if (AppConfig.supabaseUrl.isEmpty ||
        AppConfig.supabaseUrl == 'YOUR_SUPABASE_PROJECT_URL' ||
        AppConfig.supabaseAnonKey.isEmpty ||
        AppConfig.supabaseAnonKey == 'YOUR_SUPABASE_ANON_KEY') {
      return false;
    }
    try {
      final client = Supabase.instance.client;
      // Simple connection check using animals table which we know exists
      await client.from('animals').select('id').limit(1);
      return true;
    } catch (e) {
      debugPrint('Supabase connection test failed: $e');
      return false;
    }
  }

  /// Deletes the current user's per-user profile settings from the cloud
  /// (ranch name, address, phone, email, owner, NKR ids, logo path). Used by
  /// the in-app "Reset Ranch Profile" action to recover an account whose cloud
  /// profile was polluted by an earlier cross-user leak. Returns null on
  /// success (including when there is no cloud configured / not logged in, in
  /// which case there is simply nothing to clean), or an error string.
  Future<String?> resetCloudProfile() async {
    final client = await getClient();
    if (client == null) return null;
    final user = client.auth.currentUser;
    if (user == null) return null;
    try {
      for (final key in DatabaseHelper.userProfileSettingKeys) {
        await client
            .from('settings')
            .delete()
            .eq('user_id', user.id)
            .eq('key', key);
      }
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> syncNow() async {
    final client = await getClient();
    if (client == null) {
      return 'Sync disabled or credentials not configured.';
    }
    if (client.auth.currentSession == null) {
      return 'Authentication required. Please log in first.';
    }

    final db = DatabaseHelper();
    final lastSyncStr =
        await db.getSetting('sync_last_time') ?? '1970-01-01T00:00:00.000Z';
    final currentSyncTime = DateTime.now().toUtc().toIso8601String();

    try {
      // Temporarily disable foreign keys during sync to allow tables/records
      // (like parent/child animals) to sync in any order.
      await db.execute('PRAGMA foreign_keys = OFF');

      final tables = [
        'animals',
        'weight_records',
        'breeding_events',
        'kidding_records',
        'health_records',
        'pastures',
        'pasture_history',
        'vaccinations',
        'dewormings',
        'financial_records',
        'reminders',
        'notes',
      ];

      final currentUserId = client.auth.currentUser!.id;

      // 1. Process local deletions (Push to Supabase)
      final localDeletes = await db.query('deleted_records');
      for (final del in localDeletes) {
        final table = del['table_name'] as String;
        final id = del['record_id'] as int;

        try {
          // Delete from Supabase (only this user's record)
          await client
              .from(table)
              .delete()
              .eq('id', id)
              .eq('user_id', currentUserId);

          // Log delete in Supabase's deleted_records so other clients know
          await client.from('deleted_records').upsert({
            'table_name': table,
            'record_id': id,
            'deleted_at': del['deleted_at'],
            'user_id': currentUserId,
          }, onConflict: 'table_name, record_id, user_id');
        } catch (e) {
          debugPrint('Failed to delete remote record ($table, $id): $e');
        }

        // Clean up locally
        await db.delete(
          'deleted_records',
          where: 'id = ?',
          whereArgs: [del['id']],
        );
      }

      // 2. Pull remote deletions (only this user's)
      try {
        final remoteDeletes = await client
            .from('deleted_records')
            .select()
            .eq('user_id', currentUserId)
            .gt('deleted_at', lastSyncStr);
        for (final del in remoteDeletes) {
          final table = del['table_name'] as String;
          final id = del['record_id'] as int;

          // Delete locally and clear any cascading delete triggers
          await db.delete(table, where: 'id = ?', whereArgs: [id]);
          await db.delete(
            'deleted_records',
            where: 'table_name = ? AND record_id = ?',
            whereArgs: [table, id],
          );
        }
      } catch (e) {
        debugPrint('Failed to pull remote deletes: $e');
      }

      // 3. Bidirectional sync for all tables
      for (final table in tables) {
        // --- PUSH LOCAL CHANGES ---
        final localChanges = await db.query(
          table,
          where: 'updated_at > ?',
          whereArgs: [lastSyncStr],
        );
        for (final row in localChanges) {
          Map<String, dynamic> mutableRow = Map.from(row);

          // Explicitly associate the record with the currently logged-in user to comply with RLS
          mutableRow['user_id'] = currentUserId;

          if (table == 'animals') {
            final photoPath = mutableRow['photo_path'] as String?;
            if (photoPath != null && photoPath.isNotEmpty) {
              final userId = client.auth.currentUser!.id;
              if (photoPath.startsWith('$userId/')) {
                debugPrint('DEBUG SYNC: Animal ${mutableRow['name']} already has remote photo path: $photoPath');
              } else {
                // It's a local path, resolve and upload
                final resolvedPath = PathResolver.resolvePath(photoPath);
                debugPrint('DEBUG SYNC: Animal ${mutableRow['name']} has local photo path: $photoPath. Resolved to: $resolvedPath');
                if (resolvedPath != null && File(resolvedPath).existsSync()) {
                  final animalId = mutableRow['id'];
                  final ext = p.extension(resolvedPath);
                  final remoteFileName = 'animal_$animalId$ext';
                  debugPrint('DEBUG SYNC: Uploading animal photo from resolved local path: $resolvedPath to remote file: $remoteFileName');
                  final remotePath = await _uploadFile(
                    client,
                    userId,
                    'photos',
                    resolvedPath,
                    remoteFileName,
                  );
                  debugPrint('DEBUG SYNC: Upload result remote path: $remotePath');
                  if (remotePath != null) {
                    mutableRow['photo_path'] = remotePath;
                  } else {
                    // Upload failed, do not push the local path
                    mutableRow['photo_path'] = null;
                  }
                } else {
                  debugPrint('DEBUG SYNC: Animal photo file does not exist at resolved path: $resolvedPath');
                  // File does not exist locally, do not push the local path
                  mutableRow['photo_path'] = null;
                }
              }
            }
            // Map SQLite markings to Supabase color and remove markings before pushing to avoid DB error
            mutableRow['color'] = mutableRow['markings'];
            mutableRow.remove('markings');
          } else if (table == 'weight_records') {
            // Remove unsupported or calculated fields before pushing to avoid schema validation/generated column errors
            mutableRow.remove('weight_kg');
            mutableRow.remove('body_condition_score');
          }

          bool success = false;
          int retries = 0;
          while (!success) {
            try {
              await client.from(table).upsert(mutableRow);
              success = true;
            } on PostgrestException catch (pe) {
              if (pe.code == 'PGRST204' && retries < 15) {
                final reg = RegExp(r"Could not find the '([^']+)' column of");
                final match = reg.firstMatch(pe.message);
                if (match != null) {
                  final missingCol = match.group(1);
                  if (missingCol != null && mutableRow.containsKey(missingCol)) {
                    debugPrint('DEBUG SYNC: Table $table is missing column $missingCol on remote. Removing column and retrying...');
                    mutableRow.remove(missingCol);
                    retries++;
                    continue;
                  }
                }
              }
              rethrow;
            }
          }
        }

        // --- PULL REMOTE CHANGES (filter by user_id to enforce per-user isolation) ---
        final remoteChanges = await client
            .from(table)
            .select()
            .eq('user_id', currentUserId)
            .gt('updated_at', lastSyncStr);

        for (final row in remoteChanges) {
          final id = row['id'] as int;
          final remoteUpdatedAt = DateTime.parse(row['updated_at'] as String);

          Map<String, dynamic> mutableRow = Map.from(row);
          if (table == 'animals') {
            final remotePhotoPath = mutableRow['photo_path'] as String?;
            if (remotePhotoPath != null && remotePhotoPath.isNotEmpty) {
              final userId = client.auth.currentUser!.id;
              debugPrint('DEBUG SYNC PULL: Animal ${mutableRow['name']} has remote photo path: $remotePhotoPath');
              if (remotePhotoPath.startsWith('$userId/photos/')) {
                final fileName = p.basename(remotePhotoPath);
                final docDir = await getApplicationDocumentsDirectory();
                final localFilePath = p.join(
                  docDir.path,
                  'flockkeeper_media',
                  'photos',
                  fileName,
                );

                bool shouldDownload = true;
                final localRowList = await db.query(
                  table,
                  where: 'id = ?',
                  whereArgs: [id],
                );
                if (localRowList.isNotEmpty) {
                  final remoteUpdate = DateTime.parse(row['updated_at'] as String);
                  final localUpdate = DateTime.parse(
                    localRowList.first['updated_at'] as String,
                  );
                  shouldDownload = remoteUpdate.isAfter(localUpdate) || !File(localFilePath).existsSync();
                  debugPrint('DEBUG SYNC PULL: Animal local update: $localUpdate, remote update: $remoteUpdate. shouldDownload: $shouldDownload');
                }

                if (shouldDownload) {
                  debugPrint('DEBUG SYNC PULL: Downloading remote photo $remotePhotoPath to local path: $localFilePath');
                  final downloadedPath = await _downloadFile(
                    client,
                    remotePhotoPath,
                    'photos',
                    fileName,
                  );
                  debugPrint('DEBUG SYNC PULL: Download result path: $downloadedPath');
                  if (downloadedPath != null) {
                    mutableRow['photo_path'] = downloadedPath;
                  }
                } else {
                  mutableRow['photo_path'] = localFilePath;
                }
              } else {
                debugPrint('DEBUG SYNC PULL: Skipping download because remote path $remotePhotoPath does not start with $userId/photos/');
              }
            }
            // Map Supabase color back to SQLite markings
            mutableRow['markings'] = mutableRow['color'];
          } else if (table == 'weight_records') {
            // weight_kg is a generated column in older local databases, so it
            // can never be written directly. Strip it before the local insert/
            // update (mirrors the push side, which also removes it).
            mutableRow.remove('weight_kg');
          }

          final localRowList = await db.query(
            table,
            where: 'id = ?',
            whereArgs: [id],
          );
          if (localRowList.isEmpty) {
            await db.insert(table, mutableRow);
          } else {
            final localUpdatedAt = DateTime.parse(
              localRowList.first['updated_at'] as String,
            );
            if (remoteUpdatedAt.isAfter(localUpdatedAt)) {
              await db.update(
                table,
                mutableRow,
                where: 'id = ?',
                whereArgs: [id],
              );
            }
          }
        }
      }

      // --- SYNC SETTINGS ---
      debugPrint('DEBUG SYNC: Starting settings sync. lastSyncStr: $lastSyncStr');
      // 1. Pull remote settings first (filter by user_id)
      final remoteSettings = await client
          .from('settings')
          .select()
          .eq('user_id', currentUserId);
      debugPrint('DEBUG SYNC: Retrieved ${remoteSettings.length} remote settings from Supabase.');
      for (final setting in remoteSettings) {
        final key = setting['key'] as String;
        final value = setting['value'] as String?;
        debugPrint('DEBUG SYNC: Processing remote setting: key=$key, value=$value');
        if (key.startsWith('sync_')) {
          debugPrint('DEBUG SYNC: Skipping sync_ setting: $key');
          continue;
        }

        Map<String, dynamic> mutableSetting = Map.from(setting);
        if (key == 'farm_logo_path') {
          final remoteLogoPath = mutableSetting['value'] as String?;
          if (remoteLogoPath != null && remoteLogoPath.isNotEmpty) {
            final userId = client.auth.currentUser!.id;
            if (remoteLogoPath.startsWith('$userId/logos/')) {
              final fileName = p.basename(remoteLogoPath);
              final docDir = await getApplicationDocumentsDirectory();
              final localFilePath = p.join(
                docDir.path,
                'flockkeeper_media',
                'logos',
                fileName,
              );

              final localSetList = await db.query(
                'settings',
                where: 'key = ?',
                whereArgs: [key],
              );
              bool shouldDownload = true;
              if (localSetList.isNotEmpty) {
                final remoteUpdate = DateTime.parse(setting['updated_at'] as String);
                final localUpdate = DateTime.parse(
                  localSetList.first['updated_at'] as String,
                );
                final localVal = localSetList.first['value'] as String?;
                final isLocalDefault = localVal == null || localVal.isEmpty || lastSyncStr == '1970-01-01T00:00:00.000Z';
                shouldDownload = remoteUpdate.isAfter(localUpdate) || isLocalDefault || !File(localFilePath).existsSync();
              }

              if (shouldDownload) {
                final downloadedPath = await _downloadFile(
                  client,
                  remoteLogoPath,
                  'logos',
                  fileName,
                );
                if (downloadedPath != null) {
                  mutableSetting['value'] = downloadedPath;
                }
              } else {
                mutableSetting['value'] = localFilePath;
              }
            }
          }
        }

        final localSetList = await db.query(
          'settings',
          where: 'key = ?',
          whereArgs: [key],
        );
        if (localSetList.isEmpty) {
          debugPrint('DEBUG SYNC: Key $key not found locally. Inserting remote value: $value');
          await db.insert('settings', mutableSetting);
        } else {
          final remoteUpdate = DateTime.parse(setting['updated_at'] as String);
          final localUpdate = DateTime.parse(
            localSetList.first['updated_at'] as String,
          );
          final localVal = localSetList.first['value'] as String?;

          final isLocalDefault =
              key == 'farm_name' &&
                  (localVal == 'My Kiko Farm' || localVal == 'FlockKeeper') ||
              key == 'owner_name' && localVal == '' ||
              localVal == null ||
              localVal.isEmpty ||
              lastSyncStr == '1970-01-01T00:00:00.000Z';

          final shouldUpdate = remoteUpdate.isAfter(localUpdate) || isLocalDefault;
          debugPrint('DEBUG SYNC: Key $key exists locally (value: $localVal). remoteUpdate: $remoteUpdate, localUpdate: $localUpdate, isLocalDefault: $isLocalDefault, shouldUpdate: $shouldUpdate');

          if (shouldUpdate) {
            await db.update(
              'settings',
              mutableSetting,
              where: 'key = ?',
              whereArgs: [key],
            );
          }
        }
      }

      // 2. Push local settings next. Cross-user isolation is enforced by
      // clearUserData() on the login screen, which wipes the previous user's
      // profile BEFORE the first sync — so the only profile left to push
      // belongs to the current user, and it is safe to push even on the
      // initial epoch sync. (Default/empty values are still skipped below so
      // we don't clobber real cloud values during that first sync.)
      final localSettings = await db.query(
        'settings',
      );
      debugPrint('DEBUG SYNC: Pushing ${localSettings.length} local settings.');
      for (final setting in localSettings) {
        final key = setting['key'] as String;
        if (key.startsWith('sync_')) continue;
        if (key == 'logged_in_user_id') continue;

        final val = setting['value'] as String?;
        debugPrint('DEBUG SYNC: Checking local setting to push: key=$key, value=$val');
        if (val == null || val.isEmpty) {
          debugPrint('DEBUG SYNC: Skipping empty setting: $key');
          continue;
        }

        // Skip pushing default/empty values to avoid overwriting real cloud settings on new device logins
        final isDefault =
            key == 'farm_name' &&
                (val == 'My Kiko Farm' || val == 'FlockKeeper') ||
            key == 'owner_name' && val == '';
        if (isDefault) {
          debugPrint('DEBUG SYNC: Skipping default setting: $key');
          continue;
        }

        Map<String, dynamic> mutableSetting = Map.from(setting);
        mutableSetting['user_id'] = currentUserId;
        if (key == 'farm_logo_path') {
          final logoPath = mutableSetting['value'] as String?;
          if (logoPath != null && logoPath.isNotEmpty) {
            final userId = client.auth.currentUser!.id;
            if (logoPath.startsWith('$userId/')) {
              debugPrint('DEBUG SYNC: farm_logo_path already remote: $logoPath');
            } else {
              final resolvedPath = PathResolver.resolvePath(logoPath);
              debugPrint('DEBUG SYNC: farm_logo_path is local: $logoPath. Resolved: $resolvedPath');
              if (resolvedPath != null && File(resolvedPath).existsSync()) {
                final ext = p.extension(resolvedPath);
                final remoteFileName = 'farm_logo$ext';
                debugPrint('DEBUG SYNC: Uploading logo to remote: $remoteFileName');
                final remotePath = await _uploadFile(
                  client,
                  userId,
                  'logos',
                  resolvedPath,
                  remoteFileName,
                );
                debugPrint('DEBUG SYNC: Logo upload result: $remotePath');
                if (remotePath != null) {
                  mutableSetting['value'] = remotePath;
                } else {
                  mutableSetting['value'] = null;
                }
              } else {
                debugPrint('DEBUG SYNC: Logo file does not exist locally: $resolvedPath');
                mutableSetting['value'] = null;
              }
            }
          }
        }
        debugPrint('DEBUG SYNC: Upserting setting key=$key, value=${mutableSetting['value']} to Supabase...');
        await client
            .from('settings')
            .upsert(mutableSetting, onConflict: 'user_id,key');
      }

      // 3. Self-healing media download: check if any local records have missing photo/logo files and download them.
      debugPrint('DEBUG SYNC: Starting self-healing media check...');
      final localAnimals = await db.query('animals');
      for (final animal in localAnimals) {
        final photoPath = animal['photo_path'] as String?;
        if (photoPath != null && photoPath.isNotEmpty) {
          final fileName = p.basename(photoPath);
          final docDir = await getApplicationDocumentsDirectory();
          final localFilePath = p.join(
            docDir.path,
            'flockkeeper_media',
            'photos',
            fileName,
          );
          if (!File(localFilePath).existsSync()) {
            final remotePath = '$currentUserId/photos/$fileName';
            debugPrint('DEBUG SYNC: Local photo file missing for animal ${animal['name']} at $localFilePath. Attempting redownload from remote: $remotePath');
            final downloadedPath = await _downloadFile(
              client,
              remotePath,
              'photos',
              fileName,
            );
            debugPrint('DEBUG SYNC: Redownload result: $downloadedPath');
            if (downloadedPath != null) {
              await db.update(
                'animals',
                {'photo_path': downloadedPath},
                where: 'id = ?',
                whereArgs: [animal['id']],
              );
            }
          }
        }
      }

      // Self-healing for ranch logo
      final farmLogoSetting = await db.getSetting('farm_logo_path');
      if (farmLogoSetting != null && farmLogoSetting.isNotEmpty) {
        final fileName = p.basename(farmLogoSetting);
        final docDir = await getApplicationDocumentsDirectory();
        final localFilePath = p.join(
          docDir.path,
          'flockkeeper_media',
          'logos',
          fileName,
        );
        if (!File(localFilePath).existsSync()) {
          final remotePath = '$currentUserId/logos/$fileName';
          debugPrint('DEBUG SYNC: Local logo file missing at $localFilePath. Attempting redownload from remote: $remotePath');
          final downloadedPath = await _downloadFile(
            client,
            remotePath,
            'logos',
            fileName,
          );
          debugPrint('DEBUG SYNC: Logo redownload result: $downloadedPath');
          if (downloadedPath != null) {
            await db.setSetting('farm_logo_path', downloadedPath);
          }
        }
      }

      // Update last sync time
      await db.setSetting('sync_last_time', currentSyncTime);
      return null;
    } catch (e) {
      debugPrint('Sync failed: $e');
      return e.toString();
    } finally {
      try {
        await db.execute('PRAGMA foreign_keys = ON');
      } catch (e) {
        debugPrint('Failed to re-enable foreign keys after sync: $e');
        // Non-fatal: foreign keys should already be enabled by default
      }
    }
  }

  /// Permanently deletes the current user's account and all associated data.
  /// 1. Deletes all rows from every synced cloud table for this user.
  /// 2. Removes all files from the user's storage folder.
  /// 3. Clears all local data and settings.
  /// 4. Signs out from Supabase.
  ///
  /// Returns null on success, or an error string on failure.
  Future<String?> deleteAccount() async {
    final client = await getClient();
    if (client == null) return 'Not connected to cloud services.';

    final user = client.auth.currentUser;
    if (user == null) return 'No authenticated user found.';

    final userId = user.id;

    try {
      // 1. Delete all user data from cloud tables
      final tables = [
        'deleted_records',
        'notes',
        'reminders',
        'financial_records',
        'dewormings',
        'vaccinations',
        'pasture_history',
        'pastures',
        'health_records',
        'kidding_records',
        'breeding_events',
        'weight_records',
        'animals',
        'settings',
      ];

      for (final table in tables) {
        try {
          await client.from(table).delete().eq('user_id', userId);
        } catch (e) {
          debugPrint('Failed to delete from cloud table $table: $e');
          // Continue with other tables even if one fails
        }
      }

      // 2. Delete all files from user's storage folder
      try {
        for (final folder in ['photos', 'logos']) {
          try {
            final files = await client.storage
                .from('flockkeeper')
                .list(path: '$userId/$folder');
            if (files.isNotEmpty) {
              final paths = files
                  .map((f) => '$userId/$folder/${f.name}')
                  .toList();
              await client.storage.from('flockkeeper').remove(paths);
            }
          } catch (e) {
            debugPrint('Failed to delete storage folder $folder: $e');
          }
        }
      } catch (e) {
        debugPrint('Failed to clean storage: $e');
      }

      // 3. Clear all local data
      final db = DatabaseHelper();
      await db.clearUserData();
      await db.clearAllData();

      // 4. Clear local auth/sync settings
      await db.setSetting('sync_enabled', 'false');
      await db.setSetting('sync_supabase_session', '');
      await db.setSetting('sync_email', '');
      await db.setSetting('sync_remember_me', 'false');
      await db.setSetting('sync_last_time', '1970-01-01T00:00:00.000Z');
      await db.setSetting('logged_in_user_id', '');

      // 5. Sign out
      await signOut();

      return null;
    } catch (e) {
      debugPrint('Account deletion failed: $e');
      return e.toString();
    }
  }
}
