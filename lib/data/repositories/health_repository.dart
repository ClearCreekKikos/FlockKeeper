// lib/data/repositories/health_repository.dart

import '../database/database_helper.dart';
import '../models/health_record_model.dart';

class HealthRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  // ─── Create ───────────────────────────────────────────────────────────────
  Future<int> insertHealthRecord(HealthRecord record) async {
    final now = DateTime.now();
    final recordWithTimestamps = record.copyWith(
      createdAt: record.id == null ? now : record.createdAt,
      updatedAt: now,
    );

    // Auto-calculate withdrawal date if withdrawalDays is set but date isn't
    var finalRecord = recordWithTimestamps;
    if (finalRecord.withdrawalDays != null &&
        finalRecord.withdrawalDays! > 0 &&
        finalRecord.withdrawalDate == null) {
      finalRecord = finalRecord.copyWith(
        withdrawalDate: finalRecord.recordDate.add(
          Duration(days: finalRecord.withdrawalDays!),
        ),
      );
    }

    return await _dbHelper.insert(
      DatabaseHelper.tableHealthRecords,
      finalRecord.toMap(),
    );
  }

  // ─── Read ─────────────────────────────────────────────────────────────────

  /// Gets all health records for a specific animal (newest first)
  Future<List<HealthRecord>> getHealthRecordsForAnimal(int animalId) async {
    final maps = await _dbHelper.query(
      DatabaseHelper.tableHealthRecords,
      where: 'animal_id = ?',
      whereArgs: [animalId],
      orderBy: 'record_date DESC',
    );
    return maps.map((map) => HealthRecord.fromMap(map)).toList();
  }

  /// Gets a specific health record by its ID
  Future<HealthRecord?> getHealthRecordById(int id) async {
    final maps = await _dbHelper.query(
      DatabaseHelper.tableHealthRecords,
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return HealthRecord.fromMap(maps.first);
  }

  /// Gets all unresolved (ongoing) health issues for an animal
  Future<List<HealthRecord>> getUnresolvedRecordsForAnimal(int animalId) async {
    final maps = await _dbHelper.query(
      DatabaseHelper.tableHealthRecords,
      where: 'animal_id = ? AND resolved = 0',
      whereArgs: [animalId],
      orderBy: 'record_date DESC',
    );
    return maps.map((map) => HealthRecord.fromMap(map)).toList();
  }

  /// Gets records by type for an animal
  Future<List<HealthRecord>> getRecordsByType(
      int animalId,
      HealthRecordType type,
      ) async {
    final typeStr = _recordTypeToString(type);
    final maps = await _dbHelper.query(
      DatabaseHelper.tableHealthRecords,
      where: 'animal_id = ? AND record_type = ?',
      whereArgs: [animalId, typeStr],
      orderBy: 'record_date DESC',
    );
    return maps.map((map) => HealthRecord.fromMap(map)).toList();
  }

  /// Gets all upcoming follow-ups across the entire herd
  Future<List<HealthRecord>> getUpcomingFollowUps({int daysAhead = 14}) async {
    final now = DateTime.now();
    final futureLimit = now.add(Duration(days: daysAhead));

    final maps = await _dbHelper.query(
      DatabaseHelper.tableHealthRecords,
      where: '''
        follow_up_date IS NOT NULL 
        AND follow_up_date >= ? 
        AND follow_up_date <= ?
        AND resolved = 0
      ''',
      whereArgs: [
        now.toIso8601String(),
        futureLimit.toIso8601String(),
      ],
      orderBy: 'follow_up_date ASC',
    );
    return maps.map((map) => HealthRecord.fromMap(map)).toList();
  }

  /// CRITICAL: Gets all animals currently in a medication withdrawal period.
  /// These animals should NOT be sold for meat/milk.
  Future<List<HealthRecord>> getAnimalsInWithdrawal() async {
    final now = DateTime.now();
    final maps = await _dbHelper.query(
      DatabaseHelper.tableHealthRecords,
      where: 'withdrawal_date IS NOT NULL AND withdrawal_date > ?',
      whereArgs: [now.toIso8601String()],
      orderBy: 'withdrawal_date ASC',
    );
    return maps.map((map) => HealthRecord.fromMap(map)).toList();
  }

  // ─── Update ───────────────────────────────────────────────────────────────
  Future<int> updateHealthRecord(HealthRecord record) async {
    if (record.id == null) {
      throw Exception('Cannot update a health record without an ID');
    }

    return await _dbHelper.update(
      DatabaseHelper.tableHealthRecords,
      record.toMap(),
      where: 'id = ?',
      whereArgs: [record.id],
    );
  }

  /// Marks a health record as resolved
  Future<int> markResolved(int id) async {
    return await _dbHelper.update(
      DatabaseHelper.tableHealthRecords,
      {
        'resolved': 1,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ─── Delete ───────────────────────────────────────────────────────────────
  Future<int> deleteHealthRecord(int id) async {
    return await _dbHelper.delete(
      DatabaseHelper.tableHealthRecords,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ─── Analytics ────────────────────────────────────────────────────────────

  /// Calculates total health-related costs for an animal
  Future<double> getTotalHealthCostForAnimal(int animalId) async {
    final maps = await _dbHelper.rawQuery('''
      SELECT SUM(cost) as total 
      FROM ${DatabaseHelper.tableHealthRecords} 
      WHERE animal_id = ? AND cost IS NOT NULL
    ''', [animalId]);

    if (maps.isEmpty || maps.first['total'] == null) return 0.0;
    return (maps.first['total'] as num).toDouble();
  }

  /// Counts total health records for an animal
  Future<int> getHealthRecordCount(int animalId) async {
    final maps = await _dbHelper.rawQuery('''
      SELECT COUNT(*) as count 
      FROM ${DatabaseHelper.tableHealthRecords} 
      WHERE animal_id = ?
    ''', [animalId]);

    if (maps.isEmpty) return 0;
    return maps.first['count'] as int? ?? 0;
  }

  // ─── Private Helpers ──────────────────────────────────────────────────────
  String _recordTypeToString(HealthRecordType type) => type.name;
}
