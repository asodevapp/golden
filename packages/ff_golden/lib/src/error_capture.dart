import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

class GoldenDiagnostics {
  final List<FlutterErrorDetails> _overflows = [];

  List<FlutterErrorDetails> get overflows => List.unmodifiable(_overflows);
  bool get hasOverflow => _overflows.isNotEmpty;
}

class GoldenFlutterErrorCapture {
  GoldenFlutterErrorCapture({required this.diagnostics});

  final GoldenDiagnostics diagnostics;

  Future<T> run<T>(
    Future<T> Function() body, {
    required bool failOnOverflow,
  }) async {
    final previous = FlutterError.onError;
    FlutterError.onError = (details) {
      if (_isOverflow(details)) {
        diagnostics._overflows.add(details);
        return;
      }
      previous?.call(details);
    };

    try {
      final result = await body();
      if (failOnOverflow && diagnostics.hasOverflow) {
        final messages = diagnostics.overflows
            .map((details) => details.exceptionAsString())
            .join('\n\n');
        throw TestFailure(
          'ff_golden captured ${diagnostics.overflows.length} layout '
          'overflow(s):\n$messages',
        );
      }
      return result;
    } finally {
      FlutterError.onError = previous;
    }
  }

  bool _isOverflow(FlutterErrorDetails details) {
    final message = details.exceptionAsString();
    return message.contains('RenderFlex overflowed') ||
        message.contains('A RenderFlex overflowed by');
  }
}
