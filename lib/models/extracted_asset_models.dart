import 'dart:convert';

/// Model for extracted assets from document content
class ExtractedAsset {
  final String name;
  final String? description;
  final List<String> tags;
  final Map<String, dynamic> metadata;

  ExtractedAsset({
    required this.name,
    this.description,
    this.tags = const [],
    this.metadata = const {},
  });

  factory ExtractedAsset.fromJson(Map<String, dynamic> json) {
    return ExtractedAsset(
      name: json['name'] ?? '',
      description: json['description'],
      tags: List<String>.from(json['tags'] ?? []),
      metadata: Map<String, dynamic>.from(json['metadata'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'description': description,
      'tags': tags,
      'metadata': metadata,
    };
  }
}

/// Editable version of ExtractedAsset for the UI
class EditableExtractedAsset {
  String name;
  String description;
  List<String> tags;
  Map<String, dynamic> metadata;

  EditableExtractedAsset({
    required this.name,
    required this.description,
    this.tags = const [],
    this.metadata = const {},
  });

  factory EditableExtractedAsset.fromExtractedAsset(ExtractedAsset asset) {
    return EditableExtractedAsset(
      name: asset.name,
      description: asset.description ?? '',
      tags: List<String>.from(asset.tags),
      metadata: Map<String, dynamic>.from(asset.metadata),
    );
  }

  ExtractedAsset toExtractedAsset() {
    return ExtractedAsset(
      name: name,
      description: description.isEmpty ? null : description,
      tags: tags,
      metadata: metadata,
    );
  }

  String get tagsAsString => tags.join(', ');
  
  set tagsAsString(String value) {
    tags = value.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
  }

  String get metadataAsString {
    try {
      return const JsonEncoder.withIndent('  ').convert(metadata);
    } catch (e) {
      return metadata.toString();
    }
  }
  
  set metadataAsString(String value) {
    try {
      final decoded = jsonDecode(value);
      if (decoded is Map<String, dynamic>) {
        metadata = decoded;
      } else {
        // If it's not a valid JSON object, store as a simple key-value
        metadata = {'raw': value};
      }
    } catch (e) {
      // If JSON parsing fails, try to parse as key: value pairs
      final lines = value.split('\n');
      final newMetadata = <String, dynamic>{};
      
      for (final line in lines) {
        final parts = line.split(':');
        if (parts.length >= 2) {
          final key = parts[0].trim();
          final value = parts.sublist(1).join(':').trim();
          
          // Try to parse the value as different types
          if (value.toLowerCase() == 'true') {
            newMetadata[key] = true;
          } else if (value.toLowerCase() == 'false') {
            newMetadata[key] = false;
          } else if (double.tryParse(value) != null) {
            newMetadata[key] = double.parse(value);
          } else {
            newMetadata[key] = value;
          }
        }
      }
      
      if (newMetadata.isNotEmpty) {
        metadata = newMetadata;
      } else {
        // Fallback: store as raw text
        metadata = {'raw': value};
      }
    }
  }
}
