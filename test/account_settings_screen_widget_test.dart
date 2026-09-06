import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/app/router/app_router.dart';
import 'package:soundconnect_23_12_25codx/app/router/app_routes.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session_manager.dart';
import 'package:soundconnect_23_12_25codx/core/di/service_locator.dart';
import 'package:soundconnect_23_12_25codx/core/error/app_error.dart';
import 'package:soundconnect_23_12_25codx/core/error/result.dart';
import 'package:soundconnect_23_12_25codx/modules/auth/presentation/cubit/auth_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/auth/presentation/screens/account_settings_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/listener_profile.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/listener_visibility_mode.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/listener_profile_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/musician_profile_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/musician_calendar_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/musician_calendar.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/musician_profile.dart';

import 'support/auth_widget_test_support.dart';

void main() {
  late RecordingAuthRepository repository;
  late MemoryTokenStore tokenStore;
  late MemoryAuthSessionStore sessionStore;
  late AuthSessionManager sessionManager;
  late AuthCubit cubit;

  setUp(() async {
    await serviceLocator.reset();
    repository = RecordingAuthRepository();
    tokenStore = MemoryTokenStore();
    sessionStore = MemoryAuthSessionStore();
    sessionManager = createSessionManager(
      tokenStore: tokenStore,
      sessionStore: sessionStore,
    );
    await sessionManager.startSession(
      token: _jwt(subject: 'listener-user', roles: const ['ROLE_LISTENER']),
      username: 'old-name',
      accountStatus: 'ACTIVE',
    );
    serviceLocator.registerSingleton<AuthSessionManager>(sessionManager);
    cubit = createAuthCubit(
      repository,
      tokenStore: tokenStore,
      sessionManager: sessionManager,
    );
  });

  tearDown(() async {
    await cubit.close();
    sessionManager.dispose();
    await serviceLocator.reset();
  });

  Widget app() {
    return MaterialApp(
      home: BlocProvider<AuthCubit>.value(
        value: cubit,
        child: const AccountSettingsScreen(),
      ),
    );
  }

  for (final route in [AppRoutes.settings, AppRoutes.accountSettings]) {
    testWidgets('$route preserves account controls without calendar settings', (
      tester,
    ) async {
      final calendar = _MusicianCalendarRepositoryFake();
      serviceLocator.registerSingleton<MusicianCalendarRepository>(calendar);
      await tester.pumpWidget(
        BlocProvider<AuthCubit>.value(
          value: cubit,
          child: MaterialApp(
            onGenerateRoute: AppRouter.onGenerateRoute,
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => Navigator.of(context).pushNamed(
                    route,
                    arguments: const {
                      'bandId': 'legacy-band',
                      'focusEventSettings': true,
                    },
                  ),
                  child: const Text('Ayarları aç'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Ayarları aç'));
      await tester.pumpAndSettle();
      expect(find.text('Hesap Ayarları'), findsOneWidget);
      expect(
        find.byKey(const Key('account-settings-username-tile')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('account-settings-password-reminder')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('account-settings-delete-account-reminder')),
        findsOneWidget,
      );
      expect(find.text('Etkinlik Ayarları'), findsNothing);
      expect(find.text('Grup Ayarları'), findsNothing);
      expect(
        find.byKey(const Key('musician-calendar-visibility-switch')),
        findsNothing,
      );
      expect(calendar.settingsReads, 0);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'musician account settings do not expose or load a global calendar preference',
    (tester) async {
      final calendar = _MusicianCalendarRepositoryFake();
      serviceLocator.registerSingleton<MusicianCalendarRepository>(calendar);
      serviceLocator.registerSingleton<MusicianProfileRepository>(
        _MusicianProfileRepositoryFake(),
      );
      await sessionManager.startSession(
        token: _jwt(subject: 'musician-user', roles: const ['ROLE_MUSICIAN']),
        username: 'musician',
        accountStatus: 'ACTIVE',
      );
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('musician-calendar-visibility-switch')),
        findsNothing,
      );
      expect(find.text('Etkinlik Ayarları'), findsNothing);
      expect(calendar.settingsReads, 0);
      expect(find.textContaining('Davetleri incelemek'), findsNothing);
      await sessionManager.logout();
    },
  );

  testWidgets('listener account settings never load the musician calendar', (
    tester,
  ) async {
    final calendar = _MusicianCalendarRepositoryFake();
    serviceLocator.registerSingleton<MusicianCalendarRepository>(calendar);
    serviceLocator.registerSingleton<ListenerProfileRepository>(
      _ListenerProfileRepositoryFake(),
    );
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('musician-calendar-visibility-switch')),
      findsNothing,
    );
    expect(calendar.settingsReads, 0);
  });

  testWidgets('account settings opens directly to the compact username row', (
    tester,
  ) async {
    await tester.pumpWidget(app());

    expect(find.text('Hesap Ayarları'), findsOneWidget);
    expect(
      find.byKey(const Key('account-settings-username-tile')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('settings-account-settings-button')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('account-settings-password-reminder')),
      findsOneWidget,
    );
    expect(find.text('Şifre değiştirme özelliği yakında'), findsOneWidget);
    expect(find.byKey(const Key('account-settings-theme-tile')), findsNothing);
    expect(
      find.byKey(const Key('account-settings-support-email')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('account-settings-delete-account-reminder')),
      findsOneWidget,
    );
    expect(
      tester.widget<Text>(find.text('Hesabı sil')).style?.color,
      const Color(0xFFFF5C6C),
    );
  });

  testWidgets('updates the profile description from account settings', (
    tester,
  ) async {
    final profileRepository = _ListenerProfileRepositoryFake();
    serviceLocator.registerSingleton<ListenerProfileRepository>(
      profileRepository,
    );
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('account-settings-profile-photo')),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(const Key('account-settings-profile-description')),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('account-settings-description-field')),
      'Yeni profil açıklaması',
    );
    await tester.ensureVisible(
      find.byKey(const Key('account-settings-save-description-button')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('account-settings-save-description-button')),
    );
    await tester.pumpAndSettle();

    expect(profileRepository.lastDescription, 'Yeni profil açıklaması');
    expect(find.text('Yeni profil açıklaması'), findsOneWidget);
  });

  testWidgets(
    'requires destructive confirmation before enabling listener ghost mode',
    (tester) async {
      final profileRepository = _ListenerProfileRepositoryFake();
      serviceLocator.registerSingleton<ListenerProfileRepository>(
        profileRepository,
      );
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('account-settings-listener-visibility')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('listener-ghost-profile-switch')));
      await tester.pumpAndSettle();

      expect(find.text('Hayalet profile geç?'), findsOneWidget);
      expect(find.textContaining('kalıcı olarak kaldırılır'), findsOneWidget);
      expect(
        find.textContaining('Takip ettiklerin ve mesajların kalır'),
        findsOneWidget,
      );
      expect(profileRepository.visibilityUpdates, isEmpty);

      await tester.tap(find.byKey(const Key('confirm-enable-ghost-profile')));
      await tester.pumpAndSettle();

      expect(profileRepository.visibilityUpdates, const [
        ListenerVisibilityMode.ghost,
      ]);
      expect(profileRepository.lastExpectedVersion, 4);
      expect(
        find.byKey(const Key('account-settings-profile-description')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('account-settings-ghost-content-notice')),
        findsOneWidget,
      );
    },
  );

  testWidgets('shows visibility throttling guidance in account settings', (
    tester,
  ) async {
    const backendMessage =
        'Görünürlük ayarını çok sık değiştirdin. Lütfen biraz sonra tekrar dene.';
    final profileRepository = _ListenerProfileRepositoryFake()
      ..visibilityUpdateError = const AppError(
        code: '1306',
        message: backendMessage,
      );
    serviceLocator.registerSingleton<ListenerProfileRepository>(
      profileRepository,
    );
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('listener-ghost-profile-switch')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-enable-ghost-profile')));
    await tester.pumpAndSettle();

    expect(profileRepository.visibilityUpdates, const [
      ListenerVisibilityMode.ghost,
    ]);
    expect(
      find.descendant(
        of: find.byType(SnackBar),
        matching: find.text(backendMessage),
      ),
      findsOneWidget,
    );
    expect(
      tester
          .widget<SwitchListTile>(
            find.byKey(const Key('listener-ghost-profile-switch')),
          )
          .value,
      isFalse,
    );
  });

  testWidgets(
    'visibility mutation closes the editor and locks profile mutations',
    (tester) async {
      final profileRepository = _ListenerProfileRepositoryFake();
      final pending = Completer<Result<ListenerProfile>>();
      profileRepository.visibilityCompleter = pending;
      serviceLocator.registerSingleton<ListenerProfileRepository>(
        profileRepository,
      );
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const Key('account-settings-profile-description')),
      );
      await tester.pump();
      expect(
        find.byKey(const Key('account-settings-description-field')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('listener-ghost-profile-switch')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('confirm-enable-ghost-profile')));
      await tester.pump();

      expect(
        find.byKey(const Key('account-settings-description-field')),
        findsNothing,
      );
      expect(
        tester
            .widget<SwitchListTile>(
              find.byKey(const Key('listener-ghost-profile-switch')),
            )
            .onChanged,
        isNull,
      );
      expect(
        tester
            .widget<InkWell>(
              find.descendant(
                of: find.byKey(const Key('account-settings-profile-photo')),
                matching: find.byType(InkWell),
              ),
            )
            .onTap,
        isNull,
      );

      pending.complete(Result.success(profileRepository._profile));
      await tester.pumpAndSettle();
      expect(profileRepository.visibilityUpdates, const [
        ListenerVisibilityMode.ghost,
      ]);
    },
  );

  testWidgets('normalizes the username and refreshes session metadata', (
    tester,
  ) async {
    repository.updateUsernameResult = const Result.success('new-name');
    await tester.pumpWidget(app());

    expect(
      find.byKey(const Key('account-settings-username-tile')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('account-settings-username-field')),
      findsNothing,
    );
    await _openUsernameEditor(tester);

    final field = _usernameField();
    expect(tester.widget<TextField>(field).controller?.text, 'old-name');
    expect(find.text('Hesap bilgileri'), findsOneWidget);
    expect(
      find.byKey(const Key('account-settings-username-cooldown-warning')),
      findsNothing,
    );

    await tester.enterText(field, '  NeW-NaMe  ');
    await tester.pump();

    expect(
      find.byKey(const Key('account-settings-username-cooldown-warning')),
      findsOneWidget,
    );
    expect(
      find.text(
        'Kullanıcı adını değiştirdikten sonra 30 gün boyunca yeniden '
        'değiştiremezsin.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('account-settings-save-button')));
    await tester.pumpAndSettle();

    expect(repository.updateUsernameCalls, 1);
    expect(repository.lastUpdatedUsername, 'new-name');
    expect(sessionManager.session.username, 'new-name');
    expect(sessionStore.metadata?.username, 'new-name');
    expect(
      find.byKey(const Key('account-settings-username-field')),
      findsNothing,
    );
    expect(find.text('@new-name'), findsOneWidget);
    expect(
      find.text('Kullanıcı adın @new-name olarak güncellendi.'),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('account-settings-username-cooldown-warning')),
      findsNothing,
    );

    // The successful update reschedules the JWT-expiry timer inside the
    // widget-test fake clock. End the session before the test leaves that
    // clock so Flutter does not report a leaked timer.
    await sessionManager.logout();
  });

  testWidgets('blocks an unchanged username without making a request', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await _openUsernameEditor(tester);

    final saveButton = tester.widget<FilledButton>(
      find.byKey(const Key('account-settings-save-button')),
    );

    expect(saveButton.onPressed, isNull);
    expect(repository.updateUsernameCalls, 0);
    expect(
      find.byKey(const Key('account-settings-username-cooldown-warning')),
      findsNothing,
    );
  });

  testWidgets('hides the cooldown warning when the edit is reverted', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await _openUsernameEditor(tester);

    await tester.enterText(_usernameField(), 'new-name');
    await tester.pump();
    expect(
      find.byKey(const Key('account-settings-username-cooldown-warning')),
      findsOneWidget,
    );

    await tester.enterText(_usernameField(), ' OLD-NAME ');
    await tester.pump();
    expect(
      find.byKey(const Key('account-settings-username-cooldown-warning')),
      findsNothing,
    );
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const Key('account-settings-save-button')),
          )
          .onPressed,
      isNull,
    );
  });

  testWidgets('keeps the current session when the backend rejects a username', (
    tester,
  ) async {
    repository.updateUsernameResult = const Result.failure(
      AppError(
        code: 'auth_username_conflict',
        message: 'Bu kullanıcı adı zaten kullanılıyor.',
      ),
    );
    await tester.pumpWidget(app());
    await _openUsernameEditor(tester);

    await tester.enterText(_usernameField(), 'taken-name');
    await tester.pump();
    await tester.tap(find.byKey(const Key('account-settings-save-button')));
    await tester.pump();

    expect(repository.updateUsernameCalls, 1);
    expect(sessionManager.session.username, 'old-name');
    expect(find.text('Bu kullanıcı adı zaten kullanılıyor.'), findsOneWidget);
  });

  testWidgets('shows the backend cooldown without changing the session', (
    tester,
  ) async {
    const cooldownMessage =
        'Kullanıcı adını değiştirdikten sonra 30 gün boyunca yeniden '
        'değiştiremezsin.';
    repository.updateUsernameResult = const Result.failure(
      AppError(code: '1005', message: cooldownMessage),
    );
    await tester.pumpWidget(app());
    await _openUsernameEditor(tester);

    await tester.enterText(_usernameField(), 'another-name');
    await tester.pump();
    await tester.tap(find.byKey(const Key('account-settings-save-button')));
    await tester.pump();

    expect(repository.updateUsernameCalls, 1);
    expect(sessionManager.session.username, 'old-name');
    expect(sessionStore.metadata?.username, 'old-name');
    expect(
      find.descendant(
        of: find.byType(SnackBar),
        matching: find.text(cooldownMessage),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('account-settings-username-cooldown-warning')),
      findsOneWidget,
    );
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const Key('account-settings-save-button')),
          )
          .onPressed,
      isNotNull,
    );
  });
}

class _ListenerProfileRepositoryFake extends ListenerProfileRepository {
  String? lastDescription;
  ListenerVisibilityMode visibilityMode = ListenerVisibilityMode.standard;
  AppError? visibilityUpdateError;
  Completer<Result<ListenerProfile>>? visibilityCompleter;
  int version = 4;
  final List<ListenerVisibilityMode> visibilityUpdates =
      <ListenerVisibilityMode>[];
  int? lastExpectedVersion;

  ListenerProfile get _profile => ListenerProfile(
    id: 'listener-profile-id',
    userId: 'listener-user',
    username: 'old-name',
    bio: lastDescription ?? 'Eski açıklama',
    profilePictureUrl: null,
    followerCount: visibilityMode.isGhost ? null : 0,
    followingCount: visibilityMode.isGhost ? null : 0,
    visibilityMode: visibilityMode,
    version: version,
    profileContentVisible: !visibilityMode.isGhost,
    profileContentEditable: !visibilityMode.isGhost,
    canReceiveFollowers: !visibilityMode.isGhost,
  );

  @override
  Future<Result<ListenerProfile>> getMyProfile() async {
    return Result.success(_profile);
  }

  @override
  Future<Result<ListenerProfile>> updateMyProfile(
    ListenerProfileSaveRequest request,
  ) async {
    lastDescription = request.description ?? lastDescription;
    return Result.success(_profile);
  }

  @override
  Future<Result<ListenerProfile>> updateVisibility(
    ListenerVisibilityUpdateRequest request,
  ) async {
    visibilityUpdates.add(request.visibilityMode);
    lastExpectedVersion = request.expectedVersion;
    final updateError = visibilityUpdateError;
    if (updateError != null) return Result.failure(updateError);
    visibilityMode = request.visibilityMode;
    version += 1;
    final completer = visibilityCompleter;
    if (completer != null) return completer.future;
    return Result.success(_profile);
  }
}

class _MusicianCalendarRepositoryFake extends Fake
    implements MusicianCalendarRepository {
  int settingsReads = 0;
  @override
  Future<Result<MusicianCalendarSettings>> getSettings() async {
    settingsReads++;
    return const Result.success(
      MusicianCalendarSettings(visible: false, version: 2),
    );
  }
}

class _MusicianProfileRepositoryFake extends Fake
    implements MusicianProfileRepository {
  @override
  Future<Result<MusicianProfile>> getMyProfile() async => const Result.success(
    MusicianProfile(
      id: 'musician-profile',
      userId: 'musician-user',
      username: 'musician',
      stageName: null,
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
    ),
  );
}

Finder _usernameField() {
  return find.descendant(
    of: find.byKey(const Key('account-settings-username-field')),
    matching: find.byType(TextField),
  );
}

Future<void> _openUsernameEditor(WidgetTester tester) async {
  await tester.tap(
    find.byKey(const Key('account-settings-edit-username-button')),
  );
  await tester.pumpAndSettle();
}

String _jwt({required String subject, required List<String> roles}) {
  String encode(Object value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  final expiresAt =
      DateTime.now()
          .toUtc()
          .add(const Duration(hours: 1))
          .millisecondsSinceEpoch ~/
      1000;

  return '${encode(<String, String>{'alg': 'HS256'})}.'
      '${encode(<String, Object>{'sub': subject, 'exp': expiresAt, 'roles': roles})}.'
      'signature';
}
