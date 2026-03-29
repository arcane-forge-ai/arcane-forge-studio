import 'package:arcane_forge/screens/game_design_assistant_v2/models/project_context.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('pending list response items is mutable for provider updates', () {
    final response = PendingKnowledgeListResponse.fromJson({
      'items': [
        {
          'id': 'item-1',
          'project_id': 1,
          'session_id': 's1',
          'turn_number': 1,
          'type': 'decision',
          'content': 'A',
          'status': 'pending',
          'version': 1,
          'item_etag': 'etag-1',
        },
        {
          'id': 'item-2',
          'project_id': 1,
          'session_id': 's1',
          'turn_number': 2,
          'type': 'decision',
          'content': 'B',
          'status': 'pending',
          'version': 1,
          'item_etag': 'etag-2',
        },
      ],
      'batch_version': 1,
      'batch_etag': 'batch-etag',
      'read_mode': 'dual',
      'migration_state': 'started',
      'migration_coverage': {},
      'write_gate': {},
    });

    response.items.removeWhere((item) => item.id == 'item-1');
    expect(response.items.length, 1);
    expect(response.items.first.id, 'item-2');
  });
}

