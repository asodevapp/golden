import 'package:path/path.dart' as path;

import 'model.dart';

/// Extracts device, theme, and locale variants from a golden filename.
final class GoldenImageFactory {
  GoldenImageFactory({
    required String devicePattern,
    required String localePattern,
    required String themePattern,
  })  : _devicePattern = _compile(devicePattern, 'device-pattern'),
        _localePattern = _compile(localePattern, 'locale-pattern'),
        _themePattern = _compile(themePattern, 'theme-pattern');

  final RegExp _devicePattern;
  final RegExp _localePattern;
  final RegExp _themePattern;

  GoldenImage build({
    required String fileName,
    required String absolutePath,
    GoldenImageMetadata? metadata,
  }) {
    final name = path.basenameWithoutExtension(fileName);
    final axes = _filenameAxes(name);
    return GoldenImage(
      fileName: fileName,
      path: absolutePath,
      device: metadata?.device ?? _capture(name, _devicePattern) ?? name,
      locale: metadata?.locale ?? _capture(name, _localePattern),
      theme: metadata?.theme ?? _capture(name, _themePattern),
      captureName: metadata?.captureName,
      textScale: metadata?.textScale ?? axes.textScale,
      direction: metadata?.direction ?? axes.direction,
      directionMode: metadata?.directionMode ?? axes.direction,
      platform: metadata?.platform ?? axes.platform,
      brightness: metadata?.brightness ?? axes.brightness,
      highContrast: metadata?.highContrast ?? axes.highContrast,
      status: metadata?.status ?? GoldenImageStatus.unknown,
      durationMs: metadata?.durationMs,
      overflowCount: metadata?.overflowCount,
      failurePhase: metadata?.failurePhase,
      error: metadata?.error,
      sourceTestFile: metadata?.sourceTestFile,
      extension: path.extension(fileName).replaceFirst('.', '').toLowerCase(),
    );
  }

  _FilenameAxes _filenameAxes(String name) {
    double? textScale;
    String? direction;
    String? platform;
    String? brightness;
    bool? highContrast;
    for (final match in RegExp(r'\{([^}]+)\}').allMatches(name)) {
      final value = match.group(1)!;
      if (value.startsWith('text-')) {
        textScale = double.tryParse(value.substring('text-'.length));
      } else if (value == 'ltr' || value == 'rtl' || value == 'auto') {
        direction = value;
      } else if (_platforms.contains(value)) {
        platform = value;
      } else if (value == 'light' || value == 'dark') {
        brightness = value;
      } else if (value == 'high-contrast') {
        highContrast = true;
      } else if (value == 'normal-contrast') {
        highContrast = false;
      }
    }
    return _FilenameAxes(
      textScale: textScale,
      direction: direction,
      platform: platform,
      brightness: brightness,
      highContrast: highContrast,
    );
  }

  static RegExp _compile(String pattern, String optionName) {
    try {
      return RegExp(pattern);
    } on FormatException catch (error) {
      throw FormatException('Invalid --$optionName: ${error.message}');
    }
  }

  static String? _capture(String source, RegExp expression) {
    final match = expression.firstMatch(source);
    if (match == null) {
      return null;
    }
    if (match.groupCount < 1) {
      throw FormatException(
        'Variant patterns must contain at least one capture group.',
      );
    }
    final value = match.group(1)?.trim();
    return value == null || value.isEmpty ? null : value;
  }
}

const _platforms = {
  'android',
  'fuchsia',
  'iOS',
  'linux',
  'macOS',
  'windows',
};

final class _FilenameAxes {
  const _FilenameAxes({
    this.textScale,
    this.direction,
    this.platform,
    this.brightness,
    this.highContrast,
  });

  final double? textScale;
  final String? direction;
  final String? platform;
  final String? brightness;
  final bool? highContrast;
}
