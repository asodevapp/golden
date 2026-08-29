/// Image optimization presets exposed by the publication pipeline.
enum ImageOptimizationProfile {
  none,
  lossless,
  balanced,
  small;

  static ImageOptimizationProfile parse(String value) {
    return values.firstWhere(
      (profile) => profile.cliName == value,
      orElse: () => throw FormatException(
        'Unknown optimization profile "$value". Expected one of: '
        '${values.map((profile) => profile.cliName).join(', ')}.',
      ),
    );
  }

  String get cliName => name;

  String get description => switch (this) {
        none => 'Copy images without changing them.',
        lossless => 'Lossless PNG recompression.',
        balanced => 'High-quality PNG quantization for normal publishing.',
        small => 'Stronger PNG quantization for the smallest report.',
      };
}

/// Optimization implementation selected by the user or resolved automatically.
enum ImageOptimizerBackend {
  auto,
  pngquant,
  oxipng,
  imagemagick;

  static ImageOptimizerBackend parse(String value) {
    return values.firstWhere(
      (backend) => backend.cliName == value,
      orElse: () => throw FormatException(
        'Unknown optimizer backend "$value". Expected one of: '
        '${values.map((backend) => backend.cliName).join(', ')}.',
      ),
    );
  }

  String get cliName => switch (this) {
        imagemagick => 'imagemagick',
        _ => name,
      };
}

/// Result of copying publication images into an isolated staging directory.
final class ScreenshotCollectionResult {
  const ScreenshotCollectionResult({
    required this.fileCount,
    required this.totalBytes,
  });

  final int fileCount;
  final int totalBytes;
}

/// Result of optimizing all supported images in a directory.
final class ImageOptimizationResult {
  const ImageOptimizationResult({
    required this.fileCount,
    required this.optimizedFileCount,
    required this.bytesBefore,
    required this.bytesAfter,
    required this.backend,
  });

  final int fileCount;
  final int optimizedFileCount;
  final int bytesBefore;
  final int bytesAfter;
  final ImageOptimizerBackend? backend;

  int get savedBytes => bytesBefore - bytesAfter;
}
