// lib/data/repositories/breeding_repository.dart

import '../database/database_helper.dart';
import '../models/breeding_event_model.dart';

class BreedingRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  // ─── Create ───────────────────────────────────────────────────────────────
  Future<int> insertBreedingEvent(BreedingEvent event) async {
    final now = DateTime.now();

    // Auto-calculate expected kidding date if not provided
    final expectedDate = event.expectedKidDate ??
        BreedingEvent.calculateExpectedKidDate(event.breedingDate);

    final newEvent = event.copyWith(
      expectedKidDate: expectedDate,
      createdAt: now,
      updatedAt: now,
    );

    return await _dbHelper.insert(
      DatabaseHelper.tableBreedingEvents,
      newEvent.toMap(),
    );
  }

  // ─── Read ─────────────────────────────────────────────────────────────────
  Future<List<BreedingEvent>> getBreedingEventsForDoe(int doeId) async {
    final maps = await _dbHelper.query(
      DatabaseHelper.tableBreedingEvents,
      where: 'doe_id = ?',
      whereArgs: [doeId],
      orderBy: 'breeding_date DESC',
    );
    return maps.map((m) => BreedingEvent.fromMap(m)).toList();
  }

  Future<List<BreedingEvent>> getUpcomingKiddingEvents() async {
    final now = DateTime.now();

    final maps = await _dbHelper.query(
      DatabaseHelper.tableBreedingEvents,
      where: '''
        expected_kid_date IS NOT NULL
        AND actual_kid_date IS NULL
        AND confirmed_pregnant = 1
        AND expected_kid_date >= ?
      ''',
      whereArgs: [now.toIso8601String()],
      orderBy: 'expected_kid_date ASC',
    );

    return maps.map((m) => BreedingEvent.fromMap(m)).toList();
  }

  Future<List<BreedingEvent>> getOverdueKiddingEvents() async {
    final now = DateTime.now();

    final maps = await _dbHelper.query(
      DatabaseHelper.tableBreedingEvents,
      where: '''
        expected_kid_date < ?
        AND actual_kid_date IS NULL
        AND confirmed_pregnant = 1
      ''',
      whereArgs: [now.toIso8601String()],
    );

    return maps.map((m) => BreedingEvent.fromMap(m)).toList();
  }

  // ─── Update ───────────────────────────────────────────────────────────────
  Future<int> updateBreedingEvent(BreedingEvent event) async {
    return await _dbHelper.update(
      DatabaseHelper.tableBreedingEvents,
      event.copyWith(updatedAt: DateTime.now()).toMap(),
      where: 'id = ?',
      whereArgs: [event.id],
    );
  }

  Future<int> confirmPregnancy(int id, {String? method}) async {
    return await _dbHelper.update(
      DatabaseHelper.tableBreedingEvents,
      {
        'confirmed_pregnant': 1,
        'confirmation_date': DateTime.now().toIso8601String(),
        'confirmation_method': method,
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
  Future<List<BreedingEvent>> getAllBreedingEvents() async {
    final maps = await _dbHelper.rawQuery('''
      SELECT e.*, 
             d.name AS doe_name, 
             b.name AS buck_name
      FROM ${DatabaseHelper.tableBreedingEvents} e
      LEFT JOIN ${DatabaseHelper.tableAnimals} d ON e.doe_id = d.id
      LEFT JOIN ${DatabaseHelper.tableAnimals} b ON e.buck_id = b.id
      ORDER BY e.breeding_date DESC
    ''');
    return maps.map((m) => BreedingEvent.fromMap(m)).toList();
  }

  Future<BreedingEvent?> getBreedingEventById(int id) async {
    final maps = await _dbHelper.rawQuery('''
      SELECT e.*, 
             d.name AS doe_name, 
             b.name AS buck_name
      FROM ${DatabaseHelper.tableBreedingEvents} e
      LEFT JOIN ${DatabaseHelper.tableAnimals} d ON e.doe_id = d.id
      LEFT JOIN ${DatabaseHelper.tableAnimals} b ON e.buck_id = b.id
      WHERE e.id = ?
    ''', [id]);
    if (maps.isEmpty) return null;
    return BreedingEvent.fromMap(maps.first);
  }
}
