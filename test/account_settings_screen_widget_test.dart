import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/policy/profile_feed_availability.dart';
import 'package:soundconnect_23_12_25codx/app/router/app_router.dart';
import 'package:soundconnect_23_12_25codx/app/router/app_routes.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session_manager.dart';
import 'package:soundconnect_23_12_25codx/core/di/service_locator.dart';
import 'package:soundconnect_23_12_25codx/core/error/app_error.dart';
import 'package:soundconnect_23_12_25codx/core/error/result.dart';
import 'package:soundconnect_23_12_25codx/core/network/api_client.dart';
import 'package:soundconnect_23_12_25codx/core/push/push_coordinator.dart';
import 'package:soundconnect_23_12_25codx/core/push/push_device_api.dart';
import 'package:soundconnect_23_12_25codx/core/push/push_provider.dart';
import 'package:soundconnect_23_12_25codx/core/push/push_settings_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/auth/data/account_deletion_repository_impl.dart';
import 'package:soundconnect_23_12_25codx/modules/auth/data/account_password_repository.dart';
import 'package:soundconnect_23_12_25codx/core/network/api_exception.dart';
import 'package:soundconnect_23_12_25codx/modules/auth/domain/account_deletion_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/auth/presentation/cubit/auth_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/auth/presentation/screens/account_settings_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/auth/presentation/screens/listener_account_deletion_dialog.dart';
import 'package:soundconnect_23_12_25codx/modules/musician_feed/domain/musician_feed_muted_authors.dart';
import 'package:soundconnect_23_12_25codx/modules/musician_feed/domain/musician_feed_muted_authors_repository.dart';
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

  testWidgets(
    'retained delete action cannot open a dialog for a replacement account',
    (tester) async {
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      final openDeletion = tester
          .widget<ListTile>(
            find.byKey(const Key('account-settings-delete-account-reminder')),
          )
          .onTap!;
      await tester.runAsync(
        () => sessionManager.startSession(
          token: _jwt(
            subject: 'different-listener',
            roles: const ['ROLE_LISTENER'],
          ),
          username: 'different-listener',
          accountStatus: 'ACTIVE',
        ),
      );
      openDeletion();
      await tester.pumpAndSettle();
      expect(find.byType(AccountDeletionDialog), findsNothing);
      expect(sessionManager.session.userId, 'different-listener');
    },
  );

  for (final scenario in [
    'original session',
    'different account',
    'relogin with the same token',
  ]) {
    testWidgets('committed deletion after both routes were disposed: $scenario', (
      tester,
    ) async {
      final owner = sessionManager.session;
      final api = _PendingDeletionApi();
      serviceLocator.registerSingleton<AccountDeletionRepository>(
        AccountDeletionRepositoryImpl(api, sessionManager),
      );
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      final delete = find.byKey(
        const Key('account-settings-delete-account-reminder'),
      );
      await tester.ensureVisible(delete);
      await tester.tap(delete);
      await tester.pumpAndSettle();
      final next = find.byKey(const Key('account-delete-next'));
      await tester.ensureVisible(next);
      await tester.tap(next);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('account-delete-password')),
        'password',
      );
      final acknowledge = find.byKey(const Key('account-delete-acknowledge'));
      await tester.ensureVisible(acknowledge);
      await tester.tap(acknowledge);
      await tester.pump();
      await tester.tap(find.byKey(const Key('account-delete-confirm')));
      await tester.pump();
      expect(api.calls, 1);

      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      unawaited(
        navigator.pushAndRemoveUntil<void>(
          MaterialPageRoute(
            builder: (_) => const Scaffold(body: Text('Replacement route')),
          ),
          (_) => false,
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byType(AccountSettingsScreen, skipOffstage: false),
        findsNothing,
      );
      expect(
        find.byType(AccountDeletionDialog, skipOffstage: false),
        findsNothing,
      );
      if (scenario == 'original session') {
        // A metadata update replaces the session object without replacing its credentials.
        await tester.runAsync(
          () => sessionManager.updateUsername('renamed-listener'),
        );
      } else {
        await tester.runAsync(
          () => sessionManager.startSession(
            token: scenario == 'different account'
                ? _jwt(
                    subject: 'second-listener',
                    roles: const ['ROLE_LISTENER'],
                  )
                : owner.token!,
            username: 'new-login',
            accountStatus: 'ACTIVE',
          ),
        );
      }
      final active = sessionManager.session;
      api.response.complete(true);
      await tester.pump();
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pumpAndSettle();
      if (scenario == 'original session') {
        expect(sessionManager.session.isAuthenticated, isFalse);
        expect(tokenStore.token, isNull);
        expect(sessionStore.metadata, isNull);
      } else {
        expect(sessionManager.session, same(active));
        expect(tokenStore.token, active.token);
        expect(sessionStore.metadata?.username, 'new-login');
      }
    });
  }

  Future<void> openPassword(WidgetTester tester, _PasswordApi api) async {
    serviceLocator.registerSingleton<AccountPasswordRepository>(
      AccountPasswordRepository(api, sessionManager),
    );
    await tester.pumpWidget(app());
    final row = find.byKey(const Key('account-settings-password'));
    await tester.ensureVisible(row);
    await tester.tap(row);
    await tester.pumpAndSettle();
  }

  testWidgets('Google account sees its sign-in method in settings', (
    tester,
  ) async {
    final api = _PasswordApi('GOOGLE');
    await openPassword(tester, api);
    expect(find.text('Bu hesaba Google ile giriş yapıyorsun.'), findsOneWidget);
    expect(find.text('Şifreni değiştir'), findsNothing);
    expect(api.writes, 0);
  });

  testWidgets(
    'password sheet validates, preserves wrong-password session and replaces token on success',
    (tester) async {
      final api = _PasswordApi('LOCAL');
      final original = sessionManager.session;
      await openPassword(tester, api);
      final fields = find.byType(TextFormField);
      expect(fields, findsNWidgets(3));
      for (final input in tester.widgetList<TextField>(
        find.descendant(of: fields, matching: find.byType(TextField)),
      )) {
        expect(input.obscureText, isTrue);
      }
      await tester.enterText(fields.at(0), 'incorrect');
      await tester.enterText(fields.at(1), 'updated-pass');
      await tester.enterText(fields.at(2), 'mismatch');
      final submit = find.text('Şifreyi değiştir');
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(find.text('Şifreler eşleşmeli.'), findsOneWidget);
      expect(api.writes, 0);
      await tester.enterText(fields.at(2), 'updated-pass');
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(find.text('Mevcut şifren doğru değil.'), findsOneWidget);
      expect(sessionManager.session, same(original));
      await tester.enterText(fields.at(0), 'current-pass');
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      // The session manager's credential-write queue was created in setUp,
      // outside the widget binding's virtual clock.
      await tester.pump();
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pumpAndSettle();
      expect(find.text('Şifren değiştirildi.'), findsOneWidget);
      expect(find.text('Hesap Ayarları'), findsOneWidget);
      expect(find.text('Şifreni değiştir'), findsNothing);
      expect(sessionManager.session.token, api.renewed);
      expect(sessionManager.session.userId, original.userId);
      expect(tokenStore.token, api.renewed);
      expect(api.writes, 2);
      await tester.runAsync(sessionManager.logout);
    },
  );

  testWidgets('active settings route opens push permission controls', (
    tester,
  ) async {
    final push = _SettingsPushCoordinator();
    serviceLocator.registerSingleton<PushCoordinator>(push);
    serviceLocator.registerSingleton<PushDeviceApi>(_SettingsPushDeviceApi());
    await tester.pumpWidget(
      BlocProvider<AuthCubit>.value(
        value: cubit,
        child: MaterialApp(
          onGenerateRoute: AppRouter.onGenerateRoute,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () =>
                    Navigator.of(context).pushNamed(AppRoutes.settings),
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
    await tester.tap(find.byKey(const Key('account-settings-notifications')));
    await tester.pumpAndSettle();
    expect(find.byType(PushSettingsScreen), findsOneWidget);
    expect(find.text('Telefon bildirimleri'), findsOneWidget);
    expect(push.permissionRequests, 0);
    await tester.tap(find.text('Bildirim iznini kontrol et'));
    await tester.pumpAndSettle();
    expect(push.permissionRequests, 1);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('account-settings-username-tile')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

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
        find.byKey(const Key('account-settings-password')),
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
      await tester.runAsync(
        () => sessionManager.startSession(
          token: _jwt(subject: 'musician-user', roles: const ['ROLE_MUSICIAN']),
          username: 'musician',
          accountStatus: 'ACTIVE',
        ),
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
      expect(
        find.byKey(const Key('account-settings-muted-feed-authors')),
        ProfileFeedAvailability.enabled ? findsOneWidget : findsNothing,
      );
      await tester.runAsync(sessionManager.logout);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('account-settings-muted-feed-authors')),
        findsNothing,
      );
    },
  );

  testWidgets(
    'musician settings parks mutes or reloads persisted mutes when enabled',
    (tester) async {
      final muted = _MutedAuthorsRepositoryFake();
      serviceLocator.registerSingleton<MusicianFeedMutedAuthorsRepository>(
        muted,
      );
      serviceLocator.registerSingleton<MusicianProfileRepository>(
        _MusicianProfileRepositoryFake(),
      );
      await tester.runAsync(
        () => sessionManager.startSession(
          token: _jwt(subject: 'musician-user', roles: const ['ROLE_MUSICIAN']),
          username: 'musician',
          accountStatus: 'ACTIVE',
        ),
      );
      await tester.pumpWidget(
        BlocProvider<AuthCubit>.value(
          value: cubit,
          child: MaterialApp(
            onGenerateRoute: AppRouter.onGenerateRoute,
            home: const AccountSettingsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      if (!ProfileFeedAvailability.enabled) {
        expect(
          find.byKey(const Key('account-settings-muted-feed-authors')),
          findsNothing,
        );
        expect(muted.reads, 0);
        expect(muted.unmutes, 0);
        await tester.runAsync(sessionManager.logout);
        return;
      }
      await tester.tap(
        find.byKey(const Key('account-settings-muted-feed-authors')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Persisted Artist'), findsOneWidget);
      expect(muted.reads, 1);
      await tester.tap(find.text('Sessizi kaldır'));
      await tester.pumpAndSettle();
      expect(muted.unmutes, 1);
      expect(find.text('Akışında sessize aldığın hesap yok.'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('account-settings-muted-feed-authors')),
      );
      await tester.pumpAndSettle();
      expect(muted.reads, 2);
      expect(find.text('Persisted Artist'), findsNothing);
      expect(find.text('Akışında sessize aldığın hesap yok.'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.runAsync(sessionManager.logout);
    },
  );

  for (final role in ['VENUE', 'LISTENER']) {
    testWidgets('$role settings follows shared muted authors availability', (
      tester,
    ) async {
      final muted = _MutedAuthorsRepositoryFake();
      serviceLocator.registerSingleton<MusicianFeedMutedAuthorsRepository>(
        muted,
      );
      await tester.runAsync(
        () => sessionManager.startSession(
          token: _jwt(subject: 'profile-user', roles: ['ROLE_$role']),
          username: 'profile',
          accountStatus: 'ACTIVE',
        ),
      );
      await tester.pumpWidget(
        BlocProvider<AuthCubit>.value(
          value: cubit,
          child: MaterialApp(
            onGenerateRoute: AppRouter.onGenerateRoute,
            home: const AccountSettingsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      if (!ProfileFeedAvailability.enabled) {
        expect(
          find.byKey(const Key('account-settings-muted-feed-authors')),
          findsNothing,
        );
        expect(muted.reads, 0);
        expect(muted.unmutes, 0);
        await tester.runAsync(sessionManager.logout);
        return;
      }
      await tester.tap(
        find.byKey(const Key('account-settings-muted-feed-authors')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Persisted Artist'), findsOneWidget);
      expect(muted.reads, 1);
      await tester.tap(find.text('Sessizi kaldır'));
      await tester.pumpAndSettle();
      expect(muted.unmutes, 1);
      expect(find.text('Akışında sessize aldığın hesap yok.'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.runAsync(sessionManager.logout);
    });
  }

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
    expect(
      find.byKey(const Key('account-settings-muted-feed-authors')),
      ProfileFeedAvailability.enabled ? findsOneWidget : findsNothing,
    );
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
    expect(find.byKey(const Key('account-settings-password')), findsOneWidget);
    expect(
      tester
          .widget<ListTile>(find.byKey(const Key('account-settings-password')))
          .onTap,
      isNotNull,
    );
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
    await tester.runAsync(sessionManager.logout);
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

class _PasswordApi extends Fake implements ApiClient {
  _PasswordApi(this.provider);
  final String provider;
  final String renewed = _jwt(
    subject: 'listener-user',
    roles: ['ROLE_LISTENER'],
    version: 1,
  );
  int writes = 0;

  @override
  Future<T> request<T>(
    ApiHttpMethod method,
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    T Function(Object?)? decoder,
    ApiRequestContext? requestContext,
  }) async {
    expect(path, '/api/v1/users/me/password');
    expect(requestContext?.expectedSessionKey, 'listener-user');
    expect(requestContext?.expectedCredentialRevision, isNotNull);
    expect(requestContext?.expectedToken, isNotEmpty);
    if (method == ApiHttpMethod.get) return decoder!({'provider': provider});
    expect(method, ApiHttpMethod.post);
    writes++;
    final request = body as Map;
    expect(request['newPassword'], 'updated-pass');
    if (request['currentPassword'] != 'current-pass') {
      throw ApiException(
        const AppError(code: '1123', message: 'wrong password'),
      );
    }
    return decoder!({'token': renewed});
  }
}

class _PendingDeletionApi extends Fake implements ApiClient {
  int calls = 0;
  final response = Completer<bool>();

  @override
  Future<T> request<T>(
    ApiHttpMethod method,
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    T Function(Object?)? decoder,
    ApiRequestContext? requestContext,
  }) async {
    calls++;
    return decoder!(await response.future);
  }
}

class _MutedAuthorsRepositoryFake
    implements MusicianFeedMutedAuthorsRepository {
  int reads = 0;
  int unmutes = 0;
  bool muted = true;

  @override
  Future<Result<MusicianFeedMutedAuthorsPage>> load({
    int limit = 30,
    String? cursor,
  }) async {
    reads++;
    return Result.success(
      MusicianFeedMutedAuthorsPage(
        items: [
          if (muted)
            MusicianFeedMutedAuthor(
              identity: (
                profileType: 'MUSICIAN',
                profileId: 'persisted-profile',
              ),
              available: true,
              mutedAt: DateTime.utc(2026, 9, 13),
              displayName: 'Persisted Artist',
            ),
        ],
        nextCursor: null,
        hasMore: false,
      ),
    );
  }

  @override
  Future<Result<void>> unmute({
    required String profileType,
    required String profileId,
  }) async {
    expect(profileType, 'MUSICIAN');
    expect(profileId, 'persisted-profile');
    unmutes++;
    muted = false;
    return const Result.success(null);
  }
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

class _SettingsPushCoordinator extends Fake implements PushCoordinator {
  int permissionRequests = 0;
  @override
  bool get enabled => true;
  @override
  PushStatus get status => PushStatus.ready;
  @override
  PushPermission get permission => PushPermission.notDetermined;
  @override
  Future<void> start({Future<AuthSession>? initialSession}) async {}
  @override
  Future<void> requestPermission() async {
    permissionRequests++;
  }

  @override
  void addListener(VoidCallback listener) {}
  @override
  void removeListener(VoidCallback listener) {}
}

class _SettingsPushDeviceApi extends Fake implements PushDeviceApi {
  @override
  Future<PushPreferences> preferences(AuthSession session) async =>
      const PushPreferences(enabled: true);
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

String _jwt({
  required String subject,
  required List<String> roles,
  int version = 0,
}) {
  String encode(Object value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  final expiresAt =
      DateTime.now()
          .toUtc()
          .add(const Duration(hours: 1))
          .millisecondsSinceEpoch ~/
      1000;

  return '${encode(<String, String>{'alg': 'HS256'})}.'
      '${encode(<String, Object>{'sub': subject, 'exp': expiresAt, 'roles': roles, 'sv': version})}.'
      'signature';
}
