import 'package:ff_golden_presenter/src/review_test_log.dart';
import 'package:test/test.dart';

void main() {
  test('keeps Flutter assertions before [E], stacks, and multiple failures',
      () {
    final log = '''00:00 +0: unrelated passed test
passed output
00:01 +1: first failing test
setup context
══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞══
Expected: one widget
Actual: zero widgets
${List.generate(30, (i) => '#$i stack.dart:$i').join('\n')}
00:01 +1 -1: first failing test [E]
  Test failed. See exception logs above.
00:02 +1 -1: another passed test
unrelated output
00:03 +2 -1: second failing test
Expected: blue
Actual: red
00:03 +2 -2: second failing test [E]
  Test failed. See exception logs above.
00:04 +2 -2: final passed test
final unrelated output
''';
    final excerpt = reviewTestErrorExcerpt(log, failed: true)!;
    expect(excerpt, contains('first failing test\nsetup context'));
    expect(excerpt, contains('Expected: one widget\nActual: zero widgets'));
    expect(excerpt, contains('#29 stack.dart:29'));
    expect(excerpt, contains('Expected: blue\nActual: red'));
    expect(excerpt, isNot(contains('passed output')));
    expect(excerpt, isNot(contains('final unrelated output')));
    expect(excerpt, contains('unrelated output omitted'));
  });

  test('keeps compiler errors, stderr and strips terminal escape sequences',
      () {
    const log = '\x1b]0;terminal title\x07'
        '00:00 +0: loading test/screen_test.dart\r\n'
        '\x1b[31mtest/screen_test.dart:10:5: Error: Undefined name.\x1b[0m\n'
        '  missingSymbol();\n  ^^^^^^^^^^^^^\n'
        '00:01 +0 -1: loading test/screen_test.dart [E]\n'
        '  Failed to load test/screen_test.dart\n';
    final excerpt = reviewTestErrorExcerpt(log, failed: true)!;
    expect(excerpt, contains('missingSymbol();\n  ^^^^^^^^^^^^^'));
    expect(excerpt, isNot(contains('\x1b')));
    expect(excerpt, isNot(contains('terminal title')));
    expect(excerpt, isNot(contains('\r')));
  });

  test('does not mistake a scenario named error for a failure', () {
    expect(
        reviewTestErrorExcerpt(
            '00:00 +0: Screen error (phone:en_US:dark)\nAll tests passed!\n',
            failed: false),
        isNull);
  });

  test('unknown failures use a marked tail; active error blocks are available',
      () {
    final fallback = reviewTestErrorExcerpt(
        '${List.generate(180, (i) => 'line $i').join('\n')}\nKilled',
        failed: true)!;
    expect(fallback, startsWith('[No recognized error block;'));
    expect(fallback, isNot(contains('line 0\n')));
    expect(fallback, endsWith('Killed'));
    expect(
        reviewTestErrorExcerpt('Unhandled exception:\n#0 screen.dart:20',
            failed: false),
        contains('#0 screen.dart:20'));
  });
}
