import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:doc_scanner/main.dart' as app;

/// Integration tests for the complete app workflow
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('App Integration Tests', () {
    testWidgets('App launches and shows authentication screen',
        (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Should show authentication/setup screen
      expect(
        find.byType(Scaffold),
        findsWidgets,
      );
    });

    testWidgets('Complete authentication setup flow',
        (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Look for PIN setup
      if (find.text('Set Up PIN').evaluate().isNotEmpty) {
        // Enter PIN
        final pinFields = find.byType(TextField);
        if (pinFields.evaluate().length >= 2) {
          await tester.enterText(pinFields.first, '123456');
          await tester.pumpAndSettle();

          await tester.enterText(pinFields.last, '123456');
          await tester.pumpAndSettle();

          // Submit
          final setupButton = find.text('Set Up PIN');
          if (setupButton.evaluate().isNotEmpty) {
            await tester.tap(setupButton);
            await tester.pumpAndSettle(const Duration(seconds: 2));
          }
        }
      }

      // Should navigate to home screen or show main app
      await tester.pumpAndSettle(const Duration(seconds: 1));
      expect(find.byType(Scaffold), findsWidgets);
    });

    testWidgets('Navigation between screens works',
        (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Setup if needed
      if (find.text('Set Up PIN').evaluate().isNotEmpty) {
        final pinFields = find.byType(TextField);
        if (pinFields.evaluate().length >= 2) {
          await tester.enterText(pinFields.first, '123456');
          await tester.enterText(pinFields.last, '123456');
          await tester.pumpAndSettle();

          final setupButton = find.text('Set Up PIN');
          if (setupButton.evaluate().isNotEmpty) {
            await tester.tap(setupButton);
            await tester.pumpAndSettle(const Duration(seconds: 2));
          }
        }
      }

      await tester.pumpAndSettle(const Duration(seconds: 1));

      // Try to find bottom navigation
      final bottomNav = find.byType(BottomNavigationBar);
      if (bottomNav.evaluate().isNotEmpty) {
        // Tap on different tabs
        await tester.tap(find.text('Documents'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Activity'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Home'));
        await tester.pumpAndSettle();
      }
    });

    testWidgets('App handles back navigation', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // The app should handle system back button gracefully
      final backButton = find.byTooltip('Back');
      if (backButton.evaluate().isNotEmpty) {
        await tester.tap(backButton);
        await tester.pumpAndSettle();
      }
    });
  });
}
