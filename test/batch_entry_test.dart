// test/batch_entry_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:flockkeeper/data/database/database_helper.dart';
import 'package:flockkeeper/data/models/animal_model.dart';
import 'package:flockkeeper/data/models/weight_record_model.dart';
import 'package:flockkeeper/data/models/health_record_model.dart';
import 'package:flockkeeper/data/models/kidding_record_model.dart';
import 'package:flockkeeper/data/repositories/animal_repository.dart';
import 'package:flockkeeper/data/repositories/weight_repository.dart';
import 'package:flockkeeper/data/repositories/health_repository.dart';
import 'package:flockkeeper/data/repositories/kidding_repository.dart';
import 'package:flockkeeper/features/batch_entry/screens/batch_config_screen.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('Batch Entry Business Logic Integration Tests', () {
    late DatabaseHelper dbHelper;
    late AnimalRepository animalRepo;
    late WeightRepository weightRepo;
    late HealthRepository healthRepo;
    late KiddingRepository kiddingRepo;

    setUp(() async {
      dbHelper = DatabaseHelper();
      animalRepo = AnimalRepository();
      weightRepo = WeightRepository();
      healthRepo = HealthRepository();
      kiddingRepo = KiddingRepository();

      // Ensure clean database state
      final db = await dbHelper.database;
      await db.delete(DatabaseHelper.tableWeightRecords);
      await db.delete(DatabaseHelper.tableHealthRecords);
      await db.delete(DatabaseHelper.tableKiddingRecords);
      await db.delete(DatabaseHelper.tableAnimals);
    });

    test('Filter animals dynamically in-memory by breed, sex, and DOB', () async {
      // 1. Insert test animals
      final a1 = Animal(
        name: 'Goat A',
        sex: Sex.doe,
        breed: 'Kiko',
        dob: DateTime(2025, 1, 1),
        status: AnimalStatus.active,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      final a2 = Animal(
        name: 'Goat B',
        sex: Sex.buck,
        breed: 'Kiko',
        dob: DateTime(2025, 6, 1),
        status: AnimalStatus.active,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      final a3 = Animal(
        name: 'Goat C',
        sex: Sex.doe,
        breed: 'Boer',
        dob: DateTime(2024, 1, 1),
        status: AnimalStatus.active,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await animalRepo.insertAnimal(a1);
      await animalRepo.insertAnimal(a2);
      await animalRepo.insertAnimal(a3);

      final animals = await animalRepo.getActiveAnimals();
      expect(animals.length, 3);

      // 2. Test filtering logic (similar to screen's _loadAnimals logic)
      
      // Filter: breed = Kiko
      final kikoOnly = animals.where((a) => a.breed == 'Kiko').toList();
      expect(kikoOnly.length, 2);
      expect(kikoOnly.any((a) => a.name == 'Goat A'), isTrue);
      expect(kikoOnly.any((a) => a.name == 'Goat B'), isTrue);

      // Filter: sex = doe
      final doesOnly = animals.where((a) => a.sex == Sex.doe).toList();
      expect(doesOnly.length, 2);
      expect(doesOnly.any((a) => a.name == 'Goat A'), isTrue);
      expect(doesOnly.any((a) => a.name == 'Goat C'), isTrue);

      // Filter: DOB between 2025-01-01 and 2025-12-31
      final dobStart = DateTime(2025, 1, 1);
      final dobEnd = DateTime(2025, 12, 31);
      final bornIn2025 = animals.where((a) {
        if (a.dob == null) return false;
        return (a.dob!.isAtSameMomentAs(dobStart) || a.dob!.isAfter(dobStart)) &&
               (a.dob!.isAtSameMomentAs(dobEnd) || a.dob!.isBefore(dobEnd));
      }).toList();
      expect(bornIn2025.length, 2);
      expect(bornIn2025.any((a) => a.name == 'Goat A'), isTrue);
      expect(bornIn2025.any((a) => a.name == 'Goat B'), isTrue);
    });

    test('Batch save weights and health records correctly', () async {
      // 1. Setup animals
      final doe = Animal(
        name: 'Doe 1',
        sex: Sex.doe,
        breed: 'Kiko',
        status: AnimalStatus.active,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      final buck = Animal(
        name: 'Buck 1',
        sex: Sex.buck,
        breed: 'Kiko',
        status: AnimalStatus.active,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      final doeId = await animalRepo.insertAnimal(doe);
      final buckId = await animalRepo.insertAnimal(buck);

      // 2. Fetch loaded animals
      final animals = await animalRepo.getActiveAnimals();
      
      // Simulate spreadsheet row states
      final rowStates = animals.map((a) => BatchEntryRowState(a)).toList();

      // Enter weight for Doe 1 (rowStates[0])
      rowStates[0].weightController.text = '75.5';
      rowStates[0].weightNotesController.text = 'Healthy weight';

      // Enter health record for Buck 1 (rowStates[1])
      rowStates[1].famachaScore = 2;
      rowStates[1].bcsScore = 3.5;
      rowStates[1].actionTaken = 'Administer Treatment';
      rowStates[1].treatmentDecision = HealthRecordType.vaccination;
      rowStates[1].selectedProduct = 'CD&T';
      rowStates[1].dosageController.text = '2ml';
      rowStates[1].healthNotesController.text = 'Annual booster';

      final batchDate = DateTime(2026, 6, 21);

      // 3. Execute save simulation logic
      for (final row in rowStates) {
        final id = row.animal.id!;

        // Record weight
        final wText = row.weightController.text.trim();
        final wLbs = double.tryParse(wText);
        if (wLbs != null) {
          final record = WeightRecord(
            animalId: id,
            weightLbs: wLbs,
            weighDate: batchDate,
            notes: row.weightNotesController.text.trim().isNotEmpty 
                ? row.weightNotesController.text.trim() : null,
          );
          await weightRepo.insertWeightRecord(record);
        }

        // Record health
        final hasFamacha = row.famachaScore != null;
        final hasBcs = row.bcsScore != null;
        final action = row.actionTaken;
        final product = row.selectedProduct;
        final dosage = row.dosageController.text.trim();
        final notesInput = row.healthNotesController.text.trim();

        if (hasFamacha || hasBcs || action != null || notesInput.isNotEmpty) {
          String finalNotes = notesInput;
          if (action != null) {
            finalNotes = 'Action: $action. $finalNotes';
          }
          final record = HealthRecord(
            animalId: id,
            recordType: row.treatmentDecision ?? HealthRecordType.vaccination,
            recordDate: batchDate,
            treatment: product != null && product.isNotEmpty ? product : null,
            dosage: dosage.isNotEmpty ? dosage : null,
            famachaScore: row.famachaScore,
            bcsScore: row.bcsScore,
            notes: finalNotes.isNotEmpty ? finalNotes : null,
            resolved: true,
          );
          await healthRepo.insertHealthRecord(record);
        }
      }

      // 4. Verify results
      final doeWeights = await weightRepo.getWeightRecordsForAnimal(doeId);
      expect(doeWeights.length, 1);
      expect(doeWeights.first.weightLbs, 75.5);
      expect(doeWeights.first.notes, 'Healthy weight');

      final buckWeights = await weightRepo.getWeightRecordsForAnimal(buckId);
      expect(buckWeights.isEmpty, isTrue); // buck had no weight entered

      final buckHealth = await healthRepo.getHealthRecordsForAnimal(buckId);
      expect(buckHealth.length, 1);
      expect(buckHealth.first.recordType, HealthRecordType.vaccination);
      expect(buckHealth.first.treatment, 'CD&T');
      expect(buckHealth.first.dosage, '2ml');
      expect(buckHealth.first.famachaScore, 2);
      expect(buckHealth.first.bcsScore, 3.5);
      expect(buckHealth.first.notes, 'Action: Administer Treatment. Annual booster');

      final doeHealth = await healthRepo.getHealthRecordsForAnimal(doeId);
      expect(doeHealth.isEmpty, isTrue); // doe had no health records entered
    });

    test('Batch save kidding details and register kids as new animals', () async {
      // 1. Setup dam and sire
      final dam = Animal(
        name: 'Dam Doe',
        sex: Sex.doe,
        breed: 'Kiko',
        status: AnimalStatus.active,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      final sire = Animal(
        name: 'Sire Buck',
        sex: Sex.buck,
        breed: 'Kiko',
        status: AnimalStatus.active,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      final damId = await animalRepo.insertAnimal(dam);
      final sireId = await animalRepo.insertAnimal(sire);

      final animals = await animalRepo.getActiveAnimals();
      final doeRow = BatchEntryRowState(animals.firstWhere((a) => a.id == damId));

      // 2. Configure Kids logged for the doe row
      final kid1 = BatchKidState()
        ..name = 'My First Kid'
        ..sex = KidSex.buck
        ..weightLbs = 6.8
        ..survivalStatus = SurvivalStatus.alive
        ..presentation = Presentation.normal;

      final kid2 = BatchKidState()
        ..name = 'My Second Kid'
        ..sex = KidSex.doe
        ..weightLbs = 6.2
        ..survivalStatus = SurvivalStatus.alive
        ..presentation = Presentation.assisted;

      doeRow.kids = [kid1, kid2];
      doeRow.sireId = sireId;
      doeRow.damConditionScore = 4;
      doeRow.complicationsController.text = 'Slight assistance needed';

      final batchDate = DateTime(2026, 6, 21);

      // 3. Execute kidding save simulation logic
      if (doeRow.animal.sex == Sex.doe && doeRow.kids.isNotEmpty) {
        final doeName = doeRow.animal.name;
        final sId = doeRow.sireId;
        final sName = sId != null ? 'Sire Buck' : null;

        for (int i = 0; i < doeRow.kids.length; i++) {
          final kid = doeRow.kids[i];
          int? kidAnimalId;

          // Register new animal
          if (kid.survivalStatus == SurvivalStatus.alive || kid.survivalStatus == SurvivalStatus.sold) {
            final kidAnimal = Animal(
              name: kid.name.trim().isNotEmpty ? kid.name.trim() : 'Kid ${i + 1} of $doeName',
              dob: batchDate,
              sex: kid.sex == KidSex.doe ? Sex.doe : Sex.buck,
              damId: damId,
              sireId: sId,
              damName: doeName,
              sireName: sName,
              breed: doeRow.animal.breed,
              birthWeightLbs: kid.weightLbs,
              status: AnimalStatus.active,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            );
            kidAnimalId = await animalRepo.insertAnimal(kidAnimal);
          }

          // Save kidding record
          final kiddingRecord = KiddingRecord(
            doeId: damId,
            buckId: sId,
            kidId: kidAnimalId,
            kidName: kid.name.trim(),
            kiddingDate: batchDate,
            birthOrder: i + 1,
            litterSize: doeRow.kids.length,
            birthWeightLbs: kid.weightLbs,
            sex: kid.sex,
            birthType: BirthType.twin,
            presentation: kid.presentation,
            survivalStatus: kid.survivalStatus,
            receivedColostrum: kid.receivedColostrum,
            bottleFed: kid.bottleFed,
            damConditionScore: doeRow.damConditionScore,
            complications: doeRow.complicationsController.text.trim().isNotEmpty 
                ? doeRow.complicationsController.text.trim() : null,
            notes: kid.notes.trim().isNotEmpty ? kid.notes.trim() : null,
            createdAt: DateTime.now(),
          );
          await kiddingRepo.insertKiddingRecord(kiddingRecord);
        }
      }

      // 4. Verify registered kid animals and kidding records
      final allAnimals = await animalRepo.getActiveAnimals();
      // Total animals should be 4 now (Dam, Sire, and 2 newly registered kids)
      expect(allAnimals.length, 4);

      final registeredKid1 = allAnimals.firstWhere((a) => a.name == 'My First Kid');
      expect(registeredKid1.sex, Sex.buck);
      expect(registeredKid1.damId, damId);
      expect(registeredKid1.sireId, sireId);
      expect(registeredKid1.birthWeightLbs, 6.8);
      expect(registeredKid1.dob, batchDate);

      final registeredKid2 = allAnimals.firstWhere((a) => a.name == 'My Second Kid');
      expect(registeredKid2.sex, Sex.doe);
      expect(registeredKid2.damId, damId);
      expect(registeredKid2.sireId, sireId);
      expect(registeredKid2.birthWeightLbs, 6.2);
      expect(registeredKid2.dob, batchDate);

      final doeKiddingHistory = await kiddingRepo.getKiddingRecordsForDoe(damId);
      expect(doeKiddingHistory.length, 2);
      expect(doeKiddingHistory.any((k) => k.kidName == 'My First Kid' && k.birthOrder == 1), isTrue);
      expect(doeKiddingHistory.any((k) => k.kidName == 'My Second Kid' && k.birthOrder == 2), isTrue);
      expect(doeKiddingHistory.first.complications, 'Slight assistance needed');
      expect(doeKiddingHistory.first.damConditionScore, 4);
    });

    test('Batch save animal status updates (removals) correctly', () async {
      // 1. Insert test animals
      final a1 = Animal(
        name: 'Goat to Sell',
        sex: Sex.doe,
        breed: 'Kiko',
        status: AnimalStatus.active,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      final a2 = Animal(
        name: 'Goat to culled',
        sex: Sex.buck,
        breed: 'Boer',
        status: AnimalStatus.active,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      final id1 = await animalRepo.insertAnimal(a1);
      final id2 = await animalRepo.insertAnimal(a2);

      // 2. Fetch loaded row states
      final animals = await animalRepo.getActiveAnimals();
      final rowStates = animals.map((a) => BatchEntryRowState(a)).toList();

      // Configure status overrides
      // First animal is sold
      rowStates[0].removalStatus = AnimalStatus.sold;
      rowStates[0].soldToController.text = 'Sale Barn A';
      rowStates[0].soldPriceController.text = '150.0';

      // Second animal is culled
      rowStates[1].removalStatus = AnimalStatus.culled;

      final batchDate = DateTime(2026, 6, 21);

      // 3. Execute removal save simulation logic (matching _saveBatch removal flow)
      for (final row in rowStates) {
        final status = row.removalStatus;
        if (status != AnimalStatus.active) {
          final price = double.tryParse(row.soldPriceController.text.trim());
          final soldTo = row.soldToController.text.trim();
          final deceasedReason = row.deceasedReasonController.text.trim();

          DateTime? soldDate;
          DateTime? deceasedDate;
          if (status == AnimalStatus.sold || status == AnimalStatus.transferred) {
            soldDate = batchDate;
          } else if (status == AnimalStatus.deceased) {
            deceasedDate = batchDate;
          }

          final updatedAnimal = row.animal.copyWith(
            status: status,
            soldDate: soldDate,
            soldPrice: price,
            soldTo: soldTo.isNotEmpty ? soldTo : null,
            deceasedDate: deceasedDate,
            deceasedReason: deceasedReason.isNotEmpty ? deceasedReason : null,
            updatedAt: DateTime.now(),
          );

          await animalRepo.updateAnimal(updatedAnimal);
        }
      }

      // 4. Verify updates
      final updatedA1 = await animalRepo.getAnimalById(id1);
      expect(updatedA1?.status, AnimalStatus.sold);
      expect(updatedA1?.soldTo, 'Sale Barn A');
      expect(updatedA1?.soldPrice, 150.0);
      expect(updatedA1?.soldDate, batchDate);

      final updatedA2 = await animalRepo.getAnimalById(id2);
      expect(updatedA2?.status, AnimalStatus.culled);

      // Verify they are no longer returned by getActiveAnimals
      final activeList = await animalRepo.getActiveAnimals();
      expect(activeList.isEmpty, isTrue);
    });

    test('Batch add new animals and their initial weights correctly', () async {
      // 1. Simulate new animal row states
      final rowStates = [
        BatchEntryRowState.forAddition(Sex.doe)
          ..nameController.text = 'New Doe A'
          ..earTagController.text = 'TAG-111'
          ..tattooController.text = 'TAT-111'
          ..breedController.text = 'Kiko'
          ..colorController.text = 'Solid White'
          ..purchasePriceController.text = '250.0'
          ..purchaseFromController.text = 'Breeder X'
          ..weightController.text = '45.0', // Initial weight
        
        BatchEntryRowState.forAddition(Sex.buck)
          ..nameController.text = 'New Buck B'
          ..earTagController.text = 'TAG-222'
          ..breedController.text = 'Boer'
          ..purchasePriceController.text = '300.0'
          ..weightController.text = '55.5', // Initial weight
      ];

      final batchDate = DateTime(2026, 6, 21);

      // 2. Execute additions save simulation logic (matching _saveBatch additions flow)
      for (final row in rowStates) {
        final name = row.nameController.text.trim();
        if (name.isEmpty) continue;

        final tag = row.earTagController.text.trim();
        final tattoo = row.tattooController.text.trim();
        final breed = row.breedController.text.trim().isNotEmpty ? row.breedController.text.trim() : 'Kiko';
        final color = row.colorController.text.trim();
        final price = double.tryParse(row.purchasePriceController.text.trim());
        final seller = row.purchaseFromController.text.trim();

        final animal = Animal(
          name: name,
          sex: row.sex,
          dob: row.dob,
          breed: breed,
          color: color.isNotEmpty ? color : null,
          earTag: tag.isNotEmpty ? tag : null,
          tattoo: tattoo.isNotEmpty ? tattoo : null,
          purchaseDate: batchDate,
          purchasePrice: price,
          soldTo: seller.isNotEmpty ? seller : null, // soldTo stores seller
          status: AnimalStatus.active,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        final newId = await animalRepo.insertAnimal(animal);

        // Record weight
        final wLbs = double.tryParse(row.weightController.text.trim());
        if (wLbs != null) {
          final record = WeightRecord(
            animalId: newId,
            weightLbs: wLbs,
            weighDate: batchDate,
            notes: 'Initial weight recorded at acquisition',
          );
          await weightRepo.insertWeightRecord(record);
        }
      }

      // 3. Verify inserted animals and weight records
      final activeList = await animalRepo.getActiveAnimals();
      expect(activeList.length, 2);

      final doe = activeList.firstWhere((a) => a.name == 'New Doe A');
      expect(doe.earTag, 'TAG-111');
      expect(doe.tattoo, 'TAT-111');
      expect(doe.breed, 'Kiko');
      expect(doe.color, 'Solid White');
      expect(doe.purchasePrice, 250.0);
      expect(doe.soldTo, 'Breeder X'); // purchase source is sold_to

      final doeWeights = await weightRepo.getWeightRecordsForAnimal(doe.id!);
      expect(doeWeights.length, 1);
      expect(doeWeights.first.weightLbs, 45.0);
      expect(doeWeights.first.weighDate, batchDate);

      final buck = activeList.firstWhere((a) => a.name == 'New Buck B');
      expect(buck.earTag, 'TAG-222');
      expect(buck.breed, 'Boer');
      expect(buck.purchasePrice, 300.0);

      final buckWeights = await weightRepo.getWeightRecordsForAnimal(buck.id!);
      expect(buckWeights.length, 1);
      expect(buckWeights.first.weightLbs, 55.5);
    });
  });
}
