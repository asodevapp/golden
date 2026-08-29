import 'dart:io';

class StaleGoldenFilesFound implements Exception {
  const StaleGoldenFilesFound(this.paths);

  final List<String> paths;

  @override
  String toString() =>
      'StaleGoldenFilesFound: ${paths.length} stale golden file(s):\n'
      '${paths.map((path) => ' - $path').join('\n')}';
}

List<String> findStaleGoldenFiles({
  required Uri baseDirectory,
  required Iterable<String> expectedPaths,
  required String scope,
}) {
  final normalizedExpected =
      expectedPaths.map((path) => Uri(path: path).path.toLowerCase()).toSet();
  final scopeUri = baseDirectory.resolve(
    scope.endsWith('/') ? scope : '$scope/',
  );
  final directory = Directory.fromUri(scopeUri);
  if (!directory.existsSync()) return const [];

  final stale = <String>[];
  for (final entity in directory.listSync(recursive: true)) {
    if (entity is! File || !entity.path.toLowerCase().endsWith('.png')) {
      continue;
    }
    final relative = baseDirectory.resolveUri(entity.uri).path;
    final basePath = baseDirectory.path;
    final normalized = relative.startsWith(basePath)
        ? relative.substring(basePath.length)
        : relative;
    if (!normalizedExpected.contains(normalized.toLowerCase())) {
      stale.add(normalized);
    }
  }
  stale.sort();
  return stale;
}
