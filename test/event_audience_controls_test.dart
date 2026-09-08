import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session.dart';
import 'package:soundconnect_23_12_25codx/core/error/app_error.dart';
import 'package:soundconnect_23_12_25codx/core/error/result.dart';
import 'package:soundconnect_23_12_25codx/modules/event_audience/domain/event_audience_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/event_audience/presentation/widgets/event_audience_controls.dart';
import 'package:soundconnect_23_12_25codx/shared/theme/app_theme.dart';
import 'package:soundconnect_23_12_25codx/shared/widgets/gradient_outline_button.dart';

import 'support/event_audience_fakes.dart';

void main() {
  testWidgets(
    'audience confirmation is safe with a mounted previous route scaffold',
    (tester) async {
      final repository = AudienceTestRepository();
      final sessions = AudienceTestSessions(audienceSession());
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.navy,
          home: Scaffold(
            appBar: AppBar(title: const Text('Etkinlikler')),
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) => Scaffold(
                      appBar: AppBar(title: const Text('Etkinlik detayı')),
                      body: SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: EventAudienceControls(
                          eventId: audienceEventId,
                          eventTitle: 'Canlı müzik akşamı',
                          repository: repository,
                          sessions: sessions,
                          onProfileShare: (_) async {},
                        ),
                      ),
                    ),
                  ),
                ),
                child: const Text('Etkinliği aç'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Etkinliği aç'));
      await tester.pumpAndSettle();
      expect(find.byType(Scaffold, skipOffstage: false), findsNWidgets(2));
      await tester.tap(find.byKey(const Key('event-audience-going')));
      await tester.pump();
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(milliseconds: 80));
      expect(tester.takeException(), isNull);
      await tester.pumpAndSettle();
      expect(find.text('Gidiyorum olarak işaretlendi.'), findsOneWidget);
      expect(repository.writes.length, 1);
      await tester.tap(find.byKey(const Key('event-audience-thinking')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Düşünüyorum olarak işaretlendi.'), findsOneWidget);
    },
  );

  testWidgets(
    'stacked-route snackbar profile action survives push and pop animations',
    (tester) async {
      final repository = AudienceTestRepository();
      final sessions = AudienceTestSessions(audienceSession());
      var profilePushes = 0;
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.navy,
          home: Scaffold(
            appBar: AppBar(title: const Text('Etkinlikler')),
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (detailContext) => Scaffold(
                      appBar: AppBar(title: const Text('Etkinlik detayı')),
                      body: SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: EventAudienceControls(
                          eventId: audienceEventId,
                          eventTitle: 'Canlı müzik akşamı',
                          repository: repository,
                          sessions: sessions,
                          onProfileShare: (expected) async {
                            expect(expected.userId, sessions.session.userId);
                            profilePushes++;
                            await Navigator.of(detailContext).push<void>(
                              MaterialPageRoute<void>(
                                builder: (_) => Scaffold(
                                  appBar: AppBar(
                                    title: const Text('Profil paylaşımı'),
                                  ),
                                  body: const Text('Profil taslağı'),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
                child: const Text('Etkinliği aç'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Etkinliği aç'));
      await tester.pumpAndSettle();
      await _tap(tester, 'event-audience-going');
      expect(find.byType(Scaffold, skipOffstage: false), findsNWidgets(2));
      await tester.tap(
        find.byKey(const Key('event-audience-snackbar-profile')),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(milliseconds: 80));
      expect(tester.takeException(), isNull);
      await tester.pumpAndSettle();
      expect(profilePushes, 1);
      expect(find.byType(Scaffold, skipOffstage: false), findsNWidgets(3));
      expect(find.text('Profil taslağı'), findsOneWidget);
      await tester.pageBack();
      await tester.pump();
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(milliseconds: 80));
      expect(tester.takeException(), isNull);
      await tester.pumpAndSettle();
      expect(find.text('Etkinlik detayı'), findsOneWidget);
      _expectNoDetailStatusRow();
      expect(
        tester
            .widget<GradientOutlineButton>(
              find.byKey(const Key('event-audience-going')),
            )
            .backgroundColor,
        isNotNull,
      );
      expect(repository.writes.length, 1);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(Scaffold, skipOffstage: false), findsOneWidget);
      expect(find.text('Etkinlikler'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final status in [
    EventAudienceStatus.going,
    EventAudienceStatus.thinking,
  ]) {
    testWidgets(
      'new ${status.name} saves privately then shows eight-second branded confirmation only',
      (tester) async {
        final repository = AudienceTestRepository();
        var drafts = 0;
        await _pump(tester, repository, onProfileShare: (_) async => drafts++);
        await _tap(tester, 'event-audience-${status.name}');
        expect(repository.writes.single.intent, status);
        expect(repository.writes.single.published, isFalse);
        _expectNoDetailStatusRow();
        expect(
          find.text('${status.label} olarak işaretlendi.'),
          findsOneWidget,
        );
        expect(find.byType(BottomSheet), findsNothing);
        expect(find.byType(TextField), findsNothing);
        final bar = tester.widget<SnackBar>(find.byType(SnackBar));
        expect(bar.duration, const Duration(seconds: 8));
        expect(bar.persist, isFalse);
        final profile = _snackAction(tester);
        profile();
        profile();
        await tester.pumpAndSettle();
        expect(drafts, 1);
        expect(repository.writes.length, 1);
        expect(repository.current.publishedOnProfile, isFalse);
      },
    );
  }

  testWidgets(
    'confirmation expires without changing intent or opening a panel',
    (tester) async {
      final repository = AudienceTestRepository();
      await _pump(tester, repository);
      await _tap(tester, 'event-audience-going');
      await tester.pump(const Duration(seconds: 9));
      await tester.pumpAndSettle();
      expect(find.byType(SnackBar), findsNothing);
      expect(repository.current.intent, EventAudienceStatus.going);
      expect(repository.writes.length, 1);
    },
  );

  testWidgets(
    'repeat selected intent opens only the anchored two-item popup without another PUT',
    (tester) async {
      final repository = AudienceTestRepository();
      var drafts = 0;
      await _pump(
        tester,
        repository,
        onProfileShare: (_) async {
          expect(find.byType(BottomSheet), findsNothing);
          expect(
            find.byKey(const Key('event-audience-quick-menu')),
            findsNothing,
          );
          drafts++;
        },
      );
      await _tap(tester, 'event-audience-going');
      await _tap(tester, 'event-audience-going');
      expect(repository.writes.length, 1);
      expect(
        find.byKey(const Key('event-audience-quick-menu')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('event-audience-quick-profile')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('event-audience-quick-clear')),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate((widget) => widget is PopupMenuItem),
        findsNWidgets(2),
      );
      expect(find.byType(BottomSheet), findsNothing);
      expect(
        find.byKey(const Key('event-audience-external-share')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('event-audience-management-going')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('event-audience-management-thinking')),
        findsNothing,
      );
      expect(find.byType(TextField), findsNothing);
      await _tap(tester, 'event-audience-quick-profile');
      expect(drafts, 1);
      expect(repository.writes.length, 1);
    },
  );

  testWidgets(
    'quick removal clears one published intent with its original version',
    (tester) async {
      final repository = AudienceTestRepository()
        ..current = audienceState(
          intent: EventAudienceStatus.going,
          published: true,
          note: 'Görüşürüz',
          version: 4,
        );
      await _pump(tester, repository);
      await _tap(tester, 'event-audience-going');
      expect(repository.writes, isEmpty);
      expect(find.text('Paylaşımı düzenle'), findsOneWidget);
      expect(find.byType(BottomSheet), findsNothing);
      final clear = _popupAction(tester, 'event-audience-quick-clear');
      clear();
      clear();
      await tester.pumpAndSettle();
      expect(repository.writes.single.intent, EventAudienceStatus.none);
      expect(repository.writes.single.published, isFalse);
      expect(repository.writes.single.note, isNull);
      expect(repository.writes.single.version, 4);
      expect(find.byKey(const Key('event-audience-quick-menu')), findsNothing);
    },
  );

  testWidgets(
    'published choice has no detail status row and selected button opens the profile popup',
    (tester) async {
      final repository = AudienceTestRepository()
        ..current = audienceState(
          intent: EventAudienceStatus.thinking,
          published: true,
          note: 'Görüşürüz',
          version: 2,
        );
      var drafts = 0;
      await _pump(
        tester,
        repository,
        onProfileShare: (_) async {
          expect(
            find.byKey(const Key('event-audience-quick-menu')),
            findsNothing,
          );
          expect(
            find.byWidgetPredicate((widget) => widget is PopupMenuItem),
            findsNothing,
          );
          drafts++;
        },
      );
      _expectNoDetailStatusRow();
      await _tap(tester, 'event-audience-thinking');
      expect(
        find.byWidgetPredicate((widget) => widget is PopupMenuItem),
        findsNWidgets(2),
      );
      expect(find.text('Paylaşımı düzenle'), findsOneWidget);
      expect(find.byType(BottomSheet), findsNothing);
      await tester.tap(find.byKey(const Key('event-audience-quick-profile')));
      await tester.pump();
      expect(drafts, 0);
      await tester.pumpAndSettle();
      expect(drafts, 1);
      expect(repository.writes, isEmpty);
      expect(repository.current.note, 'Görüşürüz');
      _expectNoDetailStatusRow();
    },
  );

  testWidgets(
    'revision update dismisses quick popup and rejects its retained action',
    (tester) async {
      final repository = AudienceTestRepository()
        ..current = audienceState(
          intent: EventAudienceStatus.going,
          version: 1,
        );
      var drafts = 0;
      await _pump(tester, repository, onProfileShare: (_) async => drafts++);
      await _tap(tester, 'event-audience-going');
      final oldProfile = _popupAction(tester, 'event-audience-quick-profile');
      repository.current = audienceState(
        intent: EventAudienceStatus.thinking,
        version: 2,
      );
      repository.signal.value++;
      oldProfile();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('event-audience-quick-menu')), findsNothing);
      expect(drafts, 0);
      expect(repository.writes, isEmpty);
    },
  );

  testWidgets(
    'event binding update dismisses the popup without mutating the new event',
    (tester) async {
      final repository = AudienceTestRepository()
        ..current = audienceState(
          intent: EventAudienceStatus.going,
          version: 1,
        );
      final sessions = AudienceTestSessions(audienceSession());
      await _pump(tester, repository, sessions: sessions);
      await _tap(tester, 'event-audience-going');
      repository.current = audienceState(eventId: audienceVenueId);
      await _pump(
        tester,
        repository,
        sessions: sessions,
        eventId: audienceVenueId,
      );
      expect(find.byKey(const Key('event-audience-quick-menu')), findsNothing);
      expect(repository.writes, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'event rebind before the first popup frame cannot leave a stale overlay',
    (tester) async {
      final repository = AudienceTestRepository()
        ..current = audienceState(
          intent: EventAudienceStatus.going,
          version: 1,
        );
      final sessions = AudienceTestSessions(audienceSession());
      await _pump(tester, repository, sessions: sessions);
      // Start showMenu without rendering its item Builder/route capture yet.
      _action(tester, 'event-audience-going')();
      repository.current = audienceState(eventId: audienceVenueId);
      await _pump(
        tester,
        repository,
        sessions: sessions,
        eventId: audienceVenueId,
      );
      expect(find.byKey(const Key('event-audience-quick-menu')), findsNothing);
      expect(
        find.byWidgetPredicate((widget) => widget is PopupMenuItem),
        findsNothing,
      );
      expect(
        ModalRoute.of(
          tester.element(find.byType(EventAudienceControls)),
        )!.isCurrent,
        isTrue,
      );
      expect(repository.writes, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'control disposal before the first popup frame leaves no inert overlay',
    (tester) async {
      final repository = AudienceTestRepository()
        ..current = audienceState(
          intent: EventAudienceStatus.going,
          version: 1,
        );
      final sessions = AudienceTestSessions(audienceSession());
      await _pump(tester, repository, sessions: sessions);
      _action(tester, 'event-audience-going')();
      await _pump(tester, repository, sessions: sessions, showControls: false);
      expect(find.byKey(const Key('event-audience-quick-menu')), findsNothing);
      expect(
        find.byWidgetPredicate((widget) => widget is PopupMenuItem),
        findsNothing,
      );
      expect(repository.writes, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'open popup survives the row-column resize boundary safely and reopens at the new anchor',
    (tester) async {
      final repository = AudienceTestRepository()
        ..current = audienceState(
          intent: EventAudienceStatus.going,
          version: 1,
        );
      final sessions = AudienceTestSessions(audienceSession());
      await _pump(tester, repository, sessions: sessions, width: 390);
      await _tap(tester, 'event-audience-going');
      expect(
        find.byKey(const Key('event-audience-quick-menu')),
        findsOneWidget,
      );
      await tester.binding.setSurfaceSize(const Size(320, 844));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      // A still-valid anchor may reposition; a detached row anchor safely closes.
      if (find
          .byKey(const Key('event-audience-quick-menu'))
          .evaluate()
          .isNotEmpty) {
        await tester.tapAt(const Offset(4, 830));
        await tester.pumpAndSettle();
      }
      await _tap(tester, 'event-audience-going');
      expect(
        find.byKey(const Key('event-audience-quick-menu')),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate((widget) => widget is PopupMenuItem),
        findsNWidgets(2),
      );
      for (final key in [
        'event-audience-quick-clear',
        'event-audience-quick-profile',
      ]) {
        final bounds = tester.getRect(find.byKey(Key(key)));
        expect(bounds.left, greaterThanOrEqualTo(0));
        expect(bounds.right, lessThanOrEqualTo(320));
        expect(bounds.top, greaterThanOrEqualTo(0));
        expect(bounds.bottom, lessThanOrEqualTo(844));
      }
      expect(repository.writes, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'listener role change invalidates popup profile action before it can navigate',
    (tester) async {
      final repository = AudienceTestRepository()
        ..current = audienceState(
          intent: EventAudienceStatus.going,
          version: 1,
        );
      final sessions = AudienceTestSessions(audienceSession());
      var drafts = 0;
      await _pump(
        tester,
        repository,
        sessions: sessions,
        onProfileShare: (_) async => drafts++,
      );
      await _tap(tester, 'event-audience-going');
      final oldProfile = _popupAction(tester, 'event-audience-quick-profile');
      sessions.replace(audienceSession(role: 'ROLE_MUSICIAN'));
      oldProfile();
      await tester.pumpAndSettle();
      expect(drafts, 0);
      expect(find.byKey(const Key('event-audience-quick-menu')), findsNothing);
      expect(repository.writes, isEmpty);
    },
  );

  testWidgets(
    'account switch during popup dismissal prevents profile navigation',
    (tester) async {
      final repository = AudienceTestRepository()
        ..current = audienceState(
          intent: EventAudienceStatus.going,
          version: 1,
        );
      final sessions = AudienceTestSessions(audienceSession());
      var drafts = 0;
      await _pump(
        tester,
        repository,
        sessions: sessions,
        onProfileShare: (_) async => drafts++,
      );
      await _tap(tester, 'event-audience-going');
      await tester.tap(find.byKey(const Key('event-audience-quick-profile')));
      await tester.pump(const Duration(milliseconds: 10));
      sessions.replace(audienceSession(user: 'second', token: 'second-token'));
      await tester.pumpAndSettle();
      expect(drafts, 0);
      expect(find.byKey(const Key('event-audience-quick-menu')), findsNothing);
    },
  );

  testWidgets(
    'retained native popup action is harmless after the popup is dismissed',
    (tester) async {
      final repository = AudienceTestRepository()
        ..current = audienceState(
          intent: EventAudienceStatus.going,
          version: 1,
        );
      var drafts = 0;
      await _pump(tester, repository, onProfileShare: (_) async => drafts++);
      await _tap(tester, 'event-audience-going');
      final oldProfile = _popupAction(tester, 'event-audience-quick-profile');
      await tester.tapAt(const Offset(4, 830));
      await tester.pumpAndSettle();
      oldProfile();
      await tester.pumpAndSettle();
      expect(drafts, 0);
      expect(repository.writes, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'positive status change preserves publication and note then replaces feedback',
    (tester) async {
      final repository = AudienceTestRepository()
        ..current = audienceState(
          intent: EventAudienceStatus.going,
          published: true,
          note: 'Görüşürüz',
          version: 4,
        );
      await _pump(tester, repository);
      await _tap(tester, 'event-audience-thinking');
      expect(repository.current.publishedOnProfile, isTrue);
      expect(repository.current.note, 'Görüşürüz');
      expect(find.text('Düşünüyorum olarak işaretlendi.'), findsOneWidget);
      expect(find.text('Paylaşımı düzenle'), findsOneWidget);
      expect(find.byType(BottomSheet), findsNothing);
      await _tap(tester, 'event-audience-going');
      expect(repository.writes.length, 2);
      expect(repository.current.publishedOnProfile, isTrue);
      expect(repository.current.note, 'Görüşürüz');
      expect(find.text('Gidiyorum olarak işaretlendi.'), findsOneWidget);
      expect(find.text('Düşünüyorum olarak işaretlendi.'), findsNothing);
    },
  );

  testWidgets(
    'musician repeat popup exposes only removal and no listener profile or external action',
    (tester) async {
      final repository = AudienceTestRepository();
      await _pump(
        tester,
        repository,
        sessions: AudienceTestSessions(audienceSession(role: 'ROLE_MUSICIAN')),
      );
      await _tap(tester, 'event-audience-thinking');
      expect(find.text('Düşünüyorum olarak işaretlendi.'), findsOneWidget);
      expect(find.byType(SnackBarAction), findsNothing);
      await _tap(tester, 'event-audience-thinking');
      expect(
        find.byKey(const Key('event-audience-quick-profile')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('event-audience-quick-clear')),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate((widget) => widget is PopupMenuItem),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('event-audience-external-share')),
        findsNothing,
      );
      expect(find.byType(BottomSheet), findsNothing);
      expect(find.byType(TextField), findsNothing);
      await _tap(tester, 'event-audience-quick-clear');
      expect(repository.current.intent, EventAudienceStatus.none);
      expect(repository.writes.length, 2);
    },
  );

  testWidgets(
    'rapid opposing callbacks dispatch once; stale callbacks cannot overwrite',
    (tester) async {
      final pending = Completer<Result<EventAudienceState>>();
      final repository = AudienceTestRepository()
        ..onWrite = (_) => pending.future;
      await _pump(tester, repository);
      final going = _action(tester, 'event-audience-going');
      final thinking = _action(tester, 'event-audience-thinking');
      going();
      thinking();
      going();
      await tester.pump();
      expect(repository.writes.length, 1);
      expect(find.byType(SnackBar), findsNothing);
      pending.complete(
        Result.success(
          audienceState(intent: EventAudienceStatus.going, version: 1),
        ),
      );
      await tester.pumpAndSettle();
      thinking();
      await tester.pumpAndSettle();
      expect(repository.writes.length, 1);
      expect(find.text('Gidiyorum olarak işaretlendi.'), findsOneWidget);
    },
  );

  testWidgets(
    'logout during pending save cannot show confirmation from late response',
    (tester) async {
      final pending = Completer<Result<EventAudienceState>>();
      final repository = AudienceTestRepository()
        ..onWrite = (_) => pending.future;
      final sessions = AudienceTestSessions(audienceSession());
      await _pump(tester, repository, sessions: sessions);
      await tester.tap(find.byKey(const Key('event-audience-going')));
      sessions.replace(const AuthSession.guest());
      pending.complete(
        Result.success(
          audienceState(intent: EventAudienceStatus.going, version: 1),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('event-audience-controls')), findsNothing);
      expect(find.byType(SnackBar), findsNothing);
      expect(find.byType(BottomSheet), findsNothing);
    },
  );

  testWidgets(
    'account switch removes own confirmation and rejects captured profile action',
    (tester) async {
      final repository = AudienceTestRepository();
      final sessions = AudienceTestSessions(audienceSession());
      var drafts = 0;
      await _pump(
        tester,
        repository,
        sessions: sessions,
        onProfileShare: (_) async => drafts++,
      );
      await _tap(tester, 'event-audience-going');
      final old = _snackAction(tester);
      repository.current = audienceState();
      sessions.replace(audienceSession(user: 'other', token: 'other-token'));
      old();
      await tester.pumpAndSettle();
      expect(drafts, 0);
      expect(find.byType(SnackBar), findsNothing);
      expect(repository.writes.length, 1);
    },
  );

  testWidgets('newer readback invalidates old snackbar action', (tester) async {
    final repository = AudienceTestRepository();
    var drafts = 0;
    await _pump(tester, repository, onProfileShare: (_) async => drafts++);
    await _tap(tester, 'event-audience-going');
    final old = _snackAction(tester);
    repository.current = audienceState(
      intent: EventAudienceStatus.thinking,
      version: 2,
    );
    repository.signal.value++;
    await tester.pumpAndSettle();
    old();
    await tester.pumpAndSettle();
    expect(drafts, 0);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets(
    'new confirmed selection replaces previous queued feedback without stale toast queue',
    (tester) async {
      final repository = AudienceTestRepository();
      await _pump(tester, repository);
      final messenger = ScaffoldMessenger.of(
        tester.element(find.byType(EventAudienceControls)),
      );
      messenger.showSnackBar(const SnackBar(content: Text('Previous')));
      messenger.showSnackBar(const SnackBar(content: Text('Queued')));
      await tester.pumpAndSettle();
      await _tap(tester, 'event-audience-going');
      expect(find.text('Previous'), findsNothing);
      expect(find.text('Queued'), findsNothing);
      expect(find.text('Gidiyorum olarak işaretlendi.'), findsOneWidget);
      await _tap(tester, 'event-audience-thinking');
      expect(find.text('Gidiyorum olarak işaretlendi.'), findsNothing);
      expect(find.text('Düşünüyorum olarak işaretlendi.'), findsOneWidget);
      await tester.pump(const Duration(seconds: 9));
      await tester.pumpAndSettle();
      expect(find.byType(SnackBar), findsNothing);
    },
  );

  testWidgets('logout cleanup never removes a newer unrelated snackbar', (
    tester,
  ) async {
    final repository = AudienceTestRepository();
    final sessions = AudienceTestSessions(audienceSession());
    await _pump(tester, repository, sessions: sessions);
    await _tap(tester, 'event-audience-going');
    final messenger = ScaffoldMessenger.of(
      tester.element(find.byType(EventAudienceControls)),
    );
    messenger.removeCurrentSnackBar();
    messenger.showSnackBar(const SnackBar(content: Text('Unrelated feedback')));
    sessions.replace(const AuthSession.guest());
    await tester.pumpAndSettle();
    expect(find.text('Unrelated feedback'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'later post-frame replacement survives previously scheduled session cleanup',
    (tester) async {
      final repository = AudienceTestRepository();
      final sessions = AudienceTestSessions(audienceSession());
      var drafts = 0;
      await _pump(
        tester,
        repository,
        sessions: sessions,
        onProfileShare: (_) async => drafts++,
      );
      await _tap(tester, 'event-audience-going');
      final oldProfileAction = _snackAction(tester);
      final messenger = ScaffoldMessenger.of(
        tester.element(find.byType(EventAudienceControls)),
      );
      // Logout schedules audience cleanup first. A separate feature replaces
      // feedback later in that same frame, before completion microtasks drain.
      sessions.replace(const AuthSession.guest());
      var replacementShown = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        messenger.removeCurrentSnackBar();
        messenger.showSnackBar(
          const SnackBar(content: Text('Later unrelated feedback')),
        );
        replacementShown = true;
      });
      await tester.pump();
      expect(replacementShown, isTrue);
      await tester.pumpAndSettle();
      oldProfileAction();
      await tester.pump();
      expect(drafts, 0);
      expect(find.text('Later unrelated feedback'), findsOneWidget);
      expect(find.text('Gidiyorum olarak işaretlendi.'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'changed event binding removes own feedback and invalidates retained controls',
    (tester) async {
      final repository = AudienceTestRepository();
      final sessions = AudienceTestSessions(audienceSession());
      var drafts = 0;
      await _pump(
        tester,
        repository,
        sessions: sessions,
        onProfileShare: (_) async => drafts++,
      );
      final oldChoice = _action(tester, 'event-audience-thinking');
      await _tap(tester, 'event-audience-going');
      final oldProfile = _snackAction(tester);
      repository.current = audienceState(eventId: audienceVenueId);
      await _pump(
        tester,
        repository,
        sessions: sessions,
        eventId: audienceVenueId,
        onProfileShare: (_) async => drafts++,
      );
      oldChoice();
      oldProfile();
      await tester.pumpAndSettle();
      expect(repository.writes.length, 1);
      expect(drafts, 0);
      expect(find.byType(SnackBar), findsNothing);
    },
  );

  testWidgets(
    'session switch closes quick popup and invalidates its captured action',
    (tester) async {
      final repository = AudienceTestRepository()
        ..current = audienceState(
          intent: EventAudienceStatus.going,
          version: 1,
        );
      final sessions = AudienceTestSessions(audienceSession());
      var drafts = 0;
      await _pump(
        tester,
        repository,
        sessions: sessions,
        onProfileShare: (_) async => drafts++,
      );
      await _tap(tester, 'event-audience-going');
      final oldProfile = _popupAction(tester, 'event-audience-quick-profile');
      sessions.replace(audienceSession(user: 'other', token: 'other'));
      oldProfile();
      await tester.pumpAndSettle();
      expect(drafts, 0);
      expect(find.byType(BottomSheet), findsNothing);
      expect(find.byKey(const Key('event-audience-quick-menu')), findsNothing);
      expect(repository.writes, isEmpty);
    },
  );

  for (final unavailable in [false, true]) {
    testWidgets(
      'past/unavailable detail keeps only the selected removal button unavailable=$unavailable',
      (tester) async {
        final selected = unavailable ? 'thinking' : 'going';
        final other = unavailable ? 'going' : 'thinking';
        final repository = AudienceTestRepository()
          ..current = audienceState(
            intent: unavailable
                ? EventAudienceStatus.thinking
                : EventAudienceStatus.going,
            published: !unavailable,
            note: unavailable ? null : 'Geçmiş',
            version: 4,
            ended: !unavailable,
            available: !unavailable,
          );
        await _pump(
          tester,
          repository,
          sessions: AudienceTestSessions(
            audienceSession(
              role: unavailable ? 'ROLE_MUSICIAN' : 'ROLE_LISTENER',
            ),
          ),
        );
        _expectNoDetailStatusRow();
        expect(find.byKey(Key('event-audience-$selected')), findsOneWidget);
        expect(find.byKey(Key('event-audience-$other')), findsNothing);
        await _tap(tester, 'event-audience-$selected');
        expect(repository.writes, isEmpty);
        expect(find.byType(BottomSheet), findsNothing);
        expect(
          find.byWidgetPredicate((widget) => widget is PopupMenuItem),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('event-audience-quick-profile')),
          findsNothing,
        );
        await _tap(tester, 'event-audience-quick-clear');
        expect(repository.writes, hasLength(1));
        expect(repository.writes.single.intent, EventAudienceStatus.none);
        expect(repository.writes.single.published, isFalse);
        expect(repository.writes.single.note, isNull);
        expect(repository.writes.single.version, 4);
        expect(repository.current.intent, EventAudienceStatus.none);
        expect(find.byKey(Key('event-audience-$selected')), findsNothing);
        _expectNoDetailStatusRow();
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'past/unavailable plan management retains only removal actions unavailable=$unavailable',
      (tester) async {
        final repository = AudienceTestRepository()
          ..current = audienceState(
            intent: EventAudienceStatus.going,
            published: true,
            note: 'Geçmiş',
            version: 4,
            ended: !unavailable,
            available: !unavailable,
          );
        await _pumpLauncher(
          tester,
          repository,
          AudienceTestSessions(audienceSession()),
        );
        await tester.tap(find.text('Ben de gidiyorum'));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('event-audience-management-going')),
          findsNothing,
        );
        expect(
          find.byKey(const Key('event-audience-profile-share')),
          findsNothing,
        );
        expect(
          find.byKey(const Key('event-audience-external-share')),
          findsNothing,
        );
        await _tap(tester, 'event-audience-unpublish');
        expect(repository.current.publishedOnProfile, isFalse);
        await tester.tap(find.text('Ben de gidiyorum'));
        await tester.pumpAndSettle();
        await _tap(tester, 'event-audience-clear');
        expect(repository.current.intent, EventAudienceStatus.none);
        expect(repository.current.note, isNull);
        expect(find.byType(SnackBar), findsNothing);
      },
    );
  }

  testWidgets(
    'listener lacking server publication capability gets no profile CTA',
    (tester) async {
      final repository = AudienceTestRepository()
        ..current = audienceState(canPublish: false);
      await _pump(tester, repository);
      await _tap(tester, 'event-audience-going');
      expect(find.byType(SnackBarAction), findsNothing);
      await _tap(tester, 'event-audience-going');
      expect(
        find.byKey(const Key('event-audience-quick-profile')),
        findsNothing,
      );
    },
  );

  testWidgets(
    'row helper reads on tap and confirms on host after sheet is fully dismissed',
    (tester) async {
      final repository = AudienceTestRepository();
      final sessions = AudienceTestSessions(audienceSession());
      var drafts = 0;
      await _pumpLauncher(
        tester,
        repository,
        sessions,
        onProfileShare: (_) async {
          expect(find.byType(BottomSheet), findsNothing);
          drafts++;
        },
      );
      expect(repository.reads, isEmpty);
      await tester.tap(find.text('Ben de gidiyorum'));
      await tester.pumpAndSettle();
      expect(repository.reads, ['listener']);
      await _tap(tester, 'event-audience-management-going');
      expect(find.byType(BottomSheet), findsNothing);
      expect(find.text('Gidiyorum olarak işaretlendi.'), findsOneWidget);
      await tester.tap(
        find.byKey(const Key('event-audience-snackbar-profile')),
      );
      await tester.pumpAndSettle();
      expect(drafts, 1);
      expect(repository.writes.single.published, isFalse);
    },
  );

  testWidgets(
    'row-helper confirmation session cleanup safely disposes its controller',
    (tester) async {
      final repository = AudienceTestRepository();
      final sessions = AudienceTestSessions(audienceSession());
      await _pumpLauncher(tester, repository, sessions);
      await tester.tap(find.text('Ben de gidiyorum'));
      await tester.pumpAndSettle();
      await _tap(tester, 'event-audience-management-going');
      sessions.replace(const AuthSession.guest());
      await tester.pumpAndSettle();
      expect(find.byType(SnackBar), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'failed row mutation stays recoverable and requires GET before another write',
    (tester) async {
      final repository = AudienceTestRepository()
        ..onWrite = (_) async =>
            const Result.failure(AppError(code: '9921', message: 'reload'));
      await _pumpLauncher(
        tester,
        repository,
        AudienceTestSessions(audienceSession()),
      );
      await tester.tap(find.text('Ben de gidiyorum'));
      await tester.pumpAndSettle();
      await _tap(tester, 'event-audience-management-going');
      expect(
        find.byKey(const Key('event-audience-management')),
        findsOneWidget,
      );
      expect(
        find.text('Seçimin doğrulanamadı. Güncel durumu yeniden yükle.'),
        findsOneWidget,
      );
      expect(repository.writes.length, 1);
      expect(
        tester
            .widget<GradientOutlineButton>(
              find.byKey(const Key('event-audience-management-going')),
            )
            .onPressed,
        isNull,
      );
      repository.onWrite = null;
      await tester.tap(find.text('Yeniden yükle'));
      await tester.pumpAndSettle();
      expect(repository.reads.length, 2);
      await _tap(tester, 'event-audience-management-going');
      expect(find.byType(BottomSheet), findsNothing);
      expect(find.text('Gidiyorum olarak işaretlendi.'), findsOneWidget);
    },
  );

  for (final profile in [true, false]) {
    testWidgets(
      'existing plan action leaves the single sheet before navigation profile=$profile',
      (tester) async {
        final repository = AudienceTestRepository()
          ..current = audienceState(
            intent: EventAudienceStatus.going,
            version: 1,
          );
        var routed = false;
        Future<void> complete() async {
          expect(find.byType(BottomSheet), findsNothing);
          routed = true;
        }

        await _pumpLauncher(
          tester,
          repository,
          AudienceTestSessions(audienceSession()),
          onProfileShare: (_) => complete(),
          onExternalShare: (_) => complete(),
        );
        await tester.tap(find.text('Ben de gidiyorum'));
        await tester.pumpAndSettle();
        expect(find.text('Seçimin: Gidiyorum'), findsOneWidget);
        await _tap(
          tester,
          profile
              ? 'event-audience-profile-share'
              : 'event-audience-external-share',
        );
        expect(routed, isTrue);
        expect(repository.writes, isEmpty);
      },
    );
  }

  testWidgets(
    '320px 200 percent text supports compact feedback and readable anchored popup',
    (tester) async {
      final repository = AudienceTestRepository();
      await _pump(tester, repository, width: 320, scale: 2);
      await _tap(tester, 'event-audience-thinking');
      expect(find.text('Düşünüyorum olarak işaretlendi.'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await _tap(tester, 'event-audience-thinking');
      expect(find.byType(TextField), findsNothing);
      expect(find.byType(BottomSheet), findsNothing);
      expect(
        find.byKey(const Key('event-audience-quick-clear')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('event-audience-quick-profile')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.tapAt(const Offset(310, 830));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('event-audience-quick-menu')), findsNothing);
      expect(repository.writes.length, 1);
    },
  );
}

VoidCallback _action(WidgetTester tester, String key) =>
    tester.widget<GradientOutlineButton>(find.byKey(Key(key))).onPressed!;
void _expectNoDetailStatusRow() {
  expect(find.byKey(const Key('event-audience-current')), findsNothing);
  expect(find.byKey(const Key('event-audience-manage')), findsNothing);
  expect(find.textContaining('Seçimin:'), findsNothing);
  expect(find.text('Seçimimi düzenle'), findsNothing);
}

VoidCallback _popupAction(WidgetTester tester, String key) => tester
    .widget<InkWell>(
      find
          .descendant(of: find.byKey(Key(key)), matching: find.byType(InkWell))
          .first,
    )
    .onTap!;
VoidCallback _snackAction(WidgetTester tester) => tester
    .widget<SnackBarAction>(
      find.byKey(const Key('event-audience-snackbar-profile')),
    )
    .onPressed;
Future<void> _tap(WidgetTester tester, String key) async {
  await tester.tap(find.byKey(Key(key)));
  await tester.pumpAndSettle();
}

Future<void> _pump(
  WidgetTester tester,
  AudienceTestRepository repository, {
  AudienceTestSessions? sessions,
  AudienceExternalShare? onExternalShare,
  AudienceProfileShare? onProfileShare,
  double width = 390,
  double scale = 1,
  String eventId = audienceEventId,
  bool showControls = true,
}) async {
  await tester.binding.setSurfaceSize(Size(width, 844));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.navy,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: showControls
              ? EventAudienceControls(
                  eventId: eventId,
                  eventTitle: 'Canlı müzik akşamı',
                  repository: repository,
                  sessions: sessions ?? AudienceTestSessions(audienceSession()),
                  onExternalShare: onExternalShare,
                  onProfileShare: onProfileShare,
                )
              : const SizedBox.shrink(),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpLauncher(
  WidgetTester tester,
  AudienceTestRepository repository,
  AudienceTestSessions sessions, {
  AudienceExternalShare? onExternalShare,
  AudienceProfileShare? onProfileShare,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.navy,
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showEventAudienceSheet(
              context,
              eventId: audienceEventId,
              eventTitle: 'Canlı müzik akşamı',
              repository: repository,
              sessions: sessions,
              onExternalShare: onExternalShare,
              onProfileShare: onProfileShare,
            ),
            child: const Text('Ben de gidiyorum'),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
