import 'package:arcane_forge/screens/game_design_assistant_v2/utils/pending_etag_contract.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('canonical json uses deterministic key ordering', () {
    final left = <String, dynamic>{
      'b': 1,
      'a': 2,
      'nested': <String, dynamic>{'z': 3, 'm': 4},
    };
    final right = <String, dynamic>{
      'a': 2,
      'nested': <String, dynamic>{'m': 4, 'z': 3},
      'b': 1,
    };

    expect(canonicalJson(left), canonicalJson(right));
  });

  test('pending item etag matches backend golden vector', () {
    final item = <String, dynamic>{
      'project_id': 42,
      'item_id': 'mem_example',
      'session_id': 's-example',
      'turn_number': 12,
      'type': 'decision',
      'content': 'Use pixel art style',
      'original_text': "Let's use pixel art",
      'merge_action': 'add',
      'target_entry_id': null,
      'conflict_meta': null,
      'status': 'pending',
      'version': 3,
    };

    expect(
      buildPendingItemEtag(item),
      '53075a0a86a720013efebef7268935e6b10209c5108a694bbbe92547ac3e7acd',
    );
  });

  test('pending batch etag matches backend golden vector', () {
    final base = <String, dynamic>{
      'project_id': 42,
      'session_id': 's-example',
      'turn_number': 12,
      'type': 'decision',
      'content': 'Use pixel art style',
      'original_text': "Let's use pixel art",
      'merge_action': 'add',
      'target_entry_id': null,
      'conflict_meta': null,
    };
    final items = <Map<String, dynamic>>[
      <String, dynamic>{
        ...base,
        'item_id': 'mem_b',
        'version': 2,
        'status': 'pending',
      },
      <String, dynamic>{
        ...base,
        'item_id': 'mem_a',
        'version': 5,
        'status': 'pending',
      },
    ];

    expect(
      buildPendingBatchEtag(42, 7, items),
      'eea648084238c42b2e55e8603a94d4544f1c711b4c9f99a5380d028ce5598100',
    );
  });
}

