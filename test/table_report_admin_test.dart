import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/app/router/app_route_guard.dart';
import 'package:soundconnect_23_12_25codx/app/router/app_routes.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session.dart';
import 'package:soundconnect_23_12_25codx/modules/admin/data/table_report_admin_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/admin/presentation/screens/table_report_admin_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/admin/presentation/screens/table_report_decision_screen.dart';
import 'support/event_audience_fakes.dart';
import 'support/recording_api_client.dart';

const _id = 'fce40f3e-32ea-49c1-8cc5-84d9dc6680c1';
const _report = <String, dynamic>{
  'id': _id,
  'kind': 'MESSAGE',
  'reason': 'MONEY_REQUEST',
  'status': 'OPEN',
  'tableDescription': 'Moda’da akustik buluşma',
  'version': 0,
  'reportedAt': '2026-11-24T16:00:00Z',
  'description': 'Yer için para istendi.',
  'messageText': 'Koltuk için ödeme gönder.',
  'senderUsername': 'ritimci',
  'reporterUsername': 'deniz',
  'messageSentAt': '2026-11-24T15:55:00Z',
  'tableActive': true,
  'messageRemovable': true,
};
AuthSession _admin({bool manage = true}) => AuthSession.authenticated(
  token: 'fixture',
  userId: 'admin',
  username: 'yonetici',
  roles: const ['ROLE_ADMIN'],
  permissions: ['ADMIN_PANEL_ACCESS', if (manage) 'MANAGE_TABLE_GROUP_REPORTS'],
  accountStatus: 'ACTIVE',
  expiresAt: DateTime.utc(2100),
  isAdmin: true,
);

Future<void> _tap(WidgetTester tester, String text) async {
  final matches = find.text(text);
  if (matches.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      find.text(text),
      180,
      scrollable: find.byType(Scrollable).last,
    );
  }
  final item = matches.last;
  await tester.ensureVisible(item);
  await tester.pumpAndSettle();
  await tester.tap(item);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'Masa queue keeps the page on detail return and refreshes the selected type and status',
    (tester) async {
      final sessions = AudienceTestSessions(_admin());
      final api = RecordingApiClient((request) {
        if (request.path.endsWith('/$_id')) return _report;
        final query = request.query!;
        final page = query['page'] as int;
        final empty =
            query['status'] == 'RESOLVED' || query['kind'] == 'INCIDENT';
        return {
          'content': [if (!empty) _report],
          'page': page,
          'size': 20,
          'totalPages': empty ? 0 : 2,
          'totalElements': empty ? 0 : 21,
          'first': page == 0,
          'last': empty || page == 1,
        };
      });
      await tester.pumpWidget(
        MaterialApp(
          home: TableReportAdminScreen(
            sessions: sessions,
            initialSession: sessions.session,
            repository: TableReportAdminRepository(api, sessions),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _tap(tester, 'Sonraki sayfa');
      expect(api.lastRequest.query?['page'], 1);
      await _tap(tester, 'Moda’da akustik buluşma');
      expect(find.text('Bildirenin beyanı'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(api.lastRequest.query?['page'], 1);
      await _tap(tester, 'Tümü');
      await _tap(tester, 'Olay');
      expect(api.lastRequest.query, {
        'status': 'OPEN',
        'kind': 'INCIDENT',
        'page': 0,
        'size': 20,
      });
      expect(
        find.text('Bu filtrelere uygun şikâyet bulunamadı.'),
        findsOneWidget,
      );
      await _tap(tester, 'Açık');
      await _tap(tester, 'Sonuçlanmış');
      final beforeRefresh = api.requests.length;
      await tester.tap(find.byTooltip('Listeyi yenile'));
      await tester.pumpAndSettle();
      expect(api.requests.length, beforeRefresh + 1);
      expect(api.lastRequest.query, {
        'status': 'RESOLVED',
        'kind': 'INCIDENT',
        'page': 0,
        'size': 20,
      });
      expect(
        find.text('Bu filtrelere uygun şikâyet bulunamadı.'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'revoking access closes the action while its confirmation is visible',
    (tester) async {
      final access = ValueNotifier(true);
      addTearDown(access.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: TableReportDecisionScreen(
            report: TableAdminReport.fromJson(_report),
            access: access,
          ),
        ),
      );
      await _tap(tester, 'Masayı yayından kaldır');
      await tester.enterText(
        find.byType(TextFormField),
        'İlan açıklaması incelendi.',
      );
      await _tap(tester, 'Devam et');
      expect(find.text('Masayı kaldır ve kararı kaydet'), findsOneWidget);
      access.value = false;
      await tester.pumpAndSettle();
      expect(find.text('Masayı kaldır ve kararı kaydet'), findsNothing);
      expect(find.text('İlan açıklaması incelendi.'), findsNothing);
      await _tap(tester, 'Vazgeç');
      expect(
        find.text(TableReportAdminRepository.accessError.message),
        findsOneWidget,
      );
    },
  );

  test('a panel user without the Masa permission does not reach its queue', () {
    expect(
      AppRouteGuard.redirectFor(
        AppRoutes.adminTableReports,
        _admin(manage: false),
      ),
      isNotNull,
    );
    expect(
      AppRouteGuard.redirectFor(AppRoutes.adminTableReports, _admin()),
      isNull,
    );
  });

  testWidgets(
    'selected message survives a lost decision response and reopens from history',
    (tester) async {
      final sessions = AudienceTestSessions(_admin());
      var record = {..._report};
      var decisions = 0;
      final api = RecordingApiClient((r) {
        if (r.method == RecordedHttpMethod.post) {
          expect(r.body, {
            'decision': 'REMOVE_MESSAGE',
            'expectedVersion': 0,
            'resolutionNote': 'Ödeme talebi doğrulandı.',
          });
          decisions++;
          record = {
            ...record,
            'status': 'RESOLVED',
            'decision': 'REMOVE_MESSAGE',
            'version': 1,
            'resolutionNote': 'Ödeme talebi doğrulandı.',
            'reviewerUsername': 'yonetici',
            'reviewedAt': '2026-11-24T16:05:00Z',
            'messageRemovable': false,
          };
          throw Exception('response lost after commit');
        }
        if (r.path.endsWith('/$_id')) return record;
        final content = [if (r.query?['status'] == record['status']) record];
        return {
          'content': content,
          'page': 0,
          'size': 20,
          'totalPages': content.isEmpty ? 0 : 1,
          'totalElements': content.length,
          'first': true,
          'last': true,
        };
      });
      await tester.pumpWidget(
        MaterialApp(
          home: TableReportAdminScreen(
            sessions: sessions,
            initialSession: sessions.session,
            repository: TableReportAdminRepository(api, sessions),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _tap(tester, 'Moda’da akustik buluşma');
      expect(find.text('Bildirenin beyanı'), findsOneWidget);
      await _tap(tester, 'Karar ver');
      await _tap(tester, 'Bildirilen mesajı kaldır');
      await _tap(tester, 'Devam et');
      expect(find.text('5–500 karakterlik bir gerekçe yaz.'), findsOneWidget);
      await tester.enterText(
        find.byType(TextFormField),
        'Ödeme talebi doğrulandı.',
      );
      await _tap(tester, 'Devam et');
      await _tap(tester, 'Vazgeç');
      expect(decisions, 0);
      await _tap(tester, 'Devam et');
      await _tap(tester, 'Mesajı kaldır ve kararı kaydet');
      expect(find.text('Karar kaydı'), findsOneWidget);
      await _tap(tester, 'Sonuçlanmış şikâyetlere dön');
      await _tap(tester, 'Moda’da akustik buluşma');
      expect(find.text('Ödeme talebi doğrulandı.'), findsOneWidget);
      expect(decisions, 1);
    },
  );
}
