import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session.dart';
import 'package:soundconnect_23_12_25codx/core/error/app_error.dart';
import 'package:soundconnect_23_12_25codx/core/network/api_exception.dart';
import 'package:soundconnect_23_12_25codx/modules/admin/data/collab_report_admin_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/admin/domain/collab_report_admin.dart';
import 'package:soundconnect_23_12_25codx/modules/admin/domain/collab_report_admin_access.dart';
import 'package:soundconnect_23_12_25codx/modules/admin/presentation/screens/collab_report_admin_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/admin/presentation/screens/collab_report_review_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/admin/presentation/widgets/application_review_widgets.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/domain/collab_types.dart';

import 'support/event_audience_fakes.dart';
import 'support/recording_api_client.dart';

const reportId = 'a0000000-0000-4000-8000-000000000001';
const title = 'Caz gecesi için gitarist';
const openReport = <String, dynamic>{
  'id': reportId,
  'version': 3,
  'status': 'OPEN',
  'reason': 'MISLEADING',
  'details': 'Tarih bilgisi yanlış.',
  'reportedAt': '2026-11-22T15:00:00Z',
  'listingId': 'listing',
  'listingTitle': title,
  'listingDescription': 'Cuma akşamı sahneye çıkacak gitarist arıyoruz.',
  'listingStatus': 'CLOSED',
  'listingStatusAtReport': 'OPEN',
  'hasListingEvidence': true,
  'publisherActorId': 'studio',
  'publisherDisplayName': 'Caz Stüdyo',
  'cadence': 'EXTRA',
  'wantedType': 'MUSICIAN',
  'city': {'id': 'city', 'name': 'Ankara'},
  'instrument': {'id': 'instrument', 'name': 'Gitar'},
  'listingGenres': ['Caz'],
  'reporterUserId': 'reporter',
  'reporterUsername': 'deniz',
};

AuthSession reviewer() => AuthSession.authenticated(
  token: 'test-token',
  userId: 'reviewer',
  username: 'moderator',
  roles: const ['ROLE_ADMIN'],
  permissions: const [collabReportAdminPermission],
  accountStatus: 'ACTIVE',
  expiresAt: DateTime.utc(2100),
  isAdmin: true,
);

Map<String, dynamic> closedReport(CollabReportDecision decision, String note) =>
    {
      ...openReport,
      'version': 4,
      'status': decision.resultingStatus.apiValue,
      'reviewDecision': decision.apiValue,
      'resolutionNote': note,
      'reviewedAt': '2026-11-23T09:00:00Z',
      'reviewedByUserId': 'reviewer',
    };

Map<String, dynamic> page(
  List<Map<String, dynamic>> items, {
  int index = 0,
  bool last = true,
}) => {
  'page': index,
  'size': 20,
  'last': last,
  'first': index == 0,
  'totalPages': last ? index + 1 : index + 2,
  'totalElements': items.length,
  'content': items,
};

Future<void> openQueue(
  WidgetTester tester,
  AudienceTestSessions sessions,
  RecordingApiClient api,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: CollabReportAdminScreen(
        sessions: sessions,
        repository: CollabReportAdminRepository(api, sessions),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> tapText(WidgetTester tester, String label) async {
  final matches = find.text(label);
  if (matches.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      matches,
      240,
      scrollable: find.byType(Scrollable).first,
    );
  }
  final target = matches.last;
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Finder labeledValue(String label, String value) => find.descendant(
  of: find.widgetWithText(ApplicationInfoLine, label),
  matching: find.text(value),
);

void main() {
  for (final decision in CollabReportDecision.values) {
    testWidgets(
      '${decision.apiValue} validates the reason and the same record can be reopened from history',
      (tester) async {
        final sessions = AudienceTestSessions(reviewer());
        var report = openReport;
        const note = 'Tarih bilgisi incelendi.';
        final api = RecordingApiClient((r) {
          if (r.method == RecordedHttpMethod.post) {
            expect(r.body, {
              'decision': decision.apiValue,
              'expectedVersion': 3,
              'resolutionNote': note,
            });
            report = closedReport(decision, note);
            if (decision == CollabReportDecision.dismiss) {
              report = {...report, 'reviewedByUsername': 'moderatör'};
            }
            return report;
          }
          if (r.path.endsWith('/$reportId')) return report;
          return page([if (report['status'] == r.query?['status']) report]);
        });
        await openQueue(tester, sessions, api);
        await tapText(tester, title);
        expect(find.text('Bildirim anındaki ilan'), findsOneWidget);
        expect(labeledValue('Bildiren', '@deniz'), findsOneWidget);
        await tapText(tester, decision.label);
        await tapText(tester, 'Kararı kaydet');
        expect(find.text('5–500 karakterlik bir gerekçe yaz.'), findsOneWidget);
        expect(
          api.requests.any((r) => r.method == RecordedHttpMethod.post),
          isFalse,
        );
        await tester.enterText(find.byType(TextFormField), '  $note  ');
        await tapText(tester, 'Kararı kaydet');
        expect(find.text(note), findsOneWidget);
        expect(find.text('Karar kaydı'), findsOneWidget);
        expect(labeledValue('Bildiren', '@deniz'), findsOneWidget);
        expect(
          labeledValue(
            'Kararı veren yönetici',
            decision == CollabReportDecision.dismiss
                ? '@moderatör'
                : 'reviewer',
          ),
          findsOneWidget,
        );
        await tester.pageBack();
        await tester.pumpAndSettle();
        expect(find.text(title), findsNothing);
        await tapText(tester, CollabReportStatus.open.label);
        await tapText(tester, decision.resultingStatus.label);
        await tapText(tester, title);
        expect(find.text(note), findsOneWidget);
        expect(find.text('Kararı kaydet'), findsNothing);
        expect(
          api.requests.where((r) => r.method == RecordedHttpMethod.post),
          hasLength(1),
        );
      },
    );
  }

  for (final username in [null, '  ']) {
    testWidgets(
      'shows the reporter ID when their username is ${username == null ? 'missing' : 'blank'}',
      (tester) async {
        final report = Map.of(openReport)..remove('reporterUsername');
        if (username != null) report['reporterUsername'] = username;
        final api = RecordingApiClient(
          (r) => r.path.endsWith('/$reportId') ? report : page([report]),
        );
        await openQueue(tester, AudienceTestSessions(reviewer()), api);
        await tapText(tester, title);
        expect(labeledValue('Bildiren', 'reporter'), findsOneWidget);
      },
    );
  }

  testWidgets(
    'a concurrent decision loads that exact report and displays its authoritative receipt',
    (tester) async {
      final sessions = AudienceTestSessions(reviewer());
      var detailReads = 0;
      final api = RecordingApiClient((r) {
        if (r.method == RecordedHttpMethod.post) {
          throw ApiException(
            const AppError(code: '9324', message: 'Durum değişti.'),
          );
        }
        if (r.path.endsWith('/$reportId')) {
          return ++detailReads == 1
              ? openReport
              : closedReport(
                  CollabReportDecision.removeListing,
                  'Önceki yöneticinin kararı.',
                );
        }
        return page([openReport]);
      });
      await openQueue(tester, sessions, api);
      await tapText(tester, title);
      await tapText(tester, CollabReportDecision.dismiss.label);
      await tester.enterText(find.byType(TextFormField), 'İncelendi.');
      await tapText(tester, 'Kararı kaydet');
      expect(detailReads, 2);
      expect(find.textContaining('sen incelerken değişti'), findsOneWidget);
      expect(find.text('Önceki yöneticinin kararı.'), findsOneWidget);
      expect(find.text(CollabReportDecision.dismiss.label), findsNothing);
    },
  );

  testWidgets(
    'a revoked grant hides the active sheet and both underlying screens',
    (tester) async {
      final sessions = AudienceTestSessions(reviewer());
      final api = RecordingApiClient(
        (r) => r.path.endsWith('/$reportId') ? openReport : page([openReport]),
      );
      await openQueue(tester, sessions, api);
      await tapText(tester, title);
      await tapText(tester, CollabReportDecision.removeListing.label);
      await tester.enterText(find.byType(TextFormField), 'Özel karar notu.');
      sessions.replace(const AuthSession.guest());
      await tester.pumpAndSettle();
      expect(find.byType(TextFormField), findsNothing);
      expect(find.text(title), findsNothing);
      expect(find.text('Özel karar notu.'), findsNothing);
      // Restoring an authorized account must not revive this review session.
      sessions.replace(reviewer());
      await tester.pumpAndSettle();
      expect(find.text('Kararı kaydet'), findsNothing);
      for (var i = 0; i < 2; i++) {
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.text(collabReportAccessLostMessage), findsOneWidget);
      }
      expect(api.requests, hasLength(2));
    },
  );

  testWidgets('a server-side denial hides the detail and the previous list', (
    tester,
  ) async {
    final sessions = AudienceTestSessions(reviewer());
    final api = RecordingApiClient((r) {
      if (r.method == RecordedHttpMethod.post) {
        throw ApiException(
          const AppError(code: '403', message: 'Yetki gerekli.'),
        );
      }
      return r.path.endsWith('/$reportId') ? openReport : page([openReport]);
    });
    await openQueue(tester, sessions, api);
    await tapText(tester, title);
    await tapText(tester, CollabReportDecision.dismiss.label);
    await tester.enterText(find.byType(TextFormField), 'İncelendi.');
    await tapText(tester, 'Kararı kaydet');
    expect(find.text(collabReportAccessLostMessage), findsOneWidget);
    expect(find.text(title), findsNothing);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text(collabReportAccessLostMessage), findsOneWidget);
    expect(api.requests, hasLength(3));
  });

  testWidgets(
    'historical records with an unverified snapshot show its provenance',
    (tester) async {
      final sessions = AudienceTestSessions(reviewer());
      final legacy = {...openReport, 'hasListingEvidence': false};
      final api = RecordingApiClient(
        (r) => r.path.endsWith('/$reportId') ? legacy : page([legacy]),
      );
      await openQueue(tester, sessions, api);
      await tapText(tester, title);
      expect(find.text('Bildirim anındaki ilan'), findsNothing);
      expect(
        find.text('İlanın bildirim anındaki hali doğrulanamıyor.'),
        findsOneWidget,
      );
      expect(find.text('Bildirim anındaki durum'), findsNothing);
      await tester.scrollUntilVisible(
        find.text('İlanın güncel durumu'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Kapalı'), findsOneWidget);
    },
  );

  testWidgets('reason filter resets pagination and can be cleared', (
    tester,
  ) async {
    final sessions = AudienceTestSessions(reviewer());
    final api = RecordingApiClient((r) {
      final index = r.query!['page'] as int;
      return page([openReport], index: index, last: index == 1);
    });
    await openQueue(tester, sessions, api);
    await tapText(tester, 'Sonraki sayfa');
    expect(api.lastRequest.query?['page'], 1);
    await tapText(tester, 'Tümü');
    await tapText(tester, CollabReportReason.misleading.label);
    expect(api.lastRequest.query?['reason'], 'MISLEADING');
    expect(api.lastRequest.query?['page'], 0);
    await tapText(tester, CollabReportReason.misleading.label);
    await tapText(tester, 'Tümü');
    expect(api.lastRequest.query?.containsKey('reason'), isFalse);
  });

  testWidgets('a slower refresh cannot overwrite a newer filter', (
    tester,
  ) async {
    final sessions = AudienceTestSessions(reviewer());
    var reads = 0;
    final pending = Completer<Object?>();
    final resolved = {
      ...closedReport(CollabReportDecision.dismiss, 'İncelendi.'),
      'listingTitle': 'Sonuçlanan ilan',
    };
    final api = RecordingApiClient((r) {
      if (++reads == 2) return pending.future;
      return page([r.query?['status'] == 'OPEN' ? openReport : resolved]);
    });
    await openQueue(tester, sessions, api);
    final changeFilter = tester
        .widget<DropdownButtonFormField<CollabReportStatus>>(
          find.byType(DropdownButtonFormField<CollabReportStatus>),
        )
        .onChanged!;
    await tester.tap(find.byTooltip('Listeyi yenile'));
    changeFilter(CollabReportStatus.dismissed);
    await tester.pumpAndSettle();
    expect(find.text('Sonuçlanan ilan'), findsOneWidget);
    pending.complete(page([openReport]));
    await tester.pumpAndSettle();
    expect(find.text('Sonuçlanan ilan'), findsOneWidget);
    expect(find.text(title), findsNothing);
  });

  testWidgets('ambiguous POST and failed readback retry only the GET', (
    tester,
  ) async {
    final sessions = AudienceTestSessions(reviewer());
    var detailReads = 0;
    final api = RecordingApiClient((r) {
      if (r.method == RecordedHttpMethod.post) {
        throw StateError('Connection lost');
      }
      if (r.path.endsWith('/$reportId')) {
        if (++detailReads == 1) return openReport;
        if (detailReads == 2) throw StateError('Offline');
        return closedReport(CollabReportDecision.dismiss, 'İncelendi.');
      }
      return page([openReport]);
    });
    await openQueue(tester, sessions, api);
    await tapText(tester, title);
    await tapText(tester, CollabReportDecision.dismiss.label);
    await tester.enterText(find.byType(TextFormField), 'İncelendi.');
    await tapText(tester, 'Kararı kaydet');
    expect(find.text(CollabReportDecision.dismiss.label), findsNothing);
    await tapText(tester, 'Tekrar dene');
    expect(find.text('İncelendi.'), findsOneWidget);
    expect(detailReads, 3);
    expect(
      api.requests.where((r) => r.method == RecordedHttpMethod.post),
      hasLength(1),
    );
  });
}
