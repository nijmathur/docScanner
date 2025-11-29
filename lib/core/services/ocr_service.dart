import 'dart:io';
import 'dart:typed_data';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// OCR result containing recognized text and metadata
class OCRResult {
  final String fullText;
  final List<TextBlock> blocks;
  final double? confidence;
  final Duration processingTime;

  const OCRResult({
    required this.fullText,
    required this.blocks,
    this.confidence,
    required this.processingTime,
  });
}

/// OCR Service using Google ML Kit Text Recognition (on-device)
///
/// Features:
/// - On-device OCR using Google ML Kit
/// - Support for multiple scripts/languages
/// - Text block, line, and word level recognition
/// - Confidence scores
/// - Asynchronous processing
class OCRService {
  late final TextRecognizer _textRecognizer;
  final TextRecognitionScript script;

  OCRService({
    this.script = TextRecognitionScript.latin,
  }) {
    _textRecognizer = TextRecognizer(script: script);
  }

  /// Perform OCR on an image file
  ///
  /// [imagePath] - Path to the image file
  /// Returns OCRResult with recognized text and metadata
  Future<OCRResult> recognizeText(String imagePath) async {
    final stopwatch = Stopwatch()..start();

    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final recognizedText = await _textRecognizer.processImage(inputImage);

      stopwatch.stop();

      // Calculate average confidence if available
      double? avgConfidence;
      int totalElements = 0;
      double totalConfidence = 0.0;

      for (final block in recognizedText.blocks) {
        for (final line in block.lines) {
          for (final element in line.elements) {
            // Note: ML Kit doesn't directly provide confidence scores
            // This is a placeholder for when/if they add it
            totalElements++;
          }
        }
      }

      if (totalElements > 0) {
        avgConfidence = totalConfidence / totalElements;
      }

      return OCRResult(
        fullText: recognizedText.text,
        blocks: recognizedText.blocks,
        confidence: avgConfidence,
        processingTime: stopwatch.elapsed,
      );
    } catch (e) {
      stopwatch.stop();
      throw Exception('OCR processing failed: $e');
    }
  }

  /// Perform OCR on image bytes
  ///
  /// [imageBytes] - Image data as bytes
  /// [filePath] - Temporary file path to write bytes
  Future<OCRResult> recognizeTextFromBytes(
    Uint8List imageBytes,
    String filePath,
  ) async {
    // Write bytes to temporary file
    final file = File(filePath);
    await file.writeAsBytes(imageBytes);

    try {
      return await recognizeText(filePath);
    } finally {
      // Clean up temporary file
      if (await file.exists()) {
        await file.delete();
      }
    }
  }

  /// Extract text blocks with their positions
  ///
  /// Useful for highlighting text on images
  List<Map<String, dynamic>> getTextBlocksWithPositions(OCRResult result) {
    final blocks = <Map<String, dynamic>>[];

    for (final block in result.blocks) {
      blocks.add({
        'text': block.text,
        'boundingBox': {
          'left': block.boundingBox.left,
          'top': block.boundingBox.top,
          'right': block.boundingBox.right,
          'bottom': block.boundingBox.bottom,
        },
        'cornerPoints': block.cornerPoints
            .map((p) => {'x': p.x, 'y': p.y})
            .toList(),
        'recognizedLanguages': block.recognizedLanguages,
      });
    }

    return blocks;
  }

  /// Extract only text content (normalized and concatenated)
  String extractPlainText(OCRResult result) {
    // Normalize: remove extra whitespace, trim lines
    final lines = result.fullText.split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();

    return lines.join('\n');
  }

  /// Search for specific patterns in OCR text (e.g., dates, amounts)
  Map<String, List<String>> extractPatterns(String text) {
    final patterns = <String, List<String>>{};

    // Extract dates (various formats)
    final datePattern = RegExp(
      r'\b\d{1,2}[-/]\d{1,2}[-/]\d{2,4}\b|\b\d{4}[-/]\d{1,2}[-/]\d{1,2}\b',
    );
    patterns['dates'] = datePattern
        .allMatches(text)
        .map((m) => m.group(0)!)
        .toList();

    // Extract amounts/currency
    final amountPattern = RegExp(
      r'[\$£€¥]\s*\d+(?:,\d{3})*(?:\.\d{2})?|\d+(?:,\d{3})*(?:\.\d{2})?\s*[\$£€¥]',
    );
    patterns['amounts'] = amountPattern
        .allMatches(text)
        .map((m) => m.group(0)!)
        .toList();

    // Extract emails
    final emailPattern = RegExp(
      r'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b',
    );
    patterns['emails'] = emailPattern
        .allMatches(text)
        .map((m) => m.group(0)!)
        .toList();

    // Extract phone numbers
    final phonePattern = RegExp(
      r'\b(?:\+\d{1,3}\s?)?(?:\(\d{3}\)|\d{3})[-.\s]?\d{3}[-.\s]?\d{4}\b',
    );
    patterns['phones'] = phonePattern
        .allMatches(text)
        .map((m) => m.group(0)!)
        .toList();

    return patterns;
  }

  /// Check if OCR result has sufficient quality
  bool hasGoodQuality(OCRResult result) {
    // Check if we have meaningful text
    if (result.fullText.trim().isEmpty) return false;

    // Check if text has minimum length
    if (result.fullText.trim().length < 10) return false;

    // Check confidence if available
    if (result.confidence != null && result.confidence! < 0.5) return false;

    // Check if processing took reasonable time (not too fast = likely empty)
    if (result.processingTime.inMilliseconds < 100) return false;

    return true;
  }

  /// Get suggested document type based on OCR content
  String suggestDocumentType(String text) {
    final lowerText = text.toLowerCase();

    if (lowerText.contains('invoice') ||
        lowerText.contains('bill to') ||
        lowerText.contains('total amount')) {
      return 'Invoice';
    } else if (lowerText.contains('receipt') ||
        lowerText.contains('payment') ||
        lowerText.contains('transaction')) {
      return 'Receipt';
    } else if (lowerText.contains('contract') ||
        lowerText.contains('agreement') ||
        lowerText.contains('terms and conditions')) {
      return 'Contract';
    } else if (lowerText.contains('medical') ||
        lowerText.contains('patient') ||
        lowerText.contains('prescription')) {
      return 'Medical';
    } else if (lowerText.contains('letter') ||
        lowerText.contains('dear') ||
        lowerText.contains('sincerely')) {
      return 'Letter';
    }

    return 'Other';
  }

  /// Dispose resources
  void dispose() {
    _textRecognizer.close();
  }
}
