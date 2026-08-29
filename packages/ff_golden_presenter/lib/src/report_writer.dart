import 'dart:io';

import 'model.dart';

/// Persists a rendered report, creating the output directory when necessary.
final class HtmlReportWriter {
  HtmlReportWriter({required this.outputPath});

  final String outputPath;

  Future<void> write(GoldenPresenterResult result) async {
    final file = File(outputPath);
    await file.parent.create(recursive: true);
    await file.writeAsString(result.html, flush: true);
  }
}
