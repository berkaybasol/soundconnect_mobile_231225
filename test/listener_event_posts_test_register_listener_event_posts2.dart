part of 'listener_event_posts_test.dart';

extension _RegisterListenerEventPosts2 on _ListenerEventPostsCases {
  void _registerListenerEventPosts2() {
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
        expect(find.text('Bu etkinliğe gidiyor.'), findsOneWidget);
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
          repository.intentWrites.every(
            (write) => !write.$2 && write.$3 == null,
          ),
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
        expect(find.text('Bu etkinliğe gidiyor.'), findsOneWidget);
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
        await tester.tap(
          find.byKey(const ValueKey('listener-event-open-event')),
        );
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

    testWidgets(
      'comment-close count refresh waits for an older stats request',
      (tester) async {
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
      },
    );

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
          expect(
            find.byKey(const Key('listener-share-delete-dialog')),
            findsOneWidget,
          );
          if (change == 'account') {
            sessions.change(_session(userId: 'other', token: 'other-token'));
          } else {
            if (change == 'republication') {
              repository.posts = [_post(postId: 'new-publication')];
            }
            repository.changes.value++;
          }
          await tester.pumpAndSettle();
          expect(
            find.byKey(const Key('listener-share-delete-dialog')),
            findsNothing,
          );
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
        expect(find.text('Bu etkinliğe gitmeyi planlamıştı.'), findsOneWidget);
        expect(find.text('Ben de gidiyorum'), findsNothing);
        expect(
          find.byKey(const ValueKey('listener-event-open-event')),
          findsOneWidget,
        );
      },
    );
  }
}
