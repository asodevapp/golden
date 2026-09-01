import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'git_image_review.dart';
import 'model.dart';
import 'run_manifest.dart';
import 'review_test_source.dart';
import 'review_test_variants.dart';

final class ReviewTestTarget {
  const ReviewTestTarget(this.path, this.packagePath, this.relativePath);
  final String path;
  final String packagePath;
  final String relativePath;
  String get id => base64Url.encode(utf8.encode(path));
  Map<String, Object> toJson() => {
        'id': id,
        'path': path,
        'package': packagePath,
      };
}

final class ReviewScenario {
  ReviewScenario(this.testId, this.description, this.name, this.fullName);
  final String testId, description, name;
  final String? fullName;
  final goldenDirectories = <String>{};
  String get id =>
      'scenario:${base64Url.encode(utf8.encode('$testId\u0000${fullName ?? description}\u0000$name'))}';
}

final class ReviewTestScope {
  const ReviewTestScope(this.id, this.kind, this.path, this.fileIds,
      {this.scenarioId});
  final String id, kind, path;
  final List<String> fileIds;
  final String? scenarioId;
  Map<String, Object?> toJson() => {
        'id': id,
        'kind': kind,
        'path': path,
        'fileCount': fileIds.length,
        'testId': fileIds.length == 1 ? fileIds.single : null,
        'scenarioId': scenarioId,
      };
}

final class ReviewTestSelection {
  const ReviewTestSelection(this.target, this.scenarios);
  final ReviewTestTarget target;

  /// Empty means all golden tests in this explicit file.
  final List<ReviewScenario> scenarios;
}

/// Discovers files without executing test code. Run requests use these IDs only.
final class ReviewTestCatalog {
  ReviewTestCatalog(this.repository);
  final GitImageRepository repository;
  final targets = <String, ReviewTestTarget>{};
  final scopes = <String, ReviewTestScope>{};
  final scenarios = <String, ReviewScenario>{};
  final _indexes = <String, GoldenRunIndex>{};
  final _sourceCache = <String, ({String stamp, ReviewTestSource source})>{};
  final warnings = <String>[];
  final _variants = <String, List<ReviewTestVariant>>{};

  /// Resolves a catalog path, which always uses POSIX separators, locally.
  String absolutePath(String repositoryRelativePath) => p.normalize(p.joinAll([
        repository.directory.path,
        ...p.posix.split(repositoryRelativePath),
      ]));

  void forgetVariants(ReviewTestTarget target) => _variants.remove(target.id);
  void rememberVariants(
      ReviewTestTarget target, List<ReviewTestVariant> values) {
    _variants[target.id] = List.unmodifiable(values);
  }

  List<ReviewTestVariant>? variantsFor(ReviewTestSelection selection) {
    final values = _variants[selection.target.id];
    final pattern = ReviewTestFilters.parse({}).patternFor(selection.scenarios);
    return pattern == null
        ? values
        : values
            ?.where((value) => RegExp(pattern).hasMatch(value.fullName))
            .toList();
  }

  bool hasCompleteVariants(ReviewTestSelection selection) =>
      _variants.containsKey(selection.target.id) &&
      (selection.scenarios.isNotEmpty ||
          _sourceCache[selection.target.path]?.source.hasTaggedTests == false);

  Map<String, Object?> variantOptions(
      List<ReviewTestSelection> selections, ReviewTestFilters filters) {
    final values = <ReviewTestVariant>[];
    var loaded = 0;
    for (final selection in selections) {
      final variants = variantsFor(selection);
      if (variants != null) {
        loaded++;
        values.addAll(variants);
      }
    }
    bool matches(ReviewTestVariant value, Map<String, String> selected) {
      final pattern = ReviewTestFilters.parse(selected).pattern;
      return pattern == null || RegExp(pattern).hasMatch(value.fullName);
    }

    final options = <String, List<String>>{};
    for (final key in ReviewTestFilters.keys.where((key) => key != 'name')) {
      final remaining = {...filters.values}..remove(key);
      final choices = {
        for (final value in values)
          if (matches(value, remaining) && value.axes[key] != null)
            value.axes[key]!,
      }.toList()
        ..sort((a, b) => key == 'textScale'
            ? double.parse(a).compareTo(double.parse(b))
            : a.compareTo(b));
      options[key] = choices;
    }
    return {
      'options': options,
      'names': values.map((value) => value.description).toSet().toList()
        ..sort(),
      'loadedFiles': loaded,
      'fileCount': selections.length,
      'complete': selections.every(hasCompleteVariants),
      'customTests': selections.any((selection) =>
          selection.scenarios.isEmpty &&
          _sourceCache[selection.target.path]?.source.hasTaggedTests == true),
      'total': values.length,
      'matching':
          values.where((value) => matches(value, filters.values)).length,
      'coverage': values.any((value) => value.axes.containsKey('textScale')),
    };
  }

  Future<void> refresh() async {
    targets.clear();
    _indexes.clear();
    warnings.clear();
    scopes.clear();
    scenarios.clear();
    final root = repository.directory.path;
    Future<void> visit(Directory directory, String? packagePath) async {
      final pubspec = p.join(directory.path, 'pubspec.yaml');
      if (await FileSystemEntity.type(pubspec, followLinks: false) ==
          FileSystemEntityType.file) {
        packagePath = _posix(p.relative(directory.path, from: root));
      }
      await for (final entity in directory.list(followLinks: false)) {
        final name = p.basename(entity.path);
        if (entity is Directory) {
          if (name.startsWith('.') || _excluded.contains(name)) continue;
          await visit(entity, packagePath);
        } else if (entity is File &&
            packagePath != null &&
            name.endsWith('_test.dart')) {
          final relative =
              _posix(p.relative(entity.path, from: absolutePath(packagePath)));
          final target = ReviewTestTarget(
            _posix(p.relative(entity.path, from: root)),
            packagePath,
            relative,
          );
          targets[target.id] = target;
          if (targets.length > 5000) {
            throw const GitReviewException(
                'More than 5000 tests found. Start diff with a narrower --project.');
          }
        }
      }
    }

    // A subdirectory may still belong to a pubspec above --project.
    String? parentPackage;
    var parent = repository.projectDirectory;
    while (p.isWithin(root, parent.path) || parent.path == root) {
      if (await FileSystemEntity.type(p.join(parent.path, 'pubspec.yaml'),
              followLinks: false) ==
          FileSystemEntityType.file) {
        parentPackage = _posix(p.relative(parent.path, from: root));
        break;
      }
      parent = parent.parent;
    }
    await visit(repository.projectDirectory, parentPackage);
    for (final package in targets.values.map((t) => t.packagePath).toSet()) {
      try {
        _indexes[package] = await GoldenRunManifestLoader(
          projectDirectory: Directory(absolutePath(package)),
          imageRoot: repository.directory,
          manifestPaths: const ['build/ff_golden'],
        ).load();
      } on FormatException catch (error) {
        warnings.add(error.message);
      } on FileSystemException {
        warnings.add('Could not read the run manifest for $package.');
      }
    }
    final manifestFiles = {
      for (final entry in _indexes.entries)
        for (final file in entry.value.sourceTestFiles)
          p.posix
              .normalize(p.posix.join(entry.key, file.replaceAll('\\', '/'))),
    };
    final candidates = targets.values.toList();
    for (final target in candidates) {
      final source = await _readSource(target);
      if (!source.isGolden && !manifestFiles.contains(target.path)) {
        targets.remove(target.id);
      }
    }
    final paths = candidates.map((target) => target.path).toSet();
    _sourceCache.removeWhere((path, _) => !paths.contains(path));
    _variants.removeWhere((id, _) => !targets.containsKey(id));
    _buildScopes();
  }

  Future<ReviewTestSource> _readSource(ReviewTestTarget target) async {
    final file = File(absolutePath(target.path));
    final stat = await file.stat();
    if (stat.size > 1024 * 1024) {
      warnings.add(
          'Golden discovery skipped for ${target.path}: source exceeds 1 MiB; a run manifest is required.');
      _sourceCache.remove(target.path);
      return const ReviewTestSource();
    }
    final stamp = '${stat.modified.microsecondsSinceEpoch}:${stat.size}';
    var cached = _sourceCache[target.path];
    if (cached == null || cached.stamp != stamp) {
      forgetVariants(target);
      cached = (
        stamp: stamp,
        source: readReviewTestSource(await file.readAsString())
      );
      _sourceCache[target.path] = cached;
    }
    return cached.source;
  }

  void _buildScopes() {
    final sorted = targets.values.toList()
      ..sort((a, b) => a.path.compareTo(b.path));
    final root = repository.directory.path;
    final project = p
        .relative(repository.projectDirectory.path, from: root)
        .split(p.separator)
        .join('/');
    final folders = <String, List<String>>{};
    for (final target in sorted) {
      scopes[target.id] =
          ReviewTestScope(target.id, 'file', target.path, [target.id]);
      var folder = p.posix.dirname(target.path);
      while (_under(project, folder)) {
        (folders[folder] ??= []).add(target.id);
        if (folder == project || folder == '.') break;
        folder = p.posix.dirname(folder);
      }
      for (final hint in _sourceCache[target.path]?.source.scenarios ??
          <ReviewSourceScenario>[]) {
        final scenario = ReviewScenario(target.id, hint.description,
            hint.scenario ?? hint.description, hint.fullName);
        final known = scenarios.putIfAbsent(scenario.id, () => scenario);
        if (hint.goldenFolder != null) {
          known.goldenDirectories.add(p.posix.normalize(
              p.posix.join(p.posix.dirname(target.path), hint.goldenFolder!)));
        }
      }
    }
    for (final package in _indexes.entries) {
      for (final capture in package.value.exactImages.entries) {
        final metadata = capture.value;
        if (metadata.testDescription == null) continue;
        var files = sorted
            .where((target) =>
                target.packagePath == package.key &&
                metadata.sourceTestFile != null &&
                p.posix.normalize(
                        p.posix.join(package.key, metadata.sourceTestFile!)) ==
                    target.path)
            .toList();
        if (metadata.sourceTestFile == null) {
          final marker = capture.key.split('/').indexOf('golden');
          if (marker >= 0) {
            final base = capture.key.split('/').take(marker).join('/');
            files = sorted
                .where((target) =>
                    target.packagePath == package.key &&
                    p.posix.dirname(target.path) == base)
                .toList();
          }
        }
        if (files.length != 1) continue;
        final known = scenarios.values
            .where((scenario) =>
                scenario.testId == files.single.id &&
                scenario.description == metadata.testDescription &&
                (metadata.scenario == null ||
                    scenario.name == metadata.scenario))
            .toList();
        if (known.length > 1) continue;
        final scenario = known.firstOrNull ??
            ReviewScenario(files.single.id, metadata.testDescription!,
                metadata.scenario ?? metadata.testDescription!, null);
        scenarios[scenario.id] = scenario;
        scenario.goldenDirectories.add(p.posix.dirname(capture.key));
      }
    }
    scopes['project'] = ReviewTestScope('project', 'project', project,
        sorted.map((target) => target.id).toList());
    for (final entry in folders.entries) {
      final id = 'folder:${base64Url.encode(utf8.encode(entry.key))}';
      scopes[id] = ReviewTestScope(id, 'folder', entry.key, entry.value);
    }
    for (final scenario in scenarios.values) {
      final target = targets[scenario.testId]!;
      scopes[scenario.id] = ReviewTestScope(scenario.id, 'scenario',
          '${target.path} › ${scenario.name}', [target.id],
          scenarioId: scenario.id);
    }
  }

  static bool _under(String parent, String child) =>
      parent == '.' || parent == child || p.posix.isWithin(parent, child);

  Future<List<ReviewTestSelection>> resolveScopes(Object? raw) async {
    if (raw is! List ||
        raw.isEmpty ||
        raw.length > 5000 ||
        raw.any((id) => id is! String || !scopes.containsKey(id))) {
      throw const FormatException('Choose discovered test scopes.');
    }
    final selected = <String, Set<String>?>{};
    for (final id in raw) {
      final scope = scopes[id]!;
      for (final file in scope.fileIds) {
        if (scope.scenarioId == null) {
          selected[file] = null;
        } else if (!selected.containsKey(file) || selected[file] != null) {
          (selected[file] ??= {}).add(scope.scenarioId!);
        }
      }
    }
    if (selected.isEmpty) {
      throw const GitReviewException('No test files in this scope.');
    }
    final result = <ReviewTestSelection>[];
    for (final entry in selected.entries) {
      result.add(ReviewTestSelection(await validate(entry.key),
          [for (final id in entry.value ?? <String>{}) scenarios[id]!]));
    }
    return result..sort((a, b) => a.target.path.compareTo(b.target.path));
  }

  Map<String, Object?> context(List<GitImageChange> images,
      {String? folder, bool wholeFiles = false}) {
    final ids = <String>{};
    final unresolved = <String>[];
    var entireFolder = false;
    if (wholeFiles) {
      for (final image
          in {for (final image in images) image.path: image}.values) {
        final scenarioFiles = _scenariosForImage(image)
            .map((scenario) => scenario.testId)
            .toSet();
        final candidates = scenarioFiles.length == 1
            ? scenarioFiles.toList()
            : _imageJson(image)['candidateIds'] as List<String>;
        if (candidates.length == 1) {
          ids.add(candidates.single);
        } else {
          unresolved.add(image.path);
        }
      }
    }
    if (folder != null) {
      final matchingFolders = scopes.values
          .where((scope) => scope.kind == 'folder' && scope.path == folder);
      if (matchingFolders.isNotEmpty) {
        ids.add(matchingFolders.single.id);
        entireFolder = true;
      } else if (p.posix.basename(folder) == 'golden') {
        ids.addAll(targets.values
            .where((target) =>
                p.posix.dirname(target.path) == p.posix.dirname(folder))
            .map((target) => target.id));
        entireFolder = ids.isNotEmpty;
      } else {
        for (final scenario in scenarios.values) {
          if (scenario.goldenDirectories.any((path) => _under(folder, path))) {
            ids.add(scenario.id);
          }
        }
      }
    }
    if (!entireFolder && !wholeFiles) {
      for (final image
          in {for (final image in images) image.path: image}.values) {
        final candidates = _scenariosForImage(image);
        if (candidates.length == 1) {
          ids.add(candidates.single.id);
        } else {
          unresolved.add(image.path);
        }
      }
    }
    return {
      'scopeIds': unresolved.isEmpty ? ids.toList() : <String>[],
      'unresolved': unresolved,
      'mapping': unresolved.isNotEmpty
          ? 'Could not map ${unresolved.length} image(s) unambiguously. Choose a scope manually; nothing will be skipped silently.'
          : ids.isEmpty
              ? 'No matching tests. Choose a scope manually.'
              : wholeFiles
                  ? 'Entire test files selected. Variant filters still apply.'
                  : folder != null
                      ? 'Scope: $folder. Includes discovered unchanged tests/scenarios; variant filters still apply.'
                      : 'Mapped ${images.map((image) => image.path).toSet().length} image(s) to their scenarios. All captures of each matching test run together.',
      'filters': images.length == 1 && folder == null
          ? _imageJson(images.single)['filters']
          : <String, Object>{},
    };
  }

  List<ReviewScenario> _scenariosForImage(GitImageChange image) {
    final matches = scenarios.values
        .where((scenario) =>
            scenario.goldenDirectories.any((path) => _under(path, image.path)))
        .toList();
    final metadata = _metadataFor(image);
    final exact = matches
        .where((scenario) =>
            metadata?.testDescription == scenario.description &&
            (metadata?.scenario == null || metadata?.scenario == scenario.name))
        .toList();
    return exact.isNotEmpty ? exact : matches;
  }

  GoldenImageMetadata? _metadataFor(GitImageChange image) {
    final matches = [
      for (final entry in _indexes.entries)
        if (_under(entry.key, image.path))
          if (entry.value.metadataFor(image.path) case final metadata?) metadata
    ];
    return matches.length == 1 ? matches.single : null;
  }

  Map<String, Object?> toJson({GitImageChange? image}) {
    final ordered = scopes.values.toList()
      ..sort((a, b) => a.path.compareTo(b.path));
    return {
      ..._imageJson(image),
      'scopes': ordered.map((scope) => scope.toJson()).toList(),
      if (image != null) 'context': context([image]),
    };
  }

  Map<String, Object?> _imageJson(GitImageChange? image) {
    final sorted = targets.values.toList()
      ..sort((a, b) => a.path.compareTo(b.path));
    final candidates = <String>{};
    GoldenImageMetadata? metadata;
    if (image != null) {
      for (final entry in _indexes.entries) {
        if (entry.key != '.' && !p.isWithin(entry.key, image.path)) continue;
        final match = entry.value.metadataFor(image.path);
        if (match?.sourceTestFile == null) continue;
        final path = p
            .normalize(p.join(entry.key, match!.sourceTestFile!))
            .split(p.separator)
            .join('/');
        final found = sorted.where((t) => t.path == path);
        if (found.length == 1) {
          candidates.add(found.single.id);
          metadata = match;
        }
      }
      if (candidates.isEmpty) {
        final segments = image.path.split('/');
        final marker = segments.indexOf('golden');
        if (marker >= 0) {
          final base = segments.take(marker).join('/');
          candidates.addAll(sorted
              .where((t) => p.posix.dirname(t.path) == base)
              .map((t) => t.id));
        }
      }
    }
    return {
      'tests': sorted.map((t) => t.toJson()).toList(),
      'suggestedTestId': candidates.length == 1 ? candidates.single : null,
      'candidateIds': candidates.toList(),
      'filters': metadata == null || candidates.length != 1
          ? <String, Object>{}
          : {
              'device': metadata.device,
              if (metadata.theme != null) 'theme': metadata.theme,
              if (metadata.locale != null) 'locale': metadata.locale,
              if (metadata.textScale != null)
                'textScale': '${metadata.textScale}',
              if (metadata.direction != null) 'direction': metadata.direction,
              if (metadata.platform != null) 'platform': metadata.platform,
              if (metadata.highContrast != null)
                'highContrast': '${metadata.highContrast}',
            },
      'mapping': metadata != null && candidates.length == 1
          ? 'Mapped from the run manifest.'
          : candidates.length == 1
              ? 'One test file beside this golden directory. Check the file before running.'
              : 'Choose a test file. No unambiguous image-to-test mapping is available.',
      'warnings': warnings,
    };
  }

  Future<ReviewTestTarget> validate(String id) async {
    final target = targets[id];
    if (target == null) {
      throw const GitReviewException('Choose a discovered test file.');
    }
    final root = repository.directory.path;
    final file = File(absolutePath(target.path));
    if (await FileSystemEntity.type(file.path, followLinks: false) !=
            FileSystemEntityType.file ||
        !p.isWithin(root, await file.resolveSymbolicLinks()) ||
        await file.resolveSymbolicLinks() != p.normalize(file.path)) {
      throw const GitReviewException(
          'Test file moved or became a symbolic link. Refresh the test list.');
    }
    return target;
  }

  static const _excluded = {
    'build',
    'node_modules',
    'golden',
    'goldens',
    'failures',
    'Pods',
    'vendor',
    'coverage',
  };
}

String _posix(String path) => path.split(p.separator).join('/');

/// Matches ff_golden's public legacy and coverage test-name formats.
final class ReviewTestFilters {
  ReviewTestFilters._(this.values);
  final Map<String, String> values;
  static const keys = {
    'name',
    'device',
    'theme',
    'locale',
    'textScale',
    'direction',
    'platform',
    'highContrast',
  };

  factory ReviewTestFilters.parse(Object? raw) {
    if (raw is! Map || raw.keys.any((k) => !keys.contains(k))) {
      throw const FormatException('Expected supported test filters.');
    }
    final values = <String, String>{};
    for (final entry in raw.entries) {
      final value = entry.value;
      if (value is! String ||
          value.length > 200 ||
          value.contains(RegExp(r'[\x00-\x1f]'))) {
        throw const FormatException(
            'Test filters must be short single-line strings.');
      }
      if (value.trim().isNotEmpty) values[entry.key as String] = value.trim();
    }
    if (values['textScale'] case final text?) {
      final scale = double.tryParse(text);
      if (scale == null || !scale.isFinite || scale <= 0) {
        throw const FormatException(
            'Text scale must be a positive finite number.');
      }
    }
    for (final entry in {
      'direction': {'ltr', 'rtl'},
      'platform': {'android', 'fuchsia', 'iOS', 'linux', 'macOS', 'windows'},
      'highContrast': {'true', 'false'},
    }.entries) {
      if (values.containsKey(entry.key) &&
          !entry.value.contains(values[entry.key])) {
        throw FormatException('Unsupported ${entry.key} filter.');
      }
    }
    return ReviewTestFilters._(values);
  }

  String? get pattern {
    final name = values['name'];
    if (values.keys.every((key) => key == 'name')) {
      return name == null ? null : RegExp.escape(name);
    }
    String axis(String key, String fallback) =>
        values[key] == null ? fallback : RegExp.escape(values[key]!);
    final locale = values['locale']
            ?.split(RegExp('[-_]'))
            .map(RegExp.escape)
            .join('[-_]') ??
        r'[^,:()\r\n]+';
    final scaleValue = double.tryParse(values['textScale'] ?? '');
    final scale = scaleValue == null
        ? r'[0-9.eE+-]+'
        : scaleValue < 1e21 && scaleValue == scaleValue.roundToDouble()
            ? '${scaleValue.toInt()}(?:\\.0+)?'
            : RegExp.escape('$scaleValue');
    final contrast = switch (values['highContrast']) {
      'true' => ', high-contrast',
      'false' => '',
      _ => '(?:, high-contrast)?',
    };
    final modern = '${axis('device', r'[^,\r\n]+')}, '
        '${axis('theme', r'[^,\r\n]+')}, $locale, ${scale}x text, '
        '${axis('direction', '(?:ltr|rtl)')}, '
        '${axis('platform', r'[^,()\r\n]+')}$contrast';
    final advanced = ['textScale', 'direction', 'platform', 'highContrast']
        .any(values.containsKey);
    final legacy = '${axis('device', r'[^:\r\n]+')}:$locale:'
        '${axis('theme', r'[^()\r\n]+')}';
    final suffix = advanced ? modern : '$modern|$legacy';
    return '^${name == null ? '' : '(?=[\\s\\S]*${RegExp.escape(name)})'}'
        '[\\s\\S]* \\((?:$suffix)\\)\$';
  }

  String? patternFor(List<ReviewScenario> scenarios) {
    if (scenarios.isEmpty) return pattern;
    final names = scenarios
        .map((scenario) => scenario.fullName == null
            ? '(?:[\\s\\S]* )?${RegExp.escape(scenario.description)}'
            : RegExp.escape(scenario.fullName!))
        .toSet()
        .join('|');
    final filter = pattern;
    final constraint = filter == null
        ? ''
        : filter.startsWith('^')
            ? '(?=${filter.substring(1)})'
            : '(?=[\\s\\S]*$filter)';
    return '^$constraint(?:$names) \\([^\\r\\n]*\\)\$';
  }
}
