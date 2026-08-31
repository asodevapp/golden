import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'variant.dart';

/// Opt-in metadata collection for the local presenter. The dedicated tag keeps
/// ordinary golden/widget tests out of discovery runs, including on older SDKs.
const goldenDiscoveryEnabled = bool.fromEnvironment('FF_GOLDEN_DISCOVERY');

void registerGoldenDiscovery({
  required String testName,
  required String description,
  required GoldenVariant variant,
  String? scenario,
  bool legacy = false,
}) {
  test(testName, () {
    // Flutter's JSON reporter attaches the real (group-prefixed) test ID/name.
    // Do not call widget builders, scenario hooks, captures, or reporters here.
    // ignore: avoid_print
    print('FF_GOLDEN_DISCOVERY ${jsonEncode({
          'schema': 1,
          'description': description,
          'scenario': scenario,
          'api': legacy ? 'legacy' : 'coverage',
          'axes': {
            'device': variant.device.name,
            'theme': variant.theme.name,
            'locale': variant.locale.toLanguageTag(),
            if (!legacy) ...{
              'textScale': '${variant.textScale}',
              'direction': variant.textDirection.name,
              'platform': variant.platform.name,
              'highContrast': '${variant.highContrast}',
            },
          },
        })}');
  }, tags: const ['ff_golden_discovery']);
}
