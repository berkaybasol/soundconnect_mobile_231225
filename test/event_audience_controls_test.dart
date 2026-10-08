import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session.dart';
import 'package:soundconnect_23_12_25codx/core/error/app_error.dart';
import 'package:soundconnect_23_12_25codx/core/error/result.dart';
import 'package:soundconnect_23_12_25codx/modules/event_audience/domain/event_audience_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/event_audience/presentation/widgets/event_audience_controls.dart';
import 'package:soundconnect_23_12_25codx/shared/theme/app_theme.dart';
import 'package:soundconnect_23_12_25codx/shared/widgets/gradient_outline_button.dart';

import 'support/event_audience_fakes.dart';

part 'event_audience_controls_test_register_event_audience_controls1.dart';
part 'event_audience_controls_test_register_event_audience_controls2.dart';

void main() {
  _registerEventAudienceControls1();
  _registerEventAudienceControls2();
}

VoidCallback _action(WidgetTester tester, String key) =>
    tester.widget<GradientOutlineButton>(find.byKey(Key(key))).onPressed!;

void _expectNoDetailStatusRow() {
  expect(find.byKey(const Key('event-audience-current')), findsNothing);
  expect(find.byKey(const Key('event-audience-manage')), findsNothing);
  expect(find.textContaining('Seçimin:'), findsNothing);
  expect(find.text('Seçimimi düzenle'), findsNothing);
}

VoidCallback _popupAction(WidgetTester tester, String key) => tester
    .widget<InkWell>(
      find
          .descendant(of: find.byKey(Key(key)), matching: find.byType(InkWell))
          .first,
    )
    .onTap!;

VoidCallback _snackAction(WidgetTester tester) => tester
    .widget<SnackBarAction>(
      find.byKey(const Key('event-audience-snackbar-profile')),
    )
    .onPressed;

Future<void> _tap(WidgetTester tester, String key) async {
  await tester.tap(find.byKey(Key(key)));
  await tester.pumpAndSettle();
}

Future<void> _pump(
  WidgetTester tester,
  AudienceTestRepository repository, {
  AudienceTestSessions? sessions,
  AudienceExternalShare? onExternalShare,
  AudienceProfileShare? onProfileShare,
  double width = 390,
  double scale = 1,
  String eventId = audienceEventId,
  bool showControls = true,
}) async {
  await tester.binding.setSurfaceSize(Size(width, 844));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.navy,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: showControls
              ? EventAudienceControls(
                  eventId: eventId,
                  eventTitle: 'Canlı müzik akşamı',
                  repository: repository,
                  sessions: sessions ?? AudienceTestSessions(audienceSession()),
                  onExternalShare: onExternalShare,
                  onProfileShare: onProfileShare,
                )
              : const SizedBox.shrink(),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpLauncher(
  WidgetTester tester,
  AudienceTestRepository repository,
  AudienceTestSessions sessions, {
  AudienceExternalShare? onExternalShare,
  AudienceProfileShare? onProfileShare,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.navy,
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showEventAudienceSheet(
              context,
              eventId: audienceEventId,
              eventTitle: 'Canlı müzik akşamı',
              repository: repository,
              sessions: sessions,
              onExternalShare: onExternalShare,
              onProfileShare: onProfileShare,
            ),
            child: const Text('Ben de gidiyorum'),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
