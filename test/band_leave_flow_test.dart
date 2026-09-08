import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/app/router/app_routes.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session_manager.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session_store.dart';
import 'package:soundconnect_23_12_25codx/core/auth/token_store.dart';
import 'package:soundconnect_23_12_25codx/core/di/service_locator.dart';
import 'package:soundconnect_23_12_25codx/core/error/app_error.dart';
import 'package:soundconnect_23_12_25codx/core/error/result.dart';
import 'package:soundconnect_23_12_25codx/core/network/api_client.dart';
import 'package:soundconnect_23_12_25codx/modules/artist_venue/domain/artist_venue_connection_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/engagement/domain/engagement_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/engagement/presentation/cubit/interaction_stats_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/follow/domain/band_follow_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/data/band_repository_impl.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/band_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/band_member_summary.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/band_profile.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/musician_profile.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/profile_media.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/profile_venue_models.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/musician_calendar_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/musician_profile_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/profile_media_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/cubit/profile_media_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/band_profile_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/profile_section_support.dart';
import 'package:soundconnect_23_12_25codx/shared/theme/app_theme.dart';
import 'package:soundconnect_23_12_25codx/shared/widgets/gradient_outline_button.dart';

void main() {
  late _Bands bands;
  late _Session session;
  late _Calendar calendar;
  late _Connections connections;
  late _Followers followers;

  setUp(() async {
    await serviceLocator.reset();
    bands = _Bands();
    session = _Session();
    calendar = _Calendar();
    connections = _Connections();
    followers = _Followers();
    serviceLocator
      ..registerSingleton<BandRepository>(bands)
      ..registerSingleton<AuthSessionManager>(session)
      ..registerSingleton<TokenStore>(_Tokens())
      ..registerSingleton<MusicianProfileRepository>(_Musicians())
      ..registerSingleton<MusicianCalendarRepository>(calendar)
      ..registerSingleton<ArtistVenueConnectionRepository>(connections)
      ..registerSingleton<BandFollowRepository>(followers)
      ..registerSingleton<AudioHandler>(BaseAudioHandler())
      ..registerFactory<ProfileMediaCubit>(() => ProfileMediaCubit(_Media()))
      ..registerFactory<InteractionStatsCubit>(
        () => InteractionStatsCubit(_Engagement()),
      );
  });

  tearDown(() async {
    session.dispose();
    await serviceLocator.reset();
  });

  for (final scale in [1.0, 2.0, 3.0]) {
    for (final founder in [false, true]) {
      testWidgets('mini member card fits caption $founder at $scale', (
        tester,
      ) async {
        bands.profile = _profile(
          role: founder ? 'FOUNDER' : 'MEMBER',
          title: founder ? 'Gitarist' : null,
        );
        // The card stays 168dp wide. Give the unrelated profile header room at 3x.
        await _open(
          tester,
          width: scale > 2 ? 400 : 320,
          height: 1400,
          scale: scale,
        );
        await tester.pumpAndSettle();
        final card = find.byWidgetPredicate(
          (widget) => widget is SizedBox && widget.width == 168,
        );
        expect(card, findsOneWidget);
        await tester.ensureVisible(card);
        await tester.pumpAndSettle();
        if (scale == 1) {
          expect(tester.getSize(card).height, lessThanOrEqualTo(52));
        }
        expect(
          find.byTooltip('Kurucu'),
          founder ? findsOneWidget : findsNothing,
        );
        expect(find.text('Kurucu'), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }
  }

  for (final mode in BandProfileViewMode.values) {
    testWidgets('active member can leave from $mode route', (tester) async {
      await _open(tester, mode: mode);
      expect(
        find.byKey(const Key('band-profile-leave-action')),
        findsOneWidget,
      );
      expect(find.text('Yönetim Paneli'), findsNothing);
      await _confirm(tester);
      expect(bands.leaves, 1);
      expect(bands.leftBand, 'band');
      expect(bands.expectedUser, 'aedrum-user');
      expect(calendar.invalidations, 1);
      expect(find.byKey(const Key('band-profile-leave-action')), findsNothing);
      expect(find.text('Gruptan ayrıldın.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  for (final membership in [
    (role: 'FOUNDER', status: 'ACTIVE', user: 'aedrum-user'),
    (role: ' founder ', status: ' active ', user: 'aedrum-user'),
    (role: 'MEMBER', status: 'PENDING', user: 'aedrum-user'),
    (role: 'MEMBER', status: 'LEFT', user: 'aedrum-user'),
    (role: 'MEMBER', status: 'ACTIVE', user: 'other-user'),
  ]) {
    testWidgets('leave denied for $membership', (tester) async {
      bands.profile = _profile(
        role: membership.role,
        status: membership.status,
        user: membership.user,
      );
      await _open(tester);
      expect(find.byKey(const Key('band-profile-leave-action')), findsNothing);
      expect(bands.leaves, 0);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('guest cannot leave even with matching response membership', (
    tester,
  ) async {
    session.current = const AuthSession.guest();
    await _open(tester);
    expect(find.byKey(const Key('band-profile-leave-action')), findsNothing);
    expect(bands.leaves, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ambiguous duplicate memberships do not offer leave', (
    tester,
  ) async {
    bands.profile = _profile(duplicate: true);
    await _open(tester);
    expect(find.byKey(const Key('band-profile-leave-action')), findsNothing);
    expect(bands.leaves, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('suspended account cannot leave from stale active roster', (
    tester,
  ) async {
    session.current = _session(status: 'SUSPENDED');
    await _open(tester);
    expect(find.byKey(const Key('band-profile-leave-action')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('non-musician account cannot use a matching stale membership', (
    tester,
  ) async {
    session.current = _session(roles: const ['ROLE_VENUE']);
    await _open(tester);
    expect(find.byKey(const Key('band-profile-leave-action')), findsNothing);
    expect(bands.leaves, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('session change during initial profile load ends pending UI', (
    tester,
  ) async {
    bands.pendingRead = Completer<Result<BandProfile>>();
    await _open(tester, settle: false);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    session.change(_session(user: 'other-user'));
    await tester.pump();
    bands.pendingRead!.complete(Result.success(bands.profile));
    await tester.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Oturum değişti. Bu sayfayı yeniden aç.'), findsOneWidget);
    expect(find.byKey(const Key('band-profile-leave-action')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('thrown owner read falls back to public membership safely', (
    tester,
  ) async {
    bands.throwPrivate = true;
    await _open(tester);
    expect(bands.publicReads, 1);
    expect(find.byKey(const Key('band-profile-leave-action')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final mode in [BandProfileViewMode.auto, BandProfileViewMode.public]) {
    testWidgets('thrown profile reads in $mode end loading and retry', (
      tester,
    ) async {
      bands.throwPrivate = true;
      bands.throwPublic = true;
      await _open(tester, mode: mode);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byKey(const Key('band-profile-leave-action')), findsNothing);
      bands.throwPrivate = false;
      bands.throwPublic = false;
      await tester.tap(find.byKey(const Key('band-profile-load-retry')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('band-profile-leave-action')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('mismatched band ID in $mode fails closed', (tester) async {
      bands.profile = _profile(id: 'wrong-band');
      await _open(tester, mode: mode);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byKey(const Key('band-profile-leave-action')), findsNothing);
      expect(followers.reads, 0);
      expect(connections.reads, 0);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'optional venue failure preserves membership and later sections',
    (tester) async {
      connections.fail = true;
      await _open(tester);
      expect(
        find.byKey(const Key('band-profile-leave-action')),
        findsOneWidget,
      );
      expect(followers.reads, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'session change stops late secondary requests after venue await',
    (tester) async {
      connections.pending = Completer<Result<List<VenueConnection>>>();
      await _open(tester);
      expect(connections.reads, 1);
      session.change(_session(user: 'other-user'));
      connections.pending!.complete(const Result.success([]));
      await tester.pumpAndSettle();
      expect(followers.reads, 0);
      expect(find.byKey(const Key('band-profile-leave-action')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('cancel does not mutate or invalidate and restores action', (
    tester,
  ) async {
    await _open(tester);
    await _showDialog(tester);
    await tester.tap(find.byKey(const Key('cancel-band-leave')));
    await tester.pumpAndSettle();
    expect(bands.leaves, 0);
    expect(calendar.invalidations, 0);
    expect(_leaveButton(tester).onPressed, isNotNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'dialog and request are single flight including stale callbacks',
    (tester) async {
      await _open(tester);
      final pending = Completer<Result<void>>();
      bands.pending = pending;
      final open = _leaveButton(tester).onPressed!;
      open();
      open();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('band-leave-confirmation')), findsOneWidget);
      final confirm = tester
          .widget<GradientOutlineButton>(
            find.byKey(const Key('confirm-band-leave')),
          )
          .onPressed!;
      confirm();
      confirm();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      open();
      expect(bands.leaves, 1);
      expect(_leaveButton(tester).loading, isTrue);
      expect(calendar.invalidations, 0);
      pending.complete(const Result.success(null));
      await tester.pumpAndSettle();
      expect(calendar.invalidations, 1);
      expect(tester.takeException(), isNull);
    },
  );

  for (final throws in [false, true]) {
    testWidgets('leave failure throws=$throws remains retryable', (
      tester,
    ) async {
      await _open(tester);
      bands.failure = true;
      bands.throwLeave = throws;
      await _confirm(tester);
      expect(calendar.invalidations, 0);
      expect(_leaveButton(tester).onPressed, isNotNull);
      expect(find.text('Gruptan ayrıldın.'), findsNothing);
      bands.failure = false;
      bands.throwLeave = false;
      await _confirm(tester);
      expect(bands.leaves, 2);
      expect(calendar.invalidations, 1);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('account change during confirmation prevents the write', (
    tester,
  ) async {
    await _open(tester);
    await _showDialog(tester);
    session.change(_session(user: 'other-user'));
    await tester.pump();
    await tester.tap(find.byKey(const Key('confirm-band-leave')));
    await tester.pumpAndSettle();
    expect(bands.leaves, 0);
    expect(calendar.invalidations, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'stale leave preserves the new tenure and requires fresh confirmation',
    (tester) async {
      bands.profile = _profile(version: 7);
      await _open(tester);
      await _showDialog(tester);
      bands.profile = _profile(version: 9);
      bands.versionConflict = true;
      await tester.tap(find.byKey(const Key('confirm-band-leave')));
      await tester.pumpAndSettle();
      expect(bands.versions, [7]);
      expect(calendar.invalidations, 0);
      expect(find.text('Gruptan ayrıldın.'), findsNothing);
      expect(
        find.text(
          'Üyelik bilgileri değişti. Güncel üyeliğini kontrol edip tekrar dene.',
        ),
        findsOneWidget,
      );
      expect(_leaveButton(tester).onPressed, isNotNull);
      bands.versionConflict = false;
      await _confirm(tester);
      expect(bands.versions, [7, 9]);
      expect(calendar.invalidations, 1);
    },
  );

  testWidgets('account change after dispatch ignores old success', (
    tester,
  ) async {
    await _open(tester);
    bands.pending = Completer<Result<void>>();
    await _showDialog(tester);
    await tester.tap(find.byKey(const Key('confirm-band-leave')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    session.change(_session(user: 'other-user'));
    bands.pending!.complete(const Result.success(null));
    await tester.pumpAndSettle();
    expect(calendar.invalidations, 0);
    expect(find.text('Gruptan ayrıldın.'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('disposed profile ignores late request result', (tester) async {
    await _open(tester);
    bands.pending = Completer<Result<void>>();
    await _showDialog(tester);
    await tester.tap(find.byKey(const Key('confirm-band-leave')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpWidget(const SizedBox.shrink());
    bands.pending!.complete(const Result.success(null));
    await tester.pumpAndSettle();
    expect(calendar.invalidations, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('success does not pop a different route opened during request', (
    tester,
  ) async {
    final navigator = GlobalKey<NavigatorState>();
    await _open(tester, navigatorKey: navigator);
    bands.pending = Completer<Result<void>>();
    await _showDialog(tester);
    await tester.tap(find.byKey(const Key('confirm-band-leave')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    unawaited(
      navigator.currentState!.push<void>(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('Başka sayfa')),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    bands.pending!.complete(const Result.success(null));
    await tester.pumpAndSettle();
    expect(find.text('Başka sayfa'), findsOneWidget);
    expect(find.text('Gruptan ayrıldın.'), findsNothing);
    expect(calendar.invalidations, 1);
    navigator.currentState!.pop();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('band-profile-leave-action')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final theme in ['navy', 'light', 'black']) {
    testWidgets('leave confirmation at 320dp and 2x font in $theme', (
      tester,
    ) async {
      await _open(tester, width: 320, scale: 2, theme: theme);
      await _showDialog(tester);
      await tester.ensureVisible(find.byKey(const Key('confirm-band-leave')));
      expect(find.byKey(const Key('band-leave-confirmation')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('shared section header wraps long title with trailing action', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: Scaffold(
            body: Column(
              children: [
                ProfileSectionHeader(
                  title: 'Çaldığı Mekanlar',
                  actionLabel: 'Tümü',
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Çaldığı Mekanlar'), findsOneWidget);
    expect(find.text('Tümü'), findsOneWidget);
    expect(
      tester.getRect(find.text('Çaldığı Mekanlar')).right,
      lessThanOrEqualTo(tester.getRect(find.text('Tümü')).left),
    );
    expect(tester.takeException(), isNull);
  });

  test(
    'repository forwards expected account to fenced PATCH transport',
    () async {
      final api = _LeaveApi();
      final result = await BandRepositoryImpl(api).leaveBand(
        bandId: 'band',
        expectedSessionKey: 'aedrum-user',
        expectedTitleVersion: 0,
      );
      expect(result.isSuccess, isTrue);
      expect(api.method, ApiHttpMethod.patch);
      expect(api.path, '/api/v1/user/bands/band/leave');
      expect(api.context?.expectedSessionKey, 'aedrum-user');
      expect(api.query, {'expectedTitleVersion': 0});
    },
  );

  for (final version in <int?>[null, -1]) {
    test(
      'leave without valid originating membership version fails closed ($version)',
      () async {
        final api = _LeaveApi();
        final result = await BandRepositoryImpl(api).leaveBand(
          bandId: 'band',
          expectedSessionKey: 'aedrum-user',
          expectedTitleVersion: version,
        );
        expect(result.error?.code, '9221');
        expect(api.method, isNull);
      },
    );
  }

  test(
    'unsupported fenced API fails closed instead of unguarded PATCH',
    () async {
      final result = await BandRepositoryImpl(_UnfencedApi()).leaveBand(
        bandId: 'band',
        expectedSessionKey: 'aedrum-user',
        expectedTitleVersion: 0,
      );
      expect(result.isSuccess, isFalse);
    },
  );

  if (const bool.fromEnvironment('BAND_LEAVE_PREVIEW')) {
    testWidgets('mini member cards visual preview', (tester) async {
      await tester.runAsync(() async {
        const root = String.fromEnvironment('BAND_LEAVE_PREVIEW_FLUTTER_ROOT');
        for (final font in {
          'Roboto':
              '$root/engine/src/flutter/txt/third_party/fonts/Roboto-Regular.ttf',
          'MaterialIcons':
              '$root/bin/cache/dart-sdk/bin/resources/devtools/assets/fonts/MaterialIcons-Regular.otf',
        }.entries) {
          await (FontLoader(font.key)..addFont(
                File(font.value).readAsBytes().then(ByteData.sublistView),
              ))
              .load();
        }
      });
      bands.profile = _profile(duplicate: true);
      bands.profile.members[0] = const BandMemberSummary(
        userId: 'founder',
        profileId: 'founder-profile',
        username: 'bugrasahin',
        profilePictureUrl: null,
        role: 'FOUNDER',
        status: 'ACTIVE',
        memberTitle: 'Gitarist',
      );
      bands.profile.members[1] = const BandMemberSummary(
        userId: 'aedrum-user',
        profileId: 'artist',
        username: 'aedrum',
        profilePictureUrl: null,
        role: 'MEMBER',
        status: 'ACTIVE',
        memberTitle: 'Davulcu',
      );
      await _open(tester, width: 390, height: 844);
      final cards = find.byWidgetPredicate(
        (widget) => widget is SizedBox && widget.width == 168,
      );
      await tester.ensureVisible(cards.first);
      await tester.pumpAndSettle();
      await _capture(tester, 'mini-cards');
      expect(tester.takeException(), isNull);
    });
    for (final scale in [1.0, 2.0]) {
      testWidgets('band leave preview ${scale}x', (tester) async {
        await tester.runAsync(() async {
          const fontRoot = String.fromEnvironment(
            'BAND_LEAVE_PREVIEW_FLUTTER_ROOT',
          );
          for (final font in {
            'Roboto':
                '$fontRoot/engine/src/flutter/txt/third_party/fonts/Roboto-Regular.ttf',
            'MaterialIcons':
                '$fontRoot/bin/cache/dart-sdk/bin/resources/devtools/assets/fonts/MaterialIcons-Regular.otf',
          }.entries) {
            await (FontLoader(font.key)..addFont(
                  File(font.value).readAsBytes().then(ByteData.sublistView),
                ))
                .load();
          }
        });
        await _open(
          tester,
          width: scale == 1 ? 390 : 320,
          height: 844,
          scale: scale,
        );
        await _capture(tester, 'profile-$scale');
        await _showDialog(tester);
        await _capture(tester, 'dialog-$scale');
        expect(tester.takeException(), isNull);
      });
    }
  }
}

Future<void> _capture(WidgetTester tester, String name) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const Key('band-leave-preview')),
  );
  await tester.runAsync(() async {
    final picture = await boundary.toImage(pixelRatio: 2);
    try {
      final bytes = await picture.toByteData(format: ui.ImageByteFormat.png);
      await File(
        'build/band-leave-$name.png',
      ).writeAsBytes(bytes!.buffer.asUint8List());
    } finally {
      picture.dispose();
    }
  });
}

GradientOutlineButton _leaveButton(WidgetTester tester) =>
    tester.widget<GradientOutlineButton>(
      find.byKey(const Key('band-profile-leave-action')),
    );

Future<void> _showDialog(WidgetTester tester) async {
  await tester.ensureVisible(
    find.byKey(const Key('band-profile-leave-action')),
  );
  await tester.tap(find.byKey(const Key('band-profile-leave-action')));
  await tester.pumpAndSettle();
}

Future<void> _confirm(WidgetTester tester) async {
  await _showDialog(tester);
  await tester.tap(find.byKey(const Key('confirm-band-leave')));
  await tester.pumpAndSettle();
}

Future<void> _open(
  WidgetTester tester, {
  BandProfileViewMode mode = BandProfileViewMode.auto,
  double width = 390,
  double height = 1100,
  double scale = 1,
  String theme = 'navy',
  GlobalKey<NavigatorState>? navigatorKey,
  bool settle = true,
}) async {
  await tester.binding.setSurfaceSize(Size(width, height));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      navigatorKey: navigatorKey,
      theme: switch (theme) {
        'light' => AppTheme.light,
        'black' => AppTheme.black,
        _ => AppTheme.navy,
      },
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: RepaintBoundary(
          key: const Key('band-leave-preview'),
          child: child!,
        ),
      ),
      onGenerateRoute: (_) => MaterialPageRoute<void>(
        settings: RouteSettings(
          name: AppRoutes.bandProfile,
          arguments: BandProfileScreenArgs(bandId: 'band', viewMode: mode),
        ),
        builder: (_) => BandProfileScreen(),
      ),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}

BandProfile _profile({
  String role = 'MEMBER',
  String status = 'ACTIVE',
  String user = 'aedrum-user',
  bool duplicate = false,
  String id = 'band',
  String? title,
  int version = 0,
}) => BandProfile(
  id: id,
  name: 'Şahbaz',
  description: null,
  profilePictureUrl: null,
  instagramUrl: null,
  youtubeUrl: null,
  soundCloudUrl: null,
  spotifyEmbedUrl: null,
  spotifyArtistId: null,
  spotifyTrackIds: const [],
  members: List.generate(
    duplicate ? 2 : 1,
    (_) => BandMemberSummary(
      userId: user,
      profileId: 'artist',
      username: 'aedrum',
      profilePictureUrl: null,
      role: role,
      status: status,
      memberTitle: title,
      titleVersion: version,
    ),
  ),
);

AuthSession _session({
  String user = 'aedrum-user',
  String status = 'ACTIVE',
  List<String> roles = const ['ROLE_MUSICIAN'],
}) => AuthSession.authenticated(
  token: 'token-$user',
  userId: user,
  username: 'aedrum',
  accountStatus: status,
  roles: roles,
  permissions: const [],
  expiresAt: DateTime(2099),
  isAdmin: false,
);

class _Session extends AuthSessionManager {
  _Session() : super(tokenStore: _Tokens(), sessionStore: _SessionStore());
  AuthSession current = _session();
  @override
  AuthSession get session => current;
  void change(AuthSession next) {
    current = next;
    notifyListeners();
  }
}

class _Tokens implements TokenStore {
  @override
  Future<String?> readToken() async => 'token-aedrum-user';
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _SessionStore implements AuthSessionStore {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Bands implements BandRepository {
  BandProfile profile = _profile();
  int leaves = 0;
  String? leftBand;
  String? expectedUser;
  bool failure = false;
  bool versionConflict = false;
  final versions = <int?>[];
  bool throwLeave = false;
  bool throwPrivate = false;
  bool throwPublic = false;
  int publicReads = 0;
  Completer<Result<void>>? pending;
  Completer<Result<BandProfile>>? pendingRead;
  @override
  Future<Result<BandProfile>> getBandById(String bandId) async {
    if (throwPrivate) throw StateError('network');
    return pendingRead?.future ?? Result.success(profile);
  }

  @override
  Future<Result<BandProfile>> getPublicBandById(String bandId) async {
    publicReads++;
    if (throwPublic) throw StateError('network');
    return pendingRead?.future ?? Result.success(profile);
  }

  @override
  Future<Result<void>> leaveBand({
    required String bandId,
    String? expectedSessionKey,
    int? expectedTitleVersion,
  }) async {
    leaves++;
    leftBand = bandId;
    expectedUser = expectedSessionKey;
    versions.add(expectedTitleVersion);
    if (versionConflict) {
      return const Result.failure(
        AppError(code: '9221', message: 'Stale membership'),
      );
    }
    if (throwLeave) throw StateError('network');
    if (pending != null) return pending!.future;
    return failure
        ? const Result.failure(
            AppError(code: 'offline', message: 'Bağlantı yok.'),
          )
        : const Result.success(null);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Calendar implements MusicianCalendarRepository {
  int invalidations = 0;
  @override
  void invalidate() => invalidations++;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Musicians implements MusicianProfileRepository {
  @override
  Future<Result<MusicianProfile>> getPublicProfileByProfileId(
    String id,
  ) async => const Result.failure(AppError(code: '404', message: 'Missing'));
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Connections implements ArtistVenueConnectionRepository {
  int reads = 0;
  bool fail = false;
  Completer<Result<List<VenueConnection>>>? pending;
  @override
  Future<Result<List<VenueConnection>>> getVenueConnectionsByBandStatus(
    String id, {
    required String status,
  }) async {
    reads++;
    if (fail) throw StateError('offline');
    return pending?.future ?? const Result.success([]);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Followers implements BandFollowRepository {
  int reads = 0;
  @override
  Future<Result<int>> getFollowersCount(String bandId) async {
    reads++;
    return const Result.success(0);
  }

  @override
  Future<Result<bool>> isFollowingBand(String bandId) async =>
      const Result.success(false);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Media implements ProfileMediaRepository {
  @override
  Future<Result<ProfileMedia>> getProfileMedia({
    required String profileType,
    required String profileId,
  }) async =>
      Result.success(ProfileMedia(featuredVideo: null, videos: [], audios: []));
}

class _Engagement implements EngagementRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _LeaveApi implements ApiClient {
  ApiHttpMethod? method;
  String? path;
  ApiRequestContext? context;
  Map<String, dynamic>? query;
  @override
  Future<T> request<T>(
    ApiHttpMethod method,
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    T Function(Object? json)? decoder,
    ApiRequestContext? requestContext,
  }) async {
    this.method = method;
    this.path = path;
    context = requestContext;
    this.query = query;
    return decoder!(null);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _UnfencedApi extends ApiClient {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
