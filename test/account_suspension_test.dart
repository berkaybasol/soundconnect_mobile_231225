import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/app/app.dart';
import 'package:soundconnect_23_12_25codx/app/router/app_route_guard.dart';
import 'package:soundconnect_23_12_25codx/app/router/app_routes.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session_manager.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session_store.dart';
import 'package:soundconnect_23_12_25codx/core/auth/session_access_monitor.dart';
import 'package:soundconnect_23_12_25codx/core/deep_link/pending_app_deep_link_store.dart';
import 'package:soundconnect_23_12_25codx/core/di/service_locator.dart';
import 'package:soundconnect_23_12_25codx/core/error/app_error.dart';
import 'package:soundconnect_23_12_25codx/core/error/result.dart';
import 'package:soundconnect_23_12_25codx/modules/auth/presentation/screens/account_suspended_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/auth/presentation/cubit/auth_state.dart';
import 'package:soundconnect_23_12_25codx/modules/auth/presentation/screens/login_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/auth/presentation/screens/venue_pending_screen.dart';

import 'support/auth_widget_test_support.dart';

String _jwt(String user) {
  String encode(Object data) =>
      base64Url.encode(utf8.encode(jsonEncode(data))).replaceAll('=', '');
  return '${encode({'alg': 'HS256'})}.${encode({
    'sub': user,
    'roles': ['ROLE_MUSICIAN'],
    'exp': DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000,
  })}.sig';
}

void main() {
  test(
    'guest Google rejection releases login controls for the next account',
    () async {
      final tokens = MemoryTokenStore();
      final manager = AuthSessionManager(
        tokenStore: tokens,
        sessionStore: MemoryAuthSessionStore(),
      );
      final cubit = createAuthCubit(
        RecordingAuthRepository(),
        tokenStore: tokens,
        sessionManager: manager,
      );
      await cubit.authenticate(() async {
        await manager.suspendAccount(
          revision: manager.credentialRevision,
          requestToken: null,
        );
        return const Result.failure(
          AppError(code: AppError.accountSuspended, message: 'Askıda'),
        );
      });
      await manager.dismissSuspension();
      expect(cubit.state.status, isNot(AuthStatus.loading));
      await cubit.close();
      manager.dispose();
    },
  );

  testWidgets(
    'cold offline gate and an idle check replace a covered private route',
    (tester) async {
      setupDependencies();
      await serviceLocator.unregister<AuthSessionManager>();
      final issued = <Completer<void>>[];
      final manager = AuthSessionManager(
        tokenStore: MemoryTokenStore()..token = _jwt('applicant'),
        sessionStore: MemoryAuthSessionStore()
          ..metadata = const AuthSessionMetadata(
            accountStatus: 'PENDING_STUDIO_REQUEST',
          ),
        verifyAccess: (_, _) {
          final response = Completer<void>();
          issued.add(response);
          return response.future;
        },
      );
      serviceLocator.registerSingleton<AuthSessionManager>(manager);
      addTearDown(() async {
        manager.dispose();
        await serviceLocator.reset();
      });
      await tester.pumpWidget(
        SoundConnectApp(
          appDeepLinkInbox: AppDeepLinkInbox(
            store: MemoryPendingAppDeepLinkStore(),
          ),
        ),
      );
      await tester.pump();
      expect(
        find.byType(VenuePendingScreen, skipOffstage: false),
        findsNothing,
      );
      issued.single.completeError(StateError('offline'));
      await tester.pumpAndSettle();
      expect(find.text('Bağlantı kurulamadı'), findsOneWidget);
      expect(find.text('Hesabınız askıya alındı'), findsNothing);
      await tester.tap(find.text('Tekrar dene'));
      issued.last.complete();
      await tester.pumpAndSettle();
      final pending = tester.element(find.byType(VenuePendingScreen));
      Navigator.of(pending).push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('Özel sohbet')),
        ),
      );
      await tester.pumpAndSettle();
      unawaited(
        showDialog<void>(
          context: tester.element(find.text('Özel sohbet')),
          builder: (_) => const AlertDialog(title: Text('Açık menü')),
        ),
      );
      await tester.pumpAndSettle();
      await tester.pump(SessionAccessMonitor.interval);
      expect(issued.length, 3);
      await manager.suspendAccount(
        revision: manager.credentialRevision,
        requestToken: manager.session.token,
      );
      issued.last.complete();
      await tester.pumpAndSettle();
      expect(find.text('Hesabınız askıya alındı'), findsOneWidget);
      expect(find.text('Özel sohbet', skipOffstage: false), findsNothing);
      expect(find.text('Açık menü', skipOffstage: false), findsNothing);
      await tester.tap(find.text('Giriş ekranına dön'));
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(
        find.byType(VenuePendingScreen, skipOffstage: false),
        findsNothing,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'cold, background, retry and idle checks never trust an older reply',
    (tester) async {
      final calls = <Completer<void>>[];
      final manager = AuthSessionManager(
        tokenStore: MemoryTokenStore()..token = _jwt('owner'),
        sessionStore: MemoryAuthSessionStore(),
        verifyAccess: (_, _) {
          final call = Completer<void>();
          calls.add(call);
          return call.future;
        },
      );
      final monitor = SessionAccessMonitor(manager);
      await manager.restore();
      expect(monitor.state, SessionAccessState.checking);
      monitor.onSocketLoss();
      expect(calls, hasLength(1));
      monitor.setForeground(false);
      monitor.setForeground(true);
      expect(calls, hasLength(2));
      calls.first.complete();
      await tester.pump();
      expect(monitor.state, SessionAccessState.checking);
      calls.last.completeError(StateError('offline'));
      await tester.pump();
      expect(monitor.state, SessionAccessState.unavailable);
      unawaited(monitor.check());
      calls.last.complete();
      await tester.pump();
      expect(monitor.state, SessionAccessState.ready);
      await tester.pump(SessionAccessMonitor.interval);
      expect(calls, hasLength(4));
      await manager.suspendAccount(
        revision: manager.credentialRevision,
        requestToken: manager.session.token,
      );
      calls.last.complete();
      await tester.pump();
      expect(manager.session.isSuspendedNotice, isTrue);
      monitor.dispose();
      manager.dispose();
    },
  );

  testWidgets(
    'verified sign-in shows the notice, blocks public links, and permits an explicit fresh login',
    (tester) async {
      final tokens = MemoryTokenStore();
      final manager = AuthSessionManager(
        tokenStore: tokens,
        sessionStore: MemoryAuthSessionStore(),
      );
      final cubit = createAuthCubit(
        RecordingAuthRepository(),
        tokenStore: tokens,
        sessionManager: manager,
      );
      await cubit.authenticate(
        () async =>
            const Result.failure(AppError(code: '1119', message: 'Askıda')),
      );
      expect(manager.session.isSuspendedNotice, isTrue);
      for (final route in [
        AppRoutes.login,
        AppRoutes.bandPublicProfile,
        AppRoutes.collabDiscovery,
        AppRoutes.notifications,
      ]) {
        expect(
          AppRouteGuard.redirectFor(route, manager.session),
          AppRoutes.accountSuspended,
        );
      }
      await manager.logout();
      expect(manager.session.isSuspendedNotice, isTrue);
      await manager.dismissSuspension();
      await manager.startSession(
        token: _jwt('other'),
        username: 'other',
        accountStatus: 'ACTIVE',
      );
      expect(manager.session.userId, 'other');
      await cubit.close();
      manager.dispose();
    },
  );

  testWidgets(
    'restored notice opens both support channels and returns directly to login',
    (tester) async {
      setupDependencies();
      await serviceLocator.unregister<AuthSessionManager>();
      final metadata = MemoryAuthSessionStore()
        ..metadata = const AuthSessionMetadata(accountStatus: 'SUSPENDED');
      final manager = AuthSessionManager(
        tokenStore: MemoryTokenStore(),
        sessionStore: metadata,
      );
      serviceLocator.registerSingleton<AuthSessionManager>(manager);
      const channel = MethodChannel('plugins.flutter.io/url_launcher');
      final urls = <Uri>[];
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channel, (call) async {
        urls.add(Uri.parse(call.arguments['url'] as String));
        return true;
      });
      addTearDown(() async {
        messenger.setMockMethodCallHandler(channel, null);
        manager.dispose();
        await serviceLocator.reset();
      });
      await tester.pumpWidget(
        SoundConnectApp(
          appDeepLinkInbox: AppDeepLinkInbox(
            store: MemoryPendingAppDeepLinkStore(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(AccountSuspendedScreen), findsOneWidget);
      final mail = find.textContaining(
        'Karar hakkında bilgi',
        findRichText: true,
      );
      await tester.ensureVisible(mail.first);
      await tester.tap(mail.first);
      await tester.pump();
      final whatsapp = find.text('WhatsApp ile destek al');
      await tester.ensureVisible(whatsapp);
      await tester.tap(whatsapp);
      await tester.pump();
      expect(urls.first.toString(), 'mailto:destek@soundconnect.com.tr');
      expect(urls.last.host, 'wa.me');
      expect(urls.last.path, '/905378581093');
      expect(urls.last.queryParameters['text'], contains('askıya alınması'));
      await tester.tap(find.text('Giriş ekranına dön'));
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(metadata.metadata, isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
