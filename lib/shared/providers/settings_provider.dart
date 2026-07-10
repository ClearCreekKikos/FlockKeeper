import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../../data/database/database_helper.dart';

class SettingsNotifier extends StateNotifier<Map<String, String>> {
  final DatabaseHelper _db = DatabaseHelper();

  SettingsNotifier() : super({}) {
    loadSettings();
  }

  Future<void> loadSettings() async {
    final keys = [
      'farm_name',
      'farm_logo_path',
      'primary_color',
      'dark_mode',
      'card_style',
      'farm_address',
      'farm_phone',
      'farm_email',
      'owner_name',
      'nkr_client_id',
      'nkr_herd_prefix',
      'voice_rate',
      'voice_pitch',
      'voice_name',
      'is_premium',
      'target_adg_high',
      'target_adg_min',
    ];

    Map<String, String> loaded = {};
    for (var key in keys) {
      final val = await _db.getSetting(key);
      if (val != null) loaded[key] = val;
    }

    // Default fallbacks
    loaded.putIfAbsent('primary_color', () => '0xFF4CAF50');
    loaded.putIfAbsent('farm_name', () => 'FlockKeeper');
    loaded.putIfAbsent('dark_mode', () => 'true');
    loaded.putIfAbsent('voice_rate', () => '0.52');
    loaded.putIfAbsent('voice_pitch', () => '1.0');
    loaded.putIfAbsent('is_premium', () => 'false');
    loaded.putIfAbsent('target_adg_high', () => '0.45');
    loaded.putIfAbsent('target_adg_min', () => '0.25');

    if (SchedulerBinding.instance.schedulerPhase != SchedulerPhase.idle) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        state = loaded;
      });
    } else {
      state = loaded;
    }
  }

  Future<void> updateSetting(String key, String value) async {
    await _db.setSetting(key, value);
    final updated = {...state, key: value};
    if (SchedulerBinding.instance.schedulerPhase != SchedulerPhase.idle) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        state = updated;
      });
    } else {
      state = updated;
    }
  }
}
