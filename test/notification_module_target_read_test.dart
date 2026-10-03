import 'dart:async';

import 'package:flutter/material.dart' hide Page;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/app/router/app_router.dart';
import 'package:soundconnect_23_12_25codx/app/router/app_routes.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session_manager.dart';
import 'package:soundconnect_23_12_25codx/core/auth/token_store.dart';
import 'package:soundconnect_23_12_25codx/core/di/service_locator.dart';
import 'package:soundconnect_23_12_25codx/core/error/app_error.dart';
import 'package:soundconnect_23_12_25codx/core/error/result.dart';
import 'package:soundconnect_23_12_25codx/core/pagination/page.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/domain/collab_commands.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/domain/collab_page.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/domain/collab_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/domain/collab_types.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/domain/entities/collab_application.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/domain/entities/collab_listing.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/presentation/collab_route_args.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/presentation/cubit/collab_discovery_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/presentation/cubit/collab_incoming_applications_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/presentation/screens/collab_discovery_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/presentation/screens/collab_incoming_applications_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/dm/domain/dm_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/dm/presentation/cubit/dm_badge_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/instrument/domain/entities/instrument.dart';
import 'package:soundconnect_23_12_25codx/modules/instrument/domain/instrument_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/location/domain/entities/city.dart';
import 'package:soundconnect_23_12_25codx/modules/location/domain/location_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/domain/entities/app_notification.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/presentation/cubit/notification_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/presentation/cubit/notification_state.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/presentation/notification_target_read.dart';
import 'package:soundconnect_23_12_25codx/modules/overthinking/domain/entities/overthinking_incoming_unread_status.dart';
import 'package:soundconnect_23_12_25codx/modules/overthinking/domain/entities/overthinking_post.dart';
import 'package:soundconnect_23_12_25codx/modules/overthinking/domain/entities/overthinking_reveal_request.dart';
import 'package:soundconnect_23_12_25codx/modules/overthinking/domain/overthinking_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/overthinking/presentation/screens/overthinking_manage_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/tablegroup/domain/entities/table_group.dart';
import 'package:soundconnect_23_12_25codx/modules/tablegroup/domain/table_group_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/tablegroup/presentation/cubit/table_group_list_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/tablegroup/presentation/screens/table_group_list_screen.dart';

import 'support/collab_test_support.dart';
import 'support/event_audience_fakes.dart';

void main() {
  late AudienceTestSessions sessions;
  late _RecordingNotifications notifications;
  late DmBadgeCubit dmBadge;

  setUp(() async {
    await serviceLocator.reset();
    sessions = AudienceTestSessions(
      audienceSession(user: 'owner', role: 'ROLE_MUSICIAN'),
    );
    notifications = _RecordingNotifications();
    dmBadge = DmBadgeCubit(_NoopDmRepository(), _EmptyTokenStore());
    serviceLocator
      ..registerSingleton<AuthSessionManager>(sessions)
      ..registerSingleton<NotificationCubit>(notifications)
      ..registerSingleton<TokenStore>(_EmptyTokenStore())
      ..registerSingleton<DmBadgeCubit>(dmBadge);
  });

  tearDown(() async {
    await serviceLocator.reset();
    await notifications.close();
    await dmBadge.close();
    sessions.dispose();
  });

  Future<GlobalKey<NavigatorState>> open(
    WidgetTester tester,
    Widget destination, {
    required String type,
    String? namedRoute,
    Object? arguments,
  }) async {
    tester.view.physicalSize = const Size(420, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      BlocProvider<NotificationCubit>.value(
        value: notifications,
        child: MaterialApp(
          navigatorKey: navigator,
          navigatorObservers: [notificationTargetRouteObserver],
          onGenerateRoute: AppRouter.onGenerateRoute,
          home: const Scaffold(body: Text('inbox')),
        ),
      ),
    );
    final ticket = NotificationTargetRead(
      notification: AppNotification(
        id: 'notification',
        recipientId: 'owner',
        type: type,
        title: 'Bildirim',
        message: '',
        read: false,
        createdAt: DateTime.utc(2026, 9, 27),
        payload: const {},
      ),
      cubit: notifications,
      sessions: sessions,
    );
    if (namedRoute == null) {
      unawaited(
        navigator.currentState!.push<void>(
          ticket.attach(MaterialPageRoute<void>(builder: (_) => destination)),
        ),
      );
    } else {
      unawaited(
        navigator.currentState!.pushNamed<void>(
          namedRoute,
          arguments: ticket.argumentsFor(namedRoute, arguments: arguments),
        ),
      );
    }
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
    return navigator;
  }

  for (final targetExists in [false, true]) {
    testWidgets(
      'Collab intermediate discovery and pending incoming do not read; '
      '${targetExists ? 'revealed exact application reads once' : 'missing application stays unread'}',
      (tester) async {
        final repository = _CollabRepository();
        serviceLocator.registerFactory<CollabIncomingApplicationsCubit>(
          () => CollabIncomingApplicationsCubit(repository),
        );
        final discovery = CollabDiscoveryCubit(repository);
        await open(
          tester,
          CollabDiscoveryScreen(
            showBottomNavigation: false,
            cubit: discovery,
            locationRepository: _Locations(),
            instrumentRepository: _Instruments(),
            initialRouteArgs: const CollabDiscoveryRouteArgs(
              initialListingId: 'listing',
              action: 'APPLICATION_RECEIVED',
              applicationId: 'requested-application',
            ),
          ),
          type: 'COLLAB_APPLICATION_RECEIVED',
        );
        // The discovery feed has succeeded, but this is only an automatic hop.
        expect(repository.discoverCalls, 1);
        expect(find.byType(CollabIncomingApplicationsScreen), findsOneWidget);
        expect(notifications.readIds, isEmpty);
        repository.incoming.complete(
          Result.success(
            _collabPage([
              _application(targetExists ? 'requested-application' : 'other'),
            ]),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          notifications.readIds,
          targetExists ? ['notification'] : isEmpty,
        );
        await tester.pump(const Duration(seconds: 1));
        expect(notifications.readIds.length, targetExists ? 1 : 0);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await discovery.close();
      },
    );
  }

  for (final targetTab in [1, 2]) {
    testWidgets(
      'Overthinking tab $targetTab waits for loaded intended tab to be visible',
      (tester) async {
        final repository = _OverthinkingRepository(pendingTab: targetTab);
        serviceLocator.registerSingleton<OverthinkingRepository>(repository);
        await open(
          tester,
          OverthinkingManageScreen(initialTabIndex: targetTab),
          type: targetTab == 1
              ? 'OVERTHINKING_REVEAL_REQUEST_RECEIVED'
              : 'OVERTHINKING_REVEAL_REQUEST_REJECTED',
        );
        expect(notifications.readIds, isEmpty);
        final tabs = tester.widget<TabBar>(find.byType(TabBar));
        tabs.controller!.animateTo(0);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        repository.requests.complete(
          const Result.success(Page(items: [], hasNext: false)),
        );
        await tester.pumpAndSettle();
        // Target data arrived while the successful posts tab was selected.
        expect(notifications.readIds, isEmpty);
        tabs.controller!.animateTo(targetTab);
        await tester.pumpAndSettle();
        expect(notifications.readIds, ['notification']);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  for (final succeeds in [false, true]) {
    testWidgets(
      'terminal Table list ${succeeds ? 'must not read after successful empty page without exact result' : 'does not read a failed page'}',
      (tester) async {
        final repository = _TableRepository();
        serviceLocator.registerFactory<TableGroupListCubit>(
          () => TableGroupListCubit(
            tableGroupRepository: repository,
            locationRepository: _Locations(),
          ),
        );
        await open(
          tester,
          const SizedBox.shrink(),
          type: 'TABLE_CANCELLED',
          namedRoute: AppRoutes.tableGroupList,
        );
        expect(notifications.readIds, isEmpty);
        repository.page.complete(
          succeeds
              ? const Result.success(Page(items: [], hasNext: false))
              : const Result.failure(
                  AppError(code: 'NETWORK', message: 'Liste yüklenemedi.'),
                ),
        );
        // The create-table FAB intentionally pulses forever; settle on the
        // content state instead of waiting for every animation to stop.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(
          succeeds
              ? find.text('Bu filtrede aktif masa bulunamadi')
              : find.byKey(const Key('table_group_feed_error')),
          findsOneWidget,
        );
        expect(notifications.readIds, isEmpty);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
  testWidgets(
    'invalid Table detail args fall back without reading the target',
    (tester) async {
      final repository = _TableRepository();
      serviceLocator.registerFactory<TableGroupListCubit>(
        () => TableGroupListCubit(
          tableGroupRepository: repository,
          locationRepository: _Locations(),
        ),
      );
      await open(
        tester,
        const SizedBox.shrink(),
        type: 'TABLE_JOIN_REQUEST_RECEIVED',
        namedRoute: AppRoutes.tableGroupDetail,
        arguments: 'invalid-detail-arguments',
      );
      repository.page.complete(
        const Result.success(Page(items: [], hasNext: false)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(TableGroupListScreen), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Bu filtrede aktif masa bulunamadi'), findsOneWidget);
      expect(notifications.readIds, isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}

class _RecordingNotifications extends Cubit<NotificationState>
    implements NotificationCubit {
  _RecordingNotifications() : super(const NotificationState.initial());
  final readIds = <String>[];

  @override
  Future<void> markAsRead(AppNotification notification) async {
    readIds.add(notification.id);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _CollabRepository extends Fake implements CollabRepository {
  final incoming = Completer<Result<CollabPage<CollabApplication>>>();
  int discoverCalls = 0;

  @override
  Future<Result<CollabPage<CollabListing>>> discover(
    CollabDiscoveryQuery query,
  ) async {
    discoverCalls++;
    return Result.success(_collabPage<CollabListing>([]));
  }

  @override
  Future<Result<CollabPage<CollabApplication>>> getIncomingApplications(
    String listingId, {
    CollabApplicationStatus? status,
    int page = 0,
    int size = 20,
  }) => incoming.future;
}

CollabPage<T> _collabPage<T>(List<T> items) => CollabPage(
  items: items,
  page: 0,
  size: 20,
  totalElements: items.length,
  totalPages: 1,
  first: true,
  last: true,
);

CollabApplication _application(String id) => CollabApplication(
  id: id,
  version: 0,
  listing: collabListingFixture(id: 'listing', ownedByMe: true),
  applicant: musicianActor,
  phone: '5551234567',
  message: 'Başvuru',
  status: CollabApplicationStatus.pending,
  submittedAt: DateTime.utc(2026, 9, 27),
  statusChangedAt: DateTime.utc(2026, 9, 27),
);

class _OverthinkingRepository extends Fake implements OverthinkingRepository {
  _OverthinkingRepository({required this.pendingTab});
  final int pendingTab;
  final requests = Completer<Result<Page<OverthinkingRevealRequest>>>();

  @override
  Future<Result<Page<OverthinkingPost>>> getMyPosts({
    int page = 0,
    int size = 20,
  }) async => const Result.success(Page(items: [], hasNext: false));

  @override
  Future<Result<Page<OverthinkingRevealRequest>>> getIncomingRevealRequests({
    int page = 0,
    int size = 20,
  }) async => pendingTab == 1
      ? await requests.future
      : const Result.success(Page(items: [], hasNext: false));

  @override
  Future<Result<Page<OverthinkingRevealRequest>>> getSentRevealRequests({
    int page = 0,
    int size = 20,
  }) async => pendingTab == 2
      ? await requests.future
      : const Result.success(Page(items: [], hasNext: false));

  @override
  Future<Result<OverthinkingIncomingUnreadStatus>>
  getIncomingUnreadStatus() async => const Result.success(
    OverthinkingIncomingUnreadStatus(hasUnread: false, revision: 0),
  );

  @override
  Future<Result<OverthinkingIncomingUnreadStatus>> markIncomingRequestsSeen({
    required int revision,
  }) => getIncomingUnreadStatus();
}

class _TableRepository extends Fake implements TableGroupRepository {
  final page = Completer<Result<Page<TableGroup>>>();

  @override
  Future<Result<Page<TableGroup>>> listActiveTableGroups({
    required String? cityId,
    String? districtId,
    String? neighborhoodId,
    int page = 0,
    int size = 20,
  }) => this.page.future;
}

class _Locations extends Fake implements LocationRepository {
  @override
  Future<Result<List<City>>> getCities() async => const Result.success([]);
}

class _Instruments extends Fake implements InstrumentRepository {
  @override
  Future<Result<List<Instrument>>> getAll() async => const Result.success([]);
}

class _EmptyTokenStore extends Fake implements TokenStore {
  @override
  Future<String?> readToken() async => null;
}

class _NoopDmRepository extends Fake implements DmRepository {}
