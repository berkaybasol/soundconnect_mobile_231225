import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session.dart';
import 'package:soundconnect_23_12_25codx/core/error/app_error.dart';
import 'package:soundconnect_23_12_25codx/core/network/api_exception.dart';
import 'package:soundconnect_23_12_25codx/modules/admin/data/pending_application_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/admin/domain/pending_application.dart';
import 'package:soundconnect_23_12_25codx/modules/admin/presentation/screens/pending_applications_screen.dart';

import 'support/event_audience_fakes.dart';
import 'support/recording_api_client.dart';

AuthSession session(
  List<String> permissions, {
  List<String> roles = const ['ROLE_ADMIN'],
}) => AuthSession.authenticated(
  token: 'unit-test',
  userId: 'reviewer',
  username: 'reviewer',
  accountStatus: 'ACTIVE',
  roles: roles,
  permissions: permissions,
  expiresAt: DateTime.utc(2100),
  isAdmin: true,
);

const row = {
  'id': 'one',
  'businessName': 'Deneme Stüdyosu',
  'applicantUsername': 'deneme',
  'status': 'PENDING',
  'cityName': 'İzmir',
  'districtName': 'Konak',
  'applicationDate': '2026-11-21T09:00:00Z',
};
const both = [
  'ADMIN_PANEL_ACCESS',
  'MANAGE_VENUE_APPLICATIONS',
  'MANAGE_STUDIO_APPLICATIONS',
];

void main() {
  testWidgets(
    'server permission revocation clears the view without a retry prompt',
    (tester) async {
      final sessions = AudienceTestSessions(session(both));
      final api = RecordingApiClient(
        (_) => throw ApiException(
          const AppError(code: '1102', message: 'Forbidden'),
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: PendingApplicationsScreen(
            sessions: sessions,
            repository: PendingApplicationRepository(api, sessions),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Başvuruları görme yetkin değişti.'), findsOneWidget);
      expect(find.text('Tekrar dene'), findsNothing);
    },
  );

  test(
    'requires panel and kind permissions and excludes listener sessions',
    () {
      expect(
        ApplicationKind.venue.canRead(session(['MANAGE_VENUE_APPLICATIONS'])),
        isFalse,
      );
      final studioOnly = session([
        'ADMIN_PANEL_ACCESS',
        'MANAGE_STUDIO_APPLICATIONS',
      ]);
      expect(ApplicationKind.venue.canRead(studioOnly), isFalse);
      expect(ApplicationKind.studio.canRead(studioOnly), isTrue);
      expect(
        ApplicationKind.studio.canRead(
          session(both, roles: ['ROLE_ADMIN', 'LISTENER']),
        ),
        isFalse,
      );
    },
  );

  testWidgets(
    'late list is discarded on tab change, detail reads the selected id, logout hides it',
    (tester) async {
      final sessions = AudienceTestSessions(session(both));
      final venuePage = Completer<Object?>();
      final api = RecordingApiClient((request) {
        expect(request.method, RecordedHttpMethod.get);
        expect(request.requestContext?.expectedSessionKey, 'reviewer');
        if (request.path.contains('venue-applications')) {
          return venuePage.future;
        }
        if (request.path.endsWith('/pending/one')) {
          return {...row, 'address': 'Örnek sokak'};
        }
        expect(request.query, {'page': 0, 'size': 20});
        return {
          'page': 0,
          'last': true,
          'content': [row],
        };
      });
      await tester.pumpWidget(
        MaterialApp(
          home: PendingApplicationsScreen(
            sessions: sessions,
            repository: PendingApplicationRepository(api, sessions),
          ),
        ),
      );
      await tester.tap(find.text('Stüdyo'));
      await tester.pumpAndSettle();
      venuePage.complete({'page': 0, 'last': true, 'content': []});
      await tester.pump();
      expect(find.text('Deneme Stüdyosu'), findsOneWidget);
      expect(find.text('Örnek sokak'), findsNothing);
      await tester.tap(find.text('Deneme Stüdyosu'));
      await tester.pumpAndSettle();
      expect(
        api.lastRequest.path,
        '/api/v1/admin/studio-applications/pending/one',
      );
      expect(find.text('Örnek sokak'), findsOneWidget);
      sessions.replace(const AuthSession.guest());
      await tester.pump();
      expect(find.text('Örnek sokak'), findsNothing);
    },
  );
}
