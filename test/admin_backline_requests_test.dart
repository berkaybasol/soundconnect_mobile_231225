import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/app/router/app_route_guard.dart';
import 'package:soundconnect_23_12_25codx/app/router/app_router.dart';
import 'package:soundconnect_23_12_25codx/app/router/app_routes.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session_manager.dart';
import 'package:soundconnect_23_12_25codx/core/di/service_locator.dart';
import 'package:soundconnect_23_12_25codx/core/error/app_error.dart';
import 'package:soundconnect_23_12_25codx/core/network/api_client.dart';
import 'package:soundconnect_23_12_25codx/core/network/api_exception.dart';
import 'package:soundconnect_23_12_25codx/modules/admin/data/admin_backline_request_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/admin/presentation/screens/admin_dashboard_screen.dart';

import 'support/event_audience_fakes.dart';
import 'support/recording_api_client.dart';

const _permissions = ['ADMIN_PANEL_ACCESS', 'MANAGE_BACKLINE_CATALOG'];
const _rootRequest = {
  'id': 'request-1',
  'clientRequestId': 'client-1',
  'studioProfileId': 'studio-1',
  'studioName': 'Mor Oda',
  'type': 'ROOT_CATEGORY',
  'requestedName': 'Modüler sentezleyiciler',
  'proposedChildren': [
    {'name': 'Ses modülleri', 'position': 0},
  ],
  'requesterNote': 'Provalarda kullanıyoruz.',
  'status': 'PENDING',
  'createdAtUtc': '2026-11-24T10:00:00Z',
};
const _subcategory = {
  'id': 'request-2',
  'clientRequestId': 'client-2',
  'studioProfileId': 'studio-2',
  'studioName': 'Mavi Kayıt',
  'type': 'SUBCATEGORY',
  'requestedName': 'Şerit mikrofon',
  'parentCategoryId': 'parent-2',
  'parentCategoryName': 'Mikrofonlar',
  'proposedChildren': [],
  'status': 'APPROVED',
  'createdAtUtc': '2026-11-23T10:00:00Z',
};

AuthSession _admin({
  List<String> permissions = _permissions,
  List<String> roles = const ['ROLE_ADMIN'],
  bool isAdmin = true,
  DateTime? expiresAt,
}) => AuthSession.authenticated(
  token: 'test-token',
  userId: 'reviewer',
  username: 'reviewer',
  accountStatus: 'ACTIVE',
  roles: roles,
  permissions: permissions,
  expiresAt: expiresAt ?? DateTime.utc(2100),
  isAdmin: isAdmin,
);

Map<String, Object?> _page(
  List<Map<String, Object?>> rows, {
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

Finder get _inbox => find.byKey(const Key('admin-backline-requests-entry'));

Future<void> _pumpDashboard(
  WidgetTester tester,
  AudienceTestSessions sessions,
  RecordingApiClient api,
) async {
  serviceLocator.registerSingleton<AuthSessionManager>(sessions);
  serviceLocator.registerSingleton<ApiClient>(api);
  await tester.pumpWidget(
    const MaterialApp(
      home: AdminDashboardScreen(),
      onGenerateRoute: AppRouter.onGenerateRoute,
    ),
  );
  await tester.pumpAndSettle();
}

void _expectReads(RecordingApiClient api, List<int> expectedPages) {
  expect(api.requests, hasLength(expectedPages.length));
  for (final (i, page) in expectedPages.indexed) {
    final request = api.requests[i];
    expect(request.method, RecordedHttpMethod.get);
    expect(request.path, '/api/v1/admin/backline/category-requests');
    expect(request.query, {'page': page, 'size': 20});
    expect(request.body, isNull);
    expect(request.requestContext?.expectedSessionKey, 'reviewer');
    expect(request.requestContext?.expectedCredentialRevision, 0);
  }
}

void main() {
  tearDown(() => serviceLocator.reset());

  test(
    'the route and repository require a current backline administrator',
    () async {
      final sessions = AudienceTestSessions(_admin());
      final api = RecordingApiClient((_) => _page([]));
      final repository = AdminBacklineRequestRepository(api, sessions);
      expect(
        AppRouteGuard.redirectFor(
          AppRoutes.adminBacklineRequests,
          sessions.session,
        ),
        isNull,
      );
      for (final denied in [
        const AuthSession.guest(),
        const AuthSession.suspended(),
        _admin(
          permissions: const [
            'ADMIN_PANEL_ACCESS',
            'MANAGE_STUDIO_APPLICATIONS',
          ],
        ),
        _admin(permissions: const ['MANAGE_BACKLINE_CATALOG']),
        _admin(roles: const ['ROLE_ADMIN', 'ROLE_LISTENER']),
        _admin(isAdmin: false),
        _admin(expiresAt: DateTime.utc(2020)),
      ]) {
        sessions.replace(denied);
        expect(
          AppRouteGuard.redirectFor(AppRoutes.adminBacklineRequests, denied),
          isNotNull,
        );
        expect((await repository.list(0)).isSuccess, isFalse);
      }
      expect(api.requests, isEmpty);
    },
  );

  testWidgets(
    'loss of access hides the dashboard shortcut and blocks a captured tap',
    (tester) async {
      final sessions = AudienceTestSessions(_admin());
      final api = RecordingApiClient((_) => _page([]));
      await _pumpDashboard(tester, sessions, api);
      final open = tester.widget<InkWell>(_inbox).onTap!;
      sessions.replace(
        _admin(
          permissions: const [
            'ADMIN_PANEL_ACCESS',
            'MANAGE_STUDIO_APPLICATIONS',
          ],
        ),
      );
      open();
      await tester.pumpAndSettle();
      expect(_inbox, findsNothing);
      expect(
        find.byKey(const Key('admin-applications-studio')),
        findsOneWidget,
      );
      expect(api.requests, isEmpty);
    },
  );

  testWidgets(
    'both request types can be read from the real dashboard and navigation only issues GETs',
    (tester) async {
      final firstPage = [
        _rootRequest,
        for (var i = 1; i < 20; i++)
          {..._rootRequest, 'id': 'extra-$i', 'requestedName': 'Kategori $i'},
      ];
      var failNextPage = true;
      final api = RecordingApiClient((request) {
        if (request.query!['page'] == 0) return _page(firstPage, total: 21);
        if (failNextPage) {
          failNextPage = false;
          throw ApiException(
            const AppError(
              code: 'network',
              message:
                  'Baglanti reddedildi: http://localhost:8080. '
                  'Emulator icin 10.0.2.2 kullan.',
            ),
          );
        }
        return _page([_subcategory], index: 1, total: 21);
      });
      await _pumpDashboard(tester, AudienceTestSessions(_admin()), api);
      expect(api.requests, isEmpty);
      await tester.tap(_inbox);
      await tester.pumpAndSettle();

      final root = find.byKey(const ValueKey('request-1'));
      final firstSpokenRow = tester.semantics.find(root);
      final secondSpokenRow = tester.semantics.find(
        find.byKey(const ValueKey('extra-1')),
      );
      expect(firstSpokenRow.id, isNot(secondSpokenRow.id));
      expect(firstSpokenRow.label, contains('Modüler sentezleyiciler'));
      expect(firstSpokenRow.label, isNot(contains('Kategori 1')));
      expect(secondSpokenRow.label, contains('Kategori 1'));
      expect(secondSpokenRow.label, isNot(contains('Modüler sentezleyiciler')));
      for (final content in [
        'Ana kategori',
        'Modüler sentezleyiciler',
        'Mor Oda',
        'Önerilen alt kategoriler: Ses modülleri',
        'Provalarda kullanıyoruz.',
      ]) {
        expect(
          find.descendant(of: root, matching: find.text(content)),
          findsOneWidget,
        );
      }
      expect(
        find.descendant(of: root, matching: find.textContaining('Kasım 2026')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: root,
          matching: find.byWidgetPredicate((w) => w is InkResponse),
        ),
        findsNothing,
      );
      await tester.tap(find.text('Modüler sentezleyiciler'));
      await tester.pumpAndSettle();
      _expectReads(api, [0]);

      final next = find.text('Sonraki sayfa');
      await tester.scrollUntilVisible(next, 500);
      await tester.tap(next);
      await tester.pumpAndSettle();
      expect(
        find.text('Kategori talepleri yüklenemedi. Lütfen tekrar dene.'),
        findsOneWidget,
      );
      for (final diagnostic in ['localhost', 'Emulator', '10.0.2.2']) {
        expect(find.textContaining(diagnostic), findsNothing);
      }
      await tester.tap(find.text('Tekrar dene'));
      await tester.pumpAndSettle();
      for (final content in [
        'Alt kategori',
        'Şerit mikrofon',
        'Mavi Kayıt',
        'Üst kategori: Mikrofonlar',
        'Onaylandı',
      ]) {
        expect(find.text(content), findsOneWidget);
      }
      final child = find.byKey(const ValueKey('request-2'));
      expect(
        find.descendant(
          of: child,
          matching: find.byWidgetPredicate((w) => w is InkResponse),
        ),
        findsNothing,
      );
      expect(find.text('Modüler sentezleyiciler'), findsNothing);
      final previous = find.text('Önceki sayfa');
      await tester.ensureVisible(previous);
      await tester.tap(previous);
      await tester.pumpAndSettle();
      expect(find.text('Modüler sentezleyiciler'), findsOneWidget);
      _expectReads(api, [0, 1, 1, 0]);
    },
  );

  testWidgets(
    'refreshing an empty inbox shows a new request without navigating away',
    (tester) async {
      var submitted = false;
      final api = RecordingApiClient(
        (_) => _page(submitted ? [_rootRequest] : []),
      );
      await _pumpDashboard(tester, AudienceTestSessions(_admin()), api);
      await tester.tap(_inbox);
      await tester.pumpAndSettle();
      expect(find.text('Henüz kategori talebi yok.'), findsOneWidget);
      expect(find.text('Sonraki sayfa'), findsNothing);
      submitted = true;
      await tester.tap(find.byTooltip('Listeyi yenile'));
      await tester.pumpAndSettle();
      expect(find.text('Henüz kategori talebi yok.'), findsNothing);
      expect(find.text('Modüler sentezleyiciler'), findsOneWidget);
      _expectReads(api, [0, 0]);
    },
  );

  for (final localReplacement in [true, false]) {
    testWidgets(
      'a pending refresh cannot reveal rows after ${localReplacement ? 'same-account re-login' : 'server-side revocation'}',
      (tester) async {
        final sessions = AudienceTestSessions(_admin());
        final response = Completer<Object?>();
        var refreshing = false;
        final api = RecordingApiClient(
          (_) => refreshing ? response.future : _page([_rootRequest]),
        );
        await _pumpDashboard(tester, sessions, api);
        await tester.tap(_inbox);
        await tester.pumpAndSettle();
        expect(find.text('Mor Oda'), findsOneWidget);
        refreshing = true;
        await tester.tap(find.byTooltip('Listeyi yenile'));
        await tester.pump();
        expect(find.text('Mor Oda'), findsNothing);
        if (localReplacement) {
          sessions.replace(_admin());
          response.complete(_page([_subcategory]));
        } else {
          response.completeError(
            ApiException(const AppError(code: '403', message: 'Forbidden')),
          );
        }
        await tester.pumpAndSettle();
        expect(find.text('Mavi Kayıt'), findsNothing);
        expect(find.textContaining('oturumun değişti'), findsOneWidget);
        expect(find.byTooltip('Listeyi yenile'), findsNothing);
        expect(find.text('Tekrar dene'), findsNothing);
        _expectReads(api, [0, 0]);
      },
    );
  }
}
