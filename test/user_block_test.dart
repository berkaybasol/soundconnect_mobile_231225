import 'dart:async';
import 'dart:ui' show SemanticsAction;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session_manager.dart';
import 'package:soundconnect_23_12_25codx/core/di/service_locator.dart';
import 'package:soundconnect_23_12_25codx/modules/user_block/data/user_block_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/user_block/presentation/blocked_accounts_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/user_block/presentation/user_block_action.dart';
import 'package:soundconnect_23_12_25codx/shared/widgets/gradient_outline_button.dart';

import 'support/event_audience_fakes.dart';
import 'support/recording_api_client.dart';

AuthSession _session(String userId) => AuthSession.authenticated(
  token: 'token-$userId',
  userId: userId,
  username: userId,
  accountStatus: 'ACTIVE',
  roles: const ['ROLE_LISTENER'],
  permissions: const [],
  expiresAt: DateTime.utc(2100),
  isAdmin: false,
);

const _ownBlock = {'blockedByMe': true, 'interactionBlocked': true};
const _otherBlock = {'blockedByMe': false, 'interactionBlocked': true};

void main() {
  late AudienceTestSessions sessions;
  setUp(() {
    sessions = AudienceTestSessions(_session('a'));
    serviceLocator.registerSingleton<AuthSessionManager>(sessions);
  });
  tearDown(() => serviceLocator.reset());

  UserBlockRepository bind(RecordingApiClient api) {
    final repository = UserBlockRepository(api, sessions);
    serviceLocator.registerSingleton<UserBlockRepository>(
      repository,
      dispose: (r) => r.dispose(),
    );
    return repository;
  }

  test(
    'account changes discard late writes and protect the new session',
    () async {
      final response = Completer<Object?>();
      final api = RecordingApiClient((_) => response.future);
      final repository = bind(api);
      final changes = <UserBlockChange>[];
      repository.changes.listen(changes.add);
      final result = repository.block('b');
      expect(api.lastRequest.path, '/api/v1/users/me/blocks/b');
      expect(api.lastRequest.requestContext?.expectedSessionKey, 'a');
      expect(api.lastRequest.requestContext?.expectedToken, 'token-a');
      expect(api.lastRequest.requestContext?.expectedCredentialRevision, 0);
      sessions.replace(_session('new'));
      response.complete(_ownBlock);
      expect((await result).isSuccess, isFalse);
      expect(changes, isEmpty);
      expect((await repository.block('new')).isSuccess, isFalse);
      expect(api.requests, hasLength(1));
    },
  );

  test(
    'a reciprocal block survives unblocking; reading status emits no change',
    () async {
      final api = RecordingApiClient((_) => _otherBlock);
      final repository = bind(api);
      final changes = <UserBlockChange>[];
      repository.changes.listen(changes.add);
      expect((await repository.status('b')).data?.interactionBlocked, true);
      expect(changes, isEmpty);
      await repository.unblock('b');
      expect(changes.single.status.blockedByMe, false);
      expect(changes.single.status.interactionBlocked, true);
      expect(changes.single.actorId, 'a');
      expect(changes.single.userId, 'b');
      expect(api.lastRequest.method, RecordedHttpMethod.delete);
    },
  );

  testWidgets(
    'profile menu confirms before blocking and hides the open profile',
    (tester) async {
      final response = Completer<Object?>();
      final api = RecordingApiClient((_) => response.future);
      bind(api);
      await tester.pumpWidget(
        const MaterialApp(
          home: BlockAwarePublicProfile(
            userId: 'b',
            child: Scaffold(
              body: Column(
                children: [
                  Text('Örnek profil'),
                  UserBlockProfileMenu(userId: 'b', name: '@berna'),
                  UserBlockProfileMenu(userId: 'a', name: '@kendim'),
                ],
              ),
            ),
          ),
        ),
      );
      expect(find.byTooltip('Profil seçenekleri'), findsOneWidget);
      Future<void> open() async {
        await tester.tap(find.byTooltip('Profil seçenekleri'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Engelle'));
        await tester.pumpAndSettle();
        expect(find.text('@berna engellensin mi?'), findsOneWidget);
      }

      await open();
      await tester.tap(find.text('Vazgeç'));
      await tester.pumpAndSettle();
      expect(api.requests, isEmpty);
      await open();
      final confirm = find.widgetWithText(GradientOutlineButton, 'Engelle');
      await tester.tap(confirm);
      await tester.pump();
      expect(tester.widget<GradientOutlineButton>(confirm).loading, isTrue);
      await tester.tap(confirm);
      expect(api.requests, hasLength(1));
      response.complete(_ownBlock);
      await tester.pumpAndSettle();
      expect(api.lastRequest.method, RecordedHttpMethod.put);
      expect(find.text('Örnek profil'), findsNothing);
      expect(find.text('Bu profil kullanılamıyor.'), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
    },
  );

  testWidgets(
    'blocked list pages, unblocks, and hides prior rows on account switch',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 640);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var removed = false;
      final api = RecordingApiClient((request) {
        if (request.method == RecordedHttpMethod.delete) {
          expect(request.path, '/api/v1/users/me/blocks/c');
          removed = true;
          return _otherBlock;
        }
        final page = request.query!['page'] as int;
        return {
          'content': [
            if (page == 0)
              {'id': 'b', 'username': 'berna'}
            else if (!removed)
              {'id': 'c', 'username': 'can'},
          ],
          'number': page,
          'size': 20,
          'hasNext': !removed && page == 0,
        };
      });
      bind(api);
      await tester.pumpWidget(const MaterialApp(home: BlockedAccountsScreen()));
      await tester.pumpAndSettle();
      final unblock = tester
          .getSemantics(find.bySemanticsLabel(RegExp(r'^Engeli kaldır$')))
          .getSemanticsData();
      expect(unblock.flagsCollection.isButton, isTrue);
      expect(unblock.hasAction(SemanticsAction.tap), isTrue);
      await tester.tap(find.text('Daha fazla göster'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byKey(const ValueKey('c')),
          matching: find.widgetWithText(GradientOutlineButton, 'Engeli kaldır'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('@can için engel kaldırılsın mı?'), findsOneWidget);
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(GradientOutlineButton, 'Engeli kaldır'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('@can'), findsNothing);
      expect(find.text('@berna'), findsOneWidget);
      expect(api.lastRequest.query?['page'], 0);
      sessions.replace(_session('d'));
      await tester.pumpAndSettle();
      expect(find.text('@berna'), findsNothing);
      expect(find.textContaining('Hesap değişti'), findsOneWidget);
    },
  );
}
