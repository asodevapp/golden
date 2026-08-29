import 'dart:convert';

import 'package:ff_golden/ff_golden.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('font loader accepts an empty Flutter font manifest', () async {
    await loadFfGoldenFonts(bundle: _MemoryBundle('[]'));
  });

  test('font loader explains malformed manifests', () async {
    await expectLater(
      loadFfGoldenFonts(bundle: _MemoryBundle('{}')),
      throwsA(isA<GoldenFontLoadException>()),
    );
  });
}

class _MemoryBundle extends CachingAssetBundle {
  _MemoryBundle(this.manifest);

  final String manifest;

  @override
  Future<ByteData> load(String key) async {
    final bytes = Uint8List.fromList(utf8.encode(manifest));
    return ByteData.sublistView(bytes);
  }
}
