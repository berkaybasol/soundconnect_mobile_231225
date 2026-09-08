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
import 'package:soundconnect_23_12_25codx/modules/profile/domain/band_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/band_member_summary.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/band_pending_invitation.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/band_profile.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/musician_profile.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/musician_search_option.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/musician_search_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/musician_profile_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/band_management_panel_screen.dart';
import 'package:soundconnect_23_12_25codx/shared/theme/app_theme.dart';
import 'package:soundconnect_23_12_25codx/shared/widgets/gradient_outline_button.dart';

void main() {
  late _Bands bands;
  late _SessionManager session;
  late _Musicians musicians;
  late _Search search;
  setUp(() async {
    await serviceLocator.reset();
    bands = _Bands();
    session = _SessionManager();
    musicians = _Musicians();
    search = _Search();
    serviceLocator
      ..registerSingleton<BandRepository>(bands)
      ..registerSingleton<AuthSessionManager>(session)
      ..registerSingleton<MusicianProfileRepository>(musicians)
      ..registerSingleton<MusicianSearchRepository>(search);
  });
  tearDown(serviceLocator.reset);

  for (final theme in ['navy', 'light', 'black']) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('compact members layout $theme at 320dp / ${scale}x', (
        tester,
      ) async {
        bands.profile = _profile(longNames: scale == 2);
        await _open(tester, bands, theme: theme, scale: scale);
        expect(find.byType(CustomScrollView), findsOneWidget);
        expect(find.byType(ListView), findsNothing);
        expect(find.text('Kurucu'), findsOneWidget);
        expect(find.byTooltip('Kurucu kaldırılamaz'), findsNothing);
        expect(find.byTooltip('Üyeyi çıkar'), findsNothing);
        expect(find.byIcon(Icons.chevron_right_rounded), findsNothing);
        expect(find.byIcon(Icons.edit_outlined), findsNothing);
        expect(find.byIcon(Icons.person_remove_outlined), findsNothing);
        expect(find.byTooltip('Üye seçenekleri'), findsNWidgets(2));
        for (final id in ['founder', 'member-1']) {
          final menu = tester.getRect(find.byKey(Key('member-options-$id')));
          final identity = tester.getRect(
            find.byKey(Key('band-member-identity-$id')),
          );
          expect(menu.width, greaterThanOrEqualTo(48));
          expect(menu.height, greaterThanOrEqualTo(48));
          expect(menu.left, greaterThanOrEqualTo(identity.right));
          expect((menu.center.dy - identity.center.dy).abs(), lessThan(1));
        }
        expect(find.byKey(const Key('band-invite-member')), findsOneWidget);
        final member = tester.getRect(
          find.byKey(const ValueKey('band-member-founder')),
        );
        expect(member.width, 280);
        expect(member.height, lessThan(160));
        expect(tester.takeException(), isNull);

        if (const bool.fromEnvironment('MEMBER_PREVIEW')) {
          await tester.runAsync(() async {
            const fontRoot = String.fromEnvironment(
              'MEMBER_PREVIEW_FLUTTER_ROOT',
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
          await tester.pumpAndSettle();
          final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(const Key('members-preview')),
          );
          await tester.runAsync(() async {
            final picture = await boundary.toImage(pixelRatio: 2);
            try {
              final bytes = await picture.toByteData(
                format: ui.ImageByteFormat.png,
              );
              await File(
                'build/band-members-$theme-$scale.png',
              ).writeAsBytes(bytes!.buffer.asUint8List());
            } finally {
              picture.dispose();
            }
          });
        }
      });
    }
  }

  testWidgets('founder-only list has no removal action', (tester) async {
    bands.profile = _profile(count: 1);
    await _open(tester, bands);
    expect(find.byTooltip('Üyeyi çıkar'), findsNothing);
    expect(find.byIcon(Icons.delete_outline_rounded), findsNothing);
    expect(find.text('Kurucu'), findsOneWidget);
    await _openOptions(tester, 'founder');
    expect(find.byKey(const Key('edit-member-title-founder')), findsOneWidget);
    expect(find.byKey(const Key('remove-member-founder')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('large roster uses one lazy scrollable and reaches last member', (
    tester,
  ) async {
    bands.profile = _profile(count: 100);
    await _open(tester, bands);
    final last = find.byKey(const ValueKey('band-member-member-99'));
    expect(last, findsNothing);
    await tester.scrollUntilVisible(
      last,
      450,
      scrollable: find.byType(Scrollable).last,
      maxScrolls: 40,
    );
    expect(last, findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('parent refresh completion updates already open members page', (
    tester,
  ) async {
    final pending = Completer<Result<BandProfile>>();
    bands.pending = pending;
    await _open(tester, bands, settle: false);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    pending.complete(Result.success(bands.profile));
    await tester.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('bugrasahin'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('refresh is single flight and blocks invitation until complete', (
    tester,
  ) async {
    await _open(tester, bands);
    final pending = Completer<Result<BandProfile>>();
    bands.pending = pending;
    final refresh = tester
        .widget<IconButton>(
          find.byWidgetPredicate(
            (widget) =>
                widget is IconButton && widget.tooltip == 'Üyeleri yenile',
          ),
        )
        .onPressed!;
    refresh();
    refresh();
    await tester.pump();
    expect(bands.reads, 2);
    expect(
      tester
          .widget<GradientOutlineButton>(
            find.byKey(const Key('band-invite-member')),
          )
          .onPressed,
      isNull,
    );
    pending.complete(Result.success(bands.profile));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<GradientOutlineButton>(
            find.byKey(const Key('band-invite-member')),
          )
          .onPressed,
      isNotNull,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('refresh error remains retryable', (tester) async {
    await _open(tester, bands);
    bands.throwRead = true;
    await tester.tap(find.byTooltip('Üyeleri yenile'));
    await tester.pumpAndSettle();
    expect(
      find.text('Üyeler yüklenemedi. Lütfen tekrar dene.'),
      findsOneWidget,
    );
    bands.throwRead = false;
    await tester.tap(find.byTooltip('Üyeleri yenile'));
    await tester.pumpAndSettle();
    expect(find.text('bugrasahin'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty group has compact empty state and invitation', (
    tester,
  ) async {
    bands.profile = _profile(count: 0);
    await _open(tester, bands);
    expect(find.text('Henüz üye bulunmuyor.'), findsOneWidget);
    expect(find.text('Üye davet et'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'removal retains confirmation and targets only the selected member',
    (tester) async {
      await _open(tester, bands);
      await _openOptions(tester, 'member-1');
      await tester.tap(find.byKey(const Key('remove-member-member-1')));
      await tester.pumpAndSettle();
      expect(find.text('Üyeyi Çıkar'), findsOneWidget);
      await tester.tap(find.text('İptal'));
      await tester.pumpAndSettle();
      expect(bands.removedUserId, isNull);
      await _openOptions(tester, 'member-1');
      await tester.tap(find.byKey(const Key('remove-member-member-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Çıkar'));
      await tester.pumpAndSettle();
      expect(bands.removedUserId, 'member-1');
      expect(find.byTooltip('Üyeyi çıkar'), findsNothing);
      expect(find.byKey(const Key('member-options-member-1')), findsNothing);
      expect(find.text('bugrasahin'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'member menu cancellation never opens confirmation or mutates roster',
    (tester) async {
      await _open(tester, bands);
      await _openOptions(tester, 'member-1');
      expect(find.text('Rolü düzenle'), findsOneWidget);
      expect(find.text('Gruptan çıkar'), findsOneWidget);
      Navigator.of(
        tester.element(find.byKey(const Key('remove-member-member-1'))),
      ).pop();
      await tester.pumpAndSettle();
      expect(find.text('Üyeyi Çıkar'), findsNothing);
      expect(bands.removedUserId, isNull);
      expect(
        tester
            .widget<IconButton>(
              find.byKey(const Key('member-options-member-1')),
            )
            .onPressed,
        isNotNull,
      );
    },
  );

  for (final next in <String, AuthSession>{
    'another account': _session(userId: 'other-user'),
    'logout': const AuthSession.guest(),
  }.entries) {
    testWidgets(
      'remove menu selection after ${next.key} cannot open confirmation',
      (tester) async {
        await _open(tester, bands);
        await _openOptions(tester, 'member-1');
        session.change(next.value);
        await tester.pump();
        await tester.tap(find.byKey(const Key('remove-member-member-1')));
        await tester.pumpAndSettle();
        expect(find.text('Üyeyi Çıkar'), findsNothing);
        expect(bands.removedUserId, isNull);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'remove confirmation after ${next.key} cannot dispatch mutation',
      (tester) async {
        await _open(tester, bands);
        await _openOptions(tester, 'member-1');
        await tester.tap(find.byKey(const Key('remove-member-member-1')));
        await tester.pumpAndSettle();
        expect(find.text('Üyeyi Çıkar'), findsOneWidget);
        session.change(next.value);
        await tester.pump();
        await tester.tap(find.widgetWithText(FilledButton, 'Çıkar'));
        await tester.pumpAndSettle();
        expect(bands.removedUserId, isNull);
        expect(find.text('aedrum1'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'invitation opens existing picker once and cancellation restores actions',
    (tester) async {
      await _open(tester, bands);
      final invite = tester
          .widget<GradientOutlineButton>(
            find.byKey(const Key('band-invite-member')),
          )
          .onPressed!;
      invite();
      invite();
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsOneWidget);
      Navigator.of(tester.element(find.byType(TextField))).pop();
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<GradientOutlineButton>(
              find.byKey(const Key('band-invite-member')),
            )
            .onPressed,
        isNotNull,
      );
      expect(tester.takeException(), isNull);
    },
  );

  Future<void> openPicker(WidgetTester tester) async {
    await _open(tester, bands);
    await tester.tap(find.byKey(const Key('band-invite-member')));
    await tester.pumpAndSettle();
  }

  Future<void> searchForCandidate(WidgetTester tester) async {
    await tester.enterText(find.byType(TextField), 'ae');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();
  }

  for (final viewer in ['member-1', 'outsider']) {
    testWidgets('$viewer cannot start an invitation from a founder workspace', (
      tester,
    ) async {
      await _open(tester, bands);
      session.change(_session(userId: viewer));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<GradientOutlineButton>(
              find.byKey(const Key('band-invite-member')),
            )
            .onPressed,
        isNull,
      );
    });
  }

  testWidgets(
    'matching display names do not block a different musician identity',
    (tester) async {
      search.results = [_option(name: 'aedrum1')];
      await openPicker(tester);
      await searchForCandidate(tester);
      expect(find.byIcon(Icons.add_circle_outline), findsOneWidget);
      expect(find.text('Üye'), findsNothing);
    },
  );

  testWidgets(
    'canonical existing profile stays blocked even with a different display name',
    (tester) async {
      search.results = [_option(id: 'profile-1', name: 'Different stage name')];
      await openPicker(tester);
      await searchForCandidate(tester);
      expect(find.text('Üye'), findsOneWidget);
      expect(find.byIcon(Icons.add_circle_outline), findsNothing);
    },
  );

  testWidgets(
    'shortening an in-flight query invalidates its response immediately',
    (tester) async {
      search.pending = Completer<Result<List<MusicianSearchOption>>>();
      await openPicker(tester);
      await searchForCandidate(tester);
      await tester.enterText(find.byType(TextField), 'a');
      search.pending!.complete(Result.success([_option()]));
      await tester.pumpAndSettle();
      expect(find.text('Candidate'), findsNothing);
      expect(find.byType(LinearProgressIndicator), findsNothing);
    },
  );

  testWidgets('search exceptions release loading and allow a later retry', (
    tester,
  ) async {
    search.throwRead = true;
    await openPicker(tester);
    await searchForCandidate(tester);
    await tester.pumpAndSettle();
    expect(find.text('Arama başarısız. Tekrar dene.'), findsOneWidget);
    search.throwRead = false;
    await tester.tap(find.byIcon(Icons.arrow_forward));
    await tester.pumpAndSettle();
    expect(find.text('Candidate'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('stale picker selection cannot cross an account change', (
    tester,
  ) async {
    await openPicker(tester);
    await searchForCandidate(tester);
    final select = tester
        .widget<IconButton>(
          find.widgetWithIcon(IconButton, Icons.add_circle_outline),
        )
        .onPressed!;
    session.change(_session(userId: 'member-1'));
    select();
    await tester.pumpAndSettle();
    expect(bands.invites, isEmpty);
    expect(musicians.candidateReads, 0);
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('account switch during identity lookup drops the invitation', (
    tester,
  ) async {
    musicians.pendingCandidate = Completer<Result<MusicianProfile>>();
    await openPicker(tester);
    await searchForCandidate(tester);
    await tester.tap(find.byIcon(Icons.add_circle_outline));
    await tester.pump(const Duration(milliseconds: 500));
    session.change(_session(userId: 'member-1'));
    musicians.pendingCandidate!.complete(Result.success(_candidate()));
    await tester.pumpAndSettle();
    expect(bands.invites, isEmpty);
  });

  testWidgets(
    'a mismatched canonical profile response never invites another account',
    (tester) async {
      musicians.candidate = _candidate(id: 'wrong-profile');
      await openPicker(tester);
      await searchForCandidate(tester);
      await tester.tap(find.byIcon(Icons.add_circle_outline));
      await tester.pumpAndSettle();
      expect(bands.invites, isEmpty);
    },
  );

  testWidgets(
    'repeated picker delivery sends one invitation and keeps the workspace open',
    (tester) async {
      await openPicker(tester);
      await searchForCandidate(tester);
      final select = tester
          .widget<IconButton>(
            find.widgetWithIcon(IconButton, Icons.add_circle_outline),
          )
          .onPressed!;
      select();
      select();
      await tester.pumpAndSettle();
      expect(bands.invites, [('band', 'candidate-user', 'founder')]);
      expect(find.text('Üyeleri Yönet'), findsOneWidget);
    },
  );

  testWidgets(
    'late remove response cannot report success or reload for another account',
    (tester) async {
      bands.pendingRemove = Completer<Result<void>>();
      await _open(tester, bands);
      await _openOptions(tester, 'member-1');
      await tester.tap(find.byKey(const Key('remove-member-member-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Çıkar'));
      await tester.pump();
      final reads = bands.reads;
      session.change(_session(userId: 'member-1'));
      bands.pendingRemove!.complete(const Result.success(null));
      await tester.pumpAndSettle();
      expect(bands.removeAccount, 'founder');
      expect(bands.reads, reads);
      expect(find.text('aedrum1 bandden çıkarıldı.'), findsNothing);
    },
  );

  testWidgets(
    'stale removal sends frozen tenure and requires reselection after refresh',
    (tester) async {
      bands.profile = _profile(version: 4);
      await _open(tester, bands);
      await _openOptions(tester, 'member-1');
      await tester.tap(find.byKey(const Key('remove-member-member-1')));
      await tester.pumpAndSettle();
      bands.profile = _profile(version: 6);
      bands.removeConflict = true;
      await tester.tap(find.widgetWithText(FilledButton, 'Çıkar'));
      await tester.pumpAndSettle();
      expect(bands.removeVersions, [4]);
      expect(
        find.text('Üyelik bilgileri değişti. Üyeleri yenileyip tekrar seç.'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('member-options-member-1')), findsOneWidget);
      bands.removeConflict = false;
      await _openOptions(tester, 'member-1');
      await tester.tap(find.byKey(const Key('remove-member-member-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Çıkar'));
      await tester.pumpAndSettle();
      expect(bands.removeVersions, [4, 6]);
      expect(find.byKey(const Key('member-options-member-1')), findsNothing);
    },
  );
}

Future<void> _openOptions(WidgetTester tester, String id) async {
  await tester.ensureVisible(find.byKey(Key('member-options-$id')));
  await tester.tap(find.byKey(Key('member-options-$id')));
  await tester.pumpAndSettle();
}

Future<void> _open(
  WidgetTester tester,
  _Bands bands, {
  String theme = 'navy',
  double scale = 1,
  bool settle = true,
}) async {
  await tester.binding.setSurfaceSize(const Size(320, 844));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    RepaintBoundary(
      key: const Key('members-preview'),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: theme == 'light'
            ? AppTheme.light
            : theme == 'black'
            ? AppTheme.black
            : AppTheme.navy,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: BandManagementPanelScreen(profile: bands.profile),
      ),
    ),
  );
  await tester.pump();
  expect(
    tester.takeException(),
    isNull,
    reason: 'Management panel before opening members',
  );
  await tester.ensureVisible(find.text('Üyeleri Yönet'));
  await tester.tap(find.text('Üyeleri Yönet'));
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }
}

BandProfile _profile({
  int count = 2,
  bool longNames = false,
  int version = 0,
}) => BandProfile(
  id: 'band',
  name: longNames ? 'Dolu Kadehi Ters Tut ve Konuk Müzisyenler' : 'Şahbaz',
  description: null,
  profilePictureUrl: null,
  instagramUrl: null,
  youtubeUrl: null,
  soundCloudUrl: null,
  spotifyEmbedUrl: null,
  spotifyArtistId: null,
  spotifyTrackIds: const [],
  members: List.generate(
    count,
    (i) => BandMemberSummary(
      userId: i == 0 ? 'founder' : 'member-$i',
      profileId: 'profile-$i',
      username: longNames
          ? 'cokuzunbirmuzisyenkullaniciadi$i'
          : i == 0
          ? 'bugrasahin'
          : 'aedrum$i',
      profilePictureUrl: null,
      role: i == 0 ? 'FOUNDER' : 'MEMBER',
      status: 'ACTIVE',
      titleVersion: version,
    ),
  ),
);

class _Bands extends Fake implements BandRepository {
  BandProfile profile = _profile();
  Completer<Result<BandProfile>>? pending;
  int reads = 0;
  bool throwRead = false;
  String? removedUserId;
  String? removeAccount;
  bool removeConflict = false;
  final removeVersions = <int?>[];
  Completer<Result<void>>? pendingRemove;
  final invites = <(String, String, String?)>[];
  @override
  Future<Result<void>> inviteMember({
    required String bandId,
    required String invitedUserId,
    String? message,
    String? expectedSessionKey,
  }) async {
    invites.add((bandId, invitedUserId, expectedSessionKey));
    return const Result.success(null);
  }

  @override
  Future<Result<BandPendingInvitationPage>> getPendingInvitations({
    required String bandId,
    int page = 0,
    int size = 20,
    required String expectedSessionKey,
  }) async => Result.success(
    BandPendingInvitationPage(
      items: const [],
      page: page,
      size: size,
      totalElements: 0,
      hasNext: false,
    ),
  );
  @override
  Future<Result<void>> removeMember({
    required String bandId,
    required String userId,
    String? expectedSessionKey,
    int? expectedTitleVersion,
  }) async {
    expect(bandId, 'band');
    removedUserId = userId;
    removeAccount = expectedSessionKey;
    removeVersions.add(expectedTitleVersion);
    if (removeConflict) {
      return const Result.failure(
        AppError(code: '9221', message: 'Stale membership'),
      );
    }
    if (pendingRemove != null) return pendingRemove!.future;
    profile = _profile(count: 1);
    return const Result.success(null);
  }

  @override
  Future<Result<BandProfile>> getBandById(String bandId) async {
    reads++;
    if (throwRead) throw StateError('offline');
    return pending == null ? Result.success(profile) : pending!.future;
  }
}

class _Musicians extends Fake implements MusicianProfileRepository {
  MusicianProfile candidate = _candidate();
  int candidateReads = 0;
  Completer<Result<MusicianProfile>>? pendingCandidate;
  @override
  Future<Result<MusicianProfile>> getPublicProfileByProfileId(
    String profileId,
  ) async {
    if (profileId == 'candidate-profile') {
      candidateReads++;
      return pendingCandidate?.future ?? Result.success(candidate);
    }
    return const Result.failure(AppError(code: 'missing', message: 'No photo'));
  }
}

MusicianSearchOption _option({
  String id = 'candidate-profile',
  String name = 'Candidate',
}) => MusicianSearchOption(
  profileId: id,
  displayName: name,
  secondaryLabel: null,
  profilePictureUrl: null,
);

MusicianProfile _candidate({String id = 'candidate-profile'}) =>
    MusicianProfile(
      id: id,
      userId: 'candidate-user',
      username: 'Candidate',
      stageName: 'Candidate',
      bio: null,
      profilePicture: null,
      instagramUrl: null,
      youtubeUrl: null,
      soundcloudUrl: null,
      spotifyEmbedUrl: null,
      spotifyArtistId: null,
      spotifyTrackIds: [],
      spotifyTracks: [],
      instruments: [],
      activeVenues: [],
      bands: [],
    );

class _Search extends Fake implements MusicianSearchRepository {
  List<MusicianSearchOption> results = [_option()];
  Completer<Result<List<MusicianSearchOption>>>? pending;
  bool throwRead = false;
  @override
  Future<Result<List<MusicianSearchOption>>> search(String query) async {
    if (throwRead) throw StateError('offline');
    return pending?.future ?? Result.success(results);
  }
}

class _SessionManager extends Fake implements AuthSessionManager {
  final listeners = <VoidCallback>{};
  @override
  AuthSession get session => _current;
  AuthSession _current = _session();
  @override
  void addListener(VoidCallback listener) => listeners.add(listener);
  @override
  void removeListener(VoidCallback listener) => listeners.remove(listener);
  void change(AuthSession next) {
    _current = next;
    for (final listener in List.of(listeners)) {
      listener();
    }
  }
}

AuthSession _session({String userId = 'founder'}) => AuthSession.authenticated(
  token: 'token-$userId',
  userId: userId,
  username: userId,
  accountStatus: 'ACTIVE',
  roles: const ['ROLE_MUSICIAN'],
  permissions: const [],
  expiresAt: DateTime.utc(2040),
  isAdmin: false,
);
