import 'dart:async';

import 'package:ff_golden_presenter/src/git_image_difference.dart';
import 'package:ff_golden_presenter/src/git_image_review.dart';
import 'package:test/test.dart';

void main() {
  const ready = GitImageDifference.ready(changedPixels: 1, totalPixels: 4);

  test('polls and removal/reappearance do not duplicate running work',
      () async {
    final calls = <String>[];
    final first = Completer<GitImageDifference>();
    final queue = ImageDifferenceQueue<String>((value) async {
      calls.add(value);
      return value == 'a' ? first.future : ready;
    });
    addTearDown(queue.close);
    queue.schedule({'a': 'a', 'obsolete': 'obsolete'});
    queue.schedule({'b': 'b'});
    queue.schedule({'a': 'a', 'b': 'b'});
    first.complete(ready);
    await queue.idle;
    expect(calls, ['a', 'b']);
    expect(queue.stateFor('a'), same(ready));
    queue.schedule({'a': 'a', 'b': 'b'});
    await queue.idle;
    expect(calls, ['a', 'b']);
  });

  test('caches inactive results and evicts least recently used ones', () async {
    final calls = <String>[];
    final queue = ImageDifferenceQueue<String>((value) async {
      calls.add(value);
      return ready;
    }, maxInactiveResults: 1);
    addTearDown(queue.close);
    for (final key in ['a', 'b', 'a', 'c', 'a']) {
      queue.schedule({key: key});
      await queue.idle;
    }
    expect(calls, ['a', 'b', 'c']);
    queue.schedule({'b': 'b'});
    await queue.idle;
    expect(calls, ['a', 'b', 'c', 'b']);
  });

  test('retains active results beyond the inactive cache limit', () async {
    var calls = 0;
    final queue = ImageDifferenceQueue<int>((_) async {
      calls++;
      return ready;
    }, maxInactiveResults: 0);
    addTearDown(queue.close);
    final values = {for (var i = 0; i < 10; i++) '$i': i};
    queue.schedule(values);
    await queue.idle;
    queue.schedule(values);
    await queue.idle;
    expect(calls, 10);
    queue.schedule({});
    expect(queue.stateFor('0').status, GitImageDifferenceStatus.pending);
  });

  test('failed calculations are cached without blocking later files', () async {
    var calls = 0;
    final queue = ImageDifferenceQueue<String>((value) async {
      calls++;
      if (value == 'bad') throw StateError('decode failed');
      return ready;
    });
    addTearDown(queue.close);
    for (var poll = 0; poll < 3; poll++) {
      queue.schedule({'bad': 'bad', 'good': 'good'});
      await queue.idle;
    }
    expect(calls, 2);
    expect(queue.stateFor('bad').status, GitImageDifferenceStatus.unavailable);
    expect(queue.stateFor('good'), same(ready));
  });

  test('transient stale reads retry on the next scan, including sync errors',
      () async {
    var calls = 0;
    final queue = ImageDifferenceQueue<String>((value) {
      if (++calls == 1) {
        throw const GitReviewException('File changed', conflict: true);
      }
      return Future.value(ready);
    });
    addTearDown(queue.close);
    queue.schedule({'a': 'a'});
    await queue.idle;
    expect(queue.stateFor('a').status, GitImageDifferenceStatus.unavailable);
    expect(calls, 1);
    queue.schedule({'a': 'a'});
    await queue.idle;
    expect(queue.stateFor('a'), same(ready));
    expect(calls, 2);
  });

  test('close drains only the running calculation and releases results',
      () async {
    final first = Completer<GitImageDifference>();
    final calls = <String>[];
    final queue = ImageDifferenceQueue<String>((value) {
      calls.add(value);
      return first.future;
    });
    queue.schedule({'a': 'a', 'b': 'b'});
    final closing = queue.close();
    first.complete(ready);
    await closing;
    queue.schedule({'c': 'c'});
    expect(calls, ['a']);
    expect(queue.stateFor('a').status, GitImageDifferenceStatus.pending);
  });
}
