import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session.dart';
import 'package:soundconnect_23_12_25codx/core/error/app_error.dart';
import 'package:soundconnect_23_12_25codx/core/network/api_client.dart';
import 'package:soundconnect_23_12_25codx/core/network/api_exception.dart';
import 'package:soundconnect_23_12_25codx/modules/admin/data/notification_campaign_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/admin/domain/notification_campaign.dart';
import 'package:soundconnect_23_12_25codx/modules/admin/presentation/screens/notification_campaign_screen.dart';

import 'support/event_audience_fakes.dart';

const _id = '73aaf2f1-34ca-4ea1-8340-423b480516aa';
const _user = '189edfad-023a-452c-bbf6-2d3170e04ed2';
const _request = '6cdd91b1-cc9d-42c0-ae70-0d39c5b157ac';

void main() {
  endsOnlyRegressionTests();
  test(
    'local wall time stays in selected zone regardless of device timezone',
    () {
      final local = campaignWallTime('2028-03-26T02:30:00');
      expect(local.hour, 2);
      final input = _input(local: local, zone: 'Europe/Berlin');
      final schedule = input.toJson()['schedule'] as Map;
      expect(schedule['localStartsAt'], '2028-03-26T02:30:00');
      expect(schedule['zoneId'], 'Europe/Berlin');
      expect(schedule.containsKey('startsAt'), isFalse);
      // An API-authored draft can carry sub-minute precision. Editing its text
      // must not silently move its schedule to the start of the minute.
      expect(
        campaignLocalIso(campaignWallTime('2028-03-26T02:30:47.123456')),
        '2028-03-26T02:30:47.123456',
      );
      expect(
        () => campaignWallTime('2028-02-31T10:00:00'),
        throwsFormatException,
      );
      expect(
        () => campaignWallTime('2028-01-01T10:00:00+03:00'),
        throwsFormatException,
      );
    },
  );

  test('repeat and audience require explicit bounded choices', () {
    expect(_input().validationError, isNull);
    expect(_input(repeat: 'DAILY').validationError, isNotNull);
    expect(_input(repeat: 'DAILY', maximum: 10).validationError, isNull);
    expect(_input(repeat: 'WEEKLY', maximum: 10).validationError, isNotNull);
    expect(
      _input(repeat: 'WEEKLY', maximum: 10, days: [1, 7]).validationError,
      isNull,
    );
    expect(
      _input(repeat: 'INTERVAL', maximum: 10, interval: 0).validationError,
      isNotNull,
    );
    expect(
      _input(repeat: 'INTERVAL', maximum: 10, interval: 365).validationError,
      isNull,
    );
    expect(_input(mode: 'USERS').validationError, isNotNull);
    expect(_input(mode: 'USERS', users: [_user]).validationError, isNull);
    expect(
      _input(mode: 'USERS', users: List.filled(101, _user)).validationError,
      isNotNull,
    );
    expect(_input(target: 'PROFILE').validationError, isNotNull);
    expect(_input(target: 'PROFILE', targetId: _user).validationError, isNull);
  });

  test(
    'wire request excludes inactive audience, target and recurrence fields',
    () {
      final json = _input(
        mode: 'ALL',
        users: [_user],
        profiles: ['MUSICIAN'],
        targetId: _user,
        maximum: 20,
        days: [1],
      ).toJson();
      expect(json['audience'], {
        'mode': 'ALL',
        'profileTypes': [],
        'userIds': [],
      });
      expect(json['target'], {'kind': 'HOME'});
      expect((json['schedule'] as Map).containsKey('maxOccurrences'), isFalse);
      expect((json['schedule'] as Map)['weekDays'], isEmpty);
    },
  );

  test(
    'response rejects unknown states, fractional versions and missing zone local time',
    () {
      for (final value in [
        _campaign()..['status'] = 'SENDING',
        _campaign()..['version'] = 0.5,
        _campaign()..['id'] = 'wrong',
        _campaign()
          ..['schedule'] = {
            ...(_campaign()['schedule'] as Map),
            'localStartsAt': '2028-01-01T10:00:00Z',
          },
      ]) {
        expect(() => NotificationCampaign.fromJson(value), throwsA(anything));
      }
    },
  );

  test(
    'role gate rejects listener role even with admin, inactive and expired sessions',
    () async {
      for (final session in [
        const AuthSession.guest(),
        _admin(roles: ['ROLE_LISTENER', 'ROLE_ADMIN']),
        _admin(roles: ['ROLE_MUSICIAN']),
        _admin(status: 'PASSIVE'),
        _admin(expires: DateTime.utc(2020)),
      ]) {
        final sessions = AudienceTestSessions(session);
        final api = _Api();
        final result = await NotificationCampaignRepository(
          api,
          sessions,
        ).load();
        expect(result.isSuccess, isFalse);
        expect(api.calls, isEmpty);
        sessions.dispose();
      }
      expect(
        canManageNotificationCampaigns(_admin(roles: ['ROLE_OWNER'])),
        isTrue,
      );
    },
  );

  test(
    'create has stable request identity and immutable normalized draft response',
    () async {
      final sessions = AudienceTestSessions(_admin());
      final api = _Api()..handler = (_) async => _campaign();
      final result = await NotificationCampaignRepository(
        api,
        sessions,
      ).save(_input(), requestId: _request);
      expect(result.isSuccess, isTrue);
      expect(api.calls.single.method, ApiHttpMethod.post);
      expect((api.calls.single.body as Map)['requestId'], _request);
      expect(api.calls.single.context?.expectedToken, 'admin-token');
      expect(api.calls.single.context?.expectedSessionKey, _user);
      sessions.dispose();
    },
  );

  test(
    'create requires requestId and cannot edit scheduled campaign',
    () async {
      final sessions = AudienceTestSessions(_admin());
      final api = _Api();
      final repo = NotificationCampaignRepository(api, sessions);
      expect((await repo.save(_input())).isSuccess, isFalse);
      expect(
        (await repo.save(
          _input(),
          existing: NotificationCampaign.fromJson(
            _campaign(status: 'SCHEDULED'),
          ),
        )).isSuccess,
        isFalse,
      );
      expect(api.calls, isEmpty);
      sessions.dispose();
    },
  );

  test(
    'commands carry expected version and reject cross-campaign response',
    () async {
      final sessions = AudienceTestSessions(_admin());
      final api = _Api()
        ..handler = (_) async => _campaign(status: 'SCHEDULED')..['id'] = _user;
      final repo = NotificationCampaignRepository(api, sessions);
      final result = await repo.transition(
        NotificationCampaign.fromJson(_campaign()),
        'schedule',
      );
      expect(
        api.calls.single.url,
        '${NotificationCampaignRepository.path}/$_id/schedule',
      );
      expect(api.calls.single.body, {'expectedVersion': 2});
      expect(result.isSuccess, isFalse);
      sessions.dispose();
    },
  );

  test('only matching state commands can issue a request', () async {
    final sessions = AudienceTestSessions(_admin());
    final api = _Api();
    final repo = NotificationCampaignRepository(api, sessions);
    final draft = NotificationCampaign.fromJson(_campaign());
    for (final command in ['pause', 'resume', 'delete']) {
      expect((await repo.transition(draft, command)).isSuccess, isFalse);
    }
    expect(api.calls, isEmpty);
    sessions.dispose();
  });

  test('request rejects delayed A to B to A response', () async {
    final original = _admin();
    final sessions = AudienceTestSessions(original);
    final pending = Completer<Object?>();
    final api = _Api()..handler = (_) => pending.future;
    final result = NotificationCampaignRepository(api, sessions).load();
    sessions.replace(const AuthSession.guest());
    sessions.replace(original);
    pending.complete(_page());
    expect((await result).error?.code, 'campaign_access_changed');
    sessions.dispose();
  });

  test('lookup is scoped and bounded before network IO', () async {
    final sessions = AudienceTestSessions(_admin());
    final api = _Api()
      ..handler = (_) async => [
        {
          'id': _user,
          'username': 'deniz',
          'displayName': 'Deniz',
          'profileType': 'MUSICIAN',
        },
      ];
    final repo = NotificationCampaignRepository(api, sessions);
    expect((await repo.search('a')).isSuccess, isFalse);
    expect((await repo.search('deniz', targetKind: 'HOME')).isSuccess, isFalse);
    expect(api.calls, isEmpty);
    final users = await repo.search('  deniz  ');
    expect(users.data?.single.label, 'Deniz');
    expect(api.calls.single.query, {'q': 'deniz'});
    expect(
      api.calls.single.url,
      '${NotificationCampaignRepository.path}/users',
    );
    sessions.dispose();
  });

  testWidgets('opening management only lists, no create or send request', (
    tester,
  ) async {
    final sessions = AudienceTestSessions(_admin());
    final api = _Api()..handler = (_) async => _page();
    await tester.pumpWidget(
      MaterialApp(
        home: NotificationCampaignScreen(
          repository: NotificationCampaignRepository(api, sessions),
          sessions: sessions,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(api.calls, hasLength(1));
    expect(api.calls.single.method, ApiHttpMethod.get);
    expect(find.textContaining('Henüz bildirim planı yok'), findsOneWidget);
    await tester.tap(find.byKey(const Key('campaign-create')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('campaign-title')), findsOneWidget);
    expect(api.calls, hasLength(1));
    await tester.pumpWidget(const SizedBox());
    sessions.dispose();
  });

  testWidgets('validation prevents saving empty new message', (tester) async {
    final sessions = AudienceTestSessions(_admin());
    final api = _Api();
    await _editor(tester, sessions, api);
    await _reveal(tester, find.byKey(const Key('campaign-save')));
    await tester.tap(find.byKey(const Key('campaign-save')));
    await tester.pump();
    expect(api.calls, isEmpty);
    expect(find.byKey(const Key('campaign-schedule')), findsNothing);
    await tester.pumpWidget(const SizedBox());
    sessions.dispose();
  });

  testWidgets('plan confirmation can be canceled without sending', (
    tester,
  ) async {
    final sessions = AudienceTestSessions(_admin());
    final api = _Api()..handler = (_) async => _campaign();
    await _editor(tester, sessions, api, existing: true);
    final plan = find.byKey(const Key('campaign-schedule'));
    await _reveal(tester, plan);
    await tester.tap(plan);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.text('Vazgeç'));
    await tester.pumpAndSettle();
    expect(api.calls, hasLength(1));
    expect(api.calls.single.method, ApiHttpMethod.get);
    await tester.pumpWidget(const SizedBox());
    sessions.dispose();
  });

  testWidgets(
    'revocation redacts an already open plan confirmation and prevents send',
    (tester) async {
      final sessions = AudienceTestSessions(_admin());
      final api = _Api()..handler = (_) async => _campaign();
      await _editor(tester, sessions, api, existing: true);
      await _reveal(tester, find.byKey(const Key('campaign-schedule')));
      await tester.tap(find.byKey(const Key('campaign-schedule')));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.textContaining('Yeni içerikler seni bekliyor'),
        ),
        findsOneWidget,
      );
      sessions.replace(const AuthSession.guest());
      await tester.pumpAndSettle();
      expect(find.textContaining('Yeni içerikler seni bekliyor'), findsNothing);
      expect(find.text('Oturum değişti'), findsOneWidget);
      expect(
        find.widgetWithText(FilledButton, 'Gönderimi planla'),
        findsNothing,
      );
      expect(
        api.calls.where((call) => call.method != ApiHttpMethod.get),
        isEmpty,
      );
      await tester.pumpWidget(const SizedBox());
      sessions.dispose();
    },
  );

  testWidgets(
    'confirmed plan sends version exactly once and freezes draft content',
    (tester) async {
      final sessions = AudienceTestSessions(_admin());
      final api = _Api()
        ..handler = (call) async => _campaign(
          status: call.method == ApiHttpMethod.post ? 'SCHEDULED' : 'DRAFT',
        );
      await _editor(tester, sessions, api, existing: true);
      await _reveal(tester, find.byKey(const Key('campaign-schedule')));
      await tester.tap(find.byKey(const Key('campaign-schedule')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(FilledButton, 'Gönderimi planla').last,
      );
      await tester.pumpAndSettle();
      expect(
        api.calls.where((c) => c.method == ApiHttpMethod.post),
        hasLength(1),
      );
      expect(api.calls.last.body, {'expectedVersion': 2});
      await _reveal(tester, find.byKey(const Key('campaign-title')), up: true);
      expect(
        tester
            .widget<TextFormField>(find.byKey(const Key('campaign-title')))
            .enabled,
        isFalse,
      );
      await tester.pumpWidget(const SizedBox());
      sessions.dispose();
    },
  );

  testWidgets(
    'version conflict requires fresh server state before another command',
    (tester) async {
      final sessions = AudienceTestSessions(_admin());
      final api = _Api()
        ..handler = (call) async {
          if (call.method == ApiHttpMethod.post) {
            throw ApiException(
              const AppError(code: '1910', message: 'Kayıt değişti.'),
            );
          }
          return _campaign();
        };
      await _editor(tester, sessions, api, existing: true);
      await _reveal(tester, find.byKey(const Key('campaign-schedule')));
      await tester.tap(find.byKey(const Key('campaign-schedule')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(FilledButton, 'Gönderimi planla').last,
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('campaign-schedule')), findsNothing);
      await _reveal(
        tester,
        find.widgetWithText(OutlinedButton, 'Kayıtlı durumu yenile'),
        up: true,
      );
      await tester.tap(
        find.widgetWithText(OutlinedButton, 'Kayıtlı durumu yenile'),
      );
      await tester.pumpAndSettle();
      expect(
        api.calls.where((c) => c.method == ApiHttpMethod.get),
        hasLength(2),
      );
      await _reveal(tester, find.byKey(const Key('campaign-schedule')));
      expect(find.byKey(const Key('campaign-schedule')), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      sessions.dispose();
    },
  );

  testWidgets(
    'revocation hides in-flight private campaign results permanently',
    (tester) async {
      final original = _admin();
      final sessions = AudienceTestSessions(original);
      final pending = Completer<Object?>();
      final api = _Api()..handler = (_) => pending.future;
      await tester.pumpWidget(
        MaterialApp(
          home: NotificationCampaignScreen(
            repository: NotificationCampaignRepository(api, sessions),
            sessions: sessions,
          ),
        ),
      );
      sessions.replace(const AuthSession.guest());
      sessions.replace(original);
      await tester.pump();
      pending.complete(_page(items: [_campaign()]));
      await tester.pumpAndSettle();
      expect(find.text('Bildirim yönetim yetkisi gerekli.'), findsOneWidget);
      expect(find.text('Yeni içerikler seni bekliyor'), findsNothing);
      expect(find.byKey(const Key('campaign-create')), findsNothing);
      await tester.pumpWidget(const SizedBox());
      sessions.dispose();
    },
  );

  testWidgets('editor remains readable on small phone at large text size', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 720);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final sessions = AudienceTestSessions(_admin());
    final api = _Api();
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(2)),
          child: child!,
        ),
        home: NotificationCampaignEditor(
          repository: NotificationCampaignRepository(api, sessions),
          sessions: sessions,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await _reveal(tester, find.byKey(const Key('campaign-save')));
    await tester.pump();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    sessions.dispose();
  });

  testWidgets(
    'creating a draft uses selected wall time and does not schedule',
    (tester) async {
      final sessions = AudienceTestSessions(_admin());
      final api = _Api()..handler = (_) async => _campaign();
      await _editor(tester, sessions, api);
      await tester.enterText(
        find.byKey(const Key('campaign-title')),
        'Birlikte müzik',
      );
      await tester.enterText(
        find.byKey(const Key('campaign-message')),
        'Yeni içerikleri keşfet.',
      );
      await _reveal(tester, find.text('Müzisyen'));
      await tester.tap(find.text('Müzisyen'));
      await tester.pump();
      await _reveal(tester, find.byKey(const Key('campaign-start')));
      await tester.tap(find.byKey(const Key('campaign-start')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Seç'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Seç'));
      await tester.pumpAndSettle();
      await _reveal(tester, find.byKey(const Key('campaign-save')));
      await tester.tap(find.byKey(const Key('campaign-save')));
      await tester.pumpAndSettle();
      expect(api.calls, hasLength(1));
      final body = api.calls.single.body as Map;
      expect(body['audience'], {
        'mode': 'PROFILE_TYPES',
        'profileTypes': ['MUSICIAN'],
        'userIds': [],
      });
      expect(body['requestId'], matches(RegExp(r'^[0-9a-f-]{36}$')));
      expect((body['schedule'] as Map)['zoneId'], 'Europe/Istanbul');
      expect((body['schedule'] as Map)['localStartsAt'], isNotNull);
      expect(api.calls.single.url, NotificationCampaignRepository.path);
      await tester.pumpWidget(const SizedBox());
      sessions.dispose();
    },
  );

  testWidgets(
    'unknown create outcome retries the identical request and does not duplicate intent',
    (tester) async {
      final sessions = AudienceTestSessions(_admin());
      var calls = 0;
      final api = _Api()
        ..handler = (_) async {
          if (++calls == 1) throw TimeoutException('Lost response');
          return _campaign();
        };
      await _editor(tester, sessions, api);
      await tester.enterText(
        find.byKey(const Key('campaign-title')),
        'Birlikte müzik',
      );
      await tester.enterText(
        find.byKey(const Key('campaign-message')),
        'Yeni içerikleri keşfet.',
      );
      await _reveal(tester, find.text('Müzisyen'));
      await tester.tap(find.text('Müzisyen'));
      await tester.pump();
      await _reveal(tester, find.byKey(const Key('campaign-start')));
      await tester.tap(find.byKey(const Key('campaign-start')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Seç'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Seç'));
      await tester.pumpAndSettle();
      await _reveal(tester, find.byKey(const Key('campaign-save')));
      await tester.tap(find.byKey(const Key('campaign-save')));
      await tester.pumpAndSettle();
      await _reveal(
        tester,
        find.widgetWithText(OutlinedButton, 'Aynı kaydın sonucunu doğrula'),
        up: true,
      );
      await tester.tap(
        find.widgetWithText(OutlinedButton, 'Aynı kaydın sonucunu doğrula'),
      );
      await tester.pumpAndSettle();
      expect(api.calls, hasLength(2));
      expect(api.calls.first.body, api.calls.last.body);
      await _reveal(tester, find.byKey(const Key('campaign-status')), up: true);
      expect(find.textContaining('Taslak'), findsWidgets);
      await tester.pumpWidget(const SizedBox());
      sessions.dispose();
    },
  );

  testWidgets('confirmed validation rejection keeps draft editable', (
    tester,
  ) async {
    final sessions = AudienceTestSessions(_admin());
    final api = _Api()
      ..handler = (call) async {
        if (call.method == ApiHttpMethod.put) {
          throw ApiException(
            const AppError(code: '9251', message: 'Başlık geçersiz.'),
          );
        }
        return _campaign();
      };
    await _editor(tester, sessions, api, existing: true);
    await tester.enterText(
      find.byKey(const Key('campaign-title')),
      'Yeni başlık',
    );
    await _reveal(tester, find.byKey(const Key('campaign-save')));
    await tester.tap(find.byKey(const Key('campaign-save')));
    await tester.pumpAndSettle();
    await _reveal(tester, find.byKey(const Key('campaign-title')), up: true);
    expect(
      tester
          .widget<TextFormField>(find.byKey(const Key('campaign-title')))
          .enabled,
      isTrue,
    );
    expect(
      find.widgetWithText(OutlinedButton, 'Kayıtlı durumu yenile'),
      findsNothing,
    );
    await tester.pumpWidget(const SizedBox());
    sessions.dispose();
  });
}

void endsOnlyRegressionTests() {
  testWidgets(
    'loading an end-date-only draft preserves the absent occurrence cap',
    (tester) async {
      final sessions = AudienceTestSessions(_admin());
      final record = _campaign(endsOnly: true);
      final api = _Api()..handler = (_) async => record;
      await _editor(tester, sessions, api, record: record);
      await _reveal(tester, find.byKey(const Key('campaign-maximum')));
      expect(
        tester
            .widget<TextFormField>(find.byKey(const Key('campaign-maximum')))
            .controller!
            .text,
        isEmpty,
      );
      expect(find.textContaining('En fazla 10 gönderim'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      sessions.dispose();
    },
  );

  testWidgets(
    'title edit of end-date-only draft does not add an occurrence cap',
    (tester) async {
      final sessions = AudienceTestSessions(_admin());
      final record = _campaign(endsOnly: true);
      final api = _Api()..handler = (_) async => record;
      await _editor(tester, sessions, api, record: record);
      await tester.enterText(
        find.byKey(const Key('campaign-title')),
        'Sadece yeni başlık',
      );
      await _reveal(tester, find.byKey(const Key('campaign-save')));
      await tester.tap(find.byKey(const Key('campaign-save')));
      await tester.pumpAndSettle();
      final write = api.calls.singleWhere(
        (call) => call.method == ApiHttpMethod.put,
      );
      final schedule = (write.body as Map)['schedule'] as Map;
      expect(schedule.containsKey('maxOccurrences'), isFalse);
      expect(schedule['localEndsAt'], '2028-02-01T12:00:00');
      expect(schedule['repeat'], 'DAILY');
      await tester.pumpWidget(const SizedBox());
      sessions.dispose();
    },
  );

  testWidgets(
    'read-only end-date-only plan preview does not invent a ten-send cap',
    (tester) async {
      final sessions = AudienceTestSessions(_admin());
      final record = _campaign(status: 'SCHEDULED', endsOnly: true);
      final api = _Api()..handler = (_) async => record;
      await _editor(tester, sessions, api, record: record);
      await _reveal(tester, find.byKey(const Key('campaign-maximum')));
      final field = tester.widget<TextFormField>(
        find.byKey(const Key('campaign-maximum')),
      );
      expect(field.enabled, isFalse);
      expect(field.controller!.text, isEmpty);
      await _reveal(tester, find.textContaining('Her gün\nBitiş:'));
      expect(find.textContaining('En fazla 10 gönderim'), findsNothing);
      expect(api.calls, hasLength(1));
      await tester.pumpWidget(const SizedBox());
      sessions.dispose();
    },
  );
}

Future<void> _reveal(
  WidgetTester tester,
  Finder finder, {
  bool up = false,
}) async {
  await tester.scrollUntilVisible(
    finder,
    up ? -350 : 350,
    scrollable: find.byType(Scrollable).first,
    maxScrolls: 40,
  );
  await tester.pumpAndSettle();
}

CampaignInput _input({
  String repeat = 'ONCE',
  int? maximum,
  int? interval,
  List<int> days = const [],
  String mode = 'ALL',
  List<String> users = const [],
  List<String> profiles = const [],
  String target = 'HOME',
  String? targetId,
  DateTime? local,
  String zone = 'Europe/Istanbul',
}) => CampaignInput(
  title: 'Yeni içerikler seni bekliyor',
  message: 'SoundConnect dünyasına göz at.',
  audienceMode: mode,
  profileTypes: profiles,
  userIds: users,
  targetKind: target,
  targetId: targetId,
  localStartsAt: local ?? DateTime.utc(2028, 1, 1, 12),
  zoneId: zone,
  repeat: repeat,
  maxOccurrences: maximum,
  intervalDays: interval,
  weekDays: days,
);

Map<String, dynamic> _campaign({
  String status = 'DRAFT',
  bool endsOnly = false,
}) => {
  'id': _id,
  'version': 2,
  'title': 'Yeni içerikler seni bekliyor',
  'message': 'SoundConnect dünyasına göz at.',
  'audience': {'mode': 'ALL', 'profileTypes': [], 'userIds': []},
  'target': {'kind': 'HOME', 'targetId': null},
  'schedule': {
    'startsAt': '2028-01-01T09:00:00Z',
    'localStartsAt': '2028-01-01T12:00:00',
    'zoneId': 'Europe/Istanbul',
    'repeat': endsOnly ? 'DAILY' : 'ONCE',
    'intervalDays': null,
    'weekDays': [],
    'endsAt': endsOnly ? '2028-02-01T09:00:00Z' : null,
    'localEndsAt': endsOnly ? '2028-02-01T12:00:00' : null,
    'maxOccurrences': null,
  },
  'status': status,
  'nextRunAt': status == 'SCHEDULED' ? '2028-01-01T09:00:00Z' : null,
  'createdAt': '2026-10-07T00:00:00Z',
  'updatedAt': '2026-10-07T00:00:00Z',
  'stats': {
    'occurrences': 0,
    'recipients': 0,
    'notifications': 0,
    'skipped': 0,
  },
  'selectedUsers': [],
  'selectedTarget': null,
};
Map<String, dynamic> _page({List<Map<String, dynamic>> items = const []}) => {
  'items': items,
  'page': 0,
  'size': 20,
  'total': items.length,
};
AuthSession _admin({
  List<String> roles = const ['ROLE_ADMIN'],
  String status = 'ACTIVE',
  DateTime? expires,
}) => AuthSession.authenticated(
  token: 'admin-token',
  userId: _user,
  username: 'admin',
  accountStatus: status,
  roles: roles,
  permissions: const [],
  expiresAt: expires ?? DateTime.utc(2100),
  isAdmin: true,
);
Future<void> _editor(
  WidgetTester tester,
  AudienceTestSessions sessions,
  _Api api, {
  bool existing = false,
  Map<String, dynamic>? record,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: NotificationCampaignEditor(
        repository: NotificationCampaignRepository(api, sessions),
        sessions: sessions,
        campaign: existing || record != null
            ? NotificationCampaign.fromJson(record ?? _campaign())
            : null,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

typedef _Call = ({
  ApiHttpMethod method,
  String url,
  Object? body,
  Map<String, dynamic>? query,
  ApiRequestContext? context,
});

class _Api extends Fake implements ApiClient {
  final calls = <_Call>[];
  Future<Object?> Function(_Call)? handler;
  @override
  Future<T> request<T>(
    ApiHttpMethod method,
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    T Function(Object?)? decoder,
    ApiRequestContext? requestContext,
  }) async {
    final call = (
      method: method,
      url: path,
      body: body,
      query: query,
      context: requestContext,
    );
    calls.add(call);
    if (handler == null) throw StateError('Unexpected API call');
    return decoder!(await handler!(call));
  }
}
