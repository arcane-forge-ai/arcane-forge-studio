import 'sfx_generation_models.dart'; // Reuse GenerationStatus enum

class MusicAsset {
  final String id;
  final String projectId;
  final String name;
  final String description;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<MusicGeneration> generations;
  final String? favoriteGenerationId;
  final List<String> tags;
  final Map<String, dynamic> metadata;
  final int? fileSize;
  final int totalGenerations;

  MusicAsset({
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

  MusicAsset copyWith({
    String? id,
    String? projectId,
    String? name,
    String? description,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<MusicGeneration>? generations,
    String? favoriteGenerationId,
    List<String>? tags,
    Map<String, dynamic>? metadata,
    int? fileSize,
    int? totalGenerations,
  }) {
    return MusicAsset(
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
    return other is MusicAsset && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

class MusicGeneration {
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

  MusicGeneration({
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
  });

  MusicGeneration copyWith({
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
  }) {
    return MusicGeneration(
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
    );
  }
}

class MusicGenerationRequest {
  final String prompt;
  final int musicLengthMs; // Length in milliseconds (1000-600000 = 1s-10min)

  MusicGenerationRequest({
    required this.prompt,
    required this.musicLengthMs,
  });

  Map<String, dynamic> toParameters() {
    return {
      'prompt': prompt,
      'music_length_ms': musicLengthMs,
    };
  }

  Map<String, dynamic> toJson() {
    return {
      'prompt': prompt,
      'music_length_ms': musicLengthMs,
    };
  }
}

class MusicGenerationParameters {
  final Map<String, dynamic> _params;

  MusicGenerationParameters(this._params);

  // Core parameters with getters
  String get prompt => _params['prompt'] ?? '';
  int get musicLengthMs => _params['music_length_ms'] ?? 30000;

  // Extensible: any other parameters
  dynamic operator [](String key) => _params[key];
  Map<String, dynamic> toJson() => Map<String, dynamic>.from(_params);
}

