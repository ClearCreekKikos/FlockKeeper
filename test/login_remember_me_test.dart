import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flockkeeper/data/database/database_helper.dart';
import 'package:flockkeeper/features/auth/screens/login_screen.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  GoogleFonts.config.allowRuntimeFetching = false;

  group('Login Screen Remember Me & Show Password Widget Tests', () {
    late DatabaseHelper db;

    setUp(() async {
      db = DatabaseHelper();
      // Ensure clean test database state
      await db.clearAllData();
    });

    testWidgets('Loads prefilled email when remember me is checked and email is saved', (WidgetTester tester) async {
      await tester.runAsync(() async {
        // 1. Pre-configure remember me and saved email settings
        await db.setSetting('sync_remember_me', 'true');
        await db.setSetting('sync_email', 'testgoat@ranch.com');

        // 2. Build the Login screen inside a material app
        await tester.pumpWidget(
          const ProviderScope(
            child: MaterialApp(
              home: LoginScreen(),
            ),
          ),
        );

        // Wait for async initState loading of database settings to run
        await Future.delayed(const Duration(milliseconds: 200));
        await tester.pump();

        // 3. Verify that the email text field is prefilled with saved credentials
        final emailFieldFinder = find.widgetWithText(TextFormField, 'Email Address');
        expect(emailFieldFinder, findsOneWidget);
        
        final emailField = tester.widget<TextFormField>(emailFieldFinder);
        expect(emailField.controller?.text, equals('testgoat@ranch.com'));

        // 4. Verify Remember Me checkbox state
        final checkboxFinder = find.byType(Checkbox);
        expect(checkboxFinder, findsOneWidget);
        final checkbox = tester.widget<Checkbox>(checkboxFinder);
        expect(checkbox.value, isTrue);
      });
    });

    testWidgets('Toggles obscure password visibility on clicking the visibility icon', (WidgetTester tester) async {
      await tester.runAsync(() async {
        await tester.pumpWidget(
          const ProviderScope(
            child: MaterialApp(
              home: LoginScreen(),
            ),
          ),
        );
        await tester.pump();

        // Find password field
        final passwordFieldFinder = find.widgetWithText(TextFormField, 'Password');
        expect(passwordFieldFinder, findsOneWidget);
        
        // Verify password field is obscured by default
        final textFieldFinder = find.descendant(
          of: passwordFieldFinder,
          matching: find.byType(TextField),
        );
        expect(textFieldFinder, findsOneWidget);
        var textField = tester.widget<TextField>(textFieldFinder);
        expect(textField.obscureText, isTrue);

        // Find the visibility suffix icon button and tap it
        final visibilityButtonFinder = find.descendant(
          of: passwordFieldFinder,
          matching: find.byType(IconButton),
        );
        expect(visibilityButtonFinder, findsOneWidget);

        await tester.tap(visibilityButtonFinder);
        await tester.pump();

        // Verify password field is now visible/not obscured
        textField = tester.widget<TextField>(textFieldFinder);
        expect(textField.obscureText, isFalse);

        // Tap again to obscure
        await tester.tap(visibilityButtonFinder);
        await tester.pump();

        textField = tester.widget<TextField>(textFieldFinder);
        expect(textField.obscureText, isTrue);
      });
    });
  });
}
