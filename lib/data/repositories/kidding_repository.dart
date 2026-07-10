// lib/data/repositories/kidding_repository.dart

import '../database/database_helper.dart';
import '../models/hatch_record_model.dart';
import '../models/animal_model.dart';
import '../models/incubation_batch_model.dart';

class KiddingRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  Future<int> insertKiddingRecord(HatchRecord record) async {
    return await _dbHelper.insert(
      DatabaseHelper.tableKiddingRecords,
      record.toMap(),
    );
  }

  Future<List<HatchRecord>> getKiddingRecordsForDoe(int flockId) async {
    final maps = await _dbHelper.query(
      DatabaseHelper.tableKiddingRecords,
      where: 'flock_id = ? OR doe_id = ?',
      whereArgs: [flockId, flockId],
      orderBy: 'hatch_date DESC, kidding_date DESC',
    );
    return maps.map((m) => HatchRecord.fromMap(m)).toList();
  }

  Future<List<HatchRecord>> getKidsForBreedingEvent(int batchId) async {
    final maps = await _dbHelper.query(
      DatabaseHelper.tableKiddingRecords,
      where: 'batch_id = ? OR breeding_event_id = ?',
      whereArgs: [batchId, batchId],
    );
    return maps.map((m) => HatchRecord.fromMap(m)).toList();
  }

  Future<int> deleteKiddingRecord(int id) async {
    return await _dbHelper.delete(
      DatabaseHelper.tableKiddingRecords,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<HatchRecord>> getAllKiddingRecords() async {
    final maps = await _dbHelper.query(
      DatabaseHelper.tableKiddingRecords,
      orderBy: 'hatch_date DESC, kidding_date DESC',
    );
    return maps.map((m) => HatchRecord.fromMap(m)).toList();
  }

  Future<int> updateKiddingRecord(HatchRecord record) async {
    if (record.id == null) {
      throw Exception('Cannot update hatch record without an ID');
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

    // Resolve missing dam_ids by dam_name (flockName/damName)
    final missingDamAnimals = await db.query(
      'animals',
      where: 'dam_id IS NULL AND dam_name IS NOT NULL AND dam_name != \'\'',
    );
    for (final map in missingDamAnimals) {
      final id = map['id'] as int;
      final damName = map['dam_name'] as String;
      final matches = await db.query(
        'animals',
        where: 'name = ? COLLATE NOCASE',
        whereArgs: [damName.trim()],
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
        where: 'name = ? COLLATE NOCASE AND (sex = ? OR sex = ?)',
        whereArgs: [sireName.trim(), 'rooster', 'buck'],
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

    // 2. Fetch all active/owned dams/flocks to filter the kids/chicks
    final damMaps = await db.query(
      'animals',
      where: 'status = ?',
      whereArgs: ['active'],
    );
    final activeDamIds = damMaps.map((m) => m['id'] as int).toSet();

    // Filter chicks to only those whose source flock/dam is owned (active)
    final kids = animalMaps
        .map((m) => Animal.fromMap(m))
        .where((a) => activeDamIds.contains(a.damId))
        .toList();

    if (kids.isEmpty) return;

    // 3. Group chicks by (damId, sireId, dob date only)
    final groups = <String, List<Animal>>{};
    for (final kid in kids) {
      if (kid.dob == null) continue;
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

      // Stable sorting by ID so hatchOrder is consistent
      kidsInGroup.sort((a, b) => (a.id ?? 0).compareTo(b.id ?? 0));

      final litterSize = kidsInGroup.length;

      // Query if there is a pending incubation batch for this flock
      int? breedingEventId;
      final breedingMaps = await db.query(
        'incubation_batches',
        where: '(flock_id = ? OR doe_id = ?) AND actual_hatch_date IS NULL AND actual_kid_date IS NULL',
        whereArgs: [damId, damId],
      );
      final pendingEvents = breedingMaps.map((m) => IncubationBatch.fromMap(m)).toList();
      final pendingEvent = pendingEvents.isNotEmpty ? pendingEvents.first : null;

      if (pendingEvent != null) {
        breedingEventId = pendingEvent.id;
        final updatedEvent = pendingEvent.copyWith(
          actualHatchDate: dob,
          outcome: IncubationOutcome.hatched,
          updatedAt: DateTime.now(),
        );
        await db.update(
          'incubation_batches',
          updatedEvent.toMap(),
          where: 'id = ?',
          whereArgs: [pendingEvent.id],
        );
      }

      // Check existing hatch records for this group to reuse batchId if already hatched
      final existingKiddingMaps = await db.query(
        'hatch_records',
        where: 'flock_id = ? OR doe_id = ?',
        whereArgs: [damId, damId],
      );
      final existingRecords = existingKiddingMaps
          .map((m) => HatchRecord.fromMap(m))
          .where((k) => _isSameDayStr(k.hatchDate, dob))
          .toList();
      if (existingRecords.isNotEmpty && breedingEventId == null) {
        breedingEventId = existingRecords.first.batchId;
      }

      for (int i = 0; i < kidsInGroup.length; i++) {
        final kid = kidsInGroup[i];
        final birthOrder = i + 1;

        // Check if hatch record already exists for this chickId
        final kidKiddingMaps = await db.query(
          'hatch_records',
          where: 'chick_id = ? OR kid_id = ?',
          whereArgs: [kid.id, kid.id],
        );

        if (kidKiddingMaps.isNotEmpty) {
          // Update existing hatch record
          final existingRecord = HatchRecord.fromMap(kidKiddingMaps.first);
          final updatedRecord = existingRecord.copyWith(
            chicksHatched: litterSize,
            hatchOrder: birthOrder,
            roosterId: sireId,
          );
          await db.update(
            'hatch_records',
            updatedRecord.toMap(),
            where: 'id = ?',
            whereArgs: [existingRecord.id],
          );
        } else {
          // Insert new hatch record
          final hatchRecord = HatchRecord(
            batchId: breedingEventId,
            flockId: damId,
            roosterId: sireId,
            chickId: kid.id,
            chickName: kid.name,
            hatchDate: dob,
            hatchOrder: birthOrder,
            chicksHatched: litterSize,
            sex: kid.sex == Sex.hen ? KidSex.doe : (kid.sex == Sex.rooster ? KidSex.buck : KidSex.unknown),
            survivalStatus: HatchSurvival.alive,
            createdAt: DateTime.now(),
          );
          await db.insert('hatch_records', hatchRecord.toMap());
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
}
