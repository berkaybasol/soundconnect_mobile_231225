import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/app/app.dart';
import 'package:soundconnect_23_12_25codx/app/backstage_home_screen.dart';
import 'package:soundconnect_23_12_25codx/app/router/app_route_guard.dart';
import 'package:soundconnect_23_12_25codx/app/router/app_routes.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session_manager.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session_store.dart';
import 'package:soundconnect_23_12_25codx/core/auth/token_store.dart';
import 'package:soundconnect_23_12_25codx/core/deep_link/app_deep_link.dart';
import 'package:soundconnect_23_12_25codx/core/deep_link/pending_app_deep_link_store.dart';
import 'package:soundconnect_23_12_25codx/core/di/service_locator.dart';
import 'package:soundconnect_23_12_25codx/core/network/api_client.dart';
import 'package:soundconnect_23_12_25codx/core/push/push_coordinator.dart';
import 'package:soundconnect_23_12_25codx/core/push/push_device_api.dart';
import 'package:soundconnect_23_12_25codx/core/push/push_delivery_api.dart';
import 'package:soundconnect_23_12_25codx/core/push/push_installation_store.dart';
import 'package:soundconnect_23_12_25codx/core/push/push_provider.dart';
import 'package:soundconnect_23_12_25codx/modules/auth/presentation/screens/venue_application_decision_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/dm/presentation/cubit/dm_badge_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/dm/presentation/cubit/dm_badge_state.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/domain/entities/app_notification.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/presentation/cubit/notification_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/presentation/cubit/notification_state.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/presentation/screens/notification_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/profile_media_upload_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/venue_profile_screen.dart';
import 'support/auth_widget_test_support.dart';
import 'venue_application_session_test.dart'
    show applicantToken, applicantId, applicationId;

const _nid = 'cccccccc-cccc-4ccc-8ccc-cccccccccccc';
const _other = 'dddddddd-dddd-4ddd-8ddd-dddddddddddd';
const _venue = 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee';
const _base = '/api/v1/venue-application-session/applications/$applicationId';
PushTarget _target(String decision) => PushTarget(
  notificationId: _nid,
  recipientId: applicantId,
  type: 'VENUE_APPLICATION_$decision',
);

String _normalToken(String userId) =>
    'header.${base64Url.encode(utf8.encode(jsonEncode({
      'sub': userId,
      'roles': ['ROLE_VENUE'],
      'exp': DateTime.now().add(const Duration(days: 1)).millisecondsSinceEpoch ~/ 1000,
    })))}.signature';

void main() {
  late _Fixture f;
  setUp(() async {
    await serviceLocator.reset();
    f = _Fixture();
  });
  tearDown(() async {
    await f.close();
    await serviceLocator.reset();
  });

  for (final decision in ['APPROVED', 'REJECTED']) {
    testWidgets(
      'actual App external $decision uses own current application and one ACK only',
      (tester) async {
        f.api.decision = decision;
        f.api.failPromotion = true;
        f.provider.initial = _target(decision);
        await f.mount(tester);
        expect(
          find.text(
            decision == 'APPROVED'
                ? 'Mekân başvurun onaylandı.'
                : 'Mekân başvurun reddedildi.',
          ),
          findsOneWidget,
        );
        expect(find.text('Current owned venue'), findsOneWidget);
        expect(f.api.readIds, [_nid]);
        expect(f.api.unread, {_other});
        expect(
          f.api.contexts.every(
            (c) =>
                c.expectedSessionKey == applicantId &&
                c.expectedToken == f.sessions.session.token,
          ),
          isTrue,
        );
        expect(f.api.calls.every((p) => p.startsWith(_base)), isTrue);
        expect(f.notifications.starts, 0);
        expect(f.dm.starts, 0);
        expect(find.byType(NotificationScreen), findsNothing);
        expect(
          f.api.registrations.single['presentationVersion'],
          'ANDROID_NATIVE_V11',
        );
        expect(f.api.sawDecisionAtAck, isTrue);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets(
    'pending restore enrolls narrowly and foreground decision refresh never starts general services',
    (tester) async {
      f.api.decision = 'PENDING';
      await f.mount(tester);
      expect(find.text('Mekân başvurun inceleniyor.'), findsOneWidget);
      expect(f.api.registrations, hasLength(1));
      expect(
        AppRouteGuard.redirectFor(
          AppRoutes.dmConversations,
          f.sessions.session,
        ),
        AppRoutes.venuePending,
      );
      expect(
        AppRouteGuard.redirectFor(
          AppRoutes.venuePublicProfile,
          f.sessions.session,
        ),
        AppRoutes.venuePending,
      );
      f.api.decision = 'REJECTED';
      f.provider.messages.add(_target('REJECTED'));
      await tester.pumpAndSettle();
      expect(find.text('Mekân başvurun reddedildi.'), findsOneWidget);
      expect(find.text('WhatsApp ile destek al'), findsOneWidget);
      expect(
        f.api.readIds,
        isEmpty,
      ); // A foreground refresh is not a notification tap.
      expect(f.notifications.starts, 0);
      expect(f.dm.starts, 0);
      expect(f.api.calls.every((p) => p.startsWith(_base)), isTrue);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('limited session refuses DM and old venue external targets', (
    tester,
  ) async {
    await f.mount(tester);
    final before = f.api.calls.length;
    for (final type in [
      'DM_NEW_MESSAGE',
      'ARTIST_VENUE_LINK_APPLICATION_REQUEST',
    ]) {
      f.provider.opens.add(
        PushTarget(
          notificationId: _other,
          recipientId: applicantId,
          type: type,
          conversationId: type == 'DM_NEW_MESSAGE' ? _venue : null,
        ),
      );
      await tester.pumpAndSettle();
    }
    expect(f.api.calls.length, before);
    expect(f.push.pending, isNull);
    expect(find.byType(NotificationScreen), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'signed approval automatically opens the own profile after exact ACK',
    (tester) async {
      f.api.decision = 'APPROVED';
      f.provider.initial = _target('APPROVED');
      await f.mount(tester);
      expect(f.api.promotions, 1);
      expect(f.sessions.session.isActive, isTrue);
      expect(f.sessions.session.roles, ['ROLE_VENUE']);
      expect(f.sessions.session.isVenueApplicationSession, isFalse);
      expect(find.byType(VenueApplicationDecisionScreen), findsNothing);
      expect(find.byType(VenueProfileScreen), findsOneWidget);
      expect(find.byType(BackstageHomeScreen), findsNothing);
      expect(
        find.text('Mekân başvurun onaylandı. Profilin hazır!'),
        findsOneWidget,
      );
      expect(f.api.sawDecisionAtAck, isTrue);
      expect(f.api.unread, {_other});
      expect(f.notifications.starts, greaterThan(0));
      expect(f.api.readIds, [_nid]);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  for (final nativeTarget in [true, false]) {
    testWidgets(
      'own promotion preserves approved presentation in every transition frame native=$nativeTarget',
      (tester) async {
        f.api.decision = 'APPROVED';
        f.api.promoteGate = Completer<void>();
        if (nativeTarget) f.provider.initial = _target('APPROVED');
        await f.mount(tester);
        expect(f.api.promotions, 1);
        expect(find.text('Current owned venue'), findsOneWidget);
        expect(f.api.readIds, nativeTarget ? [_nid] : isEmpty);
        final revision = f.sessions.credentialRevision;
        f.api.promoteGate!.complete();
        var sawHandoffFrame = false;
        var reachedProfile = false;
        for (var frame = 0; frame < 40; frame++) {
          await tester.pump(const Duration(milliseconds: 16));
          final decision = find.byType(VenueApplicationDecisionScreen);
          final profile = find.byType(VenueProfileScreen);
          final error = find.text('Oturum değişti. Başvurunu yeniden aç.');
          debugPrint(
            'promotion-frame native=$nativeTarget frame=$frame '
            'decision=${decision.evaluate().isNotEmpty} '
            'profile=${profile.evaluate().isNotEmpty} '
            'sessionError=${error.evaluate().isNotEmpty}',
          );
          expect(error, findsNothing, reason: 'false error in frame $frame');
          expect(find.text('Tekrar dene'), findsNothing);
          if (decision.evaluate().isNotEmpty && profile.evaluate().isEmpty) {
            expect(find.text('Current owned venue'), findsOneWidget);
            expect(find.text('Mekân başvurun onaylandı.'), findsOneWidget);
            expect(find.text('Profilin açılıyor…'), findsOneWidget);
            expect(
              tester
                  .widget<TextButton>(
                    find.widgetWithText(TextButton, 'Çıkış yap'),
                  )
                  .onPressed,
              isNull,
            );
            sawHandoffFrame |= !f.sessions.session.isVenueApplicationSession;
          }
          if (profile.evaluate().isNotEmpty) {
            reachedProfile = true;
            break;
          }
        }
        expect(sawHandoffFrame, isTrue);
        expect(reachedProfile, isTrue);
        expect(f.sessions.credentialRevision, revision);
        expect(f.api.promotions, 1);
        expect(f.api.readIds, nativeTarget ? [_nid] : isEmpty);
        expect(f.api.unread, nativeTarget ? {_other} : {_nid, _other});
        await tester.pumpAndSettle();
        expect(
          find.text('Mekân başvurun onaylandı. Profilin hazır!'),
          findsOneWidget,
        );
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  for (final replacement in ['logout', 'other-user', 'same-user-login']) {
    testWidgets(
      'in-flight approval clears private detail immediately for $replacement',
      (tester) async {
        f.api.decision = 'APPROVED';
        f.api.promoteGate = Completer<void>();
        await f.mountDecision(tester);
        expect(find.text('Current owned venue'), findsOneWidget);
        final revision = f.sessions.credentialRevision;
        if (replacement == 'logout') {
          await f.sessions.logout();
        } else {
          await f.sessions.startSession(
            token: _normalToken(
              replacement == 'other-user' ? _other : applicantId,
            ),
            username: 'replacement',
            accountStatus: 'ACTIVE',
          );
        }
        final replacementSession = f.sessions.session;
        expect(f.sessions.credentialRevision, greaterThan(revision));
        await tester.pump();
        expect(find.text('Current owned venue'), findsNothing);
        expect(find.text('Mekân başvurun onaylandı.'), findsNothing);
        f.api.promoteGate!.complete();
        await tester.pumpAndSettle();
        expect(identical(f.sessions.session, replacementSession), isTrue);
        expect(find.text('Current owned venue'), findsNothing);
        expect(
          find.text('Mekân başvurun onaylandı. Profilin hazır!'),
          findsNothing,
        );
        expect(f.api.readIds, isEmpty);
        expect(f.api.promotions, 1);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  for (final replacement in [
    'logout',
    'other-user',
    'same-user-login',
    'same-revision-object',
  ]) {
    testWidgets(
      'accepted promotion presentation clears on subsequent $replacement',
      (tester) async {
        f.api.decision = 'APPROVED';
        f.api.promoteGate = Completer<void>();
        // Keep this real screen mounted after the real manager commits, so a
        // subsequent replacement is tested before any app route disposal.
        await f.mountDecision(tester);
        f.api.promoteGate!.complete();
        await tester.pump();
        expect(f.sessions.session.isActive, isTrue);
        expect(find.text('Current owned venue'), findsOneWidget);
        expect(
          find.text('Oturum değişti. Başvurunu yeniden aç.'),
          findsNothing,
        );
        final successor = f.sessions.session;
        final revision = f.sessions.credentialRevision;
        if (replacement == 'logout') {
          await f.sessions.logout();
        } else if (replacement == 'same-revision-object') {
          await f.sessions.updateUsername('updated');
          expect(f.sessions.credentialRevision, revision);
        } else {
          await f.sessions.startSession(
            token: _normalToken(
              replacement == 'other-user' ? _other : applicantId,
            ),
            username: 'replacement',
            accountStatus: 'ACTIVE',
          );
        }
        expect(identical(f.sessions.session, successor), isFalse);
        await tester.pump();
        expect(find.text('Current owned venue'), findsNothing);
        expect(find.text('Mekân başvurun onaylandı.'), findsNothing);
        expect(
          find.text('Oturum değişti. Başvurunu yeniden aç.'),
          findsOneWidget,
        );
        expect(f.api.promotions, 1);
        expect(f.api.readIds, isEmpty);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  for (final defect in ['application', 'recipient', 'status', 'source']) {
    testWidgets('mismatched current $defect never presents decision or ACKs', (
      tester,
    ) async {
      f.api.defect = defect;
      f.provider.initial = _target('REJECTED');
      await f.mount(tester);
      expect(find.text('Mekân başvurun reddedildi.'), findsNothing);
      expect(find.text('Tekrar dene'), findsOneWidget);
      expect(f.api.readIds, isEmpty);
      expect(f.api.unread, {_nid, _other});
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets(
    'offline exact lookup retries in place without broad inbox fallback',
    (tester) async {
      f.api.failLookup = true;
      f.provider.initial = _target('REJECTED');
      await f.mount(tester);
      expect(find.text('Tekrar dene'), findsOneWidget);
      expect(f.api.readIds, isEmpty);
      f.api.failLookup = false;
      await tester.tap(find.text('Tekrar dene'));
      await tester.pumpAndSettle();
      expect(f.api.readIds, [_nid]);
      expect(find.byType(NotificationScreen), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'background application response waits for a resumed visible decision before ACK',
    (tester) async {
      f.api.detailGate = Completer<void>();
      f.provider.initial = _target('REJECTED');
      await f.mount(tester, settle: false);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      f.api.detailGate!.complete();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(f.api.readIds, isEmpty);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(f.api.readIds, [_nid]);
      expect(f.notifications.starts, 0);
      expect(f.dm.starts, 0);
      expect(f.api.registrations.length, greaterThanOrEqualTo(2));
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'covered ACK cannot navigate until return and never repeats the ACK',
    (tester) async {
      f.api.decision = 'APPROVED';
      f.api.ackGate = Completer<void>();
      f.provider.initial = _target('APPROVED');
      await f.mount(tester);
      final navigator = Navigator.of(
        tester.element(find.text('Mekân başvurun onaylandı.')),
      );
      unawaited(
        navigator.push(
          MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Text('covered')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      f.api.ackGate!.complete();
      await tester.pumpAndSettle();
      expect(f.api.promotions, 0);
      expect(f.sessions.session.isVenueApplicationSession, isTrue);
      navigator.pop();
      await tester.pumpAndSettle();
      expect(find.byType(VenueProfileScreen), findsOneWidget);
      expect(f.api.promotions, 1);
      expect(f.api.readIds, [_nid]);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'slow native lookup retains the exact scoped target before promotion',
    (tester) async {
      f.api.decision = 'APPROVED';
      f.provider.initial = _target('APPROVED');
      f.provider.initialGate = Completer<void>();
      await f.mount(tester);
      expect(f.api.promotions, 0);
      expect(f.api.readIds, isEmpty);
      f.provider.initialGate!.complete();
      await tester.pumpAndSettle();
      expect(f.api.promotions, 1);
      expect(f.api.readIds, [_nid]);
      expect(f.api.unread, {_other});
      expect(find.byType(VenueProfileScreen), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('approved restore opens own profile without fabricating a read', (
    tester,
  ) async {
    f.api.decision = 'APPROVED';
    await f.mount(tester);
    expect(find.byType(VenueProfileScreen), findsOneWidget);
    expect(f.api.promotions, 1);
    expect(f.api.readIds, isEmpty);
    expect(f.api.unread, {_nid, _other});
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('failed promotion waits for explicit retry across resume', (
    tester,
  ) async {
    f.api.decision = 'APPROVED';
    f.api.failPromotion = true;
    f.provider.initial = _target('APPROVED');
    await f.mount(tester);
    expect(f.api.promotions, 1);
    expect(f.sessions.session.isVenueApplicationSession, isTrue);
    expect(find.text('Profilimi açmayı tekrar dene'), findsOneWidget);
    f.api.failLookup = true;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(f.api.promotions, 1);
    f.api.failPromotion = false;
    f.api.failLookup = false;
    await tester.tap(find.text('Profilimi açmayı tekrar dene'));
    await tester.pumpAndSettle();
    expect(f.api.promotions, 2);
    expect(f.api.readIds, [_nid]);
    expect(find.byType(VenueProfileScreen), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('failed ACK keeps restricted session until deliberate retry', (
    tester,
  ) async {
    f.api.decision = 'APPROVED';
    f.api.failAck = true;
    f.provider.initial = _target('APPROVED');
    await f.mount(tester);
    expect(f.api.promotions, 0);
    expect(f.api.ackAttempts, 1);
    expect(f.api.unread, {_nid, _other});
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(f.api.ackAttempts, 1);
    f.api.failAck = false;
    await tester.tap(find.text('Okundu bilgisini yeniden gönder'));
    await tester.pumpAndSettle();
    expect(f.api.ackAttempts, 2);
    expect(f.api.promotions, 1);
    expect(f.api.readIds, [_nid]);
    expect(f.api.unread, {_other});
    expect(find.byType(VenueProfileScreen), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'late signed promotion after logout never resurrects the account',
    (tester) async {
      f.api.decision = 'APPROVED';
      f.api.promoteGate = Completer<void>();
      await f.mount(tester);
      expect(f.api.promotions, 1);
      await f.sessions.logout();
      f.api.promoteGate!.complete();
      await tester.pumpAndSettle();
      expect(f.sessions.session.isAuthenticated, isFalse);
      expect(find.byType(VenueProfileScreen), findsNothing);
      expect(
        find.text('Mekân başvurun onaylandı. Profilin hazır!'),
        findsNothing,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('approved payload alone cannot promote a pending application', (
    tester,
  ) async {
    f.api.decision = 'APPROVED';
    f.api.defect = 'status';
    f.provider.initial = _target('APPROVED');
    await f.mount(tester);
    expect(f.api.promotions, 0);
    expect(f.api.readIds, isEmpty);
    expect(find.byType(VenueProfileScreen), findsNothing);
    expect(f.sessions.session.isVenueApplicationSession, isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'late application reply after logout cannot reveal or ACK old decision',
    (tester) async {
      f.api.detailGate = Completer<void>();
      f.provider.initial = _target('REJECTED');
      await f.mount(tester, settle: false);
      await f.sessions.logout();
      f.api.detailGate!.complete();
      await tester.pumpAndSettle();
      expect(find.text('Current owned venue'), findsNothing);
      expect(f.api.readIds, isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'already presented detail disappears immediately on session replacement',
    (tester) async {
      await f.mount(tester);
      expect(find.text('Current owned venue'), findsOneWidget);
      await f.sessions.logout();
      await tester.pump();
      expect(find.text('Current owned venue'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}

class _Fixture {
  final tokens = MemoryTokenStore();
  final metadata = MemoryAuthSessionStore();
  late final sessions = AuthSessionManager(
    tokenStore: tokens,
    sessionStore: metadata,
    expiryTimerFactory: (_, _) => _NoTimer(),
  );
  late final api = _Api(sessions);
  final provider = _Provider();
  final store = _Store();
  final notifications = _Notifications();
  final dm = _Dm();
  late final push = PushCoordinator(
    sessions: sessions,
    provider: provider,
    api: _Devices(api),
    store: store,
    deliveryApi: HttpPushDeliveryApi(api),
    enabled: true,
    reconcileUnread: () async => notifications.starts++,
  );
  Future<void> setup() async {
    setupDependencies();
    await serviceLocator.unregister<TokenStore>();
    serviceLocator.registerSingleton<TokenStore>(tokens);
    await serviceLocator.unregister<AuthSessionStore>();
    serviceLocator.registerSingleton<AuthSessionStore>(metadata);
    await serviceLocator.unregister<AuthSessionManager>();
    serviceLocator.registerSingleton<AuthSessionManager>(sessions);
    await serviceLocator.unregister<ApiClient>();
    serviceLocator.registerSingleton<ApiClient>(api);
    await serviceLocator.unregister<PushCoordinator>();
    serviceLocator.registerSingleton<PushCoordinator>(push);
    await serviceLocator.unregister<NotificationCubit>();
    serviceLocator.registerSingleton<NotificationCubit>(notifications);
    await serviceLocator.unregister<DmBadgeCubit>();
    serviceLocator.registerSingleton<DmBadgeCubit>(dm);
    await serviceLocator.unregister<ProfileMediaUploadRepository>();
    serviceLocator.registerSingleton<ProfileMediaUploadRepository>(_Uploads());
    tokens.token = applicantToken();
    metadata.metadata = const AuthSessionMetadata(
      username: 'applicant',
      accountStatus: 'PENDING_VENUE_REQUEST',
    );
  }

  Future<void> mount(WidgetTester tester, {bool settle = true}) async {
    await setup();
    api.visibleDecision = () => find
        .text(
          api.decision == 'APPROVED'
              ? 'Mekân başvurun onaylandı.'
              : 'Mekân başvurun reddedildi.',
        )
        .evaluate()
        .isNotEmpty;
    await tester.pumpWidget(
      SoundConnectApp(
        appLinkSource: _Links(),
        appDeepLinkInbox: AppDeepLinkInbox(
          store: MemoryPendingAppDeepLinkStore(),
        ),
      ),
    );
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      for (var i = 0; i < 10; i++) {
        await tester.pump();
      }
    }
  }

  Future<void> mountDecision(WidgetTester tester) async {
    await setup();
    await sessions.restore();
    await tester.pumpWidget(
      const MaterialApp(home: VenueApplicationDecisionScreen()),
    );
    await tester.pumpAndSettle();
  }

  Future<void> close() async {
    push.dispose();
    sessions.dispose();
    await provider.close();
    await notifications.close();
    await dm.close();
  }
}

class _Api extends Fake implements ApiClient {
  _Api(this.sessions);
  final AuthSessionManager sessions;
  String decision = 'REJECTED';
  String? defect;
  bool failLookup = false, sawDecisionAtAck = false;
  bool failPromotion = false, failAck = false;
  int ackAttempts = 0;
  bool Function()? visibleDecision;
  Completer<void>? detailGate, promoteGate, ackGate;
  final calls = <String>[], readIds = <String>[];
  final contexts = <ApiRequestContext>[];
  final registrations = <Map<String, dynamic>>[];
  final unread = {_nid, _other};
  int promotions = 0;
  @override
  Future<T> request<T>(
    ApiHttpMethod method,
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    T Function(Object?)? decoder,
    ApiRequestContext? requestContext,
  }) async {
    calls.add(path);
    if (requestContext != null) {
      contexts.add(requestContext);
      // Lifecycle callbacks may run outside the tester's guarded pump zone.
      // A plain guard enforces the transport fence without test-API reentrancy.
      if (requestContext.expectedSessionKey != sessions.session.userId ||
          requestContext.expectedToken != sessions.session.token) {
        throw StateError('Request adopted a different test session');
      }
    }
    Object? data;
    if (path.contains('/push/devices/')) {
      registrations.add(Map<String, dynamic>.from(body as Map));
    } else if (path.endsWith('/delivery-state')) {
      data = {
        'dismissedIds': (body as Map)['notificationIds']
            .where((id) => !unread.contains(id))
            .toList(),
      };
    } else if (path == '$_base/notifications/$_nid') {
      if (failLookup) throw StateError('offline');
      data = {
        'id': _nid,
        'recipientId': applicantId,
        'type': 'VENUE_APPLICATION_$decision',
        'read': !unread.contains(_nid),
        'payload': {
          'module': defect == 'source' ? 'DM' : 'VENUE_APPLICATION',
          'applicationId': applicationId,
          'applicantUserId': applicantId,
          'action': 'APPLICATION_$decision',
          'status': decision,
        },
      };
    } else if (path == '$_base/notifications/$_nid/read') {
      ackAttempts++;
      sawDecisionAtAck = visibleDecision?.call() == true;
      await ackGate?.future;
      if (failAck) throw StateError('offline ACK');
      readIds.add(_nid);
      unread.remove(_nid);
    } else if (path == _base) {
      await detailGate?.future;
      data = {
        'id': defect == 'application' ? _other : applicationId,
        'applicantUserId': defect == 'recipient' ? _other : applicantId,
        'status': defect == 'status' ? 'PENDING' : decision,
        'venueName': 'Current owned venue',
        'venueId': decision == 'APPROVED' ? _venue : null,
      };
    } else if (path == '$_base/promote') {
      promotions++;
      await promoteGate?.future;
      if (failPromotion) throw StateError('offline promotion');
      final jwt =
          'header.${base64Url.encode(utf8.encode(jsonEncode({
            'sub': applicantId,
            'roles': ['ROLE_VENUE'],
            'exp': DateTime.now().add(const Duration(days: 1)).millisecondsSinceEpoch ~/ 1000,
          })))}.signature';
      data = {
        'token': jwt,
        'status': 'ACTIVE',
        'userId': applicantId,
        'username': 'applicant',
        'roles': ['ROLE_VENUE'],
        'permissions': <String>[],
        'admin': false,
        'requiresListenerProfileChoice': false,
      };
    } else {
      throw StateError('Unexpected request $path');
    }
    return decoder == null ? null as T : decoder(data);
  }

  @override
  Future<T> get<T>(
    String path, {
    Map<String, dynamic>? query,
    T Function(Object?)? decoder,
  }) => request(ApiHttpMethod.get, path, query: query, decoder: decoder);
  @override
  Future<T> post<T>(
    String path, {
    Object? body,
    T Function(Object?)? decoder,
  }) => request(ApiHttpMethod.post, path, body: body, decoder: decoder);
}

class _Provider
    implements
        PushProvider,
        PushRecipientBindingProvider,
        PushDeliveredProvider {
  final opens = StreamController<PushTarget>.broadcast(),
      messages = StreamController<PushTarget>.broadcast();
  String? owner;
  PushTarget? initial;
  Completer<void>? initialGate;
  @override
  bool get supported => true;
  @override
  String get platform => 'ANDROID';
  @override
  Future<void> initialize() async {}
  @override
  Future<PushPermission> permission({bool request = false}) async =>
      PushPermission.authorized;
  @override
  Future<String?> token() async => 'fictional-fcm-token';
  @override
  Future<void> deleteToken() async {
    owner = null;
  }

  @override
  Stream<String> get tokenRefresh => const Stream.empty();
  @override
  Stream<PushTarget> get opened => opens.stream;
  @override
  Stream<PushTarget> get foreground => messages.stream;
  @override
  Future<PushTarget?> initialMessage() async {
    await initialGate?.future;
    return initial;
  }

  @override
  Future<void> bindRecipient(String? value) async {
    owner = value;
  }

  @override
  Future<PushDeliveredSnapshot?> deliveredSnapshot(String recipientId) async =>
      owner == recipientId
      ? PushDeliveredSnapshot(
          recipientId: recipientId,
          bindingEpoch: _venue,
          notificationIds: [],
        )
      : null;
  @override
  Future<void> dismissDelivered(
    PushDeliveredSnapshot snapshot,
    List<String> ids,
  ) async {}
  Future<void> close() async {
    await opens.close();
    await messages.close();
  }
}

class _Store implements PushInstallationStore, PushBindingContextStore {
  String? owner, context;
  bool reset = false;
  int revision = 0;
  @override
  Future<String> installationId() async => _other;
  @override
  Future<PushInstallationMutation> nextMutation() async =>
      PushInstallationMutation(_other, ++revision);
  @override
  Future<String?> ownerId() async => owner;
  @override
  Future<void> setOwnerId(String? v) async {
    owner = v;
  }

  @override
  Future<bool> resetRequired() async => reset;
  @override
  Future<void> setResetRequired(bool v) async {
    reset = v;
  }

  @override
  Future<String?> bindingContext() async => context;
  @override
  Future<void> setBindingContext(String v) async {
    context = v;
  }
}

class _Notifications extends Cubit<NotificationState>
    implements NotificationCubit {
  _Notifications() : super(const NotificationState.initial());
  int starts = 0;
  @override
  Future<void> ensureStarted() async {
    starts++;
  }

  @override
  Future<void> stop() async {}
  @override
  Future<void> reconcileAfterResume() async {}
  @override
  Future<void> applyConfirmedExternalRead(
    AppNotification n,
    AuthSession s,
  ) async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Dm extends Cubit<DmBadgeState> implements DmBadgeCubit {
  _Dm() : super(const DmBadgeState.initial());
  int starts = 0;
  @override
  Future<void> ensureStarted() async {
    starts++;
  }

  @override
  Future<void> stop() async {}
  @override
  Future<void> reconcileAfterResume() async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Uploads extends Fake implements ProfileMediaUploadRepository {
  @override
  Future<void> resumePendingUploads() async {}
}

class _Links implements AppLinkSource {
  @override
  Stream<Uri> get uriLinkStream => const Stream.empty();
}

class _Devices extends HttpPushDeviceApi {
  _Devices(super.client);
  @override
  Future<void> revoke({
    required AuthSession session,
    required String installationId,
    required int clientRevision,
  }) async {}
}

class _NoTimer implements Timer {
  @override
  bool get isActive => false;
  @override
  int get tick => 0;
  @override
  void cancel() {}
}
