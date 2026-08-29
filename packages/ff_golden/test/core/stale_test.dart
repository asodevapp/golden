import 'dart:io';

import 'package:ff_golden/ff_golden.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory directory;

  setUp(() {
    directory = Directory.systemTemp.createTempSync('ff_golden_stale_');
  });

  tearDown(() {
    directory.deleteSync(recursive: true);
  });

  test('finds only PNG files outside the expected manifest', () {
    final scope = Directory.fromUri(
      directory.uri.resolve('golden/scenario/'),
    )..createSync(recursive: true);
    File.fromUri(scope.uri.resolve('expected.png')).writeAsBytesSync([1]);
    File.fromUri(scope.uri.resolve('stale.png')).writeAsBytesSync([1]);
    File.fromUri(scope.uri.resolve('notes.txt')).writeAsStringSync('ignored');

    expect(
      findStaleGoldenFiles(
        baseDirectory: directory.uri,
        expectedPaths: const ['golden/scenario/expected.png'],
        scope: 'golden/scenario',
      ),
      ['golden/scenario/stale.png'],
    );
  });
}
