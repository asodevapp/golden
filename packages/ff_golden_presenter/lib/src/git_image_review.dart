import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

const reviewImageExtensions = {'png', 'jpg', 'jpeg', 'webp'};
const reviewMaxImageBytes = 32 * 1024 * 1024;
const reviewIgnoreFileName = '.golden_ignore';
const _maxIgnoreBytes = 1024 * 1024;

typedef GitLockUsageProbe = Future<bool?> Function(String path);

/// A Git change, with immutable blob IDs for HEAD/index and a working-file hash.
final class GitImageChange {
  GitImageChange({
    required this.path,
    required this.staged,
    required this.status,
    required this.beforeBlob,
    required this.afterBlob,
    this.workingHash,
    this.ignored = false,
  });

  final String path;
  final bool staged;
  final String status;
  final String? beforeBlob;
  final String? afterBlob;
  final String? workingHash;
  final bool ignored;

  String get id =>
      base64Url.encode(utf8.encode('${staged ? 'index' : 'work'}\u0000$path'));
  String get revision => sha256
      .convert(utf8.encode(
        '$id\u0000$status\u0000$beforeBlob\u0000$afterBlob\u0000$workingHash',
      ))
      .toString();
  bool get hasBefore => beforeBlob != null;
  bool get hasAfter => afterBlob != null || workingHash != null;

  Map<String, Object?> toJson() => {
        'id': id,
        'path': path,
        'staged': staged,
        'status': status,
        'revision': revision,
        'hasBefore': hasBefore,
        'hasAfter': hasAfter,
        'ignored': ignored,
      };
}

final class GitImageSnapshot {
  const GitImageSnapshot(this.changes, this.warnings);
  final List<GitImageChange> changes;
  final List<String> warnings;
}

final class GitReviewException implements Exception {
  const GitReviewException(this.message, {this.conflict = false});
  final String message;
  final bool conflict;
  @override
  String toString() => message;
}

/// Reviews Git, stages selected paths, and manages the local review ignore list.
final class GitImageRepository {
  GitImageRepository._(
    this.directory,
    this.input,
    this.projectDirectory,
    this._lockUsageProbe,
  );

  final Directory directory;
  final Directory projectDirectory;

  /// Repository-relative literal path scope; may include deleted directories.
  final String input;
  final _hashCache = <String, ({String stamp, String hash})>{};
  final GitLockUsageProbe _lockUsageProbe;

  static Future<GitImageRepository> open({
    required Directory project,
    String input = '.',
    GitLockUsageProbe? lockUsageProbe,
  }) async {
    final projectPath = await project.resolveSymbolicLinks();
    final result = await _git(projectPath, ['rev-parse', '--show-toplevel']);
    final root =
        p.normalize(utf8.decode(result.stdout as List<int>).trimRight());
    final inputPath = p.normalize(p.join(projectPath, input));
    if (!p.equals(inputPath, root) && !p.isWithin(root, inputPath)) {
      throw const GitReviewException(
          'Input must be inside the Git repository.');
    }
    return GitImageRepository._(
      Directory(root),
      p.relative(inputPath, from: root).split(p.separator).join('/'),
      Directory(projectPath),
      lockUsageProbe ?? _indexLockInUse,
    );
  }

  Future<GitImageSnapshot> scan({bool verifyWorkingBytes = false}) async {
    final ignored = _ignorePaths(await _readIgnoreFile());
    final changes = <GitImageChange>[];
    final warnings = <String>[];
    final conflicts = <String>{};
    final unmerged = await _text(['ls-files', '--unmerged', '-z', '--', input]);
    for (final record in unmerged.split('\u0000').where((v) => v.isNotEmpty)) {
      conflicts.add(record.substring(record.indexOf('\t') + 1));
    }
    for (final file in conflicts.where(_isImage)) {
      warnings.add('Resolve the Git conflict in your Git client: $file');
    }
    for (final staged in [false, true]) {
      final output = await _text([
        'diff',
        if (staged) '--cached',
        '--raw',
        '--no-abbrev',
        '-z',
        '--no-renames',
        '--no-ext-diff',
        '--no-textconv',
        '--diff-filter=AMD',
        '--',
        input,
      ]);
      final records = output.split('\u0000');
      for (var i = 0; i + 1 < records.length; i += 2) {
        final fields = records[i].split(' ');
        final file = records[i + 1];
        if (!_isImage(file) || conflicts.contains(file)) continue;
        if (fields.length != 5 || !fields.first.startsWith(':')) {
          throw const GitReviewException('Unexpected Git diff output.');
        }
        final beforeMode = fields[0].substring(1);
        final afterMode = fields[1];
        if (!_regularOrMissing(beforeMode) || !_regularOrMissing(afterMode)) {
          warnings.add(
              'Symbolic links and non-regular files are not reviewed: $file');
          continue;
        }
        final before = _blob(fields[2]);
        final after = staged ? _blob(fields[3]) : null;
        String? workingHash;
        if (!staged && fields[4] != 'D') {
          workingHash = await _hashWorkingFile(file, warnings,
              verify: verifyWorkingBytes);
          if (workingHash == null) continue;
        }
        changes.add(GitImageChange(
          path: file,
          staged: staged,
          status: fields[4],
          beforeBlob: before,
          afterBlob: after,
          workingHash: workingHash,
          ignored: ignored.contains(file),
        ));
      }
    }
    final untracked = await _text(
        ['ls-files', '--others', '--exclude-standard', '-z', '--', input]);
    for (final file in untracked.split('\u0000').where(_isImage)) {
      final hash =
          await _hashWorkingFile(file, warnings, verify: verifyWorkingBytes);
      if (hash == null) continue;
      changes.add(GitImageChange(
        path: file,
        staged: false,
        status: '?',
        beforeBlob: null,
        afterBlob: null,
        workingHash: hash,
        ignored: ignored.contains(file),
      ));
    }
    changes.sort((a, b) {
      if (a.staged != b.staged) return a.staged ? 1 : -1;
      return a.path.compareTo(b.path);
    });
    return GitImageSnapshot(changes, warnings);
  }

  Future<List<int>> readImage(GitImageChange change,
      {required bool before}) async {
    final blob = before ? change.beforeBlob : change.afterBlob;
    late final List<int> bytes;
    if (blob != null) {
      final size = int.parse((await _text(['cat-file', '-s', blob])).trim());
      if (size > reviewMaxImageBytes) {
        throw const GitReviewException(
            'Image exceeds the 32 MiB preview limit.');
      }
      bytes = (await _git(directory.path, ['cat-file', 'blob', blob])).stdout
          as List<int>;
    } else if (!before && change.workingHash != null) {
      final file = await _workingFile(change.path);
      bytes = await file.readAsBytes();
      if (sha256.convert(bytes).toString() != change.workingHash) {
        throw const GitReviewException('Image changed. Refresh the comparison.',
            conflict: true);
      }
    } else {
      throw const GitReviewException('This side of the image does not exist.');
    }
    if (utf8
        .decode(bytes.take(80).toList(), allowMalformed: true)
        .startsWith('version https://git-lfs.github.com/spec/')) {
      throw const GitReviewException(
          'Git LFS pointer: this MVP cannot preview LFS objects.');
    }
    return bytes;
  }

  /// Rejects stale selections before touching the index. Never writes worktree files.
  Future<bool> setStaged(Map<String, String> revisions,
      {required bool staged}) async {
    if (revisions.isEmpty || revisions.length > 500) {
      throw const GitReviewException('Select between 1 and 500 images.');
    }
    final snapshot = await scan(verifyWorkingBytes: true);
    final current = {for (final change in snapshot.changes) change.id: change};
    final paths = <String>[];
    for (final entry in revisions.entries) {
      final change = current[entry.key];
      if (change == null ||
          change.revision != entry.value ||
          change.ignored ||
          change.staged == staged) {
        throw const GitReviewException(
          'Selection changed since it was loaded. Review the refreshed images and try again.',
          conflict: true,
        );
      }
      paths.add(change.path);
    }
    if (staged) {
      return _mutateIndex(['add', '--', ...paths]);
    } else {
      final head = await _git(
          directory.path, ['rev-parse', '--verify', '--quiet', 'HEAD'],
          allowFailure: true);
      if (head.exitCode == 0) {
        return _mutateIndex(
            ['restore', '--staged', '--source=HEAD', '--', ...paths]);
      } else if (head.exitCode == 1) {
        // An unborn branch has no HEAD to restore. --cached preserves the files.
        return _mutateIndex(['rm', '--cached', '--force', '--', ...paths]);
      } else {
        // An interrupted Git process must never be mistaken for an unborn branch.
        throw const GitReviewException(
            'Could not read HEAD. The index was not changed; refresh and retry.');
      }
    }
  }

  /// Reverts only working-tree changes. The index and staged changes are kept.
  /// Untracked files are deleted after their content revision is revalidated.
  Future<({int restored, int deleted})> revertWorkingChanges(
      Map<String, String> revisions) async {
    if (revisions.isEmpty || revisions.length > 500) {
      throw const GitReviewException('Select between 1 and 500 images.');
    }
    final snapshot = await scan(verifyWorkingBytes: true);
    final current = {for (final change in snapshot.changes) change.id: change};
    final trackedPaths = <String>{};
    final untracked = <GitImageChange>[];
    for (final entry in revisions.entries) {
      final change = current[entry.key];
      if (change == null || change.revision != entry.value || change.staged) {
        throw const GitReviewException(
          'Selection changed since it was loaded. Only current unstaged changes can be reverted.',
          conflict: true,
        );
      }
      if (change.status == '?') {
        untracked.add(change);
      } else {
        trackedPaths.add(change.path);
      }
    }

    final untrackedFiles = <File>[];
    for (final change in untracked) {
      final warnings = <String>[];
      final currentHash = await _hashWorkingFile(
        change.path,
        warnings,
        verify: true,
      );
      if (currentHash == null || currentHash != change.workingHash) {
        throw const GitReviewException(
          'An untracked image changed. Nothing was reverted; refresh and try again.',
          conflict: true,
        );
      }
      untrackedFiles.add(await _workingFile(change.path));
    }

    if (trackedPaths.isNotEmpty) {
      await _text(['restore', '--worktree', '--', ...trackedPaths]);
    }
    for (final file in untrackedFiles) {
      await file.delete();
    }
    for (final path in [...trackedPaths, ...untracked.map((c) => c.path)]) {
      _hashCache.remove(path);
    }
    return (restored: trackedPaths.length, deleted: untrackedFiles.length);
  }

  Future<bool> _mutateIndex(List<String> arguments) async {
    try {
      await _text(arguments);
      return false;
    } on GitReviewException catch (error) {
      final recovery = await _recoverStaleIndexLock(error.message);
      if (!recovery.retry) rethrow;
      await _text(arguments);
      return recovery.removed;
    }
  }

  Future<({bool retry, bool removed})> _recoverStaleIndexLock(
      String message) async {
    if (!message.contains('Unable to create') ||
        !message.contains('index.lock') ||
        !message.contains('File exists')) {
      return (retry: false, removed: false);
    }
    final gitDirectoryResult = await _git(
      directory.path,
      ['rev-parse', '--absolute-git-dir'],
      allowFailure: true,
    );
    final lockResult = await _git(
      directory.path,
      ['rev-parse', '--git-path', 'index.lock'],
      allowFailure: true,
    );
    if (gitDirectoryResult.exitCode != 0 || lockResult.exitCode != 0) {
      return (retry: false, removed: false);
    }
    final gitDirectory = p.normalize(
      utf8.decode(gitDirectoryResult.stdout as List<int>).trimRight(),
    );
    final reportedLock =
        utf8.decode(lockResult.stdout as List<int>).trimRight();
    final lockPath = p.normalize(p.isAbsolute(reportedLock)
        ? reportedLock
        : p.join(directory.path, reportedLock));
    if (!p.equals(lockPath, p.join(gitDirectory, 'index.lock')) ||
        !message.contains(lockPath)) {
      return (retry: false, removed: false);
    }
    final type = await FileSystemEntity.type(lockPath, followLinks: false);
    if (type == FileSystemEntityType.notFound) {
      return (retry: true, removed: false);
    }
    if (type != FileSystemEntityType.file) {
      return (retry: false, removed: false);
    }

    final lock = File(lockPath);
    final beforeProbe = await lock.stat();
    final inUse = await _lockUsageProbe(lockPath);
    final afterType = await FileSystemEntity.type(lockPath, followLinks: false);
    if (afterType == FileSystemEntityType.notFound) {
      return (retry: true, removed: false);
    }
    if (inUse != false || afterType != FileSystemEntityType.file) {
      return (retry: false, removed: false);
    }
    final afterProbe = await lock.stat();
    if (beforeProbe.type != afterProbe.type ||
        beforeProbe.size != afterProbe.size ||
        beforeProbe.modified != afterProbe.modified ||
        beforeProbe.changed != afterProbe.changed) {
      return (retry: false, removed: false);
    }
    try {
      await lock.delete();
      return (retry: true, removed: true);
    } on FileSystemException {
      final disappeared =
          await FileSystemEntity.type(lockPath, followLinks: false) ==
              FileSystemEntityType.notFound;
      return (retry: disappeared, removed: false);
    }
  }

  /// Changes only .golden_ignore; never stages paths or rewrites image files.
  Future<void> setIgnored(Map<String, String> revisions,
      {required bool ignored}) async {
    if (revisions.isEmpty || revisions.length > 500) {
      throw const GitReviewException('Select between 1 and 500 images.');
    }
    final original = await _readIgnoreFile();
    final snapshot = await scan(verifyWorkingBytes: true);
    final current = {for (final change in snapshot.changes) change.id: change};
    final paths = <String>{};
    for (final entry in revisions.entries) {
      final change = current[entry.key];
      if (change == null || change.revision != entry.value) {
        throw const GitReviewException(
          'Selection changed since it was loaded. Review the refreshed images and try again.',
          conflict: true,
        );
      }
      if (change.path.contains(RegExp(r'[\r\n]'))) {
        throw const GitReviewException(
            '.golden_ignore cannot store file names containing line breaks.');
      }
      paths.add(change.path);
    }
    late final String updated;
    if (ignored) {
      final additions = paths.difference(_ignorePaths(original)).toList()
        ..sort();
      if (additions.isEmpty) return;
      final content = original ??
          '# FF Golden diff: exact paths relative to the Git repository root.\n'
              '# Only the review is filtered; Git and golden tests are unchanged.\n';
      // A leading slash also makes file names starting with # unambiguous.
      updated =
          '$content${content.isNotEmpty && !content.endsWith('\n') ? '\n' : ''}'
          '${additions.map((path) => '/$path\n').join()}';
    } else {
      if (original == null) return;
      updated = original
          .split('\n')
          .where((line) => !paths.contains(_ignorePath(line)))
          .join('\n');
      if (updated == original) return;
    }
    if (utf8.encode(updated).length > _maxIgnoreBytes) {
      throw const GitReviewException('.golden_ignore exceeds the 1 MiB limit.');
    }
    // Replace rather than append so symlinks/hard links cannot redirect a write.
    final temporary = await directory.createTemp('.ff-golden-ignore-');
    try {
      final replacement = File(p.join(temporary.path, 'ignore'));
      await replacement.writeAsString(updated, flush: true);
      if (await _readIgnoreFile() != original) {
        throw const GitReviewException(
            '.golden_ignore changed while saving. Refresh and try again.',
            conflict: true);
      }
      await replacement.rename(p.join(directory.path, reviewIgnoreFileName));
    } finally {
      await temporary.delete(recursive: true);
    }
  }

  Future<String?> _readIgnoreFile() async {
    final file = File(p.join(directory.path, reviewIgnoreFileName));
    final type = await FileSystemEntity.type(file.path, followLinks: false);
    if (type == FileSystemEntityType.notFound) return null;
    if (type != FileSystemEntityType.file) {
      throw const GitReviewException(
          '.golden_ignore must be a regular file, not a symbolic link or directory.');
    }
    if (await file.length() > _maxIgnoreBytes) {
      throw const GitReviewException('.golden_ignore exceeds the 1 MiB limit.');
    }
    return file.readAsString();
  }

  static Set<String> _ignorePaths(String? content) =>
      (content ?? '').split('\n').map(_ignorePath).whereType<String>().toSet();

  static String? _ignorePath(String line) {
    if (line.endsWith('\r')) line = line.substring(0, line.length - 1);
    if (line.trim().isEmpty || line.startsWith('#')) return null;
    return line.startsWith('/') ? line.substring(1) : line;
  }

  Future<String?> _hashWorkingFile(String file, List<String> warnings,
      {bool verify = false}) async {
    try {
      final source = await _workingFile(file);
      final stat = await source.stat();
      final stamp =
          '${stat.size}:${stat.modified.microsecondsSinceEpoch}:${stat.changed.microsecondsSinceEpoch}';
      final cached = _hashCache[file];
      if (!verify && cached?.stamp == stamp) return cached!.hash;
      final hash = (await sha256.bind(source.openRead()).first).toString();
      _hashCache[file] = (stamp: stamp, hash: hash);
      return hash;
    } on FileSystemException {
      warnings.add('File changed while scanning; refresh to retry: $file');
    } on GitReviewException catch (error) {
      warnings.add('${error.message} ($file)');
    }
    return null;
  }

  Future<File> _workingFile(String relative) async {
    final absolute = p.joinAll([directory.path, ...p.posix.split(relative)]);
    if (!p.isWithin(directory.path, p.normalize(absolute)) ||
        await FileSystemEntity.type(absolute, followLinks: false) !=
            FileSystemEntityType.file) {
      throw const GitReviewException(
          'Preview requires a regular file inside the repository.');
    }
    final file = File(absolute);
    final resolved = await file.resolveSymbolicLinks();
    if (!p.isWithin(directory.path, resolved)) {
      throw const GitReviewException(
          'Preview cannot follow links outside the repository.');
    }
    if (await file.length() > reviewMaxImageBytes) {
      throw const GitReviewException('Image exceeds the 32 MiB preview limit.');
    }
    return file;
  }

  Future<String> _text(List<String> arguments) async =>
      utf8.decode((await _git(directory.path, arguments)).stdout as List<int>);

  static bool _regularOrMissing(String mode) =>
      mode == '000000' || mode.startsWith('100');
  static String? _blob(String value) =>
      RegExp(r'^0+$').hasMatch(value) ? null : value;
  static bool _isImage(String file) => reviewImageExtensions
      .contains(p.extension(file).replaceFirst('.', '').toLowerCase());

  static Future<bool?> _indexLockInUse(String path) async {
    if (Platform.isWindows) return null;
    try {
      final result = await Process.run(
        'lsof',
        ['-t', '--', path],
        stdoutEncoding: utf8,
        stderrEncoding: utf8,
      );
      final output = (result.stdout as String).trim();
      final errors = (result.stderr as String).trim();
      if (result.exitCode == 0) return output.isNotEmpty;
      if (result.exitCode == 1 && output.isEmpty && errors.isEmpty) {
        return false;
      }
      return null;
    } on ProcessException {
      return null;
    }
  }

  static Future<ProcessResult> _git(String directory, List<String> arguments,
      {bool allowFailure = false}) async {
    try {
      final result = await Process.run(
        'git',
        [
          '--no-optional-locks',
          '--literal-pathspecs',
          '-c',
          'core.fsmonitor=false',
          ...arguments
        ],
        workingDirectory: directory,
        stdoutEncoding: null,
      );
      if (result.exitCode != 0 && !allowFailure) {
        throw GitReviewException(result.stderr.toString().trim());
      }
      return result;
    } on ProcessException {
      throw const GitReviewException(
          'Git was not found. Install Git and ensure it is on PATH.');
    }
  }
}
