import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';
import 'package:soundconnect_23_12_25codx/app/router/app_route_guard.dart';
import 'package:soundconnect_23_12_25codx/app/router/app_router.dart';
import 'package:soundconnect_23_12_25codx/app/router/app_routes.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session_manager.dart';
import 'package:soundconnect_23_12_25codx/core/di/service_locator.dart';
import 'package:soundconnect_23_12_25codx/core/error/app_error.dart';
import 'package:soundconnect_23_12_25codx/core/network/api_exception.dart';
import 'package:soundconnect_23_12_25codx/modules/admin/data/admin_user_directory_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/admin/domain/admin_user_directory.dart';
import 'package:soundconnect_23_12_25codx/modules/admin/presentation/screens/admin_dashboard_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/admin/presentation/screens/admin_user_directory_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/navigation/profile_route_resolver.dart';

import 'support/event_audience_fakes.dart';
import 'support/recording_api_client.dart';

const path = '/api/v1/admin/users';
const accountId = 'ae540b51-a55c-4674-a445-000000000001';
const profileId = '19e41890-2665-4288-88f6-8101e2882000';
const perms = ['ADMIN_PANEL_ACCESS', 'READ_USERS'];
const managePerms = [...perms, 'MANAGE_USERS'];

AuthSession admin({
  List<String> permissions = perms,
  List<String> roles = const ['ROLE_ADMIN'],
}) => AuthSession.authenticated(
  token: 'local-test-token',
  userId: 'moderator',
  username: 'moderator',
  roles: roles,
  permissions: permissions,
  expiresAt: DateTime.utc(2100),
  accountStatus: 'ACTIVE',
  isAdmin: true,
);

Map<String, dynamic> account({
  String name = 'mavioda',
  String type = 'STUDIO',
  String id = accountId,
}) => {'userId': id, 'username': name, 'profileType': type, 'status': 'ACTIVE'};

Map<String, dynamic> profile(Map<String, dynamic> row) => {
  ...row,
  'publicCode': 'SC-23F23F23F23F23F23F23',
  'createdAt': null,
  'emailVerified': true,
  'profileTarget': {'type': row['profileType'], 'profileId': profileId},
};

Map<String, dynamic> page(
  List<Map<String, dynamic>> rows, {
  int index = 0,
  int? total,
}) {
  final count = total ?? rows.length;
  return {
    'content': rows,
    'page': index,
    'size': 20,
    'totalElements': count,
    'totalPages': (count + 19) ~/ 20,
  };
}

Future<void> openDirectory(
  WidgetTester tester,
  RecordingApiClient api,
  AudienceTestSessions sessions, {
  RouteFactory? onGenerateRoute,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      onGenerateRoute: onGenerateRoute,
      home: AdminUserDirectoryScreen(
        sessions: sessions,
        initialSession: sessions.session,
        repository: AdminUserDirectoryRepository(api, sessions),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> tap(WidgetTester tester, Finder target) async {
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

void main() {
  test(
    'directory requires both permissions and fences responses even on same-account replacement',
    () async {
      final completion = Completer<Object?>();
      final api = RecordingApiClient((_) => completion.future);
      final sessions = AudienceTestSessions(
        admin(permissions: const ['MANAGE_USERS', 'ADMIN_PANEL_ACCESS']),
      );
      final repository = AdminUserDirectoryRepository(api, sessions);
      for (final denied in [
        sessions.session,
        admin(permissions: const ['READ_USERS']),
        admin(roles: const ['ROLE_LISTENER']),
        const AuthSession.guest(),
      ]) {
        expect(canReadAdminUsers(denied), isFalse);
        expect(
          AppRouteGuard.redirectFor(AppRoutes.adminUsers, denied),
          isNotNull,
        );
        sessions.replace(denied);
        expect((await repository.search()).error, adminUsersAccessError);
        expect(
          (await repository.detail(accountId)).error,
          adminUsersAccessError,
        );
      }
      expect(api.requests, isEmpty);
      sessions.replace(admin());
      final revision = sessions.credentialRevision;
      final result = repository.search(
        query: '  @mavi  ',
        profileType: AdminUserProfileType.studio,
        status: AdminUserStatus.active,
        page: 1,
      );
      expect(api.lastRequest.path, path);
      expect(api.lastRequest.query, {
        'query': '@mavi',
        'profileType': 'STUDIO',
        'status': 'ACTIVE',
        'page': 1,
        'size': 20,
      });
      expect(
        api.lastRequest.requestContext?.expectedCredentialRevision,
        revision,
      );
      expect(
        api.lastRequest.requestContext?.expectedSessionKey,
        sessions.session.userId,
      );
      sessions.replace(admin());
      completion.complete(page([account()], index: 1, total: 21));
      expect((await result).error, adminUsersAccessError);
    },
  );

  test(
    'validates IDs, filter scope, malformed pages and profile ownership context',
    () async {
      final sessions = AudienceTestSessions(admin());
      Object? response;
      final api = RecordingApiClient((_) => response);
      final repository = AdminUserDirectoryRepository(api, sessions);
      await repository.detail('not-uuid');
      await repository.search(page: 1001);
      await repository.search(query: 'x' * 81);
      expect(api.requests, isEmpty);
      response = page([account(), account()]);
      expect((await repository.search()).isSuccess, isFalse);
      response = page([account()]);
      expect(
        (await repository.search(
          profileType: AdminUserProfileType.venue,
        )).isSuccess,
        isFalse,
      );
      response = {
        ...profile(account()),
        'profileTarget': {'type': 'VENUE', 'profileId': profileId},
      };
      expect((await repository.detail(accountId)).isSuccess, isFalse);
      response = profile(account(id: profileId));
      expect((await repository.detail(accountId)).isSuccess, isFalse);
      response = profile(account());
      final detail = (await repository.detail(accountId)).data!;
      expect(detail.account.username, 'mavioda');
      expect(detail.createdAt, isNull);
      expect(detail.profileId, profileId);
    },
  );

  test(
    'access writes require both client permission and current target capability; receipts must match',
    () async {
      final sessions = AudienceTestSessions(admin());
      final row = {...account(), 'suspended': false};
      var receiptRevision = 1;
      final api = RecordingApiClient(
        (r) => r.method == RecordedHttpMethod.post
            ? {'suspended': true, 'revision': receiptRevision}
            : {...profile(row), 'accessRevision': 0, 'canManageAccess': true},
      );
      final repo = AdminUserDirectoryRepository(api, sessions);
      final readOnly = (await repo.detail(accountId)).data!;
      expect(readOnly.canManageAccess, isFalse);
      expect(
        (await repo.changeAccess(readOnly, 'Geçerli gerekçe')).isSuccess,
        isFalse,
      );
      sessions.replace(admin(permissions: managePerms));
      final detail = (await repo.detail(accountId)).data!;
      expect(detail.canManageAccess, isTrue);
      expect((await repo.changeAccess(detail, '    ')).isSuccess, isFalse);
      expect((await repo.changeAccess(detail, 'A' * 501)).isSuccess, isFalse);
      expect(
        api.requests.where((r) => r.method == RecordedHttpMethod.post),
        isEmpty,
      );
      expect(
        (await repo.changeAccess(detail, '  Geçerli gerekçe  ')).data,
        isTrue,
      );
      expect(api.lastRequest.path, '$path/$accountId/access');
      final body = api.lastRequest.body as Map;
      expect(Uuid.isValidUUID(fromString: body['requestId'] as String), isTrue);
      expect(body['suspended'], isTrue);
      expect(body['reason'], 'Geçerli gerekçe');
      expect(body['expectedRevision'], 0);
      expect(
        api.lastRequest.requestContext?.expectedCredentialRevision,
        sessions.credentialRevision,
      );
      receiptRevision = 8;
      expect(
        (await repo.changeAccess(detail, 'Örnek gerekçe')).isSuccess,
        isFalse,
      );
      sessions.replace(admin());
      final before = api.requests.length;
      expect(
        (await repo.changeAccess(detail, 'Örnek gerekçe')).isSuccess,
        isFalse,
      );
      expect(api.requests.length, before);
      final malformed = {
        ...profile(row),
        'canManageAccess': true,
        'accessRevision': 1,
      };
      expect(() => AdminUserDetail.fromJson(malformed), throwsFormatException);
    },
  );

  for (final outcome in ['success', 'conflict', 'lostReceipt', 'permission']) {
    testWidgets(
      'access decision reconciles $outcome with a fresh detail and filtered list',
      (tester) async {
        var revision = 0;
        var manage = true;
        var actorName = 'moderator';
        Map<String, dynamic> row() => {
          ...account(),
          'suspended': revision == 1,
        };
        final api = RecordingApiClient((r) {
          if (r.path == path) {
            return page(
              r.query?['suspended'] == true && revision != 1 ? [] : [row()],
            );
          }
          if (r.method == RecordedHttpMethod.get) {
            return {
              ...profile(row()),
              'accessRevision': revision,
              'canManageAccess': manage,
              if (revision > 0)
                'lastAccessDecision': {
                  'suspended': revision == 1,
                  'reason': 'Kayıtlı son gerekçe',
                  'actorUsername': actorName,
                  'decidedAt': '2026-11-23T13:30:00Z',
                },
            };
          }
          expect(r.body, containsPair('expectedRevision', revision));
          if (outcome == 'permission') {
            manage = false;
            throw ApiException(
              const AppError(code: '1102', message: 'Forbidden'),
            );
          }
          revision++;
          if (outcome == 'conflict') {
            actorName = 'other-admin';
            throw ApiException(
              const AppError(code: '1010', message: 'Conflict'),
            );
          }
          if (outcome == 'lostReceipt') {
            throw TimeoutException('connection lost');
          }
          return {'suspended': revision == 1, 'revision': revision};
        });
        await openDirectory(
          tester,
          api,
          AudienceTestSessions(admin(permissions: managePerms)),
        );
        await tap(tester, find.text('@mavioda'));
        await tap(tester, find.text('Hesabı askıya al'));
        expect(find.text('Yalnızca yöneticiler görür.'), findsOneWidget);
        await tap(tester, find.text('Askıya al'));
        expect(find.text('5–500 karakterlik bir gerekçe yaz.'), findsOneWidget);
        await tester.enterText(
          find.byType(TextFormField),
          'Hesap ihlali doğrulandı',
        );
        await tap(tester, find.text('Askıya al'));
        expect(
          api.requests.where((r) => r.method == RecordedHttpMethod.post),
          hasLength(1),
        );
        expect(api.lastRequest.path, '$path/$accountId');
        if (outcome == 'permission') {
          expect(
            find.text('Bu hesabın erişimini değiştirme yetkin yok.'),
            findsOneWidget,
          );
          expect(find.text('Hesabı askıya al'), findsNothing);
          expect(find.text('Askı yok'), findsOneWidget);
        } else {
          expect(find.text('Askıda'), findsOneWidget);
          expect(find.text('Kayıtlı son gerekçe'), findsOneWidget);
          expect(find.text('@$actorName'), findsOneWidget);
          if (outcome == 'conflict') {
            expect(
              find.text('Hesap erişimi değişti. Güncel kararı kontrol et.'),
              findsOneWidget,
            );
          }
          if (outcome == 'lostReceipt') {
            expect(
              find.textContaining('Karar yanıtı alınamadı.'),
              findsOneWidget,
            );
          }
        }
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        await tap(tester, find.text('Yalnızca askıdaki hesaplar'));
        expect(api.lastRequest.query?['suspended'], true);
        if (outcome == 'permission') {
          expect(find.text('Hesap bulunamadı'), findsOneWidget);
        } else if (outcome == 'success') {
          await tap(tester, find.text('@mavioda'));
          await tap(tester, find.text('Askıyı kaldır'));
          await tap(tester, find.text('Vazgeç'));
          expect(
            api.requests.where((r) => r.method == RecordedHttpMethod.post),
            hasLength(1),
          );
          await tap(tester, find.text('Askıyı kaldır'));
          await tester.enterText(
            find.byType(TextFormField),
            'İnceleme tamamlandı',
          );
          await tap(tester, find.text('Askıyı kaldır').last);
          expect(find.text('Askı kaldırıldı'), findsOneWidget);
          await tester.binding.handlePopRoute();
          await tester.pumpAndSettle();
          expect(find.text('Hesap bulunamadı'), findsOneWidget);
        }
      },
    );
  }

  testWidgets(
    'panel shortcut opens the guarded feature from the real router only for eligible sessions',
    (tester) async {
      final sessions = AudienceTestSessions(
        admin(permissions: const ['ADMIN_PANEL_ACCESS']),
      );
      serviceLocator.registerSingleton<AuthSessionManager>(sessions);
      final api = RecordingApiClient((_) => page([account()]));
      serviceLocator.registerSingleton<AdminUserDirectoryRepository>(
        AdminUserDirectoryRepository(api, sessions),
      );
      addTearDown(serviceLocator.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: const AdminDashboardScreen(),
          onGenerateRoute: AppRouter.onGenerateRoute,
        ),
      );
      await tester.pumpAndSettle();
      final shortcut = find.byKey(const Key('admin-user-search-entry'));
      expect(shortcut, findsNothing);
      sessions.replace(admin());
      await tester.pumpAndSettle();
      await tap(tester, shortcut);
      expect(find.text('@mavioda'), findsOneWidget);
      expect(find.byKey(const Key('admin-nav-system')), findsOneWidget);
      expect(api.requests.single.path, path);
    },
  );

  testWidgets(
    'older search responses cannot replace a new query or the filter empty state',
    (tester) async {
      final pending = Completer<Object?>();
      final api = RecordingApiClient((r) {
        if (r.query?['query'] == 'old') return pending.future;
        if (r.query?['profileType'] == 'VENUE') return page([]);
        return page([account(name: r.query?['query'] as String? ?? 'initial')]);
      });
      await openDirectory(tester, api, AudienceTestSessions(admin()));
      final field = find.byKey(const Key('admin-users-query'));
      await tester.enterText(field, 'old');
      await tester.pump(const Duration(milliseconds: 310));
      await tester.enterText(field, 'fresh');
      await tester.pump(const Duration(milliseconds: 310));
      await tester.pumpAndSettle();
      expect(find.text('@fresh'), findsOneWidget);
      pending.complete(page([account(name: 'old')]));
      await tester.pumpAndSettle();
      expect(find.text('@old'), findsNothing);
      await tap(tester, find.byKey(const Key('admin-users-type')));
      await tap(tester, find.text('Mekân').last);
      expect(find.text('Hesap bulunamadı'), findsOneWidget);
      await tap(tester, find.text('Aramayı temizle'));
      expect(api.lastRequest.query, {'page': 0, 'size': 20});
    },
  );

  for (final (kind, type) in [
    (ProfileRouteKind.musician, 'MUSICIAN'),
    (ProfileRouteKind.listener, 'LISTENER'),
    (ProfileRouteKind.venue, 'VENUE'),
    (ProfileRouteKind.studio, 'STUDIO'),
  ]) {
    testWidgets(
      '$type uses the existing public route and actual profile target, then preserves page and search',
      (tester) async {
        final row = account(type: type);
        final api = RecordingApiClient(
          (r) => r.path == path
              ? page([row], index: r.query!['page'] as int, total: 21)
              : profile(row),
        );
        RouteSettings? opened;
        await openDirectory(
          tester,
          api,
          AudienceTestSessions(admin()),
          onGenerateRoute: (settings) {
            opened = settings;
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (_) => const Scaffold(body: Text('Ziyaretçi profili')),
            );
          },
        );
        await tester.enterText(find.byType(TextField), '@mavi');
        await tester.pump(const Duration(milliseconds: 310));
        await tester.pumpAndSettle();
        await tap(tester, find.byTooltip('Sonraki sayfa'));
        await tap(tester, find.text('@mavioda'));
        expect(api.lastRequest.path, '$path/$accountId');
        await tap(tester, find.text('Profili aç'));
        final expected = ProfileRouteTarget(kind: kind, id: profileId);
        expect(opened?.name, expected.publicRoute);
        expect(
          ProfileRouteTarget.fromArguments(kind, opened?.arguments).id,
          profileId,
        );
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(
          api.requests.where((r) => r.path == '$path/$accountId'),
          hasLength(2),
        );
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.text('2 / 2'), findsOneWidget);
        expect(
          tester.widget<TextField>(find.byType(TextField)).controller!.text,
          '@mavi',
        );
        expect(api.lastRequest.path, path);
        expect(api.lastRequest.query, {
          'query': '@mavi',
          'page': 1,
          'size': 20,
        });
      },
    );
  }

  testWidgets(
    'server permission revocation from detail also removes the underlying directory',
    (tester) async {
      final api = RecordingApiClient((r) {
        if (r.path == path) return page([account()]);
        throw ApiException(
          const AppError(code: '1102', message: 'Erişim kapandı.'),
        );
      });
      await openDirectory(tester, api, AudienceTestSessions(admin()));
      await tap(tester, find.text('@mavioda'));
      expect(find.text(adminUsersAccessError.message), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text(adminUsersAccessError.message), findsOneWidget);
      expect(find.text('@mavioda'), findsNothing);
      expect(find.byType(TextField), findsNothing);
    },
  );

  testWidgets(
    'returning from a scrolled filtered list restores its exact position',
    (tester) async {
      final rows = List.generate(
        20,
        (index) => account(
          name: 'studio$index',
          id: 'ae540b51-a55c-4674-a445-${(index + 1).toString().padLeft(12, '0')}',
        ),
      );
      final api = RecordingApiClient((request) {
        if (request.path == path) return page(rows);
        return profile(rows.last);
      });
      await openDirectory(tester, api, AudienceTestSessions(admin()));
      await tap(tester, find.byKey(const Key('admin-users-type')));
      await tap(tester, find.text('Stüdyo').last);
      final list = find.byType(ListView);
      final controller = tester.widget<ListView>(list).controller!;
      final last = find.text('@studio19');
      await tester.ensureVisible(last);
      await tester.pumpAndSettle();
      final before = controller.offset;
      expect(before, greaterThan(0));
      await tap(tester, last);
      expect(find.text('Profili aç'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(controller.offset, before);
      expect(find.text('@studio19').hitTestable(), findsOneWidget);
      expect(
        api.requests.where((r) => r.path == path).last.query?['profileType'],
        'STUDIO',
      );
    },
  );

  testWidgets(
    'visible detail refreshes only the selected account and closes a deleted account decision',
    (tester) async {
      var deleted = false;
      var reads = 0;
      final api = RecordingApiClient((r) {
        if (r.path == path) return page([account()]);
        expect(r.path, '$path/$accountId');
        expect(r.method, RecordedHttpMethod.get);
        reads++;
        if (deleted) {
          throw ApiException(
            const AppError(code: '1001', message: 'Hesap bulunamadı.'),
          );
        }
        return {
          ...profile(account()),
          'suspended': false,
          'canManageAccess': true,
          'accessRevision': 0,
        };
      });
      await openDirectory(
        tester,
        api,
        AudienceTestSessions(admin(permissions: managePerms)),
      );
      await tap(tester, find.text('@mavioda'));
      expect(reads, 1);
      await tap(tester, find.byTooltip('Hesabı yenile'));
      expect(reads, 2);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump(const Duration(seconds: 31));
      expect(reads, 2);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(reads, 3);
      await tap(tester, find.text('Hesabı askıya al'));
      expect(find.text('Askıya al'), findsOneWidget);
      deleted = true;
      await tester.pump(const Duration(seconds: 31));
      await tester.pumpAndSettle();
      expect(find.text('Hesap bulunamadı.'), findsOneWidget);
      expect(find.text('Askıya al'), findsNothing);
      expect(find.byTooltip('Hesap kimliğini kopyala'), findsNothing);
      expect(find.text('Profili aç'), findsNothing);
      expect(api.requests.where((r) => r.path == path), hasLength(1));
    },
  );

  testWidgets(
    'transient detail reads preserve the reason, resume polling and recheck before sending',
    (tester) async {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      var offline = false;
      var reads = 0;
      var writes = 0;
      var readsAtWrite = 0;
      const note = 'Yönetici tarafından hazırlanan taslak';
      final api = RecordingApiClient((r) {
        if (r.path == path) return page([account()]);
        if (r.method == RecordedHttpMethod.post) {
          expect(r.body, containsPair('reason', note));
          expect(r.body, containsPair('expectedRevision', 0));
          writes++;
          readsAtWrite = reads;
          return {'suspended': true, 'revision': 1};
        }
        reads++;
        if (offline) {
          throw ApiException(
            const AppError(code: 'network', message: 'Bağlantı kurulamadı.'),
          );
        }
        return {
          ...profile(account()),
          'suspended': writes > 0,
          'canManageAccess': true,
          'accessRevision': writes,
          if (writes > 0)
            'lastAccessDecision': {
              'suspended': true,
              'reason': note,
              'actorUsername': 'moderator',
              'decidedAt': '2026-11-23T13:30:00Z',
            },
        };
      });
      await openDirectory(
        tester,
        api,
        AudienceTestSessions(admin(permissions: managePerms)),
      );
      await tap(tester, find.text('@mavioda'));
      await tap(tester, find.text('Hesabı askıya al'));
      await tester.enterText(find.byType(TextFormField), note);
      offline = true;
      await tester.pump(const Duration(seconds: 31));
      await tester.pumpAndSettle();
      expect(reads, 2);
      expect(find.text(note), findsOneWidget);
      await tap(tester, find.text('Askıya al'));
      expect(reads, 3);
      expect(writes, 0);
      expect(find.text(note), findsOneWidget);
      expect(find.text('Bağlantı kurulamadı.').hitTestable(), findsOneWidget);
      offline = false;
      await tester.pump(const Duration(seconds: 31));
      await tester.pumpAndSettle();
      expect(reads, 4);
      expect(find.text(note), findsOneWidget);
      await tap(tester, find.text('Askıya al'));
      expect(readsAtWrite, 5);
      expect(writes, 1);
      expect(find.byType(TextFormField), findsNothing);
    },
  );

  for (final lostReadAccess in [true, false]) {
    testWidgets(
      'open reason closes when updated account loses ${lostReadAccess ? "read" : "decision"} access',
      (tester) async {
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        var changed = false;
        final api = RecordingApiClient((r) {
          if (r.path == path) return page([account()]);
          expect(r.method, RecordedHttpMethod.get);
          if (changed && lostReadAccess) {
            throw ApiException(
              const AppError(code: '1102', message: 'Forbidden'),
            );
          }
          return {
            ...profile(account()),
            'suspended': false,
            'accessRevision': 0,
            'canManageAccess': !changed,
          };
        });
        await openDirectory(
          tester,
          api,
          AudienceTestSessions(admin(permissions: managePerms)),
        );
        await tap(tester, find.text('@mavioda'));
        await tap(tester, find.text('Hesabı askıya al'));
        await tester.enterText(
          find.byType(TextFormField),
          'Geçerli gerekçe taslağı',
        );
        changed = true;
        await tester.pump(const Duration(seconds: 31));
        await tester.pumpAndSettle();
        expect(find.byType(TextFormField), findsNothing);
        expect(find.text('Hesabı askıya al'), findsNothing);
        expect(
          find.text(
            lostReadAccess ? adminUsersAccessError.message : 'Askı yok',
          ),
          findsOneWidget,
        );
      },
    );
  }

  for (final revoked in [true, false]) {
    testWidgets(
      'profile return rechecks a ${revoked ? "revoked permission" : "deleted account"} before showing or copying details',
      (tester) async {
        final pending = Completer<Object?>();
        var detailReads = 0;
        var listReads = 0;
        final api = RecordingApiClient((r) {
          if (r.path == path) return page(++listReads == 1 ? [account()] : []);
          return ++detailReads == 1 ? profile(account()) : pending.future;
        });
        await openDirectory(
          tester,
          api,
          AudienceTestSessions(admin()),
          onGenerateRoute: (settings) => MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => const Scaffold(body: Text('Ziyaretçi profili')),
          ),
        );
        await tap(tester, find.text('@mavioda'));
        await tap(tester, find.text('Profili aç'));
        await tester.binding.handlePopRoute();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        expect(detailReads, 2);
        expect(find.byTooltip('Hesap kimliğini kopyala'), findsNothing);
        pending.completeError(
          ApiException(
            AppError(
              code: revoked ? '1102' : '1001',
              message: 'Hesap artık açılamıyor.',
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.text(
            revoked ? adminUsersAccessError.message : 'Hesap artık açılamıyor.',
          ),
          findsOneWidget,
        );
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.text('@mavioda').hitTestable(), findsNothing);
        expect(
          find.text(
            revoked ? adminUsersAccessError.message : 'Hesap bulunamadı',
          ),
          findsOneWidget,
        );
        expect(listReads, revoked ? 1 : 2);
      },
    );
  }
}
