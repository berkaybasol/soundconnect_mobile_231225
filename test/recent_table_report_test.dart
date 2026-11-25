import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/modules/tablegroup/data/table_group_report_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/tablegroup/presentation/screens/recent_table_report_screen.dart';
import 'package:soundconnect_23_12_25codx/shared/widgets/gradient_outline_button.dart';

import 'support/event_audience_fakes.dart';
import 'support/recording_api_client.dart';

void main() {
  final end = DateTime.now().toUtc().subtract(const Duration(hours: 1));
  Map<String, dynamic> page(int number, {required bool last}) => {
    'number': number,
    'size': 20,
    'last': last,
    'content': [
      {
        'tableGroupId': 'table-$number',
        'tableDescription': 'Masa $number',
        'districtName': 'Kadıköy',
        'meetingAt': end.toIso8601String(),
        'endReason': number == 0 ? 'KICKED' : 'EXPIRED',
        'endedAt': end.toIso8601String(),
        'reportUntil': end.add(const Duration(hours: 48)).toIso8601String(),
      },
    ],
  };

  testWidgets(
    'recent tables page can report an incident without chat, validates the narrative, and erases an open draft on account switch',
    (tester) async {
      final sessions = AudienceTestSessions(audienceSession(user: 'A'));
      final receipt = Completer<Object?>();
      final api = RecordingApiClient((request) {
        if (request.method == RecordedHttpMethod.post) {
          return receipt.future;
        }
        final n = request.query!['page'] as int;
        return page(n, last: n == 1);
      });
      final repository = TableGroupReportRepository(api, sessions);
      await tester.pumpWidget(
        MaterialApp(
          home: RecentTableReportScreen(
            repository: repository,
            actor: repository.capture(sessions.session)!,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Masadan çıkarıldın'), findsOneWidget);
      await tester.tap(find.text('Daha fazla göster'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Masanın süresi doldu'), findsOneWidget);
      await tester.tap(find.text('Masa 1'));
      await tester.pumpAndSettle();
      final reasonFrame = find.ancestor(
        of: find.text('Güvenlik sorunu'),
        matching: find.byType(GradientOutline),
      );
      expect(tester.widget<GradientOutline>(reasonFrame).colors, isNull);
      expect(
        find.widgetWithText(GradientOutlineButton, 'Bildirimi gönder'),
        findsOneWidget,
      );
      await tester.tap(find.text('Güvenlik sorunu'));
      await tester.ensureVisible(find.text('Bildirimi gönder'));
      await tester.tap(find.text('Bildirimi gönder'));
      await tester.pumpAndSettle();
      expect(find.text('Yaşadığın olayı anlat.'), findsOneWidget);
      expect(api.requests, hasLength(2));
      await tester.enterText(
        find.byType(TextFormField),
        '  Buluşmada bir olay yaşandı.  ',
      );
      await tester.ensureVisible(find.text('Bildirimi gönder'));
      await tester.tap(find.text('Bildirimi gönder'));
      await tester.pump();
      expect(
        tester
            .widget<GradientOutlineButton>(find.byType(GradientOutlineButton))
            .loading,
        isTrue,
      );
      final lockedColors = tester.widget<GradientOutline>(reasonFrame).colors!;
      expect(lockedColors.first, lockedColors.last);
      receipt.complete({'id': 'receipt', 'reportedAt': end.toIso8601String()});
      await tester.pumpAndSettle();
      expect(find.text('Bildirimin alındı'), findsOneWidget);
      expect(
        find.widgetWithText(GradientOutlineButton, 'Tamam'),
        findsOneWidget,
      );
      expect(api.lastRequest.path, '/api/v1/table-groups/table-1/reports');
      expect(
        api.lastRequest.body,
        containsPair('description', 'Buluşmada bir olay yaşandı.'),
      );
      expect(api.lastRequest.body, containsPair('kind', 'INCIDENT'));
      expect(api.lastRequest.body, containsPair('reason', 'SAFETY'));
      expect(api.requests.where((r) => r.path.contains('/chat')), isEmpty);
      await tester.tap(find.text('Tamam'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Masa 0'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextFormField),
        'Önceki hesabın anlatımı',
      );
      sessions.replace(audienceSession(user: 'B'));
      await tester.pumpAndSettle();
      expect(find.text('Önceki hesabın anlatımı'), findsNothing);
      expect(find.text('Bildirimi gönder'), findsNothing);
      expect(find.text('Oturum değişti'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

  test('delayed reads never return the prior session’s history', () async {
    final sessions = AudienceTestSessions(audienceSession(user: 'one'));
    final response = Completer<Object?>();
    final api = RecordingApiClient((_) => response.future);
    final repo = TableGroupReportRepository(api, sessions);
    final actor = repo.capture(sessions.session)!;
    final pending = repo.recent(actor: actor, page: 0);
    sessions.replace(audienceSession(user: 'two'));
    response.complete(page(0, last: true));
    expect((await pending).error, TableGroupReportRepository.sessionChanged);
    expect((await repo.recent(actor: actor, page: 0)).data, isNull);
    expect(api.requests, hasLength(1));
  });
}
