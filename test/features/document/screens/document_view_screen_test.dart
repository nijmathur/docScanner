import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';
import 'package:doc_scanner/features/document/screens/document_view_screen.dart';
import 'package:doc_scanner/core/services/database_service.dart';
import 'package:doc_scanner/core/services/audit_service.dart';
import 'package:doc_scanner/core/domain/entities/document.dart';

import '../../../core/services/backup_service_test.mocks.dart';

void main() {
  group('DocumentViewScreen', () {
    late MockDatabaseService mockDatabaseService;
    late MockAuditService mockAuditService;

    setUp(() {
      mockDatabaseService = MockDatabaseService();
      mockAuditService = MockAuditService();
    });

    Widget createDocumentViewScreen(String documentId) {
      return MultiProvider(
        providers: [
          Provider<DatabaseService>.value(value: mockDatabaseService),
          Provider<AuditService>.value(value: mockAuditService),
        ],
        child: MaterialApp(
          home: DocumentViewScreen(documentId: documentId),
        ),
      );
    }

    final testDocument = Document(
      id: 'test-id',
      title: 'Test Document',
      description: 'Test description',
      documentType: 'General',
      tags: ['tag1', 'tag2'],
      captureDate: DateTime(2025, 1, 1),
      createdAt: DateTime(2025, 1, 1),
      updatedAt: DateTime(2025, 1, 2),
      ocrText: 'This is some OCR text from the document',
      checksum: 'abc123',
      fileSizeBytes: 1024000,
      encryptedImagePath: '/path/to/encrypted/image',
      encryptedThumbnailPath: '/path/to/encrypted/thumbnail',
    );

    testWidgets('should show loading indicator initially', (WidgetTester tester) async {
      when(mockDatabaseService.getDocument(any)).thenAnswer(
        (_) async => Future.delayed(const Duration(seconds: 1), () => testDocument),
      );
      when(mockAuditService.logDocumentViewed(documentId: anyNamed('documentId')))
          .thenAnswer((_) async => Future.value());

      await tester.pumpWidget(createDocumentViewScreen('test-id'));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('should display document details', (WidgetTester tester) async {
      when(mockDatabaseService.getDocument('test-id')).thenAnswer((_) async => testDocument);
      when(mockAuditService.logDocumentViewed(documentId: anyNamed('documentId')))
          .thenAnswer((_) async => Future.value());

      await tester.pumpWidget(createDocumentViewScreen('test-id'));
      await tester.pumpAndSettle();

      expect(find.text('Test Document'), findsOneWidget);
      expect(find.text('General'), findsOneWidget);
      expect(find.text('1000.0 KB'), findsOneWidget);
    });

    testWidgets('should display tags', (WidgetTester tester) async {
      when(mockDatabaseService.getDocument('test-id')).thenAnswer((_) async => testDocument);
      when(mockAuditService.logDocumentViewed(documentId: anyNamed('documentId')))
          .thenAnswer((_) async => Future.value());

      await tester.pumpWidget(createDocumentViewScreen('test-id'));
      await tester.pumpAndSettle();

      expect(find.text('tag1'), findsOneWidget);
      expect(find.text('tag2'), findsOneWidget);
    });

    testWidgets('should show OCR text when expanded', (WidgetTester tester) async {
      when(mockDatabaseService.getDocument('test-id')).thenAnswer((_) async => testDocument);
      when(mockAuditService.logDocumentViewed(documentId: anyNamed('documentId')))
          .thenAnswer((_) async => Future.value());

      await tester.pumpWidget(createDocumentViewScreen('test-id'));
      await tester.pumpAndSettle();

      // Initially OCR text should not be visible
      expect(find.text('This is some OCR text from the document'), findsNothing);

      // Tap to expand OCR section
      await tester.tap(find.byIcon(Icons.expand_more));
      await tester.pumpAndSettle();

      // Now OCR text should be visible
      expect(find.text('This is some OCR text from the document'), findsOneWidget);
    });

    testWidgets('should have delete button in app bar', (WidgetTester tester) async {
      when(mockDatabaseService.getDocument('test-id')).thenAnswer((_) async => testDocument);
      when(mockAuditService.logDocumentViewed(documentId: anyNamed('documentId')))
          .thenAnswer((_) async => Future.value());

      await tester.pumpWidget(createDocumentViewScreen('test-id'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.delete), findsOneWidget);
      expect(find.byIcon(Icons.edit), findsOneWidget);
      expect(find.byIcon(Icons.share), findsOneWidget);
    });

    testWidgets('should show confirmation dialog on delete', (WidgetTester tester) async {
      when(mockDatabaseService.getDocument('test-id')).thenAnswer((_) async => testDocument);
      when(mockAuditService.logDocumentViewed(documentId: anyNamed('documentId')))
          .thenAnswer((_) async => Future.value());

      await tester.pumpWidget(createDocumentViewScreen('test-id'));
      await tester.pumpAndSettle();

      // Tap delete button
      await tester.tap(find.byIcon(Icons.delete));
      await tester.pumpAndSettle();

      // Should show confirmation dialog
      expect(find.text('Delete Document'), findsOneWidget);
      expect(find.text('Are you sure you want to delete this document?'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
    });

    testWidgets('should show "Document not found" when document is null', (WidgetTester tester) async {
      when(mockDatabaseService.getDocument('test-id')).thenAnswer((_) async => null);

      await tester.pumpWidget(createDocumentViewScreen('test-id'));
      await tester.pumpAndSettle();

      expect(find.text('Document not found'), findsOneWidget);
    });

    testWidgets('should log document viewed event', (WidgetTester tester) async {
      when(mockDatabaseService.getDocument('test-id')).thenAnswer((_) async => testDocument);
      when(mockAuditService.logDocumentViewed(documentId: anyNamed('documentId')))
          .thenAnswer((_) async => Future.value());

      await tester.pumpWidget(createDocumentViewScreen('test-id'));
      await tester.pumpAndSettle();

      verify(mockAuditService.logDocumentViewed(documentId: 'test-id')).called(1);
    });
  });
}
