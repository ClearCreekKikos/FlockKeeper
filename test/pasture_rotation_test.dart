import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:flockkeeper/data/database/database_helper.dart';
import 'package:flockkeeper/data/models/animal_model.dart';
import 'package:flockkeeper/data/models/pasture_model.dart';
import 'package:flockkeeper/data/repositories/animal_repository.dart';
import 'package:flockkeeper/data/repositories/pasture_repository.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('Pasture Rotational Grazing Tests', () {
    late DatabaseHelper dbHelper;
    late AnimalRepository animalRepo;
    late PastureRepository pastureRepo;

    setUp(() async {
      dbHelper = DatabaseHelper();
      animalRepo = AnimalRepository();
      pastureRepo = PastureRepository();

      final db = await dbHelper.database;
      await db.delete(DatabaseHelper.tablePastureHistory);
      await db.delete(DatabaseHelper.tablePastures);
      await db.delete(DatabaseHelper.tableAnimals);
    });

    test('Moving animal into pasture checks out from previous pasture', () async {
      final now = DateTime.now();

      // 1. Create two pastures
      final p1Id = await pastureRepo.insertPasture(Pasture(
        name: 'Field A',
        acreage: 5.0,
        carryingCapacity: 10,
        createdAt: now,
        updatedAt: now,
      ));

      final p2Id = await pastureRepo.insertPasture(Pasture(
        name: 'Field B',
        acreage: 10.0,
        carryingCapacity: 20,
        createdAt: now,
        updatedAt: now,
      ));

      // 2. Create animal
      final animalId = await animalRepo.insertAnimal(Animal(
        name: 'Grazer Doe',
        sex: Sex.doe,
        createdAt: now,
        updatedAt: now,
      ));

      // 3. Move animal into Field A
      await pastureRepo.moveAnimalIntoPasture(
        animalId: animalId,
        pastureId: p1Id,
        moveInDate: now,
      );

      // Verify Field A is occupied
      var pasture1 = await pastureRepo.getPastureById(p1Id);
      expect(pasture1!.status, PastureStatus.occupied);
      expect(pasture1.currentAnimalCount, 1);

      // 4. Move animal into Field B (should check out from Field A)
      final moveOutDate = now.add(const Duration(days: 5));
      await pastureRepo.moveAnimalIntoPasture(
        animalId: animalId,
        pastureId: p2Id,
        moveInDate: moveOutDate,
      );

      // Verify Field A is now resting (since its last grazer checked out)
      pasture1 = await pastureRepo.getPastureById(p1Id);
      expect(pasture1!.status, PastureStatus.resting);
      expect(pasture1.currentAnimalCount, 0);
      expect(pasture1.lastGrazedDate, isNotNull);

      // Verify Field B is now occupied
      var pasture2 = await pastureRepo.getPastureById(p2Id);
      expect(pasture2!.status, PastureStatus.occupied);
      expect(pasture2.currentAnimalCount, 1);

      // Verify active pasture query
      final activePasture = await pastureRepo.getPastureForAnimal(animalId);
      expect(activePasture!.id, p2Id);
    });

    test('Checkout triggers resting status and calculates availability date', () async {
      final now = DateTime.now();

      final pId = await pastureRepo.insertPasture(Pasture(
        name: 'Field C',
        carryingCapacity: 5,
        restDaysTarget: 15,
        createdAt: now,
        updatedAt: now,
      ));

      final aId = await animalRepo.insertAnimal(Animal(
        name: 'Billy',
        sex: Sex.buck,
        createdAt: now,
        updatedAt: now,
      ));

      // Move in
      await pastureRepo.moveAnimalIntoPasture(
        animalId: aId,
        pastureId: pId,
        moveInDate: now,
      );

      // Move out
      final checkoutDate = now.add(const Duration(days: 4));
      await pastureRepo.moveAnimalOutOfPasture(
        animalId: aId,
        pastureId: pId,
        moveOutDate: checkoutDate,
      );

      // Verify pasture transitions to resting
      final pasture = await pastureRepo.getPastureById(pId);
      expect(pasture!.status, PastureStatus.resting);
      expect(pasture.currentAnimalCount, 0);

      // Verify available Date is checkoutDate + restDaysTarget (15 days)
      final expectedAvailable = checkoutDate.add(const Duration(days: 15));
      expect(pasture.availableDate!.year, expectedAvailable.year);
      expect(pasture.availableDate!.month, expectedAvailable.month);
      expect(pasture.availableDate!.day, expectedAvailable.day);
    });
  });
}
