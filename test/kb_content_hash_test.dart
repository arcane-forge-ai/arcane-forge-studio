import 'dart:convert';

import 'package:arcane_forge/utils/kb_content_hash.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('preserves existing signed FNV-1a manifest hash vectors', () {
    const Map<String, String> vectors = <String, String>{
      '': '-340d631b7bdddcdb',
      'a': '-509c23b379fe1374',
      'foobar': '-7a6bbe8e08c69818',
      'hello': '-5bcf27b97f5542f5',
      'hello world': '779a65e7023cd2e7',
      '# changed': '-b75759f437c68ce',
    };

    for (final MapEntry<String, String> vector in vectors.entries) {
      expect(kbContentHash(utf8.encode(vector.key)), vector.value);
    }
  });

  test('hashes binary contents with exact 64-bit overflow', () {
    expect(
      kbContentHash(List<int>.generate(256, (int i) => i)),
      '4242dc5249c33625',
    );
  });
}
