part of 'notification_campaign_design_test.dart';

const _audienceLabels = {
  'MUSICIAN': 'Müzisyen',
  'LISTENER': 'Dinleyici',
  'VENUE': 'Mekân',
  'STUDIO': 'Stüdyo',
};

void _registerAudienceMatrix() {
  for (final profiles in [
    ['MUSICIAN'],
    ['LISTENER'],
    ['VENUE'],
    ['STUDIO'],
    ['MUSICIAN', 'LISTENER', 'VENUE', 'STUDIO'],
    ['VENUE', 'STUDIO'],
  ]) {
    testWidgets(
      'real editor saves exactly selected profile audience $profiles',
      (t) async {
        final h = await _mountAudience(t);
        await _selectAudience(t, 'Profil türleri');
        for (final profile in profiles) {
          final chip = find.widgetWithText(
            FilterChip,
            _audienceLabels[profile]!,
          );
          await _reveal(t, chip);
          await t.tap(chip);
          await t.pumpAndSettle();
        }
        final body = await _saveAudience(t, h.api);
        expect(body['audience'], {
          'mode': 'PROFILE_TYPES',
          'profileTypes': [...profiles]..sort(),
          'userIds': [],
        });
        expect(body['target'], {'kind': 'HOME'});
      },
    );
  }

  for (final profile in _audienceLabels.keys) {
    testWidgets(
      'username lookup $profile saves account UUID and duplicate selection does not duplicate recipient',
      (t) async {
        const selectedId = 'd008104a-d6d7-4a60-982c-000000000000';
        final h = await _mountAudience(t, profile: profile);
        await _selectAudience(t, 'Seçtiğim kullanıcılar');
        for (final count in [0, 1]) {
          final add = find.widgetWithText(
            OutlinedButton,
            'Kullanıcı seç ($count/100)',
          );
          await _reveal(t, add);
          await t.tap(add);
          await t.pumpAndSettle();
          await t.enterText(
            find.byKey(const Key('campaign-lookup-query')),
            '  deniz  ',
          );
          await t.testTextInput.receiveAction(TextInputAction.search);
          await t.pumpAndSettle();
          expect(h.api.lastRequest.query, {'q': 'deniz'});
          await t.tap(find.widgetWithText(ListTile, 'Deniz Sonuç 0'));
          await t.pumpAndSettle();
          expect(
            find.widgetWithText(OutlinedButton, 'Kullanıcı seç (1/100)'),
            findsOneWidget,
          );
        }
        final body = await _saveAudience(t, h.api);
        expect(body['audience'], {
          'mode': 'USERS',
          'profileTypes': [],
          'userIds': [selectedId],
        });
      },
    );
  }

  for (final original in ['USERS', 'PROFILE_TYPES']) {
    testWidgets(
      'switch from $original to ALL excludes stale audience selectors',
      (t) async {
        final record = _record(users: original == 'USERS');
        if (original == 'PROFILE_TYPES') {
          record['audience'] = {
            'mode': original,
            'profileTypes': ['VENUE', 'STUDIO'],
            'userIds': [],
          };
        }
        final h = await _mountAudience(t, record: record);
        await _selectAudience(t, 'Tüm uygun kullanıcılar');
        expect(
          find.text('Müzisyen, Dinleyici, Mekân ve Stüdyo hesapları.'),
          findsOneWidget,
        );
        final body = await _saveAudience(t, h.api);
        expect(body['audience'], {
          'mode': 'ALL',
          'profileTypes': [],
          'userIds': [],
        });
      },
    );
  }

  testWidgets(
    'removing last username recipient prevents empty-user campaign save',
    (t) async {
      final h = await _mountAudience(t, record: _record(users: true));
      final chip = find.byType(InputChip);
      await _reveal(t, chip);
      await t.tap(find.descendant(of: chip, matching: find.byType(Icon)).last);
      await t.pumpAndSettle();
      expect(
        find.widgetWithText(OutlinedButton, 'Kullanıcı seç (0/100)'),
        findsOneWidget,
      );
      await _reveal(t, find.byKey(const Key('campaign-save')));
      await t.tap(find.byKey(const Key('campaign-save')));
      await t.pumpAndSettle();
      expect(
        h.api.requests.where((r) => r.method != RecordedHttpMethod.get),
        isEmpty,
      );
    },
  );
}

Future<({RecordingApiClient api})> _mountAudience(
  WidgetTester tester, {
  Map<String, dynamic>? record,
  String profile = 'MUSICIAN',
}) async {
  final sessions = _sessions();
  final data = record ?? _record();
  final api = RecordingApiClient(
    (r) => r.path.endsWith('/users')
        ? [
            {..._lookupResults().first, 'profileType': profile},
          ]
        : data,
  );
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.navy,
      home: NotificationCampaignEditor(
        repository: NotificationCampaignRepository(api, sessions),
        sessions: sessions,
        campaign: NotificationCampaign.fromJson(data),
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

Future<void> _selectAudience(WidgetTester tester, String label) async {
  final field = find.byType(DropdownButtonFormField<String>).first;
  await _reveal(tester, field);
  await tester.tap(field);
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

Future<Map> _saveAudience(WidgetTester tester, RecordingApiClient api) async {
  await _reveal(tester, find.byKey(const Key('campaign-save')));
  await tester.tap(find.byKey(const Key('campaign-save')));
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
  expect(
    api.requests.where((r) => r.method == RecordedHttpMethod.post),
    isEmpty,
    reason: 'Saving a draft must never send or schedule it.',
  );
  return api.requests
          .singleWhere((r) => r.method == RecordedHttpMethod.put)
          .body
      as Map;
}
