import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'diff_viewer.dart';
import 'git_image_difference.dart';
import 'git_image_review.dart';
import 'review_test_catalog.dart';
import 'review_test_opener.dart';
import 'review_test_runner.dart';

/// A session-scoped loopback viewer. It has no arbitrary file or command API.
final class DiffReviewServer {
  DiffReviewServer._(this.repository, this._server, this.token,
      {String? flutterExecutable, required this.openTestFile}) {
    _tests = ReviewTestCatalog(repository);
    _runner = ReviewTestRunner(_tests, flutterExecutable: flutterExecutable);
    _differences = GitImageDifferenceQueue(repository);
  }
  final GitImageRepository repository;
  final HttpServer _server;
  final String token;
  final Future<void> Function(String path) openTestFile;
  Future<void> _pending = Future.value();
  GitImageSnapshot _snapshot = const GitImageSnapshot([], []);
  late final ReviewTestCatalog _tests;
  late final ReviewTestRunner _runner;
  late final GitImageDifferenceQueue _differences;

  Uri get uri =>
      Uri(scheme: 'http', host: '127.0.0.1', port: _server.port, path: '/');

  static Future<DiffReviewServer> start(GitImageRepository repository,
      {int port = 0,
      String? flutterExecutable,
      Future<void> Function(String path) openTestFile =
          openReviewTestFile}) async {
    final snapshot = await repository.scan();
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
    server.serverHeader = null;
    final random = Random.secure();
    final token =
        base64Url.encode(List.generate(32, (_) => random.nextInt(256)));
    final viewer = DiffReviewServer._(repository, server, token,
        flutterExecutable: flutterExecutable, openTestFile: openTestFile)
      .._snapshot = snapshot
      .._differences.schedule(snapshot);
    server.listen((request) {
      // Polling, reads, index and ignore-list writes share a session queue.
      viewer._pending = viewer._pending.then((_) => viewer._handle(request));
    });
    return viewer;
  }

  Future<void> close() async {
    await _server.close(force: true);
    await _pending;
    await _runner.close();
    await _differences.close();
  }

  Future<void> _handle(HttpRequest request) async {
    final response = request.response;
    response.headers
      ..set('Cache-Control', 'no-store')
      ..set('X-Content-Type-Options', 'nosniff')
      ..set('Referrer-Policy', 'no-referrer')
      ..set('Content-Security-Policy',
          "default-src 'none'; script-src 'nonce-$token'; style-src 'unsafe-inline'; img-src 'self' blob:; connect-src 'self'; frame-ancestors 'none'; base-uri 'none'; form-action 'none'");
    try {
      if (request.headers.value('host') != uri.authority ||
          (request.headers.value('origin') != null &&
              request.headers.value('origin') != uri.origin)) {
        _json(response, 403,
            {'error': 'Only this local viewer may access the session.'});
        return;
      }
      if (request.method == 'GET' && request.uri.path == '/') {
        response.headers.contentType = ContentType.html;
        response.write(renderDiffViewer(token));
        return;
      }
      if (request.headers.value('X-FF-Golden-Token') != token) {
        _json(response, 403, {'error': 'Invalid viewer session.'});
        return;
      }
      if (request.method == 'GET' && request.uri.path == '/api/changes') {
        await _refresh(response);
      } else if (request.method == 'GET' && request.uri.path == '/api/tests') {
        await _tests.refresh();
        final images = _snapshot.changes
            .where((image) => image.id == request.uri.queryParameters['image']);
        _json(response, 200, _tests.toJson(image: images.firstOrNull));
      } else if (request.method == 'GET' &&
          request.uri.path == '/api/test-run') {
        final after = int.tryParse(request.uri.queryParameters['after'] ?? '0');
        if (after == null || after < 0) {
          throw const FormatException('Expected a log cursor.');
        }
        final sameRun = request.uri.queryParameters['runId'] == _runner.runId;
        _json(response, 200, _runner.snapshot(after: sameRun ? after : 0));
      } else if (request.method == 'POST' &&
          request.uri.path == '/api/test-open') {
        final body = await _readBody(request);
        if (body is! Map || body.length != 1 || body['testId'] is! String) {
          throw const FormatException('Expected a discovered test ID.');
        }
        final target = await _tests.validate(body['testId'] as String);
        await openTestFile(_tests.absolutePath(target.path));
        _json(response, 200, {'file': target.path});
      } else if (request.method == 'POST' &&
          request.uri.path == '/api/test-log') {
        final body = await _readBody(request);
        if (body is! Map ||
            body.length != 2 ||
            body['runId'] is! String ||
            !['all', 'errors'].contains(body['part'])) {
          throw const FormatException('Expected a run ID and all or errors.');
        }
        _json(response, 200, {
          'text': _runner.logReport(body['runId'] as String,
              errorsOnly: body['part'] == 'errors'),
        });
      } else if (request.method == 'POST' &&
          request.uri.path == '/api/test-context') {
        final body = await _readBody(request);
        if (body is! Map ||
            body['imageIds'] is! List ||
            body.keys.any((key) =>
                key != 'imageIds' && key != 'folder' && key != 'wholeFiles') ||
            (body.containsKey('wholeFiles') && body['wholeFiles'] is! bool) ||
            (body.containsKey('folder') && body['folder'] is! String)) {
          throw const FormatException(
              'Expected image IDs and an optional folder.');
        }
        final ids = body['imageIds'] as List;
        if (ids.isEmpty ||
            ids.length > 5000 ||
            ids.any((id) => id is! String)) {
          throw const FormatException('Choose images from the current review.');
        }
        final images = <GitImageChange>[];
        for (final id in ids.toSet()) {
          final image =
              _snapshot.changes.where((image) => image.id == id).firstOrNull;
          if (image == null) {
            throw const GitReviewException(
                'Image selection changed. Refresh and choose again.',
                conflict: true);
          }
          images.add(image);
        }
        final folder = body['folder'] as String?;
        if (folder != null &&
            (folder.isEmpty ||
                images.any((image) => !image.path.startsWith('$folder/')))) {
          throw const FormatException(
              'Folder must contain the selected images.');
        }
        _json(
            response,
            200,
            _tests.context(images,
                folder: folder, wholeFiles: body['wholeFiles'] == true));
      } else if (request.method == 'POST' &&
          request.uri.path == '/api/test-options') {
        final body = await _readBody(request);
        if (body is! Map ||
            body.length != 2 ||
            !body.containsKey('scopeIds') ||
            !body.containsKey('filters')) {
          throw const FormatException('Expected scopes and filters.');
        }
        _json(
            response,
            200,
            _tests.variantOptions(await _tests.resolveScopes(body['scopeIds']),
                ReviewTestFilters.parse(body['filters'])));
      } else if (request.method == 'POST' &&
          [
            '/api/test-plan',
            '/api/test-run',
            '/api/test-discover',
            '/api/test-stop'
          ].contains(request.uri.path)) {
        final body = await _readBody(request);
        if (request.uri.path == '/api/test-plan') {
          _json(response, 200, (await _runner.plan(body)).toJson());
        } else if (request.uri.path == '/api/test-run' ||
            request.uri.path == '/api/test-discover') {
          await _runner.start(body,
              discovery: request.uri.path == '/api/test-discover');
          _json(response, 200, _runner.snapshot());
        } else {
          if (body is! Map || body['runId'] is! String || body.length != 1) {
            throw const FormatException('Expected the current run ID.');
          }
          _runner.stop(body['runId'] as String);
          _json(response, 200, _runner.snapshot());
        }
      } else if (request.method == 'GET' && request.uri.path == '/api/image') {
        final query = request.uri.queryParameters;
        final matches = _snapshot.changes.where((c) => c.id == query['id']);
        if (matches.isEmpty || matches.single.revision != query['revision']) {
          throw const GitReviewException(
              'Image changed. Refresh the comparison.',
              conflict: true);
        }
        if (query['side'] != 'before' && query['side'] != 'after') {
          _json(response, 400, {'error': 'Expected before or after.'});
          return;
        }
        final change = matches.single;
        final bytes = await repository.readImage(change,
            before: query['side'] == 'before');
        final extension = change.path.split('.').last.toLowerCase();
        response.headers.contentType = ContentType(
            'image',
            switch (extension) {
              'jpg' || 'jpeg' => 'jpeg',
              'webp' => 'webp',
              _ => 'png',
            });
        response.add(bytes);
      } else if (request.method == 'POST' &&
          [
            '/api/stage',
            '/api/unstage',
            '/api/revert',
            '/api/ignore',
            '/api/unignore'
          ].contains(request.uri.path)) {
        final body = await _readBody(request);
        if (body is! Map ||
            body['revisions'] is! Map ||
            !(body['revisions'] as Map)
                .entries
                .every((e) => e.key is String && e.value is String)) {
          throw const FormatException('Expected a revisions map.');
        }
        final revisions = Map<String, String>.from(body['revisions'] as Map);
        var removedStaleIndexLock = false;
        var restoredWorkingFiles = 0;
        var deletedUntrackedFiles = 0;
        if (request.uri.path == '/api/ignore' ||
            request.uri.path == '/api/unignore') {
          await repository.setIgnored(revisions,
              ignored: request.uri.path == '/api/ignore');
        } else if (request.uri.path == '/api/revert') {
          final result = await repository.revertWorkingChanges(revisions);
          restoredWorkingFiles = result.restored;
          deletedUntrackedFiles = result.deleted;
        } else {
          removedStaleIndexLock = await repository.setStaged(revisions,
              staged: request.uri.path == '/api/stage');
        }
        await _refresh(
          response,
          removedStaleIndexLock: removedStaleIndexLock,
          restoredWorkingFiles: restoredWorkingFiles,
          deletedUntrackedFiles: deletedUntrackedFiles,
        );
      } else {
        _json(response, 404, {'error': 'Not found.'});
      }
    } on GitReviewException catch (error) {
      _json(response, error.conflict ? 409 : 400, {'error': error.message});
    } on FormatException catch (error) {
      _json(response, 400, {'error': error.message});
    } on FileSystemException {
      _json(response, 409, {
        'error': 'File changed or became unavailable. Refresh and try again.'
      });
    } on TimeoutException {
      _json(response, 408, {'error': 'Request timed out.'});
    } catch (_) {
      _json(response, 500,
          {'error': 'Unable to complete the request. Refresh and try again.'});
    } finally {
      try {
        await response.close();
      } on Exception {
        // Closing a browser tab must not stop the local server.
      }
    }
  }

  static Future<Object?> _readBody(HttpRequest request) async {
    if (request.headers.contentType?.mimeType != 'application/json') {
      throw const FormatException('Expected application/json.');
    }
    final bytes = <int>[];
    await for (final chunk in request.timeout(const Duration(seconds: 10))) {
      bytes.addAll(chunk);
      if (bytes.length > 128 * 1024) {
        throw const FormatException('Request is too large.');
      }
    }
    return jsonDecode(utf8.decode(bytes));
  }

  Future<void> _refresh(HttpResponse response,
      {bool removedStaleIndexLock = false,
      int restoredWorkingFiles = 0,
      int deletedUntrackedFiles = 0}) async {
    _snapshot = await repository.scan();
    _differences.schedule(_snapshot);
    _json(response, 200, {
      'repository': repository.directory.path,
      'input': repository.input,
      'changes': _snapshot.changes
          .map((change) => {
                ...change.toJson(),
                'difference': _differences.stateFor(change).toJson(),
              })
          .toList(),
      'warnings': _snapshot.warnings,
      if (removedStaleIndexLock) 'removedStaleIndexLock': true,
      if (restoredWorkingFiles > 0)
        'restoredWorkingFiles': restoredWorkingFiles,
      if (deletedUntrackedFiles > 0)
        'deletedUntrackedFiles': deletedUntrackedFiles,
    });
  }

  static void _json(HttpResponse response, int status, Object value) {
    response.statusCode = status;
    response.headers.contentType = ContentType.json;
    response.write(jsonEncode(value));
  }
}
