import 'package:flutter/widgets.dart';

import 'variant.dart';

class GoldenPathCollision implements Exception {
  const GoldenPathCollision(this.collisions);

  final Map<String, List<GoldenVariant>> collisions;

  @override
  String toString() {
    final paths = collisions.keys.join(', ');
    return 'GoldenPathCollision: multiple variants resolve to: $paths. '
        'Use includeDefaultAxes or change duplicate axis names.';
  }
}

class GoldenPathStrategy {
  const GoldenPathStrategy({
    this.folder = 'golden',
    this.includeDefaultAxes = false,
  });

  final String folder;
  final bool includeDefaultAxes;

  String build({
    required String scenario,
    required GoldenVariant variant,
    String testName = '',
  }) {
    final buffer = StringBuffer();
    if (testName.isNotEmpty) {
      buffer
        ..write(ffGoldenSafeName(testName))
        ..write('.');
    }
    buffer.write(ffGoldenSafeName(variant.device.name));

    if (includeDefaultAxes || !variant.theme.isDefault) {
      buffer
        ..write('[')
        ..write(ffGoldenSafeName(variant.theme.name))
        ..write(']');
    }
    if (includeDefaultAxes || !_isDefaultEnglish(variant.locale)) {
      buffer
        ..write('(')
        ..write(ffGoldenSafeName(variant.locale.toLanguageTag()))
        ..write(')');
    }
    if (includeDefaultAxes || variant.textScale != 1) {
      buffer
        ..write('{text-')
        ..write(_number(variant.textScale))
        ..write('}');
    }
    if (includeDefaultAxes || variant.direction != GoldenDirection.auto) {
      buffer
        ..write('{')
        ..write(variant.direction.name)
        ..write('}');
    }
    if (includeDefaultAxes || variant.platform != variant.device.platform) {
      buffer
        ..write('{')
        ..write(variant.platform.name)
        ..write('}');
    }
    if (includeDefaultAxes || variant.brightness != variant.device.brightness) {
      buffer
        ..write('{')
        ..write(variant.brightness.name)
        ..write('}');
    }
    if (includeDefaultAxes || variant.highContrast) {
      buffer.write(
          variant.highContrast ? '{high-contrast}' : '{normal-contrast}');
    }
    return '${ffGoldenSafeName(folder)}/${ffGoldenSafeName(scenario)}/$buffer.png';
  }

  Map<String, List<GoldenVariant>> collisions({
    required String scenario,
    required Iterable<GoldenVariant> variants,
    String testName = '',
  }) {
    final byPath = <String, List<GoldenVariant>>{};
    for (final variant in variants) {
      final path = build(
        scenario: scenario,
        variant: variant,
        testName: testName,
      );
      byPath.putIfAbsent(path.toLowerCase(), () => []).add(variant);
    }
    return Map.fromEntries(
      byPath.entries.where((entry) => entry.value.length > 1),
    );
  }

  void validate({
    required String scenario,
    required Iterable<GoldenVariant> variants,
    String testName = '',
  }) {
    final found = collisions(
      scenario: scenario,
      variants: variants,
      testName: testName,
    );
    if (found.isNotEmpty) throw GoldenPathCollision(found);
  }

  bool _isDefaultEnglish(Locale locale) =>
      locale.languageCode == 'en' &&
      locale.countryCode == null &&
      locale.scriptCode == null;

  String _number(double value) => value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toString();
}

String ffGoldenSafeName(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return 'unnamed';
  return trimmed
      .replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '-')
      .replaceAll(RegExp('-+'), '-')
      .replaceAll(RegExp(r'^[-.]+|[-.]+$'), '');
}
