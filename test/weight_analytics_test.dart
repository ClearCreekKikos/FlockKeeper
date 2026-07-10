import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flockkeeper/data/database/database_helper.dart';
import 'package:flockkeeper/features/weights/screens/weight_analytics_screen.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  GoogleFonts.config.allowRuntimeFetching = false;

  group('Weight Analytics Provider and Screen Tests', () {
    late DatabaseHelper dbHelper;

    setUp(() async {
      dbHelper = DatabaseHelper();
      final db = await dbHelper.database;
      await db.delete(DatabaseHelper.tableWeightRecords);
      await db.delete(DatabaseHelper.tableAnimals);
    });

    testWidgets('Weight Analytics Screen loads and displays correctly', (WidgetTester tester) async {
      await tester.runAsync(() async {
        final db = await dbHelper.database;
        
        // 1. Insert an animal and weight record to populate group
        final now = DateTime.now();
        final kidDob = now.subtract(const Duration(days: 45)); // Should fit in "Kids" category (0-90 days)
        
        final animalId = await db.insert(DatabaseHelper.tableAnimals, {
          'name': 'Buster Kid',
          'sex': 'buck',
          'status': 'active',
          'breed': 'Kiko',
          'dob': kidDob.toIso8601String(),
          'birth_weight_lbs': 8.5,
          'created_at': now.toIso8601String(),
          'updated_at': now.toIso8601String(),
        });

        // Insert recent weight record for Buster Kid
        await db.insert(DatabaseHelper.tableWeightRecords, {
          'animal_id': animalId,
          'weight_lbs': 38.5,
          'weigh_date': now.toIso8601String(),
          'created_at': now.toIso8601String(),
        });

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: const Scaffold(
                body: WeightAnalyticsScreen(),
              ),
            ),
          ),
        );

        // Verify progress indicator is shown initially
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        
        // Wait for provider to load and settle
        await Future.delayed(const Duration(seconds: 1));
        await tester.pumpAndSettle();

        // Verify cards and elements are rendered
        expect(find.text('Weight & Growth Analytics'), findsOneWidget);
        expect(find.text('Total Goats'), findsOneWidget);
        expect(find.text('1'), findsAtLeast(1)); // Buster Kid count
        expect(find.text('Buster Kid'), findsOneWidget);
        expect(find.text('38.5 lbs'), findsNWidgets(2));
      });
    });
  });
}
