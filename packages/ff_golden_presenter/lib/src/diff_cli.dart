import 'dart:async';
import 'dart:io';

import 'diff_cli_options.dart';
import 'diff_server.dart';
import 'git_image_review.dart';

Future<int> runDiff(
    List<String> arguments, StringSink output, StringSink errors) async {
  late final DiffCliOptions options;
  try {
    options = DiffCliOptions.parse(arguments);
  } on FormatException catch (error) {
    errors.writeln('Error: ${error.message}');
    errors.write(DiffCliOptions.parse(['--help']).usage);
    return 64;
  }
  if (options.showHelp) {
    output.write(options.usage);
    return 0;
  }
  DiffReviewServer? server;
  final signals = <StreamSubscription<ProcessSignal>>[];
  try {
    final repository = await GitImageRepository.open(
      project: Directory(options.project),
      input: options.input,
    );
    server = await DiffReviewServer.start(repository,
        port: options.port, flutterExecutable: options.flutterExecutable);
    output.writeln('FF Golden Changes: ${server.uri}');
    output.writeln(
        'Repository: ${repository.directory.path} (scope: ${repository.input})');
    output.writeln('Stage/unstage only selected images. '
        'Ignore writes $reviewIgnoreFileName. Press Ctrl-C to stop.');
    output.writeln(
        'Tests runs selected scenarios, files or folders with live logs (no baseline updates).');
    final stopped = Completer<void>();
    void stop(ProcessSignal _) {
      if (!stopped.isCompleted) stopped.complete();
    }

    signals.add(ProcessSignal.sigint.watch().listen(stop));
    if (!Platform.isWindows) {
      signals.add(ProcessSignal.sigterm.watch().listen(stop));
    }
    if (options.openBrowser) {
      try {
        final url = server.uri.toString();
        final result = Platform.isMacOS
            ? await Process.run('open', [url])
            : Platform.isWindows
                ? await Process.run('cmd', ['/c', 'start', '', url])
                : await Process.run('xdg-open', [url]);
        if (result.exitCode != 0) {
          errors.writeln(
              'Could not open a browser. Open ${server.uri} manually.');
        }
      } on ProcessException {
        errors
            .writeln('Could not open a browser. Open ${server.uri} manually.');
      }
    }
    await stopped.future;
    return 0;
  } on GitReviewException catch (error) {
    errors.writeln('Error: ${error.message}');
    return 69;
  } on SocketException catch (error) {
    errors.writeln('Error: could not start the local viewer: ${error.message}');
    return 69;
  } on FileSystemException catch (error) {
    errors.writeln('Error: ${error.message} (${error.path})');
    return 66;
  } finally {
    for (final subscription in signals) {
      await subscription.cancel();
    }
    await server?.close();
  }
}
