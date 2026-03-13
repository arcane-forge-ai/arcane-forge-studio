import 'dart:convert';

import 'package:crypto/crypto.dart';

const List<String> pendingItemEtagFields = <String>[
  'project_id',
  'item_id',
  'session_id',
  'turn_number',
  'type',
  'content',
  'original_text',
  'merge_action',
  'target_entry_id',
  'conflict_meta',
  'status',
  'version',
];

const List<String> pendingBatchEtagFields = <String>[
  'project_id',
  'batch_version',
  'item_id',
  'version',
  'status',
];

String canonicalJson(Object? value) {
  final normalized = _normalizeForCanonicalJson(value);
  return jsonEncode(normalized);
}

String sha256Hex(Object? value) {
  final bytes = utf8.encode(canonicalJson(value));
  return sha256.convert(bytes).toString();
}

String buildPendingItemEtag(Map<String, dynamic> item) {
  final payload = <String, dynamic>{};
  for (final field in pendingItemEtagFields) {
    payload[field] = item[field];
  }
  return sha256Hex(payload);
}

String buildPendingBatchEtag(
  int projectId,
  int batchVersion,
  List<Map<String, dynamic>> items,
) {
  final sortedItems = List<Map<String, dynamic>>.from(items)
    ..sort((a, b) =>
        (a['item_id']?.toString() ?? '').compareTo(b['item_id']?.toString() ?? ''));

  final vector = sortedItems
      .map(
        (item) => <String, dynamic>{
          'project_id': projectId,
          'batch_version': batchVersion,
          'item_id': item['item_id'],
          'version': item['version'] ?? 0,
          'status': item['status'] ?? 'pending',
        },
      )
      .toList(growable: false);
  return sha256Hex(vector);
}

Object? _normalizeForCanonicalJson(Object? value) {
  if (value is Map) {
    final keys = value.keys.map((k) => k.toString()).toList()..sort();
    final out = <String, Object?>{};
    for (final key in keys) {
      out[key] = _normalizeForCanonicalJson(value[key]);
    }
    return out;
  }
  if (value is List) {
    return value.map(_normalizeForCanonicalJson).toList(growable: false);
  }
  return value;
}

