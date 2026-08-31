import 'dart:convert';

/// Values emitted by ff_golden after planning the real test configuration.
final class ReviewTestVariant {
  const ReviewTestVariant(this.fullName, this.description, this.axes);
  final String fullName, description;
  final Map<String, String> axes;
}

/// Reads Flutter's JSON reporter, associating metadata with the actual grouped
/// test name. Project output is data, never a command or a filesystem path.
final class ReviewVariantReader {
  final variants = <ReviewTestVariant>[];
  final _names = <int, String>{};
  String? error;
  static const prefix = 'FF_GOLDEN_DISCOVERY ';

  void addLine(String line) {
    if (line.length > 64 * 1024 || error != null) return;
    Object? event;
    try {
      event = jsonDecode(line);
    } on FormatException {
      return;
    }
    if (event is! Map) return;
    if (event['type'] == 'testStart' && event['test'] is Map) {
      final test = event['test'] as Map;
      if (test['id'] is int &&
          test['name'] is String &&
          _names.length < 10000) {
        _names[test['id'] as int] = test['name'] as String;
      }
    }
    final message = event['message'];
    if (event['type'] != 'print' ||
        message is! String ||
        !message.startsWith(prefix)) {
      return;
    }
    try {
      final data = jsonDecode(message.substring(prefix.length));
      final name = _names[event['testID']];
      if (data is! Map ||
          data['schema'] != 1 ||
          name == null ||
          data['description'] is! String ||
          data['axes'] is! Map ||
          !{'legacy', 'coverage'}.contains(data['api'])) {
        throw const FormatException('Unsupported variant metadata.');
      }
      final axes = Map<String, String>.from(data['axes'] as Map);
      const allowed = {
        'device',
        'theme',
        'locale',
        'textScale',
        'direction',
        'platform',
        'highContrast'
      };
      if (axes.keys.any((key) => !allowed.contains(key)) ||
          !axes.keys.toSet().containsAll(['device', 'theme', 'locale']) ||
          axes.values.any((value) =>
              value.isEmpty ||
              value.length > 200 ||
              value.contains(RegExp(r'[\x00-\x1f]'))) ||
          name.length > 4096) {
        throw const FormatException('Invalid variant values.');
      }
      final scale = double.tryParse(axes['textScale'] ?? '');
      if (data['api'] == 'coverage' &&
          (scale == null ||
              !scale.isFinite ||
              scale <= 0 ||
              !{'ltr', 'rtl'}.contains(axes['direction']) ||
              !{'android', 'fuchsia', 'iOS', 'linux', 'macOS', 'windows'}
                  .contains(axes['platform']) ||
              !{'true', 'false'}.contains(axes['highContrast']))) {
        throw const FormatException('Invalid coverage axes.');
      }
      if (variants.length >= 10000) {
        throw const FormatException(
            'More than 10000 variants; choose a smaller test file.');
      }
      variants
          .add(ReviewTestVariant(name, data['description'] as String, axes));
    } catch (_) {
      error =
          'Could not read variant metadata. Check the ff_golden version and test output.';
    }
  }
}
