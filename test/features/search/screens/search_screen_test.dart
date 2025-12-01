import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';
import 'package:doc_scanner/features/search/screens/search_screen.dart';
import 'package:doc_scanner/core/services/database_service.dart';
import 'package:doc_scanner/core/domain/entities/document.dart';

import '../../../core/services/backup_service_test.mocks.dart';

void main() {
  group('SearchScreen', () {
    late MockDatabaseService mockDatabaseService;

    setUp(() {
      mockDatabaseService = MockDatabaseService();
    });

    Widget createSearchScreen() {
      return MultiProvider(
        providers: [
          Provider<DatabaseService>.value(value: mockDatabaseService),
        ],
        child: const MaterialApp(
          home: SearchScreen(),
        ),
      );
    }

    final testDocuments = [
      Document(
        id: 'doc1',
        title: 'Invoice 2025-01',
        description: 'January invoice',
        documentType: 'Invoice',
        tags: ['finance', '2025'],
        captureDate: DateTime(2025, 1, 15),
        createdAt: DateTime(2025, 1, 15),
        ocrText: 'Total amount: \$1000',
        checksum: 'abc123',
        fileSizeBytes: 500000,
        encryptedImagePath: '/path/to/doc1',
        encryptedThumbnailPath: '/path/to/thumb1',
      ),
      Document(
        id: 'doc2',
        title: 'Receipt Walmart',
        description: 'Grocery receipt',
        documentType: 'Receipt',
        tags: ['shopping'],
        captureDate: DateTime(2025, 1, 20),
        createdAt: DateTime(2025, 1, 20),
        ocrText: 'Walmart Supercenter - Total: \$45.67',
        checksum: 'def456',
        fileSizeBytes: 300000,
        encryptedImagePath: '/path/to/doc2',
        encryptedThumbnailPath: '/path/to/thumb2',
      ),
    ];

    testWidgets('should display search UI', (WidgetTester tester) async {
      await tester.pumpWidget(createSearchScreen());

      expect(find.text('Search Documents'), findsOneWidget);
      expect(find.byIcon(Icons.search), findsAtLeastNWidgets(1));
      expect(find.text('Search documents...'), findsOneWidget);
    });

    testWidgets('should display initial empty state', (WidgetTester tester) async {
      await tester.pumpWidget(createSearchScreen());

      expect(find.text('Search your documents'), findsOneWidget);
      expect(find.text('Search by title, type, tags, or OCR text'), findsOneWidget);
    });

    testWidgets('should perform search when text is entered', (WidgetTester tester) async {
      when(mockDatabaseService.searchDocuments(query: 'invoice', limit: 50))
          .thenAnswer((_) async => [testDocuments[0]]);

      await tester.pumpWidget(createSearchScreen());

      // Enter search text
      await tester.enterText(find.byType(TextField), 'invoice');
      await tester.pumpAndSettle();

      // Should call search method
      verify(mockDatabaseService.searchDocuments(query: 'invoice', limit: 50)).called(1);
    });

    testWidgets('should display search results', (WidgetTester tester) async {
      when(mockDatabaseService.searchDocuments(query: 'invoice', limit: 50))
          .thenAnswer((_) async => [testDocuments[0]]);

      await tester.pumpWidget(createSearchScreen());

      await tester.enterText(find.byType(TextField), 'invoice');
      await tester.pumpAndSettle();

      expect(find.text('Invoice 2025-01'), findsOneWidget);
      expect(find.text('Invoice'), findsOneWidget);
    });

    testWidgets('should display OCR snippet in results', (WidgetTester tester) async {
      when(mockDatabaseService.searchDocuments(query: 'walmart', limit: 50))
          .thenAnswer((_) async => [testDocuments[1]]);

      await tester.pumpWidget(createSearchScreen());

      await tester.enterText(find.byType(TextField), 'walmart');
      await tester.pumpAndSettle();

      expect(find.text('Walmart Supercenter - Total: \$45.67'), findsOneWidget);
    });

    testWidgets('should show no results message when search returns empty', (WidgetTester tester) async {
      when(mockDatabaseService.searchDocuments(query: 'nonexistent', limit: 50))
          .thenAnswer((_) async => []);

      await tester.pumpWidget(createSearchScreen());

      await tester.enterText(find.byType(TextField), 'nonexistent');
      await tester.pumpAndSettle();

      expect(find.text('No results found'), findsOneWidget);
      expect(find.text('Try different keywords'), findsOneWidget);
    });

    testWidgets('should show clear button when text is entered', (WidgetTester tester) async {
      when(mockDatabaseService.searchDocuments(query: 'test', limit: 50))
          .thenAnswer((_) async => []);

      await tester.pumpWidget(createSearchScreen());

      // Initially no clear button
      expect(find.byIcon(Icons.clear), findsNothing);

      // Enter text
      await tester.enterText(find.byType(TextField), 'test');
      await tester.pumpAndSettle();

      // Clear button should appear
      expect(find.byIcon(Icons.clear), findsOneWidget);
    });

    testWidgets('should clear search when clear button is tapped', (WidgetTester tester) async {
      when(mockDatabaseService.searchDocuments(query: 'test', limit: 50))
          .thenAnswer((_) async => testDocuments);

      await tester.pumpWidget(createSearchScreen());

      // Enter text
      await tester.enterText(find.byType(TextField), 'test');
      await tester.pumpAndSettle();

      // Tap clear button
      await tester.tap(find.byIcon(Icons.clear));
      await tester.pumpAndSettle();

      // Should return to initial state
      expect(find.text('Search your documents'), findsOneWidget);
    });

    testWidgets('should have autofocus on search field', (WidgetTester tester) async {
      await tester.pumpWidget(createSearchScreen());

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.autofocus, isTrue);
    });

    testWidgets('should show loading indicator while searching', (WidgetTester tester) async {
      when(mockDatabaseService.searchDocuments(query: 'slow', limit: 50))
          .thenAnswer((_) async => Future.delayed(const Duration(milliseconds: 100), () => []));

      await tester.pumpWidget(createSearchScreen());

      await tester.enterText(find.byType(TextField), 'slow');
      await tester.pump();

      // Should show loading indicator
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });
}
