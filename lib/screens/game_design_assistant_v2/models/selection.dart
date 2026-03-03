class SelectionOption {
  final String id;
  final String label;
  final String? description;

  SelectionOption({
    required this.id,
    required this.label,
    this.description,
  });

  factory SelectionOption.fromJson(Map<String, dynamic> json) {
    return SelectionOption(
      id: json['id']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      description: json['description']?.toString(),
    );
  }
}

class SelectionInfo {
  final String title;
  final String? description;
  final List<SelectionOption> options;
  final bool allowMultiple;
  final int minSelection;
  final int maxSelection;

  SelectionInfo({
    required this.title,
    this.description,
    required this.options,
    this.allowMultiple = false,
    this.minSelection = 1,
    this.maxSelection = 1,
  });

  factory SelectionInfo.fromJson(Map<String, dynamic> json) {
    final rawOptions = json['options'] as List? ?? const [];
    return SelectionInfo(
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString(),
      options: rawOptions
          .map((e) =>
              SelectionOption.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      allowMultiple: json['allow_multiple'] == true,
      minSelection: (json['min_selection'] as num?)?.toInt() ?? 1,
      maxSelection: (json['max_selection'] as num?)?.toInt() ?? 1,
    );
  }
}
