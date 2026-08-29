import 'package:flutter/material.dart';

@immutable
class GoldenTheme {
  const GoldenTheme({
    required this.name,
    required this.data,
    this.isDefault = false,
  });

  final String name;
  final ThemeData data;
  final bool isDefault;

  static final defaultTheme = GoldenTheme(
    name: 'light',
    data: ThemeData.light(),
    isDefault: true,
  );

  static final light = defaultTheme;
  static final dark = GoldenTheme(name: 'dark', data: ThemeData.dark());

  @override
  String toString() => 'GoldenTheme($name)';
}

@Deprecated('Use GoldenTheme. The alias will be removed in ff_golden 2.0.')
typedef NamedTheme = GoldenTheme;
