import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session_manager.dart';
import 'package:soundconnect_23_12_25codx/core/di/service_locator.dart';
import 'package:soundconnect_23_12_25codx/core/error/result.dart';
import 'package:soundconnect_23_12_25codx/modules/instrument/domain/entities/instrument.dart';
import 'package:soundconnect_23_12_25codx/modules/instrument/domain/instrument_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/musician_feed/domain/musician_feed_preferences.dart';
import 'package:soundconnect_23_12_25codx/modules/musician_feed/domain/musician_feed_preferences_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/data/models/musician_profile_save_request.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/musician_profile.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/musician_profile_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/musician_profile_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/profile_social_support.dart';
import 'package:soundconnect_23_12_25codx/shared/theme/app_theme.dart';
import 'package:soundconnect_23_12_25codx/shared/widgets/gradient_outline_button.dart';

void main() {
  late _SessionManager session;
  late _ProfileRepository profiles;

  setUp(() async {
    await serviceLocator.reset();
    session = _SessionManager();
    profiles = _ProfileRepository();
    serviceLocator
      ..registerSingleton<AuthSessionManager>(session)
      ..registerSingleton<MusicianProfileRepository>(profiles);
  });

  tearDown(() => serviceLocator.reset());

  test('completion task codes resolve to dedicated musician editors', () {
    expect(
      musicianProfileCompletionEditorForCode('INSTRUMENTS'),
      MusicianProfileCompletionEditor.instruments,
    );
    expect(
      musicianProfileCompletionEditorForCode('STAGE_NAME_AND_BIO'),
      MusicianProfileCompletionEditor.profileDetails,
    );
    expect(
      musicianProfileCompletionEditorForCode('PORTFOLIO'),
      MusicianProfileCompletionEditor.portfolio,
    );
    expect(
      musicianProfileCompletionEditorForCode(
        'PROFILE_PHOTO_AND_SOCIAL_LINKS',
      ),
      MusicianProfileCompletionEditor.photoAndSocialLinks,
    );
    expect(musicianProfileCompletionEditorForCode('UNKNOWN'), isNull);
  });

  testWidgets('portfolio completion opens the actual track upload editor', (
    tester,
  ) async {
    await _mountVoidEditorLauncher(
      tester,
      open: (context) =>
          showMusicianPortfolioCompletionEditor(context, profile: _profile),
    );

    await tester.tap(find.text('Aç'));
    await tester.pumpAndSettle();

    expect(find.text('SoundConnect üzerinden şarkı ekle'), findsOneWidget);
    expect(find.text('Ses dosyası seç'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('photo and social completion opens its photo action', (
    tester,
  ) async {
    var photoEdits = 0;
    await _mountVoidEditorLauncher(
      tester,
      open: (context) => showMusicianPhotoAndSocialLinksCompletionEditor(
        context,
        profile: _profile,
        onEditPhoto: () async => photoEdits += 1,
        onEditSocialLink: (_) async {},
      ),
    );

    await tester.tap(find.text('Aç'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('musician-photo-social-completion-editor')),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(const Key('musician-completion-edit-photo')),
    );
    await tester.pumpAndSettle();

    expect(photoEdits, 1);
    expect(find.text('Fotoğraf ve bağlantılar'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('photo and social completion opens the selected link editor', (
    tester,
  ) async {
    ProfileSocialPlatform? editedPlatform;
    await _mountVoidEditorLauncher(
      tester,
      open: (context) => showMusicianPhotoAndSocialLinksCompletionEditor(
        context,
        profile: _profile,
        onEditPhoto: () async {},
        onEditSocialLink: (platform) async => editedPlatform = platform,
      ),
    );

    await tester.tap(find.text('Aç'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(
        const Key('musician-completion-edit-social-instagram'),
      ),
    );
    await tester.pumpAndSettle();

    expect(editedPlatform, ProfileSocialPlatform.instagram);
    expect(tester.takeException(), isNull);
  });

  testWidgets('profile details completion saves a fenced partial update', (
    tester,
  ) async {
    await _mountEditorLauncher(
      tester,
      open: (context) =>
          showMusicianProfileDetailsEditor(context, profile: _profile),
    );

    await tester.tap(find.text('Aç'));
    await tester.pumpAndSettle();
    final fields = find.byType(TextField);
    expect(fields, findsNWidgets(2));
    await tester.enterText(fields.at(0), '  Sahne Adı  ');
    await tester.enterText(fields.at(1), '  Yeni biyografi  ');
    await tester.tap(
      find.widgetWithText(GradientOutlineButton, 'Bilgileri kaydet'),
    );
    await tester.pumpAndSettle();

    expect(profiles.expectedSessionKeys, ['owner-1']);
    expect(profiles.requests, hasLength(1));
    expect(profiles.requests.single.toJson(), {
      'stageName': 'Sahne Adı',
      'description': 'Yeni biyografi',
    });
    expect(find.byType(BottomSheet), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an account switch prevents a stale completion write', (
    tester,
  ) async {
    await _mountEditorLauncher(
      tester,
      open: (context) =>
          showMusicianProfileDetailsEditor(context, profile: _profile),
    );

    await tester.tap(find.text('Aç'));
    await tester.pumpAndSettle();
    session.current = _authenticated('other');
    await tester.tap(
      find.widgetWithText(GradientOutlineButton, 'Bilgileri kaydet'),
    );
    await tester.pump();

    expect(profiles.requests, isEmpty);
    expect(find.text('Oturum değişti. Lütfen yeniden dene.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a mismatched profile response cannot claim completion success', (
    tester,
  ) async {
    profiles.response = const Result.success(_otherProfile);
    await _mountEditorLauncher(
      tester,
      open: (context) =>
          showMusicianProfileDetailsEditor(context, profile: _profile),
    );

    await tester.tap(find.text('Aç'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(GradientOutlineButton, 'Bilgileri kaydet'),
    );
    await tester.pumpAndSettle();

    expect(profiles.requests, hasLength(1));
    expect(
      find.text('Profil kimliği doğrulanamadı. Lütfen yeniden dene.'),
      findsOneWidget,
    );
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('instrument completion starts from canonical preferences', (
    tester,
  ) async {
    serviceLocator
      ..registerSingleton<InstrumentRepository>(_Instruments())
      ..registerSingleton<MusicianFeedPreferencesRepository>(_Preferences());
    await _mountEditorLauncher(
      tester,
      open: (context) =>
          showMusicianInstrumentEditor(context, profile: _profile),
    );

    await tester.tap(find.text('Aç'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<CheckboxListTile>(
            find.byKey(const ValueKey('musician-instrument-i-guitar')),
          )
          .value,
      isTrue,
    );
    await tester.tap(find.byKey(const ValueKey('musician-instrument-i-bass')));
    await tester.pump();
    await tester.tap(
      find.widgetWithText(GradientOutlineButton, 'Enstrümanları kaydet'),
    );
    await tester.pumpAndSettle();

    expect(profiles.expectedSessionKeys, ['owner-1']);
    expect(profiles.requests.single.instrumentIds, ['i-bass', 'i-guitar']);
    expect(find.byType(BottomSheet), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _mountEditorLauncher(
  WidgetTester tester, {
  required Future<bool> Function(BuildContext context) open,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.navy,
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => unawaited(open(context)),
            child: const Text('Aç'),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _mountVoidEditorLauncher(
  WidgetTester tester, {
  required Future<void> Function(BuildContext context) open,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.navy,
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => unawaited(open(context)),
            child: const Text('Aç'),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

AuthSession _authenticated(String userId) => AuthSession.authenticated(
  token: 'token-$userId',
  userId: userId,
  username: userId,
  accountStatus: 'ACTIVE',
  roles: const ['ROLE_MUSICIAN'],
  permissions: const [],
  expiresAt: DateTime(2100),
  isAdmin: false,
);

const _profile = MusicianProfile(
  id: 'profile-1',
  userId: 'owner-1',
  username: 'owner',
  stageName: 'Eski Sahne Adı',
  bio: 'Eski biyografi',
  profilePicture: null,
  instagramUrl: null,
  youtubeUrl: null,
  soundcloudUrl: null,
  spotifyEmbedUrl: null,
  spotifyArtistId: null,
  spotifyTrackIds: [],
  spotifyTracks: [],
  instruments: ['Gitar'],
  activeVenues: [],
  bands: [],
);

const _otherProfile = MusicianProfile(
  id: 'other-profile',
  userId: 'other',
  username: 'other',
  stageName: 'Başka profil',
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

class _SessionManager extends Fake
    with ChangeNotifier
    implements AuthSessionManager {
  AuthSession current = _authenticated('owner-1');

  @override
  AuthSession get session => current;
}

class _ProfileRepository extends Fake implements MusicianProfileRepository {
  final requests = <MusicianProfileSaveRequest>[];
  final expectedSessionKeys = <String?>[];
  Result<MusicianProfile> response = const Result.success(_profile);

  @override
  Future<Result<MusicianProfile>> updateMyProfile(
    MusicianProfileSaveRequest request, {
    String? expectedSessionKey,
  }) async {
    requests.add(request);
    expectedSessionKeys.add(expectedSessionKey);
    return response;
  }
}

class _Instruments extends Fake implements InstrumentRepository {
  @override
  Future<Result<List<Instrument>>> getAll() async => const Result.success([
    Instrument(id: 'i-guitar', name: 'Gitar'),
    Instrument(id: 'i-bass', name: 'Bas Gitar'),
  ]);
}

class _Preferences extends Fake implements MusicianFeedPreferencesRepository {
  @override
  Future<Result<MusicianFeedPreferences>> get() async => const Result.success(
    MusicianFeedPreferences(
      contractVersion: 1,
      version: 3,
      opportunityCity: null,
      instruments: [
        MusicianFeedPreferenceInstrument(id: 'i-guitar', name: 'Gitar'),
      ],
    ),
  );
}
