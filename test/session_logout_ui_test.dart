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
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/listener_visibility_mode.dart';
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

  testWidgets('listener owner never renders a preview identity while loading', (
    tester,
  ) async {
    _registerDmBadgeCubit(tokenStore);
    _registerListenerRepository(_PendingListenerProfileRepository());

    await tester.pumpWidget(MaterialApp(home: ListenerProfileScreen()));
    await tester.pump();

    expect(find.text('berkaybasol'), findsNothing);
    expect(find.text('Çalma Listeleri'), findsNothing);
    expect(find.byKey(const Key('listener-profile-loading')), findsOneWidget);
    await _openListenerMenu(tester);
    expect(find.byKey(sessionLogoutMenuTileKey), findsOneWidget);
  });

  testWidgets('listener owner exposes retry state when loading fails', (
    tester,
  ) async {
    _registerDmBadgeCubit(tokenStore);
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
    expect(find.text('berkaybasol'), findsNothing);
    expect(find.text('Çalma Listeleri'), findsNothing);
    expect(find.byKey(const Key('listener-profile-retry')), findsOneWidget);
    await _openListenerMenu(tester);
    expect(find.byKey(sessionLogoutMenuTileKey), findsOneWidget);
  });

  testWidgets('listener can log out after the profile loads', (tester) async {
    _registerDmBadgeCubit(tokenStore);
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
    expect(find.text('Çalma Listeleri'), findsOneWidget);
    expect(find.text('Çankaya, Ankara'), findsNothing);
    expect(find.byKey(const Key('listener-enable-ghost')), findsNothing);
    await _openListenerMenu(tester);
    expect(find.byKey(sessionLogoutMenuTileKey), findsOneWidget);
  });

  testWidgets('listener reloads its username after returning from settings', (
    tester,
  ) async {
    _registerDmBadgeCubit(tokenStore);
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

    await _openListenerMenu(tester);
    await tester.tap(find.byKey(const Key('listener-account-settings')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('return-from-settings')));
    await tester.pumpAndSettle();

    expect(repository.calls, 2);
    expect(find.text('new-name'), findsWidgets);
    expect(find.text('old-name'), findsNothing);
  });

  testWidgets('listener standard mode confirmation uses premium dialog', (
    tester,
  ) async {
    _registerDmBadgeCubit(tokenStore);
    final repository = _VisibilityListenerProfileRepository();
    _registerListenerRepository(repository);

    await tester.pumpWidget(const MaterialApp(home: ListenerProfileScreen()));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Sosyal Profile Dön'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sosyal Profile Dön'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('listener-standard-mode-dialog')),
      findsOneWidget,
    );
    expect(find.byType(AlertDialog), findsNothing);
    expect(
      find.byKey(const Key('listener-standard-mode-dialog-icon')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('listener-standard-mode-restore-notice')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('listener-standard-mode-dialog')),
        matching: find.byType(GradientOutlineButton),
      ),
      findsOneWidget,
    );
    expect(find.text('GÖRÜNÜRLÜK TERCİHİ'), findsOneWidget);
    expect(find.text('Sosyal profile dönülsün mü?'), findsOneWidget);
    expect(
      find.text('Daha önce kaldırılan takipçiler geri yüklenmez.'),
      findsOneWidget,
    );
    expect(
      tester
          .getSize(find.byKey(const Key('listener-cancel-disable-ghost')))
          .height,
      greaterThanOrEqualTo(48),
    );
    expect(
      tester
          .getSize(find.byKey(const Key('listener-confirm-disable-ghost')))
          .height,
      greaterThanOrEqualTo(48),
    );

    await tester.tap(find.byKey(const Key('listener-cancel-disable-ghost')));
    await tester.pumpAndSettle();
    expect(repository.visibilityUpdateCalls, 0);

    await tester.tap(find.text('Sosyal Profile Dön'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('listener-confirm-disable-ghost')));
    await tester.pumpAndSettle();

    expect(repository.visibilityUpdateCalls, 1);
    expect(
      repository.lastVisibilityRequest?.visibilityMode,
      ListenerVisibilityMode.standard,
    );
  });

  testWidgets('premium standard mode dialog fits narrow large-text screens', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    _registerDmBadgeCubit(tokenStore);
    _registerListenerRepository(_VisibilityListenerProfileRepository());

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: const ListenerProfileScreen(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Sosyal Profile Dön'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sosyal Profile Dön'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('listener-standard-mode-dialog')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(
      find.byKey(const Key('listener-confirm-disable-ghost')),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(
      tester
          .getSize(find.byKey(const Key('listener-confirm-disable-ghost')))
          .height,
      greaterThanOrEqualTo(48),
    );
  });
}

void _registerDmBadgeCubit(MemoryTokenStore tokenStore) {
  GetIt.instance.registerSingleton<DmBadgeCubit>(
    DmBadgeCubit(_NoopDmRepository(), tokenStore),
    dispose: (value) => value.close(),
  );
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

Future<void> _openListenerMenu(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('listener-owner-menu')));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void _registerListenerRepository(ListenerProfileRepository repository) {
  GetIt.instance.registerFactory<ListenerProfileCubit>(
    () => ListenerProfileCubit(repository),
  );
}

class _PendingListenerProfileRepository extends ListenerProfileRepository {
  final Completer<Result<ListenerProfile>> _completer = Completer();

  @override
  Future<Result<ListenerProfile>> getMyProfile() => _completer.future;

  @override
  Future<Result<ListenerProfile>> updateMyProfile(
    ListenerProfileSaveRequest request,
  ) => _completer.future;
}

class _FixedListenerProfileRepository extends ListenerProfileRepository {
  const _FixedListenerProfileRepository(this.result);

  final Result<ListenerProfile> result;

  @override
  Future<Result<ListenerProfile>> getMyProfile() async => result;

  @override
  Future<Result<ListenerProfile>> updateMyProfile(
    ListenerProfileSaveRequest request,
  ) async => result;
}

class _SequenceListenerProfileRepository extends ListenerProfileRepository {
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

class _VisibilityListenerProfileRepository extends ListenerProfileRepository {
  ListenerProfile profile = const ListenerProfile(
    id: 'listener-profile-ghost',
    userId: 'listener-user-ghost',
    username: 'listener',
    bio: null,
    profilePictureUrl: null,
    followerCount: null,
    followingCount: null,
    visibilityMode: ListenerVisibilityMode.ghost,
    version: 3,
  );
  int visibilityUpdateCalls = 0;
  ListenerVisibilityUpdateRequest? lastVisibilityRequest;

  @override
  Future<Result<ListenerProfile>> getMyProfile() async =>
      Result.success(profile);

  @override
  Future<Result<ListenerProfile>> updateVisibility(
    ListenerVisibilityUpdateRequest request,
  ) async {
    visibilityUpdateCalls += 1;
    lastVisibilityRequest = request;
    profile = const ListenerProfile(
      id: 'listener-profile-ghost',
      userId: 'listener-user-ghost',
      username: 'listener',
      bio: null,
      profilePictureUrl: null,
      followerCount: 0,
      followingCount: 0,
      visibilityMode: ListenerVisibilityMode.standard,
      version: 4,
    );
    return Result.success(profile);
  }
}

class _NoopDmRepository implements DmRepository {
  @override
  Future<Result<int>> getUnreadCount() async => const Result.success(0);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
