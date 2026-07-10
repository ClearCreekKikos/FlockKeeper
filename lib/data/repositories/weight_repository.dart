// lib/data/repositories/weight_repository.dart

import '../database/database_helper.dart';
import '../models/weight_record_model.dart';

class WeightRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  // ─── Create ───────────────────────────────────────────────────────────────
  Future<int> insertWeightRecord(WeightRecord record) async {
    final now = DateTime.now();
    final recordWithTimestamp = record.copyWith(
      createdAt: now,
    );

    return await _dbHelper.insert(
      DatabaseHelper.tableWeightRecords,
      recordWithTimestamp.toMap(),
    );
  }

  // ─── Read ─────────────────────────────────────────────────────────────────

  /// Gets all weight records for a specific animal, ordered by date (newest first)
  Future<List<WeightRecord>> getWeightRecordsForAnimal(int animalId) async {
    final maps = await _dbHelper.query(
      DatabaseHelper.tableWeightRecords,
      where: 'animal_id = ?',
      whereArgs: [animalId],
      orderBy: 'weigh_date DESC',
    );
    return maps.map((map) => WeightRecord.fromMap(map)).toList();
  }

  /// Gets the single most recent weight record for an animal
  Future<WeightRecord?> getLatestWeightForAnimal(int animalId) async {
    final maps = await _dbHelper.query(
      DatabaseHelper.tableWeightRecords,
      where: 'animal_id = ?',
      whereArgs: [animalId],
      orderBy: 'weigh_date DESC',
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return WeightRecord.fromMap(maps.first);
  }

  /// Gets a specific weight record by its ID
  Future<WeightRecord?> getWeightRecordById(int id) async {
    final maps = await _dbHelper.query(
      DatabaseHelper.tableWeightRecords,
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return WeightRecord.fromMap(maps.first);
  }

  // ─── Update ───────────────────────────────────────────────────────────────
  Future<int> updateWeightRecord(WeightRecord record) async {
    if (record.id == null) {
      throw Exception('Cannot update a weight record without an ID');
    }

    return await _dbHelper.update(
      DatabaseHelper.tableWeightRecords,
      record.toMap(),
      where: 'id = ?',
      whereArgs: [record.id],
    );
  }

  // ─── Delete ───────────────────────────────────────────────────────────────
  Future<int> deleteWeightRecord(int id) async {
    return await _dbHelper.delete(
      DatabaseHelper.tableWeightRecords,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ─── Analytics & Calculations ─────────────────────────────────────────────

  /// Calculates Average Daily Gain (ADG) between the first and last recorded weights.
  /// Extremely important for tracking Kiko meat production performance.
  Future<double?> calculateLifetimeADG(int animalId) async {
    final records = await getWeightRecordsForAnimal(animalId);
    
    // Fetch birth data from animal table
    final animalData = await _dbHelper.query(
      DatabaseHelper.tableAnimals,
      where: 'id = ?',
      whereArgs: [animalId],
      columns: ['dob', 'birth_weight_lbs'],
    );

    final double? birthWeight = animalData.isNotEmpty 
        ? animalData.first['birth_weight_lbs'] as double? 
        : null;

    if (records.isEmpty && birthWeight == null) return null;
    if (records.length < 2 && birthWeight == null) return null;

    // Records are sorted DESC (newest first)
    final latestRecord = records.first;

    double startingWeight;
    DateTime startingDate;

    if (birthWeight != null) {
      if (animalData.isNotEmpty && animalData.first['dob'] != null) {
        startingWeight = birthWeight;
        startingDate = DateTime.parse(animalData.first['dob'] as String);
      } else {
        // Fallback to oldest record if DOB is missing
        startingWeight = records.last.weightLbs;
        startingDate = records.last.weighDate;
      }
    } else {
      // Use the oldest recorded weight
      startingWeight = records.last.weightLbs;
      startingDate = records.last.weighDate;
    }

    final daysBetween = latestRecord.weighDate.difference(startingDate).inDays;

    if (daysBetween <= 0) return 0.0; // Prevent division by zero

    final weightGained = latestRecord.weightLbs - startingWeight;

    return weightGained / daysBetween;
  }

  /// Calculates ADG over the last N weigh-ins (e.g., last 3)
  Future<double?> calculateRecentADG(int animalId, int pointCount) async {
    final records = await getWeightRecordsForAnimal(animalId);
    
    if (records.length < pointCount) return null;

    // Records are sorted DESC
    final newest = records.first;
    final oldestOfRange = records[pointCount - 1];

    final daysBetween = newest.weighDate.difference(oldestOfRange.weighDate).inDays;
    if (daysBetween <= 0) return null;

    final weightGained = newest.weightLbs - oldestOfRange.weightLbs;
    return weightGained / daysBetween;
  }

  /// Calculates ADG between two specific consecutive weight records
  double calculatePeriodADG(WeightRecord olderRecord, WeightRecord newerRecord) {
    final daysBetween = newerRecord.weighDate.difference(olderRecord.weighDate).inDays;
    if (daysBetween <= 0) return 0.0;

    final weightGained = newerRecord.weightLbs - olderRecord.weightLbs;
    return weightGained / daysBetween;
  }

  /// Finds the weight record closest to a specific target date within a tolerance
  Future<WeightRecord?> getWeightClosestToDate(
    int animalId,
    DateTime targetDate, {
    int toleranceDays = 14,
  }) async {
    final records = await getWeightRecordsForAnimal(animalId);
    if (records.isEmpty) return null;

    WeightRecord? closest;
    int minDiff = 999999;

    for (var r in records) {
      final diff = r.weighDate.difference(targetDate).inDays.abs();
      if (diff <= toleranceDays && diff < minDiff) {
        minDiff = diff;
        closest = r;
      }
    }
    return closest;
  }
}
