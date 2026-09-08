import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session_manager.dart';
import 'package:soundconnect_23_12_25codx/core/error/app_error.dart';
import 'package:soundconnect_23_12_25codx/core/error/result.dart';
import 'package:soundconnect_23_12_25codx/modules/analytics/domain/venue_analytics_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/analytics/domain/venue_analytics_reporting_config.dart';
import 'package:soundconnect_23_12_25codx/modules/analytics/presentation/widgets/venue_analytics_reporting_scope.dart';
import 'package:soundconnect_23_12_25codx/modules/analytics/presentation/screens/venue_analytics_screen.dart';
import 'package:soundconnect_23_12_25codx/shared/theme/app_theme.dart';
import 'package:soundconnect_23_12_25codx/shared/widgets/gradient_outline_button.dart';

void main() {
  test('reporting build defaults off independently from collection', () {
    expect(VenueAnalyticsReportingConfig.build.enabled, isFalse);
  });

  for (final mode in ['overview', 'event', 'profile-link', 'event-link']) {
    testWidgets('default-off $mode never dispatches private reads', (
      tester,
    ) async {
      final repository = _Repository();
      await _mount(
        tester,
        repository,
        _Sessions(_session()),
        mode: mode,
        reportingConfig: null,
      );
      expect(repository.reads, isEmpty);
      expect(find.byKey(const Key('analytics-open-link')), findsNothing);
      expect(
        find.byKey(const Key('analytics-metric-impressions')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('analytics-reporting-coming-soon')),
        mode.endsWith('-link') ? findsNothing : findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'captured enabled link callback becomes inert when scope closes',
    (tester) async {
      final repository = _Repository();
      final sessions = _Sessions(_session());
      final navigation = _Navigation();
      await _mount(
        tester,
        repository,
        sessions,
        mode: 'profile-link',
        navigation: navigation,
      );
      final callback = _linkCallback(tester);
      await _mount(
        tester,
        repository,
        sessions,
        mode: 'profile-link',
        navigation: navigation,
        reportingConfig: const VenueAnalyticsReportingConfig(enabled: false),
      );
      callback();
      await tester.pumpAndSettle();
      expect(repository.reads, isEmpty);
      expect(navigation.pushed.length, 1);
      expect(find.byKey(const Key('analytics-open-link')), findsNothing);
    },
  );

  testWidgets(
    'closing scope disposes private content and rejects in-flight result',
    (tester) async {
      final pending = Completer<Result<VenueAnalyticsSummary>>();
      final repository = _Repository()..summaryReply = (_) => pending.future;
      final sessions = _Sessions(_session());
      await _mount(tester, repository, sessions, mode: 'event', settle: false);
      expect(repository.reads.length, 1);
      await _mount(
        tester,
        repository,
        sessions,
        mode: 'event',
        reportingConfig: const VenueAnalyticsReportingConfig(enabled: false),
      );
      expect(sessions.listening, isFalse);
      pending.complete(Result.success(_summary(event: 'event')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('analytics-reporting-coming-soon')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('analytics-metric-impressions')),
        findsNothing,
      );
      expect(repository.reads.length, 1);
    },
  );

  for (final mode in ['profile-link', 'event-link']) {
    for (final identity in [
      const AuthSession.guest(),
      _session(user: 'visitor'),
      _session(role: 'ROLE_MUSICIAN'),
      _session(status: 'PASSIVE'),
    ]) {
      testWidgets('$mode is absent for an unauthorized viewer', (tester) async {
        final repository = _Repository();
        await _mount(tester, repository, _Sessions(identity), mode: mode);
        expect(find.byKey(const Key('analytics-open-link')), findsNothing);
        expect(find.text('İstatistikleri gör'), findsNothing);
        expect(repository.reads, isEmpty);
      });
    }

    testWidgets('$mode is compact and defers all reads until one scoped push', (
      tester,
    ) async {
      final repository = _Repository();
      final navigation = _Navigation();
      await _mount(
        tester,
        repository,
        _Sessions(_session()),
        mode: mode,
        navigation: navigation,
      );
      expect(find.text('İstatistikleri gör'), findsOneWidget);
      expect(
        find.byKey(const Key('analytics-metric-profileVisits')),
        findsNothing,
      );
      expect(find.byKey(const Key('analytics-going-soon')), findsNothing);
      expect(find.byKey(const Key('analytics-period-30')), findsNothing);
      expect(find.byTooltip('İstatistikler hakkında'), findsNothing);
      expect(repository.reads, isEmpty);
      final onTap = _linkCallback(tester);
      onTap();
      onTap();
      await tester.pumpAndSettle();
      expect(navigation.pushed.length, 2); // Home plus one analytics route.
      final screen = tester.widget<VenueAnalyticsScreen>(
        find.byType(VenueAnalyticsScreen),
      );
      expect(screen.venueId, 'venue');
      expect(screen.venueName, 'SoundConnect Ankara');
      expect(screen.ownerUserId, 'owner');
      expect(screen.eventId, mode == 'event-link' ? 'event' : isNull);
      expect(
        screen.eventTitle,
        mode == 'event-link' ? 'Canlı müzik akşamı' : isNull,
      );
      expect(repository.reads.length, mode == 'event-link' ? 1 : 2);
      expect(
        repository.reads.first.$1,
        mode == 'event-link' ? 'event' : 'summary',
      );
      expect(
        repository.reads.every((request) => request.$3 == 'owner'),
        isTrue,
      );
      final reads = repository.reads.length;
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('analytics-open-link')), findsOneWidget);
      expect(repository.reads.length, reads);
      await tester.tap(find.byKey(const Key('analytics-open-link')));
      await tester.pumpAndSettle();
      expect(navigation.pushed.length, 3);
      expect(repository.reads.length, reads * 2);
    });

    testWidgets('$mode blocks captured callbacks after account switch', (
      tester,
    ) async {
      final repository = _Repository();
      final sessions = _Sessions(_session());
      final navigation = _Navigation();
      await _mount(
        tester,
        repository,
        sessions,
        mode: mode,
        navigation: navigation,
      );
      final onTap = _linkCallback(tester);
      sessions.replace(_session(user: 'different', token: 'different-token'));
      onTap(); // Before the listener's requested rebuild is painted.
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('analytics-open-link')), findsNothing);
      expect(navigation.pushed.length, 1);
      expect(repository.reads, isEmpty);
      sessions.replace(_session());
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('analytics-open-link')), findsOneWidget);
      expect(repository.reads, isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
      onTap(); // A callback retained by a removed route must stay inert.
      await tester.pump();
      expect(sessions.listening, isFalse);
      expect(repository.reads, isEmpty);
      expect(tester.takeException(), isNull);
    });

    testWidgets('$mode cannot push from a covered source route', (
      tester,
    ) async {
      final repository = _Repository();
      final navigation = _Navigation();
      await _mount(
        tester,
        repository,
        _Sessions(_session()),
        mode: mode,
        navigation: navigation,
      );
      final onTap = _linkCallback(tester);
      unawaited(
        Navigator.of(
          tester.element(find.byKey(const Key('analytics-open-link'))),
        ).push(
          MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Text('Other route')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      onTap();
      await tester.pumpAndSettle();
      expect(navigation.pushed.length, 2);
      expect(repository.reads, isEmpty);
      expect(find.text('Other route'), findsOneWidget);
    });

    testWidgets('$mode remains a semantic 48px target at 320px and 200% text', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      try {
        final repository = _Repository();
        await _mount(
          tester,
          repository,
          _Sessions(_session()),
          mode: mode,
          size: const Size(320, 500),
          scale: 2,
        );
        final link = find.byKey(const Key('analytics-open-link'));
        expect(tester.getSize(link).height, greaterThanOrEqualTo(48));
        expect(tester.getSize(link).width, lessThanOrEqualTo(288));
        final data = tester
            .getSemantics(find.bySemanticsLabel('İstatistikleri gör'))
            .getSemanticsData();
        expect(data.hasFlag(ui.SemanticsFlag.isButton), isTrue);
        expect(data.hasAction(ui.SemanticsAction.tap), isTrue);
        expect(repository.reads, isEmpty);
        expect(tester.takeException(), isNull);
      } finally {
        semantics.dispose();
      }
    });
  }

  for (final mode in ['overview', 'event']) {
    for (final identity in [
      const AuthSession.guest(),
      _session(user: 'visitor'),
      _session(role: 'ROLE_MUSICIAN'),
      _session(status: 'PASSIVE'),
    ]) {
      testWidgets(
        '$mode hides all metrics and makes no reads for ${identity.userId}/${identity.accountStatus}/${identity.roles}',
        (tester) async {
          final repository = _Repository();
          await _mount(tester, repository, _Sessions(identity), mode: mode);
          expect(repository.reads, isEmpty);
          expect(
            find.byKey(const Key('analytics-metric-profileVisits')),
            findsNothing,
          );
          expect(find.text('İstatistikler'), findsNothing);
        },
      );
    }
    testWidgets('$mode owner uses fenced real data without N plus one reads', (
      tester,
    ) async {
      final repository = _Repository();
      await _mount(tester, repository, _Sessions(_session()), mode: mode);
      expect(
        find.byKey(const Key('analytics-metric-profileVisits')),
        findsOneWidget,
      );
      expect(
        repository.reads.every((request) => request.$3 == 'owner'),
        isTrue,
      );
      expect(repository.reads.length, mode == 'overview' ? 2 : 1);
      expect(repository.reads.first.$1, mode == 'event' ? 'event' : 'summary');
      expect(find.byKey(const Key('analytics-going-soon')), findsOneWidget);
      expect(find.text('Yakında'), findsOneWidget);
      expect(find.text('Ölçüm başlangıcı: 08.09.2026'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('period changes discard late summary and page responses', (
    tester,
  ) async {
    final repository = _Repository();
    final lateSummary = Completer<Result<VenueAnalyticsSummary>>();
    final latePage = Completer<Result<VenueAnalyticsEventPage>>();
    repository.summaryReply = (days) => days == 7
        ? lateSummary.future
        : Future.value(Result.success(_summary(days: days, count: days)));
    repository.pageReply = (days, page) => days == 7
        ? latePage.future
        : Future.value(Result.success(_page(['Dönem $days'])));
    await _mount(tester, repository, _Sessions(_session()));
    await tester.tap(find.byKey(const Key('analytics-period-7')));
    await tester.pump();
    expect(find.byKey(const Key('analytics-metric-impressions')), findsNothing);
    await tester.tap(find.byKey(const Key('analytics-period-90')));
    await tester.pumpAndSettle();
    lateSummary.complete(Result.success(_summary(days: 7, count: 777)));
    latePage.complete(Result.success(_page(['Eski dönem'])));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<Text>(find.byKey(const Key('analytics-metric-impressions')))
          .data,
      '90',
    );
    expect(find.text('Eski dönem'), findsNothing);
    await _reveal(tester, find.text('Dönem 90'));
    expect(find.text('Dönem 90'), findsOneWidget);
  });

  testWidgets(
    'same period does not reread while switching clears old account data immediately',
    (tester) async {
      final repository = _Repository();
      final sessions = _Sessions(_session());
      await _mount(tester, repository, sessions);
      await tester.tap(find.byKey(const Key('analytics-period-30')));
      await tester.pumpAndSettle();
      expect(repository.reads.length, 2);
      sessions.replace(_session(user: 'another', token: 'another-token'));
      await tester.pump();
      expect(
        find.byKey(const Key('analytics-metric-impressions')),
        findsNothing,
      );
      expect(find.text('İstatistikler'), findsNothing);
      expect(repository.reads.length, 2);
    },
  );

  testWidgets(
    'logout during an in flight summary rejects late private data and unsubscribes',
    (tester) async {
      final repository = _Repository();
      final pending = Completer<Result<VenueAnalyticsSummary>>();
      repository.summaryReply = (_) => pending.future;
      final sessions = _Sessions(_session());
      await _mount(tester, repository, sessions, settle: false);
      expect(sessions.listening, isTrue);
      sessions.replace(const AuthSession.guest());
      await tester.pump();
      pending.complete(Result.success(_summary(count: 999)));
      await tester.pumpAndSettle();
      expect(find.text('999'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      expect(sessions.listening, isFalse);
      sessions.replace(_session());
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('mismatched venue or event summary is never rendered', (
    tester,
  ) async {
    final repository = _Repository()
      ..summaryReply = (_) async => Result.success(_summary(venue: 'another'));
    await _mount(tester, repository, _Sessions(_session()));
    expect(find.text('İstatistikler yüklenemedi.'), findsOneWidget);
    expect(find.byKey(const Key('analytics-metric-impressions')), findsNothing);
  });

  testWidgets('event screen rejects a summary for another event', (
    tester,
  ) async {
    final repository = _Repository()
      ..summaryReply = (_) async =>
          Result.success(_summary(event: 'different-event'));
    await _mount(tester, repository, _Sessions(_session()), mode: 'event');
    expect(find.text('İstatistikler yüklenemedi.'), findsOneWidget);
    expect(find.byKey(const Key('analytics-metric-impressions')), findsNothing);
  });

  testWidgets(
    'period choices expose selected state and a working semantic action',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        await _mount(tester, _Repository(), _Sessions(_session()));
        final selected = tester
            .getSemantics(find.bySemanticsLabel('Son 30 gün'))
            .getSemanticsData();
        expect(selected.hasFlag(ui.SemanticsFlag.isSelected), isTrue);
        expect(selected.hasAction(ui.SemanticsAction.tap), isTrue);
        final other = tester
            .getSemantics(find.bySemanticsLabel('Son 7 gün'))
            .getSemanticsData();
        expect(other.hasFlag(ui.SemanticsFlag.isSelected), isFalse);
      } finally {
        semantics.dispose();
      }
    },
  );

  testWidgets('summary error offers retry without invented zero counts', (
    tester,
  ) async {
    final repository = _Repository()
      ..summaryReply = (_) async =>
          const Result.failure(AppError(code: 'offline', message: 'offline'));
    await _mount(tester, repository, _Sessions(_session()), mode: 'event');
    expect(find.text('İstatistikler yüklenemedi.'), findsOneWidget);
    expect(find.byKey(const Key('analytics-metric-impressions')), findsNothing);
    repository.summaryReply = (_) async =>
        Result.success(_summary(event: 'event', count: 0, tracking: false));
    await tester.tap(find.text('Yeniden dene'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<Text>(find.byKey(const Key('analytics-metric-impressions')))
          .data,
      '0',
    );
    expect(find.text('Henüz ölçüm kaydı bulunmuyor.'), findsOneWidget);
  });

  testWidgets(
    'page retry preserves rows deduplicates append and blocks repeated load more',
    (tester) async {
      final repository = _Repository();
      final pending = Completer<Result<VenueAnalyticsEventPage>>();
      repository.pageReply = (_, page) => page == 0
          ? Future.value(Result.success(_page(['Birinci'], more: true)))
          : pending.future;
      await _mount(tester, repository, _Sessions(_session()));
      await _reveal(tester, find.byKey(const Key('analytics-load-more')));
      final callback = tester
          .widget<GradientOutlineButton>(
            find.byKey(const Key('analytics-load-more')),
          )
          .onPressed!;
      callback();
      callback();
      await tester.pump();
      expect(repository.reads.where((item) => item.$1 == 'events-1').length, 1);
      pending.complete(
        const Result.failure(AppError(code: 'offline', message: 'offline')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Birinci'), findsOneWidget);
      expect(find.text('Etkinlik listesi yüklenemedi.'), findsOneWidget);
      repository.pageReply = (_, page) async =>
          Result.success(_page(['Birinci', 'İkinci'], page: page));
      await _reveal(tester, find.text('Yeniden dene'));
      await tester.tap(find.text('Yeniden dene'));
      await tester.pumpAndSettle();
      expect(find.text('Birinci'), findsOneWidget);
      expect(find.text('İkinci'), findsOneWidget);
      expect(repository.reads.where((item) => item.$1 == 'events-1').length, 2);
    },
  );

  for (final mode in ['overview', 'event']) {
    testWidgets(
      '$mode screen refresh is single flight and keeps owner fencing',
      (tester) async {
        final repository = _Repository();
        final sessions = _Sessions(_session());
        await _mount(tester, repository, sessions, mode: mode);
        final pending = Completer<Result<VenueAnalyticsSummary>>();
        repository.summaryReply = (_) => pending.future;
        final callback = tester
            .widget<IconButton>(find.byKey(const Key('analytics-refresh')))
            .onPressed!;
        callback();
        callback();
        await tester.pump();
        expect(repository.reads.length, mode == 'overview' ? 4 : 2);
        expect(repository.reads.last.$3, 'owner');
        expect(
          tester
              .widget<IconButton>(find.byKey(const Key('analytics-refresh')))
              .onPressed,
          isNull,
        );
        pending.complete(
          Result.success(
            _summary(count: 543, event: mode == 'event' ? 'event' : null),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<Text>(
                find.byKey(const Key('analytics-metric-profileVisits')),
              )
              .data,
          '543',
        );
        sessions.replace(const AuthSession.guest());
        await tester.pump();
        expect(find.byKey(const Key('analytics-refresh')), findsNothing);
      },
    );
  }

  for (final mode in ['overview', 'event']) {
    testWidgets(
      '$mode supports 320 px 200 percent text and large actual counts',
      (tester) async {
        final repository = _Repository()
          ..summaryReply = (_) async => Result.success(
            _summary(
              count: 999999999999,
              event: mode == 'event' ? 'event' : null,
            ),
          );
        await _mount(
          tester,
          repository,
          _Sessions(_session()),
          mode: mode,
          size: const Size(320, 720),
          scale: 2,
        );
        await _reveal(
          tester,
          find.byKey(const Key('analytics-metric-profileVisits')),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final mode in ['overview', 'event']) {
    testWidgets('$mode has no info action while metrics and controls remain', (
      tester,
    ) async {
      await _mount(tester, _Repository(), _Sessions(_session()), mode: mode);
      expect(find.byTooltip('İstatistikler hakkında'), findsNothing);
      expect(find.byIcon(Icons.info_outline_rounded), findsNothing);
      expect(find.text('Sayılar ne anlama geliyor?'), findsNothing);
      expect(find.byType(AlertDialog), findsNothing);
      for (final metric in ['impressions', 'detailViews', 'profileVisits']) {
        expect(find.byKey(Key('analytics-metric-$metric')), findsOneWidget);
      }
      expect(find.byKey(const Key('analytics-going-soon')), findsOneWidget);
      expect(find.byKey(const Key('analytics-refresh')), findsOneWidget);
      for (final days in [7, 30, 90]) {
        expect(find.byKey(Key('analytics-period-$days')), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'sorting resets server pagination and fences late old pages without rereading summary',
    (tester) async {
      final stale = Completer<Result<VenueAnalyticsEventPage>>();
      final repository = _Repository()
        ..sortedPageReply = (sort, page) {
          if (sort == VenueAnalyticsSort.date && page == 1) return stale.future;
          return Future.value(
            Result.success(
              _page(
                [
                  sort == VenueAnalyticsSort.date
                      ? 'Tarih sırası'
                      : 'Erişim sırası',
                ],
                page: page,
                more: sort == VenueAnalyticsSort.date,
                sort: sort,
              ),
            ),
          );
        };
      await _mount(tester, repository, _Sessions(_session()));
      await _reveal(tester, find.byKey(const Key('analytics-event-sort-date')));
      final changeSort = tester
          .widget<DropdownButtonFormField<VenueAnalyticsSort>>(
            find.byKey(const Key('analytics-event-sort-date')),
          )
          .onChanged!;
      await _reveal(tester, find.byKey(const Key('analytics-load-more')));
      await tester.tap(find.byKey(const Key('analytics-load-more')));
      await tester.pump();
      changeSort(VenueAnalyticsSort.reach);
      await tester.pumpAndSettle();
      stale.complete(Result.success(_page(['Eski sayfa'], page: 1)));
      await tester.pumpAndSettle();
      await _reveal(tester, find.text('Erişim sırası'));
      expect(find.text('Eski sayfa'), findsNothing);
      expect(find.text('Tarih sırası'), findsNothing);
      expect(repository.sortReads, [
        VenueAnalyticsSort.date,
        VenueAnalyticsSort.date,
        VenueAnalyticsSort.reach,
      ]);
      expect(repository.reads.where((read) => read.$1 == 'summary').length, 1);
      expect(repository.reads.last.$1, 'events-0');
    },
  );

  testWidgets('event row opens one captured event route with selected period', (
    tester,
  ) async {
    final repository = _Repository();
    final navigation = _Navigation();
    await _mount(
      tester,
      repository,
      _Sessions(_session()),
      navigation: navigation,
    );
    await tester.tap(find.byKey(const Key('analytics-period-7')));
    await tester.pumpAndSettle();
    final row = find.byKey(
      const Key('analytics-event-open-Canlı müzik akşamı'),
    );
    await _reveal(tester, row);
    final callback = tester.widget<InkWell>(row).onTap!;
    callback();
    callback();
    await tester.pumpAndSettle();
    expect(navigation.pushed.length, 2);
    final screen = tester.widget<VenueAnalyticsScreen>(
      find.byType(VenueAnalyticsScreen).last,
    );
    expect(screen.eventId, 'Canlı müzik akşamı');
    expect(screen.initialDays, 7);
    expect(repository.reads.last, ('event', 7, 'owner'));
  });

  for (final change in ['logout', 'new period', 'new sort']) {
    testWidgets('retained event callback stays inert after $change', (
      tester,
    ) async {
      final repository = _Repository();
      final sessions = _Sessions(_session());
      final navigation = _Navigation();
      await _mount(tester, repository, sessions, navigation: navigation);
      final period = tester
          .widget<InkWell>(find.byKey(const Key('analytics-period-7')))
          .onTap!;
      await _reveal(tester, find.byKey(const Key('analytics-event-sort-date')));
      final sort = tester
          .widget<DropdownButtonFormField<VenueAnalyticsSort>>(
            find.byKey(const Key('analytics-event-sort-date')),
          )
          .onChanged!;
      final row = find.byKey(
        const Key('analytics-event-open-Canlı müzik akşamı'),
      );
      await _reveal(tester, row);
      final callback = tester.widget<InkWell>(row).onTap!;
      if (change == 'logout') sessions.replace(const AuthSession.guest());
      if (change == 'new period') period();
      if (change == 'new sort') sort(VenueAnalyticsSort.reach);
      callback();
      await tester.pumpAndSettle();
      callback();
      await tester.pumpAndSettle();
      expect(navigation.pushed.length, 1);
      expect(repository.reads.where((read) => read.$1 == 'event'), isEmpty);
      expect(tester.takeException(), isNull);
    });
  }

  final render = Platform.environment['VENUE_ANALYTICS_RENDER_DIR'];
  if (render != null) {
    testWidgets('render real owner analytics surfaces', (tester) async {
      await tester.runAsync(() async {
        final fonts =
            '${File(Platform.resolvedExecutable).parent.parent.parent.path}/material_fonts';
        final loader = FontLoader('Roboto');
        for (final file in [
          'roboto-regular.ttf',
          'roboto-medium.ttf',
          'roboto-bold.ttf',
          'roboto-black.ttf',
        ]) {
          loader.addFont(
            File('$fonts/$file').readAsBytes().then(ByteData.sublistView),
          );
        }
        await loader.load();
        await (FontLoader(
          'MaterialIcons',
        )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
      });
      for (final mode in ['overview', 'profile-link', 'event-link', 'event']) {
        await tester.pumpWidget(const SizedBox.shrink());
        final capture = GlobalKey();
        await _mount(
          tester,
          _Repository()
            ..summaryReply = (days) async => Result.success(
              _summary(
                days: days,
                event: mode == 'event' ? 'event' : null,
                reporting: true,
              ),
            ),
          _Sessions(_session()),
          mode: mode,
          capture: capture,
        );
        await tester.runAsync(() async {
          final boundary =
              capture.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
          final image = await boundary.toImage(pixelRatio: 1);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await Directory(render).create(recursive: true);
          await File(
            '$render/$mode.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
        if (mode == 'overview') {
          await _reveal(tester, find.text('Etkinlik karşılaştırması'));
          await tester.runAsync(() async {
            final boundary =
                capture.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
            final image = await boundary.toImage(pixelRatio: 1);
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await File(
              '$render/event-comparison.png',
            ).writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
      }
    });
  }
}

AuthSession _session({
  String user = 'owner',
  String token = 'token',
  String role = 'ROLE_VENUE',
  String status = 'ACTIVE',
}) => AuthSession.authenticated(
  token: token,
  userId: user,
  username: user,
  accountStatus: status,
  roles: [role],
  permissions: [],
  expiresAt: DateTime.utc(2100),
  isAdmin: false,
);

class _Sessions extends Fake with ChangeNotifier implements AuthSessionManager {
  _Sessions(this._session);
  AuthSession _session;
  @override
  AuthSession get session => _session;
  bool get listening => hasListeners;
  void replace(AuthSession next) {
    _session = next;
    notifyListeners();
  }
}

VenueAnalyticsSummary _summary({
  int days = 30,
  int count = 1200,
  String venue = 'venue',
  String? event,
  bool tracking = true,
  bool reporting = false,
}) => VenueAnalyticsSummary(
  venueId: venue,
  eventId: event,
  fromDate: DateTime.utc(2026, 9, 8).subtract(Duration(days: days - 1)),
  toDate: DateTime.utc(2026, 9, 8),
  days: days,
  timeZone: 'Europe/Istanbul',
  trackingStartedAt: !tracking
      ? null
      : reporting
      ? DateTime.utc(2026, 6, 1)
      : DateTime.utc(2026, 9, 8, 8),
  updatedAt: DateTime.utc(2026, 9, 8, 12),
  metrics: VenueAnalyticsMetrics(
    impressions: count,
    detailViews: reporting ? 420 : count,
    profileVisits: reporting ? 68 : count,
  ),
  daily: !reporting
      ? const []
      : List.generate(
          days,
          (index) => VenueAnalyticsDailyPoint(
            date: DateTime.utc(
              2026,
              9,
              8,
            ).subtract(Duration(days: days - index - 1)),
            metrics: VenueAnalyticsMetrics(
              impressions: 40 + (index * 19) % 90,
              detailViews: 10 + index % 24,
              profileVisits: 2 + index % 7,
            ),
            partial: index == days - 1,
          ),
        ),
  comparison: !reporting
      ? null
      : VenueAnalyticsComparison(
          status: days == 90
              ? VenueAnalyticsComparisonStatus.retentionLimit
              : VenueAnalyticsComparisonStatus.available,
          currentFromDate: DateTime.utc(
            2026,
            9,
            8,
          ).subtract(Duration(days: days)),
          currentToDate: DateTime.utc(2026, 9, 7),
          previousFromDate: DateTime.utc(
            2026,
            9,
            8,
          ).subtract(Duration(days: days * 2)),
          previousToDate: DateTime.utc(
            2026,
            9,
            7,
          ).subtract(Duration(days: days)),
          currentMetrics: days == 90
              ? null
              : const VenueAnalyticsMetrics(
                  impressions: 1160,
                  detailViews: 404,
                  profileVisits: 64,
                ),
          previousMetrics: days == 90
              ? null
              : const VenueAnalyticsMetrics(
                  impressions: 920,
                  detailViews: 315,
                  profileVisits: 46,
                ),
        ),
);
VenueAnalyticsEventPage _page(
  List<String> titles, {
  int page = 0,
  bool more = false,
  VenueAnalyticsSort sort = VenueAnalyticsSort.date,
}) => VenueAnalyticsEventPage(
  items: titles
      .map(
        (title) => VenueAnalyticsEvent(
          eventId: title,
          title: title,
          eventDate: DateTime.utc(2026, 9, 8),
          metrics: _summary().metrics,
        ),
      )
      .toList(),
  page: page,
  size: 20,
  totalElements: more ? 40 : titles.length,
  totalPages: more ? 2 : 1,
  hasNext: more,
  sort: sort,
);

class _Repository implements VenueAnalyticsRepository {
  final reads = <(String, int, String)>[];
  Future<Result<VenueAnalyticsSummary>> Function(int)? summaryReply;
  Future<Result<VenueAnalyticsEventPage>> Function(int, int)? pageReply;
  Future<Result<VenueAnalyticsEventPage>> Function(VenueAnalyticsSort, int)?
  sortedPageReply;
  final sortReads = <VenueAnalyticsSort>[];
  @override
  Future<Result<VenueAnalyticsSummary>> summary({
    required String venueId,
    required String expectedSessionKey,
    int days = 30,
  }) {
    reads.add(('summary', days, expectedSessionKey));
    return summaryReply?.call(days) ??
        Future.value(Result.success(_summary(days: days)));
  }

  @override
  Future<Result<VenueAnalyticsSummary>> event({
    required String venueId,
    required String eventId,
    required String expectedSessionKey,
    int days = 30,
  }) {
    reads.add(('event', days, expectedSessionKey));
    return summaryReply?.call(days) ??
        Future.value(Result.success(_summary(days: days, event: eventId)));
  }

  @override
  Future<Result<VenueAnalyticsEventPage>> events({
    required String venueId,
    required String expectedSessionKey,
    int days = 30,
    int page = 0,
    int size = 20,
    VenueAnalyticsSort sort = VenueAnalyticsSort.date,
  }) {
    reads.add(('events-$page', days, expectedSessionKey));
    sortReads.add(sort);
    return sortedPageReply?.call(sort, page) ??
        pageReply?.call(days, page) ??
        Future.value(Result.success(_page(['Canlı müzik akşamı'], sort: sort)));
  }
}

class _Navigation extends NavigatorObserver {
  final pushed = <Route<dynamic>>[];
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushed.add(route);
    super.didPush(route, previousRoute);
  }
}

VoidCallback _linkCallback(WidgetTester tester) {
  final link = find.byKey(const Key('analytics-open-link'));
  return tester.widget<TextButton>(link).onPressed!;
}

Future<void> _reveal(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      finder,
      260,
      scrollable: find.byType(Scrollable).last,
    );
  }
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

Future<void> _mount(
  WidgetTester tester,
  _Repository repository,
  _Sessions sessions, {
  String mode = 'overview',
  bool settle = true,
  Size size = const Size(390, 844),
  double scale = 1,
  GlobalKey? capture,
  _Navigation? navigation,
  VenueAnalyticsReportingConfig? reportingConfig =
      const VenueAnalyticsReportingConfig(enabled: true),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final Widget widget = switch (mode) {
    'profile-link' || 'event-link' => VenueAnalyticsLink(
      venueId: 'venue',
      venueName: 'SoundConnect Ankara',
      ownerUserId: 'owner',
      eventId: mode == 'event-link' ? 'event' : null,
      eventTitle: mode == 'event-link' ? 'Canlı müzik akşamı' : null,
      repository: repository,
      sessions: sessions,
    ),
    'event' => VenueAnalyticsScreen(
      venueId: 'venue',
      venueName: 'SoundConnect Ankara',
      eventId: 'event',
      eventTitle: 'Canlı müzik akşamı',
      ownerUserId: 'owner',
      repository: repository,
      sessions: sessions,
    ),
    _ => VenueAnalyticsScreen(
      venueId: 'venue',
      venueName: 'SoundConnect Ankara',
      ownerUserId: 'owner',
      repository: repository,
      sessions: sessions,
    ),
  };
  final application = RepaintBoundary(
    key: capture,
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      navigatorObservers: [if (navigation != null) navigation],
      theme: capture == null
          ? AppTheme.navy
          : AppTheme.navy.copyWith(
              textTheme: AppTheme.navy.textTheme.apply(fontFamily: 'Roboto'),
              primaryTextTheme: AppTheme.navy.primaryTextTheme.apply(
                fontFamily: 'Roboto',
              ),
            ),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: !mode.endsWith('-link')
          ? widget
          : Scaffold(
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: widget,
              ),
            ),
    ),
  );
  await tester.pumpWidget(
    reportingConfig == null
        ? application
        : VenueAnalyticsReportingScope(
            config: reportingConfig,
            child: application,
          ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}
