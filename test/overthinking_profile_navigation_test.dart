import 'dart:async';

import 'package:flutter/material.dart' hide Page;
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/app/router/app_routes.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session_manager.dart';
import 'package:soundconnect_23_12_25codx/core/auth/token_store.dart';
import 'package:soundconnect_23_12_25codx/core/di/service_locator.dart';
import 'package:soundconnect_23_12_25codx/core/error/result.dart';
import 'package:soundconnect_23_12_25codx/core/pagination/page.dart';
import 'package:soundconnect_23_12_25codx/modules/dm/data/dm_user_profile_resolver_impl.dart';
import 'package:soundconnect_23_12_25codx/modules/dm/domain/dm_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/dm/domain/dm_user_profile_resolver.dart';
import 'package:soundconnect_23_12_25codx/modules/dm/domain/entities/dm_profile_target.dart';
import 'package:soundconnect_23_12_25codx/modules/dm/presentation/cubit/dm_badge_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/overthinking/data/models/overthinking_post_model.dart';
import 'package:soundconnect_23_12_25codx/modules/overthinking/domain/entities/overthinking_incoming_unread_status.dart';
import 'package:soundconnect_23_12_25codx/modules/overthinking/domain/entities/overthinking_post.dart';
import 'package:soundconnect_23_12_25codx/modules/overthinking/domain/entities/overthinking_reveal_request.dart';
import 'package:soundconnect_23_12_25codx/modules/overthinking/domain/overthinking_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/overthinking/presentation/screens/overthinking_feed_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/overthinking/presentation/screens/overthinking_manage_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/overthinking/presentation/screens/overthinking_profile_link.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/listener_visibility_mode.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/profile_route_args.dart';

import 'support/event_audience_fakes.dart';
import 'support/recording_api_client.dart';

void main() {
  late AudienceTestSessions sessions;
  late _Resolver resolver;
  late List<RouteSettings> destinations;

  setUp(() {
    sessions = AudienceTestSessions(audienceSession(user: 'viewer'));
    resolver = _Resolver();
    destinations = [];
    serviceLocator.registerSingleton<AuthSessionManager>(sessions);
    serviceLocator.registerSingleton<DmUserProfileResolver>(resolver);
  });
  tearDown(() async => serviceLocator.reset());

  Future<void> mount(
    WidgetTester tester, {
    Widget? child,
    GlobalKey<NavigatorState>? navigatorKey,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        onGenerateRoute: (settings) {
          destinations.add(settings);
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => const Scaffold(body: Text('Public destination')),
          );
        },
        home: Scaffold(
          body: Center(
            child:
                child ??
                const OverthinkingProfileLink(
                  userId: 'author-user',
                  child: Text('Author identity'),
                ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final entry in {
    DmProfileTargetType.listener: AppRoutes.listenerPublicProfile,
    DmProfileTargetType.musician: AppRoutes.musicianPublicProfile,
    DmProfileTargetType.studio: AppRoutes.studioPublicProfile,
    DmProfileTargetType.venue: AppRoutes.venuePublicProfile,
  }.entries) {
    testWidgets('${entry.key.name} identity uses canonical public profile ID', (
      tester,
    ) async {
      resolver.targets = [_target(entry.key)];
      await mount(tester);
      await tester.tap(find.text('Author identity'));
      await tester.pumpAndSettle();
      expect(resolver.lookups, ['author-user']);
      expect(resolver.hints.single, isNull);
      expect(destinations.single.name, entry.value);
      expect(
        (destinations.single.arguments as PublicProfileArgs).profileId,
        'canonical-profile',
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('rapid avatar/name taps cause one lookup and one destination', (
    tester,
  ) async {
    final pending = Completer<List<DmProfileTarget>>();
    resolver.pending = pending;
    await mount(tester);
    await tester.tap(find.text('Author identity'));
    await tester.tap(find.text('Author identity'));
    expect(resolver.lookups, hasLength(1));
    pending.complete([_target(DmProfileTargetType.studio)]);
    await tester.pumpAndSettle();
    expect(destinations, hasLength(1));
  });

  for (final change in ['account', 'same-account', 'route', 'revoked']) {
    testWidgets('$change while resolving cannot open a stale identity', (
      tester,
    ) async {
      final pending = Completer<List<DmProfileTarget>>();
      resolver.pending = pending;
      final navigator = GlobalKey<NavigatorState>();
      final visible = ValueNotifier(true);
      addTearDown(visible.dispose);
      await mount(
        tester,
        navigatorKey: navigator,
        child: ValueListenableBuilder<bool>(
          valueListenable: visible,
          builder: (_, enabled, _) => OverthinkingProfileLink(
            userId: enabled ? 'author-user' : null,
            enabled: enabled,
            child: Text(enabled ? 'Author identity' : 'Anonim'),
          ),
        ),
      );
      await tester.tap(find.text('Author identity'));
      switch (change) {
        case 'account':
          sessions.replace(audienceSession(user: 'other'));
        case 'same-account':
          sessions.replace(audienceSession(user: 'viewer', token: 'new-token'));
        case 'route':
          navigator.currentState!.push(
            MaterialPageRoute<void>(
              builder: (_) => const Scaffold(body: Text('Another screen')),
            ),
          );
        case 'revoked':
          visible.value = false;
      }
      await tester.pumpAndSettle();
      pending.complete([_target(DmProfileTargetType.listener)]);
      await tester.pumpAndSettle();
      expect(destinations, isEmpty);
      expect(find.text('Public destination'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'hidden anonymous post never loads avatar or resolves leaked DTO identity',
    (tester) async {
      final post = OverthinkingPostModel.fromJson({
        'id': 'anonymous-post',
        'title': 'Anonymous title',
        'content': 'A thought',
        'anonymous': true,
        'canViewAuthor': false,
        'visibilityType': 'ANONYMOUS',
        'authorId': 'must-not-resolve',
        'authorUsername': 'must-not-display',
        'authorAvatarUrl': 'https://example.test/private-avatar.jpg',
      });
      await mount(
        tester,
        child: OverthinkingPostCard(
          post: post,
          onTap: () {},
          onLike: () {},
          onComments: () {},
        ),
      );
      expect(find.textContaining('must-not-display'), findsNothing);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Image &&
              widget.image is NetworkImage &&
              (widget.image as NetworkImage).url.contains('private-avatar'),
        ),
        findsNothing,
      );
      expect(
        find
            .byType(OverthinkingProfileLink)
            .evaluate()
            .every(
              (element) => !(element.widget as OverthinkingProfileLink).enabled,
            ),
        isTrue,
      );
      await tester.tap(find.text('Anonim'));
      await tester.pumpAndSettle();
      expect(resolver.lookups, isEmpty);
      expect(destinations, isEmpty);
    },
  );

  testWidgets(
    'multiple profiles offer type choices without stale display names or avatars',
    (tester) async {
      resolver.targets = [
        _target(DmProfileTargetType.listener),
        _target(DmProfileTargetType.musician),
      ];
      await mount(tester);
      await tester.tap(find.text('Author identity'));
      await tester.pumpAndSettle();
      expect(find.text('Dinleyici'), findsOneWidget);
      expect(find.text('Müzisyen'), findsOneWidget);
      expect(find.text('Resolver-only name'), findsNothing);
      await tester.tap(find.text('Müzisyen'));
      await tester.pumpAndSettle();
      expect(destinations.single.name, AppRoutes.musicianPublicProfile);
    },
  );

  testWidgets(
    'ghost requester avatar and username both open fresh listener profile',
    (tester) async {
      final api = RecordingApiClient(
        (_) => {
          'profiles': [
            {
              'type': 'LISTENER',
              'profileId': 'ghost-profile',
              'displayName': 'Ghost from canonical resolver',
              'visibilityMode': 'GHOST',
            },
          ],
        },
      );
      serviceLocator.unregister<DmUserProfileResolver>();
      serviceLocator.registerSingleton<DmUserProfileResolver>(
        DmUserProfileResolverImpl(apiClient: api),
      );
      final posts = _Posts();
      serviceLocator.registerSingleton<OverthinkingRepository>(posts);
      final badge = DmBadgeCubit(_Dm(), _Tokens());
      addTearDown(badge.close);
      serviceLocator.registerSingleton<DmBadgeCubit>(badge);
      await mount(
        tester,
        child: const OverthinkingManageScreen(initialTabIndex: 1),
      );
      expect(find.text('@contextual-ghost'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('reveal-requester-ghost-request')),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const ValueKey('reveal-requester-avatar-request')),
      );
      await tester.pumpAndSettle();
      expect(destinations.single.name, AppRoutes.listenerPublicProfile);
      expect(
        (destinations.single.arguments as PublicProfileArgs).profileId,
        'ghost-profile',
      );
      Navigator.of(tester.element(find.text('Public destination'))).pop();
      await tester.pumpAndSettle();
      await tester.tap(find.text('@contextual-ghost'));
      await tester.pumpAndSettle();
      expect(destinations, hasLength(2));
      // Listener projections are mutable; this must not use a persisted target.
      expect(api.requests, hasLength(2));
      expect(
        api.requests.every(
          (request) => request.path.endsWith('/requester-user'),
        ),
        isTrue,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'management preview author avatar opens the canonical public profile',
    (tester) async {
      resolver.targets = [_target(DmProfileTargetType.venue)];
      serviceLocator.registerSingleton<OverthinkingRepository>(
        _Posts(withPost: true),
      );
      final badge = DmBadgeCubit(_Dm(), _Tokens());
      addTearDown(badge.close);
      serviceLocator.registerSingleton<DmBadgeCubit>(badge);
      await mount(tester, child: const OverthinkingManageScreen());
      await tester.tap(find.text('Visible preview title'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('preview-author-avatar')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('preview-author-avatar')));
      await tester.pumpAndSettle();
      expect(resolver.lookups, ['preview-author']);
      expect(destinations.single.name, AppRoutes.venuePublicProfile);
      expect(
        (destinations.single.arguments as PublicProfileArgs).profileId,
        'canonical-profile',
      );
      expect(tester.takeException(), isNull);
    },
  );
}

DmProfileTarget _target(DmProfileTargetType type) => DmProfileTarget(
  type: type,
  id: 'canonical-profile',
  displayName: 'Resolver-only name',
  imageUrl: null,
);

class _Resolver extends Fake implements DmUserProfileResolver {
  final lookups = <String>[];
  final hints = <String?>[];
  List<DmProfileTarget> targets = [];
  Completer<List<DmProfileTarget>>? pending;
  @override
  Future<List<DmProfileTarget>> resolveByUserId({
    required String userId,
    String? usernameHint,
  }) async {
    lookups.add(userId);
    hints.add(usernameHint);
    return pending?.future ?? targets;
  }
}

class _Posts extends Fake implements OverthinkingRepository {
  _Posts({this.withPost = false});
  final bool withPost;
  final post = OverthinkingPostModel.fromJson({
    'id': 'preview-post',
    'title': 'Visible preview title',
    'content': 'Preview content',
    'authorId': 'preview-author',
    'authorUsername': 'preview-name',
    'anonymous': false,
    'canViewAuthor': true,
    'visibilityType': 'VISIBLE',
  });
  @override
  Future<Result<OverthinkingPost>> getDetail({required String postId}) async =>
      Result.success(post);
  @override
  Future<Result<Page<OverthinkingPost>>> getMyPosts({
    int page = 0,
    int size = 20,
  }) async =>
      Result.success(Page(items: withPost ? [post] : [], hasNext: false));
  @override
  Future<Result<Page<OverthinkingRevealRequest>>> getIncomingRevealRequests({
    int page = 0,
    int size = 20,
  }) async => const Result.success(
    Page(
      items: [
        OverthinkingRevealRequest(
          id: 'request',
          postId: 'post',
          postTitle: 'A thought',
          requesterId: 'requester-user',
          requesterUsername: 'contextual-ghost',
          requesterAvatarUrl: null,
          requesterVisibilityMode: ListenerVisibilityMode.ghost,
          authorId: '',
          status: 'PENDING',
          createdAt: null,
        ),
      ],
      hasNext: false,
    ),
  );
  @override
  Future<Result<Page<OverthinkingRevealRequest>>> getSentRevealRequests({
    int page = 0,
    int size = 20,
  }) async => const Result.success(Page(items: [], hasNext: false));
  @override
  Future<Result<OverthinkingIncomingUnreadStatus>>
  getIncomingUnreadStatus() async => const Result.success(
    OverthinkingIncomingUnreadStatus(hasUnread: false, revision: 0),
  );
  @override
  Future<Result<OverthinkingIncomingUnreadStatus>> markIncomingRequestsSeen({
    required int revision,
  }) async => const Result.success(
    OverthinkingIncomingUnreadStatus(hasUnread: false, revision: 0),
  );
}

class _Dm extends Fake implements DmRepository {}

class _Tokens extends Fake implements TokenStore {
  @override
  Future<String?> readToken() async => null;
}
