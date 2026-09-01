import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'git_image_review.dart';
import 'review_test_catalog.dart';
import 'review_test_log.dart';
import 'review_test_variants.dart';

final class ReviewTestCommand {
  const ReviewTestCommand(
      this.executable, this.arguments, this.directory, this.selection);
  final String executable;
  final List<String> arguments;
  final String directory;
  final ReviewTestSelection selection;
  String get command => [executable, ...arguments].map((part) {
        if (RegExp(r'^[A-Za-z0-9_./:=+,-]+$').hasMatch(part)) return part;
        return "'${part.replaceAll("'", "'\\''")}'";
      }).join(' ');
  Map<String, Object> toJson() => {
        'command': command,
        'directory': directory,
        'file': selection.target.path,
        'testId': selection.target.id,
        'scenarios':
            selection.scenarios.map((scenario) => scenario.name).toList(),
      };
}

final class ReviewTestPlan {
  const ReviewTestPlan(this.commands,
      {this.discovery = false, this.filters = const {}});
  final List<ReviewTestCommand> commands;
  final bool discovery;
  final Map<String, String> filters;
  Map<String, Object> toJson() => {
        'commands': commands.map((command) => command.toJson()).toList(),
        'fileCount': commands.length,
        'discovery': discovery,
        'filters': filters,
      };
}

/// One queue per viewer. Every command has an explicit, revalidated file and
/// its own name filter; scenario filters never leak into neighboring files.
final class ReviewTestRunner {
  ReviewTestRunner(this.catalog, {this.flutterExecutable});
  final ReviewTestCatalog catalog;
  final String? flutterExecutable;
  Process? _process;
  Future<Process>? _launch;
  Future<int>? _processDone;
  Future<void>? _batch;
  Future<void>? _stopping;
  String? _id;
  String _status = 'idle';
  ReviewTestPlan? _plan;
  DateTime? _started, _finished;
  int? _exitCode;
  bool _cancelRequested = false, _preparing = false, _closed = false;
  int _runNumber = 0, _sequence = 0, _logSize = 0, _currentIndex = -1;
  final _logs = Queue<Map<String, Object>>();
  final _results = <Map<String, Object?>>[];
  bool get active =>
      _preparing || _status == 'running' || _status == 'stopping';
  String? get runId => _id;

  Future<ReviewTestPlan> plan(Object? body, {bool discovery = false}) async {
    if (body is! Map ||
        body.keys.any((key) =>
            key != 'testId' && key != 'scopeIds' && key != 'filters') ||
        body.containsKey('testId') == body.containsKey('scopeIds') ||
        (body.containsKey('testId') && body['testId'] is! String)) {
      throw const FormatException('Expected test scopes and filters.');
    }
    final selections = body.containsKey('testId')
        ? [
            ReviewTestSelection(
                await catalog.validate(body['testId'] as String), const [])
          ]
        : await catalog.resolveScopes(body['scopeIds']);
    final filters = ReviewTestFilters.parse(body['filters']);
    final jobs = <ReviewTestCommand>[
      for (final selection in selections)
        if (discovery || _hasMatches(selection, filters))
          ReviewTestCommand(
            _resolveFlutter(catalog.absolutePath(selection.target.packagePath)),
            [
              'test',
              '--no-pub',
              discovery ? '--tags=ff_golden_discovery' : '--tags=golden',
              '--concurrency=1',
              if (discovery) '--dart-define=FF_GOLDEN_DISCOVERY=true',
              discovery ? '--reporter=json' : '--reporter=expanded',
              if (!discovery)
                if (filters.patternFor(selection.scenarios)
                    case final pattern?) ...['--name', pattern],
              './${selection.target.relativePath}',
            ],
            catalog.absolutePath(selection.target.packagePath),
            selection,
          ),
    ];
    if (jobs.isEmpty) {
      throw const FormatException('No golden variants match these filters.');
    }
    return ReviewTestPlan(jobs,
        discovery: discovery,
        filters: discovery ? const {} : Map.unmodifiable(filters.values));
  }

  bool _hasMatches(ReviewTestSelection selection, ReviewTestFilters filters) {
    if (!catalog.hasCompleteVariants(selection)) return true;
    final values = catalog.variantsFor(selection);
    if (values == null) return true;
    final pattern = filters.patternFor(selection.scenarios);
    return values.any(
        (value) => pattern == null || RegExp(pattern).hasMatch(value.fullName));
  }

  Future<void> start(Object? body, {bool discovery = false}) async {
    if (Platform.isWindows) {
      throw const GitReviewException(
          'The Tests panel currently runs on macOS and Linux. On Windows, run the preview commands in your terminal.');
    }
    if (_closed || active) {
      throw const GitReviewException(
          'A test queue is already running or the viewer is closing.',
          conflict: true);
    }
    _preparing = true;
    try {
      final next = await plan(body, discovery: discovery);
      _id = '${++_runNumber}';
      _plan = next;
      _status = 'running';
      _started = DateTime.now().toUtc();
      _finished = null;
      _exitCode = null;
      _logs.clear();
      _results.clear();
      _logSize = 0;
      _sequence = 0;
      _currentIndex = -1;
      _cancelRequested = false;
      _stopping = null;
      _batch = _runQueue(next);
    } finally {
      _preparing = false;
    }
  }

  Future<void> _runQueue(ReviewTestPlan plan) async {
    var failed = false;
    try {
      for (var index = 0; index < plan.commands.length; index++) {
        if (_cancelRequested) break;
        _currentIndex = index;
        final job = plan.commands[index];
        _append('system',
            '\n[${index + 1}/${plan.commands.length}] ${job.selection.target.path}\n\$ ${job.command}\n');
        int? code;
        final variants = plan.discovery ? ReviewVariantReader() : null;
        try {
          // Recheck queued files immediately before launch, not only at preview.
          await catalog.validate(job.selection.target.id);
          if (_cancelRequested) break;
          if (plan.discovery) catalog.forgetVariants(job.selection.target);
          _launch = Process.start(job.executable, job.arguments,
              workingDirectory: job.directory,
              environment: {'TERM': 'dumb', 'NO_COLOR': '1', 'CLICOLOR': '0'},
              runInShell: false);
          final process = await _launch!;
          _process = process;
          _launch = null;
          _processDone = _observe(process, variants: variants);
          code = await _processDone;
          if (variants != null && !_cancelRequested) {
            if (code == 0 &&
                variants.error == null &&
                variants.variants.isNotEmpty) {
              catalog.rememberVariants(job.selection.target, variants.variants);
              _append('system',
                  'Loaded ${variants.variants.length} variants. No golden callbacks or comparisons ran.\n');
            } else {
              code = code == 0 ? 1 : code;
              _append('stderr',
                  '${variants.error ?? 'No variants loaded. This requires ff_golden with discovery support; check dependencies and test initialization.'}\n');
            }
          }
        } on ProcessException catch (error) {
          _append('stderr',
              'Could not start Flutter: ${error.message}\nInstall dependencies first, or start diff with --flutter /path/to/flutter.\n');
        } on Exception catch (error) {
          _append(
              'stderr', 'Could not run ${job.selection.target.path}: $error\n');
        } finally {
          _process = null;
          _launch = null;
        }
        final status = _cancelRequested
            ? 'cancelled'
            : code == 0
                ? 'passed'
                : 'failed';
        failed = failed || status == 'failed';
        _results.add({
          'file': job.selection.target.path,
          'status': status,
          'exitCode': code
        });
        if (status == 'failed' && _exitCode == null) _exitCode = code ?? 1;
        _append('system',
            '[$status] ${job.selection.target.path}${code == null ? '' : ' · exit $code'}\n');
      }
    } finally {
      await _stopping;
      _status = _cancelRequested
          ? 'cancelled'
          : failed
              ? 'failed'
              : 'passed';
      _exitCode = _cancelRequested ? null : _exitCode ?? 0;
      _finished = DateTime.now().toUtc();
      if (_cancelRequested) {
        _append('system', 'Queue cancelled. Remaining files will not run.\n');
      }
    }
  }

  Future<int> _observe(Process process, {ReviewVariantReader? variants}) async {
    void discoveryLine(String line) {
      final previous = variants!.variants.length;
      variants.addLine(line);
      if (variants.variants.length > previous) {
        _append('stdout', 'Variant: ${variants.variants.last.fullName}\n');
        return;
      }
      try {
        final event = jsonDecode(line);
        if (event is Map) {
          if (event['type'] == 'error') {
            _append(
                'stderr', '${event['error']}\n${event['stackTrace'] ?? ''}\n');
          } else if (event['type'] == 'print' &&
              event['message'] is String &&
              !(event['message'] as String)
                  .startsWith(ReviewVariantReader.prefix)) {
            _append('stdout', '${event['message']}\n');
          } else if (event['type'] == 'testStart' &&
              event['test'] is Map &&
              event['test']['name'] is String &&
              (event['test']['name'] as String).startsWith('loading ')) {
            _append('system', '${event['test']['name']}\n');
          }
        }
      } on FormatException {
        if (line.trim().isNotEmpty) _append('stdout', '$line\n');
      }
    }

    Future<void> read(Stream<List<int>> stream, String channel) async {
      var pending = '';
      var dropping = false;
      try {
        await for (final text
            in stream.transform(const Utf8Decoder(allowMalformed: true))) {
          if (variants == null || channel != 'stdout') _append(channel, text);
          if (variants != null && channel == 'stdout') {
            for (final part in text.split('\n').indexed) {
              if (part.$1 > 0) {
                if (!dropping) discoveryLine(pending);
                pending = '';
                dropping = false;
              }
              if (!dropping) pending += part.$2;
              if (pending.length > 64 * 1024) {
                pending = '';
                dropping = true;
                variants.error =
                    'A discovery output line exceeded 64 KiB. Variant lists are incomplete.';
              }
            }
          }
        }
        if (variants != null && channel == 'stdout' && !dropping) {
          discoveryLine(pending);
        }
      } on IOException catch (error) {
        _append('system', 'Log stream closed: $error\n');
      }
    }

    final streams = Future.wait(
        [read(process.stdout, 'stdout'), read(process.stderr, 'stderr')]);
    final code = await process.exitCode;
    await streams;
    return code;
  }

  void stop(String runId) {
    if (runId != _id) {
      throw const GitReviewException('This is no longer the current test run.',
          conflict: true);
    }
    if (!active || _stopping != null) return;
    _cancelRequested = true;
    _status = 'stopping';
    _append('system', '\nStopping test and cancelling queued files…\n');
    _stopping = _stopOwnedProcess();
  }

  Future<void> _stopOwnedProcess() async {
    try {
      // Stop may arrive while Process.start is still acquiring the process.
      try {
        await _launch;
      } on ProcessException {
        return;
      }
      final process = _process;
      if (process == null) return;
      final descendants = await _descendants(process.pid);
      for (final pid in descendants.reversed) {
        Process.killPid(pid, ProcessSignal.sigterm);
      }
      process.kill(ProcessSignal.sigterm);
      try {
        await _processDone?.timeout(const Duration(seconds: 3));
      } on TimeoutException {
        for (final pid in descendants.reversed) {
          Process.killPid(pid, ProcessSignal.sigkill);
        }
        process.kill(ProcessSignal.sigkill);
      }
      await _processDone?.timeout(const Duration(seconds: 3));
    } catch (error) {
      _append('system', 'Unable to confirm process shutdown: $error\n');
      _status = 'running';
      _stopping = null;
    }
  }

  static Future<List<int>> _descendants(int parent) async {
    final result = await Process.run('ps', ['-A', '-o', 'pid=', '-o', 'ppid=']);
    if (result.exitCode != 0) {
      throw const ProcessException('ps', [], 'Cannot inspect test processes.');
    }
    final children = <int, List<int>>{};
    for (final line in (result.stdout as String).split('\n')) {
      final pair = line.trim().split(RegExp(r'\s+'));
      if (pair.length != 2) continue;
      final pid = int.tryParse(pair[0]), ppid = int.tryParse(pair[1]);
      if (pid != null && ppid != null) (children[ppid] ??= []).add(pid);
    }
    final resultPids = <int>[];
    void visit(int pid) {
      for (final child in children[pid] ?? <int>[]) {
        resultPids.add(child);
        visit(child);
      }
    }

    visit(parent);
    return resultPids;
  }

  void _append(String channel, String text) {
    // Small chunks let incremental polling cap memory even for huge output.
    for (var offset = 0; offset < text.length; offset += 8192) {
      final end = (offset + 8192).clamp(0, text.length);
      final chunk = text.substring(offset, end);
      _logs.add({
        'sequence': ++_sequence,
        'channel': channel,
        'text': chunk,
        'job': _currentIndex,
      });
      _logSize += chunk.length;
      while (_logSize > 512 * 1024 || _logs.length > 2000) {
        _logSize -= (_logs.removeFirst()['text'] as String).length;
      }
    }
  }

  String logReport(String runId, {required bool errorsOnly}) {
    final plan = _plan;
    if (_id != runId || plan == null) {
      throw const GitReviewException('This is no longer the current test run.',
          conflict: true);
    }
    final sections = <String>[];
    for (final (index, job) in plan.commands.indexed) {
      final result = index < _results.length ? _results[index] : null;
      final state =
          result?['status'] ?? (_currentIndex == index ? _status : 'not run');
      final output = cleanReviewTestLog(_logs
          .where((entry) => entry['job'] == index)
          .map((entry) => entry['text'] as String)
          .join());
      final excerpt = errorsOnly
          ? state == 'passed' || state == 'not run'
              ? null
              : reviewTestErrorExcerpt(output, failed: state == 'failed')
          : output;
      if (excerpt == null) continue;
      sections.add('File: ${job.selection.target.path}\n'
          'Result: $state${result?['exitCode'] == null ? '' : ' (exit ${result!['exitCode']})'}\n'
          'Scenarios: ${job.selection.scenarios.isEmpty ? 'all golden tests' : job.selection.scenarios.map((s) => s.name).join(', ')}\n'
          'Directory: ${job.directory}\n'
          '\$ ${job.command}\n\n'
          '${excerpt.trim().isEmpty ? '[No retained output for this file]' : excerpt.trimRight()}');
    }
    if (errorsOnly && sections.isEmpty) {
      throw const GitReviewException(
          'No error output found. Use Copy log for the full retained output.');
    }
    final truncated = _logs.isNotEmpty && _logs.first['sequence'] != 1;
    return 'FF Golden ${plan.discovery ? 'variant discovery' : 'test run'}\n'
        'Status: $_status${_exitCode == null ? '' : ' (exit $_exitCode)'}\n'
        'Files completed: ${_results.length}/${plan.commands.length}\n'
        'Started: ${_started?.toIso8601String()}\n'
        'Finished: ${_finished?.toIso8601String() ?? 'still running'}\n'
        'Filters: ${plan.filters.isEmpty ? 'none' : jsonEncode(plan.filters)}\n'
        'Output: ${errorsOnly ? 'error excerpts with context (detected from Flutter output)' : 'full retained log'}\n'
        '${truncated ? 'WARNING: Earlier output was truncated by the viewer log limit (approximately 512 KiB).\n' : ''}'
        '${active ? 'NOTE: The run is still active; this is a snapshot.\n' : ''}'
        '\n${sections.join('\n\n---\n\n')}\n';
  }

  Map<String, Object?> snapshot({int after = 0}) => {
        'id': _id,
        'status': _status,
        'active': active,
        'started': _started?.toIso8601String(),
        'finished': _finished?.toIso8601String(),
        'exitCode': _exitCode,
        'plan': _plan?.toJson(),
        'results': _results,
        'currentIndex': _currentIndex,
        'completed': _results.length,
        'total': _plan?.commands.length ?? 0,
        'cursor': _sequence,
        'truncated':
            _logs.isNotEmpty && after < (_logs.first['sequence'] as int) - 1,
        'logs':
            _logs.where((entry) => (entry['sequence'] as int) > after).toList(),
      };

  Future<void> close() async {
    _closed = true;
    if (active) stop(_id!);
    await _stopping;
    await _batch;
  }

  String _resolveFlutter(String directory) {
    if (flutterExecutable case final explicit?) return explicit;
    final name = Platform.isWindows ? 'flutter.bat' : 'flutter';
    var sdk = Platform.resolvedExecutable;
    for (var i = 0; i < 4; i++) {
      sdk = p.dirname(sdk);
    }
    for (final candidate in [
      p.join(directory, '.fvm', 'flutter_sdk', 'bin', name),
      if (Platform.environment['FLUTTER_ROOT'] case final root?)
        p.join(root, 'bin', name),
      p.join(sdk, name),
    ]) {
      if (File(candidate).existsSync()) return candidate;
    }
    return name;
  }
}
