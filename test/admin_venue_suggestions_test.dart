import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/app/router/app_route_guard.dart';
import 'package:soundconnect_23_12_25codx/app/router/app_router.dart';
import 'package:soundconnect_23_12_25codx/app/router/app_routes.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session_manager.dart';
import 'package:soundconnect_23_12_25codx/core/di/service_locator.dart';
import 'package:soundconnect_23_12_25codx/core/network/api_client.dart';
import 'package:soundconnect_23_12_25codx/modules/admin/data/admin_venue_suggestion_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/admin/presentation/screens/admin_dashboard_screen.dart';

import 'support/event_audience_fakes.dart';
import 'support/recording_api_client.dart';

const _permissions = ['ADMIN_PANEL_ACCESS', 'MANAGE_VENUES'];
const _venue = {
  'venueName': 'Şehir Sahnesi',
  'cityName': 'Ankara',
  'districtName': 'Çankaya',
  'liveMusic': 'YES',
};

AuthSession _admin({
  List<String> permissions = _permissions,
  List<String> roles = const ['ROLE_ADMIN'],
}) => AuthSession.authenticated(
  token: 'test-token',
  userId: 'operator',
  username: 'operator',
  accountStatus: 'ACTIVE',
  roles: roles,
  permissions: permissions,
  expiresAt: DateTime.utc(2100),
  isAdmin: true,
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

final _entry = find.byKey(const Key('admin-venue-suggestions-entry'));

Future<void> _dashboard(
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

void _expectReads(RecordingApiClient api, List<int> pages) {
  expect(api.requests, hasLength(pages.length));
  for (final (i, index) in pages.indexed) {
    final request = api.requests[i];
    expect(request.method, RecordedHttpMethod.get);
    expect(request.path, '/api/v1/admin/venue-suggestions');
    expect(request.query, {'page': index, 'size': 20});
    expect(request.body, isNull);
    expect(request.requestContext?.expectedSessionKey, 'operator');
  }
}

void main() {
  tearDown(() => serviceLocator.reset());

  testWidgets(
    'the venue-management permission controls the card, route and repository',
    (tester) async {
      final sessions = AudienceTestSessions(_admin());
      final api = RecordingApiClient((_) => _page([_venue]));
      final repository = AdminVenueSuggestionRepository(api, sessions);
      await _dashboard(tester, sessions, api);
      expect(_entry, findsOneWidget);
      expect(
        AppRouteGuard.redirectFor(
          AppRoutes.adminVenueSuggestions,
          sessions.session,
        ),
        isNull,
      );
      for (final denied in [
        _admin(
          permissions: const [
            'ADMIN_PANEL_ACCESS',
            'MANAGE_VENUE_APPLICATIONS',
          ],
        ),
        _admin(permissions: const ['MANAGE_VENUES']),
        _admin(roles: const ['ROLE_ADMIN', 'ROLE_LISTENER']),
      ]) {
        sessions.replace(denied);
        await tester.pumpAndSettle();
        expect(_entry, findsNothing);
        expect(
          AppRouteGuard.redirectFor(AppRoutes.adminVenueSuggestions, denied),
          isNotNull,
        );
        expect((await repository.list(0)).isSuccess, isFalse);
      }
      expect(api.requests, isEmpty);
    },
  );

  testWidgets(
    'an empty list refreshes to independently readable same-name suggestions',
    (tester) async {
      final sessions = AudienceTestSessions(_admin());
      final rows = <Map<String, Object?>>[];
      final api = RecordingApiClient((_) => _page(rows));
      await _dashboard(tester, sessions, api);
      expect(api.requests, isEmpty);
      await tester.tap(_entry);
      await tester.pumpAndSettle();
      expect(find.text('Henüz mekân önerisi yok.'), findsOneWidget);
      rows.addAll([
        {
          ..._venue,
          'requestId': 'internal-request',
          'recipient': 'private@example.test',
        },
        {
          ..._venue,
          'cityName': 'İstanbul',
          'districtName': 'Kadıköy',
          'liveMusic': 'NO',
        },
        {..._venue, 'venueName': 'Küçük Salon', 'liveMusic': 'UNKNOWN'},
      ]);
      await tester.tap(find.byTooltip('Listeyi yenile'));
      await tester.pumpAndSettle();
      expect(find.text('Şehir Sahnesi'), findsNWidgets(2));
      expect(find.text('Canlı müzik: Bilmiyorum'), findsOneWidget);
      final yes = tester.semantics.find(find.text('Ankara / Çankaya').first);
      final no = tester.semantics.find(find.text('İstanbul / Kadıköy'));
      expect(yes.id, isNot(no.id));
      expect(yes.label, contains('Şehir Sahnesi'));
      expect(yes.label, contains('Canlı müzik: Evet'));
      expect(yes.label, isNot(contains('Kadıköy')));
      expect(no.label, contains('Şehir Sahnesi'));
      expect(no.label, contains('Canlı müzik: Hayır'));
      for (final row in [yes, no]) {
        expect(
          row.getSemanticsData().hasAction(ui.SemanticsAction.tap),
          isFalse,
        );
        expect(row.label, isNot(contains('internal-request')));
        expect(row.label, isNot(contains('private@example.test')));
      }
      await tester.tap(find.text('Şehir Sahnesi').first);
      await tester.pumpAndSettle();
      _expectReads(api, [0, 0]);
      sessions.replace(_admin(permissions: const ['ADMIN_PANEL_ACCESS']));
      await tester.pumpAndSettle();
      expect(find.text('Şehir Sahnesi'), findsNothing);
      expect(find.byTooltip('Listeyi yenile'), findsNothing);
    },
  );

  testWidgets(
    'a malformed answer on page two is not treated as unknown; retry reloads that page',
    (tester) async {
      var invalid = true;
      final api = RecordingApiClient((request) {
        if (request.query!['page'] == 0) {
          return _page([
            for (var i = 1; i <= 20; i++) {..._venue, 'venueName': 'Salon $i'},
          ], total: 21);
        }
        return _page(
          [
            {
              ..._venue,
              'venueName': 'Son öneri',
              'liveMusic': invalid ? null : 'UNKNOWN',
            },
          ],
          index: 1,
          total: 21,
        );
      });
      await _dashboard(tester, AudienceTestSessions(_admin()), api);
      await tester.tap(_entry);
      await tester.pumpAndSettle();
      final next = find.text('Sonraki sayfa');
      await tester.scrollUntilVisible(next, 450);
      await tester.tap(next);
      await tester.pumpAndSettle();
      expect(
        find.text('Mekân önerileri yüklenemedi. Lütfen tekrar dene.'),
        findsOneWidget,
      );
      expect(find.text('Son öneri'), findsNothing);
      expect(find.text('Canlı müzik: Bilmiyorum'), findsNothing);
      invalid = false;
      await tester.tap(find.text('Tekrar dene'));
      await tester.pumpAndSettle();
      expect(find.text('Son öneri'), findsOneWidget);
      expect(find.text('Canlı müzik: Bilmiyorum'), findsOneWidget);
      _expectReads(api, [0, 1, 1]);
    },
  );

  test(
    'a mismatched returned page cannot silently repeat earlier suggestions',
    () async {
      final api = RecordingApiClient((_) => _page([_venue], total: 21));
      final repo = AdminVenueSuggestionRepository(
        api,
        AudienceTestSessions(_admin()),
      );
      expect((await repo.list(1)).error?.code, repo.listError.code);
      _expectReads(api, [1]);
    },
  );
}
