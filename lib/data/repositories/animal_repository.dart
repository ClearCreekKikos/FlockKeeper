// lib/data/repositories/animal_repository.dart

import '../database/database_helper.dart';
import '../models/animal_model.dart';

class AnimalRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  // ─── Create ───────────────────────────────────────────────────────────────
  Future<int> insertAnimal(Animal animal) async {
    final now = DateTime.now();
    final animalWithTimestamps = animal.copyWith(
      createdAt: animal.createdAt,
      updatedAt: now,
    );

    final newId = await _dbHelper.insert(
      DatabaseHelper.tableAnimals,
      animalWithTimestamps.toMap(),
    );

    final insertedAnimal = animalWithTimestamps.copyWith(id: newId);
    await _syncFinancialRecords(insertedAnimal);

    return newId;
  }

  // ─── Read ─────────────────────────────────────────────────────────────────
  Future<List<Animal>> getAllAnimals({String? orderBy}) async {
    final maps = await _dbHelper.query(
      DatabaseHelper.tableAnimals,
      orderBy: orderBy ?? 'id ASC',
    );
    return maps.map((map) => Animal.fromMap(map)).toList();
  }

  Future<Animal?> getAnimalById(int id) async {
    final maps = await _dbHelper.query(
      DatabaseHelper.tableAnimals,
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return Animal.fromMap(maps.first);
  }

  Future<Animal?> getAnimalByNkrRegNumber(String regNumber) async {
    final maps = await _dbHelper.query(
      DatabaseHelper.tableAnimals,
      where: 'band_number = ? OR nkr_reg_number = ?',
      whereArgs: [regNumber, regNumber],
    );
    if (maps.isEmpty) return null;
    return Animal.fromMap(maps.first);
  }

  Future<Animal?> getAnimalByTattoo(String tattoo) async {
    final maps = await _dbHelper.query(
      DatabaseHelper.tableAnimals,
      where: 'tattoo = ?',
      whereArgs: [tattoo],
    );
    if (maps.isEmpty) return null;
    return Animal.fromMap(maps.first);
  }

  Future<Animal?> getAnimalByEarTag(String earTag) async {
    final maps = await _dbHelper.query(
      DatabaseHelper.tableAnimals,
      where: 'ear_tag = ?',
      whereArgs: [earTag],
    );
    if (maps.isEmpty) return null;
    return Animal.fromMap(maps.first);
  }

  Future<List<Animal>> getAnimalsByStatus(AnimalStatus status) async {
    final maps = await _dbHelper.query(
      DatabaseHelper.tableAnimals,
      where: 'status = ?',
      whereArgs: [status.name],
      orderBy: 'id ASC',
    );
    return maps.map((map) => Animal.fromMap(map)).toList();
  }

  Future<List<Animal>> getActiveAnimals() async {
    return getAnimalsByStatus(AnimalStatus.active);
  }

  Future<List<Animal>> getAnimalsBySex(Sex sex) async {
    final maps = await _dbHelper.query(
      DatabaseHelper.tableAnimals,
      where: 'sex = ? AND status = ?',
      whereArgs: [sex.name, AnimalStatus.active.name],
      orderBy: 'id ASC',
    );
    return maps.map((map) => Animal.fromMap(map)).toList();
  }

  Future<List<Animal>> getHerdSires() async {
    final maps = await _dbHelper.query(
      DatabaseHelper.tableAnimals,
      where: 'is_herd_sire = 1 AND status = ?',
      whereArgs: [AnimalStatus.active.name],
      orderBy: 'id ASC',
    );
    return maps.map((map) => Animal.fromMap(map)).toList();
  }

  Future<List<Animal>> searchAnimals(String query, {AnimalStatus? status}) async {
    final searchTerm = '%$query%';
    final targetStatus = status ?? AnimalStatus.active;
    final maps = await _dbHelper.query(
      DatabaseHelper.tableAnimals,
      where: '''
        (name LIKE ? OR 
         band_number LIKE ? OR 
         nkr_reg_number LIKE ? OR 
         ear_tag LIKE ? OR 
         tattoo LIKE ? OR 
         color LIKE ? OR 
         notes LIKE ? OR
         rfid_tag LIKE ?)
        AND status = ?
      ''',
      whereArgs: [
        searchTerm,
        searchTerm,
        searchTerm,
        searchTerm,
        searchTerm,
        searchTerm,
        searchTerm,
        searchTerm,
        targetStatus.name,
      ],
      orderBy: 'id ASC',
    );
    return maps.map((map) => Animal.fromMap(map)).toList();
  }

  Future<List<Animal>> getOffspring(int parentId) async {
    final maps = await _dbHelper.query(
      DatabaseHelper.tableAnimals,
      where: 'dam_id = ? OR sire_id = ?',
      whereArgs: [parentId, parentId],
      orderBy: 'dob ASC',
    );
    return maps.map((map) => Animal.fromMap(map)).toList();
  }

  // ─── Update ───────────────────────────────────────────────────────────────
  Future<int> updateAnimal(Animal animal) async {
    if (animal.id == null) {
      throw Exception('Cannot update animal without an ID');
    }

    final updatedAnimal = animal.copyWith(updatedAt: DateTime.now());

    final res = await _dbHelper.update(
      DatabaseHelper.tableAnimals,
      updatedAnimal.toMap(),
      where: 'id = ?',
      whereArgs: [animal.id],
    );

    await _syncFinancialRecords(updatedAnimal);

    return res;
  }

  Future<int> updateAnimalStatus(int id, AnimalStatus newStatus) async {
    final res = await _dbHelper.update(
      DatabaseHelper.tableAnimals,
      {
        'status': newStatus.name,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    final animal = await getAnimalById(id);
    if (animal != null) {
      await _syncFinancialRecords(animal);
    }
    return res;
  }

  // ─── Delete ───────────────────────────────────────────────────────────────
  Future<int> deleteAnimal(int id) async {
    return await _dbHelper.delete(
      DatabaseHelper.tableAnimals,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> softDeleteAnimal(int id) async {
    // Instead of deleting, mark as culled/transferred
    return await updateAnimalStatus(id, AnimalStatus.culled);
  }

  // ─── Utility ──────────────────────────────────────────────────────────────
  Future<int> getAnimalCount({AnimalStatus? status}) async {
    String? where;
    List<dynamic>? whereArgs;

    if (status != null) {
      where = 'status = ?';
      whereArgs = [status.name];
    }

    final maps = await _dbHelper.query(
      DatabaseHelper.tableAnimals,
      where: where,
      whereArgs: whereArgs,
      columns: ['COUNT(*) as count'],
    );

    if (maps.isEmpty) return 0;
    return maps.first['count'] as int? ?? 0;
  }

  Future<Map<Sex, int>> getAnimalCountBySex() async {
    final result = <Sex, int>{};

    for (final sex in Sex.values) {
      final count = await _dbHelper.rawQuery('''
        SELECT COUNT(*) as count 
        FROM ${DatabaseHelper.tableAnimals} 
        WHERE sex = ? AND status = ?
      ''', [sex.name, AnimalStatus.active.name]);

      result[sex] = count.first['count'] as int? ?? 0;
    }

    return result;
  }

  Future<bool> nkrRegNumberExists(String regNumber, {int? excludeId}) async {
    String where = '(band_number = ? OR nkr_reg_number = ?)';
    List<dynamic> whereArgs = [regNumber, regNumber];

    if (excludeId != null) {
      where += ' AND id != ?';
      whereArgs.add(excludeId);
    }

    final maps = await _dbHelper.query(
      DatabaseHelper.tableAnimals,
      where: where,
      whereArgs: whereArgs,
      columns: ['id'],
    );

    return maps.isNotEmpty;
  }

  Future<bool> tattooExists(String tattoo, {int? excludeId}) async {
    String where = 'tattoo = ?';
    List<dynamic> whereArgs = [tattoo];

    if (excludeId != null) {
      where += ' AND id != ?';
      whereArgs.add(excludeId);
    }

    final maps = await _dbHelper.query(
      DatabaseHelper.tableAnimals,
      where: where,
      whereArgs: whereArgs,
      columns: ['id'],
    );

    return maps.isNotEmpty;
  }

  Future<bool> earTagExists(String earTag, {int? excludeId}) async {
    String where = 'ear_tag = ?';
    List<dynamic> whereArgs = [earTag];

    if (excludeId != null) {
      where += ' AND id != ?';
      whereArgs.add(excludeId);
    }

    final maps = await _dbHelper.query(
      DatabaseHelper.tableAnimals,
      where: where,
      whereArgs: whereArgs,
      columns: ['id'],
    );

    return maps.isNotEmpty;
  }

  Future<Animal?> getAnimalByNameCaseInsensitive(String name) async {
    final maps = await _dbHelper.query(
      DatabaseHelper.tableAnimals,
      where: 'name = ? COLLATE NOCASE',
      whereArgs: [name],
    );
    if (maps.isEmpty) return null;
    return Animal.fromMap(maps.first);
  }

  Future<Animal?> getAnimalByNkrRegNumberCaseInsensitive(String regNumber) async {
    final maps = await _dbHelper.query(
      DatabaseHelper.tableAnimals,
      where: 'band_number = ? COLLATE NOCASE OR nkr_reg_number = ? COLLATE NOCASE',
      whereArgs: [regNumber, regNumber],
    );
    if (maps.isEmpty) return null;
    return Animal.fromMap(maps.first);
  }

  Future<Animal?> getAnimalByRfidTag(String rfidTag) async {
    final maps = await _dbHelper.query(
      DatabaseHelper.tableAnimals,
      where: 'rfid_tag = ? COLLATE NOCASE',
      whereArgs: [rfidTag.trim()],
    );
    if (maps.isEmpty) return null;
    return Animal.fromMap(maps.first);
  }

  Future<bool> rfidTagExists(String rfidTag, {int? excludeId}) async {
    String where = 'rfid_tag = ?';
    List<dynamic> whereArgs = [rfidTag];
    if (excludeId != null) {
      where += ' AND id != ?';
      whereArgs.add(excludeId);
    }
    final maps = await _dbHelper.query(
      DatabaseHelper.tableAnimals,
      where: where,
      whereArgs: whereArgs,
      columns: ['id'],
    );
    return maps.isNotEmpty;
  }

  Future<bool> scrapieTagExists(String scrapieTag, {int? excludeId}) async {
    String where = 'scrapie_tag = ?';
    List<dynamic> whereArgs = [scrapieTag];
    if (excludeId != null) {
      where += ' AND id != ?';
      whereArgs.add(excludeId);
    }
    final maps = await _dbHelper.query(
      DatabaseHelper.tableAnimals,
      where: where,
      whereArgs: whereArgs,
      columns: ['id'],
    );
    return maps.isNotEmpty;
  }

  Future<bool> vglIdExists(String vglId, {int? excludeId}) async {
    String where = 'vgl_id = ?';
    List<dynamic> whereArgs = [vglId];
    if (excludeId != null) {
      where += ' AND id != ?';
      whereArgs.add(excludeId);
    }
    final maps = await _dbHelper.query(
      DatabaseHelper.tableAnimals,
      where: where,
      whereArgs: whereArgs,
      columns: ['id'],
    );
    return maps.isNotEmpty;
  }

  Future<Animal?> findDuplicateAnimal(Animal animal, {int? excludeId}) async {
    // 1. Check NKR Registration Number (Band Number)
    if (animal.bandNumber != null && animal.bandNumber!.trim().isNotEmpty) {
      final reg = animal.bandNumber!.trim();
      String query = '(band_number = ? COLLATE NOCASE OR nkr_reg_number = ? COLLATE NOCASE)';
      List<dynamic> args = [reg, reg];
      if (excludeId != null) {
        query += ' AND id != ?';
        args.add(excludeId);
      }
      final maps = await _dbHelper.query(DatabaseHelper.tableAnimals, where: query, whereArgs: args);
      if (maps.isNotEmpty) return Animal.fromMap(maps.first);
    }

    // 2. Check Ear Tag
    if (animal.earTag != null && animal.earTag!.trim().isNotEmpty) {
      final earTag = animal.earTag!.trim();
      String query = 'ear_tag = ? COLLATE NOCASE';
      List<dynamic> args = [earTag];
      if (excludeId != null) {
        query += ' AND id != ?';
        args.add(excludeId);
      }
      final maps = await _dbHelper.query(DatabaseHelper.tableAnimals, where: query, whereArgs: args);
      if (maps.isNotEmpty) return Animal.fromMap(maps.first);
    }

    // 3. Check Tattoo
    if (animal.tattoo != null && animal.tattoo!.trim().isNotEmpty) {
      final tattoo = animal.tattoo!.trim();
      String query = 'tattoo = ? COLLATE NOCASE';
      List<dynamic> args = [tattoo];
      if (excludeId != null) {
        query += ' AND id != ?';
        args.add(excludeId);
      }
      final maps = await _dbHelper.query(DatabaseHelper.tableAnimals, where: query, whereArgs: args);
      if (maps.isNotEmpty) return Animal.fromMap(maps.first);
    }

    // 4. Check RFID Tag / EID
    if (animal.rfidTag != null && animal.rfidTag!.trim().isNotEmpty) {
      final rfid = animal.rfidTag!.trim();
      String query = 'rfid_tag = ? COLLATE NOCASE';
      List<dynamic> args = [rfid];
      if (excludeId != null) {
        query += ' AND id != ?';
        args.add(excludeId);
      }
      final maps = await _dbHelper.query(DatabaseHelper.tableAnimals, where: query, whereArgs: args);
      if (maps.isNotEmpty) return Animal.fromMap(maps.first);
    }


    // 6. Check UC Davis VGL ID
    if (animal.vglId != null && animal.vglId!.trim().isNotEmpty) {
      final vgl = animal.vglId!.trim();
      String query = 'vgl_id = ? COLLATE NOCASE';
      List<dynamic> args = [vgl];
      if (excludeId != null) {
        query += ' AND id != ?';
        args.add(excludeId);
      }
      final maps = await _dbHelper.query(DatabaseHelper.tableAnimals, where: query, whereArgs: args);
      if (maps.isNotEmpty) return Animal.fromMap(maps.first);
    }

    // 7. Check Name + DOB / Name duplicate
    if (animal.name.isNotEmpty) {
      String query = 'name = ? COLLATE NOCASE';
      List<dynamic> args = [animal.name.trim()];
      if (excludeId != null) {
        query += ' AND id != ?';
        args.add(excludeId);
      }
      final maps = await _dbHelper.query(DatabaseHelper.tableAnimals, where: query, whereArgs: args);
      for (final map in maps) {
        final existing = Animal.fromMap(map);
        if (animal.dob != null && existing.dob != null) {
          final isSameDay = animal.dob!.year == existing.dob!.year &&
              animal.dob!.month == existing.dob!.month &&
              animal.dob!.day == existing.dob!.day;
          if (!isSameDay) {
            continue;
          }
        }
        return existing;
      }
    }

    return null;
  }

  Future<void> deduplicateDatabase() async {
    // Startup auto-deduplication disabled to prevent data loss.
  }

  Future<void> _syncFinancialRecords(Animal animal) async {
    if (animal.id == null) return;

    // 1. Sync Purchase Record
    if (animal.purchasePrice != null && animal.purchasePrice! > 0) {
      final existingPurchases = await _dbHelper.query(
        DatabaseHelper.tableFinancialRecords,
        where: 'animal_id = ? AND category = ?',
        whereArgs: [animal.id!, 'purchase'],
      );

      final recordDate = animal.purchaseDate ?? animal.dob ?? DateTime.now();
      final mapData = {
        'animal_id': animal.id!,
        'record_date': recordDate.toIso8601String(),
        'category': 'purchase',
        'type': 'expense',
        'amount': animal.purchasePrice!,
        'description': 'Purchase of ${animal.name}',
        'vendor_buyer': animal.status == AnimalStatus.sold ? null : animal.soldTo,
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (existingPurchases.isNotEmpty) {
        final existingId = existingPurchases.first['id'];
        await _dbHelper.update(
          DatabaseHelper.tableFinancialRecords,
          mapData,
          where: 'id = ?',
          whereArgs: [existingId],
        );
      } else {
        mapData['created_at'] = DateTime.now().toIso8601String();
        await _dbHelper.insert(
          DatabaseHelper.tableFinancialRecords,
          mapData,
        );
      }
    } else {
      await _dbHelper.delete(
        DatabaseHelper.tableFinancialRecords,
        where: 'animal_id = ? AND category = ?',
        whereArgs: [animal.id!, 'purchase'],
      );
    }

    // 2. Sync Sale Record
    if (animal.status == AnimalStatus.sold && animal.soldPrice != null && animal.soldPrice! > 0) {
      final existingSales = await _dbHelper.query(
        DatabaseHelper.tableFinancialRecords,
        where: 'animal_id = ? AND category = ?',
        whereArgs: [animal.id!, 'sale'],
      );

      final recordDate = animal.soldDate ?? DateTime.now();
      final mapData = {
        'animal_id': animal.id!,
        'record_date': recordDate.toIso8601String(),
        'category': 'sale',
        'type': 'income',
        'amount': animal.soldPrice!,
        'description': 'Sale of ${animal.name}',
        'vendor_buyer': animal.soldTo,
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (existingSales.isNotEmpty) {
        final existingId = existingSales.first['id'];
        await _dbHelper.update(
          DatabaseHelper.tableFinancialRecords,
          mapData,
          where: 'id = ?',
          whereArgs: [existingId],
        );
      } else {
        mapData['created_at'] = DateTime.now().toIso8601String();
        await _dbHelper.insert(
          DatabaseHelper.tableFinancialRecords,
          mapData,
        );
      }
    } else {
      await _dbHelper.delete(
        DatabaseHelper.tableFinancialRecords,
        where: 'animal_id = ? AND category = ?',
        whereArgs: [animal.id!, 'sale'],
      );
    }
  }

}
