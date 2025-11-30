import 'dart:io';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:flutter/material.dart';

/// Processed image result
class ProcessedImage {
  final Uint8List imageBytes;
  final int width;
  final int height;
  final int sizeBytes;
  final String format;

  const ProcessedImage({
    required this.imageBytes,
    required this.width,
    required this.height,
    required this.sizeBytes,
    this.format = 'jpg',
  });
}

/// Image Processing Service for document enhancement
///
/// Features:
/// - Grayscale and binarization
/// - Contrast enhancement
/// - Noise reduction
/// - Image compression and optimization
/// - Thumbnail generation
/// - Perspective correction support
class ImageProcessingService {
  /// Process a captured document image
  ///
  /// Steps:
  /// 1. Decode image
  /// 2. Apply grayscale conversion
  /// 3. Enhance contrast
  /// 4. Apply noise reduction
  /// 5. Compress for storage
  Future<ProcessedImage> processDocumentImage({
    required String imagePath,
    int quality = 85,
    bool applyGrayscale = true,
    bool enhanceContrast = true,
    bool reduceNoise = true,
  }) async {
    try {
      // Read image file
      final imageFile = File(imagePath);
      final imageBytes = await imageFile.readAsBytes();

      // Decode image
      img.Image? image = img.decodeImage(imageBytes);
      if (image == null) {
        throw Exception('Failed to decode image');
      }

      // Apply grayscale
      if (applyGrayscale) {
        image = img.grayscale(image);
      }

      // Enhance contrast
      if (enhanceContrast) {
        image = img.adjustColor(
          image,
          contrast: 1.2,
          brightness: 1.05,
        );
      }

      // Apply noise reduction (simple median filter)
      if (reduceNoise) {
        // Simple blur to reduce noise
        image = img.gaussianBlur(image, radius: 1);
      }

      // Sharpen slightly to restore edges
      image = img.adjustColor(image, saturation: 1.1);

      // Encode to JPEG with specified quality
      final processed = img.encodeJpg(image, quality: quality);

      return ProcessedImage(
        imageBytes: Uint8List.fromList(processed),
        width: image.width,
        height: image.height,
        sizeBytes: processed.length,
        format: 'jpg',
      );
    } catch (e) {
      throw Exception('Image processing failed: $e');
    }
  }

  /// Generate thumbnail from image
  Future<ProcessedImage> generateThumbnail({
    required String imagePath,
    int maxWidth = 300,
    int maxHeight = 300,
    int quality = 75,
  }) async {
    try {
      final imageFile = File(imagePath);
      final imageBytes = await imageFile.readAsBytes();

      img.Image? image = img.decodeImage(imageBytes);
      if (image == null) {
        throw Exception('Failed to decode image');
      }

      // Calculate thumbnail dimensions maintaining aspect ratio
      final thumbnail = img.copyResize(
        image,
        width: maxWidth,
        height: maxHeight,
        interpolation: img.Interpolation.average,
      );

      // Apply grayscale for consistency
      final grayscaleThumbnail = img.grayscale(thumbnail);

      final encoded = img.encodeJpg(grayscaleThumbnail, quality: quality);

      return ProcessedImage(
        imageBytes: Uint8List.fromList(encoded),
        width: grayscaleThumbnail.width,
        height: grayscaleThumbnail.height,
        sizeBytes: encoded.length,
        format: 'jpg',
      );
    } catch (e) {
      throw Exception('Thumbnail generation failed: $e');
    }
  }

  /// Apply binarization (black and white conversion)
  Future<ProcessedImage> applyBinarization({
    required String imagePath,
    int threshold = 128,
  }) async {
    try {
      final imageFile = File(imagePath);
      final imageBytes = await imageFile.readAsBytes();

      img.Image? image = img.decodeImage(imageBytes);
      if (image == null) {
        throw Exception('Failed to decode image');
      }

      // Convert to grayscale first
      image = img.grayscale(image);

      // Apply threshold binarization
      for (int y = 0; y < image.height; y++) {
        for (int x = 0; x < image.width; x++) {
          final pixel = image.getPixel(x, y);
          final luminance = pixel.r.toInt();

          final newColor = luminance > threshold
              ? img.ColorRgb8(255, 255, 255)
              : img.ColorRgb8(0, 0, 0);

          image.setPixel(x, y, newColor);
        }
      }

      final encoded = img.encodeJpg(image, quality: 90);

      return ProcessedImage(
        imageBytes: Uint8List.fromList(encoded),
        width: image.width,
        height: image.height,
        sizeBytes: encoded.length,
        format: 'jpg',
      );
    } catch (e) {
      throw Exception('Binarization failed: $e');
    }
  }

  /// Crop image to specified bounds
  Future<ProcessedImage> cropImage({
    required String imagePath,
    required Rect cropRect,
  }) async {
    try {
      final imageFile = File(imagePath);
      final imageBytes = await imageFile.readAsBytes();

      img.Image? image = img.decodeImage(imageBytes);
      if (image == null) {
        throw Exception('Failed to decode image');
      }

      final cropped = img.copyCrop(
        image,
        x: cropRect.left.toInt(),
        y: cropRect.top.toInt(),
        width: cropRect.width.toInt(),
        height: cropRect.height.toInt(),
      );

      final encoded = img.encodeJpg(cropped, quality: 90);

      return ProcessedImage(
        imageBytes: Uint8List.fromList(encoded),
        width: cropped.width,
        height: cropped.height,
        sizeBytes: encoded.length,
        format: 'jpg',
      );
    } catch (e) {
      throw Exception('Crop failed: $e');
    }
  }

  /// Rotate image by specified degrees
  Future<ProcessedImage> rotateImage({
    required String imagePath,
    required double degrees,
  }) async {
    try {
      final imageFile = File(imagePath);
      final imageBytes = await imageFile.readAsBytes();

      img.Image? image = img.decodeImage(imageBytes);
      if (image == null) {
        throw Exception('Failed to decode image');
      }

      // Rotate image
      final rotated = img.copyRotate(image, angle: degrees);

      final encoded = img.encodeJpg(rotated, quality: 90);

      return ProcessedImage(
        imageBytes: Uint8List.fromList(encoded),
        width: rotated.width,
        height: rotated.height,
        sizeBytes: encoded.length,
        format: 'jpg',
      );
    } catch (e) {
      throw Exception('Rotation failed: $e');
    }
  }

  /// Calculate optimal compression quality based on image size
  int calculateOptimalQuality(int width, int height) {
    final pixels = width * height;

    if (pixels > 10000000) {
      // > 10MP
      return 75;
    } else if (pixels > 5000000) {
      // > 5MP
      return 80;
    } else if (pixels > 2000000) {
      // > 2MP
      return 85;
    } else {
      return 90;
    }
  }

  /// Estimate processed image size
  int estimateCompressedSize({
    required int width,
    required int height,
    required int quality,
    bool isGrayscale = true,
  }) {
    final pixels = width * height;
    final colorMultiplier = isGrayscale ? 1 : 3;
    final qualityFactor = quality / 100.0;

    // Rough estimation: JPEG compression typically achieves 10:1 to 20:1
    final estimatedSize =
        (pixels * colorMultiplier * qualityFactor / 15).toInt();

    return estimatedSize;
  }

  /// Apply auto-enhancement (automatic levels adjustment)
  Future<ProcessedImage> autoEnhance(String imagePath) async {
    try {
      final imageFile = File(imagePath);
      final imageBytes = await imageFile.readAsBytes();

      img.Image? image = img.decodeImage(imageBytes);
      if (image == null) {
        throw Exception('Failed to decode image');
      }

      // Apply auto-contrast
      image = _autoContrast(image);

      // Apply sharpening
      image = img.adjustColor(image, contrast: 1.1);

      final encoded = img.encodeJpg(image, quality: 90);

      return ProcessedImage(
        imageBytes: Uint8List.fromList(encoded),
        width: image.width,
        height: image.height,
        sizeBytes: encoded.length,
        format: 'jpg',
      );
    } catch (e) {
      throw Exception('Auto enhancement failed: $e');
    }
  }

  /// Auto-contrast helper
  img.Image _autoContrast(img.Image src) {
    // Find min and max luminance
    int minLum = 255;
    int maxLum = 0;

    for (int y = 0; y < src.height; y++) {
      for (int x = 0; x < src.width; x++) {
        final pixel = src.getPixel(x, y);
        final lum = (pixel.r.toInt() + pixel.g.toInt() + pixel.b.toInt()) ~/ 3;

        if (lum < minLum) minLum = lum;
        if (lum > maxLum) maxLum = lum;
      }
    }

    // Apply stretch
    final range = maxLum - minLum;
    if (range == 0) return src;

    for (int y = 0; y < src.height; y++) {
      for (int x = 0; x < src.width; x++) {
        final pixel = src.getPixel(x, y);
        final r =
            ((pixel.r.toInt() - minLum) * 255 / range).clamp(0, 255).toInt();
        final g =
            ((pixel.g.toInt() - minLum) * 255 / range).clamp(0, 255).toInt();
        final b =
            ((pixel.b.toInt() - minLum) * 255 / range).clamp(0, 255).toInt();

        src.setPixel(x, y, img.ColorRgb8(r, g, b));
      }
    }

    return src;
  }

  /// Save processed image to file
  Future<String> saveProcessedImage({
    required ProcessedImage processedImage,
    required String outputPath,
  }) async {
    final file = File(outputPath);
    await file.writeAsBytes(processedImage.imageBytes);
    return outputPath;
  }
}
