import 'package:flutter/widgets.dart';

import 'device.dart';
import 'theme.dart';

enum GoldenDirection {
  auto,
  ltr,
  rtl;

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

@immutable
class GoldenVariant {
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

  final GoldenDevice device;
  final Locale locale;
  final GoldenTheme theme;
  final double textScale;
  final GoldenDirection direction;
  final TargetPlatform platform;
  final Brightness brightness;
  final bool highContrast;

  TextDirection get textDirection => direction.resolve(locale);

  String get label {
    final contrast = highContrast ? ', high-contrast' : '';
    return '${device.name}, ${theme.name}, ${locale.toLanguageTag()}, '
        '${textScale}x text, ${textDirection.name}, ${platform.name}$contrast';
  }

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
