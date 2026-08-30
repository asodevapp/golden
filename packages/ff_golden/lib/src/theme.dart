import 'package:flutter/material.dart';

/// A named Flutter theme used as a golden coverage axis.
@immutable
class GoldenTheme {
  /// Creates a named theme and optionally marks it as the default variant.
  const GoldenTheme({
    required this.name,
    required this.data,
    this.isDefault = false,
  });

  /// Stable name used in test labels and golden filenames.
  final String name;

  /// Flutter theme data installed for the variant.
  final ThemeData data;

  /// Whether filenames may omit this theme for migration-friendly paths.
  final bool isDefault;

  /// The default light theme.
  static final defaultTheme = GoldenTheme(
    name: 'light',
    data: ThemeData.light(),
    isDefault: true,
  );

  /// Alias for [defaultTheme].
  static final light = defaultTheme;

  /// The built-in dark theme.
  static final dark = GoldenTheme(name: 'dark', data: ThemeData.dark());

  @override
  String toString() => 'GoldenTheme($name)';
}

/// Deprecated compatibility name for [GoldenTheme].
@Deprecated('Use GoldenTheme. The alias will be removed in ff_golden 2.0.')
typedef NamedTheme = GoldenTheme;
