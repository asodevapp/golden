import 'dart:io';

import 'package:path/path.dart' as path;

enum MigrationFindingKind { safeChange, manualReview }

final class MigrationFinding {
  const MigrationFinding({
    required this.kind,
    required this.filePath,
    required this.line,
    required this.message,
  });

  final MigrationFindingKind kind;
  final String filePath;
  final int line;
  final String message;
}

final class MigrationResult {
  const MigrationResult({
    required this.scannedFiles,
    required this.changedFiles,
    required this.safeChanges,
    required this.manualReviews,
    required this.applied,
  });

  final int scannedFiles;
  final int changedFiles;
  final List<MigrationFinding> safeChanges;
  final List<MigrationFinding> manualReviews;
  final bool applied;

  bool get isClean => safeChanges.isEmpty && manualReviews.isEmpty;
}

/// Audits a project for the `golden` -> `ff_golden` package migration.
///
/// With [apply] enabled, only unambiguous package/import/command/type renames
/// are written. Device geometry and custom scripts are intentionally left for
/// manual review.
final class FfGoldenProjectMigrator {
  FfGoldenProjectMigrator({required Directory projectDirectory})
      : _projectDirectory = projectDirectory;

  final Directory _projectDirectory;

  static const _excludedDirectories = {
    '.dart_tool',
    '.git',
    '.idea',
    'build',
    'coverage',
    'node_modules',
    'Pods',
  };

  static const _supportedExtensions = {
    '.dart',
    '.json',
    '.md',
    '.sh',
    '.tmpl',
    '.bash',
    '.zsh',
    '.yaml',
    '.yml',
  };

  Future<MigrationResult> run({bool apply = false}) async {
    final root = path.normalize(path.absolute(_projectDirectory.path));
    if (!await Directory(root).exists()) {
      throw FileSystemException('Project directory does not exist', root);
    }

    final safeChanges = <MigrationFinding>[];
    final manualReviews = <MigrationFinding>[];
    var scannedFiles = 0;
    var changedFiles = 0;

    await for (final entity in Directory(root).list(
      recursive: true,
      followLinks: false,
    )) {
      if (entity is! File || !_shouldScan(root, entity.path)) continue;
      if (await entity.length() > 2 * 1024 * 1024) continue;
      scannedFiles++;

      final relativePath = path.relative(entity.path, from: root);
      final original = await entity.readAsString();
      var migrated = original;
      for (final rule in _rulesFor(entity.path)) {
        final matches = rule.pattern.allMatches(migrated).toList();
        for (final match in matches) {
          safeChanges.add(
            MigrationFinding(
              kind: MigrationFindingKind.safeChange,
              filePath: relativePath,
              line: _lineNumber(migrated, match.start),
              message: rule.message,
            ),
          );
        }
        migrated = migrated.replaceAllMapped(rule.pattern, rule.replace);
      }
      if ({'.dart', '.tmpl'}.contains(path.extension(entity.path)) &&
          migrated.contains('package:ff_golden/ff_golden.dart')) {
        for (final rule in _dartPublicAliasRules) {
          final matches = rule.pattern.allMatches(migrated).toList();
          for (final match in matches) {
            safeChanges.add(
              MigrationFinding(
                kind: MigrationFindingKind.safeChange,
                filePath: relativePath,
                line: _lineNumber(migrated, match.start),
                message: rule.message,
              ),
            );
          }
          migrated = migrated.replaceAllMapped(rule.pattern, rule.replace);
        }
        final orderedImports = _orderFfGoldenImport(migrated);
        if (orderedImports != migrated) {
          safeChanges.add(
            MigrationFinding(
              kind: MigrationFindingKind.safeChange,
              filePath: relativePath,
              line: _ffGoldenImportLine(migrated),
              message: 'sort the ff_golden package import',
            ),
          );
          migrated = orderedImports;
        }
      }
      if (path.basename(entity.path) == 'pubspec.yaml') {
        final workspacePaths = _addWorkspacePaths(relativePath, migrated);
        migrated = workspacePaths.source;
        safeChanges.addAll(workspacePaths.findings);
      }

      manualReviews.addAll(
        _manualFindings(relativePath, entity.path, migrated),
      );
      if (apply && migrated != original) {
        await entity.writeAsString(migrated, flush: true);
        changedFiles++;
      }
    }

    _sort(safeChanges);
    _sort(manualReviews);
    return MigrationResult(
      scannedFiles: scannedFiles,
      changedFiles: changedFiles,
      safeChanges: List.unmodifiable(safeChanges),
      manualReviews: List.unmodifiable(manualReviews),
      applied: apply,
    );
  }

  bool _shouldScan(String root, String filePath) {
    final relative = path.relative(filePath, from: root);
    final segments = path.split(relative);
    if (segments.any(_excludedDirectories.contains)) return false;
    final basename = path.basename(filePath);
    return _supportedExtensions.contains(path.extension(basename)) ||
        basename == 'Dockerfile' ||
        basename == 'Makefile';
  }

  Iterable<_MigrationRule> _rulesFor(String filePath) sync* {
    yield* _generalRules;
    if (path.basename(filePath) == 'pubspec.yaml') {
      yield const _MigrationRule(
        pattern: r'^([ \t]*)golden:([ \t]*(?:#.*)?)$',
        replacement: r'$1ff_golden:$2',
        message: 'rename the golden dependency to ff_golden',
        multiLine: true,
      );
      yield const _MigrationRule(
        pattern: r'^([ \t]*)golden_presenter:([ \t]*(?:#.*)?)$',
        replacement: r'$1ff_golden_presenter:$2',
        message: 'rename the golden_presenter dependency',
        multiLine: true,
      );
    }
  }

  List<MigrationFinding> _manualFindings(
    String relativePath,
    String absolutePath,
    String source,
  ) {
    final result = <MigrationFinding>[];
    void add(RegExp pattern, String message) {
      for (final match in pattern.allMatches(source)) {
        result.add(
          MigrationFinding(
            kind: MigrationFindingKind.manualReview,
            filePath: relativePath,
            line: _lineNumber(source, match.start),
            message: message,
          ),
        );
      }
    }

    add(
      RegExp(r"package:golden/src/"),
      'replace private golden imports with package:ff_golden/ff_golden.dart',
    );
    add(
      RegExp(r'\bgolden\.sh\b'),
      'replace the project shell pipeline with ff_golden_presenter build',
    );
    add(
      RegExp(r'https://github\.com/Gorniv/golden_presenter(?:\.git)?'),
      'use the Gorniv/golden repository and packages/ff_golden_presenter path',
    );

    add(
      RegExp(
        r'\b(?:const\s+)?(?:Device|GoldenDevice)\s*\([^;]*?\bsize\s*:',
        dotAll: true,
      ),
      'convert physical Device(size:) to GoldenDevice('
      'logicalSize: physicalSize / devicePixelRatio) manually',
    );
    if (source.contains('package:ff_golden/ff_golden.dart')) {
      add(
        RegExp(r'\b(?:device|GoldenDevice\.[A-Za-z0-9_]+)\.size\b'),
        'replace deprecated device.size with logicalSize or physicalSize',
      );
    }

    if (path.basename(absolutePath) == 'pubspec.yaml') {
      result.addAll(
        _missingWorkspacePaths(relativePath, source),
      );
    }
    return result;
  }

  List<MigrationFinding> _missingWorkspacePaths(
    String relativePath,
    String source,
  ) {
    final lines = source.split('\n');
    final result = <MigrationFinding>[];
    for (final package in const ['ff_golden', 'ff_golden_presenter']) {
      for (var index = 0; index < lines.length; index++) {
        final match = RegExp('^([ \\t]*)$package:[ \\t]*(?:#.*)?\$')
            .firstMatch(lines[index]);
        if (match == null) continue;
        final indentation = match.group(1)!.length;
        final block = <String>[];
        for (var cursor = index + 1; cursor < lines.length; cursor++) {
          final line = lines[cursor];
          if (line.trim().isNotEmpty && _indentation(line) <= indentation) {
            break;
          }
          block.add(line);
        }
        final joined = block.join('\n');
        if (RegExp(r'^\s*git\s*:', multiLine: true).hasMatch(joined) &&
            !RegExp('^\\s*path\\s*:\\s*packages/$package\\s*\$',
                    multiLine: true)
                .hasMatch(joined)) {
          result.add(
            MigrationFinding(
              kind: MigrationFindingKind.manualReview,
              filePath: relativePath,
              line: index + 1,
              message: 'add git.path: packages/$package',
            ),
          );
        }
      }
    }
    return result;
  }

  _WorkspacePathMigration _addWorkspacePaths(
    String relativePath,
    String source,
  ) {
    final lines = source.split('\n');
    final findings = <MigrationFinding>[];
    for (final package in const ['ff_golden', 'ff_golden_presenter']) {
      for (var index = 0; index < lines.length; index++) {
        final packageMatch = RegExp(
          '^([ \\t]*)$package:[ \\t]*(?:#.*)?\$',
        ).firstMatch(lines[index]);
        if (packageMatch == null) continue;
        final packageIndent = packageMatch.group(1)!.length;
        var blockEnd = lines.length;
        for (var cursor = index + 1; cursor < lines.length; cursor++) {
          final line = lines[cursor];
          if (line.trim().isNotEmpty && _indentation(line) <= packageIndent) {
            blockEnd = cursor;
            break;
          }
        }

        int? gitLine;
        int? gitIndent;
        for (var cursor = index + 1; cursor < blockEnd; cursor++) {
          if (RegExp(r'^\s*git\s*:\s*(?:#.*)?$').hasMatch(lines[cursor])) {
            gitLine = cursor;
            gitIndent = _indentation(lines[cursor]);
            break;
          }
        }
        if (gitLine == null || gitIndent == null) continue;

        int? urlLine;
        var hasPath = false;
        for (var cursor = gitLine + 1; cursor < blockEnd; cursor++) {
          final line = lines[cursor];
          if (line.trim().isNotEmpty && _indentation(line) <= gitIndent) break;
          if (RegExp(r'^\s*path\s*:').hasMatch(line)) hasPath = true;
          if (RegExp(
            r'^\s*url\s*:\s*https://github\.com/Gorniv/golden(?:\.git)?\s*(?:#.*)?$',
          ).hasMatch(line)) {
            urlLine = cursor;
          }
        }
        if (hasPath || urlLine == null) continue;

        final indentation = lines[urlLine].substring(
          0,
          _indentation(lines[urlLine]),
        );
        lines.insert(urlLine + 1, '$indentation' 'path: packages/$package');
        findings.add(
          MigrationFinding(
            kind: MigrationFindingKind.safeChange,
            filePath: relativePath,
            line: urlLine + 1,
            message: 'add git.path: packages/$package',
          ),
        );
        break;
      }
    }
    return _WorkspacePathMigration(lines.join('\n'), findings);
  }

  int _indentation(String line) => line.length - line.trimLeft().length;

  String _orderFfGoldenImport(String source) {
    final lines = source.split('\n');
    final targetPattern = RegExp(
      r'''^import ['"]package:ff_golden/ff_golden\.dart['"];$''',
    );
    final targetIndex = lines.indexWhere(targetPattern.hasMatch);
    if (targetIndex < 0) return source;

    final targetLine = lines.removeAt(targetIndex);
    final packagePattern = RegExp(r'''^import ['"](package:[^'"]+)['"]''');
    const targetUri = 'package:ff_golden/ff_golden.dart';
    int? insertionIndex;
    var lastPackageImport = -1;
    for (var index = 0; index < lines.length; index++) {
      final match = packagePattern.firstMatch(lines[index]);
      if (match == null) continue;
      lastPackageImport = index;
      if (insertionIndex == null && match.group(1)!.compareTo(targetUri) > 0) {
        insertionIndex = index;
      }
    }
    lines.insert(
      insertionIndex ??
          (lastPackageImport < 0 ? targetIndex : lastPackageImport + 1),
      targetLine,
    );
    return lines.join('\n');
  }

  int _ffGoldenImportLine(String source) {
    final offset = source.indexOf('package:ff_golden/ff_golden.dart');
    return offset < 0 ? 1 : _lineNumber(source, offset);
  }

  static int _lineNumber(String source, int offset) =>
      '\n'.allMatches(source.substring(0, offset)).length + 1;

  static void _sort(List<MigrationFinding> findings) {
    findings.sort((left, right) {
      final file = left.filePath.compareTo(right.filePath);
      return file != 0 ? file : left.line.compareTo(right.line);
    });
  }
}

final class _MigrationRule {
  const _MigrationRule({
    required String pattern,
    required this.replacement,
    required this.message,
    this.multiLine = false,
  }) : patternSource = pattern;

  final String patternSource;
  final String replacement;
  final String message;
  final bool multiLine;

  RegExp get pattern => RegExp(patternSource, multiLine: multiLine);

  String replace(Match match) {
    var value = replacement;
    for (var index = match.groupCount; index >= 0; index--) {
      value = value.replaceAll('\$$index', match.group(index) ?? '');
    }
    return value;
  }
}

final class _WorkspacePathMigration {
  const _WorkspacePathMigration(this.source, this.findings);

  final String source;
  final List<MigrationFinding> findings;
}

const _generalRules = <_MigrationRule>[
  _MigrationRule(
    pattern: r'package:golden/golden\.dart',
    replacement: 'package:ff_golden/ff_golden.dart',
    message: 'replace the golden package import',
  ),
  _MigrationRule(
    pattern: r'package:golden_presenter/golden_presenter\.dart',
    replacement: 'package:ff_golden_presenter/ff_golden_presenter.dart',
    message: 'replace the golden_presenter package import',
  ),
  _MigrationRule(
    pattern:
        r'https://github\.com/Gorniv/golden_presenter(?:\.git)?(?=[\s\x27\x22/]|$)',
    replacement: 'https://github.com/Gorniv/golden.git',
    message: 'move the presenter dependency to the golden monorepository',
  ),
  _MigrationRule(
    pattern: r'flutter\s+pub\s+run\s+golden_presenter:golden_presenter',
    replacement: 'dart run ff_golden_presenter',
    message: 'replace the legacy Flutter Pub presenter command',
  ),
  _MigrationRule(
    pattern:
        r'dart\s+pub\s+global\s+run\s+golden_presenter(?::golden_presenter)?',
    replacement: 'dart run ff_golden_presenter',
    message: 'replace global presenter activation with a local command',
  ),
  _MigrationRule(
    pattern: r'dart\s+run\s+golden_presenter\b',
    replacement: 'dart run ff_golden_presenter',
    message: 'rename the presenter executable',
  ),
  _MigrationRule(
    pattern: r'packages/golden_presenter\b',
    replacement: 'packages/ff_golden_presenter',
    message: 'update the presenter Git workspace path',
  ),
  _MigrationRule(
    pattern: r'packages/golden\b',
    replacement: 'packages/ff_golden',
    message: 'update the runner Git workspace path',
  ),
];

const _dartPublicAliasRules = <_MigrationRule>[
  _MigrationRule(
    pattern: r'\bDevice\b(?!\s*\()',
    replacement: 'GoldenDevice',
    message: 'replace the legacy Device alias with GoldenDevice',
  ),
  _MigrationRule(
    pattern: r'\bNamedTheme\b',
    replacement: 'GoldenTheme',
    message: 'replace the legacy NamedTheme alias with GoldenTheme',
  ),
];
