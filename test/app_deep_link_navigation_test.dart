import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:soundconnect_23_12_25codx/app/app.dart';
import 'package:soundconnect_23_12_25codx/app/router/app_routes.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session_manager.dart';
import 'package:soundconnect_23_12_25codx/core/deep_link/app_deep_link.dart';
import 'package:soundconnect_23_12_25codx/core/deep_link/pending_app_deep_link_store.dart';
import 'package:soundconnect_23_12_25codx/core/di/service_locator.dart';
import 'package:soundconnect_23_12_25codx/core/error/result.dart';
import 'package:soundconnect_23_12_25codx/modules/auth/domain/entities/login_result.dart';
import 'package:soundconnect_23_12_25codx/modules/auth/presentation/cubit/auth_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/auth/presentation/screens/login_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/auth/presentation/screens/register_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/presentation/collab_route_args.dart';
import 'package:soundconnect_23_12_25codx/shared/theme/app_theme_variant.dart';
import 'package:soundconnect_23_12_25codx/shared/theme/theme_controller.dart';

import 'support/auth_widget_test_support.dart';

const _listingId = '550e8400-e29b-41d4-a716-446655440000';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() async {
    await GetIt.instance.reset();
  });

  testWidgets('guest HTTPS link opens login and persists the listing target', (
    tester,
  ) async {
    setupDependencies();
    final source = _FakeAppLinkSource();
    final store = MemoryPendingAppDeepLinkStore();
    final inbox = AppDeepLinkInbox(store: store);

    await tester.pumpWidget(
      SoundConnectApp(
        initialTokenFuture: Future<String?>.value(null),
        themeController: ThemeController.memory(),
        appLinkSource: source,
        appDeepLinkInbox: inbox,
      ),
    );
    await tester.pump();
    source.add(
      Uri.parse('https://soundconnect.com.tr/is-birligi/ilan/$_listingId'),
    );
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(
      find.text(
        'İlan detayını görüntülemek için giriş yap veya ücretsiz üye ol.',
      ),
      findsOneWidget,
    );
    expect((await inbox.pending())?.target.listingId, _listingId);

    ScaffoldMessenger.of(
      tester.element(find.byType(LoginScreen)),
    ).hideCurrentSnackBar();
    await tester.pumpAndSettle();
    final membershipButton = find.widgetWithText(TextButton, 'Üye ol');
    await tester.ensureVisible(membershipButton);
    await tester.pumpAndSettle();
    await tester.tap(membershipButton);
    await tester.pumpAndSettle();

    expect(find.byType(RegisterScreen), findsOneWidget);
    expect((await inbox.pending())?.target.listingId, _listingId);

    await tester.pumpWidget(const SizedBox.shrink());
    await source.close();
  });

  testWidgets('guest pending link survives anonymous popup routes', (
    tester,
  ) async {
    setupDependencies();
    final source = _FakeAppLinkSource();
    final inbox = AppDeepLinkInbox(store: MemoryPendingAppDeepLinkStore());

    await tester.pumpWidget(
      SoundConnectApp(
        initialTokenFuture: Future<String?>.value(null),
        themeController: ThemeController.memory(),
        appLinkSource: source,
        appDeepLinkInbox: inbox,
      ),
    );
    await tester.pump();
    source.add(
      Uri.parse('https://soundconnect.com.tr/is-birligi/ilan/$_listingId'),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'korunmali');

    await tester.tap(find.byType(PopupMenuButton<AppThemeVariant>));
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('korunmali'), findsOneWidget);
    expect((await inbox.pending())?.target.listingId, _listingId);

    await tester.pumpWidget(const SizedBox.shrink());
    await source.close();
  });

  testWidgets('successful login resumes and consumes the pending listing', (
    tester,
  ) async {
    final tokenStore = MemoryTokenStore();
    final sessionManager = AuthSessionManager(
      tokenStore: tokenStore,
      sessionStore: MemoryAuthSessionStore(),
    );
    serviceLocator.registerSingleton<AuthSessionManager>(sessionManager);
    final inbox = AppDeepLinkInbox(store: MemoryPendingAppDeepLinkStore());
    serviceLocator.registerSingleton<AppDeepLinkInbox>(inbox);
    await inbox.record(const AppDeepLinkTarget.listing(listingId: _listingId));
    final cubit = createAuthCubit(
      _SuccessfulLoginRepository(token: _token(role: 'ROLE_MUSICIAN')),
      tokenStore: tokenStore,
      sessionManager: sessionManager,
    );

    await tester.pumpWidget(
      MaterialApp(
        onGenerateRoute: _testRoute,
        home: BlocProvider<AuthCubit>.value(
          value: cubit,
          child: const LoginScreen(),
        ),
      ),
    );
    await cubit.login(username: 'musician', password: 'password123');
    await tester.pumpAndSettle();

    expect(find.text('listing:$_listingId'), findsOneWidget);
    expect(await inbox.pending(), isNull);

    await cubit.close();
    sessionManager.dispose();
  });

  testWidgets(
    'login waits for a busy link claim then performs one fallback handoff',
    (tester) async {
      final tokenStore = MemoryTokenStore();
      final sessionManager = AuthSessionManager(
        tokenStore: tokenStore,
        sessionStore: MemoryAuthSessionStore(),
      );
      addTearDown(sessionManager.dispose);
      serviceLocator.registerSingleton<AuthSessionManager>(sessionManager);
      final inbox = AppDeepLinkInbox(store: MemoryPendingAppDeepLinkStore());
      serviceLocator.registerSingleton<AppDeepLinkInbox>(inbox);
      await inbox.record(
        const AppDeepLinkTarget.listing(listingId: _listingId),
      );
      final externalClaim = await inbox.claim();
      expect(externalClaim.status, AppDeepLinkClaimStatus.acquired);

      final cubit = createAuthCubit(
        _SuccessfulLoginRepository(token: _token(role: 'ROLE_MUSICIAN')),
        tokenStore: tokenStore,
        sessionManager: sessionManager,
      );
      addTearDown(cubit.close);
      final observer = _RecordingNavigatorObserver();
      await tester.pumpWidget(
        MaterialApp(
          navigatorObservers: <NavigatorObserver>[observer],
          onGenerateRoute: _testRoute,
          home: BlocProvider<AuthCubit>.value(
            value: cubit,
            child: const LoginScreen(),
          ),
        ),
      );

      await cubit.login(username: 'musician', password: 'password123');
      await tester.pump();
      await tester.pump();
      expect(find.byType(LoginScreen), findsOneWidget);

      await inbox.complete(externalClaim.link!);
      await tester.pumpAndSettle();

      expect(find.text('home destination'), findsOneWidget);
      expect(
        observer.pushedRouteNames.where((name) => name == AppRoutes.home),
        hasLength(1),
      );
      expect(await inbox.pending(), isNull);
      expect(tester.takeException(), isNull);

      await sessionManager.logout();
    },
  );

  testWidgets('unsupported active role discards the target without a loop', (
    tester,
  ) async {
    final tokenStore = MemoryTokenStore();
    final sessionManager = AuthSessionManager(
      tokenStore: tokenStore,
      sessionStore: MemoryAuthSessionStore(),
    );
    serviceLocator.registerSingleton<AuthSessionManager>(sessionManager);
    final inbox = AppDeepLinkInbox(store: MemoryPendingAppDeepLinkStore());
    serviceLocator.registerSingleton<AppDeepLinkInbox>(inbox);
    await inbox.record(const AppDeepLinkTarget.listing(listingId: _listingId));
    final cubit = createAuthCubit(
      _SuccessfulLoginRepository(token: _token(role: 'ROLE_LISTENER')),
      tokenStore: tokenStore,
      sessionManager: sessionManager,
    );

    await tester.pumpWidget(
      MaterialApp(
        onGenerateRoute: _testRoute,
        home: BlocProvider<AuthCubit>.value(
          value: cubit,
          child: const LoginScreen(),
        ),
      ),
    );
    await cubit.login(username: 'listener', password: 'password123');
    await tester.pumpAndSettle();

    expect(find.text('listener destination'), findsOneWidget);
    expect(find.textContaining('listing:'), findsNothing);
    expect(
      find.text(
        'Bu ilanı müzisyen, mekan veya stüdyo hesabıyla görüntüleyebilirsin.',
      ),
      findsOneWidget,
    );
    expect(await inbox.pending(), isNull);

    await cubit.close();
    sessionManager.dispose();
  });
}

Route<dynamic> _testRoute(RouteSettings settings) {
  if (settings.name == AppRoutes.collabDiscovery) {
    final args = settings.arguments! as CollabDiscoveryRouteArgs;
    return MaterialPageRoute<void>(
      settings: settings,
      builder: (_) => Scaffold(body: Text('listing:${args.initialListingId}')),
    );
  }
  if (settings.name == AppRoutes.listenerProfile) {
    return MaterialPageRoute<void>(
      settings: settings,
      builder: (_) => const Scaffold(body: Text('listener destination')),
    );
  }
  if (settings.name == AppRoutes.home) {
    return MaterialPageRoute<void>(
      settings: settings,
      builder: (_) => const Scaffold(body: Text('home destination')),
    );
  }
  throw StateError('Unexpected route: ${settings.name}');
}

class _FakeAppLinkSource implements AppLinkSource {
  final StreamController<Uri> _controller = StreamController<Uri>.broadcast();

  @override
  Stream<Uri> get uriLinkStream => _controller.stream;

  void add(Uri uri) => _controller.add(uri);

  Future<void> close() => _controller.close();
}

class _RecordingNavigatorObserver extends NavigatorObserver {
  final List<String?> pushedRouteNames = <String?>[];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushedRouteNames.add(route.settings.name);
  }
}

class _SuccessfulLoginRepository extends RecordingAuthRepository {
  _SuccessfulLoginRepository({required this.token});

  final String token;

  @override
  Future<Result<LoginResult>> login({
    required String username,
    required String password,
  }) async => Result<LoginResult>.success(
    LoginResult(token: token, username: username),
  );
}

String _token({required String role}) {
  String encode(Map<String, Object> value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  final expiresAt = DateTime.utc(2035).millisecondsSinceEpoch ~/ 1000;
  return '${encode(const <String, Object>{'alg': 'HS256'})}.'
      '${encode(<String, Object>{
        'sub': 'user-id',
        'roles': <String>[role],
        'exp': expiresAt,
      })}.signature';
}
