import 'dart:io';

import 'package:path/path.dart' as path;

import 'catalog_scanner.dart';
import 'golden_image_factory.dart';
import 'golden_presenter.dart';
import 'html_report_renderer.dart';
import 'image_optimizer.dart';
import 'model.dart';
import 'publication_model.dart';
import 'report_writer.dart';
import 'run_manifest.dart';
import 'screenshot_collector.dart';

/// Configuration for collect -> optimize -> report.
final class GoldenPublicationOptions {
  const GoldenPublicationOptions({
    required this.inputDirectory,
    required this.outputDirectory,
    required this.reportFileName,
    required this.title,
    required this.goldenDirectory,
    required this.extensions,
    required this.devicePattern,
    required this.localePattern,
    required this.themePattern,
    required this.manifestPaths,
    this.supportAttribution = true,
    this.customization = GoldenReportCustomization.empty,
    required this.profile,
    required this.backend,
    required this.jobs,
    required this.clean,
    required this.installTools,
    required this.dryRun,
  });

  final Directory inputDirectory;
  final Directory outputDirectory;
  final String reportFileName;
  final String title;
  final String goldenDirectory;
  final Set<String> extensions;
  final String devicePattern;
  final String localePattern;
  final String themePattern;
  final List<String> manifestPaths;
  final bool supportAttribution;
  final GoldenReportCustomization customization;
  final ImageOptimizationProfile profile;
  final ImageOptimizerBackend backend;
  final int jobs;
  final bool clean;
  final bool installTools;
  final bool dryRun;
}

/// Complete result from publishing one staged report.
final class GoldenPublicationResult {
  const GoldenPublicationResult({
    required this.collection,
    required this.optimization,
    required this.report,
    required this.reportPath,
  });

  final ScreenshotCollectionResult collection;
  final ImageOptimizationResult optimization;
  final GoldenPresenterResult? report;
  final String reportPath;
}

/// Creates a self-contained, optimized publication directory.
final class GoldenPublicationPipeline {
  GoldenPublicationPipeline({
    required GoldenPublicationOptions options,
    ImageOptimizer? optimizer,
  })  : _options = options,
        _optimizer = optimizer;

  final GoldenPublicationOptions _options;
  final ImageOptimizer? _optimizer;

  Future<GoldenPublicationResult> run({
    void Function(String message)? onMessage,
  }) async {
    _validateReportFileName(_options.reportFileName);
    final outputPath = path.normalize(
      path.absolute(_options.outputDirectory.path),
    );
    final reportPath = path.join(outputPath, _options.reportFileName);
    final runIndex = await GoldenRunManifestLoader(
      projectDirectory: Directory.current,
      imageRoot: _options.inputDirectory,
      manifestPaths: _options.manifestPaths,
    ).load();
    if (runIndex.manifestCount > 0) {
      onMessage?.call(
        'Loaded ${runIndex.manifestCount} ff_golden.run shards with '
        '${runIndex.imageCount} captures.',
      );
    }
    final collector = ScreenshotCollector(
      inputDirectory: _options.inputDirectory,
      outputDirectory: Directory(outputPath),
      extensions: _options.extensions,
    );
    final collection = await collector.collect(
      clean: _options.clean,
      dryRun: _options.dryRun,
    );
    onMessage?.call(
      '${_options.dryRun ? 'Would collect' : 'Collected'} '
      '${collection.fileCount} images (${_formatBytes(collection.totalBytes)}).',
    );

    late final ImageOptimizationResult optimization;
    if (!_options.extensions.contains('png')) {
      optimization = const ImageOptimizationResult(
        fileCount: 0,
        optimizedFileCount: 0,
        bytesBefore: 0,
        bytesAfter: 0,
        backend: null,
      );
    } else {
      final optimizationDirectory =
          _options.dryRun ? _options.inputDirectory : Directory(outputPath);
      final optimizer =
          _optimizer ?? ImageOptimizer(inputDirectory: optimizationDirectory);
      optimization = await optimizer.optimize(
        profile: _options.profile,
        requestedBackend: _options.backend,
        jobs: _options.jobs,
        installTools: _options.installTools,
        dryRun: _options.dryRun,
        onMessage: onMessage,
      );
    }
    if (_options.profile != ImageOptimizationProfile.none) {
      onMessage?.call(
        optimization.fileCount == 0
            ? 'No PNG files to optimize.'
            : _options.dryRun
                ? 'Would optimize ${optimization.fileCount} PNG files with '
                    '${_options.profile.cliName} profile.'
                : 'Optimized ${optimization.optimizedFileCount}/'
                    '${optimization.fileCount} PNG files with '
                    '${optimization.backend!.cliName}; saved '
                    '${_formatBytes(optimization.savedBytes)}.',
      );
    }

    if (_options.dryRun) {
      return GoldenPublicationResult(
        collection: collection,
        optimization: optimization,
        report: null,
        reportPath: reportPath,
      );
    }

    final imageFactory = GoldenImageFactory(
      devicePattern: _options.devicePattern,
      localePattern: _options.localePattern,
      themePattern: _options.themePattern,
    );
    final presenter = GoldenPresenter(
      scanner: GoldenCatalogScanner(
        inputDirectory: Directory(outputPath),
        imageFactory: imageFactory,
        runIndex: runIndex,
        goldenDirectoryName: _options.goldenDirectory,
        extensions: _options.extensions,
      ),
      renderer: HtmlReportRenderer(
        outputPath: reportPath,
        title: _options.title,
        showSupportAttribution: _options.supportAttribution,
        customization: _options.customization,
      ),
      writer: HtmlReportWriter(outputPath: reportPath),
    );
    final report = await presenter.generate();
    return GoldenPublicationResult(
      collection: collection,
      optimization: optimization,
      report: report,
      reportPath: reportPath,
    );
  }

  void _validateReportFileName(String value) {
    if (value.isEmpty ||
        path.isAbsolute(value) ||
        path.basename(value) != value ||
        path.extension(value).toLowerCase() != '.html') {
      throw const FormatException(
        '--report-file must be a relative .html filename without directories.',
      );
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    }
    final kibibytes = bytes / 1024;
    if (kibibytes < 1024) {
      return '${kibibytes.toStringAsFixed(1)} KiB';
    }
    return '${(kibibytes / 1024).toStringAsFixed(1)} MiB';
  }
}
