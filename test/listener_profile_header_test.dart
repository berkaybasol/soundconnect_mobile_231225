import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/listener_profile.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/listener_public_profile.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/listener_visibility_mode.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/listener_ghost_profile_content.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/listener_profile_header.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/listener_profile_owner_content.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/listener_profile_theme.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/listener_public_profile_content.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/profile_common_widgets.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/profile_section_support.dart';
import 'package:soundconnect_23_12_25codx/shared/theme/app_theme.dart';

void main() {
  testWidgets('owner uses a 96 pixel avatar and compact follower pills', (
    tester,
  ) async {
    await _pump(tester, _owner());

    expect(
      tester.getSize(find.byKey(const Key('listener-profile-avatar'))),
      const Size(96, 96),
    );
    expect(find.text('berna'), findsOneWidget);
    for (final pill in find.byType(ProfilePillBadge).evaluate()) {
      expect(tester.getSize(find.byWidget(pill.widget)).width, lessThan(175));
    }
    expect(find.text('12 Takipçi'), findsOneWidget);
    expect(find.text('8 Takip'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('owner actions remain usable with a 48 pixel avatar target', (
    tester,
  ) async {
    var avatarEdits = 0;
    var profileEdits = 0;
    await _pump(
      tester,
      _owner(
        onEditAvatar: () => avatarEdits++,
        onEditProfile: () => profileEdits++,
      ),
    );
    final avatarTarget = find.byKey(const Key('listener-edit-avatar'));
    final profileTarget = find.byKey(const Key('listener-edit-profile'));
    expect(tester.getSize(avatarTarget), const Size(48, 48));
    final avatarBounds = tester.getRect(
      find.byKey(const Key('listener-profile-avatar')),
    );
    expect(avatarBounds.contains(tester.getCenter(avatarTarget)), isTrue);

    await tester.tap(avatarTarget);
    await tester.tap(profileTarget);
    expect(avatarEdits, 1);
    expect(profileEdits, 1);
  });

  testWidgets('busy owner keeps visible controls but blocks both edits', (
    tester,
  ) async {
    var edits = 0;
    await _pump(
      tester,
      _owner(
        busy: true,
        onEditAvatar: () => edits++,
        onEditProfile: () => edits++,
      ),
    );

    await tester.tap(find.byKey(const Key('listener-edit-avatar')));
    await tester.tap(find.byKey(const Key('listener-edit-profile')));
    expect(edits, 0);
    expect(find.text('Profili Düzenle'), findsOneWidget);
  });

  testWidgets('missing social counts are not replaced with fake zeroes', (
    tester,
  ) async {
    for (final counts in [(null, null), (12, null), (null, 8)]) {
      await _pump(
        tester,
        ListenerProfileHeader(
          username: 'berna',
          followerCount: counts.$1,
          followingCount: counts.$2,
          actionButtons: const SizedBox.shrink(),
          bio: '',
        ),
      );
      expect(find.byType(ProfilePillBadge), findsNothing);
      expect(find.text('0 Takipçi'), findsNothing);
      expect(find.byKey(const Key('listener-edit-avatar')), findsNothing);
    }
  });

  testWidgets('owner action precedes biography and private plans', (
    tester,
  ) async {
    await _pump(tester, _owner());

    final editY = tester.getTopLeft(find.text('Profili Düzenle')).dy;
    final bioY = tester.getTopLeft(find.text(_bio)).dy;
    final plansY = tester.getTopLeft(find.text('Planlarım')).dy;
    final playlistsY = tester.getTopLeft(find.text('Çalma Listeleri')).dy;
    expect(editY, lessThan(bioY));
    expect(bioY, lessThan(plansY));
    expect(plansY, lessThan(playlistsY));
  });

  testWidgets('long identity and large counts fit a narrow enlarged screen', (
    tester,
  ) async {
    await _pump(
      tester,
      _owner(username: 'W' * 80, count: 123456789),
      width: 320,
      textScale: 2,
    );

    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('Profili Düzenle'));
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('Planlarım'));
    expect(tester.takeException(), isNull);
  });

  for (final owner in [true, false]) {
    testWidgets(
      '${owner ? 'owner' : 'public'} chrome inherits app theme while publications retain their palette',
      (tester) async {
        for (final appTheme in [AppTheme.navy, ThemeData.light()]) {
          const sentinelKey = Key('publication-theme-sentinel');
          final sentinel = Builder(
            builder: (context) => ColoredBox(
              key: sentinelKey,
              color: Theme.of(context).colorScheme.surface,
              child: const SizedBox(height: 32, width: double.infinity),
            ),
          );
          await _pump(
            tester,
            owner
                ? _owner(eventPosts: sentinel)
                : _public(eventPosts: sentinel),
            theme: appTheme,
          );
          final avatarContext = tester.element(
            find.byKey(const Key('listener-profile-avatar')),
          );
          expect(
            Theme.of(avatarContext).colorScheme.surface,
            appTheme.colorScheme.surface,
          );
          expect(
            DefaultTextStyle.of(avatarContext).style.color,
            appTheme.textTheme.bodyMedium!.color,
          );
          final avatar = tester.widget<Container>(
            find.byKey(const Key('listener-profile-avatar')),
          );
          expect(
            (avatar.decoration! as BoxDecoration).color,
            appTheme.colorScheme.surfaceContainerHighest,
          );
          final post = tester.widget<ColoredBox>(find.byKey(sentinelKey));
          expect(post.color, listenerProfileDeepSurface);
          expect(
            DefaultTextStyle.of(
              tester.element(find.byKey(sentinelKey)),
            ).style.color,
            Colors.white,
          );
          expect(
            Theme.of(
              tester.element(find.byKey(sentinelKey)),
            ).colorScheme.onSurfaceVariant,
            listenerProfileMuted,
          );
          expect(tester.takeException(), isNull);
        }
      },
    );
  }

  testWidgets('shared identity keeps long artist metadata bounded at 2x', (
    tester,
  ) async {
    final name = 'W' * 80;
    final secondary = 'Uzun sanatçı grubu ve mekan bilgileri ' * 12;
    await _pump(
      tester,
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: ProfileIdentityHeader(username: name, secondaryText: secondary),
      ),
      width: 320,
      textScale: 2,
    );

    expect(tester.takeException(), isNull);
    for (final content in [name, secondary.trim()]) {
      final bounds = tester.getRect(find.text(content));
      expect(bounds.left, greaterThanOrEqualTo(20));
      expect(bounds.right, lessThanOrEqualTo(300));
      expect(bounds.height, lessThan(125));
    }
  });

  testWidgets('shared follower summary wraps large counts on a 320px screen', (
    tester,
  ) async {
    await _pump(
      tester,
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: ProfileFollowerSummary(
          followersCount: 123456789,
          followingCount: 987654321,
        ),
      ),
      width: 320,
      textScale: 2,
    );

    expect(tester.takeException(), isNull);
    final follower = tester.getRect(find.text('123456789 Takipçi'));
    final following = tester.getRect(find.text('987654321 Takip'));
    expect(following.top, greaterThan(follower.bottom));
    for (final pill in find.byType(ProfilePillBadge).evaluate()) {
      final bounds = tester.getRect(find.byWidget(pill.widget));
      expect(bounds.left, greaterThanOrEqualTo(20));
      expect(bounds.right, lessThanOrEqualTo(300));
    }
  });

  testWidgets(
    'shared follower summary retains loading and single-count modes',
    (tester) async {
      await _pump(
        tester,
        ProfileFollowerSummary(followersCount: null, followingCount: null),
        width: 320,
        textScale: 2,
      );
      expect(find.text('... Takipçi'), findsOneWidget);
      expect(find.text('... Takip'), findsOneWidget);
      expect(find.text('0 Takipçi'), findsNothing);
      expect(tester.takeException(), isNull);

      await _pump(
        tester,
        ProfileFollowerSummary(
          followersCount: 9,
          followingCount: null,
          showFollowing: false,
          followersLabel: 'Dinleyici',
        ),
        width: 320,
        textScale: 2,
      );
      expect(find.text('9 Dinleyici'), findsOneWidget);
      expect(find.text('... Takip'), findsNothing);
      expect(find.byType(ProfilePillBadge), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  if (Platform.environment['LISTENER_PROFILE_HEADER_RENDER_DIR'] != null) {
    testWidgets('render unified listener headers with real fonts', (
      tester,
    ) async {
      await tester.runAsync(() async {
        final fonts =
            '${File(Platform.resolvedExecutable).parent.parent.parent.path}/material_fonts';
        final loader = FontLoader('Roboto');
        for (final font in [
          'roboto-regular.ttf',
          'roboto-medium.ttf',
          'roboto-bold.ttf',
          'roboto-black.ttf',
        ]) {
          loader.addFont(
            File('$fonts/$font').readAsBytes().then(ByteData.sublistView),
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
        'ghost-owner',
        'ghost-public',
        'owner-narrow-2x',
        'public-narrow-2x',
        'ghost-owner-narrow-2x',
        'ghost-public-narrow-2x',
      ]) {
        final narrow = name.endsWith('2x');
        final capture = GlobalKey();
        final child = name.startsWith('ghost')
            ? _ghost(owner: name.startsWith('ghost-owner'))
            : name.startsWith('public')
            ? _public()
            : _owner();
        await _pump(
          tester,
          child,
          width: narrow ? 320 : 390,
          textScale: narrow ? 2 : 1,
          capture: capture,
        );
        if (name.startsWith('ghost')) {
          await tester.runAsync(() async {
            await precacheImage(
              const AssetImage('assets/ghost (1).png'),
              tester.element(find.byType(Scaffold)),
            );
          });
          await tester.pumpAndSettle();
        }
        await tester.runAsync(() async {
          await precacheImage(
            const AssetImage('assets/headphone2.png'),
            capture.currentContext!,
          );
        });
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.runAsync(() async {
          final pixels =
              await (capture.currentContext!.findRenderObject()!
                      as RenderRepaintBoundary)
                  .toImage(pixelRatio: 2);
          final bytes = await pixels.toByteData(format: ui.ImageByteFormat.png);
          final output =
              Platform.environment['LISTENER_PROFILE_HEADER_RENDER_DIR']!;
          await Directory(output).create(recursive: true);
          await File(
            '$output/$name.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
          pixels.dispose();
        });
      }
    });
  }
}

const _bio = 'Güzel müziğin ve canlı sahnelerin peşinde.';

Widget _owner({
  String username = 'berna',
  int count = 12,
  bool busy = false,
  VoidCallback? onEditProfile,
  VoidCallback? onEditAvatar,
  Widget? eventPosts,
}) {
  return ListenerProfileOwnerContent(
    profile: ListenerProfile(
      id: 'listener-profile',
      userId: 'listener-user',
      username: username,
      bio: _bio,
      profilePictureUrl: null,
      followerCount: count,
      followingCount: count == 12 ? 8 : count,
    ),
    actionBusy: busy,
    onEditProfile: onEditProfile ?? () {},
    onEditAvatar: onEditAvatar ?? () {},
    onEditPlaylists: () {},
    onPlaylistTap: (_) {},
    onPreviewAction: (_) {},
    eventPosts: eventPosts,
    eventPlansAction: OutlinedButton.icon(
      onPressed: () {},
      icon: const Icon(Icons.event_note_outlined, size: 18),
      label: const Text('Planlarım'),
    ),
  );
}

Widget _public({Widget? eventPosts}) {
  return ListenerPublicProfileContent(
    profile: const ListenerPublicProfile(
      id: 'listener-profile',
      userId: 'listener-user',
      username: 'berna',
      visibilityMode: ListenerVisibilityMode.standard,
      bio: _bio,
      profilePictureMediaId: null,
      profilePictureUrl: null,
      followerCount: 12,
      followingCount: 8,
      restricted: false,
      canFollow: true,
      canMessage: true,
    ),
    isFollowing: false,
    followBusy: false,
    onRefresh: () async {},
    onPlaylistTap: (_) {},
    onFollow: () {},
    onMessage: () {},
    eventPosts: eventPosts,
  );
}

Widget _ghost({required bool owner}) {
  return ListenerGhostProfileContent(
    username: 'berna',
    profilePictureUrl: null,
    owner: owner,
    busy: false,
    onRefresh: () async {},
    onEditAvatar: owner ? () {} : null,
    onSwitchToStandard: owner ? () {} : null,
    onMessage: owner ? null : () {},
  );
}

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  double width = 390,
  double textScale = 1,
  GlobalKey? capture,
  ThemeData? theme,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 900);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(
    MaterialApp(
      theme: theme ?? AppTheme.navy,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Scaffold(
        body: ListenerProfileTheme(
          inheritAppTheme: true,
          child: capture == null
              ? child
              : RepaintBoundary(
                  key: capture,
                  child: ColoredBox(
                    color: (theme ?? AppTheme.navy).scaffoldBackgroundColor,
                    child: child,
                  ),
                ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
