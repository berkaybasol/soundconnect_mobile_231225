import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:soundconnect_23_12_25codx/app/router/app_routes.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session_manager.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session_store.dart';
import 'package:soundconnect_23_12_25codx/modules/auth/presentation/screens/venue_pending_screen.dart';

import 'support/auth_widget_test_support.dart';

void main() {
  const launcherChannel = MethodChannel('plugins.flutter.io/url_launcher');
  late MemoryTokenStore tokenStore;
  late MemoryAuthSessionStore sessionStore;

  setUp(() async {
    await GetIt.instance.reset();
    tokenStore = MemoryTokenStore()..token = 'test-token';
    sessionStore = MemoryAuthSessionStore()
      ..metadata = const AuthSessionMetadata(
        username: 'venue-owner',
        accountStatus: 'PENDING_VENUE_REQUEST',
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
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(launcherChannel, null);
    await GetIt.instance.reset();
  });

  Widget app() {
    return MaterialApp(
      routes: <String, WidgetBuilder>{
        AppRoutes.login: (_) => const Scaffold(body: Text('login-target')),
      },
      home: VenuePendingScreen(),
    );
  }

  testWidgets('renders pending guidance and support actions', (tester) async {
    _useLargeSurface(tester);
    await tester.pumpWidget(app());

    expect(find.byIcon(Icons.verified_outlined), findsOneWidget);
    expect(
      find.textContaining('destek@soundconnect.com.tr', findRichText: true),
      findsOneWidget,
    );
    expect(find.byType(InkWell), findsNWidgets(2));
  });

  testWidgets(
    'WhatsApp action is channel-isolated and reports launch failure',
    (tester) async {
      _useLargeSurface(tester);
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(launcherChannel, (call) async {
            calls.add(call);
            return false;
          });
      await tester.pumpWidget(app());

      await tester.tap(find.byType(InkWell).first);
      await tester.pump();
      await tester.pump();

      expect(calls, hasLength(1));
      expect(calls.single.method, 'launch');
      final arguments = calls.single.arguments as Map<Object?, Object?>;
      expect(arguments['url'].toString(), contains('wa.me'));
      expect(find.byType(SnackBar), findsOneWidget);
    },
  );

  testWidgets('login action clears the session and removes pending route', (
    tester,
  ) async {
    _useLargeSurface(tester);
    await tester.pumpWidget(app());

    await tester.tap(find.byType(InkWell).last);
    await tester.pumpAndSettle();

    expect(tokenStore.token, isNull);
    expect(tokenStore.clearCalls, 1);
    expect(sessionStore.metadata, isNull);
    expect(sessionStore.clearCalls, 1);
    expect(find.text('login-target'), findsOneWidget);
  });
}

void _useLargeSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(500, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}
