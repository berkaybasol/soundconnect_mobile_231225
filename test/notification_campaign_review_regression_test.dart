import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session.dart';
import 'package:soundconnect_23_12_25codx/modules/admin/data/notification_campaign_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/admin/domain/notification_campaign.dart';
import 'package:soundconnect_23_12_25codx/modules/admin/presentation/screens/notification_campaign_screen.dart';

import 'support/event_audience_fakes.dart';
import 'support/recording_api_client.dart';

const _id = '73aaf2f1-34ca-4ea1-8340-423b480516aa';

void main() {
  for (final value in ['1.5', 'abc', '999999999999999999999999999999']) {
    testWidgets('end-date plan rejects malformed maximum $value before save', (
      tester,
    ) async {
      final h = await _mount(tester);
      await _reveal(tester, find.byKey(const Key('campaign-maximum')));
      await tester.enterText(find.byKey(const Key('campaign-maximum')), value);
      await _reveal(tester, find.byKey(const Key('campaign-save')));
      await tester.tap(find.byKey(const Key('campaign-save')));
      await tester.pumpAndSettle();
      expect(
        h.api.requests.where((r) => r.method != RecordedHttpMethod.get),
        isEmpty,
        reason:
            'A malformed cap must not silently become an end-date-only plan.',
      );
    });
  }

  for (final value in ['', '1', '10000']) {
    testWidgets(
      'end-date plan preserves explicit maximum ${value.isEmpty ? 'empty' : value}',
      (tester) async {
        final h = await _mount(tester);
        await _reveal(tester, find.byKey(const Key('campaign-maximum')));
        await tester.enterText(
          find.byKey(const Key('campaign-maximum')),
          value,
        );
        await _reveal(tester, find.byKey(const Key('campaign-save')));
        await tester.tap(find.byKey(const Key('campaign-save')));
        await tester.pumpAndSettle();
        final write = h.api.requests.singleWhere(
          (r) => r.method == RecordedHttpMethod.put,
        );
        final schedule = (write.body as Map)['schedule'] as Map;
        expect(
          schedule['maxOccurrences'],
          value.isEmpty ? isNull : int.parse(value),
        );
        expect(schedule['localEndsAt'], '2028-02-01T12:00:00');
      },
    );
  }

  for (final year in [2000, 2100]) {
    testWidgets(
      'backend-valid start year $year opens calendar without exception',
      (tester) async {
        await _mount(tester, startYear: year);
        final tile = find.byKey(const Key('campaign-start'));
        await _reveal(tester, tile);
        await tester.tap(tile);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byType(DatePickerDialog), findsOneWidget);
      },
    );
  }
}

Future<void> _reveal(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    300,
    scrollable: find.byType(Scrollable).first,
    maxScrolls: 40,
  );
  await tester.pumpAndSettle();
}

Future<({RecordingApiClient api})> _mount(
  WidgetTester tester, {
  int startYear = 2028,
}) async {
  final sessions = AudienceTestSessions(
    AuthSession.authenticated(
      token: 'campaign-review-admin',
      userId: '189edfad-023a-452c-bbf6-2d3170e04ed2',
      username: 'admin',
      accountStatus: 'ACTIVE',
      roles: const ['ROLE_ADMIN'],
      permissions: const [],
      expiresAt: DateTime.utc(2200),
      isAdmin: true,
    ),
  );
  final record = <String, dynamic>{
    'id': _id,
    'version': 2,
    'title': 'Review campaign',
    'message': 'Retain the selected recurrence limits.',
    'audience': {'mode': 'ALL', 'profileTypes': [], 'userIds': []},
    'target': {'kind': 'HOME', 'targetId': null},
    'schedule': {
      'startsAt': '$startYear-01-01T09:00:00Z',
      'localStartsAt': '$startYear-01-01T12:00:00',
      'zoneId': 'Europe/Istanbul',
      'repeat': 'DAILY',
      'intervalDays': null,
      'weekDays': [],
      'endsAt': '$startYear-02-01T09:00:00Z',
      'localEndsAt': '$startYear-02-01T12:00:00',
      'maxOccurrences': 3,
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
    'selectedUsers': [],
    'selectedTarget': null,
  };
  final api = RecordingApiClient((_) => record);
  await tester.pumpWidget(
    MaterialApp(
      home: NotificationCampaignEditor(
        repository: NotificationCampaignRepository(api, sessions),
        sessions: sessions,
        campaign: NotificationCampaign.fromJson(record),
      ),
    ),
  );
  await tester.pumpAndSettle();
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    sessions.dispose();
  });
  return (api: api);
}
