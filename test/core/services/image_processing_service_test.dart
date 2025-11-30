import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:doc_scanner/core/services/image_processing_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ImageProcessingService', () {
    late ImageProcessingService imageProcessingService;

    setUp(() {
      imageProcessingService = ImageProcessingService();
    });

    group('ProcessedImage', () {
      test('ProcessedImage creates instance with all fields', () {
        final imageBytes = Uint8List.fromList([1, 2, 3, 4, 5]);
        final processedImage = ProcessedImage(
          imageBytes: imageBytes,
          width: 800,
          height: 600,
          sizeBytes: imageBytes.length,
          format: 'jpg',
        );

        expect(processedImage.imageBytes, equals(imageBytes));
        expect(processedImage.width, equals(800));
        expect(processedImage.height, equals(600));
        expect(processedImage.sizeBytes, equals(5));
        expect(processedImage.format, equals('jpg'));
      });

      test('ProcessedImage has default format jpg', () {
        final imageBytes = Uint8List.fromList([1, 2, 3]);
        final processedImage = ProcessedImage(
          imageBytes: imageBytes,
          width: 100,
          height: 100,
          sizeBytes: imageBytes.length,
        );

        expect(processedImage.format, equals('jpg'));
      });

      test('ProcessedImage handles large dimensions', () {
        final imageBytes = Uint8List.fromList([1, 2, 3]);
        final processedImage = ProcessedImage(
          imageBytes: imageBytes,
          width: 4000,
          height: 3000,
          sizeBytes: imageBytes.length,
        );

        expect(processedImage.width, equals(4000));
        expect(processedImage.height, equals(3000));
      });

      test('ProcessedImage handles small dimensions', () {
        final imageBytes = Uint8List.fromList([1]);
        final processedImage = ProcessedImage(
          imageBytes: imageBytes,
          width: 1,
          height: 1,
          sizeBytes: imageBytes.length,
        );

        expect(processedImage.width, equals(1));
        expect(processedImage.height, equals(1));
      });
    });

    group('calculateOptimalQuality', () {
      test('returns 75 for images larger than 10MP', () {
        // 4000 x 3000 = 12MP
        final quality =
            imageProcessingService.calculateOptimalQuality(4000, 3000);
        expect(quality, equals(75));
      });

      test('returns 80 for exactly 10MP', () {
        // 4000 x 2500 = 10MP (exactly 10000000, not > 10000000)
        final quality =
            imageProcessingService.calculateOptimalQuality(4000, 2500);
        expect(quality, equals(80));
      });

      test('returns 80 for images between 5MP and 10MP', () {
        // 3000 x 2000 = 6MP
        final quality =
            imageProcessingService.calculateOptimalQuality(3000, 2000);
        expect(quality, equals(80));
      });

      test('returns 85 for exactly 5MP', () {
        // 2500 x 2000 = 5MP (exactly 5000000, not > 5000000)
        final quality =
            imageProcessingService.calculateOptimalQuality(2500, 2000);
        expect(quality, equals(85));
      });

      test('returns 85 for images between 2MP and 5MP', () {
        // 2000 x 1500 = 3MP
        final quality =
            imageProcessingService.calculateOptimalQuality(2000, 1500);
        expect(quality, equals(85));
      });

      test('returns 90 for exactly 2MP', () {
        // 2000 x 1000 = 2MP (exactly 2000000, not > 2000000)
        final quality =
            imageProcessingService.calculateOptimalQuality(2000, 1000);
        expect(quality, equals(90));
      });

      test('returns 90 for images smaller than 2MP', () {
        // 1000 x 1000 = 1MP
        final quality =
            imageProcessingService.calculateOptimalQuality(1000, 1000);
        expect(quality, equals(90));
      });

      test('returns 90 for very small images', () {
        // 100 x 100 = 0.01MP
        final quality =
            imageProcessingService.calculateOptimalQuality(100, 100);
        expect(quality, equals(90));
      });

      test('handles wide aspect ratio images', () {
        // 4000 x 1000 = 4MP
        final quality =
            imageProcessingService.calculateOptimalQuality(4000, 1000);
        expect(quality, equals(85));
      });

      test('handles tall aspect ratio images', () {
        // 1000 x 4000 = 4MP
        final quality =
            imageProcessingService.calculateOptimalQuality(1000, 4000);
        expect(quality, equals(85));
      });

      test('handles square images', () {
        // 3000 x 3000 = 9MP
        final quality =
            imageProcessingService.calculateOptimalQuality(3000, 3000);
        expect(quality, equals(80));
      });
    });

    group('estimateCompressedSize', () {
      test('estimates size for grayscale image', () {
        final size = imageProcessingService.estimateCompressedSize(
          width: 1000,
          height: 1000,
          quality: 80,
          isGrayscale: true,
        );

        // 1000 * 1000 * 1 * 0.8 / 15 = 53,333
        expect(size, greaterThan(0));
        expect(size,
            lessThan(1000000)); // Should be much smaller than uncompressed
      });

      test('estimates size for color image', () {
        final size = imageProcessingService.estimateCompressedSize(
          width: 1000,
          height: 1000,
          quality: 80,
          isGrayscale: false,
        );

        // Should be approximately 3x larger than grayscale
        final grayscaleSize = imageProcessingService.estimateCompressedSize(
          width: 1000,
          height: 1000,
          quality: 80,
          isGrayscale: true,
        );

        expect(size, greaterThan(grayscaleSize * 2));
        expect(size, lessThan(grayscaleSize * 4));
      });

      test('estimates larger size for higher quality', () {
        final highQuality = imageProcessingService.estimateCompressedSize(
          width: 1000,
          height: 1000,
          quality: 95,
          isGrayscale: true,
        );

        final lowQuality = imageProcessingService.estimateCompressedSize(
          width: 1000,
          height: 1000,
          quality: 50,
          isGrayscale: true,
        );

        expect(highQuality, greaterThan(lowQuality));
      });

      test('estimates larger size for larger dimensions', () {
        final large = imageProcessingService.estimateCompressedSize(
          width: 2000,
          height: 2000,
          quality: 80,
          isGrayscale: true,
        );

        final small = imageProcessingService.estimateCompressedSize(
          width: 1000,
          height: 1000,
          quality: 80,
          isGrayscale: true,
        );

        expect(large, greaterThan(small * 3)); // 4x pixels, roughly 4x size
      });

      test('handles minimum quality', () {
        final size = imageProcessingService.estimateCompressedSize(
          width: 1000,
          height: 1000,
          quality: 1,
          isGrayscale: true,
        );

        expect(size, greaterThan(0));
      });

      test('handles maximum quality', () {
        final size = imageProcessingService.estimateCompressedSize(
          width: 1000,
          height: 1000,
          quality: 100,
          isGrayscale: true,
        );

        expect(size, greaterThan(0));
      });

      test('estimate is reasonable for typical document', () {
        // Typical document: 2000x3000, grayscale, quality 85
        final size = imageProcessingService.estimateCompressedSize(
          width: 2000,
          height: 3000,
          quality: 85,
          isGrayscale: true,
        );

        // Estimate should be reasonable (between 100KB and 2MB)
        expect(size, greaterThan(100000));
        expect(size, lessThan(2000000));
      });

      test('color images are estimated to be larger than grayscale', () {
        final grayscale = imageProcessingService.estimateCompressedSize(
          width: 2000,
          height: 2000,
          quality: 80,
          isGrayscale: true,
        );

        final color = imageProcessingService.estimateCompressedSize(
          width: 2000,
          height: 2000,
          quality: 80,
          isGrayscale: false,
        );

        expect(color, equals(grayscale * 3));
      });

      test('quality factor affects estimate linearly', () {
        final quality50 = imageProcessingService.estimateCompressedSize(
          width: 1000,
          height: 1000,
          quality: 50,
          isGrayscale: true,
        );

        final quality100 = imageProcessingService.estimateCompressedSize(
          width: 1000,
          height: 1000,
          quality: 100,
          isGrayscale: true,
        );

        // Quality 100 should be approximately 2x size of quality 50
        expect(quality100, closeTo(quality50 * 2, quality50 * 0.1));
      });
    });

    group('Quality Calculations Integration', () {
      test('optimal quality and size estimation work together', () {
        const width = 3000;
        const height = 2000;

        final optimalQuality =
            imageProcessingService.calculateOptimalQuality(width, height);
        final estimatedSize = imageProcessingService.estimateCompressedSize(
          width: width,
          height: height,
          quality: optimalQuality,
          isGrayscale: true,
        );

        expect(optimalQuality, equals(85)); // 6MP image
        expect(estimatedSize, greaterThan(0));
      });

      test('small images get high quality and small size', () {
        const width = 800;
        const height = 600;

        final optimalQuality =
            imageProcessingService.calculateOptimalQuality(width, height);
        final estimatedSize = imageProcessingService.estimateCompressedSize(
          width: width,
          height: height,
          quality: optimalQuality,
          isGrayscale: true,
        );

        expect(optimalQuality, equals(90)); // < 2MP image
        expect(estimatedSize, lessThan(100000)); // Should be small
      });

      test('large images get lower quality but larger size', () {
        const width = 4000;
        const height = 3000;

        final optimalQuality =
            imageProcessingService.calculateOptimalQuality(width, height);
        final estimatedSize = imageProcessingService.estimateCompressedSize(
          width: width,
          height: height,
          quality: optimalQuality,
          isGrayscale: true,
        );

        expect(optimalQuality, equals(75)); // > 10MP image
        expect(estimatedSize, greaterThan(100000)); // Should be larger
      });
    });

    group('Edge Cases', () {
      test('calculateOptimalQuality handles 1x1 image', () {
        final quality = imageProcessingService.calculateOptimalQuality(1, 1);
        expect(quality, equals(90));
      });

      test('estimateCompressedSize handles 1x1 image', () {
        final size = imageProcessingService.estimateCompressedSize(
          width: 1,
          height: 1,
          quality: 80,
          isGrayscale: true,
        );
        expect(size, greaterThanOrEqualTo(0));
      });

      test('calculateOptimalQuality handles very large dimensions', () {
        // 10000 x 10000 = 100MP
        final quality =
            imageProcessingService.calculateOptimalQuality(10000, 10000);
        expect(quality, equals(75));
      });

      test('estimateCompressedSize handles quality 0', () {
        final size = imageProcessingService.estimateCompressedSize(
          width: 1000,
          height: 1000,
          quality: 0,
          isGrayscale: true,
        );
        expect(size, equals(0)); // Quality 0 = 0 bytes
      });

      test('handles rectangular images in both orientations', () {
        // Portrait
        final qualityPortrait =
            imageProcessingService.calculateOptimalQuality(1000, 2000);
        // Landscape
        final qualityLandscape =
            imageProcessingService.calculateOptimalQuality(2000, 1000);

        // Both should give same quality as they have same pixel count
        expect(qualityPortrait, equals(qualityLandscape));
        expect(qualityPortrait, equals(90)); // 2MP image
      });
    });

    group('Compression Ratio Validation', () {
      test('compression ratio is realistic for typical quality', () {
        final uncompressedSize =
            1000 * 1000 * 1; // 1MP grayscale = 1MB uncompressed
        final estimatedCompressed =
            imageProcessingService.estimateCompressedSize(
          width: 1000,
          height: 1000,
          quality: 80,
          isGrayscale: true,
        );

        final compressionRatio = uncompressedSize / estimatedCompressed;

        // JPEG typically achieves 10:1 to 20:1 compression
        // Formula uses /15, so should be around 15:1
        expect(compressionRatio, greaterThan(10));
        expect(compressionRatio, lessThan(20));
      });

      test('lower quality produces higher compression ratio', () {
        const width = 1000;
        const height = 1000;
        final uncompressedSize = width * height * 1;

        final highQualitySize = imageProcessingService.estimateCompressedSize(
          width: width,
          height: height,
          quality: 90,
          isGrayscale: true,
        );

        final lowQualitySize = imageProcessingService.estimateCompressedSize(
          width: width,
          height: height,
          quality: 50,
          isGrayscale: true,
        );

        final highQualityRatio = uncompressedSize / highQualitySize;
        final lowQualityRatio = uncompressedSize / lowQualitySize;

        expect(lowQualityRatio, greaterThan(highQualityRatio));
      });
    });

    group('Typical Use Cases', () {
      test('standard smartphone photo gets appropriate settings', () {
        // Typical smartphone photo: 4032 x 3024 (12MP)
        final quality =
            imageProcessingService.calculateOptimalQuality(4032, 3024);
        final size = imageProcessingService.estimateCompressedSize(
          width: 4032,
          height: 3024,
          quality: quality,
          isGrayscale: true,
        );

        expect(quality, equals(75)); // High resolution gets lower quality
        expect(size, greaterThan(500000)); // At least 500KB
        expect(size, lessThan(5000000)); // Less than 5MB
      });

      test('thumbnail gets high quality and small size', () {
        // Typical thumbnail: 300 x 300
        final quality =
            imageProcessingService.calculateOptimalQuality(300, 300);
        final size = imageProcessingService.estimateCompressedSize(
          width: 300,
          height: 300,
          quality: 75, // Thumbnail quality
          isGrayscale: true,
        );

        expect(quality, equals(90));
        expect(size, lessThan(50000)); // Should be under 50KB
      });

      test('A4 scanned document at 300dpi gets appropriate settings', () {
        // A4 at 300dpi: 2480 x 3508 (~8.7MP)
        final quality =
            imageProcessingService.calculateOptimalQuality(2480, 3508);
        final size = imageProcessingService.estimateCompressedSize(
          width: 2480,
          height: 3508,
          quality: quality,
          isGrayscale: true,
        );

        expect(quality, equals(80)); // Between 5-10MP
        expect(size, greaterThan(300000)); // Reasonable document size
        expect(size, lessThan(3000000));
      });
    });
  });
}
