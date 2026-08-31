import 'dart:io';

import 'package:path/path.dart' as p;

final class GitFixture {
  GitFixture._(this.directory);
  final Directory directory;
  static Future<GitFixture> create() async {
    final fixture =
        GitFixture._(await Directory.systemTemp.createTemp('ff_golden_git_'));
    await fixture.git(['init', '--quiet']);
    return fixture;
  }

  File file(String relative) => File(p.join(directory.path, relative));
  Future<void> write(String relative, List<int> bytes) async {
    final target = file(relative);
    await target.create(recursive: true);
    await target.writeAsBytes(bytes);
  }

  Future<ProcessResult> git(List<String> args) async {
    final result = await Process.run(
        'git',
        [
          '--literal-pathspecs',
          '-c',
          'user.name=FF Golden Test',
          '-c',
          'user.email=ff-golden-test@example.invalid',
          '-c',
          'commit.gpgSign=false',
          '-c',
          'core.hooksPath=${p.join(directory.path, '.no-hooks')}',
          ...args,
        ],
        workingDirectory: directory.path,
        stdoutEncoding: null);
    if (result.exitCode != 0) {
      throw StateError('git ${args.first}: ${result.stderr}');
    }
    return result;
  }

  Future<void> commitAll() async {
    await git(['add', '--all']);
    await git(['commit', '--quiet', '-m', 'fixture']);
  }

  Future<List<int>> blob(String revision) async =>
      (await git(['cat-file', 'blob', revision])).stdout as List<int>;
}
