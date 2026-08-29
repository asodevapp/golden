import 'package:ff_golden/src/error_capture.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('layout overflow is a strict failure by default', () async {
    final diagnostics = GoldenDiagnostics();
    final capture = GoldenFlutterErrorCapture(diagnostics: diagnostics);

    await expectLater(
      () => capture.run(() async {
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: FlutterError('A RenderFlex overflowed by 3 pixels.'),
          ),
        );
      }, failOnOverflow: true),
      throwsA(
        isA<TestFailure>().having(
          (failure) => failure.message,
          'message',
          contains('1 layout overflow'),
        ),
      ),
    );
    expect(diagnostics.overflows, hasLength(1));
  });

  test('overflow can be collected as a warning only when opted in', () async {
    final diagnostics = GoldenDiagnostics();

    await GoldenFlutterErrorCapture(diagnostics: diagnostics).run(() async {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: FlutterError('A RenderFlex overflowed by 1 pixel.'),
        ),
      );
    }, failOnOverflow: false);

    expect(diagnostics.overflows, hasLength(1));
  });
}
