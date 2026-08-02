import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:soundconnect_23_12_25codx/app/router/app_routes.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session_manager.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session_store.dart';
import 'package:soundconnect_23_12_25codx/core/error/app_error.dart';
import 'package:soundconnect_23_12_25codx/core/error/result.dart';
import 'package:soundconnect_23_12_25codx/modules/dm/domain/dm_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/dm/presentation/cubit/dm_badge_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/listener_profile.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/listener_profile_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/cubit/listener_profile_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/listener_profile_screen.dart';
import 'package:soundconnect_23_12_25codx/shared/widgets/gradient_outline_button.dart';
import 'package:soundconnect_23_12_25codx/shared/widgets/session_logout_action.dart';

import 'support/auth_widget_test_support.dart';

void main() {
  late MemoryTokenStore tokenStore;
  late MemoryAuthSessionStore sessionStore;

  setUp(() async {
    await GetIt.instance.reset();
    tokenStore = MemoryTokenStore()..token = 'account-a-token';
    sessionStore = MemoryAuthSessionStore()
      ..metadata = const AuthSessionMetadata(
        username: 'account-a',
        accountStatus: 'ACTIVE',
      );
    final manager = createSessionManager(
      tokenStore: tokenStore,
      sessionStore: sessionStore,
    );
    GetIt.instance.registerSingleton<AuthSessionManager>(
      manager,
      dispose: (value) => value.dispose(),
    );
  });

  tearDown(() async {
    await GetIt.instance.reset();
  });

  testWidgets('cancel keeps the current session intact', (tester) async {
    await tester.pumpWidget(_logoutButtonApp());

    await tester.tap(find.byKey(sessionLogoutButtonKey));
    await _openLogoutDialog(tester);
    expect(find.text('Çıkış yapılsın mı?'), findsOneWidget);
    expect(find.text('Çıkış yap'), findsOneWidget);
    expect(
      find.text(
        'Bu cihazdaki SoundConnect oturumun sonlandırılacak. İstediğin zaman tekrar giriş yapabilirsin.',
      ),
      findsOneWidget,
    );
    expect(find.byType(GradientOutlineButton), findsOneWidget);

    await tester.tap(find.text('Vazgeç'));
    await tester.pumpAndSettle();

    expect(tokenStore.token, 'account-a-token');
    expect(tokenStore.clearCalls, 0);
    expect(sessionStore.metadata?.username, 'account-a');
    expect(sessionStore.clearCalls, 0);
  });

  testWidgets('confirmation clears token and session metadata', (tester) async {
    await tester.pumpWidget(_logoutButtonApp());

    await tester.tap(find.byKey(sessionLogoutButtonKey));
    await _openLogoutDialog(tester);
    await tester.tap(find.byKey(sessionLogoutConfirmKey));
    await tester.pumpAndSettle();

    expect(tokenStore.token, isNull);
    expect(tokenStore.clearCalls, 1);
    expect(sessionStore.metadata, isNull);
    expect(sessionStore.clearCalls, 1);
  });

  testWidgets('listener can log out while the profile is loading', (
    tester,
  ) async {
    _registerListenerRepository(_PendingListenerProfileRepository());

    await tester.pumpWidget(MaterialApp(home: ListenerProfileScreen()));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byKey(sessionLogoutButtonKey), findsOneWidget);
  });

  testWidgets('listener can log out when profile loading fails', (
    tester,
  ) async {
    _registerListenerRepository(
      _FixedListenerProfileRepository(
        const Result.failure(
          AppError(code: 'profile_failed', message: 'Profil getirilemedi'),
        ),
      ),
    );

    await tester.pumpWidget(MaterialApp(home: ListenerProfileScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Profil getirilemedi'), findsOneWidget);
    expect(find.byKey(sessionLogoutButtonKey), findsOneWidget);
  });

  testWidgets('listener can log out after the profile loads', (tester) async {
    GetIt.instance.registerSingleton<DmBadgeCubit>(
      DmBadgeCubit(_NoopDmRepository(), tokenStore),
      dispose: (value) => value.close(),
    );
    _registerListenerRepository(
      _FixedListenerProfileRepository(
        const Result.success(
          ListenerProfile(
            id: 'listener-profile-1',
            userId: 'listener-user-1',
            username: 'listener',
            bio: null,
            profilePictureUrl: null,
            followerCount: 0,
            followingCount: 0,
          ),
        ),
      ),
    );

    await tester.pumpWidget(MaterialApp(home: ListenerProfileScreen()));
    await tester.pumpAndSettle();

    expect(find.text('listener'), findsWidgets);
    expect(find.byKey(sessionLogoutButtonKey), findsOneWidget);
  });

  testWidgets('listener reloads its username after returning from settings', (
    tester,
  ) async {
    GetIt.instance.registerSingleton<DmBadgeCubit>(
      DmBadgeCubit(_NoopDmRepository(), tokenStore),
      dispose: (value) => value.close(),
    );
    final repository = _SequenceListenerProfileRepository(
      const ListenerProfile(
        id: 'listener-profile-1',
        userId: 'listener-user-1',
        username: 'old-name',
        bio: null,
        profilePictureUrl: null,
        followerCount: 0,
        followingCount: 0,
      ),
      const ListenerProfile(
        id: 'listener-profile-1',
        userId: 'listener-user-1',
        username: 'new-name',
        bio: null,
        profilePictureUrl: null,
        followerCount: 0,
        followingCount: 0,
      ),
    );
    _registerListenerRepository(repository);

    await tester.pumpWidget(
      MaterialApp(
        routes: <String, WidgetBuilder>{
          AppRoutes.settings: (settingsContext) => Scaffold(
            body: Center(
              child: TextButton(
                key: const Key('return-from-settings'),
                onPressed: () => Navigator.of(settingsContext).pop(),
                child: const Text('Ayarları kapat'),
              ),
            ),
          ),
        },
        home: ListenerProfileScreen(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('old-name'), findsWidgets);

    await tester.tap(find.byKey(const Key('listener-account-settings')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('return-from-settings')));
    await tester.pumpAndSettle();

    expect(repository.calls, 2);
    expect(find.text('new-name'), findsWidgets);
    expect(find.text('old-name'), findsNothing);
  });
}

Widget _logoutButtonApp() {
  return MaterialApp(
    home: Scaffold(appBar: AppBar(actions: const [SessionLogoutIconButton()])),
  );
}

Future<void> _openLogoutDialog(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void _registerListenerRepository(ListenerProfileRepository repository) {
  GetIt.instance.registerFactory<ListenerProfileCubit>(
    () => ListenerProfileCubit(repository),
  );
}

class _PendingListenerProfileRepository implements ListenerProfileRepository {
  final Completer<Result<ListenerProfile>> _completer = Completer();

  @override
  Future<Result<ListenerProfile>> getMyProfile() => _completer.future;

  @override
  Future<Result<ListenerProfile>> updateMyProfile(
    ListenerProfileSaveRequest request,
  ) => _completer.future;
}

class _FixedListenerProfileRepository implements ListenerProfileRepository {
  const _FixedListenerProfileRepository(this.result);

  final Result<ListenerProfile> result;

  @override
  Future<Result<ListenerProfile>> getMyProfile() async => result;

  @override
  Future<Result<ListenerProfile>> updateMyProfile(
    ListenerProfileSaveRequest request,
  ) async => result;
}

class _SequenceListenerProfileRepository implements ListenerProfileRepository {
  _SequenceListenerProfileRepository(this.first, this.next);

  final ListenerProfile first;
  final ListenerProfile next;
  int calls = 0;

  @override
  Future<Result<ListenerProfile>> getMyProfile() async {
    calls += 1;
    return Result.success(calls == 1 ? first : next);
  }

  @override
  Future<Result<ListenerProfile>> updateMyProfile(
    ListenerProfileSaveRequest request,
  ) async => Result.success(next);
}

class _NoopDmRepository implements DmRepository {
  @override
  Future<Result<int>> getUnreadCount() async => const Result.success(0);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
