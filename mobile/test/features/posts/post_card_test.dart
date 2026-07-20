import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kirenz_mobile/app/theme.dart';
import 'package:kirenz_mobile/features/posts/domain/entities/post.dart';
import 'package:kirenz_mobile/features/posts/presentation/widgets/post_card.dart';

void main() {
  testWidgets('reaction uses an optimistic popup without a loading bar', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 700);
    addTearDown(tester.view.reset);
    final result = Completer<bool>();

    await tester.pumpWidget(
      MaterialApp(
        theme: KirenzTheme.light,
        home: Scaffold(
          body: PostCard(
            post: _post,
            currentUserId: 'viewer',
            pending: false,
            onEdit: (_, _, _) async => true,
            onDelete: () async {},
            onShare: (_) async => true,
            onUploadImage: (_, _) => throw UnimplementedError(),
            onReact: (_) => result.future,
          ),
        ),
      ),
    );

    await tester.tap(find.text('React'));
    await tester.pump();

    expect(find.text('Like'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(tester.takeException(), isNull);

    result.complete(true);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}

const _post = Post(
  id: 'post-1',
  slug: 'post-1',
  author: PostAuthor(
    id: 'author',
    username: 'mai',
    displayName: 'Mai Nguyen',
    avatarUrl: null,
  ),
  content: 'A responsive post card',
  privacy: PostPrivacy.public,
  originalPostId: null,
  sharedPost: null,
  media: [],
  taggedUserIds: [],
  taggedUsers: [],
  reactionsCount: 0,
  reactionSummary: PostReactionSummary(
    totalCount: 0,
    currentUserReaction: null,
    breakdown: {},
  ),
  commentsCount: 0,
  status: PostStatus.active,
  createdAt: null,
  updatedAt: null,
);
