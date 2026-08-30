import 'package:flutter/widgets.dart';

import 'device.dart';
import 'theme.dart';

/// The text direction requested by one golden variant.
enum GoldenDirection {
  auto,
  ltr,
  rtl;

  /// Resolves this mode to the concrete direction for [locale].
  TextDirection resolve(Locale locale) => switch (this) {
        GoldenDirection.auto => _rtlLanguages.contains(locale.languageCode)
            ? TextDirection.rtl
            : TextDirection.ltr,
        GoldenDirection.ltr => TextDirection.ltr,
        GoldenDirection.rtl => TextDirection.rtl,
      };
}

const _rtlLanguages = <String>{
  'ar',
  'dv',
  'fa',
  'he',
  'ku',
  'ps',
  'sd',
  'ug',
  'ur',
};

/// One fully resolved combination of golden coverage axes.
@immutable
class GoldenVariant {
  /// Creates a variant with explicit values for every rendering axis.
  const GoldenVariant({
    required this.device,
    required this.locale,
    required this.theme,
    required this.textScale,
    required this.direction,
    required this.platform,
    required this.brightness,
    required this.highContrast,
  }) : assert(textScale > 0);

  /// Device geometry and defaults used by this variant.
  final GoldenDevice device;

  /// Locale installed for the rendered widget tree.
  final Locale locale;

  /// Named theme installed for the rendered widget tree.
  final GoldenTheme theme;

  /// Text scale factor exposed through `MediaQuery`.
  final double textScale;

  /// Requested direction mode before locale resolution.
  final GoldenDirection direction;

  /// Target platform applied to Flutter and the theme.
  final TargetPlatform platform;

  /// Brightness exposed through the test view.
  final Brightness brightness;

  /// Whether high-contrast rendering is enabled.
  final bool highContrast;

  /// Concrete direction resolved from [direction] and [locale].
  TextDirection get textDirection => direction.resolve(locale);

  /// Human-readable description used in diagnostics.
  String get label {
    final contrast = highContrast ? ', high-contrast' : '';
    return '${device.name}, ${theme.name}, ${locale.toLanguageTag()}, '
        '${textScale}x text, ${textDirection.name}, ${platform.name}$contrast';
  }

  /// Stable key-value tokens used by coverage sampling algorithms.
  List<String> get axisValues => <String>[
        'device=${device.name}',
        'theme=${theme.name}',
        'locale=${locale.toLanguageTag()}',
        'textScale=$textScale',
        'direction=${direction.name}',
        'platform=${platform.name}',
        'brightness=${brightness.name}',
        'highContrast=$highContrast',
      ];

  @override
  String toString() => 'GoldenVariant($label)';
}
