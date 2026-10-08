part of 'listener_event_posts_test.dart';

extension _RegisterListenerEventPosts3 on _ListenerEventPostsCases {
  void _registerListenerEventPosts3() {
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
            .widget<TextButton>(
              find.byKey(const Key('listener-event-posts-all')),
            )
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
        await tester.ensureVisible(
          find.byKey(const Key('listener-plans-next')),
        );
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
          find.textContaining('Bu etkinliğe gitmeyi planlamıştı.'),
          findsOneWidget,
        );
        expect(find.textContaining('Hayalet modda gizli'), findsOneWidget);
        expect(find.text('Planımı düzenle'), findsNothing);
        expect(find.text('Katıldı'), findsNothing);
        expect(find.text('Ben de gidiyorum'), findsNothing);
      },
    );

    testWidgets('ghost public never mounts private plan action', (
      tester,
    ) async {
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
}
