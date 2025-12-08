import '../../game_design_assistant/models/api_models.dart';

/// Model class for grouping multiple versions of files with the same name
class FileVersionGroup {
  final String fileName;
  final List<KnowledgeBaseFile> versions;

  FileVersionGroup({
    required this.fileName,
    required this.versions,
  });

  /// Get the most recent version (first in the sorted list)
  KnowledgeBaseFile get latestVersion => versions.first;

  /// Get the number of versions
  int get versionCount => versions.length;

  /// Check if this file has multiple versions
  bool get hasMultipleVersions => versions.length > 1;

  /// Get all versions except the latest (for showing in expanded view)
  List<KnowledgeBaseFile> get olderVersions => 
      versions.length > 1 ? versions.sublist(1) : [];
}

