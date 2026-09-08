import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/app/router/app_routes.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session_manager.dart';
import 'package:soundconnect_23_12_25codx/core/di/service_locator.dart';
import 'package:soundconnect_23_12_25codx/core/error/app_error.dart';
import 'package:soundconnect_23_12_25codx/core/error/result.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/venue_artist_directory_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/venue_artists_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/band_profile_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/profile_route_args.dart';
import 'package:soundconnect_23_12_25codx/shared/theme/app_theme.dart';

void main() {
  late _Directory repository;

  setUp(() async {
    await serviceLocator.reset();
    repository = _Directory();
  });
  tearDown(() => serviceLocator.reset());

  Future<void> open(
    WidgetTester tester, {
    double width = 390,
    double height = 844,
    double scale = 1,
    Brightness brightness = Brightness.dark,
    ValueChanged<RouteSettings>? onRoute,
    bool settle = true,
    GlobalKey? boundaryKey,
  }) async {
    tester.view.physicalSize = Size(width, height);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: brightness == Brightness.dark ? AppTheme.navy : AppTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        onGenerateRoute: (settings) {
          onRoute?.call(settings);
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => const Scaffold(body: Text('Profile destination')),
          );
        },
        home: RepaintBoundary(
          key: boundaryKey,
          child: VenueArtistsScreen(
            venueId: 'venue',
            venueName: 'soundconnectankara',
            repository: repository,
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

  testWidgets(
    'initial list is scoped to venue and musicians with page size 20',
    (tester) async {
      repository.respond = (_) => _success([_item('bugrasahin')]);
      await open(tester);
      expect(repository.calls, hasLength(1));
      final call = repository.calls.single;
      expect(call.venueId, 'venue');
      expect(call.kind, VenueArtistKind.musician);
      expect(call.query, isEmpty);
      expect(call.page, 0);
      expect(call.size, 20);
      expect(find.text('bugrasahin'), findsOneWidget);
      expect(find.text('Sanatçılar'), findsOneWidget);
      expect(find.text('Gruplar'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'group tab requests groups separately and replaces musician rows',
    (tester) async {
      repository.respond = (call) => _success([
        _item(
          call.kind == VenueArtistKind.band ? 'Şahbaz' : 'bugrasahin',
          kind: call.kind,
        ),
      ]);
      await open(tester);
      await tester.tap(find.text('Gruplar'));
      await tester.pumpAndSettle();
      expect(repository.calls, hasLength(2));
      expect(repository.calls.last.kind, VenueArtistKind.band);
      expect(repository.calls.last.page, 0);
      expect(find.text('Şahbaz'), findsOneWidget);
      expect(find.text('bugrasahin'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'search waits for debounce, trims input, and keeps the selected type',
    (tester) async {
      repository.respond = (call) => _success([
        _item(call.query.isEmpty ? 'Initial' : call.query, kind: call.kind),
      ]);
      await open(tester);
      await tester.tap(find.text('Gruplar'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '  Şah');
      await tester.pump(const Duration(milliseconds: 150));
      await tester.enterText(find.byType(TextField), '  Şahbaz  ');
      await tester.pump(const Duration(milliseconds: 299));
      expect(repository.calls, hasLength(2));
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pumpAndSettle();
      expect(repository.calls, hasLength(3));
      final call = repository.calls.last;
      expect(call.query, 'Şahbaz');
      expect(call.kind, VenueArtistKind.band);
      expect(call.page, 0);
      expect(call.size, 20);
      expect(find.text('Şahbaz'), findsOneWidget);
    },
  );

  testWidgets(
    'submitting search cancels debounce instead of dispatching twice',
    (tester) async {
      await open(tester);
      await tester.enterText(find.byType(TextField), 'aedrum');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 500));
      expect(repository.calls.map((call) => call.query), ['', 'aedrum']);
    },
  );

  testWidgets(
    'changing tabs cancels the timer and preserves the current query',
    (tester) async {
      await open(tester);
      await tester.enterText(find.byType(TextField), 'sah');
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('Gruplar'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 500));
      expect(repository.calls, hasLength(2));
      expect(repository.calls.last.kind, VenueArtistKind.band);
      expect(repository.calls.last.query, 'sah');
    },
  );

  testWidgets('clearing search reloads the selected category from page zero', (
    tester,
  ) async {
    await open(tester);
    await tester.tap(find.text('Gruplar'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'sah');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Aramayı temizle'));
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    expect(repository.calls.last.kind, VenueArtistKind.band);
    expect(repository.calls.last.query, '');
    expect(repository.calls.last.page, 0);
    expect(find.byTooltip('Aramayı temizle'), findsNothing);
  });

  testWidgets('late musician response cannot replace a newer group selection', (
    tester,
  ) async {
    final oldRead = Completer<Result<VenueArtistDirectoryPage>>();
    repository.respond = (call) => call.kind == VenueArtistKind.musician
        ? oldRead.future
        : _success([_item('Şahbaz', kind: VenueArtistKind.band)]);
    await open(tester, settle: false);
    await tester.tap(find.text('Gruplar'));
    await tester.pumpAndSettle();
    oldRead.complete(_success([_item('Stale musician')]));
    await tester.pumpAndSettle();
    expect(find.text('Şahbaz'), findsOneWidget);
    expect(find.text('Stale musician'), findsNothing);
  });

  testWidgets(
    'late search response cannot replace a newer query or error state',
    (tester) async {
      final oldRead = Completer<Result<VenueArtistDirectoryPage>>();
      repository.respond = (call) => call.query == 'old'
          ? oldRead.future
          : _success([_item(call.query.isEmpty ? 'Initial' : 'New result')]);
      await open(tester);
      await tester.enterText(find.byType(TextField), 'old');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.enterText(find.byType(TextField), 'new');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      oldRead.complete(
        const Result.failure(AppError(code: 'offline', message: 'Old failure')),
      );
      await tester.pumpAndSettle();
      expect(find.text('New result'), findsOneWidget);
      expect(find.textContaining('Liste yüklenemedi'), findsNothing);
      expect(find.textContaining('Old failure'), findsNothing);
    },
  );

  testWidgets('same selected tab does not perform another read', (
    tester,
  ) async {
    await open(tester);
    await tester.tap(find.text('Sanatçılar'));
    await tester.pumpAndSettle();
    expect(repository.calls, hasLength(1));
  });

  testWidgets(
    'page action fetches once, appends 20 rows, and preserves query',
    (tester) async {
      final second = Completer<Result<VenueArtistDirectoryPage>>();
      repository.respond = (call) =>
          call.page == 0 ? _success(_items(0, 20), total: 40) : second.future;
      await open(tester);
      await tester.enterText(find.byType(TextField), 'Musician');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      tester.testTextInput.hide();
      await tester.dragUntilVisible(
        find.text('Daha fazla göster'),
        find.byKey(const Key('venue-artists-list')),
        const Offset(0, -500),
      );
      await tester.tap(find.text('Daha fazla göster'));
      await tester.tap(find.text('Daha fazla göster'));
      await tester.pump();
      expect(repository.calls.map((call) => call.page), [0, 0, 1]);
      expect(repository.calls.last.query, 'Musician');
      expect(repository.calls.every((call) => call.size == 20), isTrue);
      second.complete(_success(_items(20, 20), page: 1, total: 40));
      await tester.pumpAndSettle();
      await tester.dragUntilVisible(
        find.text('Musician 39'),
        find.byKey(const Key('venue-artists-list')),
        const Offset(0, -500),
      );
      expect(find.text('Musician 39'), findsOneWidget);
      expect(find.text('Daha fazla göster'), findsNothing);
    },
  );

  for (final changed in ['total', 'duplicate']) {
    testWidgets(
      '$changed during pagination refreshes the authoritative first page',
      (tester) async {
        var firstPages = 0;
        repository.respond = (call) {
          if (call.page == 0) {
            firstPages++;
            return firstPages == 1
                ? _success(_items(0, 20), total: 40)
                : _success([_item('Current state')]);
          }
          return _success(
            _items(changed == 'duplicate' ? 19 : 20, 20),
            page: 1,
            total: changed == 'total' ? 41 : 40,
          );
        };
        await open(tester);
        await tester.dragUntilVisible(
          find.text('Daha fazla göster'),
          find.byKey(const Key('venue-artists-list')),
          const Offset(0, -500),
        );
        await tester.tap(find.text('Daha fazla göster'));
        await tester.pumpAndSettle();
        expect(repository.calls.map((call) => call.page), [0, 1, 0]);
        expect(find.text('Current state'), findsOneWidget);
        expect(find.text('Musician 19'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'first-page failure is distinct from empty and retry reloads it',
    (tester) async {
      repository.respond = (_) =>
          const Result.failure(AppError(code: 'offline', message: 'Offline'));
      await open(tester);
      expect(
        find.text('Liste yüklenemedi. Yeniden deneyebilirsin.'),
        findsOneWidget,
      );
      expect(find.text('Henüz bağlı bir sanatçı yok.'), findsNothing);
      repository.respond = (_) => _success([_item('Recovered')]);
      await tester.tap(find.text('Yeniden dene'));
      await tester.pumpAndSettle();
      expect(repository.calls.map((call) => call.page), [0, 0]);
      expect(find.text('Recovered'), findsOneWidget);
      expect(find.text('Yeniden dene'), findsNothing);
    },
  );

  testWidgets(
    'append failure retains rows and retry requests the same next page',
    (tester) async {
      var failed = false;
      repository.respond = (call) {
        if (call.page == 0) return _success(_items(0, 20), total: 21);
        if (!failed) {
          failed = true;
          return const Result.failure(
            AppError(code: 'offline', message: 'Offline'),
          );
        }
        return _success(_items(20, 1), page: 1, total: 21);
      };
      await open(tester);
      await tester.dragUntilVisible(
        find.text('Daha fazla göster'),
        find.byKey(const Key('venue-artists-list')),
        const Offset(0, -500),
      );
      await tester.tap(find.text('Daha fazla göster'));
      await tester.pumpAndSettle();
      expect(find.text('Diğer sonuçlar yüklenemedi.'), findsOneWidget);
      expect(find.text('Musician 19'), findsOneWidget);
      await tester.ensureVisible(find.text('Yeniden dene'));
      await tester.drag(
        find.byKey(const Key('venue-artists-list')),
        const Offset(0, -200),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Yeniden dene'));
      await tester.pumpAndSettle();
      expect(repository.calls.map((call) => call.page), [0, 1, 1]);
      expect(find.text('Musician 20'), findsOneWidget);
      expect(find.text('Diğer sonuçlar yüklenemedi.'), findsNothing);
    },
  );

  testWidgets(
    'empty categories and empty search communicate different states',
    (tester) async {
      await open(tester);
      expect(find.text('Henüz bağlı bir sanatçı yok.'), findsOneWidget);
      await tester.tap(find.text('Gruplar'));
      await tester.pumpAndSettle();
      expect(find.text('Henüz bağlı bir grup yok.'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'unknown');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      expect(find.text('Aramana uygun sonuç bulunamadı.'), findsOneWidget);
      expect(find.text('Henüz bağlı bir grup yok.'), findsNothing);
    },
  );

  testWidgets('pull to refresh can refresh an empty category', (tester) async {
    await open(tester);
    repository.respond = (_) => _success([_item('Fresh connection')]);
    await tester.drag(
      find.byKey(const Key('venue-artists-list')),
      const Offset(0, 450),
    );
    await tester.pumpAndSettle();
    expect(repository.calls.map((call) => call.page), [0, 0]);
    expect(find.text('Fresh connection'), findsOneWidget);
  });

  testWidgets('leaving during debounce cancels pending dispatch', (
    tester,
  ) async {
    await open(tester);
    await tester.enterText(find.byType(TextField), 'not sent');
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 500));
    expect(repository.calls, hasLength(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('leaving with an outstanding read discards its completion', (
    tester,
  ) async {
    final read = Completer<Result<VenueArtistDirectoryPage>>();
    repository.respond = (_) => read.future;
    await open(tester, settle: false);
    await tester.pumpWidget(const SizedBox());
    read.complete(_success([_item('Too late')]));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'account change clears prior rows and rejects their late response',
    (tester) async {
      final sessions = _Sessions();
      serviceLocator.registerSingleton<AuthSessionManager>(sessions);
      final read = Completer<Result<VenueArtistDirectoryPage>>();
      repository.respond = (_) => read.future;
      await open(tester, settle: false);
      expect(repository.calls.single.expectedSessionKey, 'viewer');
      sessions.change('replacement');
      await tester.pumpAndSettle();
      read.complete(_success([_item('Old account result')]));
      await tester.pumpAndSettle();
      expect(find.text('Old account result'), findsNothing);
      expect(find.text('Hesabın değişti. Listeyi yeniden aç.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('a stale load-more response cannot append to a new search', (
    tester,
  ) async {
    final append = Completer<Result<VenueArtistDirectoryPage>>();
    repository.respond = (call) {
      if (call.query == 'fresh') return _success([_item('Fresh result')]);
      if (call.page == 0) return _success(_items(0, 20), total: 40);
      return append.future;
    };
    await open(tester);
    await tester.dragUntilVisible(
      find.text('Daha fazla göster'),
      find.byKey(const Key('venue-artists-list')),
      const Offset(0, -500),
    );
    await tester.tap(find.text('Daha fazla göster'));
    await tester.pump();
    await tester.dragUntilVisible(
      find.byType(TextField),
      find.byKey(const Key('venue-artists-list')),
      const Offset(0, 500),
    );
    await tester.enterText(find.byType(TextField), 'fresh');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    append.complete(_success(_items(20, 20), page: 1, total: 40));
    await tester.pumpAndSettle();
    expect(find.text('Fresh result'), findsOneWidget);
    expect(find.text('Musician 20'), findsNothing);
    expect(find.text('Daha fazla göster'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a double profile tap pushes only one route', (tester) async {
    final routes = <RouteSettings>[];
    repository.respond = (_) => _success([_item('Double tap artist')]);
    await open(tester, onRoute: routes.add);
    final card = tester.widget<InkWell>(
      find.byKey(const ValueKey('venue-artist-musician-Double tap artist')),
    );
    card.onTap!();
    card.onTap!();
    await tester.pumpAndSettle();
    expect(routes, hasLength(1));
  });

  for (final replaced in [false, true]) {
    testWidgets(
      'returning from profile reloads connections, replaced=$replaced',
      (tester) async {
        repository.respond = (_) => _success([_item('Disconnect this artist')]);
        await open(tester);
        await tester.tap(find.text('Disconnect this artist'));
        await tester.pumpAndSettle();
        if (replaced) {
          Navigator.of(
            tester.element(find.text('Profile destination')),
          ).pushReplacement<void, void>(
            MaterialPageRoute<void>(
              builder: (_) => const Scaffold(body: Text('Owner destination')),
            ),
          );
          await tester.pumpAndSettle();
        }
        expect(repository.calls, hasLength(1));
        repository.respond = (_) => _success([]);
        Navigator.of(
          tester.element(
            find.text(replaced ? 'Owner destination' : 'Profile destination'),
          ),
        ).pop();
        await tester.pumpAndSettle();
        expect(repository.calls.map((call) => call.page), [0, 0]);
        expect(find.text('Disconnect this artist'), findsNothing);
        expect(find.text('Henüz bağlı bir sanatçı yok.'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'search and empty state fit a 320dp screen at 200% with keyboard',
    (tester) async {
      await open(tester, width: 320, height: 700, scale: 2);
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(tester.view.resetViewInsets);
      await tester.enterText(find.byType(TextField), 'Search');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('landscape search stays scrollable while the keyboard is open', (
    tester,
  ) async {
    await open(tester, width: 640, height: 360, scale: 2);
    tester.view.viewInsets = const FakeViewPadding(bottom: 180);
    addTearDown(tester.view.resetViewInsets);
    await tester.dragUntilVisible(
      find.byType(TextField),
      find.byKey(const Key('venue-artists-list')),
      const Offset(0, -100),
    );
    await tester.enterText(find.byType(TextField), 'Landscape');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    expect(repository.calls.last.query, 'Landscape');
    expect(tester.takeException(), isNull);
  });

  for (final kind in VenueArtistKind.values) {
    testWidgets('${kind.name} uses the existing identity-aware named route', (
      tester,
    ) async {
      RouteSettings? route;
      repository.respond = (call) =>
          _success([_item('Artist name', id: 'artist-id', kind: call.kind)]);
      await open(tester, onRoute: (settings) => route = settings);
      if (kind == VenueArtistKind.band) {
        await tester.tap(find.text('Gruplar'));
        await tester.pumpAndSettle();
      }
      await tester.tap(find.text('Artist name'));
      await tester.pumpAndSettle();
      expect(
        route?.name,
        kind == VenueArtistKind.band
            ? AppRoutes.bandPublicProfile
            : AppRoutes.musicianPublicProfile,
      );
      if (kind == VenueArtistKind.band) {
        expect((route?.arguments as BandProfileScreenArgs).bandId, 'artist-id');
      } else {
        expect((route?.arguments as PublicProfileArgs).profileId, 'artist-id');
      }
      expect(tester.takeException(), isNull);
    });
  }

  for (final brightness in Brightness.values) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('long and short names fit at 320dp, $scale, $brightness', (
        tester,
      ) async {
        repository.respond = (call) => _success([
          _item('A', kind: call.kind),
          _item(
            'Dolu Kadehi Ters Tut ve Çok Uzun Bir Sanatçı veya Grup İsmi',
            kind: call.kind,
          ),
        ]);
        await open(tester, width: 320, scale: scale, brightness: brightness);
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('Gruplar'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('A'), findsOneWidget);
      });
    }
  }

  if (const bool.fromEnvironment('VENUE_ARTISTS_PREVIEW')) {
    testWidgets('active artists visual previews', (tester) async {
      await tester.runAsync(() async {
        const flutterRoot = 'C:/Users/user/development/flutter';
        for (final font in {
          'Roboto':
              '$flutterRoot/engine/src/flutter/txt/third_party/fonts/Roboto-Regular.ttf',
          'MaterialIcons':
              '$flutterRoot/bin/cache/dart-sdk/bin/resources/devtools/assets/fonts/MaterialIcons-Regular.otf',
        }.entries) {
          await (FontLoader(font.key)..addFont(
                File(font.value).readAsBytes().then(ByteData.sublistView),
              ))
              .load();
        }
      });
      repository.respond = (call) => _success([
        for (final name
            in call.kind == VenueArtistKind.band
                ? ['Şahbaz', 'Dolu Kadehi Ters Tut', 'Yüzyüzeyken Konuşuruz']
                : ['bugrasahin', 'aedrum', 'Çok Uzun Bir Sanatçı Adı Soyadı'])
          _item(name, kind: call.kind),
      ]);
      for (final width in [390.0, 320.0]) {
        final boundary = GlobalKey();
        await open(tester, width: width, boundaryKey: boundary);
        if (width == 320) {
          await tester.tap(find.text('Gruplar'));
          await tester.pumpAndSettle();
        }
        final render =
            boundary.currentContext!.findRenderObject()
                as RenderRepaintBoundary;
        await tester.runAsync(() async {
          final snapshot = await render.toImage(pixelRatio: 2);
          try {
            final bytes = await snapshot.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await File(
              'build/venue-artists-preview-${width.toInt()}.png',
            ).writeAsBytes(bytes!.buffer.asUint8List());
          } finally {
            snapshot.dispose();
          }
        });
        expect(tester.takeException(), isNull);
      }
    });
  }
}

class _Read {
  const _Read({
    required this.venueId,
    required this.kind,
    required this.query,
    required this.page,
    required this.size,
    required this.expectedSessionKey,
  });

  final String venueId;
  final VenueArtistKind kind;
  final String query;
  final int page;
  final int size;
  final String? expectedSessionKey;
}

class _Directory implements VenueArtistDirectoryRepository {
  final calls = <_Read>[];
  FutureOr<Result<VenueArtistDirectoryPage>> Function(_Read call)? respond;

  @override
  Future<Result<VenueArtistDirectoryPage>> list({
    required String venueId,
    required VenueArtistKind kind,
    String query = '',
    int page = 0,
    int size = 20,
    String? expectedSessionKey,
  }) async {
    final call = _Read(
      venueId: venueId,
      kind: kind,
      query: query,
      page: page,
      size: size,
      expectedSessionKey: expectedSessionKey,
    );
    calls.add(call);
    return respond?.call(call) ?? _success([]);
  }
}

class _Sessions extends ChangeNotifier implements AuthSessionManager {
  AuthSession _session = _sessionFor('viewer');

  @override
  AuthSession get session => _session;

  void change(String userId) {
    _session = _sessionFor(userId);
    notifyListeners();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

AuthSession _sessionFor(String userId) => AuthSession.authenticated(
  token: 'token-$userId',
  userId: userId,
  username: userId,
  accountStatus: 'ACTIVE',
  roles: const ['ROLE_MUSICIAN'],
  permissions: const [],
  expiresAt: DateTime(2100),
  isAdmin: false,
);

VenueArtistDirectoryItem _item(
  String name, {
  String? id,
  VenueArtistKind kind = VenueArtistKind.musician,
}) => VenueArtistDirectoryItem(id: id ?? name, kind: kind, displayName: name);

List<VenueArtistDirectoryItem> _items(int start, int count) =>
    List.generate(count, (index) => _item('Musician ${start + index}'));

Result<VenueArtistDirectoryPage> _success(
  List<VenueArtistDirectoryItem> items, {
  int page = 0,
  int? total,
  bool? last,
}) {
  final count = total ?? items.length;
  final pages = (count / 20).ceil();
  return Result.success(
    VenueArtistDirectoryPage(
      items: items,
      page: page,
      size: 20,
      totalElements: count,
      totalPages: pages,
      last: last ?? page + 1 >= pages,
    ),
  );
}
