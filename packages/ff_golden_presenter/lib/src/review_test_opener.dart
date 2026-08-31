import 'dart:async';
import 'dart:io';

import 'git_image_review.dart';

/// Receives only a catalog-validated absolute file path, never a shell command.
Future<void> openReviewTestFile(String path) async {
  final executable = Platform.isMacOS
      ? 'open'
      : Platform.isWindows
          ? 'rundll32.exe'
          : 'xdg-open';
  final arguments = Platform.isWindows
      ? ['url.dll,FileProtocolHandler', Uri.file(path).toString()]
      : [path];
  try {
    final result = await Process.run(executable, arguments, runInShell: false)
        .timeout(const Duration(seconds: 8));
    if (result.exitCode == 0) return;
  } on ProcessException {
    // The viewer can also run on a machine without a desktop opener.
  } on TimeoutException {
    throw const GitReviewException(
        'The system did not confirm opening the file. Check your editor.');
  }
  throw const GitReviewException(
      'Could not open the test. Configure a default application for .dart files on the machine running diff.');
}
