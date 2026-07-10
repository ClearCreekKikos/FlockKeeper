import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:flockkeeper/data/database/database_helper.dart';
import 'package:flockkeeper/data/models/health_record_model.dart';
import 'package:flockkeeper/data/repositories/health_repository.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('HealthRepository Tests', () {
    late DatabaseHelper dbHelper;
    late HealthRepository healthRepo;

    setUp(() async {
      dbHelper = DatabaseHelper();
      healthRepo = HealthRepository();
      // Ensure clean database state
      final db = await dbHelper.database;
      await db.delete(DatabaseHelper.tableHealthRecords);
      await db.delete(DatabaseHelper.tableAnimals);
    });

    test('Insert health record successfully', () async {
      final db = await dbHelper.database;
      
      // Insert a dummy animal first to satisfy foreign key constraint
      final animalId = await db.insert(DatabaseHelper.tableAnimals, {
        'name': 'Test Goat',
        'sex': 'doe',
        'status': 'active',
      });

      final record = HealthRecord(
        animalId: animalId,
        recordType: HealthRecordType.famacha,
        recordDate: DateTime.now(),
        administrator: 'Dr. Smith',
        withdrawalDays: 10,
        notes: 'Test notes',
      );

      final insertedId = await healthRepo.insertHealthRecord(record);
      expect(insertedId, greaterThan(0));

      final retrieved = await healthRepo.getHealthRecordById(insertedId);
      expect(retrieved, isNotNull);
      expect(retrieved!.notes, 'Test notes');
      expect(retrieved.administrator, 'Dr. Smith');
      expect(retrieved.withdrawalDays, 10);
    });
  });
}
