import 'package:flutter/widgets.dart';

import 'device.dart';
import 'theme.dart';
import 'variant.dart';

enum GoldenSampling {
  full,
  smoke,
  pairwise,
  priority,
}

typedef GoldenVariantPredicate = bool Function(GoldenVariant variant);
typedef GoldenVariantPriority = int Function(GoldenVariant variant);

enum _GoldenRuleKind { require, exclude }

@immutable
class GoldenCoverageRule {
  const GoldenCoverageRule.require(this.name, this.predicate)
      : _kind = _GoldenRuleKind.require;

  const GoldenCoverageRule.excludeWhen(this.name, this.predicate)
      : _kind = _GoldenRuleKind.exclude;

  final String name;
  final GoldenVariantPredicate predicate;
  final _GoldenRuleKind _kind;

  bool allows(GoldenVariant variant) => switch (_kind) {
        _GoldenRuleKind.require => predicate(variant),
        _GoldenRuleKind.exclude => !predicate(variant),
      };
}

@immutable
class GoldenCoveragePlan {
  const GoldenCoveragePlan({
    required this.rawCount,
    required this.excludedCount,
    required this.sampling,
    required this.variants,
  });

  final int rawCount;
  final int excludedCount;
  final GoldenSampling sampling;
  final List<GoldenVariant> variants;

  int get selectedCount => variants.length;

  @override
  String toString() =>
      'GoldenCoveragePlan(raw: $rawCount, excluded: $excludedCount, '
      'selected: $selectedCount, sampling: ${sampling.name})';
}

class GoldenCoverageBudgetExceeded implements Exception {
  const GoldenCoverageBudgetExceeded({
    required this.strategy,
    required this.requiredCount,
    required this.maxCombinations,
  });

  final GoldenSampling strategy;
  final int requiredCount;
  final int maxCombinations;

  @override
  String toString() =>
      'GoldenCoverageBudgetExceeded: ${strategy.name} needs $requiredCount '
      'combinations, but maxCombinations is $maxCombinations. Increase the '
      'budget or use GoldenSampling.priority for a hard cap.';
}

class GoldenCoverage {
  GoldenCoverage({
    Iterable<GoldenDevice>? devices,
    Iterable<Locale>? locales,
    Iterable<GoldenTheme>? themes,
    Iterable<double>? textScales,
    Iterable<GoldenDirection> directions = const [GoldenDirection.auto],
    Iterable<TargetPlatform>? platforms,
    Iterable<Brightness>? brightnesses,
    Iterable<bool>? highContrasts,
    Iterable<GoldenCoverageRule> rules = const [],
    this.sampling = GoldenSampling.full,
    this.maxCombinations = 256,
    this.priority,
  })  : devices = List<GoldenDevice>.unmodifiable(
          devices ?? const <GoldenDevice>[GoldenDevice.iPhone11],
        ),
        locales = List<Locale>.unmodifiable(
          locales ?? const <Locale>[Locale('en', 'US')],
        ),
        themes = List<GoldenTheme>.unmodifiable(
          themes ?? <GoldenTheme>[GoldenTheme.defaultTheme],
        ),
        textScales = textScales == null ? null : List.unmodifiable(textScales),
        directions = List.unmodifiable(directions),
        platforms = platforms == null ? null : List.unmodifiable(platforms),
        brightnesses =
            brightnesses == null ? null : List.unmodifiable(brightnesses),
        highContrasts =
            highContrasts == null ? null : List.unmodifiable(highContrasts),
        rules = List.unmodifiable(rules) {
    _validateAxes();
  }

  final List<GoldenDevice> devices;
  final List<Locale> locales;
  final List<GoldenTheme> themes;
  final List<double>? textScales;
  final List<GoldenDirection> directions;
  final List<TargetPlatform>? platforms;
  final List<Brightness>? brightnesses;
  final List<bool>? highContrasts;
  final List<GoldenCoverageRule> rules;
  final GoldenSampling sampling;
  final int maxCombinations;
  final GoldenVariantPriority? priority;

  GoldenCoveragePlan plan() {
    final raw = _cartesianProduct();
    final feasible = raw
        .where((variant) => rules.every((rule) => rule.allows(variant)))
        .toList(growable: false);

    final sampled = switch (sampling) {
      GoldenSampling.full => List<GoldenVariant>.of(feasible),
      GoldenSampling.smoke => _coverAxisValues(feasible),
      GoldenSampling.pairwise => _coverPairs(feasible),
      GoldenSampling.priority => _prioritize(feasible),
    };

    if (sampling == GoldenSampling.priority) {
      if (sampled.length > maxCombinations) {
        sampled.removeRange(maxCombinations, sampled.length);
      }
    } else if (sampled.length > maxCombinations) {
      throw GoldenCoverageBudgetExceeded(
        strategy: sampling,
        requiredCount: sampled.length,
        maxCombinations: maxCombinations,
      );
    }

    return GoldenCoveragePlan(
      rawCount: raw.length,
      excludedCount: raw.length - feasible.length,
      sampling: sampling,
      variants: List.unmodifiable(sampled),
    );
  }

  List<GoldenVariant> _cartesianProduct() {
    final result = <GoldenVariant>[];
    for (final device in devices) {
      final deviceTextScales = textScales ?? [device.textScale];
      final devicePlatforms = platforms ?? [device.platform];
      final deviceBrightnesses = brightnesses ?? [device.brightness];
      final deviceContrasts = highContrasts ?? [device.highContrast];

      for (final locale in locales) {
        for (final theme in themes) {
          for (final textScale in deviceTextScales) {
            for (final direction in directions) {
              for (final platform in devicePlatforms) {
                for (final brightness in deviceBrightnesses) {
                  for (final highContrast in deviceContrasts) {
                    result.add(
                      GoldenVariant(
                        device: device,
                        locale: locale,
                        theme: theme,
                        textScale: textScale,
                        direction: direction,
                        platform: platform,
                        brightness: brightness,
                        highContrast: highContrast,
                      ),
                    );
                  }
                }
              }
            }
          }
        }
      }
    }
    return result;
  }

  List<GoldenVariant> _prioritize(List<GoldenVariant> variants) {
    final indexed = variants.indexed.toList();
    indexed.sort((left, right) {
      final scoreCompare = (priority?.call(right.$2) ?? _defaultRisk(right.$2))
          .compareTo(priority?.call(left.$2) ?? _defaultRisk(left.$2));
      return scoreCompare != 0 ? scoreCompare : left.$1.compareTo(right.$1);
    });
    return indexed.map((entry) => entry.$2).toList();
  }

  int _defaultRisk(GoldenVariant variant) {
    var score = 0;
    final area =
        variant.device.logicalSize.width * variant.device.logicalSize.height;
    if (area <= 400 * 900) score += 4;
    if (variant.textScale > 1) score += 3;
    if (variant.textDirection == TextDirection.rtl) score += 3;
    if (variant.highContrast) score += 2;
    if (variant.brightness == Brightness.dark) score += 1;
    return score;
  }

  List<GoldenVariant> _coverAxisValues(List<GoldenVariant> variants) {
    if (variants.isEmpty) return [];
    final uncovered = variants.expand((variant) => variant.axisValues).toSet();
    return _greedyCover(
      variants,
      uncovered,
      (variant) => variant.axisValues.toSet(),
    );
  }

  List<GoldenVariant> _coverPairs(List<GoldenVariant> variants) {
    if (variants.isEmpty) return [];
    final pairsByVariant = <GoldenVariant, Set<String>>{};
    final uncovered = <String>{};
    for (final variant in variants) {
      final values = variant.axisValues;
      final pairs = <String>{};
      for (var left = 0; left < values.length; left++) {
        for (var right = left + 1; right < values.length; right++) {
          pairs.add('$left:${values[left]}|$right:${values[right]}');
        }
      }
      pairsByVariant[variant] = pairs;
      uncovered.addAll(pairs);
    }
    return _greedyCover(
      variants,
      uncovered,
      (variant) => pairsByVariant[variant]!,
    );
  }

  List<GoldenVariant> _greedyCover(
    List<GoldenVariant> candidates,
    Set<String> uncovered,
    Set<String> Function(GoldenVariant) tokens,
  ) {
    final remaining = List<GoldenVariant>.of(candidates);
    final selected = <GoldenVariant>[];
    while (uncovered.isNotEmpty && remaining.isNotEmpty) {
      var bestIndex = 0;
      var bestGain = -1;
      var bestRisk = -1;
      for (var index = 0; index < remaining.length; index++) {
        final variant = remaining[index];
        final gain = tokens(variant).where(uncovered.contains).length;
        final risk = priority?.call(variant) ?? _defaultRisk(variant);
        if (gain > bestGain || (gain == bestGain && risk > bestRisk)) {
          bestIndex = index;
          bestGain = gain;
          bestRisk = risk;
        }
      }
      if (bestGain <= 0) break;
      final best = remaining.removeAt(bestIndex);
      selected.add(best);
      uncovered.removeAll(tokens(best));
    }
    return selected;
  }

  void _validateAxes() {
    if (devices.isEmpty ||
        locales.isEmpty ||
        themes.isEmpty ||
        directions.isEmpty) {
      throw ArgumentError('Golden coverage axes must not be empty.');
    }
    if (maxCombinations <= 0) {
      throw ArgumentError.value(
        maxCombinations,
        'maxCombinations',
        'must be greater than zero',
      );
    }
    final scales = textScales;
    if (scales != null &&
        scales.any((scale) => scale <= 0 || !scale.isFinite)) {
      throw ArgumentError.value(
        scales,
        'textScales',
        'values must be finite and greater than zero',
      );
    }
    _ensureUnique('device names', devices.map((device) => device.name));
    _ensureUnique('theme names', themes.map((theme) => theme.name));
    _ensureUnique(
      'locales',
      locales.map((locale) => locale.toLanguageTag()),
    );
  }

  void _ensureUnique(String axis, Iterable<String> values) {
    final normalized = <String>{};
    for (final value in values) {
      if (!normalized.add(value.toLowerCase())) {
        throw ArgumentError('Duplicate $axis value: $value');
      }
    }
  }
}
