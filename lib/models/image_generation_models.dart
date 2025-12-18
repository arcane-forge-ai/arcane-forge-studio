
enum GenerationStatus {
  pending,
  generating,
  completed,
  failed,
}

class ImageAsset {
  final String id;
  final String projectId;
  final String name;
  final String description;
  final DateTime createdAt;
  final List<ImageGeneration> generations;
  final String? thumbnail;
  final String? favoriteGenerationId;
  final int? totalGenerations; // Total count from API when generations list is not included
  final List<String> tags;
  final Map<String, dynamic> metadata;

  ImageAsset({
    required this.id,
    required this.projectId,
    required this.name,
    required this.description,
    required this.createdAt,
    required this.generations,
    this.thumbnail,
    this.favoriteGenerationId,
    this.totalGenerations,
    this.tags = const [],
    this.metadata = const {},
  });

  ImageAsset copyWith({
    String? id,
    String? projectId,
    String? name,
    String? description,
    DateTime? createdAt,
    List<ImageGeneration>? generations,
    String? thumbnail,
    String? favoriteGenerationId,
    int? totalGenerations,
    List<String>? tags,
    Map<String, dynamic>? metadata,
  }) {
    return ImageAsset(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      name: name ?? this.name,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      generations: generations ?? this.generations,
      thumbnail: thumbnail ?? this.thumbnail,
      favoriteGenerationId: favoriteGenerationId ?? this.favoriteGenerationId,
      totalGenerations: totalGenerations ?? this.totalGenerations,
      tags: tags ?? this.tags,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ImageAsset && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

class ImageGeneration {
  final String id;
  final String assetId;
  final String imagePath;
  final String? imageUrl; // Online URL from Supabase
  final Map<String, dynamic> parameters;
  final DateTime createdAt;
  final GenerationStatus status;
  final bool isFavorite;

  ImageGeneration({
    required this.id,
    required this.assetId,
    required this.imagePath,
    this.imageUrl,
    required this.parameters,
    required this.createdAt,
    required this.status,
    this.isFavorite = false,
  });

  ImageGeneration copyWith({
    String? id,
    String? assetId,
    String? imagePath,
    String? imageUrl,
    Map<String, dynamic>? parameters,
    DateTime? createdAt,
    GenerationStatus? status,
    bool? isFavorite,
  }) {
    return ImageGeneration(
      id: id ?? this.id,
      assetId: assetId ?? this.assetId,
      imagePath: imagePath ?? this.imagePath,
      imageUrl: imageUrl ?? this.imageUrl,
      parameters: parameters ?? this.parameters,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }
}

class GenerationParameters {
  final Map<String, dynamic> _params;

  GenerationParameters(this._params);

  // Core parameters with getters
  String get model => _params['model'] ?? '';
  String get positivePrompt => _params['positive_prompt'] ?? '';
  String get negativePrompt => _params['negative_prompt'] ?? '';
  int get width => _params['width'] ?? 512;
  int get height => _params['height'] ?? 512;
  int get steps => _params['steps'] ?? 20;
  double get cfgScale => _params['cfg_scale'] ?? 7.0;
  String get sampler => _params['sampler'] ?? 'euler';
  int get seed => _params['seed'] ?? -1;

  // LoRA parameters
  List<Map<String, dynamic>> get loras =>
      List<Map<String, dynamic>>.from(_params['loras'] ?? []);

  // Extensible: any other parameters
  dynamic operator [](String key) => _params[key];
  Map<String, dynamic> toJson() => Map<String, dynamic>.from(_params);
}

class ComfyUIStatus {
  final bool isRunning;
  final bool isConnected;
  final String? error;
  final String host;
  final int? port;
  final List<String> logs;

  ComfyUIStatus({
    required this.isRunning,
    required this.isConnected,
    this.error,
    required this.host,
    this.port,
    required this.logs,
  });

  ComfyUIStatus copyWith({
    bool? isRunning,
    bool? isConnected,
    String? error,
    String? host,
    int? port,
    List<String>? logs,
  }) {
    return ComfyUIStatus(
      isRunning: isRunning ?? this.isRunning,
      isConnected: isConnected ?? this.isConnected,
      error: error ?? this.error,
      host: host ?? this.host,
      port: port ?? this.port,
      logs: logs ?? this.logs,
    );
  }
}

class AIModel {
  final String id;
  final String name;
  final String type; // 'checkpoint' or 'lora'
  final String path;
  final String? description;
  final DateTime? lastModified;

  AIModel({
    required this.id,
    required this.name,
    required this.type,
    required this.path,
    this.description,
    this.lastModified,
  });
}

/// A1111 Checkpoint model from /sdapi/v1/sd-models
class A1111Checkpoint {
  final String title;
  final String modelName;
  final String? hash;
  final String? sha256;
  final String filename;
  final String? config;

  A1111Checkpoint({
    required this.title,
    required this.modelName,
    this.hash,
    this.sha256,
    required this.filename,
    this.config,
  });

  factory A1111Checkpoint.fromJson(Map<String, dynamic> json) {
    return A1111Checkpoint(
      title: json['title'] ?? '',
      modelName: json['model_name'] ?? '',
      hash: json['hash'],
      sha256: json['sha256'],
      filename: json['filename'] ?? '',
      config: json['config'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'model_name': modelName,
      'hash': hash,
      'sha256': sha256,
      'filename': filename,
      'config': config,
    };
  }
}

/// A1111 LoRA model from /sdapi/v1/loras
class A1111Lora {
  final String name;
  final String? alias;
  final String path;
  final Map<String, dynamic>? metadata;

  A1111Lora({
    required this.name,
    this.alias,
    required this.path,
    this.metadata,
  });

  factory A1111Lora.fromJson(Map<String, dynamic> json) {
    return A1111Lora(
      name: json['name'] ?? '',
      alias: json['alias'],
      path: json['path'] ?? '',
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'alias': alias,
      'path': path,
      'metadata': metadata,
    };
  }
}

class GenerationRequest {
  final String? assetId; // Made optional for simplified workflow
  final String positivePrompt;
  final String negativePrompt;
  final String model;
  final int width;
  final int height;
  final int steps;
  final double cfgScale;
  final String sampler;
  final String scheduler;
  final int seed;
  final List<Map<String, dynamic>> loras;

  GenerationRequest({
    this.assetId, // Made optional
    required this.positivePrompt,
    required this.negativePrompt,
    required this.model,
    required this.width,
    required this.height,
    required this.steps,
    required this.cfgScale,
    required this.sampler,
    required this.scheduler,
    required this.seed,
    this.loras = const [], // Added default value
  });

  Map<String, dynamic> toParameters() {
    return {
      'asset_id': assetId,
      'model': model,
      'positive_prompt': positivePrompt,
      'negative_prompt': negativePrompt,
      'width': width,
      'height': height,
      'steps': steps,
      'cfg_scale': cfgScale,
      'sampler': sampler,
      'scheduler': scheduler,
      'seed': seed,
      'loras': loras,
    };
  }
}


/// A1111 Model from backend API /api/v1/image-generation/models
class A1111Model {
  final String name;
  final String provider;
  final String? displayName;
  final String? description;
  final Map<String, dynamic>? metadata;
  final bool isActive;

  A1111Model({
    required this.name,
    required this.provider,
    this.displayName,
    this.description,
    this.metadata,
    required this.isActive,
  });

  factory A1111Model.fromJson(Map<String, dynamic> json) {
    return A1111Model(
      name: json['name'] ?? '',
      provider: json['provider'] ?? '',
      displayName: json['display_name'],
      description: json['description'],
      metadata: json['metadata'] as Map<String, dynamic>?,
      isActive: json['is_active'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'provider': provider,
      'display_name': displayName,
      'description': description,
      'metadata': metadata,
      'is_active': isActive,
    };
  }
}

/// Online image generation request for backend API
class OnlineImageGenerationRequest {
  final String prompt;
  final String model;
  final String? negativePrompt;
  final String? size;
  final String? quality;
  final String? outputFormat;
  final String? outputCompression;
  final int? n;
  final int? width;
  final int? height;
  final int? steps;
  final double? cfgScale;
  final String? sampler;
  final String? scheduler;
  final int? seed;
  final List<Map<String, dynamic>>? loras;

  OnlineImageGenerationRequest({
    required this.prompt,
    required this.model,
    this.negativePrompt,
    this.size,
    this.quality,
    this.outputFormat,
    this.outputCompression,
    this.n,
    this.width,
    this.height,
    this.steps,
    this.cfgScale,
    this.sampler,
    this.scheduler,
    this.seed,
    this.loras,
  });

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'prompt': prompt,
      'model': model,
    };
    
    if (negativePrompt != null) json['negative_prompt'] = negativePrompt;
    if (size != null) json['size'] = size;
    if (quality != null) json['quality'] = quality;
    if (outputFormat != null) json['output_format'] = outputFormat;
    if (outputCompression != null) json['output_compression'] = outputCompression;
    if (n != null) json['n'] = n;
    if (width != null) json['width'] = width;
    if (height != null) json['height'] = height;
    if (steps != null) json['steps'] = steps;
    if (cfgScale != null) json['cfg_scale'] = cfgScale;
    if (sampler != null) json['sampler'] = sampler;
    if (scheduler != null) json['scheduler'] = scheduler;
    if (seed != null) json['seed'] = seed;
    if (loras != null && loras!.isNotEmpty) json['loras'] = loras;
    
    return json;
  }
}

/// Online image generation response from backend API
class OnlineImageGenerationResponse {
  final String id;
  final String status;
  final String? imageUrl;
  final String? error;
  final Map<String, dynamic>? metadata;

  OnlineImageGenerationResponse({
    required this.id,
    required this.status,
    this.imageUrl,
    this.error,
    this.metadata,
  });

  factory OnlineImageGenerationResponse.fromJson(Map<String, dynamic> json) {
    return OnlineImageGenerationResponse(
      id: json['id'] ?? '',
      status: json['status'] ?? '',
      imageUrl: json['image_url'],
      error: json['error'],
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'status': status,
      'image_url': imageUrl,
      'error': error,
      'metadata': metadata,
    };
  }
}

/// Simplified image generation model for the new workflow
class GeneratedImage {
  final String id;
  final String prompt;
  final String negativePrompt;
  final int width;
  final int height;
  final int steps;
  final double cfgScale;
  final int seed;
  final String model;
  final String sampler;
  final String scheduler;
  final DateTime createdAt;
  final GenerationStatus status;
  final String? imagePath;
  final String? error;

  GeneratedImage({
    required this.id,
    required this.prompt,
    required this.negativePrompt,
    required this.width,
    required this.height,
    required this.steps,
    required this.cfgScale,
    required this.seed,
    required this.model,
    required this.sampler,
    required this.scheduler,
    required this.createdAt,
    required this.status,
    this.imagePath,
    this.error,
  });

  GeneratedImage copyWith({
    String? id,
    String? prompt,
    String? negativePrompt,
    int? width,
    int? height,
    int? steps,
    double? cfgScale,
    int? seed,
    String? model,
    String? sampler,
    String? scheduler,
    DateTime? createdAt,
    GenerationStatus? status,
    String? imagePath,
    String? error,
  }) {
    return GeneratedImage(
      id: id ?? this.id,
      prompt: prompt ?? this.prompt,
      negativePrompt: negativePrompt ?? this.negativePrompt,
      width: width ?? this.width,
      height: height ?? this.height,
      steps: steps ?? this.steps,
      cfgScale: cfgScale ?? this.cfgScale,
      seed: seed ?? this.seed,
      model: model ?? this.model,
      sampler: sampler ?? this.sampler,
      scheduler: scheduler ?? this.scheduler,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
      imagePath: imagePath ?? this.imagePath,
      error: error ?? this.error,
    );
  }
}
