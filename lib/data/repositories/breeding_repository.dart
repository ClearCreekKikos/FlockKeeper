// lib/data/repositories/breeding_repository.dart

import '../database/database_helper.dart';
import '../models/incubation_batch_model.dart';

class BreedingRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  // ─── Create ───────────────────────────────────────────────────────────────
  Future<int> insertBreedingEvent(IncubationBatch event) async {
    final now = DateTime.now();

    // Auto-calculate expected hatch date if not provided
    final expectedDate = event.expectedHatchDate ??
        IncubationBatch.calculateExpectedHatchDate(event.setDate);

    final newEvent = event.copyWith(
      expectedHatchDate: expectedDate,
      createdAt: now,
      updatedAt: now,
    );

    return await _dbHelper.insert(
      DatabaseHelper.tableBreedingEvents,
      newEvent.toMap(),
    );
  }

  // ─── Read ─────────────────────────────────────────────────────────────────
  Future<List<IncubationBatch>> getBreedingEventsForDoe(int flockId) async {
    final maps = await _dbHelper.query(
      DatabaseHelper.tableBreedingEvents,
      where: 'flock_id = ? OR doe_id = ?',
      whereArgs: [flockId, flockId],
      orderBy: 'set_date DESC, breeding_date DESC',
    );
    return maps.map((m) => IncubationBatch.fromMap(m)).toList();
  }

  Future<List<IncubationBatch>> getUpcomingKiddingEvents() async {
    final now = DateTime.now();

    final maps = await _dbHelper.query(
      DatabaseHelper.tableBreedingEvents,
      where: '''
        (expected_hatch_date IS NOT NULL OR expected_kid_date IS NOT NULL)
        AND actual_hatch_date IS NULL AND actual_kid_date IS NULL
        AND (outcome IS NULL OR outcome = 'ongoing')
        AND (expected_hatch_date >= ? OR expected_kid_date >= ?)
      ''',
      whereArgs: [now.toIso8601String(), now.toIso8601String()],
      orderBy: 'expected_hatch_date ASC, expected_kid_date ASC',
    );

    return maps.map((m) => IncubationBatch.fromMap(m)).toList();
  }

  Future<List<IncubationBatch>> getOverdueKiddingEvents() async {
    final now = DateTime.now();

    final maps = await _dbHelper.query(
      DatabaseHelper.tableBreedingEvents,
      where: '''
        (expected_hatch_date < ? OR expected_kid_date < ?)
        AND actual_hatch_date IS NULL AND actual_kid_date IS NULL
        AND (outcome IS NULL OR outcome = 'ongoing')
      ''',
      whereArgs: [now.toIso8601String(), now.toIso8601String()],
    );

    return maps.map((m) => IncubationBatch.fromMap(m)).toList();
  }

  // ─── Update ───────────────────────────────────────────────────────────────
  Future<int> updateBreedingEvent(IncubationBatch event) async {
    return await _dbHelper.update(
      DatabaseHelper.tableBreedingEvents,
      event.copyWith(updatedAt: DateTime.now()).toMap(),
      where: 'id = ?',
      whereArgs: [event.id],
    );
  }

  Future<int> confirmPregnancy(int id, {String? method, int? fertileCount}) async {
    return await _dbHelper.update(
      DatabaseHelper.tableBreedingEvents,
      {
        'confirmed_pregnant': 1,
        'fertile_count': fertileCount ?? 0,
        'confirmation_date': DateTime.now().toIso8601String(),
        'confirmation_method': method ?? 'Candling',
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ─── Delete ───────────────────────────────────────────────────────────────
  Future<int> deleteBreedingEvent(int id) async {
    return await _dbHelper.delete(
      DatabaseHelper.tableBreedingEvents,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ─── Extracted Queries ────────────────────────────────────────────────────
  Future<List<IncubationBatch>> getAllBreedingEvents() async {
    final maps = await _dbHelper.rawQuery('''
      SELECT e.*, 
             d.name AS flock_name, 
             b.name AS rooster_name
      FROM ${DatabaseHelper.tableBreedingEvents} e
      LEFT JOIN ${DatabaseHelper.tableAnimals} d ON (e.flock_id = d.id OR e.doe_id = d.id)
      LEFT JOIN ${DatabaseHelper.tableAnimals} b ON (e.rooster_id = b.id OR e.buck_id = b.id)
      ORDER BY e.set_date DESC, e.breeding_date DESC
    ''');
    return maps.map((m) => IncubationBatch.fromMap(m)).toList();
  }

  Future<IncubationBatch?> getBreedingEventById(int id) async {
    final maps = await _dbHelper.rawQuery('''
      SELECT e.*, 
             d.name AS flock_name, 
             b.name AS rooster_name
      FROM ${DatabaseHelper.tableBreedingEvents} e
      LEFT JOIN ${DatabaseHelper.tableAnimals} d ON (e.flock_id = d.id OR e.doe_id = d.id)
      LEFT JOIN ${DatabaseHelper.tableAnimals} b ON (e.rooster_id = b.id OR e.buck_id = b.id)
      WHERE e.id = ?
    ''', [id]);
    if (maps.isEmpty) return null;
    return IncubationBatch.fromMap(maps.first);
  }
}
