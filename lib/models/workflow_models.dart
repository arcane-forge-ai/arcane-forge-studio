/// Workflow models for image generation workflow-based system

class WorkflowVersion {
  final String id;
  final String workflowId;
  final int version;
  final String model;
  final String? promptAddition;
  final String? promptDeletion;
  final String? promptAiModificationPrompt;
  final Map<String, dynamic> additionalConfig;
  final bool isDefault;
  final DateTime createdAt;
  final String? createdBy;
  final List<String> supportedAspectRatios;
  final String defaultAspectRatio;
  final int? baseResolution;

  WorkflowVersion({
    required this.id,
    required this.workflowId,
    required this.version,
    required this.model,
    this.promptAddition,
    this.promptDeletion,
    this.promptAiModificationPrompt,
    this.additionalConfig = const {},
    required this.isDefault,
    required this.createdAt,
    this.createdBy,
    this.supportedAspectRatios = const [],
    this.defaultAspectRatio = '16:9',
    this.baseResolution,
  });

  factory WorkflowVersion.fromJson(Map<String, dynamic> json) {
    return WorkflowVersion(
      id: json['id'] as String,
      workflowId: json['workflow_id'] as String,
      version: json['version'] as int,
      model: json['model'] as String,
      promptAddition: json['prompt_addition'] as String?,
      promptDeletion: json['prompt_deletion'] as String?,
      promptAiModificationPrompt: json['prompt_ai_modification_prompt'] as String?,
      additionalConfig: json['additional_config'] as Map<String, dynamic>? ?? {},
      isDefault: json['is_default'] as bool,
      createdAt: DateTime.parse(json['created_at'] as String),
      createdBy: json['created_by'] as String?,
      supportedAspectRatios: (json['supported_aspect_ratios'] as List<dynamic>?)?.map((e) => e as String).toList() ?? [],
      defaultAspectRatio: json['default_aspect_ratio'] as String? ?? '16:9',
      baseResolution: json['base_resolution'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'workflow_id': workflowId,
      'version': version,
      'model': model,
      'prompt_addition': promptAddition,
      'prompt_deletion': promptDeletion,
      'prompt_ai_modification_prompt': promptAiModificationPrompt,
      'additional_config': additionalConfig,
      'is_default': isDefault,
      'created_at': createdAt.toIso8601String(),
      'created_by': createdBy,
      'supported_aspect_ratios': supportedAspectRatios,
      'default_aspect_ratio': defaultAspectRatio,
      'base_resolution': baseResolution,
    };
  }
}

class Workflow {
  final String id;
  final String name;
  final String? category;
  final String? description;
  final String visibility;
  final List<String> tags;
  final List<String> sampleImages;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final WorkflowVersion? defaultVersion;

  Workflow({
    required this.id,
    required this.name,
    this.category,
    this.description,
    required this.visibility,
    this.tags = const [],
    this.sampleImages = const [],
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
    this.defaultVersion,
  });

  factory Workflow.fromJson(Map<String, dynamic> json) {
    return Workflow(
      id: json['id'] as String,
      name: json['name'] as String,
      category: json['category'] as String?,
      description: json['description'] as String?,
      visibility: json['visibility'] as String,
      tags: (json['tags'] as List<dynamic>?)?.map((e) => e as String).toList() ?? [],
      sampleImages: (json['sample_images'] as List<dynamic>?)?.map((e) => e as String).toList() ?? [],
      isActive: json['is_active'] as bool,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      defaultVersion: json['default_version'] != null 
          ? WorkflowVersion.fromJson(json['default_version'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'description': description,
      'visibility': visibility,
      'tags': tags,
      'sample_images': sampleImages,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'default_version': defaultVersion?.toJson(),
    };
  }
}

class WorkflowListResponse {
  final List<Workflow> workflows;
  final int total;

  WorkflowListResponse({
    required this.workflows,
    required this.total,
  });

  factory WorkflowListResponse.fromJson(Map<String, dynamic> json) {
    return WorkflowListResponse(
      workflows: (json['workflows'] as List<dynamic>)
          .map((e) => Workflow.fromJson(e as Map<String, dynamic>))
          .toList(),
      total: json['total'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'workflows': workflows.map((w) => w.toJson()).toList(),
      'total': total,
    };
  }
}

class WorkflowRecommendRequest {
  final String instruction;
  final Map<String, dynamic> additionalInfo;
  final int count;

  WorkflowRecommendRequest({
    required this.instruction,
    this.additionalInfo = const {},
    this.count = 3,
  });

  Map<String, dynamic> toJson() {
    return {
      'instruction': instruction,
      'additional_info': additionalInfo,
      'count': count,
    };
  }
}

class WorkflowExecuteRequest {
  final String assetId;
  final String prompt;
  final int? version;
  final Map<String, dynamic>? generationConfig;

  WorkflowExecuteRequest({
    required this.assetId,
    required this.prompt,
    this.version,
    this.generationConfig,
  });

  Map<String, dynamic> toJson() {
    return {
      'asset_id': assetId,
      'prompt': prompt,
      if (version != null) 'version': version,
      if (generationConfig != null) 'generation_config': generationConfig,
    };
  }
}

