import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session_manager.dart';
import 'package:soundconnect_23_12_25codx/core/di/service_locator.dart';
import 'package:soundconnect_23_12_25codx/core/error/app_error.dart';
import 'package:soundconnect_23_12_25codx/core/error/result.dart';
import 'package:soundconnect_23_12_25codx/modules/auth/presentation/cubit/auth_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/auth/presentation/screens/account_settings_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/listener_profile.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/listener_profile_repository.dart';

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

class _ListenerProfileRepositoryFake implements ListenerProfileRepository {
  String? lastDescription;

  ListenerProfile get _profile => ListenerProfile(
    id: 'listener-profile-id',
    userId: 'listener-user',
    username: 'old-name',
    bio: lastDescription ?? 'Eski açıklama',
    profilePictureUrl: null,
    followerCount: 0,
    followingCount: 0,
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
