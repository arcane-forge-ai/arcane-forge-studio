class DocumentWriteSectionSummary {
  final String? sectionId;
  final String? title;
  final String? changeNote;

  DocumentWriteSectionSummary({
    this.sectionId,
    this.title,
    this.changeNote,
  });

  factory DocumentWriteSectionSummary.fromJson(Map<String, dynamic> json) {
    return DocumentWriteSectionSummary(
      sectionId: json['section_id']?.toString(),
      title: json['title']?.toString(),
      changeNote: json['change_note']?.toString(),
    );
  }
}

class DocumentWriteDocumentSummary {
  final String path;
  final int? versionNumber;
  final List<DocumentWriteSectionSummary> sections;

  DocumentWriteDocumentSummary({
    required this.path,
    this.versionNumber,
    required this.sections,
  });

  factory DocumentWriteDocumentSummary.fromJson(Map<String, dynamic> json) {
    final rawSections = json['sections'] as List? ?? const [];
    return DocumentWriteDocumentSummary(
      path: json['path']?.toString() ?? '',
      versionNumber: (json['version_number'] as num?)?.toInt(),
      sections: rawSections
          .map((e) => DocumentWriteSectionSummary.fromJson(
              Map<String, dynamic>.from(e as Map)))
          .toList(growable: false),
    );
  }
}

class DocumentWriteSummary {
  final List<DocumentWriteDocumentSummary> documents;
  final List<String> uncoveredItems;
  final List<String> nextActions;

  DocumentWriteSummary({
    required this.documents,
    required this.uncoveredItems,
    required this.nextActions,
  });

  factory DocumentWriteSummary.fromJson(Map<String, dynamic> json) {
    final rawDocs = json['documents'] as List? ?? const [];
    final rawUncovered = json['uncovered_items'] as List? ?? const [];
    final rawNext = json['next_actions'] as List? ?? const [];

    return DocumentWriteSummary(
      documents: rawDocs
          .map((e) => DocumentWriteDocumentSummary.fromJson(
              Map<String, dynamic>.from(e as Map)))
          .toList(growable: false),
      uncoveredItems:
          rawUncovered.map((e) => e.toString()).toList(growable: false),
      nextActions: rawNext.map((e) => e.toString()).toList(growable: false),
    );
  }
}
