import 'package:arcane_forge/models/resource_comment_models.dart';
import 'package:arcane_forge/services/resource_comment_service.dart';
import 'package:arcane_forge/widgets/resource_comments_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeCommentService implements ResourceCommentService {
  final List<ResourceComment> comments;
  int nextId = 10;

  _FakeCommentService(this.comments);

  @override
  Future<ResourceCommentPage> listComments({
    required String projectId,
    required ResourceCommentTarget target,
    int limit = 50,
    int offset = 0,
  }) async {
    final page = comments.skip(offset).take(limit).toList();
    return ResourceCommentPage(
      comments: page,
      total: comments.length,
      limit: limit,
      offset: offset,
      hasMore: offset + page.length < comments.length,
    );
  }

  @override
  Future<ResourceComment> addComment({
    required String projectId,
    required ResourceCommentTarget target,
    required String body,
  }) async {
    final now = DateTime.utc(2026, 8, 30, 10);
    final comment = ResourceComment(
      id: nextId++,
      projectId: int.parse(projectId),
      resourceType: target.type,
      resourceId: target.resourceId,
      createdByUserId: 'current-user',
      authorUsername: 'Binggan',
      body: body,
      createdAt: now,
      updatedAt: now,
      deletedAt: null,
      deletedByUserId: null,
      isDeleted: false,
    );
    comments.add(comment);
    return comment;
  }

  @override
  Future<ResourceComment> editComment({
    required String projectId,
    required int commentId,
    required String body,
  }) async {
    final index = comments.indexWhere((comment) => comment.id == commentId);
    final existing = comments[index];
    final updated = ResourceComment(
      id: existing.id,
      projectId: existing.projectId,
      resourceType: existing.resourceType,
      resourceId: existing.resourceId,
      createdByUserId: existing.createdByUserId,
      authorUsername: existing.authorUsername,
      body: body,
      createdAt: existing.createdAt,
      updatedAt: existing.updatedAt.add(const Duration(minutes: 2)),
      deletedAt: null,
      deletedByUserId: null,
      isDeleted: false,
    );
    comments[index] = updated;
    return updated;
  }

  @override
  Future<ResourceComment> deleteComment({
    required String projectId,
    required int commentId,
  }) async {
    final index = comments.indexWhere((comment) => comment.id == commentId);
    final existing = comments[index];
    final deleted = ResourceComment(
      id: existing.id,
      projectId: existing.projectId,
      resourceType: existing.resourceType,
      resourceId: existing.resourceId,
      createdByUserId: existing.createdByUserId,
      authorUsername: existing.authorUsername,
      body: null,
      createdAt: existing.createdAt,
      updatedAt: existing.updatedAt.add(const Duration(minutes: 3)),
      deletedAt: existing.updatedAt.add(const Duration(minutes: 3)),
      deletedByUserId: 'current-user',
      isDeleted: true,
    );
    comments[index] = deleted;
    return deleted;
  }
}

void main() {
  testWidgets(
      'renders active and deleted comments and adds Markdown discussion',
      (tester) async {
    final now = DateTime.utc(2026, 8, 29, 9);
    final service = _FakeCommentService([
      ResourceComment(
        id: 1,
        projectId: 50,
        resourceType: ResourceCommentType.imageGeneration,
        resourceId: 'generation-1',
        createdByUserId: 'member-1',
        authorUsername: 'Artist',
        body: '**Historical** source confirmed.',
        createdAt: now,
        updatedAt: now,
        deletedAt: null,
        deletedByUserId: null,
        isDeleted: false,
      ),
      ResourceComment(
        id: 2,
        projectId: 50,
        resourceType: ResourceCommentType.imageGeneration,
        resourceId: 'generation-1',
        createdByUserId: 'member-2',
        authorUsername: 'Reviewer',
        body: null,
        createdAt: now,
        updatedAt: now.add(const Duration(minutes: 1)),
        deletedAt: now.add(const Duration(minutes: 1)),
        deletedByUserId: 'member-2',
        isDeleted: true,
      ),
    ]);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: ResourceCommentsPanel(
              projectId: '50',
              target: const ResourceCommentTarget.resource(
                ResourceCommentType.imageGeneration,
                'generation-1',
              ),
              service: service,
              currentUserId: 'current-user',
              canModerate: false,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Team discussion — not approved design truth'),
        findsOneWidget);
    expect(
      find.textContaining('Historical', findRichText: true),
      findsOneWidget,
    );
    expect(find.text('Comment deleted'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('resource-comment-input')),
      'Keep the **original prompt** with the import.',
    );
    await tester.tap(find.byKey(const Key('submit-resource-comment')));
    await tester.pumpAndSettle();

    expect(service.comments, hasLength(3));
    expect(
      find.textContaining('original prompt', findRichText: true),
      findsOneWidget,
    );
  });

  testWidgets('authors can edit and soft-delete their own comments',
      (tester) async {
    final now = DateTime.utc(2026, 8, 30, 10);
    final service = _FakeCommentService([
      ResourceComment(
        id: 3,
        projectId: 50,
        resourceType: ResourceCommentType.project,
        resourceId: null,
        createdByUserId: 'current-user',
        authorUsername: 'Binggan',
        body: 'Initial review',
        createdAt: now,
        updatedAt: now,
        deletedAt: null,
        deletedByUserId: null,
        isDeleted: false,
      ),
    ]);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: ResourceCommentsPanel(
              projectId: '50',
              target: const ResourceCommentTarget.project(),
              service: service,
              currentUserId: 'current-user',
              canModerate: false,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Comment actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('edit-comment-input')),
      'Updated review',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Updated review'), findsOneWidget);

    await tester.tap(find.byTooltip('Comment actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(find.text('Comment deleted'), findsOneWidget);
    expect(service.comments.single.body, isNull);
  });
}
