import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/di/service_locator.dart';
import 'package:soundconnect_23_12_25codx/core/error/app_error.dart';
import 'package:soundconnect_23_12_25codx/core/error/result.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/event_performer_request.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/event_profile_publication.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/event_profile_publication_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/musician_calendar_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/event_profile_publications_screen.dart';
import 'package:soundconnect_23_12_25codx/shared/theme/app_theme.dart';

void main() {
  late _Calendar calendar;
  late _Publications publications;

  setUp(() async {
    await serviceLocator.reset();
    calendar = _Calendar();
    publications = _Publications();
    serviceLocator.registerSingleton<MusicianCalendarRepository>(calendar);
  });
  tearDown(() async {
    await calendar.dispose();
    await serviceLocator.reset();
  });

  for (final type in EventPerformerTargetType.values) {
    testWidgets('$type invalidation refreshes a covered management page', (
      tester,
    ) async {
      publications.type = type;
      await _mount(tester, publications, type: type);
      final screen = find.byType(EventProfilePublicationsScreen);
      final state = tester.state(screen);
      final navigator = Navigator.of(tester.element(screen));
      unawaited(
        navigator.push(
          MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Text('Nested group profile')),
          ),
        ),
      );
      await tester.pumpAndSettle();

      publications.items = [];
      calendar.invalidate();
      await tester.pumpAndSettle();
      expect(publications.reads, hasLength(2));
      expect(
        find.byKey(const Key('publication-event'), skipOffstage: false),
        findsNothing,
      );
      navigator.pop();
      await tester.pumpAndSettle();
      expect(tester.state(screen), same(state));
      expect(find.text('Bu bölümde etkinlik yok.'), findsOneWidget);
      expect(publications.writes, 0);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('a burst of invalidations coalesces into one bounded read', (
    tester,
  ) async {
    await _mount(tester, publications);
    for (var i = 0; i < 10; i++) {
      calendar.invalidate();
    }
    await tester.pumpAndSettle();
    expect(publications.reads, hasLength(2));
    await tester.pump(const Duration(seconds: 2));
    expect(publications.reads, hasLength(2));
  });

  testWidgets('invalidation during a pending read queues one fresh read', (
    tester,
  ) async {
    final initial = Completer<Result<EventProfilePublicationPage>>();
    publications.onRead = (call) => publications.reads.length == 1
        ? initial.future
        : Future.value(Result.success(_page([])));
    await _mount(tester, publications, settle: false);
    calendar.invalidate();
    calendar.invalidate();
    await tester.pump();
    expect(publications.reads, hasLength(1));
    initial.complete(Result.success(_page([_item()])));
    await tester.pumpAndSettle();
    expect(publications.reads, hasLength(2));
    expect(find.byKey(const Key('publication-event')), findsNothing);
    expect(find.text('Bu bölümde etkinlik yok.'), findsOneWidget);
  });

  testWidgets(
    'own mutation invalidation waits for write without losing confirmation',
    (tester) async {
      final write = Completer<Result<EventProfilePublication>>();
      publications.onWrite = () => write.future;
      final busy = <bool>[];
      await _mount(tester, publications, onBusyChanged: busy.add);
      await tester.ensureVisible(
        find.byKey(const Key('toggle-publication-event')),
      );
      await tester.tap(find.byKey(const Key('toggle-publication-event')));
      await tester.pump();
      calendar.invalidate();
      calendar.invalidate();
      await tester.pump();
      expect(publications.reads, hasLength(1));
      expect(publications.writes, 1);
      expect(busy, [true]);

      final updated = _item(visible: false, version: 4);
      publications.items = [updated];
      write.complete(Result.success(updated));
      await tester.pumpAndSettle();
      expect(publications.reads, hasLength(2));
      expect(publications.writes, 1);
      expect(busy, [true, false]);
      expect(find.text('Profilimde göster'), findsOneWidget);
      expect(
        find.text('Etkinlik profilinden gizlendi. Katılım onayın değişmedi.'),
        findsOneWidget,
      );
      await tester.pump(const Duration(seconds: 2));
      expect(publications.reads, hasLength(2));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'write reconciliation consumes queued invalidation without duplicate reads',
    (tester) async {
      final write = Completer<Result<EventProfilePublication>>();
      publications.onWrite = () => write.future;
      await _mount(tester, publications);
      await tester.ensureVisible(
        find.byKey(const Key('toggle-publication-event')),
      );
      await tester.tap(find.byKey(const Key('toggle-publication-event')));
      await tester.pump();
      calendar.invalidate();
      await tester.pump();
      write.complete(
        const Result.failure(
          AppError(code: 'conflict', message: 'Version changed'),
        ),
      );
      await tester.pumpAndSettle();
      expect(publications.reads, hasLength(2));
      expect(publications.writes, 1);
      await tester.pump(const Duration(seconds: 2));
      expect(publications.reads, hasLength(2));
    },
  );

  testWidgets('invalidation resets paging but preserves the selected period', (
    tester,
  ) async {
    publications.onRead = (call) async => Result.success(
      _page(
        [_item(id: '${call.period.name}-${call.page}')],
        page: call.page,
        totalPages: 2,
      ),
    );
    await _mount(tester, publications);
    await tester.tap(find.byKey(const Key('event-period-future')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Sonraki'));
    await tester.tap(find.text('Sonraki'));
    await tester.pumpAndSettle();
    expect(publications.reads.last.page, 1);
    calendar.invalidate();
    await tester.pumpAndSettle();
    expect(publications.reads.last.page, 0);
    expect(
      publications.reads.last.period,
      EventProfilePublicationPeriod.future,
    );
    expect(find.byKey(const Key('publication-future-0')), findsOneWidget);
    expect(find.byKey(const Key('publication-future-1')), findsNothing);
  });

  testWidgets(
    'queued refresh cannot load a previous target under a new session',
    (tester) async {
      final read = Completer<Result<EventProfilePublicationPage>>();
      publications.onRead = (_) => read.future;
      String? session = 'first';
      await _mount(tester, publications, session: () => session, settle: false);
      calendar.invalidate();
      await tester.pump();
      session = 'second';
      read.complete(Result.success(_page([_item()])));
      await tester.pumpAndSettle();
      expect(publications.reads, hasLength(1));
      expect(
        find.text('Oturum değişti. Bu sayfayı yeniden aç.'),
        findsOneWidget,
      );
      calendar.invalidate();
      await tester.pumpAndSettle();
      expect(publications.reads, hasLength(1));
    },
  );

  testWidgets('sign-out discards queued refresh during a write', (
    tester,
  ) async {
    final write = Completer<Result<EventProfilePublication>>();
    publications.onWrite = () => write.future;
    String? session = 'first';
    await _mount(tester, publications, session: () => session);
    await tester.ensureVisible(
      find.byKey(const Key('toggle-publication-event')),
    );
    await tester.tap(find.byKey(const Key('toggle-publication-event')));
    await tester.pump();
    calendar.invalidate();
    await tester.pump();
    session = null;
    write.complete(Result.success(_item(visible: false, version: 4)));
    await tester.pumpAndSettle();
    expect(publications.reads, hasLength(1));
    expect(find.text('Oturum değişti. Bu sayfayı yeniden aç.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'rebinding the target replaces the subscription without duplicate refreshes',
    (tester) async {
      await _mount(tester, publications);
      publications.targetId = 'other-profile';
      publications.items = [_item(targetId: 'other-profile')];
      await _mount(tester, publications, targetId: 'other-profile');
      expect(publications.reads, hasLength(2));
      calendar.invalidate();
      await tester.pumpAndSettle();
      expect(publications.reads, hasLength(3));
      expect(publications.reads.last.id, 'other-profile');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('disposal cancels the subscription and queued refresh', (
    tester,
  ) async {
    await _mount(tester, publications);
    expect(calendar.controller.hasListener, isTrue);
    calendar.invalidate();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    final reads = publications.reads.length;
    expect(calendar.controller.hasListener, isFalse);
    calendar.invalidate();
    await tester.pumpAndSettle();
    expect(publications.reads, hasLength(reads));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'failed invalidation refresh remains retryable without an automatic loop',
    (tester) async {
      await _mount(tester, publications);
      publications.onRead = (_) async =>
          const Result.failure(AppError(code: 'offline', message: 'Offline'));
      calendar.invalidate();
      await tester.pumpAndSettle();
      expect(publications.reads, hasLength(2));
      expect(find.text('Offline'), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
      expect(publications.reads, hasLength(2));
      publications.onRead = null;
      await tester.tap(find.text('Tekrar dene'));
      await tester.pumpAndSettle();
      expect(publications.reads, hasLength(3));
      expect(find.byKey(const Key('publication-event')), findsOneWidget);
    },
  );
}

String _stableSession() => 'session';

Future<void> _mount(
  WidgetTester tester,
  _Publications repository, {
  EventPerformerTargetType type = EventPerformerTargetType.musician,
  String targetId = 'profile',
  String? Function()? session,
  bool settle = true,
  ValueChanged<bool>? onBusyChanged,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.navy,
      home: EventProfilePublicationsScreen(
        targetType: type,
        targetId: targetId,
        repository: repository,
        sessionKeyProvider: session ?? _stableSession,
        showPeriods: true,
        onBusyChanged: onBusyChanged,
      ),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}

EventProfilePublication _item({
  String id = 'event',
  String targetId = 'profile',
  EventPerformerTargetType type = EventPerformerTargetType.musician,
  bool visible = true,
  int version = 3,
}) => EventProfilePublication(
  eventId: id,
  targetType: type,
  targetId: targetId,
  visible: visible,
  version: version,
  eventTitle: 'B-T1',
  eventDate: DateTime(2026, 9, 7),
  startTime: '20:00',
  endTime: '22:00',
  venueId: 'venue',
  venueName: 'soundconnectankara',
  performerName: 'Şahbaz',
);

EventProfilePublicationPage _page(
  List<EventProfilePublication> items, {
  int page = 0,
  int totalPages = 1,
}) => EventProfilePublicationPage(
  items: items,
  page: page,
  size: 20,
  totalElements: totalPages == 1 ? items.length : totalPages * 20,
  totalPages: totalPages == 1 && items.isEmpty ? 0 : totalPages,
  hasNext: page + 1 < totalPages,
);

typedef _Read = ({String id, int page, EventProfilePublicationPeriod period});

class _Publications extends Fake implements EventProfilePublicationRepository {
  final reads = <_Read>[];
  int writes = 0;
  String targetId = 'profile';
  EventPerformerTargetType type = EventPerformerTargetType.musician;
  List<EventProfilePublication>? items;
  Future<Result<EventProfilePublicationPage>> Function(_Read)? onRead;
  Future<Result<EventProfilePublication>> Function()? onWrite;

  @override
  Future<Result<EventProfilePublicationPage>> listMine({
    required EventPerformerTargetType targetType,
    required String targetId,
    EventProfilePublicationPeriod period = EventProfilePublicationPeriod.all,
    int page = 0,
    int size = 20,
  }) async {
    final call = (id: targetId, page: page, period: period);
    reads.add(call);
    if (onRead != null) return onRead!(call);
    return Result.success(
      _page(
        items ?? [_item(type: type, targetId: this.targetId)],
        page: page,
      ),
    );
  }

  @override
  Future<Result<EventProfilePublication>> setVisible({
    required String eventId,
    required EventPerformerTargetType targetType,
    required String targetId,
    required bool visible,
    required int version,
  }) async {
    writes++;
    if (onWrite != null) return onWrite!();
    return Result.success(
      _item(
        visible: visible,
        version: version + 1,
        targetId: targetId,
        type: targetType,
      ),
    );
  }
}

class _Calendar extends Fake implements MusicianCalendarRepository {
  final controller = StreamController<void>.broadcast();
  @override
  Stream<void> get changes => controller.stream;
  @override
  void invalidate() => controller.add(null);
  @override
  Future<void> dispose() => controller.close();
}
