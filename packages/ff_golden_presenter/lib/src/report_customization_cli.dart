import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:path/path.dart' as path;

import 'model.dart';

final class ReportCustomizationCliOptions {
  ReportCustomizationCliOptions({
    required this.primaryColor,
    required this.faviconPath,
    required this.headerLinks,
  });

  final String? primaryColor;
  final String? faviconPath;
  final List<GoldenReportLink> headerLinks;

  Future<GoldenReportCustomization> resolve() async {
    return GoldenReportCustomization(
      primaryColor: primaryColor,
      faviconHref: await _loadFaviconDataUri(faviconPath),
      headerLinks: headerLinks,
    );
  }
}

void addReportCustomizationOptions(ArgParser parser) {
  parser
    ..addOption(
      'primary-color',
      valueHelp: 'color',
      help:
          'Accent color as CSS hex or Flutter 0xAARRGGBB (for example #18BFFB).',
    )
    ..addOption(
      'favicon',
      valueHelp: 'file',
      help: 'PNG, SVG, ICO, JPEG, WebP, or GIF favicon embedded in the report.',
    )
    ..addMultiOption(
      'header-link',
      valueHelp: 'label=url',
      splitCommas: false,
      help:
          'Header navigation link; repeat for multiple links (for example Home=https://example.com).',
    );
}

ReportCustomizationCliOptions parseReportCustomization(ArgResults results) {
  final links = <GoldenReportLink>[];
  for (final value in results['header-link'] as List<String>) {
    final separator = value.indexOf('=');
    if (separator <= 0 || separator == value.length - 1) {
      throw FormatException(
        'Invalid --header-link "$value". Expected label=url.',
      );
    }
    links.add(
      GoldenReportLink(
        label: value.substring(0, separator),
        url: value.substring(separator + 1),
      ),
    );
  }

  final favicon = results['favicon'] as String?;
  if (favicon != null && favicon.trim().isEmpty) {
    throw const FormatException('--favicon must not be empty.');
  }

  final validated = GoldenReportCustomization(
    primaryColor: results['primary-color'] as String?,
    headerLinks: links,
  );
  return ReportCustomizationCliOptions(
    primaryColor: validated.primaryColor,
    faviconPath: favicon?.trim(),
    headerLinks: validated.headerLinks,
  );
}

Future<String?> _loadFaviconDataUri(String? sourcePath) async {
  if (sourcePath == null) {
    return null;
  }
  final file = File(path.normalize(path.absolute(sourcePath)));
  if (!await file.exists()) {
    throw FormatException('Favicon file does not exist: ${file.path}');
  }
  final extension = path.extension(file.path).toLowerCase();
  final mimeType = switch (extension) {
    '.png' => 'image/png',
    '.svg' => 'image/svg+xml',
    '.ico' => 'image/x-icon',
    '.jpg' || '.jpeg' => 'image/jpeg',
    '.webp' => 'image/webp',
    '.gif' => 'image/gif',
    _ => throw FormatException(
        'Unsupported favicon extension "$extension". '
        'Use PNG, SVG, ICO, JPEG, WebP, or GIF.',
      ),
  };
  final encoded = base64Encode(await file.readAsBytes());
  return 'data:$mimeType;base64,$encoded';
}
