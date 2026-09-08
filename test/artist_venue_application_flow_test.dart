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
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/artist_venue_application.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/musician_profile.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/band_repository.dart';
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

class _Applications extends Fake implements ArtistVenueConnectionRepository {
  final connectionFilters = <bool>[];
  Result<List<ArtistVenueApplication>> readResult = Result.success([
    _application(),
  ]);
  Result<void> actionResult = const Result.success(null);
  Completer<Result<void>>? pendingAction;
  int reads = 0;
  final actions = <(String, String?)>[];
  final pageRequests =
      <(int, ArtistVenueApplicationTarget, String, bool, String?)>[];
  Future<Result<ArtistVenueApplicationPage>> Function(int)? onPageRead;
  @override
  Future<Result<ArtistVenueApplicationPage>> listApplicationPage({
    required ArtistVenueApplicationTarget target,
    required String targetId,
    required bool incoming,
    bool connectionsOnly = false,
    int page = 0,
    int size = 20,
    String? expectedSessionKey,
  }) async {
    reads++;
    connectionFilters.add(connectionsOnly);
    pageRequests.add((page, target, targetId, incoming, expectedSessionKey));
    if (onPageRead != null) return onPageRead!(page);
    if (!readResult.isSuccess) return Result.failure(readResult.error);
    final items = readResult.data!;
    return Result.success(
      ArtistVenueApplicationPage(
        items: items,
        page: page,
        size: size,
        totalElements: items.length,
        totalPages: items.isEmpty ? 0 : 1,
        last: true,
      ),
    );
  }

  @override
  Future<Result<void>> acceptRequest(
    String requestId, {
    String? expectedSessionKey,
  }) async {
    actions.add((requestId, expectedSessionKey));
    return pendingAction?.future ?? actionResult;
  }

  @override
  Future<Result<void>> rejectRequest(
    String requestId, {
    String? expectedSessionKey,
  }) => acceptRequest(requestId, expectedSessionKey: expectedSessionKey);

  @override
  Future<Result<void>> disconnect(
    String requestId, {
    String? expectedSessionKey,
  }) => acceptRequest(requestId, expectedSessionKey: expectedSessionKey);
}

class _Profiles extends Fake implements MusicianProfileRepository {}

class _Directory extends Fake implements VenueDirectoryRepository {
  int reads = 0;
  @override
  Future<Result<List<VenueOption>>> getAllVenues() async {
    reads++;
    return const Result.success([]);
  }
}

class _Api extends Fake implements ApiClient {
  final contexts = <String?>[];
  final methods = <ApiHttpMethod>[];
  @override
  Future<T> request<T>(
    ApiHttpMethod method,
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    T Function(Object? json)? decoder,
    ApiRequestContext? requestContext,
  }) async {
    contexts.add(requestContext?.expectedSessionKey);
    methods.add(method);
    return decoder!(null);
  }
}

const _musician = MusicianProfile(
  id: 'musician',
  userId: 'account',
  username: 'Artist',
  stageName: 'Artist',
  bio: null,
  profilePicture: null,
  instagramUrl: null,
  youtubeUrl: null,
  soundcloudUrl: null,
  spotifyEmbedUrl: null,
  spotifyArtistId: null,
  spotifyTrackIds: [],
  spotifyTracks: [],
  instruments: [],
  activeVenues: [],
  bands: [],
);
