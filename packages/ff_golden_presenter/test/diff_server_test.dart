import 'dart:convert';
import 'dart:io';

import 'package:ff_golden_presenter/src/diff_server.dart';
import 'package:ff_golden_presenter/src/git_image_review.dart';
import 'package:test/test.dart';

import 'helpers/git_fixture.dart';

void main() {
  late GitFixture fixture;
  late DiffReviewServer server;
  late HttpClient client;
  late List<String> openedFiles;
  setUp(() async {
    fixture = await GitFixture.create();
    await fixture.write('image.png', [0, 255, 128]);
    await fixture.commitAll();
    await fixture.write('image.png', [0, 254, 127]);
    openedFiles = [];
    server = await DiffReviewServer.start(
        await GitImageRepository.open(project: fixture.directory),
        openTestFile: (path) async => openedFiles.add(path));
    client = HttpClient();
  });
  tearDown(() async {
    client.close(force: true);
    await server.close();
    await fixture.directory.delete(recursive: true);
  });

  Future<HttpClientResponse> request(String path,
      {bool authenticated = true,
      String? origin,
      String? host,
      Object? body}) async {
    final request = await client.openUrl(
        body == null ? 'GET' : 'POST', server.uri.resolve(path));
    if (authenticated) request.headers.set('X-FF-Golden-Token', server.token);
    if (origin != null) request.headers.set('Origin', origin);
    if (host != null) request.headers.set('Host', host);
    if (body != null) {
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode(body));
    }
    return request.close();
  }

  Future<Map<String, dynamic>> json(HttpClientResponse response) async =>
      jsonDecode(await utf8.decoder.bind(response).join())
          as Map<String, dynamic>;

  test(
      'serves a session page but rejects unauthenticated, cross-origin and rebound-host APIs',
      () async {
    final page = await request('/', authenticated: false);
    expect(page.statusCode, 200);
    expect(page.headers.value('content-security-policy'),
        contains("frame-ancestors 'none'"));
    final html = await utf8.decoder.bind(page).join();
    expect(html, contains('FF Golden · Changes'));
    expect(html, contains("'Staging '"));
    expect(html, contains('Removed stale Git index.lock and retried.'));
    for (final response in [
      await request('/api/changes', authenticated: false),
      await request('/api/changes', origin: 'https://untrusted.example'),
      await request('/api/changes', host: 'untrusted.example'),
      await request('/api/tests', authenticated: false),
      await request('/api/test-open',
          authenticated: false, body: {'testId': 'x'}),
      await request('/api/test-log',
          origin: 'https://untrusted.example',
          body: {'runId': '1', 'part': 'all'}),
      await request('/api/test-context', authenticated: false, body: {
        'imageIds': ['x']
      }),
      await request('/api/test-run', origin: 'https://untrusted.example'),
      await request('/api/test-run',
          authenticated: false, body: {'testId': 'x', 'filters': {}}),
      await request('/api/test-stop',
          host: 'untrusted.example', body: {'runId': '1'}),
      await request('/api/stage',
          authenticated: false, body: {'revisions': {}}),
      await request('/api/ignore',
          authenticated: false, body: {'revisions': {}}),
      await request('/api/unignore',
          origin: 'https://untrusted.example', body: {'revisions': {}}),
    ]) {
      expect(response.statusCode, 403);
      await response.drain<void>();
    }
    expect(await fixture.blob(':image.png'), [0, 255, 128]);
  });

  test(
      'opens only revalidated catalog files, never arbitrary commands or paths',
      () async {
    const path = r"test/a $(touch injected); 'quote'_test.dart";
    await fixture.write('pubspec.yaml', utf8.encode('name: fixture\n'));
    await fixture.write(path,
        utf8.encode("void main() { testDeviceGoldens('Demo', builder); }"));
    final catalog = await json(await request('/api/tests'));
    final id = (catalog['tests'] as List).single['id'];
    final opened = await request('/api/test-open', body: {'testId': id});
    expect(opened.statusCode, 200);
    expect((await json(opened))['file'], path);
    expect(openedFiles, [await fixture.file(path).resolveSymbolicLinks()]);
    for (final body in [
      {'testId': '../../etc/passwd'},
      {'testId': id, 'command': 'sh'},
      {'path': fixture.file(path).path},
    ]) {
      final response = await request('/api/test-open', body: body);
      expect(response.statusCode, 400);
      await response.drain<void>();
    }
    await fixture.file(path).delete();
    final moved = await request('/api/test-open', body: {'testId': id});
    expect(moved.statusCode, 400);
    await moved.drain<void>();
    if (!Platform.isWindows) {
      await Link(fixture.file(path).path)
          .create(fixture.file('image.png').path);
      final linked = await request('/api/test-open', body: {'testId': id});
      expect(linked.statusCode, 400);
      await linked.drain<void>();
    }
    expect(openedFiles, hasLength(1));
    expect(fixture.file('injected').existsSync(), isFalse);
  });

  test('log export validates part and rejects stale or missing runs', () async {
    for (final body in [
      {'runId': 'old', 'part': 'all', 'path': '/tmp/log'},
      {'runId': 'old', 'part': 'unknown'},
    ]) {
      final response = await request('/api/test-log', body: body);
      expect(response.statusCode, 400);
      await response.drain<void>();
    }
    final response = await request('/api/test-log',
        body: {'runId': 'old', 'part': 'errors'});
    expect(response.statusCode, 409);
    await response.drain<void>();
  });

  test('returns exact image bytes and supports selected stage and unstage',
      () async {
    var data = await json(await request('/api/changes'));
    var change = (data['changes'] as List).single as Map<String, dynamic>;
    final query = Uri(queryParameters: {
      'id': change['id'] as String,
      'revision': change['revision'] as String,
      'side': 'before'
    }).query;
    final image = await request('/api/image?$query');
    expect(image.statusCode, 200);
    expect(image.headers.contentType?.mimeType, 'image/png');
    expect(
        await image.fold<List<int>>([], (bytes, chunk) => bytes..addAll(chunk)),
        [0, 255, 128]);
    data = await json(await request('/api/stage', body: {
      'revisions': {change['id']: change['revision']}
    }));
    expect(data, isNot(contains('removedStaleIndexLock')));
    change = (data['changes'] as List).single as Map<String, dynamic>;
    expect(change['staged'], isTrue);
    expect(await fixture.blob(':image.png'), [0, 254, 127]);
    await json(await request('/api/unstage', body: {
      'revisions': {change['id']: change['revision']}
    }));
    expect(await fixture.blob(':image.png'), [0, 255, 128]);
    expect(await fixture.file('image.png').readAsBytes(), [0, 254, 127]);
  });

  test('stage response reports when a stale index lock was removed', () async {
    final data = await json(await request('/api/changes'));
    final change = (data['changes'] as List).single as Map<String, dynamic>;
    client.close(force: true);
    await server.close();
    final lock = fixture.file('.git/index.lock');
    await lock.writeAsString('stale');
    server = await DiffReviewServer.start(
      await GitImageRepository.open(
        project: fixture.directory,
        lockUsageProbe: (_) async => false,
      ),
      openTestFile: (path) async => openedFiles.add(path),
    );
    client = HttpClient();

    final staged = await json(await request('/api/stage', body: {
      'revisions': {change['id']: change['revision']}
    }));

    expect(staged['removedStaleIndexLock'], isTrue);
    expect(await lock.exists(), isFalse);
    expect(await fixture.blob(':image.png'), [0, 254, 127]);
  });

  test('rejects stale mutations and arbitrary image paths', () async {
    final data = await json(await request('/api/changes'));
    final change = (data['changes'] as List).single as Map;
    await fixture.write('image.png', [9]);
    final stale = await request('/api/stage', body: {
      'revisions': {change['id']: change['revision']}
    });
    expect(stale.statusCode, 409);
    expect((await json(stale))['error'], contains('Selection changed'));
    expect(await fixture.blob(':image.png'), [0, 255, 128]);
    final arbitrary = await request('/api/image?id=../../secret&side=after');
    expect(arbitrary.statusCode, 409);
    await arbitrary.drain<void>();
  });

  test('malformed action does not break the request queue', () async {
    final bad = await request('/api/stage', body: {
      'revisions': [1, 2]
    });
    expect(bad.statusCode, 400);
    await bad.drain<void>();
    final healthy = await request('/api/changes');
    expect(healthy.statusCode, 200);
    await healthy.drain<void>();
  });

  test('test plans require discovered files and reject command arguments',
      () async {
    await fixture.write('pubspec.yaml', utf8.encode('name: fixture\n'));
    await fixture.write(
        'test/screen_test.dart',
        utf8.encode(
            "void main() { testFfGoldens('Screen', scenario: 'screen', build: builder); }"));
    await fixture.write('test/unit_test.dart',
        utf8.encode("void main() { test('unit', callback); }"));
    final catalog = await json(await request('/api/tests'));
    final id = (catalog['tests'] as List).single['id'];
    final unknown = await request('/api/test-context', body: {
      'imageIds': ['../../outside.png']
    });
    expect(unknown.statusCode, 409);
    await unknown.drain<void>();
    final plan = await json(await request('/api/test-plan', body: {
      'testId': id,
      'filters': {'device': 'iPadPro12.9'}
    }));
    final command = (plan['commands'] as List).single['command'];
    expect(command, contains('--tags=golden'));
    expect(command, contains('--name'));
    expect(command, isNot(contains('--update-goldens')));
    for (final body in [
      {'testId': '../../etc/passwd', 'filters': {}},
      {
        'testId': base64Url.encode(utf8.encode('test/unit_test.dart')),
        'filters': {}
      },
      {
        'testId': id,
        'filters': {'arguments': '--update-goldens'}
      },
      {'testId': id, 'filters': {}, 'executable': 'sh'},
    ]) {
      final response = await request('/api/test-run', body: body);
      expect(response.statusCode, 400);
      await response.drain<void>();
    }
    expect((await json(await request('/api/test-run')))['status'], 'idle');
  });

  test('ignore and unignore persist in .golden_ignore without changing Git',
      () async {
    final data = await json(await request('/api/changes'));
    final change = (data['changes'] as List).single as Map;
    final body = {
      'revisions': {change['id']: change['revision']}
    };
    final ignored = await json(await request('/api/ignore', body: body));
    expect((ignored['changes'] as List).single['ignored'], isTrue);
    expect(await fixture.file(reviewIgnoreFileName).readAsString(),
        contains('/image.png\n'));
    expect(await fixture.blob(':image.png'), [0, 255, 128]);
    expect(await fixture.file('image.png').readAsBytes(), [0, 254, 127]);
    final hiddenStage = await request('/api/stage', body: body);
    expect(hiddenStage.statusCode, 409);
    await hiddenStage.drain<void>();
    final restored = await json(await request('/api/unignore', body: body));
    expect((restored['changes'] as List).single['ignored'], isFalse);
    expect(await fixture.file(reviewIgnoreFileName).readAsString(),
        isNot(contains('/image.png\n')));
    expect(await fixture.blob(':image.png'), [0, 255, 128]);
    final arbitrary = await request('/api/ignore', body: {
      'revisions': {'../../outside.png': 'made-up'}
    });
    expect(arbitrary.statusCode, 409);
    await arbitrary.drain<void>();
  });
}
