import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart' hide Page;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session_manager.dart';
import 'package:soundconnect_23_12_25codx/core/auth/token_store.dart';
import 'package:soundconnect_23_12_25codx/core/di/service_locator.dart';
import 'package:soundconnect_23_12_25codx/core/error/result.dart';
import 'package:soundconnect_23_12_25codx/core/network/dio_api_client.dart';
import 'package:soundconnect_23_12_25codx/core/pagination/page.dart';
import 'package:soundconnect_23_12_25codx/modules/dm/domain/dm_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/dm/presentation/cubit/dm_badge_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/engagement/domain/engagement_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/engagement/domain/entities/comment_page.dart';
import 'package:soundconnect_23_12_25codx/modules/engagement/presentation/cubit/comment_thread_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/overthinking/data/models/overthinking_post_model.dart';
import 'package:soundconnect_23_12_25codx/modules/overthinking/data/overthinking_repository_impl.dart';
import 'package:soundconnect_23_12_25codx/modules/overthinking/domain/entities/overthinking_post.dart';
import 'package:soundconnect_23_12_25codx/modules/overthinking/domain/entities/overthinking_reveal_request.dart';
import 'package:soundconnect_23_12_25codx/modules/overthinking/domain/overthinking_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/overthinking/domain/overthinking_feed_sort.dart';
import 'package:soundconnect_23_12_25codx/modules/overthinking/domain/overthinking_session.dart';
import 'package:soundconnect_23_12_25codx/modules/overthinking/presentation/cubit/overthinking_feed_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/overthinking/presentation/screens/overthinking_feed_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/overthinking/presentation/screens/overthinking_manage_screen.dart';

import 'support/event_audience_fakes.dart';
import 'support/recording_api_client.dart';

const _json = <String, dynamic>{
  'id': 'post',
  'title': 'Private draft title',
  'content': 'Private draft body',
  'authorId': 'author',
  'authorUsername': 'Revealed identity',
  'anonymous': true,
  'canViewAuthor': true,
  'visibilityType': 'ANONYMOUS',
};
final _post = OverthinkingPostModel.fromJson(_json);

void main() {
  tearDown(() async => serviceLocator.reset());

  test(
    'guest feed detail and artist reads remain public; account operations do not dispatch',
    () async {
      final sessions = AudienceTestSessions(const AuthSession.guest());
      final api = RecordingApiClient(
        (request) => request.path.endsWith('/post')
            ? _json
            : {
                'content': [_json],
                'last': true,
              },
      );
      final repository = OverthinkingRepositoryImpl(api, sessions: sessions);
      expect((await repository.getFeed()).isSuccess, isTrue);
      expect((await repository.getDetail(postId: 'post')).isSuccess, isTrue);
      expect(
        (await repository.getPostsByArtist(artistId: 'artist')).isSuccess,
        isTrue,
      );
      expect(api.requests, hasLength(3));
      for (final request in api.requests) {
        expect(request.requestContext?.requireGuestSession, isTrue);
        expect(request.requestContext?.expectedSessionKey, isNull);
      }
      expect((await repository.getMyPosts()).isSuccess, isFalse);
      expect((await repository.getIncomingRevealRequests()).isSuccess, isFalse);
      expect(
        (await repository.requestReveal(postId: 'post')).isSuccess,
        isFalse,
      );
      expect(
        (await repository.createPost(
          title: 'a',
          content: 'b',
          visibilityType: 'ANONYMOUS',
        )).isSuccess,
        isFalse,
      );
      expect(api.requests, hasLength(3));
    },
  );

  for (final user in ['other', 'owner']) {
    test(
      'repository drops private response after session replacement into $user',
      () async {
        final pending = Completer<Object?>();
        final sessions = AudienceTestSessions(
          audienceSession(user: 'owner', token: 'old'),
        );
        final api = RecordingApiClient((_) => pending.future);
        final repository = OverthinkingRepositoryImpl(api, sessions: sessions);
        final read = repository.getDetail(postId: 'post');
        expect(api.lastRequest.requestContext?.expectedSessionKey, 'owner');
        expect(api.lastRequest.requestContext?.expectedToken, 'old');
        sessions.replace(audienceSession(user: user, token: 'new'));
        pending.complete(_json);
        expect((await read).error?.code, 'overthinking_session_changed');
      },
    );

    test(
      'real transport never sends an old write after token await into $user',
      () async {
        final oldToken = _jwt('owner', 'old');
        final newToken = _jwt(user, 'new');
        final sessions = AudienceTestSessions(
          audienceSession(user: 'owner', token: oldToken),
        );
        final tokens = _Tokens(oldToken)..block = Completer<String?>();
        final adapter = _Adapter();
        final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
          ..httpClientAdapter = adapter;
        addTearDown(() => dio.close(force: true));
        final repository = OverthinkingRepositoryImpl(
          DioApiClient(dio: dio, tokenStore: tokens, sessionManager: sessions),
          sessions: sessions,
        );
        final write = repository.createPost(
          title: 'Old draft',
          content: 'Old content',
          visibilityType: 'ANONYMOUS',
        );
        await tokens.started.future;
        sessions.replace(const AuthSession.guest());
        sessions.replace(audienceSession(user: user, token: newToken));
        tokens.block!.complete(newToken);
        expect((await write).isSuccess, isFalse);
        expect(adapter.requests, isEmpty);
      },
    );
  }

  test(
    'real transport allows unchanged account and rejects guest read adopting login',
    () async {
      final token = _jwt('owner', 'current');
      final sessions = AudienceTestSessions(
        audienceSession(user: 'owner', token: token),
      );
      final tokens = _Tokens(token);
      final adapter = _Adapter();
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
        ..httpClientAdapter = adapter;
      addTearDown(() => dio.close(force: true));
      final repository = OverthinkingRepositoryImpl(
        DioApiClient(dio: dio, tokenStore: tokens, sessionManager: sessions),
        sessions: sessions,
      );
      expect(
        (await repository.createPost(
          title: 'Title',
          content: 'Body',
          visibilityType: 'ANONYMOUS',
        )).isSuccess,
        isTrue,
      );
      expect(adapter.requests, hasLength(1));
      expect(adapter.requests.single.headers['Authorization'], 'Bearer $token');
      sessions.replace(const AuthSession.guest());
      tokens.block = Completer<String?>();
      tokens.started = Completer<void>();
      final read = repository.getFeed();
      await tokens.started.future;
      sessions.replace(audienceSession(user: 'owner', token: token));
      tokens.block!.complete(token);
      expect((await read).isSuccess, isFalse);
      expect(adapter.requests, hasLength(1));
    },
  );

  test(
    'Cubit clears revealed data and ignores simultaneous late read and write',
    () async {
      final sessions = AudienceTestSessions(audienceSession(user: 'owner'));
      final posts = _Posts();
      final cubit = OverthinkingFeedCubit(
        overthinkingRepository: posts,
        engagementRepository: _Engagement(),
        sessions: sessions,
      );
      addTearDown(cubit.close);
      await cubit.load();
      expect(cubit.state.posts.single.hasVisibleAuthor, isTrue);
      // Refreshing under the same session preserves its audience and data.
      await cubit.load();
      expect(cubit.isSessionCurrent, isTrue);
      final read = Completer<Result<Page<OverthinkingPost>>>();
      final write = Completer<Result<OverthinkingPost>>();
      posts.pendingFeed = read;
      posts.pendingCreate = write;
      final pendingRead = cubit.load();
      final pendingWrite = cubit.createPost(
        title: 'a',
        content: 'b',
        anonymous: true,
      );
      sessions.replace(audienceSession(user: 'other'));
      expect(cubit.state.posts, isEmpty);
      expect(cubit.state.submitting, isFalse);
      read.complete(Result.success(Page(items: [_post], hasNext: false)));
      write.complete(Result.success(_post));
      await pendingRead;
      expect(await pendingWrite, isFalse);
      await cubit.load();
      expect(
        await cubit.createPost(title: 'a', content: 'b', anonymous: true),
        isFalse,
      );
      expect(posts.feedReads, 3);
      expect(posts.creates, 1);
      expect(cubit.state.posts, isEmpty);
    },
  );

  test(
    'logout and relogin with the same user permanently invalidates old route; new route works',
    () async {
      final initial = audienceSession(user: 'owner');
      final sessions = AudienceTestSessions(initial);
      final oldRoute = OverthinkingSession(sessions);
      addTearDown(oldRoute.dispose);
      sessions.replace(initial);
      expect(oldRoute.canWrite, isTrue);
      sessions.replace(const AuthSession.guest());
      sessions.replace(initial);
      expect(oldRoute.isCurrent, isFalse);
      final newRoute = OverthinkingSession(sessions);
      addTearDown(newRoute.dispose);
      expect(newRoute.canWrite, isTrue);
    },
  );

  testWidgets(
    'detail constructor cannot reveal an old identity after account change',
    (tester) async {
      final setup = _setup();
      final comments = CommentThreadCubit(
        _Engagement(),
        sessions: setup.sessions,
      );
      addTearDown(comments.close);
      await tester.pumpWidget(
        MaterialApp(
          home: MultiBlocProvider(
            providers: [
              BlocProvider.value(value: setup.cubit),
              BlocProvider.value(value: comments),
            ],
            child: OverthinkingDetailScreen(
              post: _post,
              revealRequesting: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('@Revealed identity'), findsOneWidget);
      setup.sessions.replace(audienceSession(user: 'other'));
      await tester.pumpAndSettle();
      expect(find.text('@Revealed identity'), findsNothing);
      expect(find.text(_post.title), findsNothing);
      expect(find.byTooltip('Beğen'), findsNothing);
      expect(find.text(OverthinkingSession.error.message), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'create draft is removed on account change; pending success cannot pop the new route',
    (tester) async {
      final setup = _setup();
      final pending = Completer<Result<OverthinkingPost>>();
      setup.posts.pendingCreate = pending;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => BlocProvider.value(
                      value: setup.cubit,
                      child: const OverthinkingCreateScreen(),
                    ),
                  ),
                ),
                child: const Text('Open writer'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open writer'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('overthinking-title')),
        'Secret title',
      );
      await tester.enterText(
        find.byKey(const ValueKey('overthinking-content')),
        'Secret body',
      );
      await tester.scrollUntilVisible(
        find.text('Yazıyı paylaş'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Yazıyı paylaş'));
      await tester.pump();
      expect(setup.posts.creates, 1);
      setup.sessions.replace(audienceSession(user: 'other'));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsNothing);
      pending.complete(Result.success(_post));
      await tester.pumpAndSettle();
      expect(find.text(OverthinkingSession.error.message), findsOneWidget);
      expect(find.text('Open writer'), findsNothing);
      expect(setup.cubit.state.posts, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'management and its open delete dialog discard account-specific text',
    (tester) async {
      final setup = _setup();
      final badge = DmBadgeCubit(_Dm(), _Tokens(null));
      addTearDown(badge.close);
      serviceLocator.registerSingleton<DmBadgeCubit>(badge);
      await tester.pumpWidget(
        const MaterialApp(home: OverthinkingManageScreen()),
      );
      await tester.pumpAndSettle();
      expect(find.text(_post.title), findsOneWidget);
      await tester.tap(find.byTooltip('Yazıyı sil'));
      await tester.pumpAndSettle();
      expect(find.text('Bu yazıyı sil?'), findsOneWidget);
      setup.sessions.replace(audienceSession(user: 'other'));
      await tester.pumpAndSettle();
      expect(find.text('Bu yazıyı sil?'), findsNothing);
      expect(find.text(_post.title), findsNothing);
      expect(find.text(_post.content), findsNothing);
      expect(find.text(OverthinkingSession.error.message), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );
}

({AudienceTestSessions sessions, _Posts posts, OverthinkingFeedCubit cubit})
_setup() {
  final sessions = AudienceTestSessions(audienceSession(user: 'owner'));
  final posts = _Posts();
  final engagement = _Engagement();
  serviceLocator.registerSingleton<AuthSessionManager>(sessions);
  serviceLocator.registerSingleton<OverthinkingRepository>(posts);
  serviceLocator.registerSingleton<EngagementRepository>(engagement);
  final cubit = OverthinkingFeedCubit(
    overthinkingRepository: posts,
    engagementRepository: engagement,
    sessions: sessions,
  );
  addTearDown(cubit.close);
  return (sessions: sessions, posts: posts, cubit: cubit);
}

class _Posts extends Fake implements OverthinkingRepository {
  Completer<Result<Page<OverthinkingPost>>>? pendingFeed;
  Completer<Result<OverthinkingPost>>? pendingCreate;
  int feedReads = 0;
  int creates = 0;
  @override
  Future<Result<Page<OverthinkingPost>>> getFeed({
    int page = 0,
    int size = 20,
    OverthinkingFeedSort sort = OverthinkingFeedSort.newest,
  }) async {
    ++feedReads;
    return pendingFeed?.future ??
        Result.success(Page(items: [_post], hasNext: false));
  }

  @override
  Future<Result<Page<OverthinkingPost>>> getMyPosts({
    int page = 0,
    int size = 20,
  }) async => Result.success(Page(items: [_post], hasNext: false));
  @override
  Future<Result<Page<OverthinkingRevealRequest>>> getIncomingRevealRequests({
    int page = 0,
    int size = 20,
  }) async => const Result.success(Page(items: [], hasNext: false));
  @override
  Future<Result<Page<OverthinkingRevealRequest>>> getSentRevealRequests({
    int page = 0,
    int size = 20,
  }) async => const Result.success(Page(items: [], hasNext: false));
  @override
  Future<Result<OverthinkingPost>> createPost({
    String? clientRequestId,
    required String title,
    required String content,
    required String visibilityType,
    String? spotifyTrackUrl,
    String? spotifyArtistId,
    String? spotifyTrackName,
    String? spotifyArtistName,
    String? spotifyAlbumImageUrl,
  }) async {
    ++creates;
    return pendingCreate?.future ?? Result.success(_post);
  }
}

class _Engagement extends Fake implements EngagementRepository {
  @override
  Future<Result<CommentPage>> listComments({
    required String targetType,
    required String targetId,
    int page = 0,
    int size = 20,
  }) async => const Result.success(CommentPage(items: [], totalElements: 0));
}

class _Dm extends Fake implements DmRepository {}

String _jwt(String user, String nonce) =>
    '${base64Url.encode(utf8.encode('{"alg":"none"}'))}.'
    '${base64Url.encode(utf8.encode(jsonEncode({'sub': user, 'jti': nonce, 'exp': 4102444800})))}.signature';

class _Tokens extends Fake implements TokenStore {
  _Tokens(this.value);
  String? value;
  Completer<String?>? block;
  Completer<void> started = Completer<void>();
  @override
  Future<String?> readToken() async {
    if (!started.isCompleted) started.complete();
    return block?.future ?? value;
  }
}

class _Adapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      jsonEncode({'success': true, 'data': _json}),
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
