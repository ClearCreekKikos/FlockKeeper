import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flockkeeper/app/app.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  GoogleFonts.config.allowRuntimeFetching = false;

  testWidgets('App load smoke test', (WidgetTester tester) async {
    // Run everything inside runAsync so all timers and SQLite queries execute on the real event loop
    await tester.runAsync(() async {
      // Build our app and trigger a frame.
      await tester.pumpWidget(
        const ProviderScope(
          child: FlockKeeperApp(),
        ),
      );

      // Wait for 3-second splash timer
      await Future.delayed(const Duration(seconds: 3));
      await tester.pump();

      // Wait for DB settings queries to complete
      await Future.delayed(const Duration(seconds: 1));
      await tester.pump();

      // Wait for route transition animation
      await Future.delayed(const Duration(milliseconds: 600));
      await tester.pump();
    });

    // Verify that the search text field on AnimalListScreen now exists.
    expect(find.byType(TextField), findsOneWidget);
  });
}
