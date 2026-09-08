import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session_manager.dart';
import 'package:soundconnect_23_12_25codx/core/di/service_locator.dart';
import 'package:soundconnect_23_12_25codx/core/error/app_error.dart';
import 'package:soundconnect_23_12_25codx/core/error/result.dart';
import 'package:soundconnect_23_12_25codx/modules/dm/presentation/cubit/dm_badge_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/dm/presentation/cubit/dm_badge_state.dart';
import 'package:soundconnect_23_12_25codx/modules/event_audience/domain/event_audience_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/event_audience/presentation/event_audience_profile_draft.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/listener_profile.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/listener_visibility_mode.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/listener_profile_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/cubit/listener_profile_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/listener_event_draft_composer.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/listener_event_post_card.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/listener_profile_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/profile_public_bottom_bar.dart';
import 'package:soundconnect_23_12_25codx/shared/theme/app_theme.dart';
import 'package:soundconnect_23_12_25codx/shared/widgets/gradient_outline_button.dart';

import 'support/event_audience_fakes.dart';

void main() {
  setUp(() async => serviceLocator.reset());
  tearDown(() async => serviceLocator.reset());

  for (final intent in [
    EventAudienceStatus.going,
    EventAudienceStatus.thinking,
  ]) {
    testWidgets(
      '$intent opens fresh inline draft without writes, publishes only explicitly',
      (tester) async {
        final repository = _Repository()
          ..current = audienceState(intent: intent, version: 7);
        final completed = <bool>[];
        await _mount(tester, repository, onFinished: completed.add);
        expect(repository.reads, ['listener']);
        expect(repository.writes, isEmpty);
        expect(find.byType(ListenerEventPostCard), findsOneWidget);
        expect(
          find.textContaining('Taslak · Henüz paylaşılmadı'),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('listener-event-draft-note')),
          findsOneWidget,
        );
        await tester.enterText(_note, ' Beraber gidelim! ');
        expect(repository.writes, isEmpty);
        await _publish(tester);
        expect(repository.writes.single, (
          intent: intent,
          published: true,
          note: 'Beraber gidelim!',
          version: 7,
          user: 'listener',
        ));
        expect(completed, [true]);
      },
    );
  }

  testWidgets('description is optional and blank publishes null', (
    tester,
  ) async {
    final repository = _Repository();
    await _mount(tester, repository);
    await _publish(tester);
    expect(repository.writes.single.note, isNull);
  });

  testWidgets(
    'initial read failure does not imply a publication attempt and can retry',
    (tester) async {
      final repository = _Repository()
        ..onRead = () async =>
            const Result.failure(AppError(code: 'network', message: 'offline'));
      await _mount(tester, repository);
      expect(
        find.text('Etkinlik seçimin yüklenemedi. Yeniden kontrol edebilirsin.'),
        findsOneWidget,
      );
      expect(repository.writes, isEmpty);
      repository.onRead = null;
      await _tap(tester, find.text('Güncel durumu kontrol et'));
      expect(_note, findsOneWidget);
      expect(repository.writes, isEmpty);
    },
  );

  testWidgets('pristine cancel leaves the saved private intent unchanged', (
    tester,
  ) async {
    final repository = _Repository();
    final completed = <bool>[];
    await _mount(tester, repository, onFinished: completed.add);
    await _tap(tester, find.byKey(const Key('listener-event-draft-cancel')));
    expect(completed, [false]);
    expect(repository.writes, isEmpty);
  });

  testWidgets(
    'dirty cancel asks once, keep retains text, discard performs no write',
    (tester) async {
      final repository = _Repository();
      final completed = <bool>[];
      await _mount(tester, repository, onFinished: completed.add);
      await tester.enterText(_note, 'Kaybolmasın');
      await _tap(tester, find.byKey(const Key('listener-event-draft-cancel')));
      expect(
        find.byKey(const Key('listener-event-draft-leave-dialog')),
        findsOneWidget,
      );
      await _tap(tester, find.text('Düzenlemeye devam et'));
      expect(_text(tester), 'Kaybolmasın');
      expect(completed, isEmpty);
      await _tap(tester, find.byKey(const Key('listener-event-draft-cancel')));
      await _tap(tester, find.text('Taslağı bırak'));
      expect(completed, [false]);
      expect(repository.writes, isEmpty);
    },
  );

  testWidgets(
    'existing publication note is prefilled without accidental update',
    (tester) async {
      final repository = _Repository()
        ..current = audienceState(
          intent: EventAudienceStatus.going,
          published: true,
          note: 'Önceki açıklama',
          version: 4,
        );
      await _mount(tester, repository);
      expect(_text(tester), 'Önceki açıklama');
      expect(find.textContaining('Değişiklikler paylaşılmadı'), findsOneWidget);
      expect(repository.writes, isEmpty);
      await tester.enterText(_note, 'Yeni açıklama');
      await _publish(tester);
      expect(repository.writes.single.note, 'Yeni açıklama');
      expect(repository.writes.single.version, 4);
    },
  );

  testWidgets(
    '500 Unicode codepoints accepted, 501 rejected, CRLF normalized',
    (tester) async {
      final repository = _Repository();
      await _mount(tester, repository);
      final fiveHundred = List.filled(500, '😀').join();
      await tester.enterText(_note, fiveHundred);
      expect(_text(tester).runes.length, 500);
      await tester.enterText(_note, '${fiveHundred}x');
      expect(_text(tester), fiveHundred);
      await tester.enterText(_note, 'Bir\r\nİki\rÜç');
      expect(_text(tester), 'Bir\nİki\nÜç');
      await _publish(tester);
      expect(repository.writes.single.note, 'Bir\nİki\nÜç');
    },
  );

  for (final scenario in ['none', 'ended', 'deleted', 'forbidden']) {
    testWidgets(
      '$scenario fresh intent cannot be published by stale profile CTA',
      (tester) async {
        final repository = _Repository()
          ..current = audienceState(
            intent: scenario == 'none'
                ? EventAudienceStatus.none
                : EventAudienceStatus.going,
            ended: scenario == 'ended',
            available: scenario != 'deleted',
            canPublish: scenario != 'forbidden',
          );
        await _mount(tester, repository);
        final publish = tester.widget<GradientOutlineButton>(
          find.byKey(const Key('listener-event-draft-publish')),
        );
        expect(publish.onPressed, isNull);
        expect(repository.writes, isEmpty);
      },
    );
  }

  for (final scenario in [
    'ghost',
    'other-owner',
    'musician',
    'inactive',
    'onboarding',
  ]) {
    testWidgets(
      '$scenario profile draft is hidden and performs no reads/writes',
      (tester) async {
        final repository = _Repository();
        final session = scenario == 'musician'
            ? audienceSession(role: 'ROLE_MUSICIAN')
            : scenario == 'inactive'
            ? audienceSession(status: 'INACTIVE')
            : audienceSession();
        await _mount(
          tester,
          repository,
          sessions: AudienceTestSessions(session),
          profile: _profile(
            ghost: scenario == 'ghost',
            userId: scenario == 'other-owner' ? 'other' : 'listener',
            choice: scenario != 'onboarding',
          ),
        );
        expect(_note, findsNothing);
        expect(repository.reads, isEmpty);
        expect(repository.writes, isEmpty);
      },
    );
  }

  testWidgets(
    'identity replacement clears note immediately and never reads replacement account',
    (tester) async {
      final repository = _Repository();
      final sessions = AudienceTestSessions(audienceSession());
      await _mount(tester, repository, sessions: sessions);
      await tester.enterText(_note, 'Özel taslağım');
      sessions.replace(audienceSession(user: 'other'));
      await tester.pumpAndSettle();
      expect(_note, findsNothing);
      expect(repository.reads, ['listener']);
      expect(repository.writes, isEmpty);
      sessions.replace(audienceSession());
      await tester.pumpAndSettle();
      expect(_note, findsNothing);
    },
  );

  testWidgets('delayed fresh load cannot populate a replacement account', (
    tester,
  ) async {
    final waiting = Completer<Result<EventAudienceState>>();
    final repository = _Repository()..onRead = () => waiting.future;
    final sessions = AudienceTestSessions(audienceSession());
    await _mount(tester, repository, sessions: sessions, settle: false);
    sessions.replace(audienceSession(user: 'other'));
    waiting.complete(
      Result.success(
        audienceState(intent: EventAudienceStatus.going, note: 'Gizli'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Gizli'), findsNothing);
    expect(repository.reads, ['listener']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('publishing is single flight, input and leaving stay disabled', (
    tester,
  ) async {
    final waiting = Completer<Result<EventAudienceState>>();
    final repository = _Repository()..onWrite = (_) => waiting.future;
    final key = GlobalKey<ListenerEventDraftComposerState>();
    await _mount(tester, repository, composerKey: key);
    await tester.enterText(_note, 'Bir kez');
    final callback = tester
        .widget<GradientOutlineButton>(
          find.byKey(const Key('listener-event-draft-publish')),
        )
        .onPressed!;
    callback();
    callback();
    await tester.pump();
    expect(repository.writes.length, 1);
    expect(tester.widget<TextField>(_note).enabled, isFalse);
    expect(await key.currentState!.canLeave(), isFalse);
    waiting.complete(
      Result.success(
        audienceState(
          intent: EventAudienceStatus.going,
          published: true,
          note: 'Bir kez',
          version: 2,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'failed publication keeps text, blocks blind retry, explicit refresh reviews latest CAS',
    (tester) async {
      final repository = _Repository()
        ..onWrite = (_) async =>
            const Result.failure(AppError(code: '409', message: 'conflict'));
      await _mount(tester, repository);
      await tester.enterText(_note, 'Benim açıklamam');
      await _publish(tester);
      expect(_text(tester), 'Benim açıklamam');
      expect(
        tester
            .widget<GradientOutlineButton>(
              find.byKey(const Key('listener-event-draft-publish')),
            )
            .onPressed,
        isNull,
      );
      repository.current = audienceState(
        intent: EventAudienceStatus.thinking,
        note: null,
        version: 8,
      );
      repository.onWrite = null;
      await _tap(tester, find.text('Güncel durumu kontrol et'));
      expect(repository.writes.length, 1);
      expect(_text(tester), 'Benim açıklamam');
      await _publish(tester);
      expect(repository.writes.last.version, 8);
      expect(repository.writes.last.intent, EventAudienceStatus.thinking);
    },
  );

  testWidgets(
    'ambiguous successful server write is reconciled without duplicate publish',
    (tester) async {
      final repository = _Repository();
      repository.onWrite = (write) async {
        repository.current = audienceState(
          intent: write.intent,
          published: true,
          note: write.note,
          version: write.version + 1,
        );
        return const Result.failure(
          AppError(code: 'network', message: 'unknown'),
        );
      };
      final completed = <bool>[];
      await _mount(tester, repository, onFinished: completed.add);
      await tester.enterText(_note, 'Sunucuya ulaştı');
      await _publish(tester);
      expect(completed, isEmpty);
      await _tap(tester, find.text('Güncel durumu kontrol et'));
      expect(completed, [true]);
      expect(repository.writes.length, 1);
    },
  );

  testWidgets(
    'retained publish callback cannot retry an uncertain write after automatic readback',
    (tester) async {
      final repository = _Repository()
        ..onWrite = (_) async =>
            const Result.failure(AppError(code: 'network', message: 'unknown'));
      await _mount(tester, repository);
      await tester.enterText(_note, 'Korunacak açıklama');
      final oldPublish = tester
          .widget<GradientOutlineButton>(
            find.byKey(const Key('listener-event-draft-publish')),
          )
          .onPressed!;
      await _publish(tester);
      expect(repository.writes, hasLength(1));
      repository.onWrite = null;
      repository.signal.value++;
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<GradientOutlineButton>(
              find.byKey(const Key('listener-event-draft-publish')),
            )
            .onPressed,
        isNull,
      );
      oldPublish();
      await tester.pumpAndSettle();
      expect(repository.writes, hasLength(1));
      expect(_text(tester), 'Korunacak açıklama');
    },
  );

  testWidgets('retained discard response cannot pop a newer route', (
    tester,
  ) async {
    final repository = _Repository();
    final composer = GlobalKey<ListenerEventDraftComposerState>();
    await _mount(tester, repository, composerKey: composer);
    await tester.enterText(_note, 'Korunacak taslak');
    FocusManager.instance.primaryFocus?.unfocus();
    final leave = composer.currentState!.canLeave();
    await tester.pumpAndSettle();
    final discard = tester
        .widget<GradientOutlineButton>(
          find.widgetWithText(GradientOutlineButton, 'Taslağı bırak'),
        )
        .onPressed!;
    final keep = tester
        .widget<TextButton>(
          find.widgetWithText(TextButton, 'Düzenlemeye devam et'),
        )
        .onPressed!;
    final navigator = Navigator.of(composer.currentContext!);
    unawaited(
      navigator.push<bool>(
        MaterialPageRoute<bool>(
          builder: (_) => const Scaffold(body: Text('Daha yeni sayfa')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    discard();
    await tester.pumpAndSettle();
    expect(find.text('Daha yeni sayfa'), findsOneWidget);
    navigator.pop(false);
    await tester.pumpAndSettle();
    keep();
    await tester.pumpAndSettle();
    expect(await leave, isFalse);
    expect(_text(tester), 'Korunacak taslak');
    expect(repository.writes, isEmpty);
  });

  for (final phase in ['before frame', 'visible', 'covered']) {
    testWidgets('account replacement dismisses discard dialog when $phase', (
      tester,
    ) async {
      final repository = _Repository();
      final sessions = AudienceTestSessions(audienceSession());
      final composer = GlobalKey<ListenerEventDraftComposerState>();
      await _mount(
        tester,
        repository,
        sessions: sessions,
        composerKey: composer,
      );
      await tester.enterText(_note, 'Eski hesabın taslağı');
      FocusManager.instance.primaryFocus?.unfocus();
      final navigator = Navigator.of(composer.currentContext!);
      final leave = composer.currentState!.canLeave();
      if (phase != 'before frame') await tester.pumpAndSettle();
      if (phase == 'covered') {
        unawaited(
          navigator.push<void>(
            MaterialPageRoute<void>(
              builder: (_) => const Scaffold(body: Text('Güncel sayfa')),
            ),
          ),
        );
        await tester.pumpAndSettle();
      }
      sessions.replace(audienceSession(user: 'other'));
      await tester.pumpAndSettle();
      expect(await leave, isFalse);
      expect(
        find.byKey(
          const Key('listener-event-draft-leave-dialog'),
          skipOffstage: false,
        ),
        findsNothing,
      );
      if (phase == 'covered') {
        expect(find.text('Güncel sayfa'), findsOneWidget);
      }
      expect(repository.writes, isEmpty);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('disposed composer cannot approve a retained leave request', (
    tester,
  ) async {
    final repository = _Repository();
    final composer = GlobalKey<ListenerEventDraftComposerState>();
    await _mount(tester, repository, composerKey: composer);
    final state = composer.currentState!;
    await tester.pumpWidget(const SizedBox.shrink());
    expect(await state.canLeave(), isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'external repository refresh cannot silently rebase a typed draft',
    (tester) async {
      final repository = _Repository();
      await _mount(tester, repository);
      await tester.enterText(_note, 'Yazdığım açıklama');
      repository.current = audienceState(
        intent: EventAudienceStatus.thinking,
        published: true,
        note: 'Başka cihazdan',
        version: 9,
      );
      repository.signal.value++;
      await tester.pumpAndSettle();
      expect(_text(tester), 'Yazdığım açıklama');
      expect(
        tester
            .widget<GradientOutlineButton>(
              find.byKey(const Key('listener-event-draft-publish')),
            )
            .onPressed,
        isNull,
      );
      expect(repository.writes, isEmpty);
      await _tap(tester, find.text('Güncel durumu kontrol et'));
      expect(repository.writes, isEmpty);
      await _publish(tester);
      expect(repository.writes.single.version, 9);
      expect(repository.writes.single.note, 'Yazdığım açıklama');
    },
  );

  testWidgets(
    'clear during conflict reload cannot become a new intent on Publish',
    (tester) async {
      final repository = _Repository();
      await _mount(tester, repository);
      repository.current = audienceState(version: 9);
      repository.signal.value++;
      await tester.pumpAndSettle();
      await _tap(tester, find.text('Güncel durumu kontrol et'));
      expect(
        tester
            .widget<GradientOutlineButton>(
              find.byKey(const Key('listener-event-draft-publish')),
            )
            .onPressed,
        isNull,
      );
      expect(repository.writes, isEmpty);
    },
  );

  testWidgets('account change during pending publish ignores old response', (
    tester,
  ) async {
    final waiting = Completer<Result<EventAudienceState>>();
    final repository = _Repository()..onWrite = (_) => waiting.future;
    final sessions = AudienceTestSessions(audienceSession());
    final completed = <bool>[];
    await _mount(
      tester,
      repository,
      sessions: sessions,
      onFinished: completed.add,
    );
    tester
        .widget<GradientOutlineButton>(
          find.byKey(const Key('listener-event-draft-publish')),
        )
        .onPressed!();
    await tester.pump();
    sessions.replace(audienceSession(user: 'other'));
    waiting.complete(
      Result.success(
        audienceState(
          intent: EventAudienceStatus.going,
          published: true,
          version: 2,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(completed, isEmpty);
    expect(_note, findsNothing);
    expect(repository.writes.single.user, 'listener');
    expect(repository.reads, ['listener']);
  });

  testWidgets(
    'real profile reveals inline draft, retains Overthinking, cancel restores event feed',
    (tester) async {
      final repository = _Repository();
      await _mountProfile(tester, repository);
      expect(_note, findsOneWidget);
      expect(tester.getRect(_note).top, lessThan(700));
      expect(repository.publicReads, 0);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget.runtimeType.toString() == '_ListenerOverthinkingPostCard',
        ),
        findsOneWidget,
      );
      await _tap(tester, find.byKey(const Key('listener-event-draft-cancel')));
      expect(_note, findsNothing);
      expect(repository.publicReads, 1);
      expect(repository.writes, isEmpty);
    },
  );

  for (final target in ['back', 'bottom', 'menu']) {
    testWidgets('real profile dirty draft guards $target navigation', (
      tester,
    ) async {
      final repository = _Repository();
      await _mountProfile(tester, repository);
      await tester.enterText(_note, 'Taslağım');
      if (target == 'back') {
        await tester.binding.handlePopRoute();
      } else if (target == 'bottom') {
        final bar = tester.widget<ProfilePublicBottomBar>(
          find.byType(ProfilePublicBottomBar),
        );
        unawaited(Future.sync(bar.onBeforeNavigate!));
      } else {
        await tester.tap(find.byKey(const Key('listener-owner-menu')));
      }
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('listener-event-draft-leave-dialog')),
        findsOneWidget,
      );
      await _tap(tester, find.text('Düzenlemeye devam et'));
      expect(_text(tester), 'Taslağım');
      expect(repository.writes, isEmpty);
    });
  }

  testWidgets(
    'real profile keeps draft and leave guard when scrolled offscreen',
    (tester) async {
      final repository = _Repository();
      await _mountProfile(tester, repository);
      await tester.enterText(_note, 'Sayfa kayınca kaybolma');
      FocusManager.instance.primaryFocus?.unfocus();
      final list = tester.widget<ListView>(
        find.byKey(const Key('listener-owner-profile-content')),
      );
      list.controller!.jumpTo(0);
      await tester.pumpAndSettle();
      expect(_text(tester), 'Sayfa kayınca kaybolma');
      expect(repository.reads.length, 1);
      final before = tester
          .widget<ProfilePublicBottomBar>(find.byType(ProfilePublicBottomBar))
          .onBeforeNavigate!;
      unawaited(Future.sync(before));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('listener-event-draft-leave-dialog')),
        findsOneWidget,
      );
      await _tap(tester, find.text('Düzenlemeye devam et'));
      list.controller!.jumpTo(list.controller!.position.maxScrollExtent);
      await tester.pumpAndSettle();
      expect(_text(tester), 'Sayfa kayınca kaybolma');
      expect(repository.writes, isEmpty);
    },
  );

  testWidgets(
    'offscreen pending publish retains single flight and navigation blockade',
    (tester) async {
      final waiting = Completer<Result<EventAudienceState>>();
      final repository = _Repository()..onWrite = (_) => waiting.future;
      await _mountProfile(tester, repository);
      tester
          .widget<GradientOutlineButton>(
            find.byKey(const Key('listener-event-draft-publish')),
          )
          .onPressed!();
      await tester.pump();
      final list = tester.widget<ListView>(
        find.byKey(const Key('listener-owner-profile-content')),
      );
      list.controller!.jumpTo(0);
      await tester.pump();
      final before = tester
          .widget<ProfilePublicBottomBar>(find.byType(ProfilePublicBottomBar))
          .onBeforeNavigate!;
      expect(await before(), isFalse);
      expect(repository.writes.length, 1);
      expect(repository.reads.length, 1);
      waiting.complete(
        Result.success(
          audienceState(
            intent: EventAudienceStatus.going,
            published: true,
            version: 2,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ListenerEventDraftComposer), findsNothing);
    },
  );

  testWidgets(
    'new route during discard exit cannot clear draft or permit old navigation',
    (tester) async {
      await _mountProfile(tester, _Repository());
      await tester.enterText(_note, 'Korunan taslak');
      final navigator = Navigator.of(
        tester.element(find.byType(ListenerProfileScreen)),
      );
      final before = tester
          .widget<ProfilePublicBottomBar>(find.byType(ProfilePublicBottomBar))
          .onBeforeNavigate!;
      final result = Future.sync(before);
      await tester.pumpAndSettle();
      navigator.pop(true);
      unawaited(
        navigator.push<void>(
          MaterialPageRoute(
            builder: (_) => const Scaffold(body: Text('NEW ROUTE')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(await result, isFalse);
      expect(await before(), isFalse);
      navigator.pop();
      await tester.pumpAndSettle();
      expect(_text(tester), 'Korunan taslak');
    },
  );

  testWidgets(
    'profile ghost refresh discards draft and standard restoration does not resurrect it',
    (tester) async {
      final repository = _Repository();
      final profiles = _Profiles();
      final cubit = await _mountProfile(tester, repository, profiles: profiles);
      await tester.enterText(_note, 'Gizli taslak');
      profiles.current = _profile(ghost: true);
      await cubit.loadMyProfile();
      await tester.pumpAndSettle();
      expect(_note, findsNothing);
      profiles.current = _profile();
      await cubit.loadMyProfile();
      await tester.pumpAndSettle();
      expect(_note, findsNothing);
      expect(find.text('Gizli taslak'), findsNothing);
      expect(repository.writes, isEmpty);
    },
  );

  testWidgets(
    'ghost projection invalidation releases system back immediately',
    (tester) async {
      final profiles = _Profiles();
      final cubit = await _mountProfile(
        tester,
        _Repository(),
        profiles: profiles,
        pushed: true,
      );
      await tester.enterText(_note, 'Gizli taslak');
      profiles.current = _profile(ghost: true);
      await cubit.loadMyProfile();
      await tester.pumpAndSettle();
      expect(_note, findsNothing);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('OPEN PROFILE'), findsOneWidget);
      expect(find.byType(ListenerProfileScreen), findsNothing);
    },
  );

  for (final scale in [1.0, 2.0]) {
    testWidgets('draft actions and note remain usable at 320px/$scale text', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await _mount(tester, _Repository(), scale: scale);
      await tester.enterText(_note, 'Bir açıklama');
      await _tap(tester, find.byKey(const Key('listener-event-draft-cancel')));
      await _tap(tester, find.text('Düzenlemeye devam et'));
      expect(tester.takeException(), isNull);
    });
  }

  if (Platform.environment['LISTENER_DRAFT_RENDER_DIR'] != null) {
    testWidgets('render real owner profile inline draft with real fonts', (
      tester,
    ) async {
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
      final capture = GlobalKey();
      await _mountProfile(tester, _Repository(), capture: capture);
      await tester.enterText(
        _note,
        'Güzel müzik, güzel bir akşam. Kimler geliyor?',
      );
      tester.testTextInput.hide();
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        final context = tester.element(find.byType(ListenerProfileScreen));
        for (final asset in [
          'assets/logo.png',
          'assets/Logoyanyana.png',
          'assets/ME!2-transparent.png',
          'assets/confined.png',
        ]) {
          await precacheImage(AssetImage(asset), context);
        }
        for (final rendered in tester.widgetList<Image>(find.byType(Image))) {
          if (context.mounted) await precacheImage(rendered.image, context);
        }
      });
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.runAsync(() async {
        final pixels =
            await (capture.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary)
                .toImage(pixelRatio: 2);
        final bytes = await pixels.toByteData(format: ui.ImageByteFormat.png);
        final output = Platform.environment['LISTENER_DRAFT_RENDER_DIR']!;
        await Directory(output).create(recursive: true);
        await File(
          '$output/listener-profile-draft.png',
        ).writeAsBytes(bytes!.buffer.asUint8List());
        pixels.dispose();
      });
    });
  }
}

final _note = find.byKey(const Key('listener-event-draft-note'));
String _text(WidgetTester tester) =>
    tester.widget<TextField>(_note).controller!.text;
Future<void> _publish(WidgetTester tester) =>
    _tap(tester, find.byKey(const Key('listener-event-draft-publish')));
Future<void> _tap(WidgetTester tester, Finder finder) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _mount(
  WidgetTester tester,
  _Repository repository, {
  AudienceTestSessions? sessions,
  ListenerProfile? profile,
  ValueChanged<bool>? onFinished,
  GlobalKey<ListenerEventDraftComposerState>? composerKey,
  bool settle = true,
  double scale = 1,
}) async {
  final manager = sessions ?? AudienceTestSessions(audienceSession());
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
          padding: const EdgeInsets.all(20),
          child: ListenerEventDraftComposer(
            key: composerKey,
            draft: EventAudienceProfileDraftArgs(
              eventId: audienceEventId,
              expectedSession: manager.session,
            ),
            profile: profile ?? _profile(),
            repository: repository,
            sessions: manager,
            onFinished: onFinished ?? (_) {},
          ),
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

Future<ListenerProfileCubit> _mountProfile(
  WidgetTester tester,
  _Repository repository, {
  _Profiles? profiles,
  GlobalKey? capture,
  bool pushed = false,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final sessions = AudienceTestSessions(audienceSession());
  serviceLocator
    ..registerSingleton<AuthSessionManager>(sessions)
    ..registerSingleton<EventAudienceRepository>(repository)
    ..registerSingleton<DmBadgeCubit>(_Badges());
  final cubit = ListenerProfileCubit(profiles ?? _Profiles());
  final screen = ListenerProfileScreen(
    cubitFactory: () => cubit,
    eventDraft: EventAudienceProfileDraftArgs(
      eventId: audienceEventId,
      expectedSession: sessions.session,
    ),
  );
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: capture == null
          ? AppTheme.navy
          : AppTheme.navy.copyWith(
              textTheme: AppTheme.navy.textTheme.apply(fontFamily: 'Roboto'),
              primaryTextTheme: AppTheme.navy.primaryTextTheme.apply(
                fontFamily: 'Roboto',
              ),
            ),
      builder: (context, child) => RepaintBoundary(key: capture, child: child!),
      home: pushed
          ? Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => Navigator.of(
                    context,
                  ).push<void>(MaterialPageRoute(builder: (_) => screen)),
                  child: const Text('OPEN PROFILE'),
                ),
              ),
            )
          : screen,
    ),
  );
  if (pushed) {
    await tester.tap(find.text('OPEN PROFILE'));
  }
  await tester.pumpAndSettle();
  return cubit;
}

ListenerProfile _profile({
  bool ghost = false,
  String userId = 'listener',
  bool choice = true,
}) => ListenerProfile(
  id: 'profile',
  userId: userId,
  username: 'deniz',
  bio: 'Müziğin peşinde.',
  profilePictureUrl: null,
  followerCount: 12,
  followingCount: 8,
  visibilityChoiceCompleted: choice,
  visibilityMode: ghost
      ? ListenerVisibilityMode.ghost
      : ListenerVisibilityMode.standard,
);

class _Profiles extends ListenerProfileRepository {
  ListenerProfile current = _profile();
  @override
  Future<Result<ListenerProfile>> getMyProfile() async =>
      Result.success(current);
}

class _Repository extends AudienceTestRepository {
  _Repository() {
    current = audienceState(intent: EventAudienceStatus.going, version: 1);
  }
  int publicReads = 0;
  @override
  Future<Result<EventAudiencePage<EventAudiencePost>>> listPublic(
    String listenerProfileId, {
    String? expectedSessionKey,
    EventAudiencePeriod period = EventAudiencePeriod.all,
    int page = 0,
    int size = 20,
  }) async {
    publicReads++;
    return Result.success(
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
}

class _Badges extends Cubit<DmBadgeState> implements DmBadgeCubit {
  _Badges() : super(const DmBadgeState.initial());
  @override
  Future<void> ensureStarted() async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
