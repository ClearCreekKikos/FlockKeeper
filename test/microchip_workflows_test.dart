import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:flockkeeper/data/database/database_helper.dart';
import 'package:flockkeeper/data/repositories/animal_repository.dart';
import 'package:flockkeeper/data/repositories/weight_repository.dart';
import 'package:flockkeeper/data/repositories/health_repository.dart';
import 'package:flockkeeper/data/repositories/pasture_repository.dart';
import 'package:flockkeeper/data/models/animal_model.dart';
import 'package:flockkeeper/data/models/weight_record_model.dart';
import 'package:flockkeeper/data/models/health_record_model.dart';
import 'package:flockkeeper/data/models/pasture_model.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late DatabaseHelper dbHelper;
  late AnimalRepository animalRepo;
  late WeightRepository weightRepo;
  late HealthRepository healthRepo;
  late PastureRepository pastureRepo;

  setUp(() async {
    dbHelper = DatabaseHelper();
    // Force clean in-memory database rebuild
    final db = await dbHelper.database;
    await db.delete(DatabaseHelper.tableAnimals);
    await db.delete(DatabaseHelper.tableWeightRecords);
    await db.delete(DatabaseHelper.tableHealthRecords);
    await db.delete(DatabaseHelper.tablePastures);
    await db.delete(DatabaseHelper.tablePastureHistory);

    animalRepo = AnimalRepository();
    weightRepo = WeightRepository();
    healthRepo = HealthRepository();
    pastureRepo = PastureRepository();
  });

  group('Microchip & EID Workflow Integration Tests', () {
    test('Search animals by EID / rfidTag column', () async {
      final now = DateTime.now();
      // 1. Insert test goats
      final goat1 = Animal(
        name: 'Goat A',
        rfidTag: 'RFID9820001',
        breed: 'Kiko',
        sex: Sex.doe,
        status: AnimalStatus.active,
        createdAt: now,
        updatedAt: now,
      );
      final goat2 = Animal(
        name: 'Goat B',
        rfidTag: 'RFID9820002',
        breed: 'Kiko',
        sex: Sex.doe,
        status: AnimalStatus.active,
        createdAt: now,
        updatedAt: now,
      );
      await animalRepo.insertAnimal(goat1);
      await animalRepo.insertAnimal(goat2);

      // 2. Perform search query with EID
      final results1 = await animalRepo.searchAnimals('RFID9820001');
      expect(results1.length, 1);
      expect(results1.first.name, 'Goat A');

      final results2 = await animalRepo.searchAnimals('RFID9820002');
      expect(results2.length, 1);
      expect(results2.first.name, 'Goat B');

      // Partial scan search
      final resultsPartial = await animalRepo.searchAnimals('RFID982');
      expect(resultsPartial.length, 2);
    });

    test('Retrieve animal by exact RFID tag', () async {
      final now = DateTime.now();
      final goat = Animal(
        name: 'Goat RFID Test',
        rfidTag: '982000123456',
        breed: 'Kiko',
        sex: Sex.buck,
        status: AnimalStatus.active,
        createdAt: now,
        updatedAt: now,
      );
      await animalRepo.insertAnimal(goat);

      final found = await animalRepo.getAnimalByRfidTag('982000123456');
      expect(found, isNotNull);
      expect(found!.name, 'Goat RFID Test');

      final notFound = await animalRepo.getAnimalByRfidTag('11111111111');
      expect(notFound, isNull);
    });

    test('Chute weigh and deworm microchip workflow logging', () async {
      final now = DateTime.now();
      final goat = Animal(
        name: 'Chute Goat',
        rfidTag: 'CHUTE-EID-100',
        breed: 'Kiko',
        sex: Sex.buck,
        status: AnimalStatus.active,
        createdAt: now,
        updatedAt: now,
      );
      final id = await animalRepo.insertAnimal(goat);

      // Verify we can fetch it, simulate chute weight entry
      final animal = await animalRepo.getAnimalByRfidTag('CHUTE-EID-100');
      expect(animal, isNotNull);

      // Log weight
      final weightRecord = WeightRecord(
        animalId: animal!.id!,
        weighDate: DateTime.now(),
        weightLbs: 120.0,
        notes: 'Chute scanned weight',
      );
      await weightRepo.insertWeightRecord(weightRecord);

      // Log treatment dewormer
      final healthRecord = HealthRecord(
        animalId: animal.id!,
        recordType: HealthRecordType.deworming,
        recordDate: DateTime.now(),
        treatment: 'Ivermectin',
        dosage: '10cc',
        resolved: true,
      );
      await healthRepo.insertHealthRecord(healthRecord);

      // Assert database matches chute actions
      final latestWeight = await weightRepo.getLatestWeightForAnimal(id);
      expect(latestWeight, isNotNull);
      expect(latestWeight!.weightLbs, 120.0);

      final healthLogs = await healthRepo.getHealthRecordsForAnimal(id);
      expect(healthLogs.length, 1);
      expect(healthLogs.first.treatment, 'Ivermectin');
    });

    test('Trailer loading bulk sale microchip workflow logging', () async {
      final now = DateTime.now();
      // Setup 3 active goats
      final g1 = Animal(name: 'Sale 1', rfidTag: 'TAG1', breed: 'Kiko', sex: Sex.doe, status: AnimalStatus.active, createdAt: now, updatedAt: now);
      final g2 = Animal(name: 'Sale 2', rfidTag: 'TAG2', breed: 'Kiko', sex: Sex.doe, status: AnimalStatus.active, createdAt: now, updatedAt: now);
      final g3 = Animal(name: 'Sale 3', rfidTag: 'TAG3', breed: 'Kiko', sex: Sex.doe, status: AnimalStatus.active, createdAt: now, updatedAt: now);

      final id1 = await animalRepo.insertAnimal(g1);
      await animalRepo.insertAnimal(g2);
      final id3 = await animalRepo.insertAnimal(g3);

      // Simulate Scanning loaded trailer: TAG1, TAG2, TAG3
      final loadedTags = ['TAG1', 'TAG2', 'TAG3'];
      final List<Animal> loadedAnimals = [];

      for (var tag in loadedTags) {
        final a = await animalRepo.getAnimalByRfidTag(tag);
        if (a != null) loadedAnimals.add(a);
      }
      expect(loadedAnimals.length, 3);

      // Perform Bulk Sale execution
      for (var a in loadedAnimals) {
        final updated = a.copyWith(
          status: AnimalStatus.sold,
          soldDate: DateTime.now(),
          soldPrice: 250.0,
          soldTo: 'Sale Barn',
        );
        await animalRepo.updateAnimal(updated);
      }

      // Assert they are marked sold in DB
      final dbG1 = await animalRepo.getAnimalById(id1);
      expect(dbG1!.status, AnimalStatus.sold);
      expect(dbG1.soldPrice, 250.0);
      expect(dbG1.soldTo, 'Sale Barn');

      final dbG3 = await animalRepo.getAnimalById(id3);
      expect(dbG3!.status, AnimalStatus.sold);
    });

    test('Pasture audit location verification and auto-transfer', () async {
      final now = DateTime.now();
      // 1. Setup two pastures
      final p1Id = await pastureRepo.insertPasture(Pasture(name: 'North Pasture', acreage: 10.0, status: PastureStatus.available, createdAt: now, updatedAt: now));
      final p2Id = await pastureRepo.insertPasture(Pasture(name: 'South Pasture', acreage: 15.0, status: PastureStatus.available, createdAt: now, updatedAt: now));

      // 2. Setup animal current pasture assignments
      final a1Id = await animalRepo.insertAnimal(Animal(name: 'Goat 1', rfidTag: 'EID1', breed: 'Kiko', sex: Sex.doe, status: AnimalStatus.active, createdAt: now, updatedAt: now));
      final a2Id = await animalRepo.insertAnimal(Animal(name: 'Goat 2', rfidTag: 'EID2', breed: 'Kiko', sex: Sex.doe, status: AnimalStatus.active, createdAt: now, updatedAt: now));

      // Goat 1 moves to North Pasture
      await pastureRepo.moveAnimalIntoPasture(animalId: a1Id, pastureId: p1Id, moveInDate: DateTime.now());
      // Goat 2 moves to South Pasture
      await pastureRepo.moveAnimalIntoPasture(animalId: a2Id, pastureId: p2Id, moveInDate: DateTime.now());

      // 3. Audit check on North Pasture (p1Id)
      // Expecting Goat 1 in North Pasture
      final expected = await pastureRepo.getAnimalsInPasture(p1Id);
      expect(expected.length, 1);
      expect(expected.first.id, a1Id);

      // Scanned Goat 2 ('EID2') in North Pasture (which is expected in South Pasture)
      final scannedWrongPastureGoat = await animalRepo.getAnimalByRfidTag('EID2');
      expect(scannedWrongPastureGoat, isNotNull);

      final currentP = await pastureRepo.getPastureForAnimal(scannedWrongPastureGoat!.id!);
      expect(currentP!.id, p2Id); // Correctly checks that it currently belongs to South Pasture

      // Auto-transfer Goat 2 into North Pasture (Audit location update)
      await pastureRepo.moveAnimalIntoPasture(
        animalId: scannedWrongPastureGoat.id!,
        pastureId: p1Id,
        moveInDate: DateTime.now(),
        notes: 'Transferred during audit',
      );

      // Assert they are both now in North Pasture
      final finalNorthAnimals = await pastureRepo.getAnimalsInPasture(p1Id);
      expect(finalNorthAnimals.length, 2);
      expect(finalNorthAnimals.any((g) => g.id == a1Id), true);
      expect(finalNorthAnimals.any((g) => g.id == a2Id), true);
    });
  });
}
