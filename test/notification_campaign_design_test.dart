import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session.dart';
import 'package:soundconnect_23_12_25codx/modules/admin/data/notification_campaign_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/admin/domain/notification_campaign.dart';
import 'package:soundconnect_23_12_25codx/modules/admin/presentation/screens/notification_campaign_screen.dart';
import 'package:soundconnect_23_12_25codx/shared/theme/app_theme.dart';
import 'package:soundconnect_23_12_25codx/shared/theme/backstage_palette.dart';
import 'package:soundconnect_23_12_25codx/shared/widgets/gradient_outline_button.dart';

import 'support/event_audience_fakes.dart';
import 'support/recording_api_client.dart';

part 'notification_campaign_audience_matrix_cases.dart';

void main() {
  _registerAudienceMatrix();
  testWidgets(
    'admin saves 21:05 in selected zone on a 12-hour English device',
    (tester) async {
      final sessions = _sessions();
      final api = RecordingApiClient((_) => _record());
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.navy,
          locale: const Locale('en', 'US'),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: false),
            child: child!,
          ),
          home: NotificationCampaignEditor(
            repository: NotificationCampaignRepository(api, sessions),
            sessions: sessions,
            campaign: NotificationCampaign.fromJson(_record()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _reveal(tester, find.byKey(const Key('campaign-start')));
      await tester.tap(find.byKey(const Key('campaign-start')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Seç'));
      await tester.pumpAndSettle();
      final picker = find.byType(TimePickerDialog);
      expect(picker, findsOneWidget);
      expect(
        MediaQuery.of(tester.element(picker)).alwaysUse24HourFormat,
        isTrue,
      );
      expect(Localizations.localeOf(tester.element(picker)).languageCode, 'tr');
      expect(find.text('AM'), findsNothing);
      expect(find.text('PM'), findsNothing);
      await tester.tap(find.byIcon(Icons.keyboard_outlined));
      await tester.pumpAndSettle();
      final fields = find.descendant(
        of: picker,
        matching: find.byType(TextFormField),
      );
      await tester.enterText(fields.at(0), '21');
      await tester.enterText(fields.at(1), '05');
      await tester.tap(find.text('Seç'));
      await tester.pumpAndSettle();
      await _reveal(tester, find.byKey(const Key('campaign-save')));
      await tester.tap(find.byKey(const Key('campaign-save')));
      await tester.pumpAndSettle();
      final write = api.requests.singleWhere(
        (r) => r.method == RecordedHttpMethod.put,
      );
      final schedule = (write.body as Map)['schedule'] as Map;
      expect(schedule['localStartsAt'], '2028-01-01T21:05:00');
      expect(schedule['zoneId'], 'Europe/Istanbul');
      expect(
        api.requests.where((r) => r.method == RecordedHttpMethod.post),
        isEmpty,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      sessions.dispose();
    },
  );

  testWidgets('editor and confirmation preserve Collab neutral surfaces', (
    tester,
  ) async {
    final sessions = _sessions();
    final api = RecordingApiClient((_) => _record());
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.navy,
        home: NotificationCampaignEditor(
          repository: NotificationCampaignRepository(api, sessions),
          sessions: sessions,
          campaign: NotificationCampaign.fromJson(_record()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final theme = Theme.of(
      tester.element(find.byKey(const Key('campaign-title'))),
    );
    expect(theme.colorScheme.surfaceContainer, BackstagePalette.surface);
    expect(theme.colorScheme.secondaryContainer, BackstagePalette.input);
    expect(theme.chipTheme.selectedColor, BackstagePalette.input);
    expect(theme.timePickerTheme.dialBackgroundColor, BackstagePalette.surface);
    expect(
      theme.filledButtonTheme.style!.backgroundColor!.resolve({}),
      Colors.transparent,
    );
    expect(
      theme.filledButtonTheme.style!.backgroundColor!.resolve({
        WidgetState.disabled,
      }),
      Colors.transparent,
    );
    await _reveal(tester, find.byKey(const Key('campaign-schedule')));
    final scheduleFrame = tester.widget<GradientOutline>(
      find.descendant(
        of: find.byKey(const Key('campaign-schedule')),
        matching: find.byType(GradientOutline),
      ),
    );
    expect(scheduleFrame.strokeWidth, 1.4);
    await tester.tap(find.byKey(const Key('campaign-schedule')));
    await tester.pumpAndSettle();
    final dialogTheme = Theme.of(tester.element(find.byType(AlertDialog)));
    expect(
      dialogTheme.dialogTheme.backgroundColor,
      BackstagePalette.surfaceRaised,
    );
    expect(dialogTheme.colorScheme.primaryContainer, BackstagePalette.input);
    final confirmation = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(FilledButton),
    );
    expect(
      find.descendant(of: confirmation, matching: find.byType(GradientOutline)),
      findsOneWidget,
    );
    expect(
      tester
          .widget<Material>(
            find.descendant(of: confirmation, matching: find.byType(Material)),
          )
          .color,
      Colors.transparent,
    );
    expect(
      api.requests.where((r) => r.method != RecordedHttpMethod.get),
      isEmpty,
    );
    await tester.pumpWidget(const SizedBox());
    sessions.dispose();
  });

  testWidgets(
    'long campaign cards and create action fit a narrow large-text phone',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 640);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final sessions = _sessions();
      final api = RecordingApiClient(
        (_) => {
          'items': [_record()],
          'page': 0,
          'size': 20,
          'total': 1,
        },
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.navy,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(2)),
            child: child!,
          ),
          home: NotificationCampaignScreen(
            repository: NotificationCampaignRepository(api, sessions),
            sessions: sessions,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await _reveal(
        tester,
        find.byKey(const Key('campaign-73aaf2f1-34ca-4ea1-8340-423b480516aa')),
      );
      expect(tester.takeException(), isNull);
      expect(
        find.byKey(const Key('campaign-create')).hitTestable(),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('campaign-create')),
          matching: find.byType(GradientOutline),
        ),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox());
      sessions.dispose();
    },
  );

  testWidgets(
    'user lookup renders twenty results with keyboard and large text',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 640);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final sessions = _sessions();
      final api = RecordingApiClient(
        (request) => request.path.endsWith('/users')
            ? _lookupResults()
            : _record(users: true),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.navy,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(2)),
            child: child!,
          ),
          home: NotificationCampaignEditor(
            repository: NotificationCampaignRepository(api, sessions),
            sessions: sessions,
            campaign: NotificationCampaign.fromJson(_record(users: true)),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final select = find.widgetWithText(
        OutlinedButton,
        'Kullanıcı seç (1/100)',
      );
      await _reveal(tester, select);
      await tester.tap(select);
      await tester.pumpAndSettle();
      tester.view.viewInsets = const FakeViewPadding(bottom: 280);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final query = find.byKey(const Key('campaign-lookup-query'));
      await tester.ensureVisible(query);
      await tester.enterText(query, 'de');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(api.lastRequest.query, {'q': 'de'});
      final result = find.widgetWithText(ListTile, 'Deniz Sonuç 19');
      await tester.scrollUntilVisible(
        result,
        250,
        scrollable: find
            .descendant(
              of: find.byType(AlertDialog),
              matching: find.byType(Scrollable),
            )
            .first,
        maxScrolls: 50,
      );
      await tester.tap(result);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(
        find.widgetWithText(OutlinedButton, 'Kullanıcı seç (2/100)'),
        findsOneWidget,
      );
      expect(find.widgetWithText(InputChip, '@deniz19'), findsOneWidget);
      expect(tester.takeException(), isNull);
      expect(
        api.requests.where((r) => r.method != RecordedHttpMethod.get),
        isEmpty,
      );
      await tester.pumpWidget(const SizedBox());
      sessions.dispose();
    },
  );

  testWidgets(
    'target lookup displays and saves the explicitly selected profile',
    (tester) async {
      final sessions = _sessions();
      final record = _record()
        ..['target'] = {
          'kind': 'PROFILE',
          'targetId': 'b3aacb86-81ce-4698-9917-7ce50875310b',
        }
        ..['selectedTarget'] = {'label': 'Eski profil'};
      final api = RecordingApiClient(
        (request) => request.path.endsWith('/targets')
            ? _lookupResults().take(1).toList()
            : record,
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.navy,
          home: NotificationCampaignEditor(
            repository: NotificationCampaignRepository(api, sessions),
            sessions: sessions,
            campaign: NotificationCampaign.fromJson(record),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final select = find.byKey(const Key('campaign-target-select'));
      await _reveal(tester, select);
      await tester.tap(select);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('campaign-lookup-query')),
        'deniz',
      );
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(api.lastRequest.query, {'q': 'deniz', 'kind': 'PROFILE'});
      final result = find.widgetWithText(ListTile, 'Deniz Sonuç 0');
      await tester.ensureVisible(result);
      await tester.tap(result);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(
        find.widgetWithText(OutlinedButton, 'Deniz Sonuç 0'),
        findsOneWidget,
      );
      await _reveal(tester, find.byKey(const Key('campaign-save')));
      await tester.tap(find.byKey(const Key('campaign-save')));
      await tester.pumpAndSettle();
      final write = api.requests.singleWhere(
        (r) => r.method == RecordedHttpMethod.put,
      );
      expect((write.body as Map)['target'], {
        'kind': 'PROFILE',
        'targetId': 'd008104a-d6d7-4a60-982c-000000000000',
      });
      expect(
        api.requests.where((r) => r.method == RecordedHttpMethod.post),
        isEmpty,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      sessions.dispose();
    },
  );

  testWidgets(
    'loaded lookup results redact on revocation and stale selection is fenced',
    (tester) async {
      final sessions = _sessions();
      final original = sessions.session;
      final api = RecordingApiClient(
        (request) => request.path.endsWith('/users')
            ? _lookupResults().take(1).toList()
            : _record(users: true),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.navy,
          home: NotificationCampaignEditor(
            repository: NotificationCampaignRepository(api, sessions),
            sessions: sessions,
            campaign: NotificationCampaign.fromJson(_record(users: true)),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final select = find.widgetWithText(
        OutlinedButton,
        'Kullanıcı seç (1/100)',
      );
      await _reveal(tester, select);
      await tester.tap(select);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('campaign-lookup-query')),
        'de',
      );
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final result = find.widgetWithText(ListTile, 'Deniz Sonuç 0');
      final staleTap = tester.widget<ListTile>(result).onTap!;
      sessions.replace(const AuthSession.guest());
      staleTap();
      await tester.pumpAndSettle();
      expect(find.text('Deniz Sonuç 0'), findsNothing);
      expect(
        find.text('Oturumun değişti. Sayfayı yeniden aç.'),
        findsOneWidget,
      );
      expect(find.byType(AlertDialog), findsOneWidget);
      sessions.replace(original);
      staleTap();
      await tester.pumpAndSettle();
      expect(find.text('Deniz Sonuç 0'), findsNothing);
      expect(find.byType(InputChip), findsNothing);
      expect(
        api.requests.where((r) => r.method != RecordedHttpMethod.get),
        isEmpty,
      );
      await tester.pumpWidget(const SizedBox());
      sessions.dispose();
    },
  );
}

List<Map<String, Object>> _lookupResults() => List.generate(
  20,
  (i) => {
    'id': 'd008104a-d6d7-4a60-982c-${i.toString().padLeft(12, '0')}',
    'label': 'Deniz Sonuç $i',
    'username': 'deniz$i',
    'profileType': 'MUSICIAN',
  },
);

Future<void> _reveal(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    300,
    scrollable: find.byType(Scrollable).first,
    maxScrolls: 50,
  );
  await tester.pumpAndSettle();
}

AudienceTestSessions _sessions() => AudienceTestSessions(
  AuthSession.authenticated(
    token: 'test-admin',
    userId: '3c51f117-76f1-472d-9504-f96722bd0710',
    username: 'admin',
    accountStatus: 'ACTIVE',
    roles: const ['ROLE_ADMIN'],
    permissions: const [],
    expiresAt: DateTime.utc(2100),
    isAdmin: true,
  ),
);

Map<String, dynamic> _record({bool users = false}) => {
  'id': '73aaf2f1-34ca-4ea1-8340-423b480516aa',
  'version': 1,
  'title':
      'Birlikte müzik yapmak isteyen herkese Soundconnect dünyasından yeni haberler',
  'message':
      'Yeni etkinlikleri, müzisyenleri ve işbirliği fırsatlarını keşfetmek için seni bekliyoruz.',
  'audience': {
    'mode': users ? 'USERS' : 'ALL',
    'profileTypes': <String>[],
    'userIds': users ? ['b3aacb86-81ce-4698-9917-7ce50875310b'] : <String>[],
  },
  'target': {'kind': 'HOME', 'targetId': null},
  'schedule': {
    'startsAt': '2028-01-01T09:00:00Z',
    'localStartsAt': '2028-01-01T12:00:00',
    'zoneId': 'Europe/Istanbul',
    'repeat': 'ONCE',
    'intervalDays': null,
    'weekDays': <int>[],
    'endsAt': null,
    'localEndsAt': null,
    'maxOccurrences': null,
  },
  'status': 'DRAFT',
  'nextRunAt': null,
  'createdAt': '2026-10-08T00:00:00Z',
  'updatedAt': '2026-10-08T00:00:00Z',
  'stats': {
    'occurrences': 0,
    'recipients': 0,
    'notifications': 0,
    'skipped': 0,
  },
  'selectedUsers': users
      ? [
          {
            'id': 'b3aacb86-81ce-4698-9917-7ce50875310b',
            'label': 'Deniz',
            'subtitle': '@deniz · Müzisyen',
          },
        ]
      : <Object>[],
  'selectedTarget': null,
};
