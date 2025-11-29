import 'package:flutter_test/flutter_test.dart';
import 'package:doc_scanner/core/services/ocr_service.dart';

void main() {
  // Initialize Flutter binding for platform channel tests
  TestWidgetsFlutterBinding.ensureInitialized();

  group('OCRService', () {
    late OCRService ocrService;

    setUp(() {
      ocrService = OCRService();
    });

    tearDown(() {
      // Don't dispose in tests as it requires platform channels
      // ocrService.dispose();
    });

    group('Pattern Extraction', () {
      test('extractPatterns finds dates in various formats', () {
        final text = '''
          Invoice Date: 2024-01-15
          Due Date: 01/20/2024
          Payment Date: 12-31-2023
        ''';

        final patterns = ocrService.extractPatterns(text);

        expect(patterns['dates'], isNotNull);
        expect(patterns['dates']!.length, greaterThanOrEqualTo(3));
        expect(patterns['dates'], contains('2024-01-15'));
        expect(patterns['dates'], contains('01/20/2024'));
      });

      test('extractPatterns finds currency amounts', () {
        final text = '''
          Subtotal: \$1,234.56
          Tax: \$123.45
          Total: £2,000.00
          Amount Due: €500.50
        ''';

        final patterns = ocrService.extractPatterns(text);

        expect(patterns['amounts'], isNotNull);
        expect(patterns['amounts']!.length, greaterThanOrEqualTo(4));
        expect(patterns['amounts']!.any((a) => a.contains('1,234.56')), isTrue);
      });

      test('extractPatterns finds email addresses', () {
        final text = '''
          Contact: john.doe@example.com
          Support: support@company.org
          Sales: sales@business.co.uk
        ''';

        final patterns = ocrService.extractPatterns(text);

        expect(patterns['emails'], isNotNull);
        expect(patterns['emails']!.length, equals(3));
        expect(patterns['emails'], contains('john.doe@example.com'));
        expect(patterns['emails'], contains('support@company.org'));
      });

      test('extractPatterns finds phone numbers', () {
        final text = '''
          Phone: (555) 123-4567
          Mobile: 555-987-6543
          Intl: +1 555 111 2222
        ''';

        final patterns = ocrService.extractPatterns(text);

        expect(patterns['phones'], isNotNull);
        expect(patterns['phones']!.length, greaterThanOrEqualTo(2));
      });

      test('extractPatterns handles empty text', () {
        final patterns = ocrService.extractPatterns('');

        expect(patterns['dates'], isEmpty);
        expect(patterns['amounts'], isEmpty);
        expect(patterns['emails'], isEmpty);
        expect(patterns['phones'], isEmpty);
      });

      test('extractPatterns handles text with no patterns', () {
        final text = 'This is just plain text without any special patterns';
        final patterns = ocrService.extractPatterns(text);

        expect(patterns['dates'], isEmpty);
        expect(patterns['amounts'], isEmpty);
        expect(patterns['emails'], isEmpty);
        expect(patterns['phones'], isEmpty);
      });
    });

    group('Plain Text Extraction', () {
      test('extractPlainText normalizes whitespace', () {
        final mockResult = OCRResult(
          fullText: 'Line 1\n\n\nLine 2\n   Line 3   ',
          blocks: [],
          processingTime: const Duration(seconds: 1),
        );

        final plainText = ocrService.extractPlainText(mockResult);

        expect(plainText, equals('Line 1\nLine 2\nLine 3'));
      });

      test('extractPlainText removes empty lines', () {
        final mockResult = OCRResult(
          fullText: 'Line 1\n\nLine 2\n\n\nLine 3',
          blocks: [],
          processingTime: const Duration(seconds: 1),
        );

        final plainText = ocrService.extractPlainText(mockResult);
        final lines = plainText.split('\n');

        expect(lines.every((line) => line.isNotEmpty), isTrue);
      });

      test('extractPlainText trims each line', () {
        final mockResult = OCRResult(
          fullText: '  Line 1  \n  Line 2  ',
          blocks: [],
          processingTime: const Duration(seconds: 1),
        );

        final plainText = ocrService.extractPlainText(mockResult);
        final lines = plainText.split('\n');

        expect(lines[0], equals('Line 1'));
        expect(lines[1], equals('Line 2'));
      });
    });

    group('Document Type Suggestion', () {
      test('suggestDocumentType identifies invoices', () {
        final text = 'INVOICE\nBill To: John Doe\nTotal Amount: \$500';
        final type = ocrService.suggestDocumentType(text);
        expect(type, equals('Invoice'));
      });

      test('suggestDocumentType identifies receipts', () {
        final text = 'RECEIPT\nPayment received\nTransaction ID: 12345';
        final type = ocrService.suggestDocumentType(text);
        expect(type, equals('Receipt'));
      });

      test('suggestDocumentType identifies contracts', () {
        final text = 'CONTRACT AGREEMENT\nTerms and Conditions\nThis agreement is made...';
        final type = ocrService.suggestDocumentType(text);
        expect(type, equals('Contract'));
      });

      test('suggestDocumentType identifies medical documents', () {
        final text = 'MEDICAL RECORDS\nPatient Name: John Doe\nPrescription: ...';
        final type = ocrService.suggestDocumentType(text);
        expect(type, equals('Medical'));
      });

      test('suggestDocumentType identifies letters', () {
        final text = 'Dear Sir/Madam,\n\nI am writing to...\n\nSincerely,\nJohn Doe';
        final type = ocrService.suggestDocumentType(text);
        expect(type, equals('Letter'));
      });

      test('suggestDocumentType returns Other for unknown types', () {
        final text = 'Random text that does not match any known document type';
        final type = ocrService.suggestDocumentType(text);
        expect(type, equals('Other'));
      });

      test('suggestDocumentType is case insensitive', () {
        final text1 = 'invoice for services';
        final text2 = 'INVOICE FOR SERVICES';

        expect(ocrService.suggestDocumentType(text1), equals('Invoice'));
        expect(ocrService.suggestDocumentType(text2), equals('Invoice'));
      });
    });

    group('Quality Assessment', () {
      test('hasGoodQuality returns true for valid results', () {
        final result = OCRResult(
          fullText: 'This is a valid OCR result with sufficient text content',
          blocks: [],
          confidence: 0.9,
          processingTime: const Duration(milliseconds: 500),
        );

        expect(ocrService.hasGoodQuality(result), isTrue);
      });

      test('hasGoodQuality returns false for empty text', () {
        final result = OCRResult(
          fullText: '',
          blocks: [],
          processingTime: const Duration(milliseconds: 500),
        );

        expect(ocrService.hasGoodQuality(result), isFalse);
      });

      test('hasGoodQuality returns false for too short text', () {
        final result = OCRResult(
          fullText: 'Short',
          blocks: [],
          processingTime: const Duration(milliseconds: 500),
        );

        expect(ocrService.hasGoodQuality(result), isFalse);
      });

      test('hasGoodQuality returns false for low confidence', () {
        final result = OCRResult(
          fullText: 'This is a longer text but with low confidence',
          blocks: [],
          confidence: 0.3,
          processingTime: const Duration(milliseconds: 500),
        );

        expect(ocrService.hasGoodQuality(result), isFalse);
      });

      test('hasGoodQuality returns false for suspiciously fast processing', () {
        final result = OCRResult(
          fullText: 'Valid text content',
          blocks: [],
          processingTime: const Duration(milliseconds: 50),
        );

        expect(ocrService.hasGoodQuality(result), isFalse);
      });
    });

    group('Text Block Position Extraction', () {
      test('getTextBlocksWithPositions returns empty for empty result', () {
        final result = OCRResult(
          fullText: '',
          blocks: [],
          processingTime: const Duration(seconds: 1),
        );

        final blocks = ocrService.getTextBlocksWithPositions(result);
        expect(blocks, isEmpty);
      });
    });

    group('Pattern Detection Edge Cases', () {
      test('extractPatterns handles dates at text boundaries', () {
        final text = '2024-01-15';
        final patterns = ocrService.extractPatterns(text);
        expect(patterns['dates'], contains('2024-01-15'));
      });

      test('extractPatterns handles amounts with spaces', () {
        final text = '\$ 1,234.56';
        final patterns = ocrService.extractPatterns(text);
        expect(patterns['amounts'], isNotEmpty);
      });

      test('extractPatterns handles multiple emails on same line', () {
        final text = 'Contact: sales@example.com or support@example.com';
        final patterns = ocrService.extractPatterns(text);
        expect(patterns['emails']!.length, equals(2));
      });

      test('extractPatterns does not extract invalid emails', () {
        final text = 'This is not an email: @invalid or missing@';
        final patterns = ocrService.extractPatterns(text);
        expect(patterns['emails'], isEmpty);
      });
    });

    group('Document Type Priority', () {
      test('suggestDocumentType prioritizes invoice over receipt', () {
        final text = 'INVOICE\nReceipt attached\nTotal: \$100';
        final type = ocrService.suggestDocumentType(text);
        expect(type, equals('Invoice'));
      });

      test('suggestDocumentType detects contract keywords', () {
        final texts = [
          'This agreement is made between...',
          'Terms and conditions apply',
          'Contract for services',
        ];

        for (final text in texts) {
          expect(ocrService.suggestDocumentType(text), equals('Contract'));
        }
      });
    });
  });
}
