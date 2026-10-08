import 'dart:async';
import 'dart:ui' show SemanticsAction;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/app/router/app_routes.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session.dart';
import 'package:soundconnect_23_12_25codx/core/error/app_error.dart';
import 'package:soundconnect_23_12_25codx/core/error/result.dart';
import 'package:soundconnect_23_12_25codx/modules/dm/domain/dm_user_profile_resolver.dart';
import 'package:soundconnect_23_12_25codx/modules/dm/domain/entities/dm_profile_target.dart';
import 'package:soundconnect_23_12_25codx/modules/engagement/domain/engagement_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/engagement/domain/entities/comment_user_summary.dart';
import 'package:soundconnect_23_12_25codx/modules/engagement/domain/entities/like_user_page.dart';
import 'package:soundconnect_23_12_25codx/modules/engagement/presentation/widgets/like_users_sheet.dart';
import 'package:soundconnect_23_12_25codx/modules/musician_feed/presentation/musician_feed_visual_theme.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/listener_visibility_mode.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/profile_route_args.dart';
import 'package:soundconnect_23_12_25codx/shared/widgets/ghost_profile_badge.dart';

import 'support/event_audience_fakes.dart';

void main() {
  testWidgets('loads exact publication and cursor pages, deduplicating users', (
    tester,
  ) async {
    final repo = _Repository();
    repo.responses.addAll([
      () async => _page([_user('leyla')], next: 'page-2'),
      () async => _page([_user('leyla'), _user('sude')]),
    ]);
    await _mount(tester, repo);
    expect(repo.calls, [
      (type: 'EVENT_POST', id: 'publication-id', cursor: null),
    ]);
    expect(find.text('Beğenenler'), findsOneWidget);
    expect(find.text('leyla'), findsOneWidget);
    await tester.tap(find.text('Daha fazla göster'));
    await tester.pumpAndSettle();
    expect(repo.calls.last.cursor, 'page-2');
    expect(find.text('leyla'), findsOneWidget);
    expect(find.text('sude'), findsOneWidget);
    expect(find.text('Daha fazla göster'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('initial loading, failure, and retry retain exact scope', (
    tester,
  ) async {
    final pending = Completer<Result<LikeUserPage>>();
    final repo = _Repository()..responses.add(() => pending.future);
    await _mount(tester, repo, settle: false);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    pending.complete(
      const Result.failure(AppError(code: 'network', message: 'internal')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Beğenenler yüklenemedi.'), findsOneWidget);
    expect(find.text('internal'), findsNothing);
    repo.responses.add(() async => _page([_user('sude')]));
    await tester.tap(find.text('Yeniden dene'));
    await tester.pumpAndSettle();
    expect(repo.calls.map((call) => call.cursor), [null, null]);
    expect(find.text('sude'), findsOneWidget);
  });

  testWidgets(
    'pagination failure preserves rows and retries the failed cursor',
    (tester) async {
      final repo = _Repository();
      repo.responses.addAll([
        () async => _page([_user('leyla')], next: 'page-2'),
        () async => throw StateError('transport failure'),
        () async => _page([_user('sude')]),
      ]);
      await _mount(tester, repo);
      await tester.tap(find.text('Daha fazla göster'));
      await tester.pumpAndSettle();
      expect(find.text('leyla'), findsOneWidget);
      expect(find.text('Diğer beğeniler yüklenemedi.'), findsOneWidget);
      await tester.tap(find.text('Yeniden dene'));
      await tester.pumpAndSettle();
      expect(repo.calls.map((call) => call.cursor), [null, 'page-2', 'page-2']);
      expect(find.text('sude'), findsOneWidget);
    },
  );

  testWidgets('parallel taps do not dispatch duplicate pages', (tester) async {
    final pending = Completer<Result<LikeUserPage>>();
    final repo = _Repository();
    repo.responses.addAll([
      () async => _page([_user('leyla')], next: 'page-2'),
      () => pending.future,
    ]);
    await _mount(tester, repo);
    await tester.tap(find.text('Daha fazla göster'));
    await tester.tap(find.text('Daha fazla göster'));
    expect(repo.calls.length, 2);
    pending.complete(_page([_user('sude')]));
    await tester.pumpAndSettle();
    expect(find.text('sude'), findsOneWidget);
  });

  testWidgets('repeated cursors stop instead of loading indefinitely', (
    tester,
  ) async {
    final repo = _Repository();
    repo.responses.addAll([
      () async => _page([_user('leyla')], next: 'same-cursor'),
      () async => _page([_user('leyla')], next: 'same-cursor'),
    ]);
    await _mount(tester, repo);
    await tester.tap(find.text('Daha fazla göster'));
    await tester.pumpAndSettle();
    await tester.drag(
      find.byKey(const Key('like-users-list')),
      const Offset(0, -300),
    );
    await tester.pumpAndSettle();
    expect(repo.calls.length, 2);
    expect(find.text('leyla'), findsOneWidget);
    expect(find.text('Daha fazla göster'), findsNothing);
  });

  testWidgets('empty list has its own state', (tester) async {
    final repo = _Repository()..responses.add(() async => _page([]));
    await _mount(tester, repo);
    expect(find.text('Henüz beğeni yok.'), findsOneWidget);
    expect(find.text('Yeniden dene'), findsNothing);
  });

  testWidgets('session replacement clears rows and rejects in-flight pages', (
    tester,
  ) async {
    final pending = Completer<Result<LikeUserPage>>();
    final repo = _Repository();
    repo.responses.addAll([
      () async => _page([_user('leyla')], next: 'page-2'),
      () => pending.future,
    ]);
    final sessions = AudienceTestSessions(audienceSession());
    addTearDown(sessions.dispose);
    await _mount(tester, repo, sessions: sessions);
    await tester.tap(find.text('Daha fazla göster'));
    sessions.replace(audienceSession(user: 'new-viewer', token: 'new-token'));
    await tester.pump();
    expect(find.text('leyla'), findsNothing);
    pending.complete(_page([_user('sude')]));
    await tester.pumpAndSettle();
    expect(find.text('sude'), findsNothing);
    expect(find.text('Daha fazla göster'), findsNothing);
    expect(repo.calls.length, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('disposed sheet ignores its late response', (tester) async {
    final pending = Completer<Result<LikeUserPage>>();
    final repo = _Repository()..responses.add(() => pending.future);
    await _mount(tester, repo, settle: false);
    await tester.pumpWidget(const MaterialApp(home: Scaffold()));
    pending.complete(_page([_user('sude')]));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('invalidated source gates navigation and pending data', (
    tester,
  ) async {
    final pending = Completer<Result<LikeUserPage>>();
    final repo = _Repository();
    repo.responses.addAll([
      () async => _page([_user('leyla')], next: 'page-2'),
      () => pending.future,
    ]);
    final resolver = _Resolver();
    var current = true;
    await _mount(tester, repo, resolver: resolver, isCurrent: () => current);
    await tester.tap(find.text('Daha fazla göster'));
    current = false;
    await tester.tap(find.text('leyla'));
    pending.complete(_page([_user('sude')]));
    await tester.pump();
    expect(resolver.users, isEmpty);
    expect(find.text('sude'), findsNothing);
  });

  testWidgets('navigates with resolved profile ID, never the liker user ID', (
    tester,
  ) async {
    final repo = _Repository()
      ..responses.add(() async => _page([_user('leyla')]));
    final resolver = _Resolver()..targets = [_target('profile-42')];
    final routes = <RouteSettings>[];
    await _mount(tester, repo, resolver: resolver, routes: routes);
    await tester.tap(find.text('leyla'));
    await tester.pumpAndSettle();
    expect(resolver.users, ['user-leyla']);
    expect(routes.single.name, AppRoutes.musicianPublicProfile);
    expect(
      (routes.single.arguments as PublicProfileArgs).profileId,
      'profile-42',
    );
  });

  testWidgets('own liker opens editable owner profile without resolver', (
    tester,
  ) async {
    final repo = _Repository()
      ..responses.add(() async => _page([_user('leyla')]));
    final resolver = _Resolver();
    final sessions = AudienceTestSessions(
      audienceSession(user: 'user-leyla', role: 'ROLE_MUSICIAN'),
    );
    addTearDown(sessions.dispose);
    final routes = <RouteSettings>[];
    await _mount(
      tester,
      repo,
      resolver: resolver,
      sessions: sessions,
      routes: routes,
    );
    await tester.tap(find.text('leyla'));
    await tester.pumpAndSettle();
    expect(resolver.users, isEmpty);
    expect(routes.single.name, AppRoutes.musicianProfile);
    expect(routes.single.arguments, isNull);
  });

  testWidgets(
    'double profile taps coalesce and session change rejects navigation',
    (tester) async {
      final pending = Completer<List<DmProfileTarget>>();
      final repo = _Repository()
        ..responses.add(() async => _page([_user('leyla')]));
      final resolver = _Resolver()..pending = pending.future;
      final sessions = AudienceTestSessions(audienceSession());
      addTearDown(sessions.dispose);
      final routes = <RouteSettings>[];
      await _mount(
        tester,
        repo,
        resolver: resolver,
        sessions: sessions,
        routes: routes,
      );
      await tester.tap(find.text('leyla'));
      await tester.tap(find.text('leyla'));
      expect(resolver.users.length, 1);
      sessions.replace(const AuthSession.guest());
      pending.complete([_target('profile-42')]);
      await tester.pumpAndSettle();
      expect(routes, isEmpty);
      expect(find.text('leyla'), findsNothing);
    },
  );

  testWidgets('studio restriction with no profile ID opens its explanation', (
    tester,
  ) async {
    final repo = _Repository()
      ..responses.add(() async => _page([_user('leyla')]));
    final resolver = _Resolver()
      ..targets = const [DmProfileTarget.studioRestricted()];
    final routes = <RouteSettings>[];
    await _mount(tester, repo, resolver: resolver, routes: routes);
    await tester.tap(find.text('leyla'));
    await tester.pumpAndSettle();
    expect(routes.single.name, AppRoutes.studioListenerInfo);
    expect((routes.single.arguments as PublicProfileArgs).profileId, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('multiple resolved profiles offer a chooser and correct route', (
    tester,
  ) async {
    final repo = _Repository()
      ..responses.add(() async => _page([_user('leyla')]));
    final resolver = _Resolver()
      ..targets = [
        _target('musician-42'),
        _target(
          'studio-42',
          type: DmProfileTargetType.studio,
          name: 'Leyla Stüdyo',
        ),
      ];
    final routes = <RouteSettings>[];
    await _mount(tester, repo, resolver: resolver, routes: routes);
    await tester.tap(find.text('leyla'));
    await tester.pumpAndSettle();
    expect(find.text('Profili seç'), findsOneWidget);
    await tester.tap(find.text('Leyla Stüdyo'));
    await tester.pumpAndSettle();
    expect(routes.single.name, AppRoutes.studioPublicProfile);
    expect(
      (routes.single.arguments as PublicProfileArgs).profileId,
      'studio-42',
    );
  });

  testWidgets('ghost badges and long usernames fit 320dp with 2x text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = _Repository()
      ..responses.add(
        () async => _page([
          _user(
            'very_long_username_that_must_wrap_without_overflow',
            ghost: true,
          ),
        ]),
      );
    await _mount(tester, repo, textScale: 2);
    expect(find.byType(GhostProfileBadge), findsOneWidget);
    final row = find.byKey(
      const ValueKey(
        'like-user-user-very_long_username_that_must_wrap_without_overflow',
      ),
    );
    expect(tester.getSize(row).height, greaterThanOrEqualTo(44));
    expect(tester.takeException(), isNull);
  });

  testWidgets('screen reader activation opens the liker profile', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      final repo = _Repository()
        ..responses.add(() async => _page([_user('leyla')]));
      final resolver = _Resolver()..targets = [_target('musician-42')];
      final routes = <RouteSettings>[];
      await _mount(tester, repo, resolver: resolver, routes: routes);
      final node = tester.getSemantics(
        find.bySemanticsLabel('leyla, profili aç'),
      );
      expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
      tester.binding.pipelineOwner.semanticsOwner!.performAction(
        node.id,
        SemanticsAction.tap,
      );
      await tester.pumpAndSettle();
      expect(routes.single.name, AppRoutes.musicianPublicProfile);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('guest session does not fetch identities', (tester) async {
    final repo = _Repository();
    final sessions = AudienceTestSessions(const AuthSession.guest());
    addTearDown(sessions.dispose);
    await _mount(tester, repo, sessions: sessions);
    expect(repo.calls, isEmpty);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}

Future<void> _mount(
  WidgetTester tester,
  _Repository repository, {
  AudienceTestSessions? sessions,
  _Resolver? resolver,
  bool Function()? isCurrent,
  List<RouteSettings>? routes,
  bool settle = true,
  double textScale = 1,
}) async {
  final manager = sessions ?? AudienceTestSessions(audienceSession());
  if (sessions == null) addTearDown(manager.dispose);
  await tester.pumpWidget(
    MaterialApp(
      onGenerateRoute: (settings) {
        routes?.add(settings);
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const Scaffold(body: Text('Profile destination')),
        );
      },
      home: MusicianFeedThemeScope(
        child: Scaffold(
          body: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(textScale)),
              child: LikeUsersSheet(
                targetType: 'EVENT_POST',
                targetId: 'publication-id',
                repository: repository,
                sessions: manager,
                resolver: resolver,
                isCurrent: isCurrent,
              ),
            ),
          ),
        ),
      ),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}

CommentUserSummary _user(String name, {bool ghost = false}) =>
    CommentUserSummary(
      id: 'user-$name',
      username: name,
      avatarUrl: null,
      visibilityMode: ghost
          ? ListenerVisibilityMode.ghost
          : ListenerVisibilityMode.standard,
    );

Result<LikeUserPage> _page(List<CommentUserSummary> users, {String? next}) =>
    Result.success(
      LikeUserPage(items: users, nextCursor: next, hasMore: next != null),
    );

DmProfileTarget _target(
  String id, {
  DmProfileTargetType type = DmProfileTargetType.musician,
  String name = 'leyla',
}) => DmProfileTarget(type: type, id: id, displayName: name, imageUrl: null);

class _Repository extends Fake implements EngagementRepository {
  final calls = <({String type, String id, String? cursor})>[];
  final responses = <Future<Result<LikeUserPage>> Function()>[];

  @override
  Future<Result<LikeUserPage>> listLikeUsers({
    required String targetType,
    required String targetId,
    String? cursor,
    int size = 20,
  }) {
    calls.add((type: targetType, id: targetId, cursor: cursor));
    return responses.removeAt(0)();
  }
}

class _Resolver extends Fake implements DmUserProfileResolver {
  final users = <String>[];
  List<DmProfileTarget> targets = [];
  Future<List<DmProfileTarget>>? pending;
  @override
  Future<List<DmProfileTarget>> resolveByUserId({
    required String userId,
    String? usernameHint,
  }) async {
    users.add(userId);
    return pending ?? targets;
  }
}
