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
import 'package:soundconnect_23_12_25codx/modules/event_audience/domain/event_audience_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/venue_event_detail.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/cubit/listener_event_feed_controller.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/listener_event_post_card.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/listener_event_posts.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/listener_ghost_profile_content.dart';
import 'package:soundconnect_23_12_25codx/shared/theme/app_theme.dart';
import 'package:soundconnect_23_12_25codx/shared/widgets/gradient_outline_button.dart';

void main() {
  if (Platform.environment['LISTENER_EVENT_RENDER_DIR'] != null) {
    testWidgets('render listener event surfaces with real fonts', (
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
      for (final name in [
        'owner',
        'public',
        'ghost',
        'past',
        'long-1x',
        'long-2x',
      ]) {
        tester.view.physicalSize = Size(name == 'long-2x' ? 320 : 390, 900);
        tester.view.devicePixelRatio = 1;
        final repository = _Repository();
        final sessions = _Sessions(_session());
        final capture = GlobalKey();
        final isLong = name.startsWith('long');
        final Widget widget;
        if (name == 'ghost') {
          widget = Scaffold(
            appBar: AppBar(title: const Text('SoundConnect')),
            body: ListenerGhostProfileContent(
              username: 'deniz',
              profilePictureUrl: null,
              owner: true,
              busy: false,
              onRefresh: () async {},
              onSwitchToStandard: () {},
              privatePlansAction: ListenerEventPlansButton(
                listenerProfileId: 'profile',
                userId: 'user',
                username: 'deniz',
                repository: repository,
                sessions: sessions,
              ),
            ),
          );
        } else if (name == 'owner' || name == 'past') {
          repository.mine = (_) async => Result.success(
            _page([
              _state(ended: name == 'past', published: true, visible: true),
            ]),
          );
          widget = ListenerEventPlansScreen(
            listenerProfileId: 'profile',
            userId: 'user',
            username: 'deniz',
            repository: repository,
            sessions: sessions,
          );
        } else {
          widget = Scaffold(
            appBar: AppBar(title: const Text('SoundConnect')),
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: isLong
                  ? ListenerEventPostCard(
                      event: _event(long: true),
                      username: 'deniz',
                      intentLabel: 'Düşünüyorum',
                      note: List.filled(
                        12,
                        'Beraber güzel bir akşam geçirebiliriz.',
                      ).join('\n'),
                      onOpen: () {},
                      onIntent: () {},
                      onShare: () {},
                    )
                  : ListenerEventPostsSection(
                      listenerProfileId: 'profile',
                      username: 'deniz',
                      repository: repository,
                      sessions: sessions,
                      showHeading: true,
                    ),
            ),
          );
        }
        await _mount(
          tester,
          widget,
          screen: true,
          capture: capture,
          scale: name == 'long-2x' ? 2 : 1,
        );
        if (name == 'past') {
          await tester.tap(
            find.byKey(const ValueKey('listener-plans-period-past')),
          );
          await tester.pumpAndSettle();
        }
        await tester.runAsync(() async {
          final context = tester.element(find.byType(Scaffold).first);
          await precacheImage(const AssetImage('assets/logo.png'), context);
          if (name == 'ghost' && context.mounted) {
            await precacheImage(
              const AssetImage('assets/ghost (1).png'),
              context,
            );
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
          final output = Platform.environment['LISTENER_EVENT_RENDER_DIR']!;
          await Directory(output).create(recursive: true);
          await File(
            '$output/listener-$name.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
          pixels.dispose();
        });
      }
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }
  group('listener event feed fencing and paging', () {
    test(
      'private feed requests only own account with bounded size and default period',
      () async {
        final repository = _Repository();
        final sessions = _Sessions(_session());
        final feed = _feed(repository, sessions);
        addTearDown(feed.dispose);
        await feed.reload();
        expect(repository.calls.single, (
          'mine',
          'user',
          EventAudiencePeriod.upcoming,
          0,
          20,
        ));
        expect(feed.rows.single.intent, EventAudienceStatus.going);
      },
    );

    test(
      'profile preview requests only the public projection, all periods and two rows',
      () async {
        final repository = _Repository();
        final sessions = _Sessions(_session());
        final feed = _feed(repository, sessions, privatePlans: false, size: 2);
        addTearDown(feed.dispose);
        await feed.reload();
        expect(repository.calls.single, (
          'profile',
          'user',
          EventAudiencePeriod.all,
          0,
          2,
        ));
        expect(feed.rows.single.privateState, isNull);
      },
    );

    for (final session in [
      const AuthSession.guest(),
      _session(userId: 'other'),
      _session(role: 'ROLE_MUSICIAN'),
      _session(extraRoles: ['ROLE_VENUE']),
      _session(extraRoles: ['ROLE_OWNER']),
      _session(status: 'INACTIVE'),
    ]) {
      test(
        'private feed rejects mismatched or ineligible session ${session.userId}/${session.roles}/${session.accountStatus}',
        () async {
          final repository = _Repository();
          final sessions = _Sessions(session);
          final feed = _feed(repository, sessions);
          addTearDown(feed.dispose);
          await feed.reload();
          expect(repository.calls, isEmpty);
          expect(feed.rows, isEmpty);
          expect(feed.allowed, isFalse);
        },
      );
    }

    test(
      'late result cannot restore data after logout or another owner login',
      () async {
        final pending =
            Completer<Result<EventAudiencePage<EventAudienceState>>>();
        final repository = _Repository()..mine = (_) => pending.future;
        final sessions = _Sessions(_session());
        final feed = _feed(repository, sessions);
        addTearDown(feed.dispose);
        final request = feed.reload();
        sessions.change(_session(userId: 'other'));
        pending.complete(Result.success(_page([_state()])));
        await request;
        expect(feed.rows, isEmpty);
        expect(feed.loading, isFalse);
        expect(repository.calls.length, 1);
      },
    );

    test(
      'same-user replacement token fences late result and fetches fresh state',
      () async {
        final old = Completer<Result<EventAudiencePage<EventAudienceState>>>();
        final fresh =
            Completer<Result<EventAudiencePage<EventAudienceState>>>();
        final repository = _Repository();
        var calls = 0;
        repository.mine = (_) => ++calls == 1 ? old.future : fresh.future;
        final sessions = _Sessions(_session());
        final feed = _feed(repository, sessions);
        addTearDown(feed.dispose);
        final request = feed.reload();
        sessions.change(_session(token: 'replacement'));
        fresh.complete(Result.success(_page([_state(id: 'fresh')])));
        await Future<void>.delayed(Duration.zero);
        old.complete(Result.success(_page([_state(id: 'old')])));
        await request;
        expect(feed.rows.single.event.id, 'fresh');
      },
    );

    test('period switch ignores out-of-order previous response', () async {
      final old = Completer<Result<EventAudiencePage<EventAudienceState>>>();
      final repository = _Repository()
        ..mine = (period) => period == EventAudiencePeriod.upcoming
            ? old.future
            : Future.value(
                Result.success(_page([_state(id: 'past', ended: true)])),
              );
      final feed = _feed(repository, _Sessions(_session()));
      addTearDown(feed.dispose);
      final request = feed.reload();
      await feed.selectPeriod(EventAudiencePeriod.past);
      old.complete(Result.success(_page([_state(id: 'old')])));
      await request;
      expect(feed.rows.single.event.id, 'past');
      expect(feed.period, EventAudiencePeriod.past);
    });

    test(
      'next page replaces previous rows instead of accumulating history',
      () async {
        final repository = _Repository();
        final feed = _feed(repository, _Sessions(_session()));
        addTearDown(feed.dispose);
        repository.minePage = 0;
        repository.mineHasNext = true;
        await feed.reload();
        repository.minePage = 1;
        repository.mineHasNext = false;
        await feed.next();
        expect(repository.calls.last.$4, 1);
        expect(feed.rows.length, 1);
        expect(feed.page, 1);
        expect(feed.hasNext, isFalse);
      },
    );

    test('privacy/read errors clear formerly public rows', () async {
      final repository = _Repository();
      final feed = _feed(
        repository,
        _Sessions(_session()),
        privatePlans: false,
      );
      addTearDown(feed.dispose);
      await feed.reload();
      expect(feed.rows, isNotEmpty);
      repository.publicFailure = true;
      await feed.reload();
      expect(feed.rows, isEmpty);
      expect(feed.error, isNotNull);
    });

    test('ghost public empty response clears retained publications', () async {
      final repository = _Repository();
      final feed = _feed(
        repository,
        _Sessions(_session()),
        privatePlans: false,
      );
      addTearDown(feed.dispose);
      await feed.reload();
      repository.posts = [];
      await feed.reload();
      expect(feed.rows, isEmpty);
      expect(feed.error, isNull);
    });

    test(
      'confirmed mutation invalidates loaded feed; disposal removes listeners',
      () async {
        final repository = _Repository();
        final sessions = _Sessions(_session());
        final feed = _feed(repository, sessions);
        await feed.reload();
        repository.changes.value++;
        await Future<void>.delayed(Duration.zero);
        expect(repository.calls.length, 2);
        feed.dispose();
        expect(feed.allowed, isFalse);
        repository.changes.value++;
        sessions.change(_session(token: 'new'));
        expect(repository.calls.length, 2);
      },
    );

    test('removed and unavailable rows never render phantom cards', () async {
      final repository = _Repository()
        ..mine = (_) async => Result.success(
          _page([
            _state(id: 'none', intent: EventAudienceStatus.none),
            _state(id: 'removed', available: false),
            _state(id: 'live'),
          ]),
        );
      final feed = _feed(repository, _Sessions(_session()));
      addTearDown(feed.dispose);
      await feed.reload();
      expect(feed.rows.map((row) => row.event.id), ['live']);
    });
  });

  testWidgets(
    'public posts render real data, no mock counters or attendee identities',
    (tester) async {
      final repository = _Repository();
      final sessions = _Sessions(_session());
      await _mount(
        tester,
        ListenerEventPostsSection(
          listenerProfileId: 'profile',
          username: 'listener',
          repository: repository,
          sessions: sessions,
          showHeading: true,
        ),
      );
      expect(find.text('Gerçek etkinlik'), findsOneWidget);
      expect(find.text('Ben de gidiyorum'), findsOneWidget);
      expect(find.text('Gidiyorum'), findsOneWidget);
      expect(find.text('Ankara Indie Night'), findsNothing);
      expect(find.text('Katılıyor'), findsNothing);
      expect(find.text('Katıldı'), findsNothing);
      expect(repository.calls.single.$1, 'profile');
      expect(repository.getCalls, 0);
    },
  );

  testWidgets(
    'public post card and comments reuse the event detail destination',
    (tester) async {
      final repository = _Repository();
      final opened = <String>[];
      await _mount(
        tester,
        ListenerEventPostsSection(
          listenerProfileId: 'profile',
          username: 'listener',
          repository: repository,
          sessions: _Sessions(_session()),
          onOpenEvent: (event) async => opened.add(event.id),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('listener-event-open-event')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('listener-event-comments-event')),
      );
      await tester.pumpAndSettle();
      expect(opened, ['event', 'event']);
    },
  );

  testWidgets(
    'past public plan keeps history but never offers audience write shortcut',
    (tester) async {
      final repository = _Repository()..posts = [_post(ended: true)];
      await _mount(
        tester,
        ListenerEventPostsSection(
          listenerProfileId: 'profile',
          username: 'listener',
          repository: repository,
          sessions: _Sessions(_session()),
        ),
      );
      expect(find.text('Geçmiş plan · Gidiyorum'), findsOneWidget);
      expect(find.text('Ben de gidiyorum'), findsNothing);
      expect(
        find.byKey(const ValueKey('listener-event-open-event')),
        findsOneWidget,
      );
    },
  );

  for (final change in [
    'refresh',
    'rebind',
    'account',
    'role',
    'covered',
    'dispose',
  ]) {
    testWidgets('retained post actions are fenced after $change', (
      tester,
    ) async {
      final repository = _Repository();
      final sessions = _Sessions(_session());
      final opened = <String>[];
      Widget section(String profile) => ListenerEventPostsSection(
        listenerProfileId: profile,
        username: profile,
        repository: repository,
        sessions: sessions,
        onOpenEvent: (event) async => opened.add(event.id),
      );
      await _mount(tester, section('profile'));
      final oldCard = tester.widget<ListenerEventPostCard>(
        find.byType(ListenerEventPostCard),
      );
      switch (change) {
        case 'refresh':
          repository.changes.value++;
          break;
        case 'rebind':
          await _mount(tester, section('other-profile'));
          break;
        case 'account':
          sessions.change(_session(userId: 'other', token: 'other'));
          break;
        case 'role':
          sessions.change(_session(role: 'ROLE_MUSICIAN'));
          break;
        case 'covered':
          unawaited(
            Navigator.of(
              tester.element(find.byType(ListenerEventPostCard)),
            ).push<void>(
              MaterialPageRoute<void>(
                builder: (_) => const Scaffold(body: Text('Covering screen')),
              ),
            ),
          );
          break;
        case 'dispose':
          await _mount(tester, const Text('Replacement content'));
          break;
      }
      await tester.pumpAndSettle();
      oldCard.onOpen!();
      oldCard.onIntent!();
      oldCard.onShare!();
      await tester.pumpAndSettle();
      expect(opened, isEmpty);
      expect(repository.getCalls, 0);
      expect(find.byType(BottomSheet), findsNothing);
      expect(find.byType(SnackBar), findsNothing);
      if (change == 'covered') {
        expect(find.text('Covering screen'), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'all-posts destination captures profile before the first route build',
    (tester) async {
      final repository = _Repository()..publicHasNext = true;
      final sessions = _Sessions(_session());
      var profile = 'original-profile';
      late StateSetter changeProfile;
      await _mount(
        tester,
        StatefulBuilder(
          builder: (context, setState) {
            changeProfile = setState;
            return ListenerEventPostsSection(
              listenerProfileId: profile,
              username: profile,
              repository: repository,
              sessions: sessions,
            );
          },
        ),
      );
      tester
          .widget<TextButton>(find.byKey(const Key('listener-event-posts-all')))
          .onPressed!();
      changeProfile(() => profile = 'replacement-profile');
      await tester.pumpAndSettle();
      expect(
        repository.calls.where((call) => call.$5 == 20).single.$1,
        'original-profile',
      );
      expect(
        tester
            .widget<ListenerEventPostCard>(find.byType(ListenerEventPostCard))
            .username,
        'original-profile',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'private page uses real period selection and bounded next-page navigation',
    (tester) async {
      final repository = _Repository()..mineHasNext = true;
      await _mount(
        tester,
        ListenerEventPlansScreen(
          listenerProfileId: 'profile',
          userId: 'user',
          username: 'listener',
          repository: repository,
          sessions: _Sessions(_session()),
        ),
        screen: true,
      );
      repository.minePage = 1;
      repository.mineHasNext = false;
      await tester.ensureVisible(find.byKey(const Key('listener-plans-next')));
      await tester.tap(find.byKey(const Key('listener-plans-next')));
      await tester.pumpAndSettle();
      expect(repository.calls.last.$4, 1);
      expect(find.byType(ListenerEventPostCard), findsOneWidget);
      repository.minePage = 0;
      await tester.ensureVisible(
        find.byKey(const ValueKey('listener-plans-period-past')),
      );
      await tester.tap(
        find.byKey(const ValueKey('listener-plans-period-past')),
      );
      await tester.pumpAndSettle();
      expect(repository.calls.last.$3, EventAudiencePeriod.past);
      expect(repository.calls.last.$4, 0);
    },
  );

  testWidgets(
    'private plans show visibility and past plan does not claim attendance',
    (tester) async {
      final repository = _Repository()
        ..mine = (_) async => Result.success(
          _page([_state(ended: true, published: true, visible: false)]),
        );
      await _mount(
        tester,
        ListenerEventPlansScreen(
          listenerProfileId: 'profile',
          userId: 'user',
          username: 'listener',
          repository: repository,
          sessions: _Sessions(_session()),
        ),
        screen: true,
      );
      expect(find.textContaining('Geçmiş plan · Gidiyorum'), findsOneWidget);
      expect(find.textContaining('Hayalet modda gizli'), findsOneWidget);
      expect(find.text('Planımı düzenle'), findsOneWidget);
      expect(find.text('Katıldı'), findsNothing);
      expect(find.text('Ben de gidiyorum'), findsNothing);
    },
  );

  testWidgets('ghost public never mounts private plan action', (tester) async {
    await _mount(
      tester,
      Scaffold(
        body: ListenerGhostProfileContent(
          username: 'listener',
          profilePictureUrl: null,
          owner: false,
          busy: false,
          onRefresh: () async {},
          privatePlansAction: const Text('PRIVATE PLAN ENTRY'),
        ),
      ),
      screen: true,
    );
    expect(find.text('PRIVATE PLAN ENTRY'), findsNothing);
  });

  testWidgets('ghost owner can reach private plans without public posts', (
    tester,
  ) async {
    await _mount(
      tester,
      Scaffold(
        body: ListenerGhostProfileContent(
          username: 'listener',
          profilePictureUrl: null,
          owner: true,
          busy: false,
          onRefresh: () async {},
          privatePlansAction: const Text('PRIVATE PLAN ENTRY'),
        ),
      ),
      screen: true,
    );
    expect(find.text('PRIVATE PLAN ENTRY'), findsOneWidget);
    expect(find.byType(ListenerEventPostsSection), findsNothing);
  });

  testWidgets('profile refresh and resume invalidate public cards', (
    tester,
  ) async {
    final repository = _Repository();
    final signal = ValueNotifier<int>(0);
    addTearDown(signal.dispose);
    await _mount(
      tester,
      ListenerEventPostsSection(
        listenerProfileId: 'profile',
        username: 'listener',
        repository: repository,
        sessions: _Sessions(_session()),
        refreshSignal: signal,
      ),
    );
    signal.value++;
    await tester.pumpAndSettle();
    expect(repository.calls.length, 2);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(repository.calls.length, 3);
  });

  testWidgets('logout instantly removes visible public post and actions', (
    tester,
  ) async {
    final sessions = _Sessions(_session());
    await _mount(
      tester,
      ListenerEventPostsSection(
        listenerProfileId: 'profile',
        username: 'listener',
        repository: _Repository(),
        sessions: sessions,
      ),
    );
    sessions.change(const AuthSession.guest());
    await tester.pumpAndSettle();
    expect(find.text('Gerçek etkinlik'), findsNothing);
    expect(find.text('Ben de gidiyorum'), findsNothing);
  });

  testWidgets(
    'private plans entry is single-navigation and captured callback becomes inert',
    (tester) async {
      final repository = _Repository();
      final sessions = _Sessions(_session());
      await _mount(
        tester,
        ListenerEventPlansButton(
          listenerProfileId: 'profile',
          userId: 'user',
          username: 'listener',
          repository: repository,
          sessions: sessions,
        ),
      );
      final callback = tester
          .widget<GradientOutlineButton>(
            find.byKey(const Key('listener-my-event-plans')),
          )
          .onPressed!;
      callback();
      callback();
      await tester.pumpAndSettle();
      expect(find.byType(ListenerEventPlansScreen), findsOneWidget);
      expect(repository.calls.length, 1);
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      callback();
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(repository.calls.length, 1);
    },
  );

  testWidgets('long notes stay compact and remain fully readable on demand', (
    tester,
  ) async {
    final note = List.filled(35, 'Plan notu').join('\n');
    await _mount(
      tester,
      ListenerEventPostCard(
        event: _event(),
        username: 'listener',
        intentLabel: 'Düşünüyorum',
        note: note,
        onOpen: () {},
        onIntent: () {},
      ),
    );
    expect(tester.widget<Text>(find.text(note)).maxLines, 3);
    expect(
      tester.getSize(find.byType(ListenerEventPostCard)).height,
      lessThan(600),
    );
    await tester.tap(find.text('Notun tamamını oku'));
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(find.text(note)).maxLines, isNull);
    await tester.ensureVisible(find.text('Daha az göster'));
    await tester.tap(find.text('Daha az göster'));
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(find.text(note)).maxLines, 3);
  });

  testWidgets(
    'public past-empty copy describes the viewed profile, not the viewer',
    (tester) async {
      final repository = _Repository()..publicHasNext = true;
      await _mount(
        tester,
        ListenerEventPostsSection(
          listenerProfileId: 'profile',
          username: 'listener',
          repository: repository,
          sessions: _Sessions(_session()),
        ),
      );
      await tester.ensureVisible(
        find.byKey(const Key('listener-event-posts-all')),
      );
      await tester.tap(find.byKey(const Key('listener-event-posts-all')));
      await tester.pumpAndSettle();
      repository.posts = [];
      repository.publicHasNext = false;
      await tester.tap(
        find.byKey(const ValueKey('listener-plans-period-past')),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Bu bölümde paylaşılmış geçmiş bir etkinlik yok.'),
        findsOneWidget,
      );
      expect(find.text('Henüz geçmiş bir planın yok.'), findsNothing);
    },
  );

  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'compact discovery-style card fits 320px at ${scale * 100}% text',
      (tester) async {
        tester.view.physicalSize = const Size(320, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await _mount(
          tester,
          ListenerEventPostCard(
            event: _event(long: true),
            username: 'uzun_bir_dinleyici_kullanıcı_adı',
            intentLabel: 'Düşünüyorum',
            note: 'Bu etkinliğe gitmeyi düşünüyorum.',
            onOpen: () {},
            onIntent: () {},
            onShare: () {},
          ),
          scale: scale,
        );
        expect(tester.takeException(), isNull);
        expect(find.text('Düşünüyorum'), findsOneWidget);
        if (scale == 1) {
          expect(
            tester
                .getSize(
                  find.byKey(const ValueKey('listener-event-open-event')),
                )
                .height,
            lessThan(330),
          );
        }
        for (final key in [
          'listener-event-intent-event',
          'listener-event-comments-event',
          'listener-event-share-event',
        ]) {
          final size = tester.getSize(find.byKey(ValueKey(key)));
          expect(size.height, greaterThanOrEqualTo(48));
          expect(size.width, greaterThanOrEqualTo(48));
        }
      },
    );
  }
}

ListenerEventFeedController _feed(
  _Repository repository,
  _Sessions sessions, {
  bool privatePlans = true,
  int size = 20,
}) => ListenerEventFeedController(
  repository: repository,
  sessions: sessions,
  listenerProfileId: 'profile',
  ownerUserId: privatePlans ? 'user' : null,
  privatePlans: privatePlans,
  pageSize: size,
);

AuthSession _session({
  String userId = 'user',
  String token = 'token',
  String role = 'ROLE_LISTENER',
  String status = 'ACTIVE',
  List<String> extraRoles = const [],
}) => AuthSession.authenticated(
  token: token,
  userId: userId,
  username: 'listener',
  accountStatus: status,
  roles: [role, ...extraRoles],
  permissions: const [],
  expiresAt: DateTime.utc(2040),
  isAdmin: false,
);

class _Sessions extends Fake with ChangeNotifier implements AuthSessionManager {
  _Sessions(this._session);
  AuthSession _session;
  @override
  AuthSession get session => _session;
  void change(AuthSession value) {
    _session = value;
    notifyListeners();
  }
}

typedef _Call = (String, String, EventAudiencePeriod, int, int);

class _Repository extends Fake implements EventAudienceRepository {
  @override
  final ValueNotifier<int> changes = ValueNotifier<int>(0);
  final calls = <_Call>[];
  int getCalls = 0;
  int minePage = 0;
  bool mineHasNext = false;
  bool publicFailure = false;
  bool publicHasNext = false;
  List<EventAudiencePost>? posts;
  Future<Result<EventAudiencePage<EventAudienceState>>> Function(
    EventAudiencePeriod,
  )?
  mine;
  @override
  Future<Result<EventAudiencePage<EventAudienceState>>> listMine({
    required String expectedSessionKey,
    EventAudiencePeriod period = EventAudiencePeriod.upcoming,
    int page = 0,
    int size = 20,
  }) {
    calls.add(('mine', expectedSessionKey, period, page, size));
    return mine?.call(period) ??
        Future.value(
          Result.success(
            _page([_state()], page: minePage, hasNext: mineHasNext),
          ),
        );
  }

  @override
  Future<Result<EventAudiencePage<EventAudiencePost>>> listPublic(
    String listenerProfileId, {
    String? expectedSessionKey,
    EventAudiencePeriod period = EventAudiencePeriod.all,
    int page = 0,
    int size = 20,
  }) async {
    calls.add((
      listenerProfileId,
      expectedSessionKey ?? '',
      period,
      page,
      size,
    ));
    if (publicFailure) {
      return const Result.failure(
        AppError(code: '404', message: 'Profil kullanılamıyor.'),
      );
    }
    return Result.success(_page(posts ?? [_post()], hasNext: publicHasNext));
  }

  @override
  Future<Result<EventAudienceState>> getIntent({
    required String eventId,
    required String expectedSessionKey,
  }) async {
    getCalls++;
    return Result.success(_state(id: eventId));
  }
}

EventAudiencePage<T> _page<T>(
  List<T> items, {
  int page = 0,
  bool hasNext = false,
}) => EventAudiencePage(
  items: items,
  page: page,
  size: 20,
  totalElements: hasNext ? 21 : items.length,
  totalPages: hasNext
      ? 2
      : items.isEmpty
      ? 0
      : 1,
  hasNext: hasNext,
);

EventAudienceState _state({
  String id = 'event',
  bool ended = false,
  bool available = true,
  bool published = false,
  bool visible = false,
  EventAudienceStatus intent = EventAudienceStatus.going,
}) => EventAudienceState(
  eventId: id,
  intent: intent,
  publishedOnProfile: published,
  note: null,
  version: 1,
  updatedAt: DateTime.utc(2026, 9, 8),
  eventAvailable: available,
  eventEnded: ended,
  canSetIntent: !ended,
  canPublish: !ended,
  publicationVisible: visible,
  event: available ? _event(id: id) : null,
);

EventAudiencePost _post({bool ended = false}) => EventAudiencePost(
  eventId: 'event',
  intent: EventAudienceStatus.going,
  note: 'Birlikte müzik dinleyelim.',
  publishedAt: DateTime.utc(2026, 9, 8),
  event: _event(),
  eventEnded: ended,
);

VenueEventDetail _event({String id = 'event', bool long = false}) =>
    VenueEventDetail(
      id: id,
      shareUrl: null,
      posterImage: null,
      musicianProfileId: null,
      performerName: long
          ? 'Dolu Kadehi Ters Tut ve uzun bir sanatçı adı'
          : 'Sahbaz',
      title: long
          ? 'Çok uzun bir etkinlik başlığı ve devam eden açıklayıcı ad'
          : 'Gerçek etkinlik',
      eventDate: DateTime(2026, 9, 9),
      startTime: '20:00:00',
      endTime: '22:00:00',
      venueId: 'venue',
      venueName: 'SoundConnect Ankara',
      venueCity: 'Ankara',
      venueDistrict: 'Çankaya',
    );

Future<void> _mount(
  WidgetTester tester,
  Widget child, {
  double scale = 1,
  bool screen = false,
  GlobalKey? capture,
}) async {
  await tester.pumpWidget(
    RepaintBoundary(
      key: capture,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
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
        home: screen
            ? child
            : Scaffold(
                body: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: child,
                ),
              ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
