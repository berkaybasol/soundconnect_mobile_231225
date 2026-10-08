import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session_manager.dart';
import 'package:soundconnect_23_12_25codx/core/di/service_locator.dart';
import 'package:soundconnect_23_12_25codx/core/error/app_error.dart';
import 'package:soundconnect_23_12_25codx/core/error/result.dart';
import 'package:soundconnect_23_12_25codx/modules/engagement/domain/engagement_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/engagement/domain/entities/comment_page.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/venue_event_detail.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/venue_event_item.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/venue_event_management.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/venue_owner_profile.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/venue_public_profile.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/venue_event_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/venue_profile_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/venue_weekly_calendar_editor_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/weekly_event_detail_screen.dart';
import 'package:soundconnect_23_12_25codx/shared/theme/app_theme.dart';
import 'package:soundconnect_23_12_25codx/shared/theme/app_theme_controller.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppThemeController.instance.setVariant(AppThemeVariant.dark);
  });
  tearDown(() => AppThemeController.instance.setVariant(AppThemeVariant.dark));
  setUpAll(() async {
    final font = File('C:/Windows/Fonts/segoeui.ttf');
    if (font.existsSync()) {
      await (FontLoader(
        'Roboto',
      )..addFont(font.readAsBytes().then(ByteData.sublistView))).load();
    }
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });

  for (final variant in AppThemeVariant.values) {
    testWidgets(
      '${variant.name} history controls fit 320px at 200 percent text',
      (tester) async {
        await AppThemeController.instance.setVariant(variant);
        final pending = Completer<Result<VenueEventHistoryPage>>();
        final repository = _HistoryRepository()
          ..historyReply = (_, __) => pending.future;
        await _open(tester, repository, size: const Size(320, 1000), scale: 2);
        expect(
          tester
              .getRect(find.byKey(const Key('venue-management-plans-tab')))
              .top,
          greaterThanOrEqualTo(
            tester
                .getRect(find.byKey(const Key('venue-management-events-tab')))
                .bottom,
          ),
        );
        await _tap(tester, 'venue-events-past', settle: false);
        await tester.ensureVisible(
          find.byKey(const Key('venue-events-history-more')),
        );
        await tester.pump(const Duration(milliseconds: 200));
        expect(find.text('Yükleniyor…'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await _capture(tester, '${variant.name}-loading-320-2x');
        pending.complete(const Result.failure(_historyError));
        await tester.pumpAndSettle();
        await _reveal(
          tester,
          find.byKey(const Key('venue-events-history-retry')),
        );
        expect(find.text('Tekrar dene'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await _capture(tester, '${variant.name}-retry-320-2x');
        repository.historyReply = (_, __) async =>
            _page(['Cuma akşamı akustik konser'], nextCursor: 'next');
        await _tap(tester, 'venue-events-history-retry');
        await _reveal(
          tester,
          find.byKey(const Key('venue-events-history-more')),
        );
        expect(find.text('Daha fazla yükle'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await _capture(tester, '${variant.name}-more-320-2x');
      },
    );

    testWidgets(
      '${variant.name} history displays load more after twenty records',
      (tester) async {
        await AppThemeController.instance.setVariant(variant);
        final repository = _HistoryRepository()
          ..pastCount = 42
          ..historyReply = (_, __) async => _page(
            List.generate(20, (index) => 'Akustik konser ${index + 1}'),
            nextCursor: 'page-2',
          );
        await _open(tester, repository, size: const Size(390, 844));
        await _tap(tester, 'venue-events-past');
        await _capture(tester, '${variant.name}-history-top');
        await _reveal(
          tester,
          find.byKey(const Key('venue-events-history-more')),
        );
        expect(find.text('Akustik konser 20'), findsOneWidget);
        expect(find.text('Daha fazla yükle'), findsOneWidget);
        expect(repository.historyRequests, hasLength(1));
        expect(tester.takeException(), isNull);
        await _capture(tester, '${variant.name}-history-page-20');
      },
    );
  }

  testWidgets(
    'closed history loads no records and displays the overall count',
    (tester) async {
      final repository = _HistoryRepository()
        ..pastCount = 42
        ..historyReply = (_, __) async => _page(
          List.generate(20, (index) => 'Geçmiş ${index + 1}'),
          nextCursor: 'page-2',
        );
      await _open(tester, repository);
      expect(repository.managementCalls, 1);
      expect(repository.historyRequests, isEmpty);
      expect(
        find.descendant(
          of: find.byKey(const Key('venue-events-past')),
          matching: find.text('42'),
        ),
        findsOneWidget,
      );

      await _tap(tester, 'venue-events-past');
      expect(repository.historyRequests, hasLength(1));
      expect(repository.historyRequests.single.venueId, 'venue-id');
      expect(repository.historyRequests.single.asOf, repository.asOf);
      expect(repository.historyRequests.single.cursor, isNull);
      expect(find.text('Geçmiş 1'), findsOneWidget);
      await _reveal(tester, find.byKey(const Key('venue-events-history-more')));
      expect(find.text('Geçmiş 20'), findsOneWidget);
      expect(find.text('Daha fazla yükle'), findsOneWidget);
      expect(repository.historyRequests, hasLength(1));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('load more appends once and prevents duplicate requests', (
    tester,
  ) async {
    final pending = Completer<Result<VenueEventHistoryPage>>();
    final repository = _HistoryRepository()
      ..historyReply = (_, cursor) => cursor == null
          ? Future.value(_page(['İlk kayıt'], nextCursor: 'next-page'))
          : pending.future;
    await _open(tester, repository);
    await _tap(tester, 'venue-events-past');
    final more = find.byKey(const Key('venue-events-history-more'));
    await _reveal(tester, more);
    await tester.tap(more);
    await tester.tap(more);
    await tester.pump();
    expect(repository.historyRequests.map((request) => request.cursor), [
      null,
      'next-page',
    ]);
    expect(find.text('İlk kayıt'), findsOneWidget);
    pending.complete(_page(['İkinci kayıt']));
    await tester.pumpAndSettle();
    expect(find.text('İlk kayıt'), findsOneWidget);
    expect(find.text('İkinci kayıt'), findsOneWidget);
    expect(find.text('Daha fazla yükle'), findsNothing);
    expect(repository.historyRequests, hasLength(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'history cache survives collapse, tab switches and detail return',
    (tester) async {
      final repository = _HistoryRepository()
        ..historyReply = (_, __) async => _page(['Arşiv konseri']);
      await _open(tester, repository);
      await _tap(tester, 'venue-events-past');
      await _tap(tester, 'venue-events-past');
      expect(find.text('Arşiv konseri'), findsNothing);
      await _tap(tester, 'venue-events-past');
      await _tap(tester, 'venue-management-plans-tab');
      expect(find.text('Arşiv konseri'), findsNothing);
      await _tap(tester, 'venue-management-events-tab');
      expect(find.text('Arşiv konseri'), findsOneWidget);

      await tester.tap(find.text('Arşiv konseri'));
      await tester.pumpAndSettle();
      expect(find.byType(WeeklyEventDetailScreen), findsOneWidget);
      Navigator.of(tester.element(find.byType(WeeklyEventDetailScreen))).pop();
      await tester.pumpAndSettle();
      expect(find.text('Arşiv konseri'), findsOneWidget);
      expect(repository.managementCalls, 1);
      expect(repository.historyRequests, hasLength(1));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'first history failure retries the same snapshot without a cursor',
    (tester) async {
      var attempt = 0;
      final repository = _HistoryRepository()
        ..historyReply = (_, __) async => ++attempt == 1
            ? const Result.failure(_historyError)
            : _page(['Kurtarılan kayıt']);
      await _open(tester, repository);
      await _tap(tester, 'venue-events-past');
      expect(find.text(_historyError.message), findsOneWidget);
      await _tap(tester, 'venue-events-history-retry');
      expect(find.text('Kurtarılan kayıt'), findsOneWidget);
      expect(find.text(_historyError.message), findsNothing);
      expect(repository.historyRequests, hasLength(2));
      expect(
        repository.historyRequests.every(
          (request) =>
              request.cursor == null && request.asOf == repository.asOf,
        ),
        isTrue,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'load more failure retains records and retries the failed cursor',
    (tester) async {
      var secondPageAttempts = 0;
      final repository = _HistoryRepository()
        ..historyReply = (_, cursor) async {
          if (cursor == null) {
            return _page(['Korunan kayıt'], nextCursor: 'page-2');
          }
          return ++secondPageAttempts == 1
              ? const Result.failure(_historyError)
              : _page(['Sonraki kayıt']);
        };
      await _open(tester, repository);
      await _tap(tester, 'venue-events-past');
      await _tap(tester, 'venue-events-history-more');
      expect(find.text('Korunan kayıt'), findsOneWidget);
      expect(find.text(_historyError.message), findsOneWidget);
      await _tap(tester, 'venue-events-history-retry');
      expect(find.text('Korunan kayıt'), findsOneWidget);
      expect(find.text('Sonraki kayıt'), findsOneWidget);
      expect(repository.historyRequests.map((request) => request.cursor), [
        null,
        'page-2',
        'page-2',
      ]);
      expect(
        repository.historyRequests.every(
          (request) => request.asOf == repository.asOf,
        ),
        isTrue,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('refresh rejects a late history response from the old snapshot', (
    tester,
  ) async {
    final stale = Completer<Result<VenueEventHistoryPage>>();
    final repository = _HistoryRepository();
    final oldAsOf = repository.asOf;
    repository.historyReply = (asOf, _) =>
        asOf == oldAsOf ? stale.future : Future.value(_page(['Güncel kayıt']));
    await _open(tester, repository);
    await _tap(tester, 'venue-events-past', settle: false);
    expect(repository.historyRequests, hasLength(1));
    repository.asOf = oldAsOf.add(const Duration(minutes: 1));
    await tester.tap(find.byTooltip('Etkinlikleri yenile'));
    await tester.pumpAndSettle();
    expect(find.text('Güncel kayıt'), findsOneWidget);
    stale.complete(_page(['Eski yanıttaki kayıt'], nextCursor: 'stale-next'));
    await tester.pumpAndSettle();
    expect(find.text('Güncel kayıt'), findsOneWidget);
    expect(find.text('Eski yanıttaki kayıt'), findsNothing);
    expect(find.text('Daha fazla yükle'), findsNothing);
    expect(repository.historyRequests.map((request) => request.asOf), [
      oldAsOf,
      repository.asOf,
    ]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed management refresh still invalidates pending history', (
    tester,
  ) async {
    final stale = Completer<Result<VenueEventHistoryPage>>();
    final repository = _HistoryRepository()
      ..historyReply = (_, __) => stale.future;
    await _open(tester, repository);
    await _tap(tester, 'venue-events-past', settle: false);
    repository.managementFailure = const AppError(
      code: 'network',
      message: 'Yönetim yenilenemedi.',
    );
    await tester.tap(find.byTooltip('Etkinlikleri yenile'));
    await tester.pumpAndSettle();
    stale.complete(_page(['Artık geçersiz kayıt']));
    await tester.pumpAndSettle();
    expect(find.text('Artık geçersiz kayıt'), findsNothing);
    expect(find.textContaining('Yönetim yenilenemedi.'), findsOneWidget);
    expect(repository.historyRequests, hasLength(1));

    repository
      ..managementFailure = null
      ..asOf = repository.asOf.add(const Duration(minutes: 1))
      ..historyReply = (_, __) async => _page(['Başarılı yenileme']);
    await tester.tap(find.byTooltip('Etkinlikleri yenile'));
    await tester.pumpAndSettle();
    expect(find.text('Başarılı yenileme'), findsOneWidget);
    expect(find.textContaining('Yönetim yenilenemedi.'), findsNothing);
    expect(repository.historyRequests, hasLength(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'refresh discards a pending next page and keeps the fresh cursor',
    (tester) async {
      final stale = Completer<Result<VenueEventHistoryPage>>();
      final repository = _HistoryRepository();
      final oldAsOf = repository.asOf;
      repository.historyReply = (asOf, cursor) async {
        if (asOf == oldAsOf) {
          return cursor == null
              ? _page(['Eski ilk kayıt'], nextCursor: 'old-page-2')
              : stale.future;
        }
        return cursor == null
            ? _page(['Yeni ilk kayıt'], nextCursor: 'new-page-2')
            : _page(['Yeni ikinci kayıt']);
      };
      await _open(tester, repository);
      await _tap(tester, 'venue-events-past');
      await _tap(tester, 'venue-events-history-more', settle: false);
      repository.asOf = oldAsOf.add(const Duration(minutes: 1));
      await tester.tap(find.byTooltip('Etkinlikleri yenile'));
      await tester.pumpAndSettle();
      stale.complete(_page(['Eski ikinci kayıt'], nextCursor: 'old-page-3'));
      await tester.pumpAndSettle();
      expect(find.text('Eski ilk kayıt'), findsNothing);
      expect(find.text('Eski ikinci kayıt'), findsNothing);
      expect(find.text('Yeni ilk kayıt'), findsOneWidget);
      await _tap(tester, 'venue-events-history-more');
      expect(find.text('Yeni ilk kayıt'), findsOneWidget);
      expect(find.text('Yeni ikinci kayıt'), findsOneWidget);
      expect(repository.historyRequests.map((request) => request.cursor), [
        null,
        'old-page-2',
        null,
        'new-page-2',
      ]);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('empty history shows its empty state without requesting a page', (
    tester,
  ) async {
    final repository = _HistoryRepository()..pastCount = 0;
    await _open(tester, repository);
    await _tap(tester, 'venue-events-past');
    expect(find.text('Henüz geçmiş etkinlik yok.'), findsOneWidget);
    expect(repository.historyRequests, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('session replacement clears cached history immediately', (
    tester,
  ) async {
    final sessions = _Sessions();
    final repository = _HistoryRepository()
      ..historyReply = (_, __) async => _page(['Önceki hesabın özel kaydı']);
    await _open(tester, repository, sessions: sessions);
    await _tap(tester, 'venue-events-past');
    expect(find.text('Önceki hesabın özel kaydı'), findsOneWidget);

    sessions.replaceOwner();
    await tester.pumpAndSettle();
    expect(find.text('Önceki hesabın özel kaydı'), findsNothing);
    expect(
      find.text('Oturum değişti. Etkinlik yönetimini yeniden aç.'),
      findsOneWidget,
    );
    await tester.tap(find.byTooltip('Etkinlikleri yenile'));
    await tester.pumpAndSettle();
    expect(repository.managementCalls, 1);
    expect(repository.historyRequests, hasLength(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('session change dismisses pending deletion and never deletes', (
    tester,
  ) async {
    final sessions = _Sessions();
    final repository = _HistoryRepository()
      ..historyReply = (_, __) async => _page(['Özel geçmiş etkinliği']);
    await _open(tester, repository, sessions: sessions);
    await _tap(tester, 'venue-events-past');
    await tester.tap(find.byTooltip('Etkinlik seçenekleri'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Etkinliği sil'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('venue-event-delete-dialog')), findsOneWidget);
    sessions.signOut();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('venue-event-delete-dialog')), findsNothing);
    expect(find.text('Özel geçmiş etkinliği'), findsNothing);
    expect(repository.deletions, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('resume refreshes management cutoff after background time', (
    tester,
  ) async {
    final repository = _HistoryRepository();
    await _open(tester, repository);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(repository.managementCalls, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'session change clears cached history when a pending page throws',
    (tester) async {
      final pending = Completer<Result<VenueEventHistoryPage>>();
      final sessions = _Sessions();
      final repository = _HistoryRepository()
        ..historyReply = (_, cursor) => cursor == null
            ? Future.value(_page(['Önceki hesabın kaydı'], nextCursor: 'next'))
            : pending.future;
      await _open(tester, repository, sessions: sessions);
      await _tap(tester, 'venue-events-past');
      expect(find.text('Önceki hesabın kaydı'), findsOneWidget);
      await _tap(tester, 'venue-events-history-more', settle: false);
      sessions.signOut();
      pending.completeError(
        StateError('Connection closed after session change'),
      );
      await tester.pumpAndSettle();
      expect(find.text('Önceki hesabın kaydı'), findsNothing);
      expect(find.byKey(const Key('venue-events-history-retry')), findsNothing);
      expect(find.byKey(const Key('venue-events-history-more')), findsNothing);
      expect(repository.historyRequests, hasLength(2));
      expect(tester.takeException(), isNull);
    },
  );
}

const _historyError = AppError(code: 'network', message: 'Geçmiş alınamadı.');

Result<VenueEventHistoryPage> _page(
  List<String> titles, {
  String? nextCursor,
}) => Result.success(
  VenueEventHistoryPage(
    items: [for (final title in titles) _event(title)],
    nextCursor: nextCursor,
    hasNext: nextCursor != null,
  ),
);

VenueOwnerEventItem _event(String title) => VenueOwnerEventItem(
  id: title,
  title: title,
  posterImage: null,
  performerName: 'Sahne sanatçısı',
  musicianProfileId: null,
  performerType: 'MANUAL',
  eventDate: DateTime.now().subtract(const Duration(days: 2)),
  startTime: '20:00',
  endTime: '22:00',
  description: 'Geçmiş etkinliğin açıklaması.',
);

Future<void> _open(
  WidgetTester tester,
  _HistoryRepository repository, {
  Size size = const Size(390, 1500),
  double scale = 1,
  _Sessions? sessions,
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await serviceLocator.reset();
  addTearDown(serviceLocator.reset);
  serviceLocator
    ..registerSingleton<VenueEventRepository>(repository)
    ..registerSingleton<EngagementRepository>(_Comments())
    ..registerSingleton<VenueProfileRepository>(_VenueProfiles());
  if (sessions != null) {
    serviceLocator.registerSingleton<AuthSessionManager>(sessions);
  }
  await tester.pumpWidget(
    RepaintBoundary(
      key: const Key('history-preview'),
      child: MaterialApp(
        theme: AppTheme.current,
        debugShowCheckedModeBanner: false,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: const VenueWeeklyCalendarEditorScreen(ownerProfile: _owner),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _capture(WidgetTester tester, String name) async {
  if (!const bool.fromEnvironment('EVENT_HISTORY_PREVIEW')) return;
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const Key('history-preview')),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final directory = Directory('.local-verification/event-history')
        ..createSync(recursive: true);
      await File(
        '${directory.path}/$name.png',
      ).writeAsBytes(bytes!.buffer.asUint8List());
    } finally {
      image.dispose();
    }
  });
}

Future<void> _reveal(WidgetTester tester, Finder finder) async {
  final scrollable = find.descendant(
    of: find.byKey(const PageStorageKey('venue-management-events-scroll')),
    matching: find.byType(Scrollable),
  );
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(finder, 700, scrollable: scrollable);
  }
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, String key, {bool settle = true}) async {
  final finder = find.byKey(Key(key));
  await _reveal(tester, finder);
  await tester.tap(finder);
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}

typedef _HistoryRequest = ({String venueId, DateTime asOf, String? cursor});

class _HistoryRepository extends Fake implements VenueEventRepository {
  int managementCalls = 0;
  final deletions = <String>[];
  int pastCount = 2;
  DateTime asOf = DateTime.now();
  AppError? managementFailure;
  final historyRequests = <_HistoryRequest>[];
  Future<Result<VenueEventHistoryPage>> Function(DateTime asOf, String? cursor)
  historyReply = (_, __) async => _page([]);

  @override
  Future<Result<VenueEventManagementSnapshot>> loadManagement(
    String venueId,
  ) async {
    managementCalls++;
    if (managementFailure case final error?) return Result.failure(error);
    return Result.success(
      VenueEventManagementSnapshot(
        upcomingEvents: const [],
        pastCount: pastCount,
        historyAsOf: asOf,
      ),
    );
  }

  @override
  Future<Result<void>> delete(String eventId) async {
    deletions.add(eventId);
    return const Result.success(null);
  }

  @override
  Future<Result<VenueEventHistoryPage>> loadHistory(
    String venueId, {
    required DateTime asOf,
    String? cursor,
  }) {
    historyRequests.add((venueId: venueId, asOf: asOf, cursor: cursor));
    return historyReply(asOf, cursor);
  }

  @override
  Future<Result<List<VenueOwnerEventItem>>> listByVenue(String venueId) =>
      throw StateError(
        'Owner management must not load the unbounded event list.',
      );

  @override
  Future<Result<VenueEventDetail>> getDetail(String eventId) async =>
      const Result.failure(
        AppError(code: 'unavailable', message: 'Use route data.'),
      );
}

class _Comments extends Fake implements EngagementRepository {
  @override
  Future<Result<CommentPage>> listComments({
    required String targetType,
    required String targetId,
    int page = 0,
    int size = 20,
  }) async => const Result.success(CommentPage(items: [], totalElements: 0));
}

class _VenueProfiles extends Fake implements VenueProfileRepository {
  @override
  Future<Result<VenuePublicProfile>> getPublicVenueProfile({
    String? venueId,
  }) async => const Result.failure(
    AppError(code: 'unavailable', message: 'Use route data.'),
  );
}

class _Sessions extends ChangeNotifier implements AuthSessionManager {
  AuthSession _session = AuthSession.authenticated(
    token: 'owner-session',
    userId: 'owner-id',
    username: 'owner',
    accountStatus: 'ACTIVE',
    roles: ['ROLE_VENUE'],
    permissions: [],
    expiresAt: DateTime(2100),
    isAdmin: false,
  );

  @override
  AuthSession get session => _session;

  void signOut() {
    _session = const AuthSession.guest();
    notifyListeners();
  }

  void replaceOwner() {
    _session = AuthSession.authenticated(
      token: 'new-owner-session',
      userId: 'owner-id',
      username: 'owner',
      accountStatus: 'ACTIVE',
      roles: ['ROLE_VENUE'],
      permissions: [],
      expiresAt: DateTime(2100),
      isAdmin: false,
    );
    notifyListeners();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _owner = VenueOwnerProfile(
  venueProfileId: 'venue-profile-id',
  venueId: 'venue-id',
  ownerUserId: 'owner-id',
  venueName: 'soundconnectankara',
  bio: null,
  profilePictureUrl: null,
  instagramUrl: null,
  youtubeUrl: null,
  websiteUrl: null,
  address: null,
  phone: null,
  website: null,
  description: null,
  musicStartTime: null,
  cityId: 'city-id',
  cityName: 'Ankara',
  districtId: 'district-id',
  districtName: 'Çankaya',
  neighborhoodId: null,
  neighborhoodName: null,
  status: 'APPROVED',
  activeMusicians: [],
  activeBands: [],
  weeklyEvents: [],
);
