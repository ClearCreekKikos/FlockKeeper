import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:flockkeeper/data/database/database_helper.dart';
import 'package:flockkeeper/data/models/animal_model.dart';
import 'package:flockkeeper/data/models/kidding_record_model.dart';
import 'package:flockkeeper/data/repositories/animal_repository.dart';
import 'package:flockkeeper/data/repositories/kidding_repository.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('Duplicate Animal and Auto Kidding Record Tests', () {
    late DatabaseHelper dbHelper;
    late AnimalRepository animalRepo;
    late KiddingRepository kiddingRepo;

    setUp(() async {
      dbHelper = DatabaseHelper();
      animalRepo = AnimalRepository();
      kiddingRepo = KiddingRepository();

      final db = await dbHelper.database;
      await db.delete(DatabaseHelper.tableKiddingRecords);
      await db.delete(DatabaseHelper.tableBreedingEvents);
      await db.delete(DatabaseHelper.tableAnimals);
    });

    test('findDuplicateAnimal returns match on unique fields and respects excludeId', () async {
      final now = DateTime.now();
      
      // 1. Insert initial animal
      final baseAnimal = Animal(
        name: 'Bella',
        earTag: 'ET-100',
        nkrRegNumber: 'NKR-123',
        tattoo: 'TATT-999',
        rfidTag: 'RFID-111',
        scrapieTag: 'SCR-222',
        vglId: 'VGL-333',
        dob: DateTime(2026, 1, 1),
        sex: Sex.doe,
        createdAt: now,
        updatedAt: now,
      );
      final id = await animalRepo.insertAnimal(baseAnimal);

      // Check ear_tag duplicate
      var dup = await animalRepo.findDuplicateAnimal(Animal(
        name: 'Other',
        earTag: 'et-100', // case-insensitive check
        sex: Sex.doe,
        createdAt: now,
        updatedAt: now,
      ));
      expect(dup, isNotNull);
      expect(dup!.id, id);

      // Check excludeId works
      dup = await animalRepo.findDuplicateAnimal(Animal(
        name: 'Other',
        earTag: 'ET-100',
        sex: Sex.doe,
        createdAt: now,
        updatedAt: now,
      ), excludeId: id);
      expect(dup, isNull);

      // Check nkrRegNumber duplicate
      dup = await animalRepo.findDuplicateAnimal(Animal(
        name: 'Other',
        nkrRegNumber: 'nkr-123',
        sex: Sex.doe,
        createdAt: now,
        updatedAt: now,
      ));
      expect(dup, isNotNull);

      // Check name + DOB duplicate
      dup = await animalRepo.findDuplicateAnimal(Animal(
        name: 'bella',
        dob: DateTime(2026, 1, 1, 10, 30), // same day, different time
        sex: Sex.doe,
        createdAt: now,
        updatedAt: now,
      ));
      expect(dup, isNotNull);

      // Check no match on name if different DOB
      dup = await animalRepo.findDuplicateAnimal(Animal(
        name: 'bella',
        dob: DateTime(2026, 1, 2),
        sex: Sex.doe,
        createdAt: now,
        updatedAt: now,
      ));
      expect(dup, isNull);

      // Check duplicate matches on name when search DOB is null (fallback to duplicate name check)
      dup = await animalRepo.findDuplicateAnimal(Animal(
        name: 'bella',
        sex: Sex.doe,
        createdAt: now,
        updatedAt: now,
      ));
      expect(dup, isNotNull);
      expect(dup!.id, id);

      // Check duplicate matches on name when both DOBs are null
      final nullDobId = await animalRepo.insertAnimal(Animal(
        name: 'NullDOBGoat',
        sex: Sex.doe,
        createdAt: now,
        updatedAt: now,
      ));
      dup = await animalRepo.findDuplicateAnimal(Animal(
        name: 'nulldobgoat',
        sex: Sex.doe,
        createdAt: now,
        updatedAt: now,
      ));
      expect(dup, isNotNull);
      expect(dup!.id, nullDobId);
    });

    test('Kidding records can be inserted, queried, and updated', () async {
      final now = DateTime.now();
      
      final doeId = await animalRepo.insertAnimal(Animal(
        name: 'Dam Doe',
        sex: Sex.doe,
        createdAt: now,
        updatedAt: now,
      ));

      final kidId = await animalRepo.insertAnimal(Animal(
        name: 'Kid Goat',
        sex: Sex.doe,
        createdAt: now,
        updatedAt: now,
      ));

      final record = KiddingRecord(
        doeId: doeId,
        kidId: kidId,
        kidName: 'Kid Goat',
        kiddingDate: DateTime.now(),
        sex: KidSex.doe,
        birthOrder: 1,
        litterSize: 1,
        createdAt: now,
      );

      final insertedId = await kiddingRepo.insertKiddingRecord(record);
      expect(insertedId, greaterThan(0));

      final fetched = await kiddingRepo.getKiddingRecordsForDoe(doeId);
      expect(fetched.length, 1);
      expect(fetched.first.litterSize, 1);

      final toUpdate = fetched.first.copyWith(litterSize: 2);
      await kiddingRepo.updateKiddingRecord(toUpdate);

      final refetched = await kiddingRepo.getKiddingRecordsForDoe(doeId);
      expect(refetched.first.litterSize, 2);
    });

    test('scanAndCreateKiddingRecords automatically creates kidding records for orphaned kids', () async {
      final now = DateTime.now();

      // 1. Insert an active Doe (mother)
      final doeId = await animalRepo.insertAnimal(Animal(
        name: 'Mama Doe',
        sex: Sex.doe,
        status: AnimalStatus.active,
        createdAt: now,
        updatedAt: now,
      ));

      // 2. Insert two kid animals with Dam = Mama Doe and DOB = now, but NO kidding records
      final kid1Id = await animalRepo.insertAnimal(Animal(
        name: 'First Kid',
        sex: Sex.doe,
        damId: doeId,
        dob: now,
        createdAt: now,
        updatedAt: now,
      ));

      final kid2Id = await animalRepo.insertAnimal(Animal(
        name: 'Second Kid',
        sex: Sex.buck,
        damId: doeId,
        dob: now,
        createdAt: now,
        updatedAt: now,
      ));

      // 3. Verify no kidding records exist yet
      var existingKiddings = await kiddingRepo.getKiddingRecordsForDoe(doeId);
      expect(existingKiddings, isEmpty);

      // 4. Run the startup scan
      await kiddingRepo.scanAndCreateKiddingRecords();

      // 5. Verify that two kidding records were automatically created as twins (litterSize = 2)
      existingKiddings = await kiddingRepo.getKiddingRecordsForDoe(doeId);
      expect(existingKiddings.length, 2);

      // Sibling kidding record details
      final k1 = existingKiddings.firstWhere((k) => k.kidId == kid1Id);
      final k2 = existingKiddings.firstWhere((k) => k.kidId == kid2Id);

      expect(k1.litterSize, 2);
      expect(k2.litterSize, 2);
      expect(k1.birthType, BirthType.twin);
      expect(k2.birthType, BirthType.twin);
      expect({k1.birthOrder, k2.birthOrder}, containsAll([1, 2]));
    });

    test('scanAndCreateKiddingRecords groups sibling kids timezone-insensitively', () async {
      final now = DateTime.now();

      // 1. Insert an active Doe (mother)
      final doeId = await animalRepo.insertAnimal(Animal(
        name: 'Mama Doe TZ',
        sex: Sex.doe,
        status: AnimalStatus.active,
        createdAt: now,
        updatedAt: now,
      ));

      // 2. Insert two kid animals with Dam = Mama Doe TZ and DOB in different timezone/string formats
      // Kid 1: UTC ISO8601 string
      final kid1Id = await animalRepo.insertAnimal(Animal(
        name: 'Kid UTC',
        sex: Sex.doe,
        damId: doeId,
        dob: DateTime.parse('2026-06-21T00:00:00.000Z'),
        createdAt: now,
        updatedAt: now,
      ));

      // Kid 2: Local DateTime (no Z)
      final kid2Id = await animalRepo.insertAnimal(Animal(
        name: 'Kid Local',
        sex: Sex.buck,
        damId: doeId,
        dob: DateTime.parse('2026-06-21T00:00:00.000'),
        createdAt: now,
        updatedAt: now,
      ));

      // 3. Run the startup scan
      await kiddingRepo.scanAndCreateKiddingRecords();

      // 4. Verify that two kidding records were automatically created as twins (litterSize = 2)
      final existingKiddings = await kiddingRepo.getKiddingRecordsForDoe(doeId);
      expect(existingKiddings.length, 2);

      final k1 = existingKiddings.firstWhere((k) => k.kidId == kid1Id);
      final k2 = existingKiddings.firstWhere((k) => k.kidId == kid2Id);

      expect(k1.litterSize, 2);
      expect(k2.litterSize, 2);
      expect(k1.birthType, BirthType.twin);
      expect(k2.birthType, BirthType.twin);
      expect({k1.birthOrder, k2.birthOrder}, containsAll([1, 2]));
    });

    test('scanAndCreateKiddingRecords resolves missing parent IDs by name and groups as twins', () async {
      final now = DateTime.now();

      // 1. Insert an active Doe (mother) and an active Buck (father)
      final doeId = await animalRepo.insertAnimal(Animal(
        name: 'Mama Doe Resolve',
        sex: Sex.doe,
        status: AnimalStatus.active,
        createdAt: now,
        updatedAt: now,
      ));

      final sireId = await animalRepo.insertAnimal(Animal(
        name: 'Papa Buck Resolve',
        sex: Sex.buck,
        status: AnimalStatus.active,
        createdAt: now,
        updatedAt: now,
      ));

      // 2. Insert two kids with null dam_id/sire_id but matching dam_name/sire_name
      final kid1Id = await animalRepo.insertAnimal(Animal(
        name: 'Kid Resolve 1',
        sex: Sex.doe,
        damName: 'Mama Doe Resolve',
        sireName: 'Papa Buck Resolve',
        dob: now,
        createdAt: now,
        updatedAt: now,
      ));

      final kid2Id = await animalRepo.insertAnimal(Animal(
        name: 'Kid Resolve 2',
        sex: Sex.buck,
        damName: 'Mama Doe Resolve',
        sireName: 'Papa Buck Resolve',
        dob: now,
        createdAt: now,
        updatedAt: now,
      ));

      // 3. Run the startup scan
      await kiddingRepo.scanAndCreateKiddingRecords();

      // 4. Verify that the animal records themselves were updated with parent IDs!
      final updatedKid1 = await animalRepo.getAnimalById(kid1Id);
      final updatedKid2 = await animalRepo.getAnimalById(kid2Id);
      expect(updatedKid1!.damId, doeId);
      expect(updatedKid1.sireId, sireId);
      expect(updatedKid2!.damId, doeId);
      expect(updatedKid2.sireId, sireId);

      // 5. Verify that kidding records were successfully generated as twins
      final existingKiddings = await kiddingRepo.getKiddingRecordsForDoe(doeId);
      expect(existingKiddings.length, 2);

      final k1 = existingKiddings.firstWhere((k) => k.kidId == kid1Id);
      final k2 = existingKiddings.firstWhere((k) => k.kidId == kid2Id);

      expect(k1.litterSize, 2);
      expect(k2.litterSize, 2);
      expect(k1.birthType, BirthType.twin);
      expect(k2.birthType, BirthType.twin);
    });

    test('findDuplicateAnimal ignores Scrapie Tag when checking for conflicts', () async {
      final now = DateTime.now();

      // 1. Insert an animal with a Scrapie Tag
      await animalRepo.insertAnimal(Animal(
        name: 'Goat A',
        sex: Sex.doe,
        scrapieTag: 'USDA-SCRAPIE-123',
        createdAt: now,
        updatedAt: now,
      ));

      // 2. Check duplicate status of a different animal with the same Scrapie Tag
      final dup = await animalRepo.findDuplicateAnimal(Animal(
        name: 'Goat B',
        sex: Sex.doe,
        scrapieTag: 'USDA-SCRAPIE-123', // Same Scrapie Tag
        createdAt: now,
        updatedAt: now,
      ));

      // 3. Since Scrapie Tag is ignored, it should not find any duplicate
      expect(dup, isNull);
    });

    test('insertAnimal allows duplicate insertion and returns new ID', () async {
      final now = DateTime.now();
      final original = Animal(
        name: 'Daisy',
        earTag: 'ET-DAISY',
        sex: Sex.doe,
        createdAt: now,
        updatedAt: now,
      );

      final originalId = await animalRepo.insertAnimal(original);

      final duplicate = Animal(
        name: 'Daisy Duplicate',
        earTag: 'ET-DAISY', // Same unique ear tag
        sex: Sex.doe,
        createdAt: now,
        updatedAt: now,
      );

      final insertId = await animalRepo.insertAnimal(duplicate);

      // Verify that it returned a new ID and inserted a new row
      expect(insertId, isNot(originalId));
      final count = await animalRepo.getAnimalCount();
      expect(count, 2);
    });

    test('deduplicateDatabase is a no-op and does not merge/delete records', () async {
      final now = DateTime.now();
      final db = await dbHelper.database;

      // 1. Insert original doe
      await animalRepo.insertAnimal(Animal(
        name: 'Dolly',
        earTag: 'ET-DOLLY',
        sex: Sex.doe,
        createdAt: now,
        updatedAt: now,
      ));

      // 2. Insert duplicate doe directly via raw database
      final duplicateId = await db.insert(DatabaseHelper.tableAnimals, {
        'name': 'Dolly Dup',
        'ear_tag': 'ET-DOLLY', // Duplicate ear tag
        'sex': 'doe',
        'status': 'active',
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      });

      // 3. Add a weight record and a note record associated with the duplicate
      await db.insert(DatabaseHelper.tableWeightRecords, {
        'animal_id': duplicateId,
        'weigh_date': now.toIso8601String(),
        'weight_lbs': 65.0,
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      });

      await db.insert(DatabaseHelper.tableNotes, {
        'animal_id': duplicateId,
        'note_date': now.toIso8601String(),
        'body': 'Duplicate note content',
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      });

      // 4. Run deduplication (should be no-op)
      await animalRepo.deduplicateDatabase();

      // 5. Verify no records were deleted or merged
      final animals = await animalRepo.getAllAnimals();
      expect(animals.length, 2);

      final weightMaps = await db.query(DatabaseHelper.tableWeightRecords);
      expect(weightMaps.length, 1);
      expect(weightMaps.first['animal_id'], duplicateId);

      final noteMaps = await db.query(DatabaseHelper.tableNotes);
      expect(noteMaps.length, 1);
      expect(noteMaps.first['animal_id'], duplicateId);
    });
  });
}
