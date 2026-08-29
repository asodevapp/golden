import 'dart:io';

/// Result from one external process invocation.
final class CommandResult {
  const CommandResult({
    required this.exitCode,
    required this.stdout,
    required this.stderr,
  });

  final int exitCode;
  final String stdout;
  final String stderr;
}

/// Injectable external process boundary used by optimization and installation.
abstract interface class CommandRunner {
  Future<CommandResult> run(String executable, List<String> arguments);
}

/// Runs commands directly without a shell, so paths are portable and quoted safely.
final class SystemCommandRunner implements CommandRunner {
  const SystemCommandRunner();

  @override
  Future<CommandResult> run(
    String executable,
    List<String> arguments,
  ) async {
    try {
      final result = await Process.run(executable, arguments);
      return CommandResult(
        exitCode: result.exitCode,
        stdout: result.stdout.toString(),
        stderr: result.stderr.toString(),
      );
    } on ProcessException catch (error) {
      return CommandResult(
        exitCode: 127,
        stdout: '',
        stderr: error.message,
      );
    }
  }
}
