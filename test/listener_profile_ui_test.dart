import 'dart:async';
import 'dart:convert';
import 'dart:ui' show SemanticsAction;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/app/router/app_routes.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session_manager.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session_store.dart';
import 'package:soundconnect_23_12_25codx/core/auth/token_store.dart';
import 'package:soundconnect_23_12_25codx/core/di/service_locator.dart';
import 'package:soundconnect_23_12_25codx/core/error/app_error.dart';
import 'package:soundconnect_23_12_25codx/core/error/result.dart';
import 'package:soundconnect_23_12_25codx/modules/follow/domain/follow_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/follow/presentation/cubit/follow_action_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/listener_profile.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/listener_public_profile.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/listener_visibility_mode.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/listener_profile_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/cubit/listener_profile_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/listener_ghost_profile_content.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/listener_playlist_manager_sheet.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/listener_profile_owner_content.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/listener_profile_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/listener_profile_preview_data.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/listener_profile_theme.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/listener_public_profile_content.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/listener_public_profile_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/profile_route_args.dart';
import 'package:soundconnect_23_12_25codx/shared/theme/app_theme.dart';
import 'package:soundconnect_23_12_25codx/modules/spotify/domain/entities/spotify_playlist_preview.dart';

void main() {
  testWidgets('ghost public profile exposes only identity and direct message', (
    tester,
  ) async {
    var messageCalls = 0;
    await tester.pumpWidget(
      _testApp(
        ListenerGhostProfileContent(
          username: 'berkaybasol',
          profilePictureUrl: null,
          owner: false,
          busy: false,
          onRefresh: () async {},
          onMessage: () => messageCalls += 1,
        ),
      ),
    );

    expect(find.text('@berkaybasol'), findsOneWidget);
    expect(find.text('HAYALET PROFİL'), findsOneWidget);
    expect(find.text('Görünürlüğü sınırlı'), findsOneWidget);
    expect(
      find.byKey(const Key('listener-owner-ghost-status-card')),
      findsNothing,
    );
    expect(find.text('Takip Et'), findsNothing);
    expect(find.text('Takipçi'), findsNothing);
    expect(find.text('Mesaj Gönder'), findsOneWidget);

    await tester.tap(find.text('Mesaj Gönder'));
    expect(messageCalls, 1);
  });

  testWidgets('ghost owner can edit avatar and return to standard mode', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    var editCalls = 0;
    var switchCalls = 0;
    await tester.pumpWidget(
      _testApp(
        ListenerGhostProfileContent(
          username: 'listener',
          profilePictureUrl: null,
          owner: true,
          busy: false,
          onRefresh: () async {},
          onEditAvatar: () => editCalls += 1,
          onSwitchToStandard: () => switchCalls += 1,
        ),
      ),
    );

    expect(
      find.byKey(const Key('listener-owner-ghost-status-card')),
      findsOneWidget,
    );
    expect(find.text('HAYALET PROFİL AKTİF'), findsOneWidget);
    expect(find.text('Hayalet modun açık'), findsOneWidget);
    expect(
      find.text(
        'SoundConnect’in bütün özelliklerinden faydalanabilirsin ancak profil içeriğin saklı kalır ve bu moddayken yeni profil içeriği kaydedilmez.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('Mainstage'), findsNothing);
    expect(find.textContaining('Hayalet profil kullanıyorsun'), findsNothing);
    expect(find.byKey(const Key('listener-owner-ghost-icon')), findsOneWidget);
    final ghostIcon = tester.widget<Image>(
      find.byKey(const Key('listener-owner-ghost-icon')),
    );
    expect((ghostIcon.image as AssetImage).assetName, 'assets/ghost (1).png');
    expect(
      find.byKey(const Key('listener-ghost-limited-visibility')),
      findsNothing,
    );
    expect(
      tester
          .getSize(find.byKey(const Key('listener-owner-ghost-status-card')))
          .height,
      greaterThanOrEqualTo(252),
    );
    expect(find.text('Mesajlar açık'), findsNothing);
    expect(
      tester.getCenter(find.text('İçerikler gizli')).dy,
      tester.getCenter(find.text('Takipçi alımı kapalı')).dy,
    );
    final cardSemantics = tester.getSemantics(
      find.byKey(const Key('listener-owner-ghost-status-summary')),
    );
    expect(
      cardSemantics.label,
      'Hayalet profil aktif. SoundConnect’in bütün özelliklerinden faydalanabilirsin ancak profil içeriğin saklı kalır ve bu moddayken yeni profil içeriği kaydedilmez. Yeni takipçi alımı kapalı.',
    );
    expect(cardSemantics.childrenCountInTraversalOrder, 0);
    expect(find.text('Sosyal Profile Dön'), findsOneWidget);
    expect(
      find.ancestor(
        of: find.text('Sosyal Profile Dön'),
        matching: find.byKey(const Key('listener-owner-ghost-status-card')),
      ),
      findsOneWidget,
    );
    expect(find.text('Mesaj Gönder'), findsNothing);
    expect(
      tester.getSize(find.byKey(const Key('listener-ghost-edit-avatar'))),
      const Size(48, 48),
    );

    final ghostAvatarEditTarget = find.byKey(
      const Key('listener-ghost-edit-avatar'),
    );
    await tester.tapAt(
      tester.getCenter(ghostAvatarEditTarget) + const Offset(20, 0),
    );
    await tester.ensureVisible(find.text('Sosyal Profile Dön'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sosyal Profile Dön'));
    expect(editCalls, 1);
    expect(switchCalls, 1);
    semantics.dispose();
  });

  testWidgets('standard owner fixtures require an explicit preview flag', (
    tester,
  ) async {
    await tester.pumpWidget(
      _testApp(
        ListenerProfileOwnerContent(
          profile: _owner,
          onEditProfile: () {},
          onEditAvatar: () {},
          onEditPlaylists: () {},
          onPlaylistTap: (_) {},
          onPreviewAction: (_) {},
        ),
      ),
    );

    expect(find.text('listener'), findsOneWidget);
    expect(find.text('Gerçek bio'), findsOneWidget);
    expect(
      find.textContaining('4 Takipçi', findRichText: true),
      findsOneWidget,
    );
    expect(find.byKey(const Key('listener-enable-ghost')), findsNothing);
    expect(
      find.byKey(const Key('listener-owner-ghost-status-card')),
      findsNothing,
    );
    expect(find.text('Çalma Listeleri'), findsOneWidget);
    expect(find.text('Müziğini profiline taşı'), findsOneWidget);
    expect(find.text('Paylaşımlar'), findsNothing);
    expect(find.text('Ankara Indie Night'), findsNothing);
  });

  testWidgets(
    'incomplete server owner projection repairs onboarding and opens chooser',
    (tester) async {
      await serviceLocator.reset();
      addTearDown(serviceLocator.reset);
      await _registerViewerSession('user-1');
      final manager = serviceLocator<AuthSessionManager>();
      const repository = _FixedOwnerListenerRepository(
        ListenerProfile(
          id: 'profile-1',
          userId: 'user-1',
          username: 'listener',
          bio: null,
          profilePictureUrl: null,
          followerCount: null,
          followingCount: null,
          visibilityMode: ListenerVisibilityMode.standard,
          version: 1,
          profileContentVisible: false,
          profileContentEditable: false,
          canReceiveFollowers: false,
          visibilityChoiceCompleted: false,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          routes: {
            AppRoutes.listenerProfileChoice: (_) =>
                const Scaffold(body: Text('choice-target')),
          },
          home: ListenerProfileScreen(
            cubitFactory: () => ListenerProfileCubit(repository),
            showBottomNavigation: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(manager.session.requiresListenerProfileChoice, isTrue);
      expect(find.text('choice-target'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await serviceLocator.reset();
    },
  );

  testWidgets('standard public profile uses only returned fields and actions', (
    tester,
  ) async {
    await tester.pumpWidget(
      _testApp(
        ListenerPublicProfileContent(
          profile: _public,
          isFollowing: false,
          followBusy: false,
          onRefresh: () async {},
          onPlaylistTap: (_) {},
          onFollow: () {},
          onMessage: () {},
        ),
      ),
    );

    expect(find.text('@listener'), findsOneWidget);
    expect(find.text('Gerçek public bio'), findsOneWidget);
    expect(
      find.textContaining('8 Takipçi', findRichText: true),
      findsOneWidget,
    );
    expect(find.text('Takip Et'), findsOneWidget);
    expect(find.text('Mesaj Gönder'), findsOneWidget);
    expect(find.text('Çalma Listeleri'), findsNothing);
    expect(find.text('Paylaşımlar'), findsNothing);
  });

  testWidgets(
    'owner playlist section shows square Spotify metadata and opens it',
    (tester) async {
      final semantics = tester.ensureSemantics();
      SpotifyPlaylistPreview? opened;
      await tester.pumpWidget(
        _testApp(
          ListenerProfileOwnerContent(
            profile: _ownerWithPlaylists,
            previewData: listenerOwnerPreviewData,
            showPreviewSections: true,
            onEditProfile: () {},
            onEditAvatar: () {},
            onEditPlaylists: () {},
            onPlaylistTap: (playlist) => opened = playlist,
            onPreviewAction: (_) {},
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Çalma Listeleri'), findsOneWidget);
      expect(find.text('Today’s Top Hits'), findsOneWidget);
      expect(find.text('Spotify'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Text &&
              RegExp(r'^\d+ şarkı$').hasMatch(widget.data?.trim() ?? ''),
        ),
        findsNothing,
      );
      expect(
        tester.getSize(find.byKey(const Key('listener-playlist-0'))).width,
        76,
      );
      final playlistSemantics = tester.getSemantics(
        find.bySemanticsLabel('Today’s Top Hits, Spotify’da aç'),
      );
      expect(
        playlistSemantics.getSemanticsData().hasAction(SemanticsAction.tap),
        isTrue,
      );

      await tester.tap(find.byKey(const Key('listener-playlist-0')));
      expect(opened?.spotifyPlaylistId, '37i9dQZF1DXcBWIGoYBM5M');
      semantics.dispose();
    },
  );

  testWidgets(
    'public playlist section is omitted when empty and shown when set',
    (tester) async {
      SpotifyPlaylistPreview? opened;
      await tester.pumpWidget(
        _testApp(
          ListenerPublicProfileContent(
            profile: _publicWithPlaylists,
            isFollowing: false,
            followBusy: false,
            onRefresh: () async {},
            onPlaylistTap: (playlist) => opened = playlist,
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Çalma Listeleri'), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('listener-playlist-0')));
      await tester.tap(find.byKey(const Key('listener-playlist-0')));
      expect(opened, same(_playlist));

      await tester.pumpWidget(
        _testApp(
          ListenerPublicProfileContent(
            profile: _public,
            isFollowing: false,
            followBusy: false,
            onRefresh: () async {},
            onPlaylistTap: (_) {},
          ),
        ),
      );
      expect(find.text('Çalma Listeleri'), findsNothing);
    },
  );

  testWidgets(
    'playlist manager validates duplicates and keeps save errors inline',
    (tester) async {
      List<String>? submitted;
      await tester.pumpWidget(
        _testApp(
          ListenerPlaylistManagerSheet(
            initialPlaylists: const <SpotifyPlaylistPreview>[],
            onSave: (spotifyUrls) async {
              submitted = spotifyUrls;
              return const ListenerPlaylistSaveResult.failure(
                'Spotify şu anda yanıt vermiyor.',
              );
            },
          ),
        ),
      );

      const sharedUrl =
          'https://open.spotify.com/playlist/37i9dQZF1DXcBWIGoYBM5M?si=test';
      await tester.enterText(
        find.byKey(const Key('listener-playlist-url-input')),
        sharedUrl,
      );
      await tester.tap(find.byKey(const Key('listener-playlist-url-commit')));
      await tester.pump();
      expect(find.textContaining('1/4'), findsOneWidget);
      expect(find.text('Spotify çalma listesi'), findsOneWidget);
      expect(
        tester.getSize(find.byKey(const Key('listener-playlist-drag-0'))),
        const Size.square(48),
      );

      await tester.enterText(
        find.byKey(const Key('listener-playlist-url-input')),
        sharedUrl,
      );
      await tester.tap(find.byKey(const Key('listener-playlist-url-commit')));
      await tester.pump();
      expect(find.text('Bu çalma listesi zaten profilinde.'), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('listener-playlist-url-input')),
        '',
      );
      await tester.tap(find.byKey(const Key('listener-playlist-save')));
      await tester.pumpAndSettle();
      expect(submitted, <String>[
        'https://open.spotify.com/playlist/37i9dQZF1DXcBWIGoYBM5M',
      ]);
      expect(find.text('Spotify şu anda yanıt vermiyor.'), findsOneWidget);
    },
  );

  testWidgets('playlist manager remains usable at 320px and 200% text', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      _scaledTestApp(
        ListenerPlaylistManagerSheet(
          initialPlaylists: const <SpotifyPlaylistPreview>[_playlist],
          onSave: (_) async => const ListenerPlaylistSaveResult.success(),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Çalma Listelerim'), findsOneWidget);
    expect(find.byKey(const Key('listener-playlist-save')), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('listener-playlist-drag-0')),
      160,
      scrollable: find
          .descendant(
            of: find.byKey(const Key('listener-playlist-manager-scroll')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pump();
    expect(find.byKey(const Key('listener-playlist-drag-0')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'playlist manager cannot dismiss in flight and closes after success',
    (tester) async {
      final saveCompleter = Completer<ListenerPlaylistSaveResult>();
      await tester.pumpWidget(
        _testApp(
          Builder(
            builder: (context) => Center(
              child: FilledButton(
                key: const Key('open-playlist-manager'),
                onPressed: () => showListenerPlaylistManagerSheet(
                  context: context,
                  initialPlaylists: const <SpotifyPlaylistPreview>[_playlist],
                  onSave: (_) => saveCompleter.future,
                ),
                child: const Text('Aç'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('open-playlist-manager')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.byKey(const Key('listener-playlist-save')));
      await tester.pump();

      await tester.binding.handlePopRoute();
      await tester.pump();
      await tester.tapAt(const Offset(4, 4));
      await tester.pump();
      expect(find.text('Çalma Listelerim'), findsOneWidget);

      saveCompleter.complete(const ListenerPlaylistSaveResult.success());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Çalma Listelerim'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'playlist manager reloads authoritative drafts after a version conflict',
    (tester) async {
      const latest = SpotifyPlaylistPreview(
        id: 'playlist-link-2',
        spotifyPlaylistId: '0vvXsWCC9xrXsKd4FyS8kM',
        title: 'Güncel Liste',
        coverImageUrl: 'https://i.scdn.co/image/current-cover',
        spotifyUrl: 'https://open.spotify.com/playlist/0vvXsWCC9xrXsKd4FyS8kM',
        position: 0,
      );
      final submissions = <List<String>>[];
      await tester.pumpWidget(
        _testApp(
          ListenerPlaylistManagerSheet(
            initialPlaylists: const <SpotifyPlaylistPreview>[_playlist],
            onSave: (spotifyUrls) async {
              submissions.add(List<String>.of(spotifyUrls));
              if (submissions.length == 1) {
                return const ListenerPlaylistSaveResult.conflict(
                  message:
                      'Profil başka bir oturumda değişti. Güncel çalma listelerini yükledik.',
                  latestPlaylists: <SpotifyPlaylistPreview>[latest],
                );
              }
              return const ListenerPlaylistSaveResult.failure('Test sonu');
            },
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('listener-playlist-save')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(submissions.single, <String>[_playlist.spotifyUrl]);
      expect(find.text('Today’s Top Hits'), findsNothing);
      expect(find.text('Güncel Liste'), findsOneWidget);
      expect(
        find.textContaining('Güncel çalma listelerini yükledik'),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('listener-playlist-save')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(submissions.last, <String>[latest.spotifyUrl]);
      expect(find.text('Çalma Listelerim'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'ghost follow race refreshes stale standard projection after backend 1206',
    (tester) async {
      await serviceLocator.reset();
      addTearDown(serviceLocator.reset);
      await _registerViewerSession('viewer-1');
      final listenerRepository = _ProjectionChangingListenerRepository();
      serviceLocator.registerFactory<ListenerProfileCubit>(
        () => ListenerProfileCubit(listenerRepository),
      );
      serviceLocator.registerFactory<FollowActionCubit>(
        () => FollowActionCubit(_GhostRaceFollowRepository()),
      );

      await _pumpPublicProfileRoute(
        tester,
        const PublicProfileArgs(
          profileId: 'profile-1',
          viewerUserId: 'viewer-1',
        ),
      );

      expect(
        find.byKey(const Key('listener-public-standard-content')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('listener-public-follow')));
      await tester.pumpAndSettle();

      expect(listenerRepository.publicLoads, 2);
      expect(
        find.byKey(const Key('listener-public-ghost-content')),
        findsOneWidget,
      );
      expect(find.text('Takip Et'), findsNothing);
      expect(
        find.text('Hayalet profiller takipçi kabul etmez.'),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await serviceLocator.reset();
    },
  );

  testWidgets(
    'ghost self-view ignores stale route actor and hides direct message',
    (tester) async {
      await serviceLocator.reset();
      addTearDown(serviceLocator.reset);
      await _registerViewerSession('user-1');
      serviceLocator.registerFactory<ListenerProfileCubit>(
        () =>
            ListenerProfileCubit(_FixedPublicListenerRepository(_ghostPublic)),
      );
      serviceLocator.registerFactory<FollowActionCubit>(
        () => FollowActionCubit(_GhostRaceFollowRepository()),
      );

      await _pumpPublicProfileRoute(
        tester,
        const PublicProfileArgs(
          profileId: 'profile-1',
          viewerUserId: 'stale-other-user',
        ),
      );

      expect(
        find.byKey(const Key('listener-public-ghost-content')),
        findsOneWidget,
      );
      expect(find.text('Mesaj Gönder'), findsNothing);
      expect(
        find.text('Bu profile doğrudan mesaj gönderebilirsin.'),
        findsNothing,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await serviceLocator.reset();
    },
  );

  testWidgets(
    'listener surface stays legible in light, dark and black themes',
    (tester) async {
      for (final theme in <ThemeData>[
        AppTheme.light,
        AppTheme.navy,
        AppTheme.black,
      ]) {
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: ListenerProfileTheme(
              child: Scaffold(
                body: ListenerGhostProfileContent(
                  username: 'listener',
                  profilePictureUrl: null,
                  owner: false,
                  busy: false,
                  onRefresh: () async {},
                  onMessage: () {},
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        final cta = tester.widget<Text>(find.text('Mesaj Gönder'));
        final badge = tester.widget<Text>(find.text('HAYALET PROFİL'));
        final localTheme = Theme.of(
          tester.element(
            find.byKey(const Key('listener-public-ghost-content')),
          ),
        );
        expect(localTheme.brightness, Brightness.dark);
        expect(cta.style?.color, Colors.white);
        expect(badge.style?.color, const Color(0xFFF7EFFF));
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets('listener layouts remain overflow-free at 320px and 200% text', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _scaledTestApp(
        ListenerProfileOwnerContent(
          profile: _ownerWithLongIdentity,
          previewData: listenerOwnerPreviewData,
          showPreviewSections: true,
          onEditProfile: () {},
          onEditAvatar: () {},
          onEditPlaylists: () {},
          onPlaylistTap: (_) {},
          onPreviewAction: (_) {},
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);

    for (var index = 0; index < 8; index++) {
      await tester.drag(
        find.byKey(const Key('listener-owner-profile-content')),
        const Offset(0, -260),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    }
    expect(find.text('Overthinking'), findsOneWidget);

    await tester.pumpWidget(
      _scaledTestApp(
        ListenerGhostProfileContent(
          username: 'WWWWWWWWWWWWWWWWWWWWWWWWWWWWWW',
          profilePictureUrl: null,
          owner: true,
          busy: false,
          onRefresh: () async {},
          onEditAvatar: () {},
          onSwitchToStandard: () {},
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(
      find.byKey(const Key('listener-owner-ghost-status-card')),
      findsOneWidget,
    );
    await tester.ensureVisible(find.text('Sosyal Profile Dön'));
    await tester.pump();
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(
      _scaledTestApp(
        ListenerPublicProfileContent(
          profile: _publicWithLongIdentity,
          isFollowing: false,
          followBusy: false,
          onRefresh: () async {},
          onPlaylistTap: (_) {},
          onFollow: () {},
          onMessage: () {},
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('Takip Et'), findsOneWidget);
    expect(find.text('Mesaj Gönder'), findsOneWidget);
  });

  testWidgets(
    'listener preview actions expose 48px targets and arrow semantics',
    (tester) async {
      final semantics = tester.ensureSemantics();
      var avatarEditCalls = 0;
      await tester.pumpWidget(
        _testApp(
          ListenerProfileOwnerContent(
            profile: _owner,
            previewData: listenerOwnerPreviewData,
            showPreviewSections: true,
            onEditProfile: () {},
            onEditAvatar: () => avatarEditCalls += 1,
            onEditPlaylists: () {},
            onPlaylistTap: (_) {},
            onPreviewAction: (_) {},
          ),
        ),
      );
      await tester.pump();

      expect(
        tester.getSize(find.byKey(const Key('listener-edit-avatar'))),
        const Size(48, 48),
      );
      final standardAvatarEditTarget = find.byKey(
        const Key('listener-edit-avatar'),
      );
      await tester.tapAt(
        tester.getCenter(standardAvatarEditTarget) + const Offset(20, 0),
      );
      expect(avatarEditCalls, 1);
      expect(
        tester.getSize(find.widgetWithText(TextButton, 'Ekle')).height,
        greaterThanOrEqualTo(48),
      );

      for (var index = 0; index < 8; index++) {
        await tester.drag(
          find.byKey(const Key('listener-owner-profile-content')),
          const Offset(0, -220),
        );
        await tester.pump();
        if (find
            .byKey(const Key('listener-open-overthinking-action'))
            .evaluate()
            .isNotEmpty) {
          break;
        }
      }

      for (final key in const <Key>[
        Key('listener-overthinking-like-action'),
        Key('listener-overthinking-comment-action'),
        Key('listener-open-overthinking-action'),
      ]) {
        final size = tester.getSize(find.byKey(key));
        expect(size.width, greaterThanOrEqualTo(48));
        expect(size.height, greaterThanOrEqualTo(48));
      }
      await tester.ensureVisible(
        find.byKey(const Key('listener-open-overthinking-action')),
      );
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Paylaşımı aç'), findsOneWidget);
      semantics.dispose();
    },
  );
}

Widget _testApp(Widget child) {
  return MaterialApp(
    theme: ThemeData.dark(useMaterial3: true),
    home: ListenerProfileTheme(child: Scaffold(body: child)),
  );
}

Widget _scaledTestApp(Widget child) {
  return MaterialApp(
    theme: AppTheme.light,
    home: MediaQuery(
      data: const MediaQueryData(
        size: Size(320, 568),
        textScaler: TextScaler.linear(2),
      ),
      child: ListenerProfileTheme(child: Scaffold(body: child)),
    ),
  );
}

Future<void> _pumpPublicProfileRoute(
  WidgetTester tester,
  PublicProfileArgs arguments,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: FilledButton(
              key: const Key('open-listener-public-profile'),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  settings: RouteSettings(
                    name: '/listener',
                    arguments: arguments,
                  ),
                  builder: (_) => const ListenerPublicProfileScreen(),
                ),
              ),
              child: const Text('Profili aç'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.byKey(const Key('open-listener-public-profile')));
  await tester.pumpAndSettle();
}

const _owner = ListenerProfile(
  id: 'profile-1',
  userId: 'user-1',
  username: 'listener',
  bio: 'Gerçek bio',
  profilePictureMediaId: null,
  profilePictureUrl: null,
  followerCount: 4,
  followingCount: 6,
  visibilityMode: ListenerVisibilityMode.standard,
  version: 2,
  profileContentVisible: true,
  profileContentEditable: true,
  avatarEditable: true,
  canReceiveFollowers: true,
);

const _ownerWithLongIdentity = ListenerProfile(
  id: 'profile-1',
  userId: 'user-1',
  username: 'WWWWWWWWWWWWWWWWWWWWWWWWWWWWWW',
  bio:
      'Yeni gruplar, canlı performanslar ve gece eve dönerken iyi giden şarkılar.',
  profilePictureMediaId: null,
  profilePictureUrl: null,
  followerCount: 123456789,
  followingCount: 987654321,
  visibilityMode: ListenerVisibilityMode.standard,
  version: 2,
  profileContentVisible: true,
  profileContentEditable: true,
  avatarEditable: true,
  canReceiveFollowers: true,
  playlists: <SpotifyPlaylistPreview>[_playlist],
);

const _ownerWithPlaylists = ListenerProfile(
  id: 'profile-1',
  userId: 'user-1',
  username: 'listener',
  bio: 'Gerçek bio',
  profilePictureMediaId: null,
  profilePictureUrl: null,
  followerCount: 4,
  followingCount: 6,
  visibilityMode: ListenerVisibilityMode.standard,
  version: 2,
  profileContentVisible: true,
  profileContentEditable: true,
  avatarEditable: true,
  canReceiveFollowers: true,
  playlists: <SpotifyPlaylistPreview>[_playlist],
);

const _public = ListenerPublicProfile(
  id: 'profile-1',
  userId: 'user-1',
  username: 'listener',
  visibilityMode: ListenerVisibilityMode.standard,
  bio: 'Gerçek public bio',
  profilePictureMediaId: null,
  profilePictureUrl: null,
  followerCount: 8,
  followingCount: 3,
  restricted: false,
  canFollow: true,
  canMessage: true,
);

const _publicWithLongIdentity = ListenerPublicProfile(
  id: 'profile-1',
  userId: 'user-1',
  username: 'WWWWWWWWWWWWWWWWWWWWWWWWWWWWWW',
  visibilityMode: ListenerVisibilityMode.standard,
  bio:
      'Yeni gruplar, canlı performanslar ve gece eve dönerken iyi giden şarkılar.',
  profilePictureMediaId: null,
  profilePictureUrl: null,
  followerCount: 123456789,
  followingCount: 987654321,
  restricted: false,
  canFollow: true,
  canMessage: true,
  playlists: <SpotifyPlaylistPreview>[_playlist],
);

const _publicWithPlaylists = ListenerPublicProfile(
  id: 'profile-1',
  userId: 'user-1',
  username: 'listener',
  visibilityMode: ListenerVisibilityMode.standard,
  bio: 'Gerçek public bio',
  profilePictureMediaId: null,
  profilePictureUrl: null,
  followerCount: 8,
  followingCount: 3,
  restricted: false,
  canFollow: true,
  canMessage: true,
  playlists: <SpotifyPlaylistPreview>[_playlist],
);

const _playlist = SpotifyPlaylistPreview(
  id: 'playlist-link-1',
  spotifyPlaylistId: '37i9dQZF1DXcBWIGoYBM5M',
  title: 'Today’s Top Hits',
  coverImageUrl: 'https://i.scdn.co/image/playlist-cover',
  spotifyUrl: 'https://open.spotify.com/playlist/37i9dQZF1DXcBWIGoYBM5M',
  position: 0,
);

const _ghostPublic = ListenerPublicProfile(
  id: 'profile-1',
  userId: 'user-1',
  username: 'listener',
  visibilityMode: ListenerVisibilityMode.ghost,
  bio: null,
  profilePictureMediaId: null,
  profilePictureUrl: null,
  followerCount: null,
  followingCount: null,
  restricted: true,
  canFollow: false,
  canMessage: true,
);

class _ProjectionChangingListenerRepository extends ListenerProfileRepository {
  int publicLoads = 0;

  @override
  Future<Result<ListenerProfile>> getMyProfile() async {
    return const Result.failure(
      AppError(code: 'not_used', message: 'Not used by this test'),
    );
  }

  @override
  Future<Result<ListenerPublicProfile>> getPublicProfile(
    String profileId,
  ) async {
    publicLoads += 1;
    return Result.success(publicLoads == 1 ? _public : _ghostPublic);
  }
}

class _FixedPublicListenerRepository extends ListenerProfileRepository {
  const _FixedPublicListenerRepository(this.profile);

  final ListenerPublicProfile profile;

  @override
  Future<Result<ListenerProfile>> getMyProfile() async {
    return const Result.failure(
      AppError(code: 'not_used', message: 'Not used by this test'),
    );
  }

  @override
  Future<Result<ListenerPublicProfile>> getPublicProfile(
    String profileId,
  ) async {
    return Result.success(profile);
  }
}

class _FixedOwnerListenerRepository extends ListenerProfileRepository {
  const _FixedOwnerListenerRepository(this.profile);

  final ListenerProfile profile;

  @override
  Future<Result<ListenerProfile>> getMyProfile() async =>
      Result.success(profile);
}

class _GhostRaceFollowRepository implements FollowRepository {
  @override
  Future<Result<int>> getFollowersCount(String userId) async {
    return const Result.success(0);
  }

  @override
  Future<Result<int>> getFollowingCount(String userId) async {
    return const Result.success(0);
  }

  @override
  Future<Result<bool>> isFollowing({
    required String followerId,
    required String followingId,
  }) async {
    return const Result.success(false);
  }

  @override
  Future<Result<void>> follow({
    required String followerId,
    required String followingId,
  }) async {
    return const Result.failure(
      AppError(code: '1206', message: 'Hayalet profiller takipçi kabul etmez.'),
    );
  }

  @override
  Future<Result<void>> unfollow({
    required String followerId,
    required String followingId,
  }) async {
    return const Result.success(null);
  }
}

Future<void> _registerViewerSession(String userId) async {
  final manager = AuthSessionManager(
    tokenStore: _NoopTokenStore(),
    sessionStore: _NoopAuthSessionStore(),
  );
  final expiresAt =
      DateTime.now()
          .toUtc()
          .add(const Duration(hours: 1))
          .millisecondsSinceEpoch ~/
      Duration.millisecondsPerSecond;
  final encodedHeader = base64Url.encode(
    utf8.encode(jsonEncode(const <String, Object>{'alg': 'none'})),
  );
  final encodedPayload = base64Url.encode(
    utf8.encode(
      jsonEncode(<String, Object>{
        'sub': userId,
        'exp': expiresAt,
        'roles': const <String>['ROLE_LISTENER'],
      }),
    ),
  );
  await manager.restore(
    tokenOverride: Future<String?>.value(
      '$encodedHeader.$encodedPayload.test-signature',
    ),
  );
  assert(manager.session.isAuthenticated);
  assert(manager.session.userId == userId);
  serviceLocator.registerSingleton<AuthSessionManager>(
    manager,
    dispose: (value) => value.dispose(),
  );
}

class _NoopTokenStore implements TokenStore {
  @override
  Future<void> clear() async {}

  @override
  Future<String?> readToken() async => null;

  @override
  Future<void> writeToken(String token) async {}
}

class _NoopAuthSessionStore implements AuthSessionStore {
  @override
  Future<void> clear() async {}

  @override
  Future<AuthSessionMetadata?> read() async => null;

  @override
  Future<void> write(AuthSessionMetadata metadata) async {}
}
