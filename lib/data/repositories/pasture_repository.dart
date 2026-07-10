// lib/data/repositories/pasture_repository.dart

import '../database/database_helper.dart';
import '../models/pasture_model.dart';
import '../models/animal_model.dart';

class PastureRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  // ─── Create ───────────────────────────────────────────────────────────────
  Future<int> insertPasture(Pasture pasture) async {
    final now = DateTime.now();
    return await _dbHelper.insert(
      DatabaseHelper.tablePastures,
      pasture.copyWith(createdAt: now, updatedAt: now).toMap(),
    );
  }

  // ─── Read ─────────────────────────────────────────────────────────────────
  Future<List<Pasture>> getAllPastures() async {
    // Also perform quick scan/refresh for resting pastures before loading
    await checkAndRefreshRestingPastures();
    final maps = await _dbHelper.query(DatabaseHelper.tablePastures);
    return maps.map((m) => Pasture.fromMap(m)).toList();
  }

  Future<List<Pasture>> getAvailablePastures() async {
    await checkAndRefreshRestingPastures();
    final maps = await _dbHelper.query(
      DatabaseHelper.tablePastures,
      where: 'status = ?',
      whereArgs: ['available'],
    );
    return maps.map((m) => Pasture.fromMap(m)).toList();
  }

  Future<Pasture?> getPastureById(int id) async {
    final maps = await _dbHelper.query(
      DatabaseHelper.tablePastures,
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return Pasture.fromMap(maps.first);
  }

  // ─── Update ───────────────────────────────────────────────────────────────
  Future<int> updatePasture(Pasture pasture) async {
    return await _dbHelper.update(
      DatabaseHelper.tablePastures,
      pasture.copyWith(updatedAt: DateTime.now()).toMap(),
      where: 'id = ?',
      whereArgs: [pasture.id],
    );
  }

  // ─── Delete ───────────────────────────────────────────────────────────────
  Future<int> deletePasture(int id) async {
    return await _dbHelper.delete(
      DatabaseHelper.tablePastures,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ─── Animals in Pasture ───────────────────────────────────────────────────
  Future<List<Animal>> getAnimalsInPasture(int pastureId) async {
    final db = await _dbHelper.database;
    final results = await db.rawQuery('''
      SELECT a.* FROM ${DatabaseHelper.tableAnimals} a
      INNER JOIN ${DatabaseHelper.tablePastureHistory} h ON a.id = h.animal_id
      WHERE h.pasture_id = ? AND h.move_out_date IS NULL AND a.status = 'active'
    ''', [pastureId]);
    return results.map((m) => Animal.fromMap(m)).toList();
  }

  // ─── Pasture for Animal ────────────────────────────────────────────────────
  Future<Pasture?> getPastureForAnimal(int animalId) async {
    final db = await _dbHelper.database;
    final results = await db.rawQuery('''
      SELECT p.* FROM ${DatabaseHelper.tablePastures} p
      INNER JOIN ${DatabaseHelper.tablePastureHistory} h ON p.id = h.pasture_id
      WHERE h.animal_id = ? AND h.move_out_date IS NULL
      LIMIT 1
    ''', [animalId]);
    if (results.isEmpty) return null;
    return Pasture.fromMap(results.first);
  }

  // ─── History ──────────────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getPastureHistory(int pastureId) async {
    final db = await _dbHelper.database;
    return await db.rawQuery('''
      SELECT h.*, a.name as animal_name, a.ear_tag as animal_ear_tag
      FROM ${DatabaseHelper.tablePastureHistory} h
      LEFT JOIN ${DatabaseHelper.tableAnimals} a ON h.animal_id = a.id
      WHERE h.pasture_id = ?
      ORDER BY h.move_in_date DESC, h.id DESC
    ''', [pastureId]);
  }

  // ─── Rotation Actions ─────────────────────────────────────────────────────
  Future<void> moveAnimalIntoPasture({
    required int animalId,
    required int pastureId,
    required DateTime moveInDate,
    String? forageConditionIn,
    String? notes,
  }) async {
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      // 1. Check out from any current pasture
      final activeGrazing = await txn.rawQuery('''
        SELECT * FROM ${DatabaseHelper.tablePastureHistory}
        WHERE animal_id = ? AND move_out_date IS NULL
      ''', [animalId]);

      for (final record in activeGrazing) {
        final recordId = record['id'] as int;
        final oldPastureId = record['pasture_id'] as int;

        // Check out
        await txn.update(
          DatabaseHelper.tablePastureHistory,
          {
            'move_out_date': moveInDate.toIso8601String(),
            'forage_condition_out': 'good',
            'updated_at': DateTime.now().toIso8601String(),
          },
          where: 'id = ?',
          whereArgs: [recordId],
        );

        // Recalculate count for old pasture
        await _recalculatePastureStatusAndCountTxn(txn, oldPastureId, moveInDate);
      }

      // 2. Insert new pasture history record
      await txn.insert(DatabaseHelper.tablePastureHistory, {
        'pasture_id': pastureId,
        'animal_id': animalId,
        'move_in_date': moveInDate.toIso8601String(),
        'forage_condition_in': forageConditionIn ?? 'good',
        'notes': notes,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      // 3. Recalculate count for new pasture
      await _recalculatePastureStatusAndCountTxn(txn, pastureId, moveInDate);
    });
  }

  Future<void> moveAnimalOutOfPasture({
    required int animalId,
    required int pastureId,
    required DateTime moveOutDate,
    String? forageConditionOut,
    String? notes,
  }) async {
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      // Find active record
      final records = await txn.query(
        DatabaseHelper.tablePastureHistory,
        where: 'animal_id = ? AND pasture_id = ? AND move_out_date IS NULL',
        whereArgs: [animalId, pastureId],
        limit: 1,
      );

      if (records.isNotEmpty) {
        final recordId = records.first['id'] as int;

        await txn.update(
          DatabaseHelper.tablePastureHistory,
          {
            'move_out_date': moveOutDate.toIso8601String(),
            'forage_condition_out': forageConditionOut ?? 'good',
            'notes': notes,
            'updated_at': DateTime.now().toIso8601String(),
          },
          where: 'id = ?',
          whereArgs: [recordId],
        );

        await _recalculatePastureStatusAndCountTxn(txn, pastureId, moveOutDate);
      }
    });
  }

  // ─── Auto-Refresher for Resting Pastures ───────────────────────────────────
  Future<void> checkAndRefreshRestingPastures() async {
    final db = await _dbHelper.database;
    final nowStr = DateTime.now().toIso8601String();
    
    final resting = await db.query(
      DatabaseHelper.tablePastures,
      where: 'status = ? AND available_date IS NOT NULL AND available_date <= ?',
      whereArgs: ['resting', nowStr],
    );

    for (final map in resting) {
      final id = map['id'] as int;
      await db.update(
        DatabaseHelper.tablePastures,
        {
          'status': 'available',
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [id],
      );
    }
  }

  // ─── Private Helper for Txn Recalculation ──────────────────────────────────
  Future<void> _recalculatePastureStatusAndCountTxn(dynamic txn, int pastureId, DateTime actionDate) async {
    final pastureMaps = await txn.query(
      DatabaseHelper.tablePastures,
      where: 'id = ?',
      whereArgs: [pastureId],
    );
    if (pastureMaps.isEmpty) return;

    final currentStatus = pastureMaps.first['status'] as String;
    final restDaysTarget = pastureMaps.first['rest_days_target'] as int? ?? 30;

    // Count active animals in this pasture
    final countResult = await txn.rawQuery('''
      SELECT COUNT(*) as cnt FROM ${DatabaseHelper.tablePastureHistory} h
      INNER JOIN ${DatabaseHelper.tableAnimals} a ON h.animal_id = a.id
      WHERE h.pasture_id = ? AND h.move_out_date IS NULL AND a.status = 'active'
    ''', [pastureId]);
    final count = countResult.first['cnt'] as int? ?? 0;

    String newStatus = currentStatus;
    String? lastGrazedDateStr;
    String? availableDateStr;

    if (count > 0) {
      newStatus = 'occupied';
    } else {
      if (currentStatus == 'occupied') {
        newStatus = 'resting';
        lastGrazedDateStr = actionDate.toIso8601String();
        availableDateStr = actionDate.add(Duration(days: restDaysTarget)).toIso8601String();
      } else if (currentStatus == 'available' || currentStatus == 'resting') {
        newStatus = 'available';
      }
    }

    await txn.update(
      DatabaseHelper.tablePastures,
      {
        'current_animal_count': count,
        'status': newStatus,
        'last_grazed_date': ?lastGrazedDateStr,
        'available_date': ?availableDateStr,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [pastureId],
    );
  }
}
