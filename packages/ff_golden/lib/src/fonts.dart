import 'dart:convert';

import 'package:flutter/services.dart';

/// Loads every font declared by the application into the test engine.
///
/// Call this once from `test/flutter_test_config.dart` before running golden
/// tests. This prevents Flutter from silently rendering text with a fallback
/// font when the application uses custom font assets.
Future<void> loadFfGoldenFonts({
  AssetBundle? bundle,
  Set<String> excludedFamilies = const <String>{},
}) async {
  final assetBundle = bundle ?? rootBundle;
  final Object? decoded;
  try {
    decoded = jsonDecode(await assetBundle.loadString('FontManifest.json'));
  } on Object catch (error) {
    throw GoldenFontLoadException(
      'Could not load FontManifest.json. Make sure the Flutter test binding '
      'is initialized and fonts are declared in pubspec.yaml.',
      error,
    );
  }

  if (decoded is! List<Object?>) {
    throw const GoldenFontLoadException(
      'FontManifest.json must contain a list of font families.',
    );
  }

  for (final Object? rawFamily in decoded) {
    if (rawFamily is! Map<String, Object?>) {
      throw const GoldenFontLoadException(
        'FontManifest.json contains an invalid font-family entry.',
      );
    }
    final family = rawFamily['family'];
    final fonts = rawFamily['fonts'];
    if (family is! String || fonts is! List<Object?>) {
      throw const GoldenFontLoadException(
        'Every font family must contain a family name and a fonts list.',
      );
    }
    if (excludedFamilies.contains(family)) continue;

    final loader = FontLoader(family);
    for (final Object? rawFont in fonts) {
      if (rawFont is! Map<String, Object?> || rawFont['asset'] is! String) {
        throw GoldenFontLoadException(
          'Font family "$family" contains an invalid asset entry.',
        );
      }
      loader.addFont(assetBundle.load(rawFont['asset']! as String));
    }
    await loader.load();
  }
}

class GoldenFontLoadException implements Exception {
  const GoldenFontLoadException(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() => cause == null
      ? 'GoldenFontLoadException: $message'
      : 'GoldenFontLoadException: $message\nCaused by: $cause';
}
