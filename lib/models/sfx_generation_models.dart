enum GenerationStatus {
  pending,
  queued,
  generating,
  completed,
  failed,
}

class SfxAsset {
  final String id;
  final String projectId;
  final String name;
  final String description;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<SfxGeneration> generations;
  final String? favoriteGenerationId;
  final List<String> tags;
  final Map<String, dynamic> metadata;
  final int? fileSize;
  final int totalGenerations;

  SfxAsset({
    required this.id,
    required this.projectId,
    required this.name,
    required this.description,
    required this.createdAt,
    required this.updatedAt,
    required this.generations,
    this.favoriteGenerationId,
    this.tags = const [],
    this.metadata = const {},
    this.fileSize,
    this.totalGenerations = 0,
  });

  SfxAsset copyWith({
    String? id,
    String? projectId,
    String? name,
    String? description,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<SfxGeneration>? generations,
    String? favoriteGenerationId,
    List<String>? tags,
    Map<String, dynamic>? metadata,
    int? fileSize,
    int? totalGenerations,
  }) {
    return SfxAsset(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      name: name ?? this.name,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      generations: generations ?? this.generations,
      favoriteGenerationId: favoriteGenerationId ?? this.favoriteGenerationId,
      tags: tags ?? this.tags,
      metadata: metadata ?? this.metadata,
      fileSize: fileSize ?? this.fileSize,
      totalGenerations: totalGenerations ?? this.totalGenerations,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SfxAsset && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

class SfxGeneration {
  final String id;
  final String assetId;
  final String? audioPath;
  final String? audioUrl;
  final Map<String, dynamic> parameters;
  final DateTime createdAt;
  final GenerationStatus status;
  final bool isFavorite;
  final int? fileSize;
  final double? duration;
  final String? format;
  final Map<String, dynamic> metadata;
  final DateTime? queuedAt;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final String? errorMessage;

  SfxGeneration({
    required this.id,
    required this.assetId,
    this.audioPath,
    this.audioUrl,
    required this.parameters,
    required this.createdAt,
    required this.status,
    this.isFavorite = false,
    this.fileSize,
    this.duration,
    this.format,
    this.metadata = const {},
    this.queuedAt,
    this.startedAt,
    this.completedAt,
    this.errorMessage,
  });

  SfxGeneration copyWith({
    String? id,
    String? assetId,
    String? audioPath,
    String? audioUrl,
    Map<String, dynamic>? parameters,
    DateTime? createdAt,
    GenerationStatus? status,
    bool? isFavorite,
    int? fileSize,
    double? duration,
    String? format,
    Map<String, dynamic>? metadata,
    DateTime? queuedAt,
    DateTime? startedAt,
    DateTime? completedAt,
    String? errorMessage,
  }) {
    return SfxGeneration(
      id: id ?? this.id,
      assetId: assetId ?? this.assetId,
      audioPath: audioPath ?? this.audioPath,
      audioUrl: audioUrl ?? this.audioUrl,
      parameters: parameters ?? this.parameters,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
      isFavorite: isFavorite ?? this.isFavorite,
      fileSize: fileSize ?? this.fileSize,
      duration: duration ?? this.duration,
      format: format ?? this.format,
      metadata: metadata ?? this.metadata,
      queuedAt: queuedAt ?? this.queuedAt,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

class SfxGenerationRequest {
  final String prompt;
  final String? negativePrompt;
  final String model;
  final double? durationSeconds;
  final double? promptInfluence;

  SfxGenerationRequest({
    required this.prompt,
    this.negativePrompt,
    this.model = 'elevenlabs',
    this.durationSeconds,
    this.promptInfluence,
  });

  Map<String, dynamic> toParameters() {
    final params = <String, dynamic>{
      'prompt': prompt,
      'model': model,
    };
    
    if (negativePrompt != null && negativePrompt!.isNotEmpty) {
      params['negative_prompt'] = negativePrompt;
    }
    if (durationSeconds != null) {
      params['duration_seconds'] = durationSeconds;
    }
    if (promptInfluence != null) {
      params['prompt_influence'] = promptInfluence;
    }
    
    return params;
  }

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'prompt': prompt,
      'model': model,
    };
    
    if (negativePrompt != null && negativePrompt!.isNotEmpty) {
      json['negative_prompt'] = negativePrompt;
    }
    if (durationSeconds != null) {
      json['duration_seconds'] = durationSeconds;
    }
    if (promptInfluence != null) {
      json['prompt_influence'] = promptInfluence;
    }
    
    return json;
  }
}

class SfxGenerationParameters {
  final Map<String, dynamic> _params;

  SfxGenerationParameters(this._params);

  // Core parameters with getters
  String get model => _params['model'] ?? 'elevenlabs';
  String get prompt => _params['prompt'] ?? '';
  String get negativePrompt => _params['negative_prompt'] ?? '';
  double get durationSeconds => _params['duration_seconds'] ?? 2.0;
  double get promptInfluence => _params['prompt_influence'] ?? 0.5;

  // Extensible: any other parameters
  dynamic operator [](String key) => _params[key];
  Map<String, dynamic> toJson() => Map<String, dynamic>.from(_params);
} 