import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';
import 'package:doc_scanner/features/camera/screens/camera_screen.dart';
import 'package:doc_scanner/core/services/database_service.dart';
import 'package:doc_scanner/core/services/encryption_service.dart';
import 'package:doc_scanner/core/services/audit_service.dart';
import 'package:doc_scanner/core/services/session_service.dart';

import '../../../core/services/backup_service_test.mocks.dart';

void main() {
  group('CameraScreen', () {
    late MockDatabaseService mockDatabaseService;
    late MockAuditService mockAuditService;
    late EncryptionService encryptionService;
    late SessionService sessionService;

    setUp(() {
      mockDatabaseService = MockDatabaseService();
      mockAuditService = MockAuditService();
      encryptionService = EncryptionService();
      sessionService = SessionService();

      // Set up a valid DEK in the session
      final dek = Uint8List.fromList(List.generate(32, (i) => i));
      sessionService.setDataEncryptionKey(dek);
    });

    tearDown(() {
      sessionService.dispose();
    });

    Widget createCameraScreen() {
      return MultiProvider(
        providers: [
          Provider<DatabaseService>.value(value: mockDatabaseService),
          Provider<EncryptionService>.value(value: encryptionService),
          Provider<AuditService>.value(value: mockAuditService),
          ChangeNotifierProvider<SessionService>.value(value: sessionService),
        ],
        child: const MaterialApp(
          home: CameraScreen(),
        ),
      );
    }

    testWidgets('should display camera scan UI', (WidgetTester tester) async {
      await tester.pumpWidget(createCameraScreen());

      expect(find.text('Scan Document'), findsOneWidget);
      expect(find.byIcon(Icons.document_scanner), findsOneWidget);
      expect(find.text('Tap the button to scan'), findsOneWidget);
      expect(find.text('Position the document in the frame'), findsOneWidget);
      expect(find.text('Start Scan'), findsOneWidget);
    });

    testWidgets('should display start scan button', (WidgetTester tester) async {
      await tester.pumpWidget(createCameraScreen());

      final scanButton = find.widgetWithText(ElevatedButton, 'Start Scan');
      expect(scanButton, findsOneWidget);

      // Verify button has camera icon
      expect(find.byIcon(Icons.camera_alt), findsOneWidget);
    });

    testWidgets('should have correct app bar title', (WidgetTester tester) async {
      await tester.pumpWidget(createCameraScreen());

      final appBar = find.byType(AppBar);
      expect(appBar, findsOneWidget);

      expect(find.text('Scan Document'), findsOneWidget);
    });
  });
}
