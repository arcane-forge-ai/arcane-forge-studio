enum ResourceCommentType {
  project,
  imageAsset,
  imageGeneration,
  sfxAsset,
  sfxGeneration,
  musicAsset,
  musicGeneration,
}

extension ResourceCommentTypeWireName on ResourceCommentType {
  String get wireName {
    switch (this) {
      case ResourceCommentType.project:
        return 'project';
      case ResourceCommentType.imageAsset:
        return 'image_asset';
      case ResourceCommentType.imageGeneration:
        return 'image_generation';
      case ResourceCommentType.sfxAsset:
        return 'sfx_asset';
      case ResourceCommentType.sfxGeneration:
        return 'sfx_generation';
      case ResourceCommentType.musicAsset:
        return 'music_asset';
      case ResourceCommentType.musicGeneration:
        return 'music_generation';
    }
  }

  String get displayName {
    switch (this) {
      case ResourceCommentType.project:
        return 'project';
      case ResourceCommentType.imageAsset:
        return 'image asset';
      case ResourceCommentType.imageGeneration:
        return 'image';
      case ResourceCommentType.sfxAsset:
        return 'SFX asset';
      case ResourceCommentType.sfxGeneration:
        return 'SFX generation';
      case ResourceCommentType.musicAsset:
        return 'music asset';
      case ResourceCommentType.musicGeneration:
        return 'music generation';
    }
  }

  static ResourceCommentType parse(String value) {
    return ResourceCommentType.values.firstWhere(
      (type) => type.wireName == value,
      orElse: () =>
          throw FormatException('Unknown comment resource type: $value'),
    );
  }
}

class ResourceCommentTarget {
  final ResourceCommentType type;
  final String? resourceId;

  const ResourceCommentTarget.project()
      : type = ResourceCommentType.project,
        resourceId = null;

  const ResourceCommentTarget.resource(this.type, this.resourceId)
      : assert(type != ResourceCommentType.project),
        assert(resourceId != null && resourceId != '');
}

class ResourceComment {
  final int id;
  final int projectId;
  final ResourceCommentType resourceType;
  final String? resourceId;
  final String? createdByUserId;
  final String? authorUsername;
  final String? body;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final String? deletedByUserId;
  final bool isDeleted;

  const ResourceComment({
    required this.id,
    required this.projectId,
    required this.resourceType,
    required this.resourceId,
    required this.createdByUserId,
    required this.authorUsername,
    required this.body,
    required this.createdAt,
    required this.updatedAt,
    required this.deletedAt,
    required this.deletedByUserId,
    required this.isDeleted,
  });

  factory ResourceComment.fromJson(Map<String, dynamic> json) {
    return ResourceComment(
      id: (json['id'] as num).toInt(),
      projectId: (json['project_id'] as num).toInt(),
      resourceType: ResourceCommentTypeWireName.parse(
        json['resource_type'] as String,
      ),
      resourceId: json['resource_id']?.toString(),
      createdByUserId: json['created_by_user_id']?.toString(),
      authorUsername: json['author_username'] as String?,
      body: json['body'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      deletedAt: json['deleted_at'] == null
          ? null
          : DateTime.parse(json['deleted_at'] as String),
      deletedByUserId: json['deleted_by_user_id']?.toString(),
      isDeleted: json['is_deleted'] as bool? ?? false,
    );
  }
}

class ResourceCommentPage {
  final List<ResourceComment> comments;
  final int total;
  final int limit;
  final int offset;
  final bool hasMore;

  const ResourceCommentPage({
    required this.comments,
    required this.total,
    required this.limit,
    required this.offset,
    required this.hasMore,
  });

  factory ResourceCommentPage.fromJson(Map<String, dynamic> json) {
    return ResourceCommentPage(
      comments: (json['comments'] as List<dynamic>? ?? const [])
          .map((item) => ResourceComment.fromJson(
                Map<String, dynamic>.from(item as Map),
              ))
          .toList(),
      total: (json['total'] as num?)?.toInt() ?? 0,
      limit: (json['limit'] as num?)?.toInt() ?? 50,
      offset: (json['offset'] as num?)?.toInt() ?? 0,
      hasMore: json['has_more'] as bool? ?? false,
    );
  }
}
