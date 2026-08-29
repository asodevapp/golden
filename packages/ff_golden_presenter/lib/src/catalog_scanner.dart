import 'dart:io';

import 'package:path/path.dart' as path;

import 'golden_image_factory.dart';
import 'model.dart';
import 'run_manifest.dart';

/// Scans an input tree and groups images by their logical golden scenario.
final class GoldenCatalogScanner {
  GoldenCatalogScanner({
    required Directory inputDirectory,
    required GoldenImageFactory imageFactory,
    GoldenRunIndex? runIndex,
    this.goldenDirectoryName = 'golden',
    Set<String> extensions = const {'png', 'jpg', 'jpeg', 'webp', 'svg'},
  })  : _inputDirectory = inputDirectory,
        _imageFactory = imageFactory,
        _runIndex = runIndex ?? GoldenRunIndex.empty(),
        extensions = {
          for (final extension in extensions)
            extension.replaceFirst('.', '').toLowerCase(),
        };

  final Directory _inputDirectory;
  final GoldenImageFactory _imageFactory;
  final GoldenRunIndex _runIndex;
  final String goldenDirectoryName;
  final Set<String> extensions;

  Future<GoldenCatalog> scan() async {
    final inputPath = path.normalize(path.absolute(_inputDirectory.path));
    final files = <File>[];

    await for (final entity in _inputDirectory.list(
      recursive: true,
      followLinks: false,
    )) {
      if (entity is File && _isSupported(entity.path)) {
        files.add(entity);
      }
    }

    files.sort((left, right) => left.path.compareTo(right.path));
    final scenarios = <String, _ScenarioBuilder>{};

    for (final file in files) {
      final absolutePath = path.normalize(path.absolute(file.path));
      final relativePath = path.relative(absolutePath, from: inputPath);
      final segments = path.split(relativePath);
      if (segments.length < 2) {
        continue;
      }

      final directories = segments.sublist(0, segments.length - 1);
      final markerIndex = directories.indexOf(goldenDirectoryName);
      if (markerIndex < 0) {
        continue;
      }

      final scenarioSegments = <String>[
        ...directories.take(markerIndex),
        ...directories.skip(markerIndex + 1),
      ];
      if (scenarioSegments.isEmpty) {
        scenarioSegments.add('Root');
      }

      final key = scenarioSegments.join('\u0000');
      final builder = scenarios.putIfAbsent(
        key,
        () => _ScenarioBuilder(scenarioSegments),
      );
      builder.images.add(
        _imageFactory.build(
          fileName: segments.last,
          absolutePath: absolutePath,
          metadata: _runIndex.metadataFor(relativePath),
        ),
      );
    }

    final result = scenarios.values.map((builder) => builder.build()).toList()
      ..sort((left, right) => left.breadcrumb.compareTo(right.breadcrumb));
    return GoldenCatalog(scenarios: result);
  }

  bool _isSupported(String filePath) {
    final extension =
        path.extension(filePath).replaceFirst('.', '').toLowerCase();
    return extensions.contains(extension);
  }
}

final class _ScenarioBuilder {
  _ScenarioBuilder(this.pathSegments);

  final List<String> pathSegments;
  final List<GoldenImage> images = [];

  GoldenScenario build() {
    images.sort((left, right) {
      final device = left.device.compareTo(right.device);
      if (device != 0) return device;
      final theme = (left.theme ?? '').compareTo(right.theme ?? '');
      if (theme != 0) return theme;
      final locale = (left.locale ?? '').compareTo(right.locale ?? '');
      if (locale != 0) return locale;
      return (left.captureName ?? '').compareTo(right.captureName ?? '');
    });
    return GoldenScenario(pathSegments: pathSegments, images: images);
  }
}
