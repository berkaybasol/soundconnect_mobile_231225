import 'dart:async';

import 'package:flutter/material.dart' hide Page;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/di/service_locator.dart';
import 'package:soundconnect_23_12_25codx/core/error/app_error.dart';
import 'package:soundconnect_23_12_25codx/core/error/result.dart';
import 'package:soundconnect_23_12_25codx/core/pagination/page.dart';
import 'package:soundconnect_23_12_25codx/modules/engagement/domain/engagement_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/engagement/presentation/cubit/comment_thread_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/engagement/presentation/widgets/comment_thread_view.dart';
import 'package:soundconnect_23_12_25codx/modules/overthinking/domain/entities/overthinking_post.dart';
import 'package:soundconnect_23_12_25codx/modules/overthinking/domain/overthinking_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/overthinking/domain/overthinking_feed_sort.dart';
import 'package:soundconnect_23_12_25codx/modules/overthinking/presentation/cubit/overthinking_feed_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/overthinking/presentation/screens/overthinking_feed_screen.dart';

void main() {
  late _Posts posts;
  late _Engagement engagement;
  late OverthinkingFeedCubit cubit;
  late CommentThreadCubit comments;

  setUp(() async {
    await serviceLocator.reset();
    posts = _Posts();
    engagement = _Engagement();
    serviceLocator.registerSingleton<EngagementRepository>(engagement);
    cubit = OverthinkingFeedCubit(
      overthinkingRepository: posts,
      engagementRepository: engagement,
    );
    comments = CommentThreadCubit(engagement);
    await cubit.load();
  });

  tearDown(() async {
    await cubit.close();
    await comments.close();
    await serviceLocator.reset();
  });

  for (final code in ['9401', '404']) {
    testWidgets(
      'confirmed missing detail ($code) removes cached content and interactions',
      (tester) async {
        await _mount(tester, cubit, comments);
        expect(find.text(_post.title), findsOneWidget);
        expect(find.byTooltip('Beğen'), findsOneWidget);

        posts.detailError = AppError(code: code, message: 'Yazı bulunamadı.');
        await cubit.refreshPost(_post.id);
        await tester.pumpAndSettle();

        expect(cubit.isPostUnavailable(_post.id), isTrue);
        expect(cubit.state.posts, isEmpty);
        expect(find.text('Bu yazı artık erişilebilir değil.'), findsOneWidget);
        expect(find.text(_post.title), findsNothing);
        expect(find.text(_post.content), findsNothing);
        expect(find.byTooltip('Beğen'), findsNothing);
        expect(find.text('Kimlik isteği gönder'), findsNothing);
        expect(find.byType(CommentThreadView), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final code in ['500', 'NETWORK']) {
    testWidgets('transient detail error ($code) preserves readable content', (
      tester,
    ) async {
      await _mount(tester, cubit, comments);
      // Classify the transport/domain code; text alone must not tombstone.
      posts.detailError = AppError(code: code, message: 'Yazı bulunamadı.');
      await cubit.refreshPost(_post.id);
      await tester.pumpAndSettle();

      expect(cubit.isPostUnavailable(_post.id), isFalse);
      expect(cubit.state.posts.single.id, _post.id);
      expect(find.text(_post.title), findsOneWidget);
      expect(find.text(_post.content), findsOneWidget);
      expect(find.byTooltip('Beğen'), findsOneWidget);
      expect(find.text('Bu yazı artık erişilebilir değil.'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  test('an older feed cannot resurrect a confirmed missing detail', () async {
    final pending = Completer<Result<Page<OverthinkingPost>>>();
    posts.pendingFeed = pending;
    final loading = cubit.load();
    posts.detailError = const AppError(
      code: '9401',
      message: 'Yazı bulunamadı.',
    );
    await cubit.refreshPost(_post.id);
    pending.complete(
      const Result.success(Page(items: [_post], hasNext: false)),
    );
    await loading;

    expect(cubit.isPostUnavailable(_post.id), isTrue);
    expect(cubit.state.posts, isEmpty);
    await cubit.toggleLike(_post);
    expect(engagement.calls, 0);
    expect(await cubit.requestReveal(_post), isFalse);
    expect(posts.revealCalls, 0);
  });
}

Future<void> _mount(
  WidgetTester tester,
  OverthinkingFeedCubit cubit,
  CommentThreadCubit comments,
) async {
  tester.view.physicalSize = const Size(390, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData.dark(useMaterial3: true),
      home: MultiBlocProvider(
        providers: [
          BlocProvider.value(value: cubit),
          BlocProvider.value(value: comments),
        ],
        child: const OverthinkingDetailScreen(
          post: _post,
          revealRequesting: false,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _Posts implements OverthinkingRepository {
  AppError? detailError;
  Completer<Result<Page<OverthinkingPost>>>? pendingFeed;
  int revealCalls = 0;

  @override
  Future<Result<Page<OverthinkingPost>>> getFeed({
    int page = 0,
    int size = 20,
    OverthinkingFeedSort sort = OverthinkingFeedSort.newest,
  }) async =>
      pendingFeed?.future ??
      const Result.success(Page(items: [_post], hasNext: false));

  @override
  Future<Result<OverthinkingPost>> getDetail({required String postId}) async =>
      detailError == null
      ? const Result.success(_post)
      : Result.failure(detailError!);

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #requestReveal) revealCalls++;
    throw UnsupportedError(invocation.memberName.toString());
  }
}

class _Engagement implements EngagementRepository {
  int calls = 0;
  @override
  dynamic noSuchMethod(Invocation invocation) {
    calls++;
    throw UnsupportedError(invocation.memberName.toString());
  }
}

const _post = OverthinkingPost(
  id: 'post',
  authorId: null,
  authorUsername: 'Anonim',
  authorAvatarUrl: null,
  anonymous: true,
  canViewAuthor: false,
  visibilityType: 'ANONYMOUS',
  title: 'Yalnızca erişilebilirken göster',
  content: 'Silinmiş bir yazının önbellekteki metni.',
  spotifyTrackUrl: null,
  spotifyArtistId: null,
  spotifyTrackName: null,
  spotifyArtistName: null,
  spotifyAlbumImageUrl: null,
  musicianTrackId: null,
  bandTrackId: null,
  artistId: null,
  artistType: null,
  likeCount: 0,
  commentCount: 0,
  likedByMe: false,
);
