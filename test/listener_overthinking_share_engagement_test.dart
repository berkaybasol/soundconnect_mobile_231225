import 'dart:async';

import 'package:flutter/material.dart' hide Page;
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session.dart';
import 'package:soundconnect_23_12_25codx/core/di/service_locator.dart';
import 'package:soundconnect_23_12_25codx/core/error/app_error.dart';
import 'package:soundconnect_23_12_25codx/core/error/result.dart';
import 'package:soundconnect_23_12_25codx/modules/engagement/domain/engagement_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/engagement/domain/entities/comment_item.dart';
import 'package:soundconnect_23_12_25codx/modules/engagement/domain/entities/comment_page.dart';
import 'package:soundconnect_23_12_25codx/modules/engagement/domain/entities/comment_user_summary.dart';
import 'package:soundconnect_23_12_25codx/modules/engagement/presentation/widgets/comment_thread_view.dart';
import 'package:soundconnect_23_12_25codx/modules/event_audience/domain/event_audience_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/overthinking/data/models/overthinking_post_model.dart';
import 'package:soundconnect_23_12_25codx/modules/overthinking/domain/entities/overthinking_post.dart';
import 'package:soundconnect_23_12_25codx/modules/overthinking/domain/overthinking_profile_share_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/overthinking/domain/overthinking_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/cubit/listener_profile_feed_controller.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/listener_event_posts.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/listener_overthinking_share_tile.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/listener_profile_theme.dart';

import 'support/event_audience_fakes.dart';

const _sourceId = 'source-post';
const _shareId = 'publication';
const _likeKey = Key('listener-overthinking-like-publication');
const _commentsKey = Key('listener-overthinking-comments-publication');

void main() {
  late _Server server;
  late _Engagement engagement;
  late _Sources sources;
  late _Shares shares;
  late AudienceTestSessions sessions;
  late ValueNotifier<OverthinkingProfileShare> row;
  late bool current;
  late int refreshes;
  late List<String> opened;

  setUp(() {
    server = _Server();
    engagement = _Engagement(server);
    sources = _Sources(server);
    shares = _Shares();
    sessions = AudienceTestSessions(audienceSession(user: 'viewer'));
    row = ValueNotifier(_share(server.post));
    current = true;
    refreshes = 0;
    opened = [];
  });

  tearDown(() async {
    shares.signal.dispose();
    row.dispose();
    sessions.dispose();
    await serviceLocator.reset();
  });

  Future<void> mount(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: ListenerProfileTheme(
          child: Scaffold(
            body: SingleChildScrollView(
              child: ValueListenableBuilder<OverthinkingProfileShare>(
                valueListenable: row,
                builder: (_, share, _) => ListenerOverthinkingShareTile(
                  share: share,
                  username: 'sharer',
                  ownerUserId: 'sharer',
                  repository: shares,
                  engagementRepository: engagement,
                  sourceRepository: sources,
                  sessions: sessions,
                  isCurrent: () => current,
                  onRefresh: () async => refreshes++,
                  onRemoved: (_) {},
                  onOpenSource: (postId) async => opened.add(postId),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  void expectCount(Key key, int count) {
    expect(
      find.descendant(of: find.byKey(key), matching: find.text('$count')),
      findsOneWidget,
    );
  }

  void expectLiked(bool liked) {
    expect(
      find.descendant(
        of: find.byKey(_likeKey),
        matching: find.byIcon(
          liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
        ),
      ),
      findsOneWidget,
    );
  }

  Future<void> openComments(WidgetTester tester) async {
    await tester.tap(find.byKey(_commentsKey));
    await tester.pumpAndSettle();
    final view = tester.widget<CommentThreadView>(
      find.byType(CommentThreadView),
    );
    expect(view.targetType, 'OVERTHINKING');
    expect(view.targetId, _sourceId);
    expect(opened, isEmpty);
  }

  Future<void> closeComments(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Yorumları kapat'));
    await tester.pumpAndSettle();
  }

  for (final pendingWhileOffscreen in [false, true]) {
    testWidgets(
      'confirmed source survives lazy recycling with pending=$pendingWhileOffscreen',
      (tester) async {
        final events = _Events();
        final scroll = ScrollController();
        final pending = Completer<Result<void>>();
        addTearDown(events.signal.dispose);
        addTearDown(scroll.dispose);
        serviceLocator.registerSingleton<EngagementRepository>(engagement);
        serviceLocator.registerSingleton<OverthinkingRepository>(sources);
        shares.items = [
          row.value,
          for (var index = 1; index < 6; index++)
            OverthinkingProfileShare(
              shareId: 'older-$index',
              note: null,
              publishedAt: row.value.publishedAt.subtract(
                Duration(minutes: index),
              ),
              post: server.post.copyWith(id: 'older-source-$index'),
            ),
        ];
        if (pendingWhileOffscreen) engagement.onLike = () => pending.future;
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            home: ListenerProfileTheme(
              child: Scaffold(
                body: CustomScrollView(
                  controller: scroll,
                  cacheExtent: 0,
                  slivers: [
                    ListenerProfilePostsSection(
                      listenerProfileId: 'profile',
                      username: 'sharer',
                      eventsRepository: events,
                      overthinkingRepository: shares,
                      sessions: sessions,
                      asSliver: true,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final original = tester.state(
          find.byType(ListenerOverthinkingShareTile).first,
        );
        await tester.tap(find.byKey(_likeKey));
        if (pendingWhileOffscreen) {
          await tester.pump();
        } else {
          await tester.pumpAndSettle();
          expectLiked(true);
          expectCount(_likeKey, 4);
        }
        scroll.jumpTo(scroll.position.maxScrollExtent);
        await tester.pumpAndSettle();
        if (pendingWhileOffscreen) {
          expect(original.mounted, isTrue);
          server.post = server.post.copyWith(likeCount: 4, likedByMe: true);
          pending.complete(const Result.success(null));
          await tester.pumpAndSettle();
        }
        // Once its request finishes, the offscreen tile must be recyclable.
        scroll.jumpTo(scroll.position.maxScrollExtent);
        await tester.pumpAndSettle();
        expect(original.mounted, isFalse);
        expect(find.byKey(_likeKey), findsNothing);
        scroll.jumpTo(0);
        await tester.pumpAndSettle();
        expectLiked(true);
        expectCount(_likeKey, 4);
        expectCount(_commentsKey, 4);
        expect(engagement.calls, [('like', 'OVERTHINKING', _sourceId)]);
        expect(sources.reads, [_sourceId]);

        // A fresh page is authoritative over the locally confirmed cache.
        shares.items[0] = _share(
          server.post.copyWith(likeCount: 12, likedByMe: false),
        );
        shares.signal.value++;
        await tester.pumpAndSettle();
        expectLiked(false);
        expectCount(_likeKey, 12);
        expect(tester.takeException(), isNull);
      },
    );
  }

  test(
    'feed source updates retain publication identity fields and reject stale scopes',
    () async {
      final events = _Events();
      final feed = ListenerProfileFeedController(
        eventsRepository: events,
        overthinkingRepository: shares,
        sessions: sessions,
        listenerProfileId: 'profile',
      );
      addTearDown(feed.dispose);
      addTearDown(events.signal.dispose);
      final original = OverthinkingProfileShare(
        shareId: _shareId,
        note: 'Paylaşan kişinin notu',
        publishedAt: row.value.publishedAt,
        post: server.post,
      );
      shares.items = [original];
      await feed.reload();
      final expectedSession = sessions.session;
      final updated = server.post.copyWith(likeCount: 4, likedByMe: true);
      feed.updateOverthinkingSource(
        expectedSession: expectedSession,
        expectedShare: original,
        post: updated,
      );
      final stored = feed.entries.single.share!;
      expect(stored.shareId, original.shareId);
      expect(stored.note, original.note);
      expect(stored.publishedAt, original.publishedAt);
      expect(identical(stored.post, updated), isTrue);
      // A retained callback cannot overwrite its own replacement or another source.
      feed.updateOverthinkingSource(
        expectedSession: expectedSession,
        expectedShare: original,
        post: server.post,
      );
      feed.updateOverthinkingSource(
        expectedSession: expectedSession,
        expectedShare: stored,
        post: updated.copyWith(id: 'other-source'),
      );
      expect(identical(feed.entries.single.share, stored), isTrue);

      final reading = Completer<Result<Page<OverthinkingProfileShare>>>();
      shares.onList = () => reading.future;
      final refresh = feed.revalidate();
      feed.updateOverthinkingSource(
        expectedSession: expectedSession,
        expectedShare: stored,
        post: server.post,
      );
      expect(identical(feed.entries.single.share, stored), isTrue);
      reading.complete(Result.success(Page(items: [original], hasNext: false)));
      await refresh;
      expect(identical(feed.entries.single.share, original), isTrue);
      feed.updateOverthinkingSource(
        expectedSession: expectedSession,
        expectedShare: stored,
        post: updated,
      );
      expect(identical(feed.entries.single.share, original), isTrue);
      feed.updateOverthinkingSource(
        expectedSession: audienceSession(user: 'other'),
        expectedShare: original,
        post: updated,
      );
      expect(identical(feed.entries.single.share, original), isTrue);
      feed.forgetShare(_shareId);
      feed.updateOverthinkingSource(
        expectedSession: expectedSession,
        expectedShare: original,
        post: updated,
      );
      expect(feed.entries, isEmpty);
    },
  );

  testWidgets(
    'standalone profile fallback persists confirmed source interactions',
    (tester) async {
      serviceLocator.registerSingleton<EngagementRepository>(engagement);
      serviceLocator.registerSingleton<OverthinkingRepository>(sources);
      shares.items = [row.value];
      await tester.pumpWidget(
        MaterialApp(
          home: ListenerProfileTheme(
            child: Scaffold(
              body: SingleChildScrollView(
                child: ListenerProfilePostsSection(
                  listenerProfileId: 'profile',
                  username: 'sharer',
                  overthinkingRepository: shares,
                  sessions: sessions,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(_likeKey));
      await tester.pumpAndSettle();
      expectLiked(true);
      expectCount(_likeKey, 4);
      await openComments(tester);
      await tester.enterText(
        find.byType(TextField),
        'Yedek profil akışından yorum',
      );
      await tester.pump();
      await tester.tap(find.byTooltip('Yorumu gönder'));
      await tester.pumpAndSettle();
      await closeComments(tester);
      expectCount(_commentsKey, 5);
      expectLiked(true);
      final tile = tester.widget<ListenerOverthinkingShareTile>(
        find.byType(ListenerOverthinkingShareTile),
      );
      expect(tile.share.post.likedByMe, isTrue);
      expect(tile.share.post.commentCount, 5);
      expect(engagement.created.single.$2, _sourceId);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'published counts are real controls seeded without per-row reads',
    (tester) async {
      await mount(tester);
      expect(find.byKey(_likeKey), findsOneWidget);
      expect(find.byKey(_commentsKey), findsOneWidget);
      expect(find.byTooltip('Beğen'), findsOneWidget);
      expect(find.byTooltip('Yorumlar'), findsOneWidget);
      expectCount(_likeKey, 3);
      expectCount(_commentsKey, 4);
      expectLiked(false);
      expect(engagement.calls, isEmpty);
      expect(sources.reads, isEmpty);
      expect(refreshes, 0);
    },
  );

  for (final role in ['ROLE_LISTENER', 'ROLE_MUSICIAN', 'ROLE_VENUE']) {
    testWidgets('profile heart toggles the source for $role viewers', (
      tester,
    ) async {
      sessions.replace(audienceSession(user: 'viewer', role: role));
      await mount(tester);
      await tester.tap(find.byKey(_likeKey));
      await tester.pumpAndSettle();
      expect(engagement.calls, [('like', 'OVERTHINKING', _sourceId)]);
      expect(sources.reads, [_sourceId]);
      expectLiked(true);
      expectCount(_likeKey, 4);
      // Source totals include one root and three replies. A root-page total
      // would incorrectly replace the source total with one after a refresh.
      expectCount(_commentsKey, 4);
      expect(find.byTooltip('Beğeniyi kaldır'), findsOneWidget);

      await tester.tap(find.byKey(_likeKey));
      await tester.pumpAndSettle();
      expect(engagement.calls, [
        ('like', 'OVERTHINKING', _sourceId),
        ('unlike', 'OVERTHINKING', _sourceId),
      ]);
      expect(sources.reads, [_sourceId, _sourceId]);
      expectLiked(false);
      expectCount(_likeKey, 3);
      expectCount(_commentsKey, 4);
      expect(opened, isEmpty);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('duplicate heart taps issue one mutation while pending', (
    tester,
  ) async {
    final pending = Completer<Result<void>>();
    engagement.onLike = () => pending.future;
    await mount(tester);
    await tester.tap(find.byKey(_likeKey));
    await tester.pump();
    await tester.tap(find.byKey(_likeKey));
    await tester.pump();
    expect(engagement.calls, [('like', 'OVERTHINKING', _sourceId)]);
    server.post = server.post.copyWith(likeCount: 4, likedByMe: true);
    pending.complete(const Result.success(null));
    await tester.pumpAndSettle();
    expectLiked(true);
    expectCount(_likeKey, 4);
    expect(sources.reads, [_sourceId]);
  });

  testWidgets('uncertain heart write shows error and reconciles before retry', (
    tester,
  ) async {
    engagement.onLike = () async {
      // The server committed the write, but its acknowledgement was lost.
      server.post = server.post.copyWith(likeCount: 4, likedByMe: true);
      return const Result.failure(
        AppError(code: 'network', message: 'Bağlantı kesildi.'),
      );
    };
    await mount(tester);
    await tester.tap(find.byKey(_likeKey));
    await tester.pumpAndSettle();
    expectLiked(false);
    expect(
      find.descendant(of: find.byKey(_likeKey), matching: find.text('—')),
      findsOneWidget,
    );
    expect(find.byType(SnackBar), findsOneWidget);
    expect(sources.reads, isEmpty);

    await tester.tap(find.byKey(_likeKey));
    await tester.pumpAndSettle();
    expect(engagement.calls, [('like', 'OVERTHINKING', _sourceId)]);
    expect(sources.reads, [_sourceId]);
    expectLiked(true);
    expectCount(_likeKey, 4);

    await tester.tap(find.byKey(_likeKey));
    await tester.pumpAndSettle();
    expect(engagement.calls.last, ('unlike', 'OVERTHINKING', _sourceId));
    expectLiked(false);
    expectCount(_likeKey, 3);
  });

  testWidgets(
    'comment create and delete use source thread and refresh totals',
    (tester) async {
      await mount(tester);
      await openComments(tester);
      expect(find.text('Asıl yazının yorumu'), findsOneWidget);
      expect(engagement.calls.single, ('comments', 'OVERTHINKING', _sourceId));
      await tester.enterText(find.byType(TextField), 'Profilden yazılan yorum');
      await tester.pump();
      await tester.tap(find.byTooltip('Yorumu gönder'));
      await tester.pumpAndSettle();
      expect(engagement.created, [
        ('OVERTHINKING', _sourceId, 'Profilden yazılan yorum', null),
      ]);
      expect(find.text('Profilden yazılan yorum'), findsOneWidget);
      await closeComments(tester);
      expectCount(_commentsKey, 5);
      expect(sources.reads, [_sourceId]);

      await openComments(tester);
      await tester.tap(find.byKey(const Key('comment-delete-created-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sil'));
      await tester.pumpAndSettle();
      expect(engagement.deleted, ['created-1']);
      expect(find.text('Profilden yazılan yorum'), findsNothing);
      await closeComments(tester);
      expectCount(_commentsKey, 4);
      expect(sources.reads, [_sourceId, _sourceId]);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('parent privacy fence blocks both retained card actions', (
    tester,
  ) async {
    await mount(tester);
    current = false;
    await tester.tap(find.byKey(_likeKey));
    await tester.tap(find.byKey(_commentsKey));
    await tester.pumpAndSettle();
    expect(engagement.calls, isEmpty);
    expect(sources.reads, isEmpty);
    expect(find.byType(CommentThreadView), findsNothing);
  });

  testWidgets('source deletion during like revokes the stale shared card', (
    tester,
  ) async {
    engagement.onLike = () async => const Result.failure(
      AppError(code: '9401', message: 'Yazı bulunamadı.'),
    );
    await mount(tester);
    await tester.tap(find.byKey(_likeKey));
    await tester.pumpAndSettle();
    expect(find.byKey(_likeKey), findsNothing);
    expect(find.byKey(_commentsKey), findsNothing);
    expect(find.text('Yazı'), findsNothing);
    expect(refreshes, 1);
    expect(sources.reads, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('late source read cannot overwrite a replacement projection', (
    tester,
  ) async {
    final pending = Completer<Result<OverthinkingPost>>();
    sources.onRead = () => pending.future;
    await mount(tester);
    await tester.tap(find.byKey(_likeKey));
    await tester.pump();
    expect(sources.reads, [_sourceId]);
    final replacement = server.post.copyWith(
      title: 'Yeni görünüm',
      likeCount: 9,
      likedByMe: false,
    );
    row.value = _share(replacement);
    await tester.pump();
    pending.complete(Result.success(server.post));
    await tester.pumpAndSettle();
    expectCount(_likeKey, 9);
    expectLiked(false);
    expect(refreshes, 0);
    expect(tester.takeException(), isNull);
  });

  for (final change in ['row', 'session']) {
    testWidgets('late heart completion cannot mutate a changed $change', (
      tester,
    ) async {
      final pending = Completer<Result<void>>();
      engagement.onLike = () => pending.future;
      await mount(tester);
      await tester.tap(find.byKey(_likeKey));
      await tester.pump();
      if (change == 'row') {
        row.value = _share(server.post.copyWith(title: 'Yeni görünüm'));
      } else {
        sessions.replace(audienceSession(user: 'another-viewer'));
      }
      await tester.pump();
      pending.complete(const Result.success(null));
      await tester.pumpAndSettle();
      expect(sources.reads, isEmpty);
      expect(refreshes, 0);
      if (change == 'row') {
        expectLiked(false);
        expectCount(_likeKey, 3);
      } else {
        expect(find.byKey(_likeKey), findsNothing);
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('row replacement revokes open comments and discards old draft', (
    tester,
  ) async {
    await mount(tester);
    await openComments(tester);
    await tester.enterText(find.byType(TextField), 'Eski görünümün taslağı');
    row.value = _share(server.post.copyWith(title: 'Yeni görünüm'));
    await tester.pumpAndSettle();
    expect(find.byType(CommentThreadView), findsNothing);
    expect(find.text('Eski görünümün taslağı'), findsNothing);
    expect(engagement.created, isEmpty);
    expect(sources.reads, isEmpty);
    expect(tester.takeException(), isNull);
  });
}

OverthinkingProfileShare _share(OverthinkingPost post) =>
    OverthinkingProfileShare(
      shareId: _shareId,
      note: null,
      publishedAt: DateTime.utc(2026, 9, 10, 18),
      post: post,
    );

class _Server {
  OverthinkingPost post = OverthinkingPostModel.fromJson({
    'id': _sourceId,
    'title': 'Yazı',
    'content': 'Bir yazının profil paylaşımı.',
    'anonymous': true,
    'visibilityType': 'ANONYMOUS',
    'canViewAuthor': false,
    'likeCount': 3,
    'commentCount': 4,
    'likedByMe': false,
  });
  final comments = <CommentItem>[
    const CommentItem(
      id: 'existing-root',
      user: CommentUserSummary(
        id: 'other-viewer',
        username: 'another',
        avatarUrl: null,
      ),
      text: 'Asıl yazının yorumu',
      deleted: false,
      parentCommentId: null,
      replyCount: 3,
      createdAt: null,
    ),
  ];
}

class _Sources extends Fake implements OverthinkingRepository {
  _Sources(this.server);
  final _Server server;
  final reads = <String>[];
  Future<Result<OverthinkingPost>> Function()? onRead;

  @override
  Future<Result<OverthinkingPost>> getDetail({required String postId}) async {
    reads.add(postId);
    return onRead?.call() ?? Result.success(server.post);
  }
}

class _Shares extends Fake implements OverthinkingProfileShareRepository {
  final signal = ValueNotifier(0);
  List<OverthinkingProfileShare> items = [];
  Future<Result<Page<OverthinkingProfileShare>>> Function()? onList;
  @override
  ValueNotifier<int> get changes => signal;

  @override
  Future<Result<Page<OverthinkingProfileShare>>> listProfile({
    required String profileId,
    required AuthSession expectedSession,
    int page = 0,
    int size = 20,
  }) async =>
      onList?.call() ??
      Result.success(
        Page(
          items: items.skip(page * size).take(size).toList(),
          hasNext: (page + 1) * size < items.length,
        ),
      );
}

class _Events extends Fake implements EventAudienceRepository {
  final signal = ValueNotifier(0);
  @override
  ValueNotifier<int> get changes => signal;

  @override
  Future<Result<EventAudiencePage<EventAudiencePost>>> listPublic(
    String listenerProfileId, {
    String? expectedSessionKey,
    EventAudiencePeriod period = EventAudiencePeriod.all,
    int page = 0,
    int size = 20,
  }) async => Result.success(
    EventAudiencePage(
      items: const [],
      page: page,
      size: size,
      totalElements: 0,
      totalPages: 0,
      hasNext: false,
    ),
  );
}

class _Engagement extends Fake implements EngagementRepository {
  _Engagement(this.server);
  final _Server server;
  final calls = <(String, String, String)>[];
  final created = <(String, String, String, String?)>[];
  final deleted = <String>[];
  Future<Result<void>> Function()? onLike;

  @override
  Future<Result<void>> like({
    required String targetType,
    required String targetId,
  }) async {
    calls.add(('like', targetType, targetId));
    if (onLike != null) return onLike!();
    server.post = server.post.copyWith(
      likeCount: server.post.likeCount + 1,
      likedByMe: true,
    );
    return const Result.success(null);
  }

  @override
  Future<Result<void>> unlike({
    required String targetType,
    required String targetId,
  }) async {
    calls.add(('unlike', targetType, targetId));
    server.post = server.post.copyWith(
      likeCount: server.post.likeCount - 1,
      likedByMe: false,
    );
    return const Result.success(null);
  }

  @override
  Future<Result<CommentPage>> listComments({
    required String targetType,
    required String targetId,
    int page = 0,
    int size = 20,
  }) async {
    calls.add(('comments', targetType, targetId));
    return Result.success(
      CommentPage(
        items: List.unmodifiable(server.comments),
        totalElements: server.comments.length,
        page: page,
        size: size,
      ),
    );
  }

  @override
  Future<Result<CommentItem>> createComment({
    required String targetType,
    required String targetId,
    required String text,
    String? parentCommentId,
  }) async {
    created.add((targetType, targetId, text, parentCommentId));
    final comment = CommentItem(
      id: 'created-${created.length}',
      user: const CommentUserSummary(
        id: 'viewer',
        username: 'viewer',
        avatarUrl: null,
      ),
      text: text,
      deleted: false,
      parentCommentId: parentCommentId,
      replyCount: 0,
      createdAt: null,
    );
    server.comments.insert(0, comment);
    server.post = server.post.copyWith(
      commentCount: server.post.commentCount + 1,
    );
    return Result.success(comment);
  }

  @override
  Future<Result<void>> deleteComment({required String commentId}) async {
    deleted.add(commentId);
    server.comments.removeWhere((item) => item.id == commentId);
    server.post = server.post.copyWith(
      commentCount: server.post.commentCount - 1,
    );
    return const Result.success(null);
  }
}
