/// Plain text suitable for a clipboard report, without terminal control codes.
String cleanReviewTestLog(String text) => text
    .replaceAll(RegExp(r'\x1b\][^\x07\x1b]*(?:\x07|\x1b\\)'), '')
    .replaceAll(RegExp(r'\x1b\[[0-?]*[ -/]*[@-~]'), '')
    .replaceAll('\r\n', '\n')
    .replaceAll('\r', '\n')
    .replaceAll(RegExp(r'[\x00-\x08\x0b\x0c\x0e-\x1f\x7f]'), '');

/// Flutter's expanded reporter prints assertion details before the [E] line.
/// Keep that test's whole diagnostic block, including stacks and nearby output.
/// Unknown failure formats fall back to the tail instead of losing diagnostics.
String? reviewTestErrorExcerpt(String text, {required bool failed}) {
  final lines = cleanReviewTestLog(text).split('\n');
  final progress = RegExp(r'^\d+:\d+(?::\d+)?\s+\+\d+[^:]*:');
  final error = RegExp(
      r'\[E\](?:\s|$)|EXCEPTION CAUGHT|\b(?:Error|Exception):|'
      r'Unhandled exception|Failed to load|^\s*Expected:|^\s*Test failed\.',
      caseSensitive: false);
  final nextProgress = List.filled(lines.length, lines.length);
  var next = lines.length;
  for (var index = lines.length - 1; index >= 0; index--) {
    nextProgress[index] = next;
    if (progress.hasMatch(lines[index])) next = index;
  }
  final ranges = <(int, int)>[];
  var previousProgress = -1;
  for (var index = 0; index < lines.length; index++) {
    final start = previousProgress >= 0
        ? previousProgress
        : (index - 8).clamp(0, lines.length);
    if (progress.hasMatch(lines[index])) previousProgress = index;
    if (!error.hasMatch(lines[index])) continue;
    final end = nextProgress[index];
    if (ranges.isNotEmpty && start <= ranges.last.$2) {
      final previous = ranges.removeLast();
      ranges.add((previous.$1, end));
    } else {
      ranges.add((start, end));
    }
  }
  if (ranges.isEmpty) {
    if (!failed) return null;
    return '[No recognized error block; showing the last 120 retained lines]\n'
        '${lines.skip((lines.length - 120).clamp(0, lines.length)).join('\n')}';
  }
  final output = StringBuffer();
  var previousEnd = 0;
  for (final (start, end) in ranges) {
    if (start > previousEnd) output.writeln('[… unrelated output omitted …]');
    output.writeln(lines.sublist(start, end).join('\n').trimRight());
    previousEnd = end;
  }
  if (previousEnd < lines.length - 1) {
    output.writeln('[… unrelated output omitted …]');
  }
  return output.toString().trimRight();
}
