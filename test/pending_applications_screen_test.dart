import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/app/router/app_router.dart';
import 'package:soundconnect_23_12_25codx/app/router/app_routes.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session_manager.dart';
import 'package:soundconnect_23_12_25codx/core/di/service_locator.dart';
import 'package:soundconnect_23_12_25codx/core/error/app_error.dart';
import 'package:soundconnect_23_12_25codx/core/network/api_client.dart';
import 'package:soundconnect_23_12_25codx/core/network/api_exception.dart';
import 'package:soundconnect_23_12_25codx/modules/admin/data/pending_application_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/admin/domain/pending_application.dart';
import 'package:soundconnect_23_12_25codx/modules/admin/presentation/screens/pending_applications_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/admin/presentation/widgets/admin_panel_frame.dart';
import 'package:soundconnect_23_12_25codx/modules/admin/presentation/widgets/admin_visual_theme.dart';

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
    'named studio entry opens its queue, keeps the frame on detail and refreshes on return',
    (tester) async {
      final sessions = AudienceTestSessions(session(both));
      final api = RecordingApiClient((request) {
        if (request.path.endsWith('/review/one')) {
          return {...row, 'phone': '05550000021'};
        }
        return {
          'page': 0,
          'last': true,
          'content': [row],
        };
      });
      serviceLocator.registerSingleton<AuthSessionManager>(sessions);
      serviceLocator.registerSingleton<ApiClient>(api);
      addTearDown(() => serviceLocator.reset());
      const shellMarker = Key('test-applications-frame');
      await tester.pumpWidget(
        MaterialApp(
          onGenerateRoute: AppRouter.onGenerateRoute,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => Navigator.pushNamed(
                  context,
                  AppRoutes.adminApplications,
                  arguments: AdminApplicationEntry(
                    kind: ApplicationKind.studio,
                    frame: (body) => Scaffold(key: shellMarker, body: body),
                  ),
                ),
                child: const Text('Kuyruğu aç'),
              ),
            ),
          ),
        ),
      );
      await tapVisible(tester, find.text('Kuyruğu aç'));
      expect(find.byKey(shellMarker), findsOneWidget);
      expect(find.text('Stüdyo başvuruları'), findsOneWidget);
      expect(find.byType(ChoiceChip), findsNothing);
      expect(
        api.requests.single.path,
        endsWith('/studio-applications/pending'),
      );
      await tapVisible(tester, find.text(row['businessName']!));
      expect(find.byKey(shellMarker), findsOneWidget);
      expect(find.text('0555 000 00 21'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Telefon')).dy,
        lessThan(tester.getTopLeft(find.text('Başvuran')).dy),
      );
      await tapVisible(tester, find.text('Stüdyo başvuruları'));
      expect(api.requests.map((r) => r.path), [
        '/api/v1/admin/studio-applications/pending',
        '/api/v1/admin/studio-applications/review/one',
        '/api/v1/admin/studio-applications/pending',
      ]);
      await tapVisible(tester, find.text('Başvurular'));
      expect(find.text('Kuyruğu aç'), findsOneWidget);
    },
  );

  testWidgets('a denied kind never loads another queue as a fallback', (
    tester,
  ) async {
    final sessions = AudienceTestSessions(
      session([both.first, ApplicationKind.venue.permission]),
    );
    final api = RecordingApiClient(
      (_) => throw StateError('Unexpected request'),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: PendingApplicationsScreen(
          initialKind: ApplicationKind.studio,
          sessions: sessions,
          repository: PendingApplicationRepository(api, sessions),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Başvuruları görme yetkin değişti.'), findsOneWidget);
    expect(find.byType(ChoiceChip), findsNothing);
    await tester.tap(find.byTooltip('Listeyi yenile'));
    expect(api.requests, isEmpty);
  });

  testWidgets(
    'a named entry cannot fetch under an admin session replaced before its first frame',
    (tester) async {
      final sessions = AudienceTestSessions(session(both));
      final api = RecordingApiClient(
        (_) => throw StateError('Unexpected request'),
      );
      serviceLocator.registerSingleton<AuthSessionManager>(sessions);
      serviceLocator.registerSingleton<ApiClient>(api);
      addTearDown(() => serviceLocator.reset());
      await tester.pumpWidget(
        MaterialApp(
          onGenerateRoute: AppRouter.onGenerateRoute,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () {
                  Navigator.pushNamed(
                    context,
                    AppRoutes.adminApplications,
                    arguments: ApplicationKind.studio,
                  );
                  sessions.replace(session(both));
                },
                child: const Text('Kuyruğu aç'),
              ),
            ),
          ),
        ),
      );
      await tapVisible(tester, find.text('Kuyruğu aç'));
      expect(find.text('Başvuruları görme yetkin değişti.'), findsOneWidget);
      expect(api.requests, isEmpty);
    },
  );

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
        if (request.path.endsWith('/review/one')) {
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
        '/api/v1/admin/studio-applications/review/one',
      );
      expect(find.text('Örnek sokak'), findsOneWidget);
      sessions.replace(const AuthSession.guest());
      await tester.pump();
      expect(find.text('Örnek sokak'), findsNothing);
    },
  );

  for (final kind in ApplicationKind.values) {
    for (final approve in [true, false]) {
      testWidgets(
        '${kind.name} ${approve ? 'approve' : 'reject'} confirms once and shows server receipt',
        (tester) async {
          final sessions = AudienceTestSessions(
            session([both.first, kind.permission]),
          );
          Map<String, Object?> detail = {
            ...row,
            'phone': '+90 555 000 0018',
            'address': 'Moda Cad.',
          };
          final prefix = '/api/v1/admin/${kind.pathName}-applications';
          var listReads = 0;
          var writes = 0;
          final api = RecordingApiClient((request) {
            expect(request.requestContext?.expectedCredentialRevision, 0);
            expect(request.requestContext?.expectedToken, 'unit-test');
            if (request.path == '$prefix/pending') {
              listReads++;
              return {
                'page': 0,
                'last': true,
                'content': writes == 0 ? [row] : [],
              };
            }
            if (request.path == '$prefix/review/one') return detail;
            expect(
              request.path,
              '$prefix/${approve ? 'approve' : 'reject'}/one',
            );
            expect(request.method, RecordedHttpMethod.post);
            expect(request.query, isNull);
            expect(request.body, approve ? null : {'reason': 'Eksik adres'});
            writes++;
            detail = {
              ...detail,
              'status': approve ? 'APPROVED' : 'REJECTED',
              'reviewedByUsername': 'selin',
              'decisionDate': '2026-11-22T07:44:00Z',
              'rejectionReason': approve ? null : 'Eksik adres',
            };
            return {'id': 'one'};
          });
          await openReview(tester, sessions, api);
          expect(find.text('+90 555 000 0018'), findsOneWidget);
          final action = approve ? 'Onayla' : 'Reddet';
          final confirm = approve ? 'Başvuruyu onayla' : 'Başvuruyu reddet';
          await tapVisible(tester, find.text(action));
          await tapVisible(tester, find.text('Vazgeç'));
          expect(writes, 0);
          await tapVisible(tester, find.text(action));
          expect(
            find.widgetWithText(AdminBrandButton, confirm),
            findsOneWidget,
          );
          if (!approve) {
            await tapVisible(
              tester,
              find.widgetWithText(FilledButton, confirm),
            );
            expect(find.text('Ret gerekçesini yaz.'), findsOneWidget);
            expect(writes, 0);
            await tester.enterText(
              find.byType(TextFormField),
              '   Eksik adres   ',
            );
            expect(
              find.text('Başvuru sahibi bu açıklamayı görecek.'),
              findsOneWidget,
            );
          }
          await tapVisible(tester, find.widgetWithText(FilledButton, confirm));
          expect(writes, 1);
          expect(find.text('Karar kaydı'), findsOneWidget);
          expect(find.text('selin'), findsOneWidget);
          expect(
            find.text(approve ? 'Onaylandı' : 'Reddedildi'),
            findsOneWidget,
          );
          if (!approve) expect(find.text('Eksik adres'), findsOneWidget);
          expect(find.text('Reddet'), findsNothing);
          await tapVisible(tester, find.text('Başvurulara dön'));
          expect(listReads, 2);
          expect(find.text(row['businessName']!), findsNothing);
        },
      );
    }
  }

  testWidgets(
    'lost or conflicting decision response recovers receipt with GET, user retry never resends POST',
    (tester) async {
      final sessions = AudienceTestSessions(session(both));
      var reads = 0;
      final api = RecordingApiClient((request) {
        if (request.path.endsWith('/pending')) {
          return {
            'page': 0,
            'last': true,
            'content': [row],
          };
        }
        if (request.method == RecordedHttpMethod.post) {
          throw ApiException(
            const AppError(code: '1602', message: 'Decision conflict'),
          );
        }
        reads++;
        if (reads == 1) return row;
        if (reads == 2) {
          throw ApiException(
            const AppError(code: 'network', message: 'Bağlantı kesildi.'),
          );
        }
        return {
          ...row,
          'status': 'REJECTED',
          'reviewedByUsername': 'otherAdmin',
          'rejectionReason': 'Eksik.',
        };
      });
      await openReview(tester, sessions, api);
      expect(find.text('Telefon'), findsOneWidget);
      expect(find.text('Belirtilmemiş'), findsWidgets);
      await tapVisible(tester, find.text('Onayla'));
      await tapVisible(
        tester,
        find.widgetWithText(FilledButton, 'Başvuruyu onayla'),
      );
      expect(find.text('Onayla'), findsNothing);
      await tapVisible(tester, find.text('Tekrar dene'));
      expect(find.text('otherAdmin'), findsOneWidget);
      expect(find.textContaining('sen incelerken'), findsOneWidget);
      expect(
        api.requests.where((r) => r.method == RecordedHttpMethod.post),
        hasLength(1),
      );
    },
  );

  testWidgets(
    'pending after uncertain write retains reason for deliberate retry',
    (tester) async {
      final sessions = AudienceTestSessions(session(both));
      final api = RecordingApiClient((request) {
        if (request.path.endsWith('/pending')) {
          return {
            'page': 0,
            'last': true,
            'content': [row],
          };
        }
        if (request.method == RecordedHttpMethod.post) {
          throw TimeoutException('transport');
        }
        return row;
      });
      await openReview(tester, sessions, api);
      await tapVisible(tester, find.text('Reddet'));
      await tester.enterText(find.byType(TextFormField), 'Adres eksik');
      await tapVisible(
        tester,
        find.widgetWithText(FilledButton, 'Başvuruyu reddet'),
      );
      expect(find.textContaining('Karar doğrulanamadı'), findsOneWidget);
      await tapVisible(tester, find.text('Reddet'));
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField))
            .controller!
            .text,
        'Adres eksik',
      );
      expect(
        api.requests.where((r) => r.method == RecordedHttpMethod.post),
        hasLength(1),
      );
    },
  );

  for (final approve in [true, false]) {
    testWidgets(
      'unverified venue email explains ${approve ? 'approval' : 'rejection'} after reading the current status',
      (tester) async {
        final sessions = AudienceTestSessions(session(both));
        final api = RecordingApiClient((request) {
          if (request.path.endsWith('/pending')) {
            return {
              'page': 0,
              'last': true,
              'content': [row],
            };
          }
          if (request.method == RecordedHttpMethod.post) {
            throw ApiException(
              const AppError(
                code: '1613',
                message: 'Email verification required',
              ),
            );
          }
          return row;
        });
        await openReview(tester, sessions, api);
        await tapVisible(tester, find.text(approve ? 'Onayla' : 'Reddet'));
        if (!approve) {
          await tester.enterText(find.byType(TextFormField), 'Adres eksik');
        }
        await tapVisible(
          tester,
          find.widgetWithText(
            FilledButton,
            approve ? 'Başvuruyu onayla' : 'Başvuruyu reddet',
          ),
        );
        expect(
          find.textContaining('e-posta adresini doğruladıktan sonra'),
          findsOneWidget,
        );
        expect(find.text('İnceleme bekliyor'), findsOneWidget);
        expect(api.lastRequest.path, endsWith('/review/one'));
        expect(
          api.requests.where((r) => r.method == RecordedHttpMethod.post),
          hasLength(1),
        );
      },
    );
  }

  testWidgets(
    'revocation while confirming hides the form and applicant data and never writes',
    (tester) async {
      final sessions = AudienceTestSessions(session(both));
      final api = RecordingApiClient(
        (request) => request.path.endsWith('/pending')
            ? {
                'page': 0,
                'last': true,
                'content': [row],
              }
            : {...row, 'phone': '5550000018'},
      );
      await openReview(tester, sessions, api);
      await tapVisible(tester, find.text('Reddet'));
      await tester.enterText(
        find.byType(TextFormField),
        'Özel başvuru açıklaması',
      );
      sessions.replace(const AuthSession.guest());
      await tester.pumpAndSettle();
      expect(find.byType(TextFormField), findsNothing);
      expect(find.textContaining('Özel başvuru'), findsNothing);
      expect(find.text('5550000018'), findsNothing);
      expect(
        api.requests.where((r) => r.method == RecordedHttpMethod.post),
        isEmpty,
      );
    },
  );

  testWidgets(
    'small screen, large type and keyboard allow reason and submit without overflow',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 640);
      addTearDown(tester.view.reset);
      final sessions = AudienceTestSessions(session(both));
      final api = RecordingApiClient(
        (request) => request.path.endsWith('/pending')
            ? {
                'page': 0,
                'last': true,
                'content': [row],
              }
            : row,
      );
      await openReview(tester, sessions, api, scale: 1.65, dark: true);
      await tester.scrollUntilVisible(
        find.text('Reddet'),
        180,
        scrollable: find.byType(Scrollable).first,
      );
      await tapVisible(tester, find.text('Reddet'));
      await tester.enterText(find.byType(TextFormField), 'Adres eksik');
      tester.view.viewInsets = const FakeViewPadding(bottom: 260);
      await tester.pumpAndSettle();
      final submit = find.widgetWithText(FilledButton, 'Başvuruyu reddet');
      await tester.ensureVisible(submit);
      await tester.pumpAndSettle();
      expect(submit.hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  test(
    'invalid reason or a stale session cannot dispatch a decision',
    () async {
      final entry = session(both);
      final sessions = AudienceTestSessions(entry);
      final api = RecordingApiClient(
        (_) => throw StateError('Unexpected transport call'),
      );
      final repo = PendingApplicationRepository(api, sessions);
      for (final reason in ['   ', 'a' * 501, '😀' * 251]) {
        expect(
          (await repo.decide(
            entry,
            ApplicationKind.venue,
            'one',
            approve: false,
            reason: reason,
          )).error?.code,
          'invalid_reason',
        );
      }
      sessions.replace(const AuthSession.guest());
      expect(
        (await repo.decide(
          entry,
          ApplicationKind.studio,
          'one',
          approve: true,
        )).error?.code,
        'access_changed',
      );
      expect(api.requests, isEmpty);
    },
  );

  testWidgets(
    'double confirm and taps during a pending POST issue one decision',
    (tester) async {
      final sessions = AudienceTestSessions(session(both));
      final write = Completer<Object?>();
      final api = RecordingApiClient((request) {
        if (request.path.endsWith('/pending')) {
          return {
            'page': 0,
            'last': true,
            'content': [row],
          };
        }
        if (request.method == RecordedHttpMethod.post) return write.future;
        return {...row, 'status': write.isCompleted ? 'APPROVED' : 'PENDING'};
      });
      await openReview(tester, sessions, api);
      await tapVisible(tester, find.text('Onayla'));
      final submit = find.widgetWithText(FilledButton, 'Başvuruyu onayla');
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.tap(submit, warnIfMissed: false);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Reddet'))
            .onPressed,
        isNull,
      );
      expect(
        api.requests.where((r) => r.method == RecordedHttpMethod.post),
        hasLength(1),
      );
      write.complete({'id': 'one'});
      await tester.pumpAndSettle();
      expect(find.text('Onaylandı'), findsOneWidget);
    },
  );

  testWidgets(
    'server write denial hides the applicant and blocks readback and repeat',
    (tester) async {
      final sessions = AudienceTestSessions(session(both));
      final api = RecordingApiClient((request) {
        if (request.path.endsWith('/pending')) {
          return {
            'page': 0,
            'last': true,
            'content': [row],
          };
        }
        if (request.method == RecordedHttpMethod.post) {
          throw ApiException(
            const AppError(code: '1102', message: 'Forbidden'),
          );
        }
        return {...row, 'phone': '+90 555 000 0018'};
      });
      await openReview(tester, sessions, api);
      await tapVisible(tester, find.text('Onayla'));
      await tapVisible(
        tester,
        find.widgetWithText(FilledButton, 'Başvuruyu onayla'),
      );
      expect(find.text('Başvuruları görme yetkin değişti.'), findsOneWidget);
      expect(find.text('+90 555 000 0018'), findsNothing);
      expect(find.text('Tekrar dene'), findsNothing);
      expect(api.lastRequest.method, RecordedHttpMethod.post);
    },
  );
}

Future<void> openReview(
  WidgetTester tester,
  AudienceTestSessions sessions,
  RecordingApiClient api, {
  double scale = 1,
  bool dark = false,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: dark ? ThemeData.dark() : ThemeData.light(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: PendingApplicationsScreen(
        sessions: sessions,
        repository: PendingApplicationRepository(api, sessions),
      ),
    ),
  );
  await tester.pumpAndSettle();
  expect(find.text('Telefon'), findsNothing);
  await tapVisible(tester, find.text(row['businessName']!));
}

Future<void> tapVisible(WidgetTester tester, Finder target) async {
  if (target.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      target,
      150,
      scrollable: find.byType(Scrollable).first,
    );
  }
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}
