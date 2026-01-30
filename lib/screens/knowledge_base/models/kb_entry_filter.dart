/// Model for knowledge base entry filtering
class KBEntryFilter {
  final List<String> entryTypes;
  final String? visibility;
  final List<String> authorityLevels;
  final List<String> tags;

  const KBEntryFilter({
    this.entryTypes = const [],
    this.visibility,
    this.authorityLevels = const [],
    this.tags = const [],
  });

  bool get hasActiveFilters =>
      entryTypes.isNotEmpty ||
      visibility != null ||
      authorityLevels.isNotEmpty ||
      tags.isNotEmpty;

  KBEntryFilter copyWith({
    List<String>? entryTypes,
    String? visibility,
    List<String>? authorityLevels,
    List<String>? tags,
  }) {
    return KBEntryFilter(
      entryTypes: entryTypes ?? this.entryTypes,
      visibility: visibility,
      authorityLevels: authorityLevels ?? this.authorityLevels,
      tags: tags ?? this.tags,
    );
  }

  KBEntryFilter clearAll() {
    return const KBEntryFilter();
  }
}
