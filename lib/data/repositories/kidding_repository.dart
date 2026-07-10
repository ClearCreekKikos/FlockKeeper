// lib/data/repositories/kidding_repository.dart

import '../database/database_helper.dart';
import '../models/kidding_record_model.dart';
import '../models/animal_model.dart';
import '../models/breeding_event_model.dart';

class KiddingRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  Future<int> insertKiddingRecord(KiddingRecord record) async {
    return await _dbHelper.insert(
      DatabaseHelper.tableKiddingRecords,
      record.toMap(),
    );
  }

  Future<List<KiddingRecord>> getKiddingRecordsForDoe(int doeId) async {
    final maps = await _dbHelper.query(
      DatabaseHelper.tableKiddingRecords,
      where: 'doe_id = ?',
      whereArgs: [doeId],
      orderBy: 'kidding_date DESC',
    );
    return maps.map((m) => KiddingRecord.fromMap(m)).toList();
  }

  Future<List<KiddingRecord>> getKidsForBreedingEvent(int breedingEventId) async {
    final maps = await _dbHelper.query(
      DatabaseHelper.tableKiddingRecords,
      where: 'breeding_event_id = ?',
      whereArgs: [breedingEventId],
    );
    return maps.map((m) => KiddingRecord.fromMap(m)).toList();
  }

  Future<int> deleteKiddingRecord(int id) async {
    return await _dbHelper.delete(
      DatabaseHelper.tableKiddingRecords,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<KiddingRecord>> getAllKiddingRecords() async {
    final maps = await _dbHelper.query(
      DatabaseHelper.tableKiddingRecords,
      orderBy: 'kidding_date DESC',
    );
    return maps.map((m) => KiddingRecord.fromMap(m)).toList();
  }

  Future<int> updateKiddingRecord(KiddingRecord record) async {
    if (record.id == null) {
      throw Exception('Cannot update kidding record without an ID');
    }
    return await _dbHelper.update(
      DatabaseHelper.tableKiddingRecords,
      record.toMap(),
      where: 'id = ?',
      whereArgs: [record.id],
    );
  }

  Future<void> scanAndCreateKiddingRecords() async {
    final db = await _dbHelper.database;

    // Resolve missing dam_ids by dam_name
    final missingDamAnimals = await db.query(
      'animals',
      where: 'dam_id IS NULL AND dam_name IS NOT NULL AND dam_name != \'\'',
    );
    for (final map in missingDamAnimals) {
      final id = map['id'] as int;
      final damName = map['dam_name'] as String;
      final matches = await db.query(
        'animals',
        where: 'name = ? COLLATE NOCASE AND sex = ?',
        whereArgs: [damName.trim(), 'doe'],
      );
      if (matches.isNotEmpty) {
        final damId = matches.first['id'] as int;
        await db.update(
          'animals',
          {'dam_id': damId, 'updated_at': DateTime.now().toIso8601String()},
          where: 'id = ?',
          whereArgs: [id],
        );
      }
    }

    // Resolve missing sire_ids by sire_name
    final missingSireAnimals = await db.query(
      'animals',
      where: 'sire_id IS NULL AND sire_name IS NOT NULL AND sire_name != \'\'',
    );
    for (final map in missingSireAnimals) {
      final id = map['id'] as int;
      final sireName = map['sire_name'] as String;
      final matches = await db.query(
        'animals',
        where: 'name = ? COLLATE NOCASE AND sex = ?',
        whereArgs: [sireName.trim(), 'buck'],
      );
      if (matches.isNotEmpty) {
        final sireId = matches.first['id'] as int;
        await db.update(
          'animals',
          {'sire_id': sireId, 'updated_at': DateTime.now().toIso8601String()},
          where: 'id = ?',
          whereArgs: [id],
        );
      }
    }

    // 1. Fetch all animals that have a dam_id and a dob
    final animalMaps = await db.query(
      'animals',
      where: 'dam_id IS NOT NULL AND dob IS NOT NULL',
    );
    if (animalMaps.isEmpty) return;

    // 2. Fetch all active/owned dams to filter the kids
    final damMaps = await db.query(
      'animals',
      where: 'sex = ? AND status = ?',
      whereArgs: ['doe', 'active'],
    );
    final activeDamIds = damMaps.map((m) => m['id'] as int).toSet();

    // Filter kids to only those whose dam is owned (active)
    final kids = animalMaps
        .map((m) => Animal.fromMap(m))
        .where((a) => activeDamIds.contains(a.damId))
        .toList();

    if (kids.isEmpty) return;

    // 3. Group kids by (damId, sireId, dob date only)
    final groups = <String, List<Animal>>{};
    for (final kid in kids) {
      final dobStr = _formatDateOnly(kid.dob!);
      final sireKey = kid.sireId != null ? kid.sireId.toString() : 'null';
      final key = '${kid.damId}_${sireKey}_$dobStr';
      groups.putIfAbsent(key, () => []).add(kid);
    }

    // 4. Process each group
    for (final entry in groups.entries) {
      final parts = entry.key.split('_');
      final damId = int.parse(parts[0]);
      final sireIdStr = parts[1];
      final sireId = sireIdStr == 'null' ? null : int.parse(sireIdStr);
      final dobStr = parts[2];
      final dob = DateTime.parse(dobStr);
      final kidsInGroup = entry.value;

      // Stable sorting by ID so birthOrder is consistent
      kidsInGroup.sort((a, b) => (a.id ?? 0).compareTo(b.id ?? 0));

      final litterSize = kidsInGroup.length;

      // Query if there is a pending breeding event for this Dam
      int? breedingEventId;
      final breedingMaps = await db.query(
        'breeding_events',
        where: 'doe_id = ? AND actual_kid_date IS NULL',
        whereArgs: [damId],
      );
      final pendingEvents = breedingMaps.map((m) => BreedingEvent.fromMap(m)).toList();
      final pendingEvent = pendingEvents.isNotEmpty ? pendingEvents.first : null;

      if (pendingEvent != null) {
        breedingEventId = pendingEvent.id;
        final updatedEvent = pendingEvent.copyWith(
          actualKidDate: dob,
          outcome: BreedingOutcome.kidded,
          updatedAt: DateTime.now(),
        );
        await db.update(
          'breeding_events',
          updatedEvent.toMap(),
          where: 'id = ?',
          whereArgs: [pendingEvent.id],
        );
      }

      // Check existing kidding records for this group to reuse breedingEventId if already kidded
      final existingKiddingMaps = await db.query(
        'kidding_records',
        where: 'doe_id = ?',
        whereArgs: [damId],
      );
      final existingRecords = existingKiddingMaps
          .map((m) => KiddingRecord.fromMap(m))
          .where((k) => _isSameDayStr(k.kiddingDate, dob))
          .toList();
      if (existingRecords.isNotEmpty && breedingEventId == null) {
        breedingEventId = existingRecords.first.breedingEventId;
      }

      for (int i = 0; i < kidsInGroup.length; i++) {
        final kid = kidsInGroup[i];
        final birthOrder = i + 1;

        // Check if kidding record already exists for this kid_id
        final kidKiddingMaps = await db.query(
          'kidding_records',
          where: 'kid_id = ?',
          whereArgs: [kid.id],
        );

        if (kidKiddingMaps.isNotEmpty) {
          // Update existing kidding record
          final existingRecord = KiddingRecord.fromMap(kidKiddingMaps.first);
          final updatedRecord = existingRecord.copyWith(
            litterSize: litterSize,
            birthOrder: birthOrder,
            birthType: _getBirthType(litterSize),
            buckId: sireId,
          );
          await db.update(
            'kidding_records',
            updatedRecord.toMap(),
            where: 'id = ?',
            whereArgs: [existingRecord.id],
          );
        } else {
          // Insert new kidding record
          final kiddingRecord = KiddingRecord(
            breedingEventId: breedingEventId,
            doeId: damId,
            buckId: sireId,
            kidId: kid.id,
            kidName: kid.name,
            kiddingDate: dob,
            birthOrder: birthOrder,
            litterSize: litterSize,
            sex: kid.sex == Sex.doe ? KidSex.doe : (kid.sex == Sex.buck ? KidSex.buck : KidSex.unknown),
            birthType: _getBirthType(litterSize),
            survivalStatus: SurvivalStatus.alive,
            createdAt: DateTime.now(),
          );
          await db.insert('kidding_records', kiddingRecord.toMap());
        }
      }
    }
  }

  String _formatDateOnly(DateTime dt) {
    return '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  bool _isSameDayStr(DateTime dt1, DateTime dt2) {
    return dt1.year == dt2.year && dt1.month == dt2.month && dt1.day == dt2.day;
  }

  BirthType _getBirthType(int size) {
    if (size == 1) return BirthType.single;
    if (size == 2) return BirthType.twin;
    if (size == 3) return BirthType.triplet;
    if (size == 4) return BirthType.quad;
    return BirthType.other;
  }
}
