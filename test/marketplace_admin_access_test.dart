import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/app/router/app_route_guard.dart';
import 'package:soundconnect_23_12_25codx/app/router/app_routes.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session.dart';
import 'package:soundconnect_23_12_25codx/core/network/api_client.dart';
import 'package:soundconnect_23_12_25codx/modules/admin/data/marketplace_report_admin_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/admin/domain/marketplace_report_admin.dart';
import 'package:soundconnect_23_12_25codx/modules/admin/presentation/screens/marketplace_report_admin_screen.dart';
import 'support/event_audience_fakes.dart';
import 'marketplace_test_support.dart' show marketListingJson;

void main() {
  test(
    'moderation evidence survives a missing current listing and reporter',
    () {
      final report = MarketplaceAdminReport.fromJson(_reportJson());
      expect(report.evidence.title, 'Fender Player Stratocaster');
      expect(report.evidence.priceMinor, isNotNull);
      expect(report.status, 'OPEN');
    },
  );

  test(
    'remove decision sends report version and preserves review identity',
    () async {
      final sessions = AudienceTestSessions(_admin());
      final api = _Api();
      final report = MarketplaceAdminReport.fromJson(_reportJson());
      final request = MarketplaceReportAdminRepository(
        api,
        sessions,
      ).review(report, removeListing: true, note: '  Yanıltıcı ürün bilgisi  ');
      expect(api.path, '/api/v1/admin/marketplace/reports/report-id/review');
      expect(api.body, {
        'expectedVersion': 2,
        'decision': 'REMOVE_LISTING',
        'resolutionNote': 'Yanıltıcı ürün bilgisi',
      });
      api.response.complete(
        _reportJson()..addAll({
          'version': 3,
          'status': 'ACTIONED',
          'resolutionNote': 'Yanıltıcı ürün bilgisi',
        }),
      );
      expect((await request).data?.version, 3);
      sessions.dispose();
    },
  );
  test(
    'listener authority vetoes moderation even with its permission',
    () async {
      for (final session in [
        const AuthSession.guest(),
        _admin(permission: false),
        _admin(roles: ['ROLE_LISTENER', 'ROLE_ADMIN']),
        _admin(status: 'PASSIVE'),
      ]) {
        expect(canManageMarketplaceReports(session), isFalse);
        expect(
          AppRouteGuard.redirectFor(AppRoutes.adminMarketplaceReports, session),
          isNotNull,
        );
        final api = _Api();
        final sessions = AudienceTestSessions(session);
        final result = await MarketplaceReportAdminRepository(
          api,
          sessions,
        ).load();
        expect(result.isSuccess, isFalse);
        expect(api.calls, 0);
        sessions.dispose();
      }
      expect(canManageMarketplaceReports(_admin()), isTrue);
    },
  );

  test(
    'moderation request is token fenced and rejects A to B to A result',
    () async {
      final original = _admin();
      final sessions = AudienceTestSessions(original);
      final api = _Api();
      final future = MarketplaceReportAdminRepository(api, sessions).load();
      expect(api.context?.expectedSessionKey, original.userId);
      expect(api.context?.expectedToken, original.token);
      sessions.replace(const AuthSession.guest());
      sessions.replace(original);
      api.response.complete({'content': [], 'last': true});
      expect((await future).isSuccess, isFalse);
      sessions.dispose();
    },
  );

  testWidgets('revoked moderation screen discards in-flight report data', (
    tester,
  ) async {
    final sessions = AudienceTestSessions(_admin());
    final api = _Api();
    await tester.pumpWidget(
      MaterialApp(
        home: MarketplaceReportAdminScreen(
          repository: MarketplaceReportAdminRepository(api, sessions),
          sessions: sessions,
        ),
      ),
    );
    sessions.replace(const AuthSession.guest());
    await tester.pump();
    api.response.complete({'content': [], 'last': true});
    await tester.pumpAndSettle();
    expect(find.text('İnceleme yetkisi gerekli.'), findsOneWidget);
    expect(find.text('Bu durumda bildirim yok.'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    sessions.dispose();
  });
}

AuthSession _admin({
  bool permission = true,
  List<String> roles = const ['ROLE_ADMIN'],
  String status = 'ACTIVE',
}) => AuthSession.authenticated(
  token: 'moderator-token',
  userId: 'moderator-id',
  username: 'moderator',
  accountStatus: status,
  roles: roles,
  permissions: permission ? ['MANAGE_MARKETPLACE_REPORTS'] : [],
  expiresAt: DateTime.utc(2100),
  isAdmin: true,
);

class _Api extends Fake implements ApiClient {
  final response = Completer<Object?>();
  int calls = 0;
  ApiRequestContext? context;
  String? path;
  Object? body;
  @override
  Future<T> request<T>(
    ApiHttpMethod method,
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    T Function(Object?)? decoder,
    ApiRequestContext? requestContext,
  }) async {
    calls++;
    this.path = path;
    this.body = body;
    context = requestContext;
    return decoder!(await response.future);
  }
}

Map<String, dynamic> _reportJson() => {
  'id': 'report-id',
  'version': 2,
  'listingId': null,
  'reporterUserId': null,
  'status': 'OPEN',
  'reason': 'MISLEADING',
  'description': 'Ürün bilgisi yanlış.',
  'reportedAt': '2026-09-20T10:00:00Z',
  'evidence': marketListingJson(),
};
