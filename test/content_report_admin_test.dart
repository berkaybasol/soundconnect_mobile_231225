import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/app/router/app_route_guard.dart';
import 'package:soundconnect_23_12_25codx/app/router/app_routes.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session.dart';
import 'package:soundconnect_23_12_25codx/modules/admin/data/admin_user_directory_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/admin/data/content_report_admin_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/admin/presentation/screens/content_report_admin_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/admin/presentation/widgets/admin_panel_frame.dart';
import 'support/event_audience_fakes.dart';
import 'support/recording_api_client.dart';

const _id = '19664ff3-fcce-4a89-b2ae-c3fc365ad742';
const _user = 'f5fdddc4-cad0-41ab-8845-b17716b45482';
const _record = {
  'id': _id,
  'version': 0,
  'kind': 'COMMENT',
  'reason': 'HARASSMENT',
  'status': 'OPEN',
  'targetLabel': 'Bildirilen yanıt',
  'reportedAt': '2026-11-25T05:00:00Z',
  'reporterUsername': 'bildiren',
  'evidenceText': 'Bildirilen örnek yorum.',
  'parentText': 'Ana yorumun metni.',
  'description': 'Yanıtta hakaret var.',
  'removable': true,
};

AuthSession _admin({bool authorized = true}) => AuthSession.authenticated(
  token: 'test',
  userId: 'admin',
  username: 'yönetici',
  roles: const ['ROLE_ADMIN'],
  accountStatus: 'ACTIVE',
  permissions: [
    'ADMIN_PANEL_ACCESS',
    'READ_USERS',
    if (authorized) 'MANAGE_CONTENT_REPORTS',
  ],
  expiresAt: DateTime.utc(2100),
  isAdmin: true,
);

Future<void> _tap(WidgetTester tester, String label) async {
  if (find.text(label).evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      find.text(label),
      160,
      scrollable: find.byType(Scrollable).last,
    );
  }
  final target = find.text(label).last;
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

void main() {
  test(
    'report tab, guarded route, and direct requests require report permission',
    () async {
      final sessions = AudienceTestSessions(_admin(authorized: false));
      final api = RecordingApiClient(
        (_) => throw StateError('unexpected request'),
      );
      final repo = ContentReportAdminRepository(api, sessions);
      expect(AdminPanelSection.reports.available(sessions.session), isFalse);
      expect(
        AppRouteGuard.redirectFor(
          AppRoutes.adminContentReports,
          sessions.session,
        ),
        isNotNull,
      );
      expect(
        (await repo.detail(_id)).error,
        ContentReportAdminRepository.accessError,
      );
      expect(api.requests, isEmpty);
      sessions.replace(_admin());
      expect(AdminPanelSection.reports.available(sessions.session), isTrue);
      expect(
        AppRouteGuard.redirectFor(
          AppRoutes.adminContentReports,
          sessions.session,
        ),
        isNull,
      );
    },
  );

  test(
    'profile removals are rejected locally and content reports cannot open an account',
    () async {
      final sessions = AudienceTestSessions(_admin());
      final api = RecordingApiClient(
        (_) => throw StateError('unexpected request'),
      );
      final repo = ContentReportAdminRepository(api, sessions);
      final profile = AdminContentReport.fromJson({
        ..._record,
        'kind': 'STUDIO_PROFILE',
        'profileUserId': _user,
      });
      expect(profile.profileUserId, _user);
      expect(
        (await repo.review(
          profile,
          ContentReportDecision.remove,
          'Uygun gerekçe',
        )).isSuccess,
        isFalse,
      );
      expect(api.requests, isEmpty);
      final comment = AdminContentReport.fromJson({
        ..._record,
        'profileUserId': _user,
      });
      expect(comment.profileUserId, isNull);
    },
  );

  testWidgets(
    'moderator removes the specific reply, reads back on lost acknowledgement and opens history',
    (tester) async {
      final sessions = AudienceTestSessions(_admin());
      Map<String, Object?> record = {..._record, 'profileUserId': _user};
      var mutations = 0;
      final api = RecordingApiClient((request) {
        if (request.method == RecordedHttpMethod.post) {
          expect(request.path, '/api/v1/admin/content-reports/$_id/review');
          expect(request.body, {
            'decision': 'REMOVE_CONTENT',
            'expectedVersion': 0,
            'resolutionNote': 'Yalnızca seçilen yanıt incelendi.',
          });
          mutations++;
          record = {
            ...record,
            'status': 'RESOLVED',
            'decision': 'REMOVE_CONTENT',
            'version': 1,
            'resolutionNote': 'Yalnızca seçilen yanıt incelendi.',
            'reviewedAt': '2026-11-25T05:01:00Z',
            'reviewerUsername': 'yonetici',
            'removable': false,
          };
          throw Exception('response lost after saving');
        }
        if (request.path.endsWith('/$_id')) return record;
        expect(request.path, '/api/v1/admin/content-reports');
        expect(request.query?['size'], 20);
        final rows = [if (request.query?['status'] == record['status']) record];
        return {
          'content': rows,
          'page': 0,
          'size': 20,
          'first': true,
          'last': true,
          'totalPages': rows.isEmpty ? 0 : 1,
          'totalElements': rows.length,
        };
      });
      await tester.pumpWidget(
        MaterialApp(
          home: ContentReportAdminScreen(
            sessions: sessions,
            initialSession: sessions.session,
            repository: ContentReportAdminRepository(api, sessions),
            userDirectory: AdminUserDirectoryRepository(api, sessions),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _tap(tester, 'Bildirilen yanıt');
      expect(find.text('Bildirilen örnek yorum.'), findsOneWidget);
      expect(find.text('Ana yorumun metni.'), findsOneWidget);
      expect(find.text('Hesap detayını aç'), findsNothing);
      await _tap(tester, 'Bildirilen içeriği kaldır');
      await tester.enterText(
        find.byType(TextFormField),
        'Yalnızca seçilen yanıt incelendi.',
      );
      await _tap(tester, 'Kararı kaydet');
      await _tap(tester, 'Sonuçlanmış şikâyetlere dön');
      expect(api.lastRequest.query?['status'], 'RESOLVED');
      await _tap(tester, 'Bildirilen yanıt');
      expect(find.text('Yalnızca seçilen yanıt incelendi.'), findsOneWidget);
      expect(mutations, 1);
      sessions.replace(_admin(authorized: false));
      await tester.pumpAndSettle();
      expect(
        find.text(ContentReportAdminRepository.accessError.message),
        findsOneWidget,
      );
      expect(find.text('Bildirilen örnek yorum.'), findsNothing);
    },
  );
}
