import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session_manager.dart';
import 'package:soundconnect_23_12_25codx/core/di/service_locator.dart';
import 'package:soundconnect_23_12_25codx/core/error/app_error.dart';
import 'package:soundconnect_23_12_25codx/core/error/result.dart';
import 'package:soundconnect_23_12_25codx/modules/event_audience/domain/event_audience_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/engagement/domain/engagement_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/engagement/domain/entities/comment_item.dart';
import 'package:soundconnect_23_12_25codx/modules/engagement/domain/entities/comment_page.dart';
import 'package:soundconnect_23_12_25codx/modules/engagement/domain/entities/comment_user_summary.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/venue_event_detail.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/cubit/listener_event_feed_controller.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/listener_event_post_card.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/listener_event_post_note_editor.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/listener_event_posts.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/listener_ghost_profile_content.dart';
import 'package:soundconnect_23_12_25codx/shared/theme/app_theme.dart';
import 'package:soundconnect_23_12_25codx/shared/widgets/gradient_outline_button.dart';

void main() {
  setUp(() async => serviceLocator.reset());
  tearDown(() async => serviceLocator.reset());
  Future<void> mountOwner(
    WidgetTester tester,
    _Repository repository,
    _Sessions sessions,
  ) => _mount(
    tester,
    ListenerEventPostsSection(
      listenerProfileId: 'profile',
      username: 'listener',
      ownerUserId: 'user',
      repository: repository,
      sessions: sessions,
    ),
  );
  Future<void> ownerMenu(WidgetTester tester, String action) async {
    await tester.tap(find.byTooltip('Paylaşım seçenekleri'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(action));
    await tester.pumpAndSettle();
  }

  testWidgets('owner status change preserves publication note and version', (
    tester,
  ) async {
    final repository = _Repository()
      ..viewerIntent = _state(
        published: true,
        note: 'Kalacak açıklama',
        version: 7,
      );
    await mountOwner(tester, repository, _Sessions(_session()));
    await ownerMenu(tester, 'Düşünüyorum olarak değiştir');
    expect(repository.intentWrites.single, (
      EventAudienceStatus.thinking,
      true,
      'Kalacak açıklama',
      7,
      'user',
    ));
    expect(repository.viewerIntent.postId, 'post-event');
  });
  testWidgets(
    'owner editor retains failed draft then saves without changing intent',
    (tester) async {
      final repository = _Repository()
        ..viewerIntent = _state(
          published: true,
          intent: EventAudienceStatus.thinking,
          note: 'Eski açıklama',
          version: 4,
        )
        ..failIntent = true;
      await mountOwner(tester, repository, _Sessions(_session()));
      await ownerMenu(tester, 'Açıklamayı düzenle');
      final input = find.byKey(const Key('listener-post-note-input'));
      expect(tester.widget<TextField>(input).controller!.text, 'Eski açıklama');
      await tester.enterText(input, '  Yeni açıklama  ');
      await tester.tap(find.byKey(const Key('listener-post-note-save')));
      await tester.pumpAndSettle();
      expect(input, findsOneWidget);
      expect(
        tester.widget<TextField>(input).controller!.text,
        '  Yeni açıklama  ',
      );
      repository.failIntent = false;
      await tester.tap(find.byKey(const Key('listener-post-note-save')));
      await tester.pumpAndSettle();
      expect(input, findsNothing);
      expect(repository.intentWrites.last, (
        EventAudienceStatus.thinking,
        true,
        'Yeni açıklama',
        4,
        'user',
      ));
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('owner can clear note and unchanged note does not write', (
    tester,
  ) async {
    final repository = _Repository()
      ..viewerIntent = _state(published: true, note: 'Eski');
    await mountOwner(tester, repository, _Sessions(_session()));
    await ownerMenu(tester, 'Açıklamayı düzenle');
    await tester.tap(find.byKey(const Key('listener-post-note-save')));
    await tester.pumpAndSettle();
    expect(repository.intentWrites, isEmpty);
    await ownerMenu(tester, 'Açıklamayı düzenle');
    await tester.enterText(
      find.byKey(const Key('listener-post-note-input')),
      '   ',
    );
    await tester.tap(find.byKey(const Key('listener-post-note-save')));
    await tester.pumpAndSettle();
    expect(repository.intentWrites.single.$3, isNull);
    expect(find.byKey(const Key('listener-post-note-input')), findsNothing);
  });
  testWidgets('session switch dismisses owner editor and prevents stale save', (
    tester,
  ) async {
    final repository = _Repository()..viewerIntent = _state(published: true);
    final sessions = _Sessions(_session());
    await mountOwner(tester, repository, sessions);
    await ownerMenu(tester, 'Açıklamayı düzenle');
    await tester.enterText(
      find.byKey(const Key('listener-post-note-input')),
      'Taslak',
    );
    sessions.change(_session(userId: 'other', token: 'other'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('listener-post-note-input')), findsNothing);
    expect(repository.intentWrites, isEmpty);
    expect(tester.takeException(), isNull);
  });
  testWidgets('owner action refuses a replaced publication', (tester) async {
    final repository = _Repository()..viewerIntent = _state();
    await mountOwner(tester, repository, _Sessions(_session()));
    await ownerMenu(tester, 'Düşünüyorum olarak değiştir');
    expect(repository.intentWrites, isEmpty);
  });

  testWidgets(
    'owner note save is single flight and blocks dismissal while saving',
    (tester) async {
      final pending = Completer<Result<EventAudienceState>>();
      final repository = _Repository()
        ..viewerIntent = _state(
          published: true,
          note: 'Eski açıklama',
          version: 8,
        )
        ..pendingIntent = pending;
      await mountOwner(tester, repository, _Sessions(_session()));
      await ownerMenu(tester, 'Açıklamayı düzenle');
      final input = find.byKey(const Key('listener-post-note-input'));
      await tester.enterText(input, 'Yeni açıklama');
      final save = tester
          .widget<TextButton>(find.byKey(const Key('listener-post-note-save')))
          .onPressed!;
      save();
      save();
      await tester.pump();
      expect(repository.intentWrites, hasLength(1));
      expect(tester.widget<TextField>(input).enabled, isFalse);
      expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, 'Vazgeç'))
            .onPressed,
        isNull,
      );
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(input, findsOneWidget);
      pending.complete(
        Result.success(
          _state(published: true, note: 'Yeni açıklama', version: 9),
        ),
      );
      await tester.pumpAndSettle();
      expect(input, findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  for (final change in ['refresh', 'republication', 'privacy', 'dispose']) {
    testWidgets(
      'owner note draft and captured save are revoked after $change',
      (tester) async {
        final repository = _Repository()
          ..viewerIntent = _state(published: true);
        await mountOwner(tester, repository, _Sessions(_session()));
        await ownerMenu(tester, 'Açıklamayı düzenle');
        await tester.enterText(
          find.byKey(const Key('listener-post-note-input')),
          'Taslak',
        );
        final save = tester
            .widget<ListenerEventPostNoteEditor>(
              find.byType(ListenerEventPostNoteEditor),
            )
            .onSave;
        if (change == 'dispose') {
          await tester.pumpWidget(const MaterialApp(home: SizedBox()));
        } else {
          if (change == 'republication') {
            repository.posts = [_post(postId: 'replacement')];
          }
          if (change == 'privacy') repository.posts = [];
          repository.changes.value++;
        }
        await tester.pumpAndSettle();
        expect(find.byType(ListenerEventPostNoteEditor), findsNothing);
        expect(await save('Stale draft'), isNotNull);
        expect(repository.intentWrites, isEmpty);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('pending owner save cannot close a replacement session route', (
    tester,
  ) async {
    final pending = Completer<Result<EventAudienceState>>();
    final repository = _Repository()
      ..viewerIntent = _state(published: true)
      ..pendingIntent = pending;
    final sessions = _Sessions(_session());
    await mountOwner(tester, repository, sessions);
    await ownerMenu(tester, 'Açıklamayı düzenle');
    await tester.enterText(
      find.byKey(const Key('listener-post-note-input')),
      'Eski hesabın taslağı',
    );
    await tester.tap(find.byKey(const Key('listener-post-note-save')));
    await tester.pump();
    sessions.change(_session(userId: 'other', token: 'other'));
    await tester.pumpAndSettle();
    expect(find.byType(ListenerEventPostNoteEditor), findsNothing);
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    unawaited(
      navigator.push<void>(
        MaterialPageRoute(
          builder: (_) => const Scaffold(body: Text('Yeni oturum sayfası')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    pending.complete(
      Result.success(
        _state(published: true, note: 'Eski hesabın taslağı', version: 2),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Yeni oturum sayfası'), findsOneWidget);
    expect(repository.intentWrites.single.$5, 'user');
    expect(tester.takeException(), isNull);
  });

  for (final action in ['intent', 'note']) {
    testWidgets(
      'owner $action read cannot write or open an editor after refresh',
      (tester) async {
        final pending = Completer<Result<EventAudienceState>>();
        final repository = _Repository()
          ..viewerIntent = _state(published: true)
          ..pendingRead = pending;
        await mountOwner(tester, repository, _Sessions(_session()));
        final card = tester.widget<ListenerEventPostCard>(
          find.byType(ListenerEventPostCard),
        );
        final callback = action == 'intent'
            ? card.onChangeIntent!
            : card.onEditNote!;
        callback();
        callback();
        await tester.pump();
        expect(repository.getCalls, 1);
        repository.changes.value++;
        await tester.pumpAndSettle();
        pending.complete(Result.success(_state(published: true)));
        await tester.pumpAndSettle();
        expect(repository.intentWrites, isEmpty);
        expect(find.byType(ListenerEventPostNoteEditor), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('owner note cancel leaves publication untouched', (tester) async {
    final repository = _Repository()
      ..viewerIntent = _state(published: true, note: 'Korunacak');
    await mountOwner(tester, repository, _Sessions(_session()));
    await ownerMenu(tester, 'Açıklamayı düzenle');
    await tester.enterText(
      find.byKey(const Key('listener-post-note-input')),
      'Vazgeçilecek',
    );
    await tester.tap(find.widgetWithText(TextButton, 'Vazgeç'));
    await tester.pumpAndSettle();
    expect(find.byType(ListenerEventPostNoteEditor), findsNothing);
    expect(repository.intentWrites, isEmpty);
    expect(repository.viewerIntent.note, 'Korunacak');
  });

  testWidgets('metadata-only session replacement keeps owner actions usable', (
    tester,
  ) async {
    final repository = _Repository()..viewerIntent = _state(published: true);
    final sessions = _Sessions(_session());
    await mountOwner(tester, repository, sessions);
    // Updating a username creates a new AuthSession without changing its
    // account, token, roles, or audience access.
    sessions.change(_session(username: 'yenikullanici'));
    await tester.pumpAndSettle();
    await ownerMenu(tester, 'Açıklamayı düzenle');
    expect(find.byType(ListenerEventPostNoteEditor), findsOneWidget);
    expect(repository.getCalls, 1);
    expect(repository.calls, hasLength(1));
  });

  testWidgets(
    'metadata-only session replacement rebinds public participation callbacks',
    (tester) async {
      final repository = _Repository();
      final sessions = _Sessions(_session());
      await _mount(
        tester,
        ListenerEventPostsSection(
          listenerProfileId: 'profile',
          username: 'author',
          repository: repository,
          sessions: sessions,
        ),
      );
      final oldToggle = tester
          .widget<ListenerEventPostCard>(find.byType(ListenerEventPostCard))
          .onIntent!;
      sessions.change(_session(username: 'yenikullanici'));
      await tester.pumpAndSettle();
      expect(repository.calls, hasLength(1));
      expect(repository.getCalls, 1);
      oldToggle();
      await tester.pumpAndSettle();
      expect(repository.intentWrites, isEmpty);
      await tester.tap(find.text('Ben de gidiyorum'));
      await tester.pumpAndSettle();
      expect(repository.intentWrites.single.$1, EventAudienceStatus.going);
      expect(find.text('Bu etkinliğe katılıyorsun!'), findsOneWidget);
    },
  );

  testWidgets(
    'owner note counts the API Unicode limit and accepts its exact boundary',
    (tester) async {
      final repository = _Repository()..viewerIntent = _state(published: true);
      await mountOwner(tester, repository, _Sessions(_session()));
      await ownerMenu(tester, 'Açıklamayı düzenle');
      final input = find.byKey(const Key('listener-post-note-input'));
      const family = '👨‍👩‍👧‍👦'; // One grapheme, seven Unicode code points.
      await tester.enterText(input, List.filled(72, family).join());
      await tester.pump();
      expect(find.text('504 / 500'), findsOneWidget);
      await tester.tap(find.byKey(const Key('listener-post-note-save')));
      await tester.pumpAndSettle();
      expect(
        find.text('Açıklama en fazla 500 karakter olabilir.'),
        findsOneWidget,
      );
      expect(repository.intentWrites, isEmpty);
      final boundary = '${List.filled(71, family).join()}abc';
      await tester.enterText(input, boundary);
      await tester.pump();
      expect(find.text('500 / 500'), findsOneWidget);
      await tester.tap(find.byKey(const Key('listener-post-note-save')));
      await tester.pumpAndSettle();
      expect(repository.intentWrites.single.$3, boundary);
      expect(find.byType(ListenerEventPostNoteEditor), findsNothing);
    },
  );
  testWidgets('private thinking plan switches to going without publishing', (
    tester,
  ) async {
    final repository = _Repository()
      ..viewerIntent = _state(intent: EventAudienceStatus.thinking);
    repository.mine = (_) async =>
        Result.success(_page([repository.viewerIntent]));
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
    expect(find.text('Planımı düzenle'), findsNothing);
    await ownerMenu(tester, 'Gidiyorum olarak değiştir');
    expect(repository.intentWrites.single, (
      EventAudienceStatus.going,
      false,
      null,
      1,
      'user',
    ));
    expect(repository.viewerIntent.postId, isNull);
  });
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
    'public participation toggles persistently without opening a sheet',
    (tester) async {
      final repository = _Repository();
      final sessions = _Sessions(_session());
      Widget section() => ListenerEventPostsSection(
        listenerProfileId: 'profile',
        username: 'author',
        repository: repository,
        sessions: sessions,
      );
      await _mount(tester, section());
      await tester.tap(find.text('Ben de gidiyorum'));
      await tester.pumpAndSettle();
      expect(find.text('Bu etkinliğe katılıyorsun!'), findsOneWidget);
      expect(find.text('Author bu etkinliğe gidiyor.'), findsOneWidget);
      expect(find.byType(BottomSheet), findsNothing);
      expect(repository.intentWrites.single, (
        EventAudienceStatus.going,
        false,
        null,
        1,
        'user',
      ));
      await _mount(tester, const SizedBox.shrink());
      await _mount(tester, section());
      expect(find.text('Bu etkinliğe katılıyorsun!'), findsOneWidget);
      await tester.tap(find.text('Bu etkinliğe katılıyorsun!'));
      await tester.pumpAndSettle();
      expect(find.text('Ben de gidiyorum'), findsOneWidget);
      expect(repository.intentWrites.last.$1, EventAudienceStatus.none);
      expect(
        repository.intentWrites.every((write) => !write.$2 && write.$3 == null),
        isTrue,
      );
      expect(find.byType(BottomSheet), findsNothing);
    },
  );

  testWidgets('an existing going plan is shown and can be cleared directly', (
    tester,
  ) async {
    final repository = _Repository()..viewerIntent = _state();
    await _mount(
      tester,
      ListenerEventPostsSection(
        listenerProfileId: 'profile',
        username: 'author',
        repository: repository,
        sessions: _Sessions(_session()),
      ),
    );
    expect(find.text('Bu etkinliğe katılıyorsun!'), findsOneWidget);
    await tester.tap(find.text('Bu etkinliğe katılıyorsun!'));
    await tester.pumpAndSettle();
    expect(repository.intentWrites.single.$1, EventAudienceStatus.none);
    expect(find.text('Ben de gidiyorum'), findsOneWidget);
  });

  testWidgets('thinking becomes going without creating a publication', (
    tester,
  ) async {
    final repository = _Repository()
      ..viewerIntent = _state(intent: EventAudienceStatus.thinking);
    await _mount(
      tester,
      ListenerEventPostsSection(
        listenerProfileId: 'profile',
        username: 'author',
        repository: repository,
        sessions: _Sessions(_session()),
      ),
    );
    await tester.tap(find.text('Ben de gidiyorum'));
    await tester.pumpAndSettle();
    expect(repository.intentWrites.single.$1, EventAudienceStatus.going);
    expect(repository.intentWrites.single.$2, isFalse);
    expect(find.byType(BottomSheet), findsNothing);
  });

  testWidgets(
    'participation is single flight and retains a disabled action while saving',
    (tester) async {
      final pending = Completer<Result<EventAudienceState>>();
      final repository = _Repository()..pendingIntent = pending;
      await _mount(
        tester,
        ListenerEventPostsSection(
          listenerProfileId: 'profile',
          username: 'author',
          repository: repository,
          sessions: _Sessions(_session()),
        ),
      );
      final callback = tester
          .widget<ListenerEventPostCard>(find.byType(ListenerEventPostCard))
          .onIntent!;
      callback();
      callback();
      await tester.pump();
      expect(repository.intentWrites, hasLength(1));
      final saving = tester.widget<ListenerEventPostCard>(
        find.byType(ListenerEventPostCard),
      );
      expect(saving.intentBusy, isTrue);
      expect(saving.onIntent, isNull);
      expect(find.text('Ben de gidiyorum'), findsOneWidget);
      pending.complete(Result.success(_state()));
      await tester.pumpAndSettle();
      expect(find.text('Bu etkinliğe katılıyorsun!'), findsOneWidget);
      expect(find.byType(BottomSheet), findsNothing);
    },
  );

  testWidgets(
    'failed participation preserves previous state and can retry safely',
    (tester) async {
      final repository = _Repository()..failIntent = true;
      await _mount(
        tester,
        ListenerEventPostsSection(
          listenerProfileId: 'profile',
          username: 'author',
          repository: repository,
          sessions: _Sessions(_session()),
        ),
      );
      await tester.tap(find.text('Ben de gidiyorum'));
      await tester.pumpAndSettle();
      expect(find.text('Bu etkinliğe katılıyorsun!'), findsNothing);
      expect(find.byType(SnackBar), findsOneWidget);
      repository.failIntent = false;
      await tester.tap(find.text('Ben de gidiyorum'));
      await tester.pumpAndSettle();
      expect(
        repository.intentWrites,
        hasLength(1),
      ); // Reconcile before retrying a write.
      await tester.tap(find.text('Ben de gidiyorum'));
      await tester.pumpAndSettle();
      expect(repository.intentWrites, hasLength(2));
      expect(find.text('Bu etkinliğe katılıyorsun!'), findsOneWidget);
    },
  );

  testWidgets('pending participation cannot update a replacement session', (
    tester,
  ) async {
    final pending = Completer<Result<EventAudienceState>>();
    final repository = _Repository()..pendingIntent = pending;
    final sessions = _Sessions(_session());
    await _mount(
      tester,
      ListenerEventPostsSection(
        listenerProfileId: 'profile',
        username: 'author',
        repository: repository,
        sessions: sessions,
      ),
    );
    await tester.tap(find.text('Ben de gidiyorum'));
    await tester.pump();
    sessions.change(_session(userId: 'other', token: 'other'));
    await tester.pumpAndSettle();
    pending.complete(Result.success(_state()));
    await tester.pumpAndSettle();
    expect(find.text('Bu etkinliğe katılıyorsun!'), findsNothing);
    expect(repository.intentWrites.single.$5, 'user');
    expect(find.byType(BottomSheet), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'profile refresh re-reads the viewer plan without a repository signal',
    (tester) async {
      final repository = _Repository();
      final refresh = ValueNotifier(0);
      addTearDown(refresh.dispose);
      await _mount(
        tester,
        ListenerEventPostsSection(
          listenerProfileId: 'profile',
          username: 'author',
          repository: repository,
          sessions: _Sessions(_session()),
          refreshSignal: refresh,
        ),
      );
      expect(find.text('Ben de gidiyorum'), findsOneWidget);
      repository.viewerIntent = _state();
      refresh.value++;
      await tester.pumpAndSettle();
      expect(find.text('Bu etkinliğe katılıyorsun!'), findsOneWidget);
      expect(repository.intentWrites, isEmpty);
    },
  );

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
      expect(find.text('@listener'), findsOneWidget);
      expect(find.text('Listener bu etkinliğe gidiyor.'), findsOneWidget);
      expect(find.text('Ankara Indie Night'), findsNothing);
      expect(find.text('Katılıyor'), findsNothing);
      expect(find.text('Katıldı'), findsNothing);
      expect(repository.calls.single.$1, 'profile');
      expect(repository.getCalls, 1);
    },
  );

  testWidgets(
    'event preview opens event while comments read and write the publication thread',
    (tester) async {
      final repository = _Repository();
      final comments = _CommentsRepository();
      serviceLocator.registerSingleton<EngagementRepository>(comments);
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
      expect(opened, ['event']);
      expect(find.text('Yorumlar'), findsOneWidget);
      expect(comments.reads, isNotEmpty);
      expect(comments.reads, everyElement(('EVENT_POST', 'post-event')));
      await tester.enterText(find.byType(TextField), 'Sadece bu paylaşıma');
      await tester.pump();
      await tester.tap(find.byTooltip('Yorumu gönder'));
      await tester.pumpAndSettle();
      expect(comments.writes, [
        ('EVENT_POST', 'post-event', 'Sadece bu paylaşıma'),
      ]);
      final feedReads = repository.calls.length;
      await tester.tap(find.byTooltip('Yorumları kapat'));
      await tester.pumpAndSettle();
      expect(repository.calls.length, feedReads);
      expect(
        tester
            .widget<ListenerEventPostCard>(find.byType(ListenerEventPostCard))
            .commentCount,
        1,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('comment-close count refresh waits for an older stats request', (
    tester,
  ) async {
    final delayedState = Completer<Result<bool>>();
    final comments = _CommentsRepository()..pendingIsLiked = delayedState;
    serviceLocator.registerSingleton<EngagementRepository>(comments);
    final repository = _Repository();
    await _mount(
      tester,
      ListenerEventPostsSection(
        listenerProfileId: 'profile',
        username: 'listener',
        repository: repository,
        sessions: _Sessions(_session()),
      ),
    );
    expect(
      tester
          .widget<ListenerEventPostCard>(find.byType(ListenerEventPostCard))
          .likeBusy,
      isTrue,
    );
    await tester.tap(
      find.byKey(const ValueKey('listener-event-comments-event')),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Yeni yorum');
    await tester.pump();
    await tester.tap(find.byTooltip('Yorumu gönder'));
    await tester.pumpAndSettle();
    final feedReads = repository.calls.length;
    await tester.tap(find.byTooltip('Yorumları kapat'));
    await tester.pumpAndSettle();
    delayedState.complete(const Result.success(false));
    await tester.pumpAndSettle();
    expect(repository.calls.length, feedReads);
    expect(
      tester
          .widget<ListenerEventPostCard>(find.byType(ListenerEventPostCard))
          .commentCount,
      1,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'post likes toggle their own publication and refresh real counts',
    (tester) async {
      final comments = _CommentsRepository();
      serviceLocator.registerSingleton<EngagementRepository>(comments);
      await _mount(
        tester,
        ListenerEventPostsSection(
          listenerProfileId: 'profile',
          username: 'listener',
          ownerUserId: 'user',
          repository: _Repository(),
          sessions: _Sessions(_session()),
        ),
      );
      ListenerEventPostCard card() =>
          tester.widget(find.byType(ListenerEventPostCard));
      expect(card().likeCount, 0);
      expect(card().isLiked, isFalse);
      await tester.tap(find.byTooltip('Beğen'));
      await tester.pumpAndSettle();
      expect(comments.likes, [('EVENT_POST', 'post-event', true)]);
      expect(card().likeCount, 1);
      expect(card().isLiked, isTrue);
      await tester.tap(find.byTooltip('Beğenmekten vazgeç'));
      await tester.pumpAndSettle();
      expect(comments.likes.last, ('EVENT_POST', 'post-event', false));
      expect(card().likeCount, 0);
      expect(card().isLiked, isFalse);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'failed post like rolls back and retries read before another write',
    (tester) async {
      final comments = _CommentsRepository()..failLike = true;
      serviceLocator.registerSingleton<EngagementRepository>(comments);
      await _mount(
        tester,
        ListenerEventPostsSection(
          listenerProfileId: 'profile',
          username: 'listener',
          repository: _Repository(),
          sessions: _Sessions(_session()),
        ),
      );
      await tester.tap(find.byTooltip('Beğen'));
      await tester.pumpAndSettle();
      expect(comments.likes.length, 1);
      final failed = tester.widget<ListenerEventPostCard>(
        find.byType(ListenerEventPostCard),
      );
      expect(failed.isLiked, isFalse);
      expect(failed.likeCount, isNull);
      expect(find.text('Beğeni kaydedilemedi.'), findsOneWidget);
      comments.failLike = false;
      await tester.tap(find.byTooltip('Beğen'));
      await tester.pumpAndSettle();
      expect(comments.likes.length, 1);
      await tester.tap(find.byTooltip('Beğen'));
      await tester.pumpAndSettle();
      expect(comments.likes.length, 2);
      expect(
        tester
            .widget<ListenerEventPostCard>(find.byType(ListenerEventPostCard))
            .isLiked,
        isTrue,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('pending old publication like cannot affect its replacement', (
    tester,
  ) async {
    final repository = _Repository();
    final comments = _CommentsRepository()
      ..pendingLike = Completer<Result<void>>();
    serviceLocator.registerSingleton<EngagementRepository>(comments);
    await _mount(
      tester,
      ListenerEventPostsSection(
        listenerProfileId: 'profile',
        username: 'listener',
        repository: repository,
        sessions: _Sessions(_session()),
      ),
    );
    final old = tester.widget<ListenerEventPostCard>(
      find.byType(ListenerEventPostCard),
    );
    old.onLike!();
    old.onLike!();
    await tester.pump();
    expect(comments.likes.length, 1);
    repository.posts = [_post(postId: 'new-post')];
    repository.changes.value++;
    await tester.pumpAndSettle();
    old.onLike!();
    comments.pendingLike!.complete(const Result.success(null));
    comments.pendingLike = null;
    await tester.pumpAndSettle();
    final replacement = tester.widget<ListenerEventPostCard>(
      find.byType(ListenerEventPostCard),
    );
    expect(replacement.likeCount, 0);
    expect(replacement.isLiked, isFalse);
    expect(comments.likes, [('EVENT_POST', 'post-event', true)]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('unpublished private plan has no public engagement controls', (
    tester,
  ) async {
    final comments = _CommentsRepository();
    serviceLocator.registerSingleton<EngagementRepository>(comments);
    await _mount(
      tester,
      ListenerEventPlansScreen(
        listenerProfileId: 'profile',
        userId: 'user',
        username: 'listener',
        repository: _Repository(),
        sessions: _Sessions(_session()),
      ),
      screen: true,
    );
    expect(find.byTooltip('Beğen'), findsNothing);
    expect(comments.reads, isEmpty);
    expect(comments.likes, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'owner post delete requires confirmation and deletes only its publication',
    (tester) async {
      final repository = _Repository();
      await _mount(
        tester,
        ListenerEventPostsSection(
          listenerProfileId: 'profile',
          username: 'listener',
          ownerUserId: 'user',
          repository: repository,
          sessions: _Sessions(_session()),
        ),
      );
      expect(find.text('Bu etkinliğe katılıyorsun!'), findsOneWidget);
      expect(find.text('Planımı düzenle'), findsNothing);
      await tester.tap(find.byTooltip('Paylaşım seçenekleri'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Paylaşımı sil'));
      await tester.pumpAndSettle();
      expect(repository.deletedPosts, isEmpty);
      await tester.tap(find.text('Vazgeç'));
      await tester.pumpAndSettle();
      expect(repository.deletedPosts, isEmpty);
      expect(find.byType(ListenerEventPostCard), findsOneWidget);
      await tester.tap(find.byTooltip('Paylaşım seçenekleri'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Paylaşımı sil'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('listener-event-post-delete-confirm')),
      );
      await tester.pumpAndSettle();
      expect(repository.deletedPosts, [('post-event', 'user')]);
      expect(repository.getCalls, 0);
      expect(find.byType(ListenerEventPostCard), findsNothing);
    },
  );

  for (final change in ['account', 'refresh', 'republication']) {
    testWidgets(
      'delete confirmation cannot remove a stale post after $change',
      (tester) async {
        final repository = _Repository();
        final sessions = _Sessions(_session());
        await _mount(
          tester,
          ListenerEventPostsSection(
            listenerProfileId: 'profile',
            username: 'listener',
            ownerUserId: 'user',
            repository: repository,
            sessions: sessions,
          ),
        );
        await tester.tap(find.byTooltip('Paylaşım seçenekleri'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Paylaşımı sil'));
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsOneWidget);
        if (change == 'account') {
          sessions.change(_session(userId: 'other', token: 'other-token'));
        } else {
          if (change == 'republication') {
            repository.posts = [_post(postId: 'new-publication')];
          }
          repository.changes.value++;
        }
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsNothing);
        expect(repository.deletedPosts, isEmpty);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'failed post deletion preserves card and shows retryable feedback',
    (tester) async {
      final repository = _Repository()..deleteFailure = true;
      await _mount(
        tester,
        ListenerEventPostsSection(
          listenerProfileId: 'profile',
          username: 'listener',
          ownerUserId: 'user',
          repository: repository,
          sessions: _Sessions(_session()),
        ),
      );
      await tester.tap(find.byTooltip('Paylaşım seçenekleri'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Paylaşımı sil'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('listener-event-post-delete-confirm')),
      );
      await tester.pumpAndSettle();
      expect(repository.deletedPosts, [('post-event', 'user')]);
      expect(find.byType(ListenerEventPostCard), findsOneWidget);
      expect(find.text('Paylaşım silinemedi.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('post comments clear when the viewing session changes', (
    tester,
  ) async {
    final repository = _Repository();
    final comments = _CommentsRepository();
    final sessions = _Sessions(_session());
    serviceLocator.registerSingleton<EngagementRepository>(comments);
    await _mount(
      tester,
      ListenerEventPostsSection(
        listenerProfileId: 'profile',
        username: 'listener',
        repository: repository,
        sessions: sessions,
      ),
    );
    await tester.tap(
      find.byKey(const ValueKey('listener-event-comments-event')),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Eski oturum taslağı');
    sessions.change(_session(userId: 'other', token: 'new-token'));
    await tester.pumpAndSettle();
    expect(find.text('Eski oturum taslağı'), findsNothing);
    expect(
      find.text('Oturum değişti. Paylaşımı yeniden açabilirsin.'),
      findsOneWidget,
    );
    expect(comments.writes, isEmpty);
    expect(tester.takeException(), isNull);
  });

  for (final change in ['removed', 'republication', 'privacy']) {
    testWidgets('open post comments are revoked after feed $change', (
      tester,
    ) async {
      final repository = _Repository();
      final comments = _CommentsRepository();
      serviceLocator.registerSingleton<EngagementRepository>(comments);
      await _mount(
        tester,
        ListenerEventPostsSection(
          listenerProfileId: 'profile',
          username: 'listener',
          repository: repository,
          sessions: _Sessions(_session()),
        ),
      );
      await tester.tap(
        find.byKey(const ValueKey('listener-event-comments-event')),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Artık görünmemeli');
      if (change == 'privacy') {
        repository.publicFailure = true;
      } else {
        repository.posts = change == 'republication'
            ? [_post(postId: 'new-publication')]
            : [];
      }
      repository.changes.value++;
      await tester.pumpAndSettle();
      expect(find.text('Artık görünmemeli'), findsNothing);
      expect(find.byType(TextField), findsNothing);
      expect(comments.writes, isEmpty);
      expect(tester.takeException(), isNull);
      // A later feed response cannot resurrect this modal's old publication.
      repository.publicFailure = false;
      repository.posts = [_post()];
      repository.changes.value++;
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

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
      expect(
        find.text('Listener bu etkinliğe gitmeyi planlamıştı.'),
        findsOneWidget,
      );
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
      final readsBeforeStaleActions = repository.getCalls;
      oldCard.onOpen!();
      oldCard.onIntent!();
      oldCard.onShare!();
      oldCard.onComments?.call();
      await tester.pumpAndSettle();
      expect(opened, isEmpty);
      expect(repository.getCalls, readsBeforeStaleActions);
      expect(repository.intentWrites, isEmpty);
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
      expect(
        find.textContaining('Listener bu etkinliğe gitmeyi planlamıştı.'),
        findsOneWidget,
      );
      expect(find.textContaining('Hayalet modda gizli'), findsOneWidget);
      expect(find.text('Planımı düzenle'), findsNothing);
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
            onComments: () {},
          ),
          scale: scale,
        );
        expect(tester.takeException(), isNull);
        expect(find.textContaining('katılmayı düşünüyor.'), findsOneWidget);
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
          expect(
            size.height,
            greaterThanOrEqualTo(
              key == 'listener-event-intent-event' ? 32 : 48,
            ),
          );
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
  String username = 'listener',
  String role = 'ROLE_LISTENER',
  String status = 'ACTIVE',
  List<String> extraRoles = const [],
}) => AuthSession.authenticated(
  token: token,
  userId: userId,
  username: username,
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
  EventAudienceState viewerIntent = _state(intent: EventAudienceStatus.none);
  final intentWrites = <(EventAudienceStatus, bool, String?, int, String)>[];
  Completer<Result<EventAudienceState>>? pendingIntent;
  Completer<Result<EventAudienceState>>? pendingRead;
  bool failIntent = false;
  final deletedPosts = <(String, String)>[];
  bool deleteFailure = false;
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
    if (pendingRead != null) return pendingRead!.future;
    return Result.success(viewerIntent);
  }

  @override
  Future<Result<EventAudienceState>> setIntent({
    required String eventId,
    required EventAudienceStatus intent,
    required bool publishedOnProfile,
    required String? note,
    required int expectedVersion,
    required String expectedSessionKey,
  }) async {
    intentWrites.add((
      intent,
      publishedOnProfile,
      note,
      expectedVersion,
      expectedSessionKey,
    ));
    if (pendingIntent != null) return pendingIntent!.future;
    if (failIntent) {
      return const Result.failure(
        AppError(code: 'network', message: 'Offline'),
      );
    }
    viewerIntent = _state(
      id: eventId,
      intent: intent,
      published: publishedOnProfile,
      note: note,
      version: expectedVersion + 1,
    );
    changes.value++;
    return Result.success(viewerIntent);
  }

  @override
  Future<Result<EventAudienceState>> deletePost({
    required String postId,
    required String expectedSessionKey,
  }) async {
    deletedPosts.add((postId, expectedSessionKey));
    if (deleteFailure) {
      return const Result.failure(
        AppError(code: 'network', message: 'Paylaşım silinemedi.'),
      );
    }
    posts = [];
    changes.value++;
    return Result.success(_state());
  }
}

class _CommentsRepository extends Fake implements EngagementRepository {
  final reads = <(String, String)>[];
  final writes = <(String, String, String)>[];
  final likes = <(String, String, bool)>[];
  final likedPosts = <String>{};
  bool failLike = false;
  Completer<Result<void>>? pendingLike;
  Completer<Result<bool>>? pendingIsLiked;

  @override
  Future<Result<int>> getLikeCount({
    required String targetType,
    required String targetId,
  }) async => Result.success(likedPosts.contains(targetId) ? 1 : 0);

  @override
  Future<Result<bool>> isLiked({
    required String targetType,
    required String targetId,
  }) async {
    final pending = pendingIsLiked;
    pendingIsLiked = null;
    return pending != null
        ? pending.future
        : Result.success(likedPosts.contains(targetId));
  }

  @override
  Future<Result<void>> like({
    required String targetType,
    required String targetId,
  }) async {
    likes.add((targetType, targetId, true));
    if (pendingLike != null) return pendingLike!.future;
    if (failLike) {
      return const Result.failure(
        AppError(code: 'network', message: 'Beğeni kaydedilemedi.'),
      );
    }
    likedPosts.add(targetId);
    return const Result.success(null);
  }

  @override
  Future<Result<void>> unlike({
    required String targetType,
    required String targetId,
  }) async {
    likes.add((targetType, targetId, false));
    likedPosts.remove(targetId);
    return const Result.success(null);
  }

  @override
  Future<Result<CommentPage>> listComments({
    required String targetType,
    required String targetId,
    int page = 0,
    int size = 20,
  }) async {
    reads.add((targetType, targetId));
    return Result.success(
      CommentPage(
        items: const [],
        totalElements: writes.length,
        page: page,
        size: size,
      ),
    );
  }

  @override
  Future<Result<CommentItem>> createComment({
    required String targetType,
    required String targetId,
    required String text,
    String? parentCommentId,
  }) async {
    writes.add((targetType, targetId, text));
    return Result.success(
      CommentItem(
        id: 'new-comment',
        user: const CommentUserSummary(
          id: 'user',
          username: 'listener',
          avatarUrl: null,
        ),
        text: text,
        deleted: false,
        parentCommentId: parentCommentId,
        replyCount: 0,
        createdAt: DateTime.now(),
      ),
    );
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
  String? note,
  int version = 1,
  EventAudienceStatus intent = EventAudienceStatus.going,
}) => EventAudienceState(
  eventId: id,
  postId: published ? 'post-$id' : null,
  intent: intent,
  publishedOnProfile: published,
  note: note,
  version: version,
  updatedAt: DateTime.utc(2026, 9, 8),
  eventAvailable: available,
  eventEnded: ended,
  canSetIntent: !ended,
  canPublish: !ended,
  publicationVisible: visible,
  event: available ? _event(id: id) : null,
);

EventAudiencePost _post({bool ended = false, String postId = 'post-event'}) =>
    EventAudiencePost(
      eventId: 'event',
      postId: postId,
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
