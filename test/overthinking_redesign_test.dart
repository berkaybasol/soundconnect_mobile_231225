import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart' hide Page;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:soundconnect_23_12_25codx/shared/widgets/gradient_outline_button.dart';
import 'package:soundconnect_23_12_25codx/app/router/app_routes.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session_manager.dart';
import 'package:soundconnect_23_12_25codx/core/auth/token_store.dart';
import 'package:soundconnect_23_12_25codx/core/di/service_locator.dart';
import 'package:soundconnect_23_12_25codx/core/error/app_error.dart';
import 'package:soundconnect_23_12_25codx/core/error/result.dart';
import 'package:soundconnect_23_12_25codx/core/pagination/page.dart';
import 'package:soundconnect_23_12_25codx/modules/dm/domain/dm_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/dm/domain/dm_user_profile_resolver.dart';
import 'package:soundconnect_23_12_25codx/modules/dm/domain/entities/dm_profile_target.dart';
import 'package:soundconnect_23_12_25codx/modules/dm/presentation/cubit/dm_badge_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/engagement/domain/engagement_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/engagement/domain/entities/comment_page.dart';
import 'package:soundconnect_23_12_25codx/modules/engagement/presentation/cubit/comment_thread_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/overthinking/domain/entities/overthinking_post.dart';
import 'package:soundconnect_23_12_25codx/modules/overthinking/domain/entities/overthinking_incoming_unread_status.dart';
import 'package:soundconnect_23_12_25codx/modules/overthinking/domain/entities/overthinking_reveal_request.dart';
import 'package:soundconnect_23_12_25codx/modules/overthinking/domain/overthinking_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/overthinking/domain/overthinking_feed_sort.dart';
import 'package:soundconnect_23_12_25codx/modules/overthinking/presentation/cubit/overthinking_feed_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/overthinking/presentation/screens/overthinking_feed_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/overthinking/presentation/screens/overthinking_manage_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/listener_visibility_mode.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/profile_route_args.dart';
import 'package:soundconnect_23_12_25codx/modules/spotify/data/spotify_endpoints.dart';
import 'package:soundconnect_23_12_25codx/modules/spotify/data/spotify_repository_impl.dart';
import 'package:soundconnect_23_12_25codx/modules/spotify/domain/entities/spotify_track_preview.dart';
import 'package:soundconnect_23_12_25codx/modules/spotify/domain/spotify_repository.dart';

import 'support/recording_api_client.dart';
import 'support/event_audience_fakes.dart';

const _preview = bool.fromEnvironment('OVERTHINKING_PREVIEW');
const _previewKey = ValueKey('overthinking-preview-boundary');
const _titleKey = ValueKey('overthinking-title');
const _contentKey = ValueKey('overthinking-content');
const _publishKey = ValueKey('overthinking-publish');
const _searchKey = ValueKey('overthinking-spotify-search');

void main() {
  late _Posts posts;
  late _Spotify spotify;
  late _Engagement engagement;
  late DmBadgeCubit badge;
  final cubits = <OverthinkingFeedCubit>[];

  OverthinkingFeedCubit makeCubit() {
    final cubit = OverthinkingFeedCubit(
      overthinkingRepository: posts,
      engagementRepository: engagement,
      sessions: serviceLocator.isRegistered<AuthSessionManager>()
          ? serviceLocator<AuthSessionManager>()
          : null,
    );
    cubits.add(cubit);
    return cubit;
  }

  setUp(() async {
    await serviceLocator.reset();
    posts = _Posts();
    spotify = _Spotify();
    engagement = _Engagement();
    badge = DmBadgeCubit(_NoopDm(), _EmptyTokenStore());
    serviceLocator
      ..registerSingleton<OverthinkingRepository>(posts)
      ..registerSingleton<EngagementRepository>(engagement)
      ..registerSingleton<SpotifyRepository>(spotify)
      ..registerSingleton<DmBadgeCubit>(badge)
      ..registerFactory<OverthinkingFeedCubit>(makeCubit)
      ..registerFactory<CommentThreadCubit>(
        () => CommentThreadCubit(engagement),
      );
  });

  tearDown(() async {
    for (final cubit in cubits) {
      if (!cubit.isClosed) await cubit.close();
    }
    cubits.clear();
    await badge.close();
    await serviceLocator.reset();
  });

  for (final layout in [
    (width: 320.0, scale: 1.6),
    (width: 390.0, scale: 1.0),
  ]) {
    testWidgets(
      'populated feed fits ${layout.width}dp at ${layout.scale} text scale',
      (tester) async {
        posts.items = [
          _post().copyWith(
            spotifyTrackUrl: 'https://open.spotify.com/track/preview',
            spotifyTrackName: 'Geceyi Dinlerken',
            spotifyArtistName: 'Deniz',
          ),
          _post(id: 'second', title: 'Bir şarkının bıraktığı yer'),
        ];
        await _mount(
          tester,
          const OverthinkingFeedScreen(),
          width: layout.width,
          scale: layout.scale,
        );
        expect(
          find.byKey(const ValueKey('overthinking-hero-title')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('overthinking-create')),
          findsOneWidget,
        );
        expect(find.textContaining('dk okuma'), findsWidgets);
        expect(tester.takeException(), isNull);
        if (layout.width == 390) {
          await _capture(tester, 'feed-390x844');
          if (_preview) {
            await tester.drag(
              find.byType(CustomScrollView),
              const Offset(0, -220),
            );
            await tester.pumpAndSettle();
            await _capture(tester, 'feed-music-390x844');
          }
        }
        await _scrollTo(tester, find.text('Bir şarkının bıraktığı yer'));
        expect(find.text('Bir şarkının bıraktığı yer'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'incoming dot clears on opening and only a new request brings it back',
    (tester) async {
      posts.latestRevision = 3;
      await _mount(tester, const OverthinkingFeedScreen());
      await _capture(tester, 'feed-incoming-dot-390x844');
      expect(
        find.text('Birbirimizi tanımıyoruz. Ama bu hissi biliyoruz.'),
        findsOneWidget,
      );
      final badge = find.byKey(
        const ValueKey('overthinking-incoming-request-dot'),
      );
      final navigationBadge = find.byKey(
        const ValueKey('overthinking-navigation-unread-dot'),
      );
      expect(tester.widget<Badge>(navigationBadge).isLabelVisible, isTrue);
      expect(tester.widget<Badge>(badge).isLabelVisible, isTrue);
      expect(tester.widget<Badge>(badge).label, isNull);
      await tester.tap(find.text('Gelen istekler'));
      await tester.pumpAndSettle();
      expect(posts.seenRevisions, [3]);
      expect(tester.widget<Badge>(navigationBadge).isLabelVisible, isFalse);
      // The request is still pending; merely entering the inbox marks it seen.
      expect(find.text('Kabul et'), findsOneWidget);
      Navigator.of(tester.element(find.byType(OverthinkingManageScreen))).pop();
      await tester.pumpAndSettle();
      expect(tester.widget<Badge>(badge).isLabelVisible, isFalse);
      expect(tester.widget<Badge>(navigationBadge).isLabelVisible, isFalse);
      await tester
          .widget<RefreshIndicator>(find.byType(RefreshIndicator))
          .onRefresh();
      await tester.pumpAndSettle();
      expect(tester.widget<Badge>(badge).isLabelVisible, isFalse);
      await tester.pumpWidget(const SizedBox.shrink());
      await _mount(tester, const OverthinkingFeedScreen());
      expect(tester.widget<Badge>(badge).isLabelVisible, isFalse);
      posts.latestRevision = 4;
      await tester
          .widget<RefreshIndicator>(find.byType(RefreshIndicator))
          .onRefresh();
      await tester.pumpAndSettle();
      expect(tester.widget<Badge>(badge).isLabelVisible, isTrue);
      expect(tester.widget<Badge>(navigationBadge).isLabelVisible, isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  for (final layout in [
    (width: 390.0, scale: 1.0),
    (width: 320.0, scale: 1.6),
  ]) {
    testWidgets('feed sort menu replaces the count at ${layout.width}dp', (
      tester,
    ) async {
      posts.items = [_post(), _post(id: 'older', title: 'Eski bir yazı')];
      await _mount(
        tester,
        const OverthinkingFeedScreen(),
        width: layout.width,
        scale: layout.scale,
      );
      expect(find.text('2 yazı'), findsNothing);
      final sort = find.byKey(const ValueKey('overthinking-sort'));
      await tester.tap(sort);
      await tester.pumpAndSettle();
      expect(find.text('En yeni'), findsOneWidget);
      expect(find.text('En çok beğenilenler'), findsOneWidget);
      expect(find.text('En eski'), findsOneWidget);
      if (layout.width == 390) await _capture(tester, 'feed-sort-390x844');
      await tester.tap(
        find.widgetWithText(
          CheckedPopupMenuItem<OverthinkingFeedSort>,
          'En çok beğenilenler',
        ),
      );
      await tester.pumpAndSettle();
      expect(posts.sortLoads, [
        OverthinkingFeedSort.newest,
        OverthinkingFeedSort.mostLiked,
      ]);
      await tester
          .widget<RefreshIndicator>(find.byType(RefreshIndicator))
          .onRefresh();
      await tester.pumpAndSettle();
      expect(posts.sortLoads.last, OverthinkingFeedSort.mostLiked);
      await tester.tap(sort);
      await tester.pumpAndSettle();
      final selected = tester
          .widget<CheckedPopupMenuItem<OverthinkingFeedSort>>(
            find.widgetWithText(
              CheckedPopupMenuItem<OverthinkingFeedSort>,
              'En çok beğenilenler',
            ),
          );
      expect(selected.checked, isTrue);
      await tester.tap(
        find.widgetWithText(
          CheckedPopupMenuItem<OverthinkingFeedSort>,
          'En eski',
        ),
      );
      await tester.pumpAndSettle();
      expect(posts.sortLoads.last, OverthinkingFeedSort.oldest);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'reveal button shows persisted sent state and withdraws on the next tap',
    (tester) async {
      final sessions = AudienceTestSessions(audienceSession(user: 'reader'));
      serviceLocator.registerSingleton<AuthSessionManager>(sessions);
      addTearDown(sessions.dispose);
      await _mount(tester, const OverthinkingFeedScreen());
      await tester.tap(find.text('Gecenin bir yerinde'));
      await tester.pumpAndSettle();
      final toggle = find.byKey(const ValueKey('overthinking-reveal-toggle'));
      await _scrollTo(tester, toggle);
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(posts.revealSends, 1);
      expect(find.text('Kimlik isteği gönderildi'), findsOneWidget);
      expect(
        find.descendant(of: toggle, matching: find.byIcon(Icons.check_rounded)),
        findsOneWidget,
      );
      await _capture(tester, 'detail-request-sent-390x844');
      Navigator.of(tester.element(find.byType(OverthinkingDetailScreen))).pop();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Gecenin bir yerinde'));
      await tester.pumpAndSettle();
      await _scrollTo(tester, toggle);
      expect(find.text('Kimlik isteği gönderildi'), findsOneWidget);
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(posts.revealCancels, 1);
      expect(find.text('Kimlik isteği gönder'), findsOneWidget);
      expect(posts.items.single.revealRequestPending, isFalse);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('failed withdrawal keeps the sent button and permits retry', (
    tester,
  ) async {
    final sessions = AudienceTestSessions(audienceSession(user: 'reader'));
    serviceLocator.registerSingleton<AuthSessionManager>(sessions);
    addTearDown(sessions.dispose);
    posts.items = [_post().copyWith(revealRequestPending: true)];
    posts.onCancelReveal = () async => const Result.failure(
      AppError(code: 'NETWORK', message: 'Bağlantı kurulamadı.'),
    );
    await _mount(tester, const OverthinkingFeedScreen());
    await tester.tap(find.text('Gecenin bir yerinde'));
    await tester.pumpAndSettle();
    final toggle = find.byKey(const ValueKey('overthinking-reveal-toggle'));
    await _scrollTo(tester, toggle);
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(find.text('Kimlik isteği gönderildi'), findsOneWidget);
    expect(find.text('Bağlantı kurulamadı.'), findsWidgets);
    posts.onCancelReveal = null;
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(find.text('Kimlik isteği gönder'), findsOneWidget);
    expect(posts.revealCancels, 2);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final surface in ['feed', 'mine', 'detail']) {
    for (final target in ['avatar', 'username']) {
      testWidgets(
        'visible author $target in $surface opens the resolved profile',
        (tester) async {
          final sessions = AudienceTestSessions(
            audienceSession(user: 'author'),
          );
          serviceLocator.registerSingleton<AuthSessionManager>(sessions);
          addTearDown(sessions.dispose);
          final profiles = _Profiles();
          serviceLocator.registerSingleton<DmUserProfileResolver>(profiles);
          posts.items = [
            _post().copyWith(
              anonymous: false,
              canViewAuthor: true,
              visibilityType: 'PUBLIC',
            ),
          ];
          final destinations = <RouteSettings>[];
          await _mount(
            tester,
            const OverthinkingFeedScreen(),
            profileRoutes: destinations,
          );
          if (surface == 'mine') {
            await tester.tap(find.text('Yazılarım'));
            await tester.pumpAndSettle();
          } else if (surface == 'detail') {
            await tester.tap(find.text('Gecenin bir yerinde'));
            await tester.pumpAndSettle();
          }
          final author = target == 'avatar'
              ? find.byKey(const ValueKey('overthinking-author-avatar-post'))
              : find.text('@deniz');
          await tester.ensureVisible(author);
          await tester.tap(author);
          await tester.pumpAndSettle();
          expect(profiles.lookups, ['author']);
          expect(destinations.single.name, AppRoutes.musicianPublicProfile);
          expect(
            (destinations.single.arguments as PublicProfileArgs).profileId,
            'musician-profile',
          );
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }
  }

  testWidgets('management navigation keeps the account that opened it', (
    tester,
  ) async {
    final sessions = AudienceTestSessions(audienceSession(user: 'writer'));
    serviceLocator.registerSingleton<AuthSessionManager>(sessions);
    addTearDown(sessions.dispose);
    await _mount(tester, const OverthinkingFeedScreen());
    await tester.tap(find.text('Yazılarım'));
    sessions.replace(audienceSession(user: 'other'));
    await tester.pumpAndSettle();
    expect(posts.mineLoads, 0);
    expect(find.textContaining('Oturum değişti.'), findsWidgets);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final viewer in ['author', 'approved-reader']) {
    testWidgets(
      'anonymous authorship is distinct from reveal access for $viewer in feed and detail',
      (tester) async {
        final sessions = AudienceTestSessions(audienceSession(user: viewer));
        serviceLocator.registerSingleton<AuthSessionManager>(sessions);
        addTearDown(sessions.dispose);
        posts.items = [
          _post().copyWith(authorId: 'author', canViewAuthor: true),
        ];
        final label = viewer == 'author'
            ? 'Anonim olarak paylaştın'
            : 'Kimliği sana açık';
        final otherLabel = viewer == 'author'
            ? 'Kimliği sana açık'
            : 'Anonim olarak paylaştın';
        await _mount(tester, const OverthinkingFeedScreen());
        await _scrollTo(tester, find.text('Gecenin bir yerinde'));
        expect(find.textContaining(label), findsOneWidget);
        expect(find.textContaining(otherLabel), findsNothing);
        await tester.tap(find.text('Gecenin bir yerinde'));
        await tester.pumpAndSettle();
        expect(find.textContaining(label), findsOneWidget);
        expect(find.textContaining(otherLabel), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets('only own feed cards offer delete and delete removes the post', (
    tester,
  ) async {
    final sessions = AudienceTestSessions(audienceSession(user: 'writer'));
    serviceLocator.registerSingleton<AuthSessionManager>(sessions);
    addTearDown(sessions.dispose);
    posts.items = [
      _post(id: 'mine').copyWith(authorId: 'writer', canViewAuthor: true),
      _post(
        id: 'other',
        title: 'Başka bir yazı',
      ).copyWith(authorId: 'someone', canViewAuthor: true),
    ];
    await _mount(tester, const OverthinkingFeedScreen());
    final ownDelete = find.byKey(const ValueKey('overthinking-delete-mine'));
    await _scrollTo(tester, ownDelete);
    expect(ownDelete, findsOneWidget);
    expect(
      find.byKey(const ValueKey('overthinking-delete-other')),
      findsNothing,
    );
    await tester.tap(ownDelete);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Vazgeç'));
    await tester.pumpAndSettle();
    expect(posts.deleted, isEmpty);
    await tester.tap(ownDelete);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Yazıyı sil'));
    await tester.pumpAndSettle();
    expect(posts.deleted, ['mine']);
    expect(find.byKey(const ValueKey('overthinking-post-mine')), findsNothing);
    expect(
      find.byKey(const ValueKey('overthinking-delete-other')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'create validates whitespace before calling repository at narrow large text',
    (tester) async {
      await _openCreate(tester, makeCubit(), width: 320, scale: 1.6);
      await tester.enterText(find.byKey(_titleKey), '   ');
      await tester.enterText(find.byKey(_contentKey), '   ');
      await _scrollTo(tester, find.byKey(_publishKey));
      await tester.tap(find.byKey(_publishKey));
      await tester.pumpAndSettle();
      expect(
        find.text('Başlık ve yazı alanlarını doldurmalısın.'),
        findsOneWidget,
      );
      expect(posts.submissions, isEmpty);
      expect(find.byType(OverthinkingCreateScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'back protects draft and lets writer continue or explicitly discard',
    (tester) async {
      await _openCreate(tester, makeCubit());
      await _capture(tester, 'create-390x844');
      if (_preview) {
        await _scrollTo(tester, find.byKey(_publishKey));
        await _capture(tester, 'create-publish-390x844');
        await _scrollTo(tester, find.byKey(_titleKey), delta: -250);
      }
      await tester.enterText(find.byKey(_titleKey), 'Yarım kalan bir cümle');
      await tester.enterText(find.byKey(_contentKey), 'Bu metin kaybolmasın.');
      await tester.tap(find.byTooltip('Geri'));
      await tester.pumpAndSettle();
      expect(find.text('Yazıyı bırakmak istiyor musun?'), findsOneWidget);
      await tester.tap(find.text('Yazmaya devam et'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byKey(_titleKey)).controller!.text,
        'Yarım kalan bir cümle',
      );
      expect(
        tester.widget<TextField>(find.byKey(_contentKey)).controller!.text,
        'Bu metin kaybolmasın.',
      );
      await tester.tap(find.byTooltip('Geri'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Vazgeç'));
      await tester.pumpAndSettle();
      expect(find.byType(OverthinkingCreateScreen), findsNothing);
      expect(find.text('Yazı alanını aç'), findsOneWidget);
      expect(posts.submissions, isEmpty);
    },
  );

  testWidgets(
    'failed submission retains text and chosen visibility for a successful retry',
    (tester) async {
      posts.onCreate = (_) async => const Result.failure(
        AppError(code: 'offline', message: 'Bağlantı kurulamadı; tekrar dene.'),
      );
      await _openCreate(tester, makeCubit());
      await tester.enterText(find.byKey(_titleKey), '  Geceye kalan  ');
      await tester.enterText(
        find.byKey(_contentKey),
        '  Bir şarkıyı tekrar dinledim.  ',
      );
      await _scrollTo(tester, find.text('Profilimle'));
      await tester.tap(find.text('Profilimle'));
      await _scrollTo(tester, find.byKey(_publishKey));
      await tester.tap(find.byKey(_publishKey));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Gönderimin sonucu doğrulanamadı.'),
        findsOneWidget,
      );
      expect(find.byType(OverthinkingCreateScreen), findsOneWidget);
      expect(posts.submissions.single, (
        title: 'Geceye kalan',
        content: 'Bir şarkıyı tekrar dinledim.',
        visibility: 'VISIBLE',
      ));
      await _scrollTo(tester, find.byKey(_titleKey), delta: -250);
      expect(
        tester.widget<TextField>(find.byKey(_titleKey)).controller!.text,
        '  Geceye kalan  ',
      );
      expect(
        tester.widget<TextField>(find.byKey(_contentKey)).controller!.text,
        '  Bir şarkıyı tekrar dinledim.  ',
      );
      posts.onCreate = (_) async => Result.success(_post(id: 'created'));
      await _scrollTo(tester, find.byKey(_publishKey));
      await tester.tap(find.byKey(_publishKey));
      await tester.pumpAndSettle();
      expect(posts.submissions, hasLength(2));
      expect(posts.submissions.last, posts.submissions.first);
      expect(find.byType(OverthinkingCreateScreen), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'pending publish disables duplicate submission and back until committed',
    (tester) async {
      final pending = Completer<Result<OverthinkingPost>>();
      posts.onCreate = (_) => pending.future;
      await _openCreate(tester, makeCubit());
      await tester.enterText(find.byKey(_titleKey), 'Tek bir yazı');
      await tester.enterText(
        find.byKey(_contentKey),
        'İki kere gönderilmesin.',
      );
      await _scrollTo(tester, find.byKey(_publishKey));
      await tester.tap(find.byKey(_publishKey));
      await tester.pump();
      expect(posts.submissions, hasLength(1));
      expect(posts.submissions.single.visibility, 'ANONYMOUS');
      expect(
        tester
            .widget<GradientOutlineButton>(
              find.descendant(
                of: find.byKey(_publishKey),
                matching: find.byType(GradientOutlineButton),
              ),
            )
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<IconButton>(
              find.widgetWithIcon(IconButton, Icons.arrow_back_rounded),
            )
            .onPressed,
        isNull,
      );
      final context = tester.element(find.byType(OverthinkingCreateScreen));
      await Navigator.of(context).maybePop();
      await tester.pump();
      expect(find.byType(OverthinkingCreateScreen), findsOneWidget);
      pending.complete(Result.success(_post(id: 'created')));
      await tester.pumpAndSettle();
      expect(find.byType(OverthinkingCreateScreen), findsNothing);
      expect(posts.submissions, hasLength(1));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Spotify picker respects API search limit and attaches the selected result',
    (tester) async {
      final client = RecordingApiClient(
        (_) => {
          'query': 'BRLN',
          'limit': 10,
          'tracks': [
            {
              'spotifyTrackId': '4uLU6hMCjMI75M1A2tKUQC',
              'name': 'Aranan şarkı',
              'spotifyUrl':
                  'https://open.spotify.com/track/4uLU6hMCjMI75M1A2tKUQC',
              'artistNames': ['BRLN'],
              'artistIds': ['0TnOYISbd1XYRBk9myaseg'],
            },
          ],
        },
      );
      await serviceLocator.unregister<SpotifyRepository>();
      serviceLocator.registerSingleton<SpotifyRepository>(
        SpotifyRepositoryImpl(client),
      );

      await _openCreate(tester, makeCubit());
      await _scrollTo(tester, find.text('Bir şarkı seç'));
      await tester.tap(find.text('Bir şarkı seç'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(_searchKey), ' BRLN ');
      await tester.pump(const Duration(milliseconds: 330));
      await tester.pumpAndSettle();

      expect(client.requests, hasLength(1));
      expect(client.lastRequest.method, RecordedHttpMethod.get);
      expect(client.lastRequest.path, SpotifyEndpoints.searchTracks);
      // SpotifyController accepts 1..10; the profile pickers also request 10.
      expect(client.lastRequest.query, {'q': 'BRLN', 'limit': 10});
      expect(find.text('Aranan şarkı'), findsOneWidget);
      await tester.tap(find.text('Aranan şarkı'));
      await tester.pumpAndSettle();
      expect(find.byKey(_searchKey), findsNothing);
      expect(find.text('Aranan şarkı'), findsOneWidget);
      expect(find.byTooltip('Şarkıyı kaldır'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'clearing Spotify query invalidates pending results and permits a fresh search',
    (tester) async {
      final stale = Completer<Result<List<SpotifyTrackPreview>>>();
      spotify.onSearch = (query) => query == 'eski'
          ? stale.future
          : Future.value(Result.success([_track('new', 'Yeni şarkı')]));
      await _openCreate(tester, makeCubit());
      await _scrollTo(tester, find.text('Bir şarkı seç'));
      await tester.tap(find.text('Bir şarkı seç'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(_searchKey), 'eski');
      await tester.pump(const Duration(milliseconds: 330));
      expect(spotify.queries, ['eski']);
      await tester.enterText(find.byKey(_searchKey), '');
      stale.complete(Result.success([_track('stale', 'Geciken şarkı')]));
      await tester.pumpAndSettle();
      expect(find.text('Geciken şarkı'), findsNothing);
      expect(find.text('Aramak için en az iki karakter yaz.'), findsOneWidget);
      await tester.enterText(find.byKey(_searchKey), 'yeni');
      await tester.pump(const Duration(milliseconds: 330));
      await tester.pumpAndSettle();
      expect(find.text('Yeni şarkı'), findsOneWidget);
      await tester.tap(find.text('Yeni şarkı'));
      await tester.pumpAndSettle();
      expect(find.byKey(_searchKey), findsNothing);
      expect(find.text('Yeni şarkı'), findsOneWidget);
      expect(find.byTooltip('Şarkıyı kaldır'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'hidden anonymous author never exposes stale identity or avatar in feed and detail',
    (tester) async {
      posts.items = [
        _post().copyWith(
          authorUsername: 'secret_real_handle',
          authorAvatarUrl: 'https://example.test/private-avatar.png',
          authorVisibilityMode: ListenerVisibilityMode.ghost,
          canViewAuthor: false,
        ),
      ];
      await _mount(tester, const OverthinkingFeedScreen());
      await _scrollTo(tester, find.text('Gecenin bir yerinde'));
      expect(find.text('@secret_real_handle'), findsNothing);
      expect(find.text('Anonim'), findsOneWidget);
      expect(find.bySemanticsLabel('Hayalet profil'), findsNothing);
      expect(_privateAvatar(), findsNothing);
      await tester.tap(find.text('Gecenin bir yerinde'));
      await tester.pumpAndSettle();
      await _capture(tester, 'detail-anonymous-390x844');
      await _scrollTo(tester, find.text('Kimlik isteği gönder'));
      expect(find.text('@secret_real_handle'), findsNothing);
      expect(_privateAvatar(), findsNothing);
      expect(find.text('Kimlik isteği gönder'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'revealed ghost author keeps contextual handle and badge without another reveal action',
    (tester) async {
      posts.items = [
        _post().copyWith(
          authorUsername: 'ghost_listener',
          authorVisibilityMode: ListenerVisibilityMode.ghost,
          canViewAuthor: true,
        ),
      ];
      await _mount(tester, const OverthinkingFeedScreen());
      await _scrollTo(tester, find.text('Gecenin bir yerinde'));
      expect(find.text('@ghost_listener'), findsOneWidget);
      expect(find.bySemanticsLabel('Hayalet profil'), findsOneWidget);
      await tester.tap(find.text('Gecenin bir yerinde'));
      await tester.pumpAndSettle();
      expect(find.text('@ghost_listener'), findsOneWidget);
      expect(find.bySemanticsLabel('Hayalet profil'), findsOneWidget);
      await _capture(tester, 'detail-ghost-390x844');
      await _scrollTo(tester, find.text('Yorumlar').first);
      expect(find.text('Kimlik isteği gönder'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}

Future<void> _mount(
  WidgetTester tester,
  Widget home, {
  double width = 390,
  double scale = 1,
  List<RouteSettings>? profileRoutes,
}) async {
  tester.view.physicalSize = Size(width, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  if (_preview) await _loadPreviewFonts(tester);
  await tester.pumpWidget(
    RepaintBoundary(
      key: _previewKey,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark(useMaterial3: true),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: home,
        onGenerateRoute: profileRoutes == null
            ? null
            : (settings) {
                profileRoutes.add(settings);
                return MaterialPageRoute<void>(
                  settings: settings,
                  builder: (_) => const Scaffold(body: Text('Profil')),
                );
              },
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _openCreate(
  WidgetTester tester,
  OverthinkingFeedCubit cubit, {
  double width = 390,
  double scale = 1,
}) async {
  await _mount(
    tester,
    Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: TextButton(
            onPressed: () => Navigator.of(context).push<void>(
              MaterialPageRoute(
                builder: (_) => BlocProvider.value(
                  value: cubit,
                  child: const OverthinkingCreateScreen(),
                ),
              ),
            ),
            child: const Text('Yazı alanını aç'),
          ),
        ),
      ),
    ),
    width: width,
    scale: scale,
  );
  await tester.tap(find.text('Yazı alanını aç'));
  await tester.pumpAndSettle();
}

Future<void> _scrollTo(
  WidgetTester tester,
  Finder target, {
  double delta = 250,
}) async {
  await tester.scrollUntilVisible(
    target,
    delta,
    scrollable: find.byType(Scrollable).first,
    maxScrolls: 25,
  );
  await tester.pumpAndSettle();
}

Finder _privateAvatar() => find.byWidgetPredicate(
  (widget) =>
      widget is Image &&
      widget.image is NetworkImage &&
      (widget.image as NetworkImage).url.contains('private-avatar'),
);

Future<void> _loadPreviewFonts(WidgetTester tester) async {
  await tester.runAsync(() async {
    final fonts =
        '${File(Platform.resolvedExecutable).parent.parent.parent.path}/material_fonts';
    final loader = FontLoader('Roboto');
    for (final name in [
      'roboto-regular.ttf',
      'roboto-medium.ttf',
      'roboto-bold.ttf',
      'roboto-black.ttf',
    ]) {
      loader.addFont(
        File('$fonts/$name').readAsBytes().then(ByteData.sublistView),
      );
    }
    await loader.load();
    await (FontLoader('Ahem')..addFont(
          File(
            '$fonts/roboto-regular.ttf',
          ).readAsBytes().then(ByteData.sublistView),
        ))
        .load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    await (FontLoader(
          'packages/${FontAwesomeIcons.spotify.fontPackage}/${FontAwesomeIcons.spotify.fontFamily}',
        )..addFont(
          rootBundle.load(
            'packages/font_awesome_flutter/lib/fonts/Font-Awesome-7-Brands-Regular-400.otf',
          ),
        ))
        .load();
  });
}

Future<void> _capture(WidgetTester tester, String name) async {
  if (!_preview) return;
  final context = tester.element(find.byKey(_previewKey));
  final assets = tester
      .widgetList<Image>(find.byType(Image))
      .map((image) => image.image)
      .whereType<AssetImage>()
      .toSet();
  await tester.runAsync(
    () => Future.wait([
      for (final asset in assets) precacheImage(asset, context),
    ]),
  );
  await tester.pumpAndSettle();
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(_previewKey),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final output = File('test/goldens/overthinking/$name.png');
      await output.parent.create(recursive: true);
      await output.writeAsBytes(bytes!.buffer.asUint8List());
    } finally {
      image.dispose();
    }
  });
}

typedef _Submission = ({String title, String content, String visibility});

class _Posts implements OverthinkingRepository {
  final sortLoads = <OverthinkingFeedSort>[];
  int revealSends = 0;
  int revealCancels = 0;
  Future<Result<void>> Function()? onCancelReveal;
  int mineLoads = 0;
  int latestRevision = 0;
  int seenRevision = 0;
  final seenRevisions = <int>[];
  final deleted = <String>[];
  List<OverthinkingPost> items = [_post()];
  final submissions = <_Submission>[];
  Future<Result<OverthinkingPost>> Function(_Submission)? onCreate;

  @override
  Future<Result<Page<OverthinkingPost>>> getMyPosts({
    int page = 0,
    int size = 20,
  }) async {
    mineLoads++;
    return Result.success(Page(items: items, hasNext: false));
  }

  @override
  Future<Result<OverthinkingIncomingUnreadStatus>>
  getIncomingUnreadStatus() async => Result.success(
    OverthinkingIncomingUnreadStatus(
      hasUnread: latestRevision > seenRevision,
      revision: latestRevision,
    ),
  );

  @override
  Future<Result<OverthinkingIncomingUnreadStatus>> markIncomingRequestsSeen({
    required int revision,
  }) async {
    seenRevisions.add(revision);
    seenRevision = revision;
    return getIncomingUnreadStatus();
  }

  @override
  Future<Result<Page<OverthinkingRevealRequest>>> getIncomingRevealRequests({
    int page = 0,
    int size = 20,
  }) async => Result.success(
    Page(
      items: [
        OverthinkingRevealRequest(
          id: 'request',
          postId: 'a',
          postTitle: 'Gecenin bir yerinde',
          requesterId: 'reader',
          requesterUsername: 'reader',
          authorId: 'author',
          status: 'PENDING',
          createdAt: null,
        ),
      ],
      hasNext: false,
    ),
  );

  @override
  Future<Result<Page<OverthinkingRevealRequest>>> getSentRevealRequests({
    int page = 0,
    int size = 20,
  }) async => const Result.success(Page(items: [], hasNext: false));

  @override
  Future<Result<void>> deletePost({required String postId}) async {
    deleted.add(postId);
    items = items.where((post) => post.id != postId).toList();
    return const Result.success(null);
  }

  @override
  Future<Result<Page<OverthinkingPost>>> getFeed({
    int page = 0,
    int size = 20,
    OverthinkingFeedSort sort = OverthinkingFeedSort.newest,
  }) async {
    sortLoads.add(sort);
    return Result.success(Page(items: items, hasNext: false));
  }

  @override
  Future<Result<void>> requestReveal({required String postId}) async {
    revealSends++;
    items = [
      for (final post in items)
        post.id == postId ? post.copyWith(revealRequestPending: true) : post,
    ];
    return const Result.success(null);
  }

  @override
  Future<Result<void>> cancelReveal({required String postId}) async {
    revealCancels++;
    final result =
        await (onCancelReveal?.call() ??
            Future.value(const Result<void>.success(null)));
    if (result.isSuccess) {
      items = [
        for (final post in items)
          post.id == postId ? post.copyWith(revealRequestPending: false) : post,
      ];
    }
    return result;
  }

  @override
  Future<Result<OverthinkingPost>> getDetail({required String postId}) async =>
      Result.success(items.firstWhere((post) => post.id == postId));

  @override
  Future<Result<OverthinkingPost>> createPost({
    String? clientRequestId,
    required String title,
    required String content,
    required String visibilityType,
    String? spotifyTrackUrl,
    String? spotifyArtistId,
    String? spotifyTrackName,
    String? spotifyArtistName,
    String? spotifyAlbumImageUrl,
  }) async {
    final submission = (
      title: title,
      content: content,
      visibility: visibilityType,
    );
    submissions.add(submission);
    return onCreate?.call(submission) ?? Result.success(_post(id: 'created'));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError(invocation.memberName.toString());
}

class _Spotify implements SpotifyRepository {
  final queries = <String>[];
  Future<Result<List<SpotifyTrackPreview>>> Function(String query)? onSearch;
  @override
  Future<Result<List<SpotifyTrackPreview>>> searchTracks(
    String query, {
    int limit = 5,
  }) async {
    queries.add(query);
    return onSearch?.call(query) ?? const Result.success([]);
  }

  @override
  Future<Result<List<SpotifyTrackPreview>>> getTracksByIds(
    List<String> ids,
  ) async => const Result.success([]);
}

class _Engagement implements EngagementRepository {
  @override
  Future<Result<CommentPage>> listComments({
    required String targetType,
    required String targetId,
    int page = 0,
    int size = 20,
  }) async => const Result.success(CommentPage(items: [], totalElements: 0));
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError(invocation.memberName.toString());
}

class _NoopDm implements DmRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError(invocation.memberName.toString());
}

class _EmptyTokenStore implements TokenStore {
  @override
  Future<void> clear() async {}
  @override
  Future<String?> readToken() async => null;
  @override
  Future<void> writeToken(String token) async {}
}

class _Profiles implements DmUserProfileResolver {
  final lookups = <String>[];
  @override
  Future<List<DmProfileTarget>> resolveByUserId({
    required String userId,
    String? usernameHint,
  }) async {
    lookups.add(userId);
    return const [
      DmProfileTarget(
        type: DmProfileTargetType.musician,
        id: 'musician-profile',
        displayName: 'Deniz',
        imageUrl: null,
      ),
    ];
  }
}

SpotifyTrackPreview _track(String id, String name) => SpotifyTrackPreview(
  id: id,
  name: name,
  previewUrl: null,
  durationSeconds: 180,
  spotifyUrl: 'https://open.spotify.com/track/$id',
  albumImageUrl: null,
  artistNames: const ['Bir Müzisyen'],
  artistIds: const ['artist'],
);

OverthinkingPost _post({
  String id = 'post',
  String title = 'Gecenin bir yerinde',
}) => OverthinkingPost(
  id: id,
  authorId: 'author',
  authorUsername: 'deniz',
  authorAvatarUrl: null,
  anonymous: true,
  canViewAuthor: false,
  visibilityType: 'ANONYMOUS',
  title: title,
  content:
      'Bazı şarkılar bizi bir yere götürmüyor; olduğumuz yerde biraz daha kalmamızı sağlıyor.',
  spotifyTrackUrl: null,
  spotifyArtistId: null,
  spotifyTrackName: null,
  spotifyArtistName: null,
  spotifyAlbumImageUrl: null,
  musicianTrackId: null,
  bandTrackId: null,
  artistId: null,
  artistType: null,
  likeCount: 24,
  commentCount: 6,
  likedByMe: false,
);
