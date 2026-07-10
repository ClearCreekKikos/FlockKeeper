// lib/data/repositories/financial_repository.dart

import '../database/database_helper.dart';
import '../models/financial_record_model.dart';

class FinancialRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  // ─── Create ───────────────────────────────────────────────────────────────
  Future<int> insertFinancialRecord(FinancialRecord record) async {
    final now = DateTime.now();
    final recordWithTimestamp = record.copyWith(
      createdAt: now,
      updatedAt: now,
    );

    return await _dbHelper.insert(
      DatabaseHelper.tableFinancialRecords,
      recordWithTimestamp.toMap(),
    );
  }

  // ─── Read ─────────────────────────────────────────────────────────────────
  
  /// Gets all financial records, ordered by date (newest first)
  Future<List<FinancialRecord>> getAllFinancialRecords() async {
    final maps = await _dbHelper.query(
      DatabaseHelper.tableFinancialRecords,
      orderBy: 'record_date DESC, id DESC',
    );
    return maps.map((map) => FinancialRecord.fromMap(map)).toList();
  }

  /// Gets financial records for a specific animal, ordered by date (newest first)
  Future<List<FinancialRecord>> getFinancialRecordsForAnimal(int animalId) async {
    final maps = await _dbHelper.query(
      DatabaseHelper.tableFinancialRecords,
      where: 'animal_id = ?',
      whereArgs: [animalId],
      orderBy: 'record_date DESC, id DESC',
    );
    return maps.map((map) => FinancialRecord.fromMap(map)).toList();
  }

  /// Gets a specific financial record by its ID
  Future<FinancialRecord?> getFinancialRecordById(int id) async {
    final maps = await _dbHelper.query(
      DatabaseHelper.tableFinancialRecords,
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return FinancialRecord.fromMap(maps.first);
  }

  // ─── Update ───────────────────────────────────────────────────────────────
  Future<int> updateFinancialRecord(FinancialRecord record) async {
    if (record.id == null) {
      throw Exception('Cannot update a financial record without an ID');
    }

    final recordWithTimestamp = record.copyWith(
      updatedAt: DateTime.now(),
    );

    return await _dbHelper.update(
      DatabaseHelper.tableFinancialRecords,
      recordWithTimestamp.toMap(),
      where: 'id = ?',
      whereArgs: [record.id],
    );
  }

  // ─── Delete ───────────────────────────────────────────────────────────────
  Future<int> deleteFinancialRecord(int id) async {
    return await _dbHelper.delete(
      DatabaseHelper.tableFinancialRecords,
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
