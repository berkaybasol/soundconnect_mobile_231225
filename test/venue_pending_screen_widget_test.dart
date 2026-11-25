import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:soundconnect_23_12_25codx/app/router/app_routes.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session_manager.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session_store.dart';
import 'package:soundconnect_23_12_25codx/core/error/studio_rejection_error.dart';
import 'package:soundconnect_23_12_25codx/modules/auth/presentation/screens/venue_pending_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/auth/presentation/widgets/membership_pending_view.dart';
import 'package:soundconnect_23_12_25codx/shared/theme/app_colors.dart';

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
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(launcherChannel, null);
    await GetIt.instance.reset();
  });

  Widget app({
    PendingMembershipType membershipType = PendingMembershipType.venue,
    StudioRejectionError? studioDecision,
  }) {
    // Create async credential queues inside the widget's FakeAsync zone.
    final manager = createSessionManager(
      tokenStore: tokenStore,
      sessionStore: sessionStore,
    );
    GetIt.instance.registerSingleton<AuthSessionManager>(
      manager,
      dispose: (value) => value.dispose(),
    );
    return MaterialApp(
      routes: <String, WidgetBuilder>{
        AppRoutes.login: (_) => const Scaffold(body: Text('login-target')),
      },
      home: VenuePendingScreen(
        membershipType: membershipType,
        studioDecision: studioDecision,
      ),
    );
  }

  for (final type in [
    PendingMembershipType.venue,
    PendingMembershipType.studio,
  ]) {
    testWidgets(
      '${type.name} renders shared pending guidance and support actions',
      (tester) async {
        _useLargeSurface(tester);
        await tester.pumpWidget(app(membershipType: type));

        expect(find.byType(MembershipPendingView), findsOneWidget);
        expect(find.text('Hesabın inceleniyor...'), findsOneWidget);
        final membership = type == PendingMembershipType.studio
            ? 'Stüdyo'
            : 'Mekan';
        expect(find.textContaining('$membership üyeliğini'), findsOneWidget);
        expect(find.byIcon(Icons.verified_outlined), findsOneWidget);
        expect(
          find.textContaining('destek@soundconnect.com.tr', findRichText: true),
          findsOneWidget,
        );
        expect(find.byType(InkWell), findsNWidgets(2));
      },
    );
  }

  testWidgets(
    'support has a full-size tap target and readable light-theme text',
    (tester) async {
      _useLargeSurface(tester);
      await tester.pumpWidget(app());

      expect(
        tester.getSize(find.byType(InkWell).first).height,
        greaterThanOrEqualTo(kMinInteractiveDimension),
      );
      final support = tester.widget<Text>(
        find.byWidgetPredicate(
          (widget) =>
              widget is Text &&
              widget.textSpan?.toPlainText().contains('destek@') == true,
        ),
      );
      final email = (support.textSpan! as TextSpan).children!.first as TextSpan;
      final ink = email.style!.color!.computeLuminance();
      final surface = AppColors.lightPalette.navBlueSoft.computeLuminance();
      expect((surface + 0.05) / (ink + 0.05), greaterThanOrEqualTo(4.5));
    },
  );

  testWidgets(
    'long decision can be read, supported and dismissed with large text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2.5;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final reason = List.filled(
        10,
        'Başvurudaki bina ve kapı numarası doğrulanamadı.',
      ).join(' ');
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(launcherChannel, (call) async {
            calls.add(call);
            return true;
          });
      await tester.pumpWidget(
        app(
          membershipType: PendingMembershipType.studioRejected,
          studioDecision: StudioRejectionError(
            code: 'auth_studio_application_rejected',
            businessName: 'Kovan Stüdyo',
            rejectionReason: reason,
          ),
        ),
      );
      await tester.scrollUntilVisible(find.text(reason), 150);
      final email = find.text('destek@soundconnect.com.tr');
      await tester.scrollUntilVisible(email.hitTestable(), 120);
      await tester.pumpAndSettle();
      await tester.tap(email);
      await tester.pump();
      expect(
        calls.single.arguments['url'],
        'mailto:destek@soundconnect.com.tr',
      );
      final back = find.text('Giriş ekranına dön');
      expect(back.hitTestable(), findsOneWidget);
      await tester.tap(back);
      await tester.pumpAndSettle();
      expect(find.text('login-target'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('return action grows with large text on a narrow phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(app());

    final leave = find.text('Giriş ekranına dön');
    await tester.ensureVisible(leave);
    expect(tester.getSize(find.byType(InkWell).last).height, greaterThan(52));
    await tester.tap(leave);
    await tester.pumpAndSettle();
    expect(find.text('login-target'), findsOneWidget);
    expect(tester.takeException(), isNull);
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

  testWidgets('WhatsApp platform errors show the existing failure message', (
    tester,
  ) async {
    _useLargeSurface(tester);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(launcherChannel, (_) async {
          throw PlatformException(code: 'launcher-unavailable');
        });
    await tester.pumpWidget(app());
    await tester.tap(find.byType(InkWell).first);
    await tester.pumpAndSettle();

    expect(find.text('WhatsApp bağlantısı açılamadı.'), findsOneWidget);
    expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final thrown in [false, true]) {
    for (final disposed in [false, true]) {
      testWidgets(
        'late WhatsApp ${thrown ? 'error' : 'false'} is ignored after ${disposed ? 'dispose' : 'covering route'}',
        (tester) async {
          _useLargeSurface(tester);
          final response = Completer<bool>();
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .setMockMethodCallHandler(
                launcherChannel,
                (_) => response.future,
              );
          await tester.pumpWidget(app());
          final navigator = Navigator.of(
            tester.element(find.byType(VenuePendingScreen)),
          );
          await tester.tap(find.byType(InkWell).first);
          await tester.pump();

          if (disposed) {
            await tester.pumpWidget(const MaterialApp(home: Scaffold()));
          } else {
            unawaited(
              navigator.push<void>(
                MaterialPageRoute<void>(
                  builder: (_) => const Scaffold(body: Text('another-screen')),
                ),
              ),
            );
          }
          await tester.pumpAndSettle();
          if (thrown) {
            response.completeError(
              PlatformException(code: 'launcher-unavailable'),
            );
          } else {
            response.complete(false);
          }
          await tester.pumpAndSettle();

          expect(find.byType(SnackBar), findsNothing);
          expect(tester.takeException(), isNull);
          if (!disposed) {
            expect(find.text('another-screen'), findsOneWidget);
          }
        },
      );
    }
  }
}

void _useLargeSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(500, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}
