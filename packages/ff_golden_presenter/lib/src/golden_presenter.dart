import 'catalog_scanner.dart';
import 'html_report_renderer.dart';
import 'model.dart';
import 'report_writer.dart';

/// Coordinates discovery, rendering, and persistence of one report.
final class GoldenPresenter {
  GoldenPresenter({
    required GoldenCatalogScanner scanner,
    required HtmlReportRenderer renderer,
    required HtmlReportWriter writer,
  })  : _scanner = scanner,
        _renderer = renderer,
        _writer = writer;

  final GoldenCatalogScanner _scanner;
  final HtmlReportRenderer _renderer;
  final HtmlReportWriter _writer;

  Future<GoldenPresenterResult> generate() async {
    final catalog = await _scanner.scan();
    final result = _renderer.render(catalog);
    await _writer.write(result);
    return result;
  }
}
