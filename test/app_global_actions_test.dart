import 'dart:async';
import 'dart:ui' show SemanticsAction;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide Page;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/app/router/app_routes.dart';
import 'package:soundconnect_23_12_25codx/app/widgets/app_global_actions.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session_manager.dart';
import 'package:soundconnect_23_12_25codx/core/di/service_locator.dart';
import 'package:soundconnect_23_12_25codx/core/error/result.dart';
import 'package:soundconnect_23_12_25codx/modules/event_audience/domain/event_audience_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/presentation/cubit/notification_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/presentation/cubit/notification_state.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/presentation/screens/notification_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/overthinking/data/models/overthinking_post_model.dart';
import 'package:soundconnect_23_12_25codx/modules/overthinking/domain/entities/overthinking_post.dart';
import 'package:soundconnect_23_12_25codx/modules/overthinking/domain/overthinking_profile_share_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/overthinking/domain/overthinking_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/overthinking/presentation/overthinking_profile_draft.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/listener_profile.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/profile_search_result.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/listener_profile_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/profile_search_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/cubit/listener_profile_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/listener_profile_screen.dart';

import 'support/event_audience_fakes.dart';

final _searchButton = find.byKey(const ValueKey('app-global-search'));
final _notificationButton = find.byTooltip('Bildirimler');

void main() {
  setUp(() async => serviceLocator.reset());
  tearDown(() async => serviceLocator.reset());

  for (final listener in [false, true]) {
    testWidgets('existing search sheet retains listener=$listener audience', (
      tester,
    ) async {
      final h = _Harness(listener: listener);
      await h.mount(tester);
      await tester.tap(_searchButton);
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(h.search.queries, isEmpty);

      await tester.enterText(find.byType(TextField), 'deniz');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      expect(h.search.queries, ['deniz']);
      expect(find.text('Deniz müzisyen'), findsOneWidget);
      if (listener) {
        expect(h.search.types, {
          ProfileSearchResultType.musician,
          ProfileSearchResultType.listener,
          ProfileSearchResultType.band,
          ProfileSearchResultType.venue,
        });
        expect(find.text('Deniz stüdyo'), findsNothing);
      } else {
        expect(h.search.types, isNull);
        expect(find.text('Deniz stüdyo'), findsOneWidget);
      }
      expect(h.notices.startCalls, 0);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets(
    'bell uses existing cubit and notification route without startup',
    (tester) async {
      final h = _Harness();
      final semantics = tester.ensureSemantics();
      try {
        await h.mount(tester);
        expect(
          tester.widget<Badge>(find.byType(Badge)).isLabelVisible,
          isFalse,
        );
        h.notices.setUnread(7);
        await tester.pumpAndSettle();
        expect(find.text('7'), findsOneWidget);
        expect(
          find.bySemanticsLabel('Bildirimler, 7 okunmamış'),
          findsOneWidget,
        );
        expect(
          tester
              .getSemantics(find.bySemanticsLabel('Bildirimler, 7 okunmamış'))
              .getSemanticsData()
              .hasAction(SemanticsAction.tap),
          isTrue,
        );
        h.notices.setUnread(120);
        await tester.pumpAndSettle();
        expect(find.text('99+'), findsOneWidget);

        await tester.tap(_notificationButton);
        await tester.pumpAndSettle();
        expect(h.observer.namedPushes, [AppRoutes.notifications]);
        expect(find.byType(NotificationScreen), findsOneWidget);
        expect(h.notices.markAllCalls, 1);
        expect(h.notices.startCalls, 0);
        h.navigator.currentState!.pop();
        await tester.pumpAndSettle();
        h.notices.setUnread(0);
        await tester.pumpAndSettle();
        expect(
          tester.widget<Badge>(find.byType(Badge)).isLabelVisible,
          isFalse,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      } finally {
        semantics.dispose();
      }
    },
  );

  testWidgets('isolated header renders a quiet bell without a cubit', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(appBar: AppBar(actions: const [AppGlobalActions()])),
      ),
    );
    expect(tester.widget<Badge>(find.byType(Badge)).isLabelVisible, isFalse);
    expect(tester.takeException(), isNull);
  });

  for (final action in ['search', 'notifications']) {
    final button = action == 'search' ? _searchButton : _notificationButton;
    testWidgets('cancelled guard blocks $action and permits a later attempt', (
      tester,
    ) async {
      var allow = false;
      var calls = 0;
      final h = _Harness();
      await h.mount(
        tester,
        beforeNavigate: () async {
          calls++;
          return allow;
        },
      );
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(calls, 1);
      expect(find.byType(BottomSheet), findsNothing);
      expect(find.byType(NotificationScreen), findsNothing);
      expect(h.observer.destinationPushes, 0);
      allow = true;
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(calls, 2);
      expect(h.observer.destinationPushes, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    for (final interruption in ['session', 'route']) {
      testWidgets(
        'delayed $action guard is fenced after $interruption change',
        (tester) async {
          final h = _Harness();
          final decision = Completer<bool>();
          await h.mount(tester, beforeNavigate: () => decision.future);
          await tester.tap(button);
          await tester.pump();
          if (interruption == 'session') {
            h.sessions.replace(audienceSession(user: 'replacement'));
          } else {
            unawaited(
              h.navigator.currentState!.push<void>(
                MaterialPageRoute(
                  settings: const RouteSettings(name: '/covered'),
                  builder: (_) => const Scaffold(body: Text('Covered route')),
                ),
              ),
            );
          }
          await tester.pumpAndSettle();
          decision.complete(true);
          await tester.pumpAndSettle();
          expect(find.byType(BottomSheet), findsNothing);
          expect(find.byType(NotificationScreen), findsNothing);
          expect(h.observer.destinationPushes, 0);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }

    testWidgets('rapid $action taps open exactly one destination', (
      tester,
    ) async {
      final h = _Harness();
      final decision = Completer<bool>();
      var guardCalls = 0;
      await h.mount(
        tester,
        beforeNavigate: () {
          guardCalls++;
          return decision.future;
        },
      );
      await tester.tap(button);
      await tester.tap(button);
      await tester.tap(
        action == 'search' ? _notificationButton : _searchButton,
      );
      await tester.pump();
      expect(guardCalls, 1);
      decision.complete(true);
      await tester.pumpAndSettle();
      expect(h.observer.destinationPushes, 1);
      expect(
        action == 'search'
            ? find.byType(BottomSheet)
            : find.byType(NotificationScreen),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('real listener dirty draft protects global $action', (
      tester,
    ) async {
      final h = _Harness(listener: true);
      final shares = _DraftShares();
      final events = _EmptyEvents();
      addTearDown(shares.signal.dispose);
      addTearDown(events.signal.dispose);
      serviceLocator
        ..registerSingleton<OverthinkingProfileShareRepository>(shares)
        ..registerSingleton<OverthinkingRepository>(_DraftSource())
        ..registerSingleton<EventAudienceRepository>(events);
      await h.mount(
        tester,
        home: ListenerProfileScreen(
          showBottomNavigation: false,
          cubitFactory: () =>
              ListenerProfileCubit(_Profiles(), sessions: h.sessions),
          overthinkingDraft: OverthinkingProfileDraftArgs(
            postId: _draftSourceId,
            expectedSession: h.sessions.session,
          ),
        ),
      );
      final note = find.byKey(const Key('listener-overthinking-draft-note'));
      expect(note, findsOneWidget);
      await tester.enterText(note, 'Taslağım kaybolmasın');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('listener-overthinking-draft-leave-dialog')),
        findsOneWidget,
      );
      await tester.tap(find.text('Düzenlemeye devam et'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(note).controller!.text,
        'Taslağım kaybolmasın',
      );
      expect(find.byType(BottomSheet), findsNothing);
      expect(find.byType(NotificationScreen), findsNothing);
      expect(h.search.queries, isEmpty);
      expect(h.observer.destinationPushes, 0);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}

class _Harness {
  _Harness({bool listener = false})
    : sessions = AudienceTestSessions(
        audienceSession(role: listener ? 'ROLE_LISTENER' : 'ROLE_MUSICIAN'),
      ) {
    serviceLocator
      ..registerSingleton<AuthSessionManager>(sessions)
      ..registerSingleton<ProfileSearchRepository>(search);
    addTearDown(sessions.dispose);
    addTearDown(notices.close);
  }

  final AudienceTestSessions sessions;
  final search = _Search();
  final notices = _Notices();
  final navigator = GlobalKey<NavigatorState>();
  final observer = _RouteObserver();

  Future<void> mount(
    WidgetTester tester, {
    Future<bool> Function()? beforeNavigate,
    Widget? home,
  }) async {
    await tester.pumpWidget(
      BlocProvider<NotificationCubit>.value(
        value: notices,
        child: MaterialApp(
          navigatorKey: navigator,
          navigatorObservers: [observer],
          routes: {AppRoutes.notifications: (_) => const NotificationScreen()},
          home:
              home ??
              Scaffold(
                appBar: AppBar(
                  title: const Text('SoundConnect'),
                  actions: [AppGlobalActions(onBeforeNavigate: beforeNavigate)],
                ),
              ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }
}

class _RouteObserver extends NavigatorObserver {
  final namedPushes = <String>[];
  int destinationPushes = 0;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    if (route.settings.name == AppRoutes.notifications) {
      namedPushes.add(route.settings.name!);
      destinationPushes++;
    } else if (route is ModalBottomSheetRoute) {
      destinationPushes++;
    }
  }
}

class _Notices extends Cubit<NotificationState> implements NotificationCubit {
  _Notices() : super(const NotificationState.initial());
  int startCalls = 0;
  int markAllCalls = 0;

  void setUnread(int count) => emit(state.copyWith(unreadCount: count));

  @override
  Future<void> ensureStarted() async {
    startCalls++;
  }

  @override
  Future<void> markAllAsRead() async {
    markAllCalls++;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Search extends Fake implements ProfileSearchRepository {
  final queries = <String>[];
  Set<ProfileSearchResultType>? types;

  @override
  Future<Result<List<ProfileSearchResult>>> searchProfiles(
    String query, {
    Set<ProfileSearchResultType>? types,
  }) async {
    queries.add(query);
    this.types = types;
    return Result.success([
      ProfileSearchResult.fromJson({
        'type': 'MUSICIAN',
        'targetId': 'musician',
        'title': 'Deniz müzisyen',
      }),
      ProfileSearchResult.fromJson({
        'type': 'STUDIO',
        'targetId': 'studio',
        'title': 'Deniz stüdyo',
      }),
    ]);
  }
}

const _draftSourceId = '0d87cfdc-44ea-48dd-a16c-28e27e92ba4d';

class _DraftShares extends Fake implements OverthinkingProfileShareRepository {
  final signal = ValueNotifier(0);

  @override
  ValueListenable<int> get changes => signal;

  @override
  Future<Result<OverthinkingProfileShareState>> getState({
    required String postId,
    required AuthSession expectedSession,
  }) async => Result.success(
    OverthinkingProfileShareState(
      postId: postId,
      shareId: null,
      publishedOnProfile: false,
      note: null,
      publishedAt: null,
      canPublish: true,
    ),
  );

  @override
  Future<Result<Page<OverthinkingProfileShare>>> listProfile({
    required String profileId,
    required AuthSession expectedSession,
    int page = 0,
    int size = 20,
  }) async =>
      const Result.success(Page(items: [], hasNext: false, totalElements: 0));
}

class _DraftSource extends Fake implements OverthinkingRepository {
  @override
  Future<Result<OverthinkingPost>> getDetail({required String postId}) async =>
      Result.success(
        OverthinkingPostModel.fromJson({
          'id': postId,
          'title': 'Taslak kaynağı',
          'content': 'Kaybolmaması gereken bir paylaşım.',
          'anonymous': true,
          'canViewAuthor': false,
          'visibilityType': 'ANONYMOUS',
          'authorUsername': 'Anonymous',
        }),
      );
}

class _Profiles extends ListenerProfileRepository {
  @override
  Future<Result<ListenerProfile>> getMyProfile() async => const Result.success(
    ListenerProfile(
      id: 'profile',
      userId: 'listener',
      username: 'deniz',
      bio: 'Müziğin peşinde.',
      profilePictureUrl: null,
      followerCount: 12,
      followingCount: 8,
      visibilityChoiceCompleted: true,
    ),
  );
}

class _EmptyEvents extends AudienceTestRepository {
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
