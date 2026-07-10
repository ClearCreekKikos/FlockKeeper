import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/database_helper.dart';
import '../models/milking_record_model.dart';
import '../models/meat_record_model.dart';

final productionRepositoryProvider = Provider((ref) => ProductionRepository());

final milkingHistoryProvider = FutureProvider.family<List<MilkingRecord>, int>((ref, animalId) {
  return ref.watch(productionRepositoryProvider).getMilkingRecordsForAnimal(animalId);
});

final meatHistoryProvider = FutureProvider.family<List<MeatRecord>, int>((ref, animalId) {
  return ref.watch(productionRepositoryProvider).getMeatRecordsForAnimal(animalId);
});

class ProductionRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  // ─── Milking Records CRUD ─────────────────────────────────────────────────

  Future<int> insertMilkingRecord(MilkingRecord record) async {
    final now = DateTime.now();
    final withTime = record.copyWith(
      createdAt: now,
      updatedAt: now,
    );
    return await _dbHelper.insert(
      DatabaseHelper.tableMilkingRecords,
      withTime.toMap(),
    );
  }

  Future<List<MilkingRecord>> getMilkingRecordsForAnimal(int animalId) async {
    final maps = await _dbHelper.query(
      DatabaseHelper.tableMilkingRecords,
      where: 'animal_id = ?',
      whereArgs: [animalId],
      orderBy: 'milking_date DESC',
    );
    return maps.map((map) => MilkingRecord.fromMap(map)).toList();
  }

  Future<int> updateMilkingRecord(MilkingRecord record) async {
    final now = DateTime.now();
    final withTime = record.copyWith(
      updatedAt: now,
    );
    return await _dbHelper.update(
      DatabaseHelper.tableMilkingRecords,
      withTime.toMap(),
      where: 'id = ?',
      whereArgs: [record.id],
    );
  }

  Future<int> deleteMilkingRecord(int id) async {
    return await _dbHelper.delete(
      DatabaseHelper.tableMilkingRecords,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ─── Meat Records CRUD ────────────────────────────────────────────────────

  Future<int> insertMeatRecord(MeatRecord record) async {
    final now = DateTime.now();
    final withTime = record.copyWith(
      createdAt: now,
      updatedAt: now,
    );
    return await _dbHelper.insert(
      DatabaseHelper.tableMeatRecords,
      withTime.toMap(),
    );
  }

  Future<List<MeatRecord>> getMeatRecordsForAnimal(int animalId) async {
    final maps = await _dbHelper.query(
      DatabaseHelper.tableMeatRecords,
      where: 'animal_id = ?',
      whereArgs: [animalId],
      orderBy: 'record_date DESC',
    );
    return maps.map((map) => MeatRecord.fromMap(map)).toList();
  }

  Future<int> updateMeatRecord(MeatRecord record) async {
    final now = DateTime.now();
    final withTime = record.copyWith(
      updatedAt: now,
    );
    return await _dbHelper.update(
      DatabaseHelper.tableMeatRecords,
      withTime.toMap(),
      where: 'id = ?',
      whereArgs: [record.id],
    );
  }

  Future<int> deleteMeatRecord(int id) async {
    return await _dbHelper.delete(
      DatabaseHelper.tableMeatRecords,
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
