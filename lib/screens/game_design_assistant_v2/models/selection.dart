import 'package:flutter/foundation.dart';

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
  final String questionId;
  final String title;
  final String? description;
  final List<SelectionOption> options;
  final bool allowMultiple;
  final int minSelection;
  final int maxSelection;
  final DateTime expiresAt;

  SelectionInfo({
    required this.questionId,
    required this.title,
    this.description,
    required this.options,
    this.allowMultiple = false,
    this.minSelection = 1,
    this.maxSelection = 1,
    required this.expiresAt,
  });

  factory SelectionInfo.fromJson(Map<String, dynamic> json) {
    final rawOptions = json['options'] as List? ?? const [];
    final expiresRaw = json['expires_at']?.toString() ?? '';
    final parsedExpiresAt = DateTime.tryParse(expiresRaw);
    if (parsedExpiresAt == null) {
      assert(() {
        debugPrint('[SelectionInfo] Invalid expires_at: $expiresRaw');
        return true;
      }());
    }
    return SelectionInfo(
      questionId: json['question_id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString(),
      options: rawOptions
          .map((e) =>
              SelectionOption.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      allowMultiple: json['allow_multiple'] == true,
      minSelection: (json['min_selection'] as num?)?.toInt() ?? 1,
      maxSelection: (json['max_selection'] as num?)?.toInt() ?? 1,
      expiresAt: parsedExpiresAt ??
          DateTime.now().toUtc().add(const Duration(minutes: 10)),
    );
  }
}

class SelectionAnswer {
  final String questionId;
  final String action;
  final List<String> selectedIds;
  final String? freeText;

  SelectionAnswer({
    required this.questionId,
    required this.action,
    this.selectedIds = const [],
    this.freeText,
  });

  Map<String, dynamic> toJson() {
    return {
      'question_id': questionId,
      'action': action,
      'selected_ids': selectedIds,
      if (freeText != null && freeText!.trim().isNotEmpty)
        'free_text': freeText!.trim(),
    };
  }
}
