import 'dart:collection';

/// A complete set of golden scenarios discovered below an input directory.
final class GoldenCatalog {
  GoldenCatalog({required Iterable<GoldenScenario> scenarios})
      : scenarios = UnmodifiableListView(scenarios);

  final List<GoldenScenario> scenarios;

  Iterable<GoldenImage> get images => scenarios.expand(
        (scenario) => scenario.images,
      );

  int get imageCount => scenarios.fold(
        0,
        (count, scenario) => count + scenario.images.length,
      );

  List<String> get devices => _distinctValues(
        images.map((image) => image.device),
      );

  List<String> get locales => _distinctValues(
        images.map((image) => image.locale).nonNulls,
      );

  List<String> get themes => _distinctValues(
        images.map((image) => image.theme).nonNulls,
      );

  List<String> get captures => _distinctValues(
        images.map((image) => image.captureName).nonNulls,
      );

  List<String> get textScales {
    final values = _distinctValues(
      images.map((image) => image.textScaleLabel).nonNulls,
    );
    values.sort(
      (left, right) => double.parse(left).compareTo(double.parse(right)),
    );
    return values;
  }

  List<String> get directions => _distinctValues(
        images.map((image) => image.direction).nonNulls,
      );

  List<String> get platforms => _distinctValues(
        images.map((image) => image.platform).nonNulls,
      );

  List<String> get brightnesses => _distinctValues(
        images.map((image) => image.brightness).nonNulls,
      );

  List<String> get contrasts => _distinctValues(
        images.map((image) => image.contrastLabel).nonNulls,
      );

  List<String> get statuses => _distinctValues(
        images
            .where((image) => image.status != GoldenImageStatus.unknown)
            .map((image) => image.status.name),
      );

  int get failedCount =>
      images.where((image) => image.status == GoldenImageStatus.failed).length;

  static List<String> _distinctValues(Iterable<String> values) {
    return values.toSet().toList()..sort(_compareNaturally);
  }
}

enum GoldenImageStatus { unknown, passed, failed }

/// Authoritative metadata associated with one image by an `ff_golden.run`
/// manifest.
final class GoldenImageMetadata {
  const GoldenImageMetadata({
    required this.device,
    required this.status,
    this.captureName,
    this.locale,
    this.theme,
    this.textScale,
    this.direction,
    this.directionMode,
    this.platform,
    this.brightness,
    this.highContrast,
    this.durationMs,
    this.overflowCount,
    this.failurePhase,
    this.error,
    this.sourceTestFile,
  });

  final String device;
  final GoldenImageStatus status;
  final String? captureName;
  final String? locale;
  final String? theme;
  final double? textScale;
  final String? direction;
  final String? directionMode;
  final String? platform;
  final String? brightness;
  final bool? highContrast;
  final double? durationMs;
  final int? overflowCount;
  final String? failurePhase;
  final String? error;
  final String? sourceTestFile;
}

/// Images that belong to one logical golden test scenario.
final class GoldenScenario {
  GoldenScenario({
    required Iterable<String> pathSegments,
    required Iterable<GoldenImage> images,
  })  : pathSegments = UnmodifiableListView(pathSegments),
        images = UnmodifiableListView(images);

  final List<String> pathSegments;
  final List<GoldenImage> images;

  String get name => pathSegments.last;

  String get breadcrumb => pathSegments.join(' / ');
}

/// One source image and the variants parsed from its filename.
final class GoldenImage {
  const GoldenImage({
    required this.fileName,
    required this.path,
    required this.device,
    required this.extension,
    this.locale,
    this.theme,
    this.captureName,
    this.textScale,
    this.direction,
    this.directionMode,
    this.platform,
    this.brightness,
    this.highContrast,
    this.status = GoldenImageStatus.unknown,
    this.durationMs,
    this.overflowCount,
    this.failurePhase,
    this.error,
    this.sourceTestFile,
  });

  final String fileName;
  final String path;
  final String device;
  final String extension;
  final String? locale;
  final String? theme;
  final String? captureName;
  final double? textScale;
  final String? direction;
  final String? directionMode;
  final String? platform;
  final String? brightness;
  final bool? highContrast;
  final GoldenImageStatus status;
  final double? durationMs;
  final int? overflowCount;
  final String? failurePhase;
  final String? error;
  final String? sourceTestFile;

  String? get textScaleLabel => textScale == null
      ? null
      : textScale == textScale!.roundToDouble()
          ? textScale!.toInt().toString()
          : textScale.toString();

  String? get contrastLabel => highContrast == null
      ? null
      : highContrast!
          ? 'high'
          : 'normal';

  String get searchText => [
        fileName,
        device,
        if (captureName != null) captureName!,
        if (locale != null) locale!,
        if (theme != null) theme!,
        if (textScaleLabel != null) textScaleLabel!,
        if (direction != null) direction!,
        if (directionMode != null) directionMode!,
        if (platform != null) platform!,
        if (brightness != null) brightness!,
        if (contrastLabel != null) contrastLabel!,
        if (status != GoldenImageStatus.unknown) status.name,
        if (failurePhase != null) failurePhase!,
        if (error != null) error!,
        if (sourceTestFile != null) sourceTestFile!,
      ].join(' ');
}

/// The rendered report together with the data used to build it.
final class GoldenPresenterResult {
  const GoldenPresenterResult({
    required this.html,
    required this.catalog,
  });

  final String html;
  final GoldenCatalog catalog;
}

int _compareNaturally(String left, String right) {
  return left.toLowerCase().compareTo(right.toLowerCase());
}
