import 'dart:async';
import 'dart:ui' show CheckedState;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/modules/tablegroup/data/table_group_report_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/tablegroup/domain/table_group_report.dart';
import 'package:soundconnect_23_12_25codx/modules/tablegroup/presentation/widgets/table_group_report_sheet.dart';
import 'package:soundconnect_23_12_25codx/shared/theme/app_theme.dart';
import 'package:soundconnect_23_12_25codx/shared/widgets/gradient_outline_button.dart';

import 'support/event_audience_fakes.dart';
import 'support/recording_api_client.dart';

void main() {
  const reasons = {
    TableGroupReportKind.listing: [
      'Uygunsuz içerik',
      'Yanıltıcı bilgi',
      'Para talebi',
      'Diğer',
    ],
    TableGroupReportKind.message: [
      'Para talebi',
      'Taciz veya tehdit',
      'Spam',
      'Diğer',
    ],
    TableGroupReportKind.incident: [
      'Taciz veya tehdit',
      'Para talebi',
      'Güvenlik sorunu',
      'Diğer',
    ],
  };
  for (final entry in reasons.entries) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        '${entry.key.name} has accessible controls at 360dp, text scale $scale',
        (tester) async {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = const Size(360, 720);
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.view.resetPhysicalSize);
          final sessions = AudienceTestSessions(
            audienceSession(user: 'member'),
          );
          final receipt = Completer<Object?>();
          final api = RecordingApiClient((request) => receipt.future);
          final repository = TableGroupReportRepository(api, sessions);
          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.current,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: Scaffold(
                body: Builder(
                  builder: (context) => TextButton(
                    child: const Text('Formu aç'),
                    onPressed: () => showTableGroupReportSheet(
                      context,
                      repository: repository,
                      actor: repository.capture(sessions.session)!,
                      tableId: 'test-table',
                      kind: entry.key,
                      messageId: entry.key == TableGroupReportKind.message
                          ? 'test-message'
                          : null,
                      evidenceLabel: 'Seçilen kayıt',
                      evidenceText: 'Deneme',
                      evidenceContext: 'Ankara',
                    ),
                  ),
                ),
              ),
            ),
          );
          Future<void> tap(Finder target) async {
            await tester.ensureVisible(target);
            await tester.pumpAndSettle();
            await tester.tap(target);
            await tester.pumpAndSettle();
          }

          final open = find.text('Formu aç');
          await tap(open);
          await tap(find.byTooltip('Kapat'));
          await tap(open);
          await tester.binding.handlePopRoute();
          await tester.pumpAndSettle();
          expect(find.text('Bildirim nedeni'), findsNothing);
          expect(api.requests, isEmpty);
          await tap(open);
          final submit = find.text('Bildirimi gönder');
          if (entry.key == TableGroupReportKind.incident) {
            await tap(submit);
            expect(find.text('Yaşadığın olayı anlat.'), findsOneWidget);
            final field = find.byType(TextFormField);
            await tester.ensureVisible(field);
            await tester.enterText(field, 'a' * 501);
            expect(
              tester
                  .widget<TextField>(find.byType(TextField))
                  .controller!
                  .text
                  .length,
              500,
            );
          }
          await tap(submit);
          expect(find.text('Bir bildirim nedeni seç.'), findsOneWidget);
          expect(api.requests, isEmpty);
          for (final reason in entry.value) {
            final label = find.text(reason);
            final tile = find.ancestor(
              of: label,
              matching: find.byType(RadioListTile<TableGroupReportReason>),
            );
            await Scrollable.ensureVisible(
              tester.element(tile),
              alignment: 0.5,
            );
            await tester.pumpAndSettle();
            await tester.tap(tile);
            await tester.pumpAndSettle();
            final node = tester.getSemantics(tile).getSemanticsData();
            expect(node.label, reason);
            expect(node.flagsCollection.isChecked, CheckedState.isTrue);
            expect(node.rect.height, greaterThanOrEqualTo(48), reason: reason);
            expect(node.rect.width, greaterThanOrEqualTo(48));
            final frame = tester.widget<GradientOutline>(
              find.ancestor(of: tile, matching: find.byType(GradientOutline)),
            );
            expect(frame.strokeWidth, 0.9);
          }
          await tester.ensureVisible(submit);
          await tester.pumpAndSettle();
          final button = find.widgetWithText(
            GradientOutlineButton,
            'Bildirimi gönder',
          );
          expect(tester.getSize(button).height, greaterThanOrEqualTo(48));
          expect(tester.widget<GradientOutlineButton>(button).strokeWidth, 0.9);
          await tester.tap(submit);
          await tester.tap(submit);
          await tester.pump();
          expect(api.requests, hasLength(1));
          expect(
            tester
                .widget<IconButton>(
                  find.widgetWithIcon(IconButton, Icons.close),
                )
                .onPressed,
            isNull,
          );
          await tester.binding.handlePopRoute();
          await tester.pump();
          expect(find.text('Bildirim nedeni'), findsOneWidget);
          receipt.complete({
            'id': 'receipt',
            'reportedAt': '2026-11-24T18:00:00Z',
          });
          await tester.pumpAndSettle();
          final done = find.widgetWithText(GradientOutlineButton, 'Tamam');
          expect(tester.getSize(done).height, greaterThanOrEqualTo(48));
          expect(tester.widget<GradientOutlineButton>(done).strokeWidth, 0.9);
          await tap(done);
          expect(find.text('Bildirimin alındı'), findsNothing);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
