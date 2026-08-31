import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;

import 'model.dart';

/// Metadata merged from all `ff_golden.run` JSON shards found for one run.
final class GoldenRunIndex {
  GoldenRunIndex._({
    required Map<String, GoldenImageMetadata> exact,
    required Map<String, List<GoldenImageMetadata>> suffixes,
    required this.manifestCount,
    Set<String> sourceTestFiles = const {},
  })  : _exact = Map.unmodifiable(exact),
        _suffixes = Map.unmodifiable(suffixes),
        sourceTestFiles = Set.unmodifiable(sourceTestFiles);

  factory GoldenRunIndex.empty() => GoldenRunIndex._(
        exact: const {},
        suffixes: const {},
        manifestCount: 0,
      );

  final Map<String, GoldenImageMetadata> _exact;
  final Map<String, List<GoldenImageMetadata>> _suffixes;
  final int manifestCount;

  /// Project-relative sources, including runs without captured images.
  final Set<String> sourceTestFiles;
  Map<String, GoldenImageMetadata> get exactImages => _exact;

  int get imageCount => _suffixes.values.fold(
        0,
        (count, entries) => count + entries.length,
      );

  GoldenImageMetadata? metadataFor(String relativeImagePath) {
    final key = _normalize(relativeImagePath);
    final exact = _exact[key];
    if (exact != null) return exact;

    final candidates = <GoldenImageMetadata>[];
    for (final entry in _suffixes.entries) {
      if (key == entry.key || key.endsWith('/${entry.key}')) {
        candidates.addAll(entry.value);
      }
    }
    return candidates.length == 1 ? candidates.single : null;
  }
}

/// Loads schema v1/v2 runner manifests and maps their captures to an image
/// tree. Missing locations are optional so the default `build/ff_golden`
/// lookup does not break projects that have not enabled JSON reporting yet.
final class GoldenRunManifestLoader {
  GoldenRunManifestLoader({
    required Directory projectDirectory,
    required Directory imageRoot,
    required Iterable<String> manifestPaths,
  })  : _projectDirectory = projectDirectory,
        _imageRoot = imageRoot,
        _manifestPaths = List.unmodifiable(manifestPaths);

  final Directory _projectDirectory;
  final Directory _imageRoot;
  final List<String> _manifestPaths;

  Future<GoldenRunIndex> load() async {
    final files = <File>[];
    for (final configuredPath in _manifestPaths) {
      final absolute = path.normalize(
        path.isAbsolute(configuredPath)
            ? configuredPath
            : path.join(_projectDirectory.path, configuredPath),
      );
      final type = await FileSystemEntity.type(absolute, followLinks: false);
      if (type == FileSystemEntityType.file) {
        files.add(File(absolute));
      } else if (type == FileSystemEntityType.directory) {
        await for (final entity in Directory(absolute).list(
          recursive: true,
          followLinks: false,
        )) {
          if (entity is File &&
              path.extension(entity.path).toLowerCase() == '.json') {
            files.add(entity);
          }
        }
      }
    }
    files.sort((left, right) => left.path.compareTo(right.path));

    final exact = <String, GoldenImageMetadata>{};
    final suffixes = <String, List<GoldenImageMetadata>>{};
    final sourceTestFiles = <String>{};
    var manifestCount = 0;
    for (final file in files) {
      final decoded = await _decode(file);
      if (decoded == null) continue;
      manifestCount++;
      _addManifest(decoded, exact, suffixes, file.path);
      final testFile = _string(_map(decoded['source'])?['testFile']);
      if (testFile != null) sourceTestFiles.add(testFile);
    }
    return GoldenRunIndex._(
      exact: exact,
      suffixes: suffixes,
      manifestCount: manifestCount,
      sourceTestFiles: sourceTestFiles,
    );
  }

  Future<Map<String, Object?>?> _decode(File file) async {
    Object? value;
    try {
      value = jsonDecode(await file.readAsString());
    } on FormatException catch (error) {
      throw FormatException('Invalid JSON manifest ${file.path}: $error');
    }
    if (value is! Map<String, Object?> || value['schema'] != 'ff_golden.run') {
      return null;
    }
    final version = value['schemaVersion'];
    if (version != 1 && version != 2) {
      throw FormatException(
        'Unsupported ff_golden.run schemaVersion $version in ${file.path}.',
      );
    }
    return value;
  }

  void _addManifest(
    Map<String, Object?> manifest,
    Map<String, GoldenImageMetadata> exact,
    Map<String, List<GoldenImageMetadata>> suffixes,
    String manifestPath,
  ) {
    final source = _map(manifest['source']);
    final testFile = _string(source?['testFile']);
    final baseDirectory = _string(source?['goldenBaseDirectory']);
    final results = manifest['results'];
    if (results is! List<Object?>) {
      throw FormatException('Missing results list in $manifestPath.');
    }

    for (final rawResult in results) {
      final result = _map(rawResult);
      if (result == null) {
        throw FormatException('Invalid result entry in $manifestPath.');
      }
      final variant = _map(result['variant']);
      final device = _map(variant?['device']);
      final deviceName = _string(device?['name']);
      if (variant == null || deviceName == null) {
        throw FormatException('Result has no variant device in $manifestPath.');
      }
      final metadataBase = GoldenImageMetadata(
        device: deviceName,
        status: _status(_string(result['status'])),
        locale: _string(variant['locale']),
        theme: _string(variant['theme']),
        textScale: _double(variant['textScale']),
        direction: _string(variant['direction']),
        directionMode: _string(variant['directionMode']),
        platform: _string(variant['platform']),
        brightness: _string(variant['brightness']),
        highContrast: _bool(variant['highContrast']),
        durationMs: _double(result['durationMs']),
        overflowCount: _int(result['overflowCount']),
        failurePhase: _string(result['failurePhase']),
        error: _string(result['error']),
        sourceTestFile: testFile,
        testDescription: _string(result['description']),
        scenario: _string(result['scenario']),
      );

      final captures = _captures(result);
      for (final capture in captures) {
        final capturePath = capture.$1;
        final metadata = GoldenImageMetadata(
          device: metadataBase.device,
          status: metadataBase.status,
          captureName: capture.$2,
          locale: metadataBase.locale,
          theme: metadataBase.theme,
          textScale: metadataBase.textScale,
          direction: metadataBase.direction,
          directionMode: metadataBase.directionMode,
          platform: metadataBase.platform,
          brightness: metadataBase.brightness,
          highContrast: metadataBase.highContrast,
          durationMs: metadataBase.durationMs,
          overflowCount: metadataBase.overflowCount,
          failurePhase: metadataBase.failurePhase,
          error: metadataBase.error,
          sourceTestFile: metadataBase.sourceTestFile,
          testDescription: metadataBase.testDescription,
          scenario: metadataBase.scenario,
        );
        final suffix = _normalize(capturePath);
        suffixes.putIfAbsent(suffix, () => []).add(metadata);

        if (baseDirectory != null) {
          final sourceImage = path.normalize(
            path.join(_projectDirectory.path, baseDirectory, capturePath),
          );
          final relative = path.relative(sourceImage, from: _imageRoot.path);
          if (!path.isAbsolute(relative) &&
              relative != '..' &&
              !relative.startsWith('..${path.separator}')) {
            final key = _normalize(relative);
            if (exact.containsKey(key)) {
              throw FormatException(
                'Multiple ff_golden.run results map to $key; '
                'check shard names and golden path collisions ($manifestPath).',
              );
            }
            exact[key] = metadata;
          }
        }
      }
    }
  }

  List<(String, String?)> _captures(Map<String, Object?> result) {
    final captures = result['captures'];
    if (captures is List<Object?>) {
      return [
        for (final raw in captures)
          if (_map(raw) case final capture?)
            if (_string(capture['path']) case final capturePath?)
              (capturePath, _string(capture['name'])),
      ];
    }
    final goldenPaths = result['goldenPaths'];
    if (goldenPaths is List<Object?>) {
      return [
        for (final value in goldenPaths)
          if (_string(value) case final capturePath?) (capturePath, null),
      ];
    }
    return const [];
  }

  Map<String, Object?>? _map(Object? value) =>
      value is Map<String, Object?> ? value : null;

  String? _string(Object? value) =>
      value is String && value.isNotEmpty ? value : null;

  double? _double(Object? value) => value is num ? value.toDouble() : null;

  int? _int(Object? value) => value is num ? value.toInt() : null;

  bool? _bool(Object? value) => value is bool ? value : null;

  GoldenImageStatus _status(String? value) => switch (value) {
        'passed' => GoldenImageStatus.passed,
        'failed' => GoldenImageStatus.failed,
        _ => GoldenImageStatus.unknown,
      };
}

String _normalize(String value) =>
    path.posix.joinAll(path.split(path.normalize(value)));
