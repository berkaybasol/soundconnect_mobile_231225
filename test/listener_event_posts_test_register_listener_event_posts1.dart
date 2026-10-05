part of 'listener_event_posts_test.dart';

extension _RegisterListenerEventPosts1 on _ListenerEventPostsCases {
  void _registerListenerEventPosts1() {
    setUp(() async => serviceLocator.reset());

    tearDown(() async => serviceLocator.reset());

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
        expect(
          tester.widget<TextField>(input).controller!.text,
          'Eski açıklama',
        );
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

    testWidgets(
      'session switch dismisses owner editor and prevents stale save',
      (tester) async {
        final repository = _Repository()
          ..viewerIntent = _state(published: true);
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
      },
    );

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
            .widget<TextButton>(
              find.byKey(const Key('listener-post-note-save')),
            )
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

    testWidgets('owner note cancel leaves publication untouched', (
      tester,
    ) async {
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

    testWidgets(
      'metadata-only session replacement keeps owner actions usable',
      (tester) async {
        final repository = _Repository()
          ..viewerIntent = _state(published: true);
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
      },
    );

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
        final repository = _Repository()
          ..viewerIntent = _state(published: true);
        await mountOwner(tester, repository, _Sessions(_session()));
        await ownerMenu(tester, 'Açıklamayı düzenle');
        final input = find.byKey(const Key('listener-post-note-input'));
        const family =
            '👨‍👩‍👧‍👦'; // One grapheme, seven Unicode code points.
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
          await (FontLoader('MaterialIcons')
                ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
              .load();
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
            final bytes = await pixels.toByteData(
              format: ui.ImageByteFormat.png,
            );
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
          final feed = _feed(
            repository,
            sessions,
            privatePlans: false,
            size: 2,
          );
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
          final old =
              Completer<Result<EventAudiencePage<EventAudienceState>>>();
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

      test(
        'ghost public empty response clears retained publications',
        () async {
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
        },
      );

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
  }
}
