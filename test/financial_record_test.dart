// test/financial_record_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:flockkeeper/data/database/database_helper.dart';
import 'package:flockkeeper/data/models/financial_record_model.dart';
import 'package:flockkeeper/data/repositories/financial_repository.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('FinancialRecord Model Tests', () {
    test('FinancialRecord serialization and deserialization maps correctly', () {
      final now = DateTime.now();
      final record = FinancialRecord(
        id: 1,
        animalId: 10,
        recordDate: now,
        category: 'feed',
        type: 'expense',
        amount: 150.75,
        description: 'Premium feed bag',
        vendorBuyer: 'Farmers Supply Co.',
        receiptNumber: 'INV-12345',
        notes: 'Monthly feed purchase',
        createdAt: now,
        updatedAt: now,
      );

      final map = record.toMap();
      expect(map['id'], 1);
      expect(map['animal_id'], 10);
      expect(map['record_date'], now.toIso8601String());
      expect(map['category'], 'feed');
      expect(map['type'], 'expense');
      expect(map['amount'], 150.75);
      expect(map['description'], 'Premium feed bag');
      expect(map['vendor_buyer'], 'Farmers Supply Co.');
      expect(map['receipt_number'], 'INV-12345');
      expect(map['notes'], 'Monthly feed purchase');
      expect(map['created_at'], now.toIso8601String());
      expect(map['updated_at'], now.toIso8601String());

      final parsed = FinancialRecord.fromMap(map);
      expect(parsed.id, 1);
      expect(parsed.animalId, 10);
      expect(parsed.recordDate.toIso8601String(), now.toIso8601String());
      expect(parsed.category, 'feed');
      expect(parsed.type, 'expense');
      expect(parsed.amount, 150.75);
      expect(parsed.description, 'Premium feed bag');
      expect(parsed.vendorBuyer, 'Farmers Supply Co.');
      expect(parsed.receiptNumber, 'INV-12345');
      expect(parsed.notes, 'Monthly feed purchase');
      expect(parsed.createdAt!.toIso8601String(), now.toIso8601String());
      expect(parsed.updatedAt!.toIso8601String(), now.toIso8601String());
    });

    test('FinancialRecord copyWith updates fields correctly', () {
      final record = FinancialRecord(
        recordDate: DateTime(2026, 6, 19),
        category: 'other',
        type: 'expense',
        amount: 20.0,
      );

      final updated = record.copyWith(
        id: 99,
        category: 'sale',
        type: 'income',
        amount: 500.0,
        description: 'Sold kid goat',
      );

      expect(updated.id, 99);
      expect(updated.recordDate, DateTime(2026, 6, 19));
      expect(updated.category, 'sale');
      expect(updated.type, 'income');
      expect(updated.amount, 500.0);
      expect(updated.description, 'Sold kid goat');
    });
  });

  group('FinancialRepository Database Integration Tests', () {
    late DatabaseHelper dbHelper;
    late FinancialRepository financialRepo;

    setUp(() async {
      dbHelper = DatabaseHelper();
      financialRepo = FinancialRepository();
      
      // Clear tables to start with a clean in-memory database
      final db = await dbHelper.database;
      await db.delete(DatabaseHelper.tableFinancialRecords);
      await db.delete(DatabaseHelper.tableAnimals);
    });

    test('Log, retrieve, update, and delete transactions successfully', () async {
      final db = await dbHelper.database;

      // Log a general transaction (not linked to animal)
      final record1 = FinancialRecord(
        recordDate: DateTime(2026, 6, 1),
        category: 'feed',
        type: 'expense',
        amount: 75.50,
        description: 'Alfalfa hay',
        vendorBuyer: 'Hay Provider Inc',
      );

      final id1 = await financialRepo.insertFinancialRecord(record1);
      expect(id1, greaterThan(0));

      // Retrieve all financial records
      var allRecords = await financialRepo.getAllFinancialRecords();
      expect(allRecords.length, 1);
      expect(allRecords.first.id, id1);
      expect(allRecords.first.description, 'Alfalfa hay');
      expect(allRecords.first.type, 'expense');

      // Update the transaction
      final recordToUpdate = allRecords.first.copyWith(
        amount: 80.0,
        description: 'Premium Alfalfa hay',
      );
      final updateCount = await financialRepo.updateFinancialRecord(recordToUpdate);
      expect(updateCount, 1);

      // Verify updates
      final retrievedUpdated = await financialRepo.getFinancialRecordById(id1);
      expect(retrievedUpdated, isNotNull);
      expect(retrievedUpdated!.amount, 80.0);
      expect(retrievedUpdated.description, 'Premium Alfalfa hay');

      // Add a goat first to link a transaction to it
      final animalId = await db.insert(DatabaseHelper.tableAnimals, {
        'name': 'Fin Goat',
        'sex': 'buck',
        'status': 'active',
      });

      // Log a sale transaction linked to the goat
      final record2 = FinancialRecord(
        animalId: animalId,
        recordDate: DateTime(2026, 6, 10),
        category: 'sale',
        type: 'income',
        amount: 400.0,
        description: 'Sold breeding buck',
        vendorBuyer: 'Kiko Farms Ltd',
      );

      final id2 = await financialRepo.insertFinancialRecord(record2);
      expect(id2, greaterThan(0));

      // Retrieve animal-specific financial records
      final animalRecords = await financialRepo.getFinancialRecordsForAnimal(animalId);
      expect(animalRecords.length, 1);
      expect(animalRecords.first.id, id2);
      expect(animalRecords.first.amount, 400.0);
      expect(animalRecords.first.type, 'income');

      // Check all records again, they should be 2 now, sorted by date DESC
      allRecords = await financialRepo.getAllFinancialRecords();
      expect(allRecords.length, 2);
      expect(allRecords[0].id, id2); // June 10 is newer than June 1
      expect(allRecords[1].id, id1);

      // Delete the first transaction
      final deleteCount = await financialRepo.deleteFinancialRecord(id1);
      expect(deleteCount, 1);

      // Verify deletion
      final retrievedDeleted = await financialRepo.getFinancialRecordById(id1);
      expect(retrievedDeleted, isNull);

      final remainingRecords = await financialRepo.getAllFinancialRecords();
      expect(remainingRecords.length, 1);
      expect(remainingRecords.first.id, id2);
    });
  });
}
