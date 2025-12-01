import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';
import 'package:doc_scanner/features/settings/screens/settings_screen.dart';
import 'package:doc_scanner/core/services/auth_service.dart';
import 'package:doc_scanner/core/services/database_service.dart';
import 'package:doc_scanner/core/services/session_service.dart';
import 'package:doc_scanner/core/services/encryption_service.dart';

import '../../../core/services/backup_service_test.mocks.dart';

void main() {
  group('SettingsScreen', () {
    late MockDatabaseService mockDatabaseService;
    late AuthService authService;
    late SessionService sessionService;

    setUp(() {
      mockDatabaseService = MockDatabaseService();
      // Create real AuthService for testing (no mocking needed for UI tests)
      authService = AuthService(encryptionService: EncryptionService());
      sessionService = SessionService();
    });

    Widget createSettingsScreen() {
      return MultiProvider(
        providers: [
          Provider<AuthService>.value(value: authService),
          Provider<DatabaseService>.value(value: mockDatabaseService),
          ChangeNotifierProvider<SessionService>.value(value: sessionService),
        ],
        child: const MaterialApp(
          home: SettingsScreen(),
        ),
      );
    }

    testWidgets('should display settings UI', (WidgetTester tester) async {
      when(mockDatabaseService.getDocumentCount()).thenAnswer((_) async => 42);

      await tester.pumpWidget(createSettingsScreen());
      await tester.pumpAndSettle();

      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('Statistics'), findsOneWidget);
      expect(find.text('Storage'), findsOneWidget);
      expect(find.text('Security'), findsOneWidget);
      expect(find.text('About'), findsOneWidget);
    });

    testWidgets('should display document count', (WidgetTester tester) async {
      when(mockDatabaseService.getDocumentCount()).thenAnswer((_) async => 42);

      await tester.pumpWidget(createSettingsScreen());
      await tester.pumpAndSettle();

      expect(find.text('Total Documents'), findsOneWidget);
      expect(find.text('42'), findsOneWidget);
    });

    testWidgets('should show loading indicator initially', (WidgetTester tester) async {
      when(mockDatabaseService.getDocumentCount()).thenAnswer(
        (_) async => Future.delayed(const Duration(seconds: 1), () => 10),
      );

      await tester.pumpWidget(createSettingsScreen());

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('should display logout button', (WidgetTester tester) async {
      when(mockDatabaseService.getDocumentCount()).thenAnswer((_) async => 10);

      await tester.pumpWidget(createSettingsScreen());
      await tester.pumpAndSettle();

      expect(find.widgetWithText(ElevatedButton, 'Logout'), findsOneWidget);
      expect(find.byIcon(Icons.logout), findsOneWidget);
    });

    testWidgets('should show logout confirmation dialog', (WidgetTester tester) async {
      when(mockDatabaseService.getDocumentCount()).thenAnswer((_) async => 10);

      await tester.pumpWidget(createSettingsScreen());
      await tester.pumpAndSettle();

      // Tap logout button
      await tester.tap(find.widgetWithText(ElevatedButton, 'Logout'));
      await tester.pumpAndSettle();

      // Should show confirmation dialog
      expect(find.text('Logout'), findsAtLeastNWidgets(1));
      expect(find.text('Are you sure you want to logout?'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    });

    testWidgets('should cancel logout when cancel is tapped', (WidgetTester tester) async {
      when(mockDatabaseService.getDocumentCount()).thenAnswer((_) async => 10);

      await tester.pumpWidget(createSettingsScreen());
      await tester.pumpAndSettle();

      // Tap logout button
      await tester.tap(find.widgetWithText(ElevatedButton, 'Logout'));
      await tester.pumpAndSettle();

      // Tap cancel
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // Should still be on settings screen
      expect(find.text('Settings'), findsOneWidget);
    });

    testWidgets('should have database optimization option', (WidgetTester tester) async {
      when(mockDatabaseService.getDocumentCount()).thenAnswer((_) async => 10);

      await tester.pumpWidget(createSettingsScreen());
      await tester.pumpAndSettle();

      expect(find.text('Optimize Database'), findsOneWidget);
      expect(find.text('Compact and optimize storage'), findsOneWidget);
    });

    testWidgets('should have backup and restore options', (WidgetTester tester) async {
      when(mockDatabaseService.getDocumentCount()).thenAnswer((_) async => 10);

      await tester.pumpWidget(createSettingsScreen());
      await tester.pumpAndSettle();

      expect(find.text('Backup'), findsOneWidget);
      expect(find.text('Restore'), findsOneWidget);
    });

    testWidgets('should have security options', (WidgetTester tester) async {
      when(mockDatabaseService.getDocumentCount()).thenAnswer((_) async => 10);

      await tester.pumpWidget(createSettingsScreen());
      await tester.pumpAndSettle();

      expect(find.text('Change PIN'), findsOneWidget);
      expect(find.text('Biometric Authentication'), findsOneWidget);
      expect(find.text('Audit Log'), findsOneWidget);
    });

    testWidgets('should display version information', (WidgetTester tester) async {
      when(mockDatabaseService.getDocumentCount()).thenAnswer((_) async => 10);

      await tester.pumpWidget(createSettingsScreen());
      await tester.pumpAndSettle();

      expect(find.text('Version'), findsOneWidget);
      expect(find.text('1.0.0'), findsOneWidget);
    });

    testWidgets('should have privacy policy and terms links', (WidgetTester tester) async {
      when(mockDatabaseService.getDocumentCount()).thenAnswer((_) async => 10);

      await tester.pumpWidget(createSettingsScreen());
      await tester.pumpAndSettle();

      expect(find.text('Privacy Policy'), findsOneWidget);
      expect(find.text('Terms of Service'), findsOneWidget);
    });

    testWidgets('should call optimize when database optimization is tapped', (WidgetTester tester) async {
      when(mockDatabaseService.getDocumentCount()).thenAnswer((_) async => 10);
      when(mockDatabaseService.optimize()).thenAnswer((_) async => Future.value());

      await tester.pumpWidget(createSettingsScreen());
      await tester.pumpAndSettle();

      // Tap optimize database
      await tester.tap(find.text('Optimize Database'));
      await tester.pump();

      // Should show loading dialog
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.pumpAndSettle();

      // Should call optimize
      verify(mockDatabaseService.optimize()).called(1);
    });
  });
}
