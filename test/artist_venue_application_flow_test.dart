import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soundconnect_23_12_25codx/app/router/app_routes.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session_manager.dart';
import 'package:soundconnect_23_12_25codx/core/di/service_locator.dart';
import 'package:soundconnect_23_12_25codx/core/error/app_error.dart';
import 'package:soundconnect_23_12_25codx/core/error/result.dart';
import 'package:soundconnect_23_12_25codx/core/network/api_client.dart';
import 'package:soundconnect_23_12_25codx/modules/artist_venue/data/artist_venue_connection_repository_impl.dart';
import 'package:soundconnect_23_12_25codx/modules/artist_venue/domain/artist_venue_connection_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/artist_venue/domain/artist_venue_application_page.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/domain/entities/app_notification.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/presentation/cubit/notification_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/presentation/notification_target_read.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/artist_venue_application.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/musician_profile.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/band_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/band_profile.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/venue_directory_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/profile_venue_models.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/navigation/profile_action_session.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/musician_profile_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/band_profile_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/band_management_panel_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/musician_profile_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/venue_management_panel_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/profile_venue_support.dart';
import 'package:soundconnect_23_12_25codx/shared/theme/app_theme.dart';

import 'support/event_invitation_navigation_fakes.dart';

part 'artist_venue_application_flow_test_applications.dart';

void main() {
  late _Applications repository;
  late _Sessions sessions;

  setUp(() async {
    await serviceLocator.reset();
    repository = _Applications();
    sessions = _Sessions();
    serviceLocator.registerSingleton<ArtistVenueConnectionRepository>(
      repository,
    );
    serviceLocator.registerSingleton<MusicianProfileRepository>(_Profiles());
    serviceLocator.registerSingleton<AuthSessionManager>(sessions);
    serviceLocator.registerSingleton<BandRepository>(InvitationBands());
  });
  tearDown(() => serviceLocator.reset());

  test(
    'creation sessions reject an account replacement during an asynchronous selection',
    () async {
      final session = ProfileActionSession(
        roles: const ['VENUE', 'ROLE_VENUE'],
      );
      expect(session.isCurrent, isTrue);
      final selection = Completer<void>();
      Future<bool> currentAfterSelection() async {
        await selection.future;
        return session.isCurrent;
      }

      final stillCurrent = currentAfterSelection();
      sessions.change(_session(user: 'other'));
      selection.complete();
      expect(await stillCurrent, isFalse);
      expect(session.userId, 'account');
    },
  );

  test(
    'every connection creation carries the originating account to transport dispatch',
    () async {
      final api = _Api();
      final repository = ArtistVenueConnectionRepositoryImpl(api);
      await repository.createArtistRequest(
        musicianProfileId: 'musician',
        venueId: 'venue',
        message: '',
        expectedSessionKey: 'account',
      );
      await repository.createBandRequest(
        bandId: 'band',
        venueId: 'venue',
        message: '',
        expectedSessionKey: 'account',
      );
      await repository.createVenueRequest(
        musicianProfileId: 'musician',
        venueId: 'venue',
        message: '',
        expectedSessionKey: 'account',
      );
      await repository.createVenueBandRequest(
        bandId: 'band',
        venueId: 'venue',
        message: '',
        expectedSessionKey: 'account',
      );
      expect(api.contexts, ['account', 'account', 'account', 'account']);
      expect(api.methods, List.filled(4, ApiHttpMethod.post));
    },
  );

  testWidgets(
    'band creation flow stops after an intro confirmation from another account',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      sessions.change(_session(role: 'ROLE_MUSICIAN'));
      final directory = _Directory();
      serviceLocator.registerSingleton<VenueDirectoryRepository>(directory);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.navy,
          home: BandManagementPanelScreen(profile: invitationBand()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Mekan Bağlantıları'));
      await tester.tap(find.text('Mekan Bağlantıları'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('venue-connection-management-create')),
      );
      await tester.pumpAndSettle();
      expect(find.byType(VenueIntroScreen), findsOneWidget);
      sessions.change(_session(user: 'other', role: 'ROLE_MUSICIAN'));
      Navigator.of(tester.element(find.byType(VenueIntroScreen))).pop(true);
      await tester.pumpAndSettle();
      expect(directory.reads, 0);
      expect(repository.actions, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  Future<void> openVenue(
    WidgetTester tester, {
    ApplicationListMode mode = ApplicationListMode.incoming,
    RouteFactory? onGenerateRoute,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.navy,
        onGenerateRoute: onGenerateRoute,
        home: Scaffold(
          body: VenueApplicationsSheet(venueId: 'venue', mode: mode),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final target in [
    (exists: false, offscreen: false),
    (exists: true, offscreen: false),
    (exists: true, offscreen: true),
  ]) {
    final targetExists = target.exists;
    testWidgets(
      target.offscreen
          ? 'exact artist venue request below viewport waits for its visible card'
          : targetExists
          ? 'exact artist venue request present: visible target ACKs once'
          : 'exact target absent: unrelated artist venue request must not ACK notification',
      (tester) async {
        const requestId = 'c0000000-0000-4000-8000-000000000001';
        const unrelatedId = 'c0000000-0000-4000-8000-000000000002';
        const notificationId = 'd0000000-0000-4000-8000-000000000001';
        final visibleId = targetExists ? requestId : unrelatedId;
        final visibleName = targetExists ? 'Requested band' : 'Unrelated band';
        repository.readResult = Result.success([
          if (target.offscreen)
            for (var index = 0; index < 12; index++)
              _application(id: 'other-$index', bandName: 'Other band $index'),
          _application(id: visibleId, bandName: visibleName),
        ]);
        final reads = _ApplicationReadCubit();
        final navigator = GlobalKey<NavigatorState>();
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.binding.setSurfaceSize(const Size(420, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.navy,
            navigatorKey: navigator,
            navigatorObservers: [notificationTargetRouteObserver],
            home: const Scaffold(body: Text('Inbox')),
          ),
        );
        final ticket = NotificationTargetRead(
          notification: const AppNotification(
            id: notificationId,
            recipientId: 'account',
            type: 'ARTIST_VENUE_LINK_APPLICATION_REQUEST',
            title: 'Connection request',
            message: '',
            read: false,
            createdAt: null,
            payload: {
              'module': 'ARTIST_VENUE',
              'action': 'REQUEST_CREATED',
              'requestByType': 'BAND',
              'requestId': requestId,
              'bandId': 'band',
              'venueId': 'venue',
            },
          ),
          cubit: reads,
          sessions: sessions,
        );
        expect(ticket.isCurrent, isTrue);
        expect(reads.ids, isEmpty);
        unawaited(
          navigator.currentState!.push<void>(
            ticket.attach(
              MaterialPageRoute<void>(
                builder: (_) => const Scaffold(
                  body: VenueApplicationsSheet(
                    venueId: 'venue',
                    mode: ApplicationListMode.incoming,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(repository.reads, 1);
        expect(repository.pageRequests.single, (
          0,
          ArtistVenueApplicationTarget.venue,
          'venue',
          true,
          'account',
        ));
        expect(
          repository.readResult.data!.where((item) => item.id == requestId),
          hasLength(targetExists ? 1 : 0),
        );
        expect(find.byType(VenueApplicationsSheet), findsOneWidget);
        expect(find.text('Gelen İstekler'), findsOneWidget);
        expect(
          find.text(visibleName),
          target.offscreen ? findsNothing : findsOneWidget,
        );
        expect(repository.actions, isEmpty);
        expect(tester.takeException(), isNull);
        if (target.offscreen) {
          expect(reads.ids, isEmpty);
          await tester.scrollUntilVisible(find.text(visibleName), 300);
          await tester.pumpAndSettle();
          expect(find.text(visibleName), findsOneWidget);
          expect(repository.reads, 1);
        }
        expect(reads.ids, targetExists ? [notificationId] : isEmpty);
        await tester.pump(const Duration(seconds: 1));
        expect(reads.ids, targetExists ? [notificationId] : isEmpty);
      },
    );
  }

  for (final targetExists in [false, true]) {
    testWidgets(
      'musician artist venue incoming requires the exact request, target=$targetExists',
      (tester) async {
        const requestId = 'e0000000-0000-4000-8000-000000000001';
        const unrelatedId = 'e0000000-0000-4000-8000-000000000002';
        const notificationId = 'f0000000-0000-4000-8000-000000000001';
        sessions.change(_session(role: 'ROLE_MUSICIAN'));
        repository.readResult = Result.success([
          _application(
            type: 'VENUE',
            id: targetExists ? requestId : unrelatedId,
          ),
        ]);
        final reads = _ApplicationReadCubit();
        final ticket = NotificationTargetRead(
          notification: const AppNotification(
            id: notificationId,
            recipientId: 'account',
            type: 'ARTIST_VENUE_LINK_APPLICATION_REQUEST',
            title: 'Venue invitation',
            message: '',
            read: false,
            createdAt: null,
            payload: {
              'module': 'ARTIST_VENUE',
              'action': 'REQUEST_CREATED',
              'requestByType': 'VENUE',
              'requestId': requestId,
              'musicianProfileId': 'musician',
              'venueId': 'venue',
            },
          ),
          cubit: reads,
          sessions: sessions,
        );
        final observer = _ApplicationTicketObserver();
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.navy,
            navigatorObservers: [notificationTargetRouteObserver, observer],
            home: const MusicianManagementPanelScreen(
              musicianProfile: _musician,
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Mekan Bağlantıları'));
        await tester.tap(find.text('Mekan Bağlantıları'));
        await tester.pumpAndSettle();
        // Attach before the actual incoming sheet builds, using the same public
        // ticket operation that the profile's automatic notification hop uses.
        observer.nextTicket = ticket;
        await tester.tap(
          find.byKey(const Key('venue-connection-management-incoming')),
        );
        await tester.pumpAndSettle();

        expect(observer.attached, 1);
        expect(ticket.isCurrent, isTrue);
        expect(repository.reads, 1);
        expect(repository.pageRequests.single, (
          0,
          ArtistVenueApplicationTarget.musician,
          'musician',
          true,
          'account',
        ));
        expect(find.text('Gelen İstekler'), findsOneWidget);
        expect(find.text('Venue'), findsOneWidget);
        expect(repository.actions, isEmpty);
        expect(tester.takeException(), isNull);
        expect(reads.ids, targetExists ? [notificationId] : isEmpty);
      },
    );
  }

  const bandRequestId = 'a0000000-0000-4000-8000-000000000001';
  const bandNotificationId = 'b0000000-0000-4000-8000-000000000001';
  Future<
    ({
      GlobalKey<NavigatorState> navigator,
      _ApplicationReadCubit reads,
      InvitationBands bands,
    })
  >
  openBandNotificationPanel(
    WidgetTester tester, {
    bool automatic = true,
    Future<Result<BandProfile>> Function(String)? read,
  }) async {
    sessions.change(_session(user: 'owner-1', role: 'ROLE_MUSICIAN'));
    final bands = serviceLocator<BandRepository>() as InvitationBands;
    bands.read = read ?? (id) async => Result.success(invitationBand(id: id));
    final reads = _ApplicationReadCubit();
    final navigator = GlobalKey<NavigatorState>();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.navy,
        navigatorKey: navigator,
        navigatorObservers: [notificationTargetRouteObserver],
        home: const Scaffold(body: Text('Inbox')),
      ),
    );
    final ticket = NotificationTargetRead(
      notification: const AppNotification(
        id: bandNotificationId,
        recipientId: 'owner-1',
        type: 'ARTIST_VENUE_LINK_APPLICATION_REQUEST',
        title: 'Venue invitation',
        message: '',
        read: false,
        createdAt: null,
        payload: {
          'module': 'ARTIST_VENUE',
          'action': 'REQUEST_CREATED',
          'requestByType': 'VENUE',
          'requestId': bandRequestId,
          'bandId': 'band',
          'venueId': 'venue',
        },
      ),
      cubit: reads,
      sessions: sessions,
    );
    unawaited(
      navigator.currentState!.push<void>(
        ticket.attach(
          MaterialPageRoute<void>(
            builder: (_) => BandManagementPanelScreen(
              profile: invitationBand(id: 'band'),
              openIncomingVenueApplications: automatic,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    return (navigator: navigator, reads: reads, bands: bands);
  }

  for (final target in [
    (exists: false, offscreen: false),
    (exists: true, offscreen: false),
    (exists: true, offscreen: true),
  ]) {
    testWidgets(
      'band incoming auto-open ACKs only exact visible card: $target',
      (tester) async {
        repository.readResult = Result.success([
          if (target.offscreen)
            for (var index = 0; index < 12; index++)
              _application(type: 'VENUE', id: 'other-$index'),
          _application(
            type: 'VENUE',
            id: target.exists
                ? bandRequestId
                : 'a0000000-0000-4000-8000-000000000002',
          ),
        ]);
        tester.view.physicalSize = const Size(420, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final harness = await openBandNotificationPanel(tester);
        await tester.pumpAndSettle();
        expect(find.text('Gelen İstekler'), findsOneWidget);
        expect(harness.bands.ids, ['band']);
        expect(repository.pageRequests.single, (
          0,
          ArtistVenueApplicationTarget.band,
          'band',
          true,
          'owner-1',
        ));
        if (target.offscreen) {
          expect(harness.reads.ids, isEmpty);
          await tester.scrollUntilVisible(
            find.byKey(const ValueKey('artist-venue-request-$bandRequestId')),
            300,
            scrollable: find.descendant(
              of: find.byType(ListView),
              matching: find.byType(Scrollable),
            ),
          );
          await tester.pumpAndSettle();
          expect(
            MediaQuery.sizeOf(tester.element(find.byType(ListView))),
            const Size(420, 900),
          );
        }
        expect(
          harness.reads.ids,
          target.exists ? [bandNotificationId] : isEmpty,
        );
        harness.navigator.currentState!.pop();
        await tester.pumpAndSettle();
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pumpAndSettle();
        expect(find.text('Gelen İstekler'), findsNothing);
        expect(harness.bands.ids, ['band']);
        expect(repository.reads, 1);
        expect(repository.actions, isEmpty);
        expect(
          harness.reads.ids,
          target.exists ? [bandNotificationId] : isEmpty,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('manual band incoming hop does not inherit a panel read ticket', (
    tester,
  ) async {
    repository.readResult = Result.success([
      _application(type: 'VENUE', id: bandRequestId),
    ]);
    final harness = await openBandNotificationPanel(tester, automatic: false);
    await tester.pumpAndSettle();
    expect(repository.reads, 0);
    await tester.ensureVisible(find.text('Mekan Bağlantıları'));
    await tester.tap(find.text('Mekan Bağlantıları'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('venue-connection-management-incoming')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Gelen İstekler'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('artist-venue-request-$bandRequestId')),
      findsOneWidget,
    );
    expect(repository.reads, 1);
    expect(harness.bands.ids, ['band']);
    expect(harness.reads.ids, isEmpty);
    expect(tester.takeException(), isNull);
  });

  for (final membership in [
    (role: 'MANAGER', status: 'ACTIVE'),
    (role: 'MEMBER', status: 'ACTIVE'),
    (role: 'FOUNDER', status: 'INACTIVE'),
  ]) {
    testWidgets('band auto-open rejects fresh membership $membership', (
      tester,
    ) async {
      final harness = await openBandNotificationPanel(
        tester,
        read: (id) async => Result.success(
          invitationBand(
            id: id,
            role: membership.role,
            status: membership.status,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Bu işlem için yetkin yok.'), findsOneWidget);
      expect(find.text('Gelen İstekler'), findsNothing);
      expect(harness.bands.ids, ['band']);
      expect(repository.reads, 0);
      expect(harness.reads.ids, isEmpty);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'band panel fresh result cannot transfer to a replacement account',
    (tester) async {
      final profile = Completer<Result<BandProfile>>();
      final harness = await openBandNotificationPanel(
        tester,
        read: (_) => profile.future,
      );
      await tester.pumpAndSettle();
      expect(repository.reads, 0);
      sessions.change(_session(user: 'other', role: 'ROLE_MUSICIAN'));
      profile.complete(Result.success(invitationBand(id: 'band')));
      await tester.pumpAndSettle();
      expect(find.text('Gelen İstekler'), findsNothing);
      expect(harness.bands.ids, ['band']);
      expect(repository.reads, 0);
      expect(harness.reads.ids, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  for (final hiddenBy in ['route', 'background']) {
    testWidgets(
      'band auto-open waits for $hiddenBy return without refetching',
      (tester) async {
        repository.readResult = Result.success([
          _application(type: 'VENUE', id: bandRequestId),
        ]);
        final profile = Completer<Result<BandProfile>>();
        final harness = await openBandNotificationPanel(
          tester,
          read: (_) => profile.future,
        );
        await tester.pumpAndSettle();
        if (hiddenBy == 'route') {
          unawaited(
            harness.navigator.currentState!.push<void>(
              MaterialPageRoute<void>(
                builder: (_) => const Scaffold(body: Text('Cover')),
              ),
            ),
          );
          await tester.pumpAndSettle();
        } else {
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.paused,
          );
        }
        profile.complete(Result.success(invitationBand(id: 'band')));
        await tester.pumpAndSettle();
        expect(repository.reads, 0);
        expect(harness.reads.ids, isEmpty);
        if (hiddenBy == 'route') {
          harness.navigator.currentState!.pop();
        } else {
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.resumed,
          );
        }
        await tester.pumpAndSettle();
        expect(find.text('Gelen İstekler'), findsOneWidget);
        expect(harness.bands.ids, ['band']);
        expect(repository.reads, 1);
        expect(harness.reads.ids, [bandNotificationId]);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('venue application read failure is visible, not an empty list', (
    tester,
  ) async {
    repository.readResult = const Result.failure(
      AppError(code: 'offline', message: 'Offline'),
    );
    await openVenue(tester);
    expect(find.textContaining('Offline'), findsOneWidget);
    expect(find.text('Gelen istek bulunmuyor.'), findsNothing);
  });

  for (final action in ['Onayla', 'Reddet']) {
    testWidgets(
      'failed venue $action keeps the request and reports the error',
      (tester) async {
        repository.actionResult = const Result.failure(
          AppError(code: 'denied', message: 'Denied'),
        );
        await openVenue(tester);
        await tester.tap(find.text(action));
        await tester.pumpAndSettle();
        expect(repository.actions, hasLength(1));
        expect(repository.actions.single.$2, 'account');
        expect(find.textContaining('Denied'), findsOneWidget);
        expect(find.text('Beklemede'), findsOneWidget);
        expect(repository.reads, 1);
      },
    );
  }

  testWidgets('successful decision reloads authoritative application state', (
    tester,
  ) async {
    await openVenue(tester);
    repository.readResult = Result.success([_application(status: 'ACCEPTED')]);
    await tester.tap(find.text('Onayla'));
    await tester.pumpAndSettle();
    expect(repository.reads, 2);
    expect(find.text('Onaylandı'), findsOneWidget);
    expect(find.text('Onayla'), findsNothing);
  });

  testWidgets(
    'venue-originated invitation to a band preserves band identity and navigation',
    (tester) async {
      repository.readResult = Result.success([_application(type: 'VENUE')]);
      RouteSettings? opened;
      await openVenue(
        tester,
        mode: ApplicationListMode.outgoing,
        onGenerateRoute: (settings) {
          opened = settings;
          return MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Text('Band destination')),
          );
        },
      );
      expect(find.text('Sahbaz'), findsOneWidget);
      expect(find.text('Sanatçı'), findsNothing);
      await tester.tap(find.text('Sahbaz'));
      await tester.pumpAndSettle();
      expect(opened?.name, AppRoutes.bandPublicProfile);
      expect((opened?.arguments as BandProfileScreenArgs).bandId, 'band');
    },
  );

  testWidgets(
    'account switch clears applications and drops an in-flight decision result',
    (tester) async {
      await openVenue(tester);
      repository.pendingAction = Completer<Result<void>>();
      await tester.tap(find.text('Onayla'));
      await tester.pump();
      sessions.change(_session(user: 'other'));
      await tester.pump();
      repository.pendingAction!.complete(const Result.success(null));
      await tester.pumpAndSettle();
      expect(
        find.text('Hesabın değişti. İstekleri yeniden aç.'),
        findsOneWidget,
      );
      expect(find.text('Sahbaz'), findsNothing);
      expect(find.text('Başvuru onaylandı.'), findsNothing);
      expect(repository.reads, 1);
    },
  );

  testWidgets('guest cannot load or act on venue applications', (tester) async {
    sessions.change(const AuthSession.guest());
    await openVenue(tester);
    expect(repository.reads, 0);
    expect(find.text('Onayla'), findsNothing);
  });

  testWidgets(
    'decision made on another device reloads the stale pending card',
    (tester) async {
      await openVenue(tester);
      repository.actionResult = const Result.failure(
        AppError(code: '1503', message: 'Already rejected'),
      );
      repository.readResult = Result.success([
        _application(status: 'REJECTED'),
      ]);
      await tester.tap(find.text('Onayla'));
      await tester.pumpAndSettle();
      expect(repository.reads, 2);
      expect(find.text('Onayla'), findsNothing);
      expect(find.text('Reddedildi'), findsOneWidget);
      expect(find.textContaining('Already rejected'), findsOneWidget);
    },
  );

  testWidgets('permission loss on a decision clears private rows and retry', (
    tester,
  ) async {
    await openVenue(tester);
    repository.actionResult = const Result.failure(
      AppError(code: '1102', message: 'Access removed'),
    );
    await tester.tap(find.text('Onayla'));
    await tester.pumpAndSettle();
    expect(find.text('Sahbaz'), findsNothing);
    expect(find.text('Yeniden dene'), findsNothing);
    expect(find.byType(ListView), findsNothing);
  });

  testWidgets(
    'permission loss on a later page clears previously visible private rows',
    (tester) async {
      repository.onPageRead = (page) async => page == 0
          ? Result.success(_applicationPage())
          : const Result.failure(
              AppError(code: '1102', message: 'Access removed'),
            );
      await openVenue(tester);
      await tester.tap(find.text('Daha fazla göster'));
      await tester.pumpAndSettle();
      expect(find.byType(ListView), findsNothing);
      expect(find.text('Yeniden dene'), findsNothing);
      expect(find.text('Daha fazla göster'), findsNothing);
      expect(find.text('Access removed'), findsOneWidget);
    },
  );

  testWidgets(
    'musician failed decision displays failure and retains its pending request',
    (tester) async {
      sessions.change(_session(role: 'ROLE_MUSICIAN'));
      repository.readResult = Result.success([_application(type: 'VENUE')]);
      repository.actionResult = const Result.failure(
        AppError(code: 'denied', message: 'Denied'),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.navy,
          home: const MusicianManagementPanelScreen(musicianProfile: _musician),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Mekan Bağlantıları'));
      await tester.tap(find.text('Mekan Bağlantıları'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('venue-connection-management-incoming')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Onayla'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Denied'), findsOneWidget);
      expect(find.text('Beklemede'), findsOneWidget);
      expect(repository.actions.single.$2, 'account');
      expect(repository.reads, 1);
    },
  );

  test(
    'connection decisions preserve the originating account at transport dispatch',
    () async {
      final api = _Api();
      final repository = ArtistVenueConnectionRepositoryImpl(api);
      await repository.acceptRequest('request', expectedSessionKey: 'account');
      await repository.rejectRequest('request', expectedSessionKey: 'account');
      await repository.cancelRequest('request', expectedSessionKey: 'account');
      await repository.disconnect('request', expectedSessionKey: 'account');
      expect(api.contexts, ['account', 'account', 'account', 'account']);
      expect(api.methods, [
        ApiHttpMethod.post,
        ApiHttpMethod.post,
        ApiHttpMethod.post,
        ApiHttpMethod.delete,
      ]);
    },
  );

  int itemCount(WidgetTester tester) =>
      (tester
              .widget<ListView>(find.byType(ListView))
              .childrenDelegate
              .estimatedChildCount! +
          1) ~/
      2;

  testWidgets('load-more is serialized and requests the next scoped page', (
    tester,
  ) async {
    final next = Completer<Result<ArtistVenueApplicationPage>>();
    repository.onPageRead = (page) async =>
        page == 0 ? Result.success(_applicationPage()) : next.future;
    await openVenue(tester);
    final button = tester.widget<TextButton>(
      find.widgetWithText(TextButton, 'Daha fazla göster'),
    );
    button.onPressed!();
    button.onPressed!();
    await tester.pump();
    expect(repository.pageRequests.map((request) => request.$1), [0, 1]);
    next.complete(Result.success(_applicationPage(page: 1)));
    await tester.pumpAndSettle();
    expect(itemCount(tester), 40);
    expect(find.text('Daha fazla göster'), findsNothing);
    expect(repository.pageRequests.last, (
      1,
      ArtistVenueApplicationTarget.venue,
      'venue',
      true,
      'account',
    ));
  });

  testWidgets(
    'later-page failure preserves loaded rows and retries the failed page',
    (tester) async {
      var failNext = true;
      repository.onPageRead = (page) async => page == 1 && failNext
          ? const Result.failure(AppError(code: 'offline', message: 'Offline'))
          : Result.success(_applicationPage(page: page));
      await openVenue(tester);
      await tester.tap(find.text('Daha fazla göster'));
      await tester.pumpAndSettle();
      expect(itemCount(tester), 20);
      expect(find.textContaining('Offline'), findsOneWidget);
      failNext = false;
      await tester.tap(find.text('Yeniden dene'));
      await tester.pumpAndSettle();
      expect(itemCount(tester), 40);
      expect(repository.pageRequests.map((request) => request.$1), [0, 1, 1]);
    },
  );

  testWidgets('first-page failure has a working retry', (tester) async {
    repository.onPageRead = (_) async =>
        const Result.failure(AppError(code: 'offline', message: 'Offline'));
    await openVenue(tester);
    repository.onPageRead = (_) async => Result.success(_applicationPage());
    await tester.tap(find.text('Yeniden dene'));
    await tester.pumpAndSettle();
    expect(itemCount(tester), 20);
    expect(repository.pageRequests.map((request) => request.$1), [0, 0]);
  });

  testWidgets(
    'overlapping offset page reloads page zero to avoid duplicate and missing rows',
    (tester) async {
      repository.onPageRead = (page) async {
        if (page == 1) {
          return Result.success(_applicationPage(page: 1, start: 19));
        }
        return Result.success(
          _applicationPage(start: repository.reads > 1 ? 100 : 0),
        );
      };
      await openVenue(tester);
      await tester.tap(find.text('Daha fazla göster'));
      await tester.pumpAndSettle();
      expect(repository.pageRequests.map((request) => request.$1), [0, 1, 0]);
      expect(itemCount(tester), 20);
      expect(find.text('Band 100'), findsOneWidget);
      expect(find.text('Band 0'), findsNothing);
    },
  );

  testWidgets(
    'changed total during paging resets to an authoritative first page',
    (tester) async {
      repository.onPageRead = (page) async => Result.success(
        _applicationPage(page: page, total: repository.reads > 1 ? 41 : 40),
      );
      await openVenue(tester);
      await tester.tap(find.text('Daha fazla göster'));
      await tester.pumpAndSettle();
      expect(repository.pageRequests.map((request) => request.$1), [0, 1, 0]);
      expect(itemCount(tester), 20);
      expect(find.text('Daha fazla göster'), findsOneWidget);
    },
  );

  testWidgets('refresh supersedes an older in-flight pagination response', (
    tester,
  ) async {
    final next = Completer<Result<ArtistVenueApplicationPage>>();
    repository.onPageRead = (page) async => page == 1
        ? next.future
        : Result.success(
            _applicationPage(start: repository.reads > 1 ? 100 : 0),
          );
    await openVenue(tester);
    await tester.tap(find.text('Daha fazla göster'));
    await tester.pump();
    await tester
        .widget<RefreshIndicator>(find.byType(RefreshIndicator))
        .onRefresh();
    await tester.pump();
    next.complete(Result.success(_applicationPage(page: 1)));
    await tester.pumpAndSettle();
    expect(itemCount(tester), 20);
    expect(find.text('Band 100'), findsOneWidget);
    expect(repository.pageRequests.map((request) => request.$1), [0, 1, 0]);
  });

  testWidgets(
    'account switch discards pending pagination and removes retry actions',
    (tester) async {
      final next = Completer<Result<ArtistVenueApplicationPage>>();
      repository.onPageRead = (page) async =>
          page == 0 ? Result.success(_applicationPage()) : next.future;
      await openVenue(tester);
      await tester.tap(find.text('Daha fazla göster'));
      await tester.pump();
      sessions.change(_session(user: 'other'));
      next.complete(Result.success(_applicationPage(page: 1)));
      await tester.pumpAndSettle();
      expect(
        find.text('Hesabın değişti. İstekleri yeniden aç.'),
        findsOneWidget,
      );
      expect(find.byType(ListView), findsNothing);
      expect(find.text('Daha fazla göster'), findsNothing);
      expect(find.text('Yeniden dene'), findsNothing);
    },
  );

  testWidgets('venue connections paginate without losing the accepted filter', (
    tester,
  ) async {
    repository.onPageRead = (page) async =>
        Result.success(_applicationPage(page: page));
    await openVenue(tester, mode: ApplicationListMode.connections);
    expect(find.text('Bağlantılarım'), findsOneWidget);
    expect(find.text('Hello'), findsNothing);
    await tester.tap(find.text('Daha fazla göster'));
    await tester.pumpAndSettle();
    expect(itemCount(tester), 40);
    expect(repository.connectionFilters, [true, true]);
    expect(repository.pageRequests.last.$3, 'venue');
    expect(repository.pageRequests.last.$5, 'account');
  });

  testWidgets('disconnect refreshes the accepted connections list', (
    tester,
  ) async {
    repository.readResult = Result.success([_application(status: 'ACCEPTED')]);
    await openVenue(tester, mode: ApplicationListMode.connections);
    expect(find.text('Bağlı'), findsOneWidget);
    repository.readResult = const Result.success([]);
    await tester.tap(find.text('Bağlantıyı Kaldır'));
    await tester.pumpAndSettle();
    expect(repository.actions, [('request', 'account')]);
    expect(repository.connectionFilters, [true, true]);
    expect(
      find.text('Henüz bağlı olduğun bir sanatçı veya grup yok.'),
      findsOneWidget,
    );
  });

  for (final band in [false, true]) {
    for (final connectionsOnly in [false, true]) {
      testWidgets(
        '${band ? 'band' : 'musician'} requests paginate within their actor and direction, connections=$connectionsOnly',
        (tester) async {
          sessions.change(_session(role: 'ROLE_MUSICIAN'));
          repository.onPageRead = (page) async =>
              Result.success(_applicationPage(page: page));
          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.navy,
              home: band
                  ? BandManagementPanelScreen(profile: invitationBand())
                  : const MusicianManagementPanelScreen(
                      musicianProfile: _musician,
                    ),
            ),
          );
          await tester.pumpAndSettle();
          await tester.ensureVisible(find.text('Mekan Bağlantıları'));
          await tester.tap(find.text('Mekan Bağlantıları'));
          await tester.pumpAndSettle();
          await tester.tap(
            find.byKey(
              Key(
                'venue-connection-management-${connectionsOnly ? 'connections' : 'outgoing'}',
              ),
            ),
          );
          await tester.pumpAndSettle();
          await tester.tap(find.text('Daha fazla göster'));
          await tester.pumpAndSettle();
          expect(itemCount(tester), 40);
          expect(repository.connectionFilters, [
            connectionsOnly,
            connectionsOnly,
          ]);
          expect(repository.pageRequests.last, (
            1,
            band
                ? ArtistVenueApplicationTarget.band
                : ArtistVenueApplicationTarget.musician,
            band ? 'band-1' : 'musician',
            connectionsOnly,
            'account',
          ));
        },
      );
    }
  }
}

ArtistVenueApplication _application({
  String type = 'BAND',
  String status = 'PENDING',
  String id = 'request',
  String bandName = 'Sahbaz',
}) => ArtistVenueApplication(
  id: id,
  musicianProfileId: '',
  bandId: 'band',
  venueId: 'venue',
  musicianStageName: '',
  bandName: bandName,
  bandProfilePictureUrl: null,
  venueProfilePictureUrl: null,
  venueName: 'Venue',
  message: 'Hello',
  status: status,
  requestByType: type,
  createdAt: '2026-09-01',
);

ArtistVenueApplicationPage _applicationPage({
  int page = 0,
  int total = 40,
  int? start,
}) => ArtistVenueApplicationPage(
  items: List.generate((total - page * 20).clamp(0, 20), (index) {
    final number = (start ?? page * 20) + index;
    return _application(
      id: 'request-$number',
      bandName: 'Band $number',
      status: 'ACCEPTED',
    );
  }),
  page: page,
  size: 20,
  totalElements: total,
  totalPages: (total / 20).ceil(),
  last: (page + 1) * 20 >= total,
);

AuthSession _session({String user = 'account', String role = 'ROLE_VENUE'}) =>
    AuthSession.authenticated(
      token: 'token',
      userId: user,
      username: user,
      accountStatus: 'ACTIVE',
      roles: [role],
      permissions: [],
      expiresAt: DateTime.utc(2040),
      isAdmin: false,
    );

class _Sessions extends Fake implements AuthSessionManager {
  AuthSession current = _session();
  final listeners = <VoidCallback>{};
  @override
  AuthSession get session => current;
  @override
  void addListener(VoidCallback listener) => listeners.add(listener);
  @override
  void removeListener(VoidCallback listener) => listeners.remove(listener);
  void change(AuthSession value) {
    current = value;
    for (final listener in List.of(listeners)) {
      listener();
    }
  }
}
