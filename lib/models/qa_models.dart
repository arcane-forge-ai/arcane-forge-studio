/// Models for Project Knowledge Q&A API
/// Based on design doc: design_docs/PROJECT_QA_API_FRONTEND.md

class QARequest {
  final String question;
  final String? context;
  final String? userRole; // "vendor" | "internal"

  const QARequest({
    required this.question,
    this.context,
    this.userRole,
  });

  Map<String, dynamic> toJson() => {
        'question': question,
        if (context != null) 'context': context,
        if (userRole != null) 'user_role': userRole,
      };
}

class QAResponse {
  final String answer;
  final List<QAReference> references;
  final String confidence; // "high" | "medium" | "low" | "unknown"
  final QAEscalation? escalation;
  final bool needsHumanVerification;

  const QAResponse({
    required this.answer,
    required this.references,
    required this.confidence,
    this.escalation,
    required this.needsHumanVerification,
  });

  factory QAResponse.fromJson(Map<String, dynamic> json) {
    return QAResponse(
      answer: json['answer'] as String,
      references: (json['references'] as List<dynamic>)
          .map((ref) => QAReference.fromJson(ref as Map<String, dynamic>))
          .toList(),
      confidence: json['confidence'] as String,
      escalation: json['escalation'] != null
          ? QAEscalation.fromJson(json['escalation'] as Map<String, dynamic>)
          : null,
      needsHumanVerification: json['needs_human_verification'] as bool,
    );
  }
}

class QAReference {
  final String type; // "document" | "link" | "folder" | "contact" | "responsibility_area"
  final String title;
  final String? url;
  final String? source;
  final String? excerpt;

  const QAReference({
    required this.type,
    required this.title,
    this.url,
    this.source,
    this.excerpt,
  });

  factory QAReference.fromJson(Map<String, dynamic> json) {
    return QAReference(
      type: json['type'] as String,
      title: json['title'] as String,
      url: json['url'] as String?,
      source: json['source'] as String?,
      excerpt: json['excerpt'] as String?,
    );
  }
}

class QAEscalation {
  final String contactName;
  final String? contactMethod;
  final String? area;
  final String reason;

  const QAEscalation({
    required this.contactName,
    this.contactMethod,
    this.area,
    required this.reason,
  });

  factory QAEscalation.fromJson(Map<String, dynamic> json) {
    return QAEscalation(
      contactName: json['contact_name'] as String,
      contactMethod: json['contact_method'] as String?,
      area: json['area'] as String?,
      reason: json['reason'] as String,
    );
  }
}

class ResponsibilityArea {
  final int? id;
  final int? projectId;
  final String areaName;
  final List<String> areaKeywords;
  final String internalContact;
  final String externalDisplayName;
  final String? contactMethod;
  final String? notes;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const ResponsibilityArea({
    this.id,
    this.projectId,
    required this.areaName,
    required this.areaKeywords,
    required this.internalContact,
    required this.externalDisplayName,
    this.contactMethod,
    this.notes,
    this.createdAt,
    this.updatedAt,
  });

  factory ResponsibilityArea.fromJson(Map<String, dynamic> json) {
    return ResponsibilityArea(
      id: json['id'] as int?,
      projectId: json['project_id'] as int?,
      areaName: json['area_name'] as String,
      areaKeywords: (json['area_keywords'] as List<dynamic>)
          .map((k) => k as String)
          .toList(),
      internalContact: json['internal_contact'] as String,
      externalDisplayName: json['external_display_name'] as String,
      contactMethod: json['contact_method'] as String?,
      notes: json['notes'] as String?,
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        if (projectId != null) 'project_id': projectId,
        'area_name': areaName,
        'area_keywords': areaKeywords,
        'internal_contact': internalContact,
        'external_display_name': externalDisplayName,
        if (contactMethod != null) 'contact_method': contactMethod,
        if (notes != null) 'notes': notes,
        if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
        if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
      };

  ResponsibilityArea copyWith({
    int? id,
    int? projectId,
    String? areaName,
    List<String>? areaKeywords,
    String? internalContact,
    String? externalDisplayName,
    String? contactMethod,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ResponsibilityArea(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      areaName: areaName ?? this.areaName,
      areaKeywords: areaKeywords ?? this.areaKeywords,
      internalContact: internalContact ?? this.internalContact,
      externalDisplayName: externalDisplayName ?? this.externalDisplayName,
      contactMethod: contactMethod ?? this.contactMethod,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class QAPublicAccessSettings {
  final bool isEnabled;
  final String? passcode;

  const QAPublicAccessSettings({
    required this.isEnabled,
    this.passcode,
  });

  Map<String, dynamic> toJson() => {
        'is_enabled': isEnabled,
        if (passcode != null) 'passcode': passcode,
      };

  factory QAPublicAccessSettings.fromJson(Map<String, dynamic> json) {
    return QAPublicAccessSettings(
      isEnabled: json['is_enabled'] as bool,
      passcode: json['passcode'] as String?,
    );
  }
}

class QAAccessVerification {
  final bool isValid;
  final String? errorMessage;

  const QAAccessVerification({
    required this.isValid,
    this.errorMessage,
  });

  factory QAAccessVerification.fromJson(Map<String, dynamic> json) {
    return QAAccessVerification(
      isValid: json['is_valid'] as bool,
      errorMessage: json['error_message'] as String?,
    );
  }
}
