import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/di/service_locator.dart';
import 'package:soundconnect_23_12_25codx/core/error/app_error.dart';
import 'package:soundconnect_23_12_25codx/core/error/result.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/event_performer_request.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/event_profile_publication.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/event_profile_publication_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/event_profile_publications_screen.dart';
import 'package:soundconnect_23_12_25codx/shared/theme/app_theme.dart';
import 'package:soundconnect_23_12_25codx/shared/widgets/event_poster_fallback.dart';
import 'package:soundconnect_23_12_25codx/shared/widgets/gradient_outline_button.dart';

void main() {
  setUp(() => serviceLocator.reset());
  tearDown(() => serviceLocator.reset());

  for (final type in EventPerformerTargetType.values) {
    testWidgets('$type publication periods use scoped server-filtered pages', (
      tester,
    ) async {
      final repository = _Repository()..items = [_item(type: type)];
      await _mount(
        tester,
        repository: repository,
        type: type,
        showPeriods: true,
      );
      expect(find.text('Etkinliklerim'), findsOneWidget);
      expect(find.byType(AppBar), findsOneWidget);
      expect(find.byKey(const Key('publication-event')), findsOneWidget);
      expect(repository.reads.single.type, type);
      expect(repository.reads.single.id, 'profile');
      expect(
        repository.reads.single.period,
        EventProfilePublicationPeriod.current,
      );
      await tester.tap(find.byKey(const Key('event-period-future')));
      await tester.pumpAndSettle();
      expect(
        repository.reads.last.period,
        EventProfilePublicationPeriod.future,
      );
      await tester.tap(find.byKey(const Key('event-period-past')));
      await tester.pumpAndSettle();
      expect(repository.reads.last.period, EventProfilePublicationPeriod.past);
      expect(repository.reads.map((call) => call.page), [0, 0, 0]);
      expect(
        repository.reads.every(
          (call) => call.type == type && call.id == 'profile',
        ),
        isTrue,
      );
      expect(repository.writes, isEmpty);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'period switches including saved callbacks are disabled during publication writes',
    (tester) async {
      final pending = Completer<Result<EventProfilePublication>>();
      final repository = _Repository()..onWrite = (_) => pending.future;
      await _mount(tester, repository: repository, showPeriods: true);
      final stalePeriod = tester
          .widget<TextButton>(find.byKey(const Key('event-period-future')))
          .onPressed!;
      await tester.tap(find.text('Profilimde göster'));
      await tester.pump();
      stalePeriod();
      await tester.pump();
      expect(find.byType(EventProfilePublicationsScreen), findsOneWidget);
      expect(repository.writes, hasLength(1));
      expect(repository.reads, hasLength(1));
      expect(
        tester
            .widget<TextButton>(find.byKey(const Key('event-period-future')))
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<TextButton>(find.byKey(const Key('event-period-past')))
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<GradientOutlineButton>(
              find.byKey(const Key('event-period-current')),
            )
            .onPressed,
        isNull,
      );
      pending.complete(Result.success(_item(visible: true, version: 4)));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('event-period-future')));
      await tester.pumpAndSettle();
      expect(
        repository.reads.last.period,
        EventProfilePublicationPeriod.future,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'period switch discards a pending read from the previous period',
    (tester) async {
      final pending = Completer<Result<EventProfilePublicationPage>>();
      final repository = _Repository()
        ..onRead = (call) =>
            call.period == EventProfilePublicationPeriod.current
            ? pending.future
            : Future.value(Result.success(_page([_item(id: 'future-event')])));
      await _mount(
        tester,
        repository: repository,
        showPeriods: true,
        settle: false,
      );
      await tester.tap(find.byKey(const Key('event-period-future')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('publication-future-event')), findsOneWidget);
      pending.complete(Result.success(_page([_item()])));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('publication-future-event')), findsOneWidget);
      expect(find.byKey(const Key('publication-event')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('publication periods fit narrow screen with large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await _mount(
      tester,
      repository: _Repository(),
      showPeriods: true,
      scale: 2,
    );
    await tester.tap(find.byKey(const Key('event-period-future')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('publication-event')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('changing period resets pagination to the first page', (
    tester,
  ) async {
    final repository = _Repository()
      ..onRead = (call) async => Result.success(
        _page(
          [_item(id: '${call.period.name}-${call.page}')],
          page: call.page,
          totalPages: 2,
          hasNext: call.page == 0,
        ),
      );
    await _mount(tester, repository: repository, showPeriods: true);
    await tester.ensureVisible(find.text('Sonraki'));
    await tester.tap(find.text('Sonraki'));
    await tester.pumpAndSettle();
    expect(repository.reads.last.page, 1);
    await tester.tap(find.byKey(const Key('event-period-future')));
    await tester.pumpAndSettle();
    expect(repository.reads.map((call) => (call.period, call.page)), [
      (EventProfilePublicationPeriod.current, 0),
      (EventProfilePublicationPeriod.current, 1),
      (EventProfilePublicationPeriod.future, 0),
    ]);
    expect(find.byKey(const Key('publication-current-1')), findsNothing);
    expect(find.byKey(const Key('publication-future-0')), findsOneWidget);
  });

  testWidgets(
    'past events are read-only and cannot use a saved visibility action',
    (tester) async {
      final repository = _Repository();
      await _mount(tester, repository: repository, showPeriods: true);
      final staleToggle = _toggle(tester);
      await tester.tap(find.byKey(const Key('event-period-past')));
      await tester.pumpAndSettle();
      expect(find.text('Geçmiş etkinlik'), findsOneWidget);
      expect(find.byKey(const Key('toggle-publication-event')), findsNothing);
      staleToggle();
      await tester.pumpAndSettle();
      expect(repository.writes, isEmpty);
      expect(find.byKey(const Key('publication-event')), findsOneWidget);
    },
  );

  for (final visible in [false, true]) {
    testWidgets(
      'future publication visibility $visible describes scheduled display',
      (tester) async {
        final repository = _Repository()..items = [_item(visible: visible)];
        await _mount(tester, repository: repository, showPeriods: true);
        await tester.tap(find.byKey(const Key('event-period-future')));
        await tester.pumpAndSettle();
        expect(
          find.text(visible ? 'Profilinde gösterilecek' : 'Profilinde gizli'),
          findsOneWidget,
        );
        expect(find.text('Profilinde gösteriliyor'), findsNothing);
        expect(_button(tester).onPressed, isNotNull);
        expect(repository.writes, isEmpty);
      },
    );
  }

  testWidgets(
    'showing a future event confirms its saved preference without claiming current profile display',
    (tester) async {
      final repository = _Repository();
      await _mount(tester, repository: repository, showPeriods: true);
      await tester.tap(find.byKey(const Key('event-period-future')));
      await tester.pumpAndSettle();
      _toggle(tester)();
      await tester.pumpAndSettle();
      expect(repository.writes.single.visible, isTrue);
      expect(
        find.text('Profilinde gösterim tercihin kaydedildi.'),
        findsOneWidget,
      );
      expect(find.text('Profilinde gösterilecek'), findsOneWidget);
      expect(find.text('Etkinlik profilinde gösteriliyor.'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('empty filtered pages preserve next and previous navigation', (
    tester,
  ) async {
    final repository = _Repository()
      ..onRead = (call) async => Result.success(
        EventProfilePublicationPage(
          items: call.page == 2 ? [_item(id: 'later-event')] : const [],
          page: call.page,
          size: 20,
          totalElements: 41,
          totalPages: 3,
          hasNext: call.page < 2,
        ),
      );
    await _mount(tester, repository: repository, showPeriods: true);
    expect(find.text('Bu bölümde etkinlik yok.'), findsOneWidget);
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, 'Önceki'))
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, 'Sonraki'))
          .onPressed,
      isNotNull,
    );
    await tester.tap(find.text('Sonraki'));
    await tester.pumpAndSettle();
    expect(find.text('Bu bölümde etkinlik yok.'), findsOneWidget);
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, 'Önceki'))
          .onPressed,
      isNotNull,
    );
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, 'Sonraki'))
          .onPressed,
      isNotNull,
    );
    await tester.tap(find.text('Sonraki'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('publication-later-event')), findsOneWidget);
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, 'Sonraki'))
          .onPressed,
      isNull,
    );
    await tester.ensureVisible(find.text('Önceki'));
    await tester.tap(find.text('Önceki'));
    await tester.pumpAndSettle();
    expect(find.text('Bu bölümde etkinlik yok.'), findsOneWidget);
    await tester.tap(find.text('Önceki'));
    await tester.pumpAndSettle();
    expect(repository.reads.map((call) => call.page), [0, 1, 2, 1, 0]);
    expect(
      repository.reads.every(
        (call) => call.period == EventProfilePublicationPeriod.current,
      ),
      isTrue,
    );
    expect(repository.writes, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'an empty nonzero final page still allows returning to the preceding page',
    (tester) async {
      final repository = _Repository()
        ..onRead = (call) async => Result.success(
          EventProfilePublicationPage(
            items: call.page == 0 ? [_item()] : const [],
            page: call.page,
            size: 20,
            totalElements: 21,
            totalPages: 2,
            hasNext: call.page == 0,
          ),
        );
      await _mount(tester, repository: repository, showPeriods: true);
      await tester.ensureVisible(find.text('Sonraki'));
      await tester.tap(find.text('Sonraki'));
      await tester.pumpAndSettle();
      expect(find.text('Bu bölümde etkinlik yok.'), findsOneWidget);
      expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, 'Sonraki'))
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, 'Önceki'))
            .onPressed,
        isNotNull,
      );
      await tester.tap(find.text('Önceki'));
      await tester.pumpAndSettle();
      expect(repository.reads.map((call) => call.page), [0, 1, 0]);
      expect(find.byKey(const Key('publication-event')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'a visible past event can still be hidden without allowing re-publication',
    (tester) async {
      final repository = _Repository()..items = [_item(visible: true)];
      await _mount(tester, repository: repository, showPeriods: true);
      await tester.tap(find.byKey(const Key('event-period-past')));
      await tester.pumpAndSettle();
      expect(find.text('Geçmiş etkinlik'), findsOneWidget);
      expect(find.text('Profilimden gizle'), findsOneWidget);
      expect(_button(tester).onPressed, isNotNull);
      _toggle(tester)();
      await tester.pumpAndSettle();
      expect(repository.writes, hasLength(1));
      expect(repository.writes.single.visible, isFalse);
      expect(find.byKey(const Key('toggle-publication-event')), findsNothing);
      expect(find.text('Profilimde göster'), findsNothing);
      expect(find.byKey(const Key('publication-event')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final type in EventPerformerTargetType.values) {
    testWidgets('$type can show and hide an approved event independently', (
      tester,
    ) async {
      final repository = _Repository()..items = [_item(type: type)];
      await _mount(tester, repository: repository, type: type);
      expect(repository.reads.single.type, type);
      expect(repository.reads.single.id, 'profile');
      expect(repository.reads.single.page, 0);
      expect(repository.reads.single.size, 20);
      expect(find.text('Profilinde gizli'), findsOneWidget);
      expect(find.byType(EventPosterFallback), findsOneWidget);
      expect(find.byType(SwitchListTile), findsNothing);

      _toggle(tester)();
      await tester.pumpAndSettle();
      expect(repository.writes, hasLength(1));
      final show = repository.writes.single;
      expect(
        (show.eventId, show.type, show.id, show.visible, show.version),
        ('event', type, 'profile', true, 3),
      );
      expect(find.text('Profilinde gösteriliyor'), findsOneWidget);
      expect(find.text('Etkinlik profilinde gösteriliyor.'), findsOneWidget);

      _toggle(tester)();
      await tester.pumpAndSettle();
      expect(repository.writes, hasLength(2));
      final hide = repository.writes.last;
      expect(
        (hide.eventId, hide.type, hide.id, hide.visible, hide.version),
        ('event', type, 'profile', false, 4),
      );
      expect(find.text('Profilinde gizli'), findsOneWidget);
      expect(repository.reads, hasLength(1));
      expect(tester.takeException(), isNull);
    });
  }

  for (final foreign in [
    _item(id: 'foreign-event', target: 'other-profile'),
    _item(id: 'foreign-event', type: EventPerformerTargetType.band),
  ]) {
    testWidgets(
      'mixed publication list rejects ${foreign.targetType}/${foreign.targetId}',
      (tester) async {
        final repository = _Repository()..items = [_item(), foreign];
        await _mount(tester, repository: repository);
        expect(
          find.text('Etkinliklerin ait olduğu profil doğrulanamadı.'),
          findsOneWidget,
        );
        expect(find.byType(GradientOutlineButton), findsNothing);
        expect(find.byKey(const Key('publication-event')), findsNothing);
        expect(repository.writes, isEmpty);
      },
    );
  }

  testWidgets('list response from a different page is rejected', (
    tester,
  ) async {
    final repository = _Repository()
      ..onRead = (_) async => Result.success(_page([_item()], page: 7));
    await _mount(tester, repository: repository);
    expect(
      find.text('Etkinliklerin ait olduğu profil doğrulanamadı.'),
      findsOneWidget,
    );
    expect(find.byType(GradientOutlineButton), findsNothing);
  });

  testWidgets('refresh remains single flight while a list read is pending', (
    tester,
  ) async {
    final pending = Completer<Result<EventProfilePublicationPage>>();
    final repository = _Repository()..onRead = (_) => pending.future;
    await _mount(tester, repository: repository, settle: false);
    final refresh = tester
        .widget<RefreshIndicator>(find.byType(RefreshIndicator))
        .onRefresh;
    await refresh();
    await refresh();
    expect(repository.reads, hasLength(1));
    pending.complete(Result.success(_page([_item()])));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('publication-event')), findsOneWidget);
    expect(repository.writes, isEmpty);
  });

  testWidgets(
    'pending update is not optimistic and blocks duplicate or different writes and refresh',
    (tester) async {
      final pending = Completer<Result<EventProfilePublication>>();
      final repository = _Repository()
        ..items = [_item(), _item(id: 'second')]
        ..onWrite = (_) => pending.future;
      await _mount(tester, repository: repository);
      final first = _toggle(tester);
      final second = _toggle(tester, id: 'second');
      final refresh = tester
          .widget<RefreshIndicator>(find.byType(RefreshIndicator))
          .onRefresh;
      first();
      first();
      second();
      await refresh();
      await tester.pump();
      expect(repository.writes, hasLength(1));
      expect(repository.reads, hasLength(1));
      expect(find.text('Profilinde gizli'), findsNWidgets(2));
      expect(find.text('Profilinde gösteriliyor'), findsNothing);
      expect(_button(tester).loading, isTrue);
      expect(_button(tester).onPressed, isNull);
      expect(_button(tester, id: 'second').onPressed, isNull);

      pending.complete(Result.success(_item(visible: true, version: 4)));
      await tester.pumpAndSettle();
      expect(find.text('Profilinde gösteriliyor'), findsOneWidget);
      expect(find.text('Profilinde gizli'), findsOneWidget);
      expect(_button(tester, id: 'second').onPressed, isNotNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('saved action cannot replay a stale event version', (
    tester,
  ) async {
    final repository = _Repository();
    await _mount(tester, repository: repository);
    final stale = _toggle(tester);
    stale();
    await tester.pumpAndSettle();
    stale();
    await tester.pumpAndSettle();
    expect(repository.writes, hasLength(1));
    expect(find.text('Profilinde gösteriliyor'), findsOneWidget);
  });

  for (final scopeChange in ['targetId', 'targetType', 'repository']) {
    testWidgets('late read is ignored when $scopeChange changes', (
      tester,
    ) async {
      final pending = Completer<Result<EventProfilePublicationPage>>();
      final repository = _Repository()..onRead = (_) => pending.future;
      final host = await _mount(tester, repository: repository, settle: false);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      final nextType = scopeChange == 'targetType'
          ? EventPerformerTargetType.band
          : EventPerformerTargetType.musician;
      final nextId = scopeChange == 'targetId'
          ? 'different-profile'
          : 'profile';
      final next = _item(id: 'new-event', target: nextId, type: nextType);
      if (scopeChange == 'repository') {
        host.currentState!.change(repository: _Repository()..items = [next]);
      } else {
        repository.onRead = (_) async => Result.success(_page([next]));
        host.currentState!.change(type: nextType, id: nextId);
      }
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('publication-new-event')), findsOneWidget);
      pending.complete(Result.success(_page([_item()])));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('publication-new-event')), findsOneWidget);
      expect(find.byKey(const Key('publication-event')), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('late write is ignored when $scopeChange changes', (
      tester,
    ) async {
      final pending = Completer<Result<EventProfilePublication>>();
      final repository = _Repository()..onWrite = (_) => pending.future;
      final host = await _mount(tester, repository: repository);
      _toggle(tester)();
      await tester.pump();
      final nextType = scopeChange == 'targetType'
          ? EventPerformerTargetType.band
          : EventPerformerTargetType.musician;
      final nextId = scopeChange == 'targetId'
          ? 'different-profile'
          : 'profile';
      final next = _item(id: 'new-event', target: nextId, type: nextType);
      if (scopeChange == 'repository') {
        host.currentState!.change(repository: _Repository()..items = [next]);
      } else {
        repository.items = [next];
        host.currentState!.change(type: nextType, id: nextId);
      }
      await tester.pumpAndSettle();
      pending.complete(Result.success(_item(visible: true, version: 4)));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('publication-new-event')), findsOneWidget);
      expect(find.byKey(const Key('publication-event')), findsNothing);
      expect(find.text('Etkinlik profilinde gösteriliyor.'), findsNothing);
      expect(repository.writes, hasLength(1));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('session changes discard a pending read', (tester) async {
    final pending = Completer<Result<EventProfilePublicationPage>>();
    final repository = _Repository()..onRead = (_) => pending.future;
    final host = await _mount(tester, repository: repository, settle: false);
    host.currentState!.session = 'different-user';
    pending.complete(Result.success(_page([_item()])));
    await tester.pumpAndSettle();
    expect(find.text('Oturum değişti. Bu sayfayı yeniden aç.'), findsOneWidget);
    expect(find.byType(GradientOutlineButton), findsNothing);
    expect(repository.writes, isEmpty);
  });

  for (final session in <String?>['different-user', null]) {
    testWidgets(
      'session replacement $session discards pending mutation feedback',
      (tester) async {
        final pending = Completer<Result<EventProfilePublication>>();
        final repository = _Repository()..onWrite = (_) => pending.future;
        final host = await _mount(tester, repository: repository);
        _toggle(tester)();
        await tester.pump();
        host.currentState!.session = session;
        pending.complete(Result.success(_item(visible: true, version: 4)));
        await tester.pumpAndSettle();
        expect(
          find.text('Oturum değişti. Bu sayfayı yeniden aç.'),
          findsOneWidget,
        );
        expect(find.byType(GradientOutlineButton), findsNothing);
        expect(find.text('Etkinlik profilinde gösteriliyor.'), findsNothing);
        expect(repository.writes, hasLength(1));
      },
    );
  }

  testWidgets(
    'session replacement before tap blocks a stale callback without writing',
    (tester) async {
      final repository = _Repository();
      final host = await _mount(tester, repository: repository);
      final stale = _toggle(tester);
      host.currentState!.session = 'different-user';
      stale();
      await tester.pumpAndSettle();
      expect(repository.writes, isEmpty);
      expect(find.byType(GradientOutlineButton), findsNothing);
    },
  );

  for (final resultKind in [
    'conflict',
    'exception',
    'foreign-target',
    'wrong-event',
    'wrong-value',
    'stale-version',
    'empty-success',
  ]) {
    testWidgets(
      '$resultKind triggers a fresh authoritative read, never an automatic retry',
      (tester) async {
        final repository = _Repository();
        final reload = Completer<Result<EventProfilePublicationPage>>();
        repository.onWrite = (_) async {
          repository.onRead = (_) => reload.future;
          switch (resultKind) {
            case 'conflict':
              return const Result.failure(
                AppError(code: '409', message: 'Güncel durum değişti.'),
              );
            case 'exception':
              throw StateError('Connection closed');
            case 'foreign-target':
              return Result.success(
                _item(target: 'other-profile', visible: true, version: 4),
              );
            case 'wrong-event':
              return Result.success(
                _item(id: 'other-event', visible: true, version: 4),
              );
            case 'wrong-value':
              return Result.success(_item(version: 4));
            case 'stale-version':
              return Result.success(_item(visible: true));
            default:
              return const Result.success(null);
          }
        };
        await _mount(tester, repository: repository);
        _toggle(tester)();
        await tester.pump();
        await tester.pump();
        expect(repository.writes, hasLength(1));
        expect(repository.reads, hasLength(2));
        expect(find.byType(GradientOutlineButton), findsNothing);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        reload.complete(
          Result.success(_page([_item(visible: true, version: 9)])),
        );
        await tester.pumpAndSettle();
        expect(find.text('Profilinde gösteriliyor'), findsOneWidget);
        expect(repository.writes, hasLength(1));
        repository.onWrite = null;
        _toggle(tester)();
        await tester.pumpAndSettle();
        expect(repository.writes, hasLength(2));
        expect(repository.writes.last.version, 9);
        expect(repository.writes.last.visible, isFalse);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('failed list can retry without any visibility write', (
    tester,
  ) async {
    final repository = _Repository()
      ..onRead = (_) async => const Result.failure(
        AppError(code: '503', message: 'Liste alınamadı.'),
      );
    await _mount(tester, repository: repository);
    expect(find.text('Liste alınamadı.'), findsOneWidget);
    repository.onRead = null;
    await tester.tap(find.text('Tekrar dene'));
    await tester.pumpAndSettle();
    expect(repository.reads, hasLength(2));
    expect(repository.writes, isEmpty);
    expect(find.byKey(const Key('publication-event')), findsOneWidget);
  });

  testWidgets('thrown list error hides cards and exposes a retry', (
    tester,
  ) async {
    final repository = _Repository()
      ..onRead = (_) async => throw StateError('Offline');
    await _mount(tester, repository: repository);
    expect(find.text('Etkinlikler alınamadı. Tekrar dene.'), findsOneWidget);
    expect(find.byType(GradientOutlineButton), findsNothing);
    expect(find.text('Tekrar dene'), findsOneWidget);
    expect(repository.writes, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('out-of-range page returns to a fresh first page once', (
    tester,
  ) async {
    final repository = _Repository()
      ..onRead = (call) async => Result.success(
        call.page == 0
            ? _page([_item()], hasNext: true, totalPages: 2)
            : _page(const [], page: 1, totalPages: 1),
      );
    await _mount(tester, repository: repository);
    await tester.ensureVisible(find.text('Sonraki'));
    await tester.tap(find.text('Sonraki'));
    await tester.pumpAndSettle();
    expect(repository.reads.map((call) => call.page), [0, 1, 0]);
    expect(find.byKey(const Key('publication-event')), findsOneWidget);
    expect(repository.writes, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'pagination replaces old cards and uses only current page version',
    (tester) async {
      final repository = _Repository()
        ..onRead = (call) async => Result.success(
          _page(
            [
              _item(
                id: call.page == 0 ? 'first' : 'second',
                version: call.page + 3,
              ),
            ],
            page: call.page,
            hasNext: call.page == 0,
            totalPages: 2,
          ),
        );
      await _mount(tester, repository: repository);
      final staleFirst = _toggle(tester, id: 'first');
      await tester.ensureVisible(find.text('Sonraki'));
      await tester.tap(find.text('Sonraki'));
      await tester.pumpAndSettle();
      expect(repository.reads.map((call) => call.page), [0, 1]);
      expect(find.byKey(const Key('publication-first')), findsNothing);
      expect(find.byKey(const Key('publication-second')), findsOneWidget);
      staleFirst();
      expect(repository.writes, isEmpty);
      _toggle(tester, id: 'second')();
      await tester.pumpAndSettle();
      expect(repository.writes.single.eventId, 'second');
      expect(repository.writes.single.version, 4);
      await tester.ensureVisible(find.text('Önceki'));
      await tester.tap(find.text('Önceki'));
      await tester.pumpAndSettle();
      expect(repository.reads.map((call) => call.page), [0, 1, 0]);
      expect(find.byKey(const Key('publication-first')), findsOneWidget);
    },
  );

  testWidgets('saved pagination callback cannot create duplicate page reads', (
    tester,
  ) async {
    final pending = Completer<Result<EventProfilePublicationPage>>();
    final repository = _Repository()
      ..onRead = (call) async => call.page == 0
          ? Result.success(_page([_item()], hasNext: true, totalPages: 2))
          : pending.future;
    await _mount(tester, repository: repository);
    final next = tester
        .widget<TextButton>(find.widgetWithText(TextButton, 'Sonraki'))
        .onPressed!;
    next();
    next();
    await tester.pump();
    expect(repository.reads.map((call) => call.page), [0, 1]);
    expect(find.byKey(const Key('publication-event')), findsNothing);
    pending.complete(
      Result.success(_page([_item(id: 'second')], page: 1, totalPages: 2)),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('publication-second')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final empty in [false, true]) {
    testWidgets('320dp and 200 percent text is usable, empty=$empty', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(320, 568));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final repository = _Repository()
        ..items = empty
            ? []
            : [_item(title: 'Şahbaz ile Uzun Bir Akustik Performans Gecesi')];
      await _mount(tester, repository: repository, scale: 2);
      if (empty) {
        expect(
          find.textContaining('Henüz yönetebileceğin bir etkinlik yok.'),
          findsOneWidget,
        );
        expect(find.byType(GradientOutlineButton), findsNothing);
      } else {
        await tester.ensureVisible(
          find.byKey(const Key('toggle-publication-event')),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('toggle-publication-event')).hitTestable(),
          findsOneWidget,
        );
        await tester.tap(find.byKey(const Key('toggle-publication-event')));
        await tester.pumpAndSettle();
        expect(repository.writes, hasLength(1));
        expect(find.text('Profilinde gösteriliyor'), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('underlying route cannot mutate while another route is visible', (
    tester,
  ) async {
    final repository = _Repository();
    final host = await _mount(tester, repository: repository);
    final stale = _toggle(tester);
    Navigator.of(host.currentContext!).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('Başka sayfa')),
      ),
    );
    await tester.pumpAndSettle();
    stale();
    await tester.pumpAndSettle();
    expect(repository.writes, isEmpty);
    expect(find.text('Başka sayfa'), findsOneWidget);
  });

  testWidgets('disposed page ignores late responses and saved callbacks', (
    tester,
  ) async {
    final pending = Completer<Result<EventProfilePublication>>();
    final repository = _Repository()..onWrite = (_) => pending.future;
    await _mount(tester, repository: repository);
    final stale = _toggle(tester);
    final refresh = tester
        .widget<RefreshIndicator>(find.byType(RefreshIndicator))
        .onRefresh;
    stale();
    await tester.pump();
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: Text('Başlangıç'))),
    );
    pending.complete(Result.success(_item(visible: true, version: 4)));
    await tester.pumpAndSettle();
    stale();
    await refresh();
    await tester.pumpAndSettle();
    expect(repository.writes, hasLength(1));
    expect(repository.reads, hasLength(1));
    expect(find.text('Başlangıç'), findsOneWidget);
    expect(find.text('Etkinlik profilinde gösteriliyor.'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'settled disposed page ignores stale toggle and refresh callbacks',
    (tester) async {
      final repository = _Repository();
      await _mount(tester, repository: repository);
      final stale = _toggle(tester);
      final refresh = tester
          .widget<RefreshIndicator>(find.byType(RefreshIndicator))
          .onRefresh;
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: Text('Başlangıç'))),
      );
      await tester.pumpAndSettle();
      stale();
      await refresh();
      await tester.pumpAndSettle();
      expect(repository.writes, isEmpty);
      expect(repository.reads, hasLength(1));
      expect(find.text('Başlangıç'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

GradientOutlineButton _button(WidgetTester tester, {String id = 'event'}) =>
    tester.widget<GradientOutlineButton>(
      find.byKey(ValueKey('toggle-publication-$id')),
    );

VoidCallback _toggle(WidgetTester tester, {String id = 'event'}) =>
    _button(tester, id: id).onPressed!;

Future<GlobalKey<_HostState>> _mount(
  WidgetTester tester, {
  required _Repository repository,
  EventPerformerTargetType type = EventPerformerTargetType.musician,
  bool settle = true,
  double scale = 1,
  bool showPeriods = false,
}) async {
  final key = GlobalKey<_HostState>();
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.navy,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: _Host(
        key: key,
        repository: repository,
        type: type,
        showPeriods: showPeriods,
      ),
    ),
  );
  if (settle) await tester.pumpAndSettle();
  return key;
}

class _Host extends StatefulWidget {
  const _Host({
    super.key,
    required this.repository,
    required this.type,
    required this.showPeriods,
  });
  final _Repository repository;
  final EventPerformerTargetType type;
  final bool showPeriods;
  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  late _Repository repository = widget.repository;
  late EventPerformerTargetType type = widget.type;
  String id = 'profile';
  String? session = 'owner';
  String? sessionProvider() => session;
  void change({
    _Repository? repository,
    EventPerformerTargetType? type,
    String? id,
  }) {
    setState(() {
      this.repository = repository ?? this.repository;
      this.type = type ?? this.type;
      this.id = id ?? this.id;
    });
  }

  @override
  Widget build(BuildContext context) => EventProfilePublicationsScreen(
    targetType: type,
    targetId: id,
    repository: repository,
    sessionKeyProvider: sessionProvider,
    showPeriods: widget.showPeriods,
  );
}

class _ReadCall {
  const _ReadCall(this.type, this.id, this.page, this.size, this.period);
  final EventPerformerTargetType type;
  final String id;
  final int page;
  final int size;
  final EventProfilePublicationPeriod period;
}

class _WriteCall {
  const _WriteCall(
    this.eventId,
    this.type,
    this.id,
    this.visible,
    this.version,
  );
  final String eventId;
  final EventPerformerTargetType type;
  final String id;
  final bool visible;
  final int version;
}

class _Repository implements EventProfilePublicationRepository {
  List<EventProfilePublication> items = [_item()];
  final reads = <_ReadCall>[];
  final writes = <_WriteCall>[];
  Future<Result<EventProfilePublicationPage>> Function(_ReadCall)? onRead;
  Future<Result<EventProfilePublication>> Function(_WriteCall)? onWrite;
  @override
  Future<Result<EventProfilePublicationPage>> listMine({
    required EventPerformerTargetType targetType,
    required String targetId,
    EventProfilePublicationPeriod period = EventProfilePublicationPeriod.all,
    int page = 0,
    int size = 20,
  }) {
    final call = _ReadCall(targetType, targetId, page, size, period);
    reads.add(call);
    return onRead?.call(call) ??
        Future.value(Result.success(_page(items, page: page)));
  }

  @override
  Future<Result<EventProfilePublication>> setVisible({
    required String eventId,
    required EventPerformerTargetType targetType,
    required String targetId,
    required bool visible,
    required int version,
  }) {
    final call = _WriteCall(eventId, targetType, targetId, visible, version);
    writes.add(call);
    return onWrite?.call(call) ??
        Future.value(
          Result.success(
            _item(
              id: eventId,
              type: targetType,
              target: targetId,
              visible: visible,
              version: version + 1,
            ),
          ),
        );
  }
}

EventProfilePublicationPage _page(
  List<EventProfilePublication> items, {
  int page = 0,
  bool hasNext = false,
  int totalPages = 1,
}) => EventProfilePublicationPage(
  items: items,
  page: page,
  size: 20,
  totalElements: totalPages > 1 ? 21 : items.length,
  totalPages: totalPages,
  hasNext: hasNext,
);

EventProfilePublication _item({
  String id = 'event',
  EventPerformerTargetType type = EventPerformerTargetType.musician,
  String target = 'profile',
  bool visible = false,
  int version = 3,
  String title = 'Eylül Akşamı',
}) => EventProfilePublication(
  eventId: id,
  targetType: type,
  targetId: target,
  visible: visible,
  version: version,
  eventTitle: title,
  eventDate: DateTime(2026, 9, 23),
  startTime: '20:00:00',
  endTime: '22:00:00',
  venueId: 'venue',
  venueName: 'soundconnectankara',
  performerName: type == EventPerformerTargetType.band
      ? 'Şahbaz'
      : 'bugrasahin',
);
