import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;

import 'coverage.dart';
import 'variant.dart';

enum GoldenResultStatus { passed, failed }

class GoldenSuitePlan {
  const GoldenSuitePlan({
    required this.description,
    required this.scenario,
    required this.plan,
    required this.goldenPaths,
  });

  final String description;
  final String scenario;
  final GoldenCoveragePlan plan;
  final List<String> goldenPaths;

  Map<String, Object?> toJson() => {
        'description': description,
        'scenario': scenario,
        'sampling': plan.sampling.name,
        'rawCombinations': plan.rawCount,
        'excludedCombinations': plan.excludedCount,
        'selectedCombinations': plan.selectedCount,
        'goldenPaths': goldenPaths,
      };
}

class GoldenCaseResult {
  const GoldenCaseResult({
    required this.description,
    required this.scenario,
    required this.variant,
    required this.status,
    required this.duration,
    required this.captures,
    required this.overflowCount,
    this.failurePhase,
    this.error,
    this.stackTrace,
  });

  final String description;
  final String scenario;
  final GoldenVariant variant;
  final GoldenResultStatus status;
  final Duration duration;
  final List<GoldenCapture> captures;
  final int overflowCount;
  final String? failurePhase;
  final String? error;
  final String? stackTrace;

  Map<String, Object?> toJson() => {
        'description': description,
        'scenario': scenario,
        'status': status.name,
        'durationMs': duration.inMicroseconds / 1000,
        'goldenPaths': captures.map((capture) => capture.path).toList(),
        'captures': captures.map((capture) => capture.toJson()).toList(),
        'failureArtifacts': status == GoldenResultStatus.failed
            ? {
                'directory': 'failures',
                'kinds': [
                  'masterImage',
                  'testImage',
                  'isolatedDiff',
                  'maskedDiff',
                ],
              }
            : null,
        'overflowCount': overflowCount,
        'failurePhase': failurePhase,
        'error': error,
        'stackTrace': stackTrace,
        'variant': _variantJson(variant),
      };
}

class GoldenCapture {
  const GoldenCapture({required this.path, this.name});

  final String path;
  final String? name;

  Map<String, Object?> toJson() => {'path': path, 'name': name};
}

abstract interface class GoldenReporter {
  void registerPlan(GoldenSuitePlan plan);
  void record(GoldenCaseResult result);
  Future<void> complete();
}

class JsonGoldenReporter implements GoldenReporter {
  /// Creates one stable JSON shard for a test file.
  ///
  /// [shardName] must be unique across the project. Share this reporter across
  /// all scenarios registered by that test file; presenter merges the shards.
  JsonGoldenReporter(
    String outputPath, {
    required String shardName,
    Uri? testFile,
    Directory? projectDirectory,
  })  : _requestedOutputPath = outputPath,
        _testFile = testFile,
        _shardName = shardName,
        _projectDirectory = projectDirectory ?? Directory.current {
    if (shardName.trim().isEmpty) {
      throw ArgumentError.value(shardName, 'shardName', 'must not be empty');
    }
  }

  final String _requestedOutputPath;
  final Uri? _testFile;
  final String _shardName;
  final Directory _projectDirectory;
  final List<GoldenSuitePlan> _plans = [];
  final List<GoldenCaseResult> _results = [];
  var _completed = false;

  String get outputPath => _resolveOutputPath();

  @override
  void registerPlan(GoldenSuitePlan plan) {
    if (_completed) {
      throw StateError('Cannot register a plan after report completion.');
    }
    _plans.add(plan);
  }

  @override
  void record(GoldenCaseResult result) {
    if (_completed) {
      throw StateError('Cannot record a result after report completion.');
    }
    _results.add(result);
  }

  @override
  Future<void> complete() async {
    if (_completed) return;
    _completed = true;
    _results.sort((left, right) {
      final scenario = left.scenario.compareTo(right.scenario);
      if (scenario != 0) return scenario;
      return left.variant.label.compareTo(right.variant.label);
    });

    final file = File(outputPath);
    await file.parent.create(recursive: true);
    final payload = {
      'schema': 'ff_golden.run',
      'schemaVersion': 2,
      'generatedAt': DateTime.now().toUtc().toIso8601String(),
      'source': {
        'testFile': _relativeTestFile,
        'goldenBaseDirectory': _goldenBaseDirectory,
        'shard': _shardName,
      },
      'summary': {
        'total': _results.length,
        'passed': _results
            .where((result) => result.status == GoldenResultStatus.passed)
            .length,
        'failed': _results
            .where((result) => result.status == GoldenResultStatus.failed)
            .length,
        'overflows': _results.fold<int>(
          0,
          (sum, result) => sum + result.overflowCount,
        ),
      },
      'plans': _plans.map((plan) => plan.toJson()).toList(),
      'results': _results.map((result) => result.toJson()).toList(),
    };
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(payload),
      flush: true,
    );
  }

  String _resolveOutputPath() {
    final requested = path.normalize(path.absolute(_requestedOutputPath));
    final explicitJson = path.extension(requested).toLowerCase() == '.json';
    final directory = explicitJson ? path.dirname(requested) : requested;
    final prefix =
        explicitJson ? '${path.basenameWithoutExtension(requested)}.' : '';
    return path.join(directory, '$prefix$_resolvedShardName.json');
  }

  String get _resolvedShardName {
    return '${_safeName(_shardName)}.ff-golden-run';
  }

  String? get _relativeTestFile {
    final testFile = _testFile;
    if (testFile == null) return null;
    if (testFile.scheme != 'file') return testFile.toString();
    final absolute = path.normalize(path.absolute(testFile.toFilePath()));
    final relative = path.relative(absolute, from: _projectDirectory.path);
    return path.posix.joinAll(path.split(relative));
  }

  String get _goldenBaseDirectory {
    final testFile = _relativeTestFile;
    if (testFile != null) return path.posix.dirname(testFile);
    final comparator = goldenFileComparator;
    if (comparator is LocalFileComparator) {
      final absolute = path.normalize(path.fromUri(comparator.basedir));
      final relative = path.relative(absolute, from: _projectDirectory.path);
      return path.posix.joinAll(path.split(relative));
    }
    return '.';
  }

  String _safeName(String value) => value
      .replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '-')
      .replaceAll(RegExp('-+'), '-')
      .replaceAll(RegExp(r'^[-.]+|[-.]+$'), '');
}

Map<String, Object?> _variantJson(GoldenVariant variant) => {
      'device': {
        'name': variant.device.name,
        'logicalWidth': variant.device.logicalSize.width,
        'logicalHeight': variant.device.logicalSize.height,
        'physicalWidth': variant.device.physicalSize.width,
        'physicalHeight': variant.device.physicalSize.height,
        'devicePixelRatio': variant.device.devicePixelRatio,
        'safeArea': {
          'left': variant.device.safeArea.left,
          'top': variant.device.safeArea.top,
          'right': variant.device.safeArea.right,
          'bottom': variant.device.safeArea.bottom,
        },
      },
      'theme': variant.theme.name,
      'locale': variant.locale.toLanguageTag(),
      'textScale': variant.textScale,
      'direction': variant.textDirection.name,
      'directionMode': variant.direction.name,
      'platform': variant.platform.name,
      'brightness': variant.brightness.name,
      'highContrast': variant.highContrast,
    };
