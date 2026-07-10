import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/database_helper.dart';
import '../models/egg_collection_model.dart';
import '../models/meat_record_model.dart';

final productionRepositoryProvider = Provider((ref) => ProductionRepository());

final eggCollectionHistoryProvider = FutureProvider.family<List<EggCollection>, int>((ref, animalId) {
  return ref.watch(productionRepositoryProvider).getEggCollectionsForAnimal(animalId);
});

final milkingHistoryProvider = eggCollectionHistoryProvider;

final meatHistoryProvider = FutureProvider.family<List<MeatRecord>, int>((ref, animalId) {
  return ref.watch(productionRepositoryProvider).getMeatRecordsForAnimal(animalId);
});

class ProductionRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  // ─── Egg Collection Records CRUD ──────────────────────────────────────────

  Future<int> insertEggCollection(EggCollection record) async {
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

  Future<List<EggCollection>> getEggCollectionsForAnimal(int animalId) async {
    final maps = await _dbHelper.query(
      DatabaseHelper.tableMilkingRecords,
      where: 'animal_id = ?',
      whereArgs: [animalId],
      orderBy: 'collection_date DESC',
    );
    return maps.map((map) => EggCollection.fromMap(map)).toList();
  }

  Future<int> updateEggCollection(EggCollection record) async {
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

  Future<int> deleteEggCollection(int id) async {
    return await _dbHelper.delete(
      DatabaseHelper.tableMilkingRecords,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Compatibility methods
  Future<int> insertMilkingRecord(EggCollection record) => insertEggCollection(record);
  Future<int> updateMilkingRecord(EggCollection record) => updateEggCollection(record);
  Future<int> deleteMilkingRecord(int id) => deleteEggCollection(id);

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
