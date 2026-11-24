import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soundconnect_23_12_25codx/app/router/app_router.dart';
import 'package:soundconnect_23_12_25codx/app/router/app_routes.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session_manager.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session_store.dart';
import 'package:soundconnect_23_12_25codx/core/network/api_client.dart';
import 'package:soundconnect_23_12_25codx/modules/admin/data/system_health_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/admin/domain/collab_report_admin_access.dart';
import 'package:soundconnect_23_12_25codx/modules/admin/domain/musician_feed_report_admin.dart';
import 'package:soundconnect_23_12_25codx/modules/admin/domain/pending_application.dart';
import 'package:soundconnect_23_12_25codx/modules/admin/presentation/screens/admin_dashboard_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/admin/presentation/screens/system_health_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/admin/presentation/widgets/admin_panel_frame.dart';
import 'package:soundconnect_23_12_25codx/shared/theme/app_theme.dart';
import 'package:soundconnect_23_12_25codx/shared/theme/app_theme_controller.dart';
import 'package:soundconnect_23_12_25codx/shared/widgets/session_logout_action.dart';

import 'support/auth_widget_test_support.dart';
import 'support/event_audience_fakes.dart';
import 'support/recording_api_client.dart';

const _permissions = [
  'ADMIN_PANEL_ACCESS',
  'MANAGE_VENUE_APPLICATIONS',
  'MANAGE_STUDIO_APPLICATIONS',
  'MANAGE_MARKETPLACE_REPORTS',
  collabReportAdminPermission,
  musicianFeedReportAdminPermission,
  'MANAGE_PROMOTIONS',
];

Finder _entry(String key) => find.byKey(Key('admin-$key'));
Finder _nav(String section) => _entry('nav-$section');

AuthSession _admin({
  List<String> permissions = _permissions,
  List<String> roles = const ['ROLE_ADMIN'],
}) => AuthSession.authenticated(
  token: 'admin-token',
  userId: 'reviewer',
  username: 'admin',
  accountStatus: 'ACTIVE',
  roles: roles,
  permissions: permissions,
  expiresAt: DateTime.utc(2100),
  isAdmin: true,
);

AudienceTestSessions _register([AuthSession? session]) {
  final sessions = AudienceTestSessions(session ?? _admin());
  GetIt.instance.registerSingleton<AuthSessionManager>(
    sessions,
    dispose: (value) => value.dispose(),
  );
  return sessions;
}

Future<void> _pump(
  WidgetTester tester, {
  Size size = const Size(390, 800),
  double textScale = 1,
  RouteFactory? onGenerateRoute,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.current,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: const AdminDashboardScreen(),
      onGenerateRoute: onGenerateRoute,
    ),
  );
  await tester.pumpAndSettle();
}

RouteFactory _record(List<RouteSettings> opened) => (settings) {
  opened.add(settings);
  return MaterialPageRoute<void>(
    settings: settings,
    builder: (_) => Scaffold(body: Text(settings.name!)),
  );
};

Future<void> _tap(WidgetTester tester, Finder item) async {
  await tester.tap(item);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() async {
    await GetIt.instance.reset();
    SharedPreferences.setMockInitialValues({});
  });
  tearDown(() async {
    await GetIt.instance.reset();
    await AppThemeController.instance.setVariant(AppThemeVariant.dark);
  });

  testWidgets(
    'authorized application cards are the landing screen and only open their own named queue',
    (tester) async {
      _register();
      final opened = <RouteSettings>[];
      await _pump(tester, onGenerateRoute: _record(opened));
      for (final section in [
        'applications',
        'reports',
        'publishing',
        'system',
      ]) {
        expect(_nav(section).hitTestable(), findsOneWidget);
      }
      expect(GetIt.instance.isRegistered<ApiClient>(), isFalse);
      for (final kind in ApplicationKind.values) {
        final card = _entry('applications-${kind.name}');
        expect(card.hitTestable(), findsOneWidget);
        await _tap(tester, card);
        final settings = opened.last;
        expect(settings.name, AppRoutes.adminApplications);
        expect((settings.arguments as AdminApplicationEntry).kind, kind);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
      }
      expect(opened, hasLength(2));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'single-kind permission hides the other queue and a replaced session invalidates a captured card',
    (tester) async {
      final sessions = _register(
        _admin(
          permissions: const [
            'ADMIN_PANEL_ACCESS',
            'MANAGE_STUDIO_APPLICATIONS',
          ],
        ),
      );
      final opened = <RouteSettings>[];
      await _pump(tester, onGenerateRoute: _record(opened));
      expect(_entry('applications-venue'), findsNothing);
      expect(_nav('reports'), findsNothing);
      final studio = _entry('applications-studio');
      final staleTap = tester.widget<InkWell>(studio).onTap!;
      sessions.replace(
        _admin(
          permissions: const [
            'ADMIN_PANEL_ACCESS',
            'MANAGE_VENUE_APPLICATIONS',
          ],
        ),
      );
      staleTap();
      await tester.pumpAndSettle();
      expect(opened, isEmpty);
      expect(studio, findsNothing);
      expect(_entry('applications-venue'), findsOneWidget);
    },
  );

  testWidgets(
    'notification shortcut is reachable at 360dp and rechecks the current session',
    (tester) async {
      final sessions = _register();
      final opened = <RouteSettings>[];
      await _pump(
        tester,
        size: const Size(360, 800),
        onGenerateRoute: _record(opened),
      );
      final bell = _entry('notification-home-entry');
      expect(bell.hitTestable(), findsOneWidget);
      final stale = tester.widget<IconButton>(bell).onPressed!;
      sessions.replace(const AuthSession.guest());
      stale();
      await tester.pumpAndSettle();
      expect(opened, isEmpty);
      expect(bell, findsNothing);
      sessions.replace(_admin());
      await tester.pumpAndSettle();
      await _tap(tester, bell);
      expect(opened.single.name, AppRoutes.adminNotificationCampaigns);
    },
  );

  testWidgets(
    'publishing offers separate announcement and private notification destinations; removed access fences an old action',
    (tester) async {
      final sessions = _register();
      final opened = <RouteSettings>[];
      await _pump(tester, onGenerateRoute: _record(opened));
      await _tap(tester, _nav('publishing'));
      expect(_entry('announcements-entry'), findsOneWidget);
      final notifications = _entry('notification-campaigns-entry');
      final stale = tester.widget<InkWell>(notifications).onTap!;
      sessions.replace(const AuthSession.guest());
      stale();
      await tester.pumpAndSettle();
      expect(opened, isEmpty);
      expect(notifications, findsNothing);
      sessions.replace(_admin(permissions: const []));
      await tester.pumpAndSettle();
      expect(_nav('applications'), findsNothing);
      expect(_entry('announcements-entry'), findsNothing);
      await _tap(tester, notifications);
      expect(opened.single.name, AppRoutes.adminNotificationCampaigns);
    },
  );

  testWidgets(
    'report visibility and routing use the exact permission for each source',
    (tester) async {
      final sessions = _register(
        _admin(permissions: const ['ADMIN_PANEL_ACCESS', 'MANAGE_USERS']),
      );
      final opened = <RouteSettings>[];
      await _pump(tester, onGenerateRoute: _record(opened));
      expect(_nav('reports'), findsNothing);
      sessions.replace(
        _admin(permissions: const [musicianFeedReportAdminPermission]),
      );
      await tester.pumpAndSettle();
      await _tap(tester, _nav('reports'));
      final feed = _entry('feed-reports-entry');
      final market = _entry('marketplace-reports-entry');
      final collab = _entry('collab-reports-entry');
      expect(market, findsNothing);
      expect(collab, findsNothing);
      final stale = tester.widget<InkWell>(feed).onTap!;
      sessions.replace(
        _admin(permissions: const ['MANAGE_MARKETPLACE_REPORTS']),
      );
      stale();
      await tester.pumpAndSettle();
      expect(feed, findsNothing);
      expect(opened, isEmpty);
      await _tap(tester, market);
      expect(opened.single.name, AppRoutes.adminMarketplaceReports);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      sessions.replace(
        _admin(permissions: const [collabReportAdminPermission]),
      );
      await tester.pumpAndSettle();
      expect(feed, findsNothing);
      expect(market, findsNothing);
      await _tap(tester, collab);
      expect(opened.last.name, AppRoutes.adminCollabReports);
      expect(opened.last.arguments, isA<AdminSubpageFrame>());
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      sessions.replace(_admin());
      await tester.pumpAndSettle();
      await _tap(tester, _nav('reports'));
      await _tap(tester, feed);
      expect(opened.last.name, AppRoutes.adminMusicianFeedReports);
    },
  );

  testWidgets(
    'no service registration renders a passive shell without privileged pages or data',
    (tester) async {
      await _pump(tester);
      expect(_entry('home-empty'), findsOneWidget);
      expect(find.byKey(sessionLogoutButtonKey), findsOneWidget);
      for (final section in [
        'applications',
        'reports',
        'publishing',
        'system',
      ]) {
        expect(_nav(section), findsNothing);
      }
      for (final text in [
        'Sponsorluklar',
        'Backline Kategori Talepleri',
        'Collab Moderasyonu',
        'DM Moderasyon',
        'Kullanıcılar',
        'Onayla',
        'Reddet',
      ]) {
        expect(find.text(text), findsNothing, reason: text);
      }
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byType(SystemHealthScreen), findsNothing);
      expect(GetIt.instance.isRegistered<ApiClient>(), isFalse);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'screen-reader can select a different work area and hear the selection',
    (tester) async {
      _register();
      final handle = tester.ensureSemantics();
      try {
        await _pump(tester);
        final previous = _nav('applications');
        final next = _nav('reports');
        final applications = tester.getSemantics(previous);
        final reports = tester.getSemantics(next);
        expect(applications.hasFlag(ui.SemanticsFlag.isSelected), isTrue);
        expect(reports.hasFlag(ui.SemanticsFlag.isSelected), isFalse);
        expect(
          reports.getSemanticsData().hasAction(ui.SemanticsAction.tap),
          isTrue,
        );
        tester.binding.pipelineOwner.semanticsOwner!.performAction(
          reports.id,
          ui.SemanticsAction.tap,
        );
        await tester.pumpAndSettle();
        expect(
          tester.getSemantics(next).hasFlag(ui.SemanticsFlag.isSelected),
          isTrue,
        );
        expect(
          tester.getSemantics(previous).hasFlag(ui.SemanticsFlag.isSelected),
          isFalse,
        );
        expect(_entry('marketplace-reports-entry'), findsOneWidget);
      } finally {
        handle.dispose();
      }
    },
  );

  testWidgets(
    'brand and destination labels fit as whole words at 320dp and 200%',
    (tester) async {
      _register(_admin(permissions: [..._permissions, 'READ_USERS']));
      await _pump(tester, size: const Size(320, 800), textScale: 2);
      for (final (text, label) in [
        ('SoundConnect', find.text('SoundConnect')),
        for (final section in AdminPanelSection.values)
          (
            section.label,
            find.descendant(
              of: _nav(section.name),
              matching: find.text(section.label),
            ),
          ),
      ]) {
        final paragraph = tester.renderObject<RenderParagraph>(label);
        final boxes = paragraph.getBoxesForSelection(
          TextSelection(baseOffset: 0, extentOffset: text.length),
        );
        expect(boxes, isNotEmpty, reason: text);
        expect(boxes.map((b) => b.top).toSet(), hasLength(1), reason: text);
        expect(
          paragraph.getBoxesForSelection(
            TextSelection(
              baseOffset: text.length - 1,
              extentOffset: text.length,
            ),
          ),
          isNotEmpty,
          reason: 'Last letter of $text is visible',
        );
      }
      expect(find.byTooltip('Kullanıcı ara').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final variant in AppThemeVariant.values) {
    testWidgets(
      'fixed destinations and report rows are usable at 320dp and 200% text in ${variant.name}',
      (tester) async {
        _register();
        await AppThemeController.instance.setVariant(variant);
        await _pump(tester, size: const Size(320, 800), textScale: 2);
        for (final section in [
          'applications',
          'reports',
          'publishing',
          'system',
        ]) {
          expect(_nav(section).hitTestable(), findsOneWidget);
        }
        await _tap(tester, _nav('reports'));
        final feed = _entry('feed-reports-entry');
        await tester.scrollUntilVisible(
          feed,
          150,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        expect(
          feed.hitTestable(),
          findsOneWidget,
          reason:
              'row ${tester.getRect(feed)} in viewport ${tester.getRect(find.byType(Scrollable).first)}',
        );
        expect(tester.takeException(), isNull);
        await _tap(tester, _nav('publishing'));
        final campaigns = _entry('notification-campaigns-entry');
        await tester.scrollUntilVisible(
          campaigns,
          150,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        expect(campaigns.hitTestable(), findsOneWidget);
        await _tap(tester, _nav('applications'));
        final studio = _entry('applications-studio');
        await tester.scrollUntilVisible(
          studio,
          150,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        expect(studio.hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'wide window keeps the current section accessible and navigates back to applications',
    (tester) async {
      _register();
      await _pump(tester, size: const Size(1280, 800));
      await _tap(tester, _nav('publishing'));
      expect(_entry('announcements-entry').hitTestable(), findsOneWidget);
      await _tap(tester, _nav('applications'));
      expect(_entry('applications-venue').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'a system-only operator can open health from the landing card without background requests',
    (tester) async {
      _register(
        _admin(
          permissions: const ['ADMIN_PANEL_ACCESS'],
          roles: const ['ROLE_MUSICIAN'],
        ),
      );
      final api = RecordingApiClient((request) {
        if (request.path.endsWith('/mobile-events')) return {'events': []};
        return {
          'status': 'UP',
          'generatedAt': '2026-11-22T06:30:00Z',
          'refreshIntervalSeconds': 15,
          'staleAfterSeconds': 60,
          'components': [],
        };
      });
      GetIt.instance.registerSingleton<ApiClient>(api);
      await _pump(tester);
      final openHealth = find.text('Sistem sağlığını aç');
      expect(openHealth.hitTestable(), findsOneWidget);
      expect(_nav('applications'), findsNothing);
      expect(_nav('reports'), findsNothing);
      expect(_nav('publishing'), findsNothing);
      await tester.pump(const Duration(seconds: 30));
      expect(find.byType(SystemHealthScreen), findsNothing);
      expect(api.requests, isEmpty);
      await _tap(tester, openHealth);
      expect(
        tester
            .widget<SystemHealthScreen>(find.byType(SystemHealthScreen))
            .embedded,
        isTrue,
      );
      expect(
        api.requests.map((request) => request.path),
        unorderedEquals([
          SystemHealthRepository.path,
          '${SystemHealthRepository.path}/mobile-events',
        ]),
      );
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'system measurements start only on explicit entry and stop on leaving or revocation',
    (tester) async {
      final sessions = _register();
      final api = RecordingApiClient((request) {
        if (request.path.endsWith('/mobile-events')) return {'events': []};
        expect(request.path, SystemHealthRepository.path);
        return {
          'status': 'UP',
          'generatedAt': '2026-11-22T06:30:00Z',
          'refreshIntervalSeconds': 15,
          'staleAfterSeconds': 60,
          'components': [],
        };
      });
      GetIt.instance.registerSingleton<ApiClient>(api);
      await _pump(tester);
      await tester.pump(const Duration(seconds: 30));
      expect(api.requests, isEmpty);
      await _tap(tester, _nav('system'));
      expect(find.byType(SystemHealthScreen), findsOneWidget);
      final expectedRequests = [
        SystemHealthRepository.path,
        '${SystemHealthRepository.path}/mobile-events',
      ];
      expect(
        api.requests.map((r) => r.path),
        unorderedEquals(expectedRequests),
      );
      await _tap(tester, _nav('applications'));
      await tester.pump(const Duration(seconds: 30));
      expect(find.byType(SystemHealthScreen), findsNothing);
      expect(api.requests, hasLength(2));
      await _tap(tester, _nav('system'));
      expect(api.requests, hasLength(4));
      sessions.replace(const AuthSession.guest());
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 30));
      expect(find.byType(SystemHealthScreen), findsNothing);
      expect(api.requests, hasLength(4));
      sessions.replace(_admin());
      await tester.pumpAndSettle();
      expect(_entry('applications-studio'), findsOneWidget);
      expect(api.requests, hasLength(4));
    },
  );

  testWidgets(
    'switching sections from a real studio detail returns to the panel and cannot resurface a stale detail',
    (tester) async {
      _register();
      const row = {
        'id': 'studio-one',
        'businessName': 'Kayıt Atölyesi',
        'applicantUsername': 'kayit',
        'status': 'PENDING',
        'cityName': 'İzmir',
        'districtName': 'Konak',
        'applicationDate': '2026-11-21T09:00:00Z',
      };
      final api = RecordingApiClient((request) {
        if (request.path == '/api/v1/admin/studio-applications/pending') {
          return {
            'page': 0,
            'last': true,
            'content': [row],
          };
        }
        expect(
          request.path,
          '/api/v1/admin/studio-applications/review/studio-one',
        );
        return {...row, 'phone': '05550000025', 'address': 'Örnek sokak'};
      });
      GetIt.instance.registerSingleton<ApiClient>(api);
      await _pump(tester, onGenerateRoute: AppRouter.onGenerateRoute);
      await _tap(tester, _entry('applications-studio'));
      await _tap(tester, find.text('Kayıt Atölyesi'));
      expect(find.text('Telefon'), findsOneWidget);
      expect(api.requests, hasLength(2));
      await _tap(tester, _nav('reports'));
      expect(_entry('feed-reports-entry'), findsOneWidget);
      final nav = Navigator.of(
        tester.element(find.byType(AdminDashboardScreen)),
      );
      expect(nav.canPop(), isFalse);
      await _tap(tester, _nav('applications'));
      expect(_entry('applications-studio'), findsOneWidget);
      expect(find.text('Kayıt Atölyesi'), findsNothing);
      expect(
        api.requests.every((r) => r.method == RecordedHttpMethod.get),
        isTrue,
      );
    },
  );

  testWidgets(
    'pushed panel does not add an implicit back button to its root header',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) => const AdminDashboardScreen(),
                  ),
                ),
                child: const Text('Open admin'),
              ),
            ),
          ),
        ),
      );
      await _tap(tester, find.text('Open admin'));
      expect(
        Navigator.of(
          tester.element(find.byType(AdminDashboardScreen)),
        ).canPop(),
        isTrue,
      );
      expect(find.byType(BackButton), findsNothing);
      expect(find.byType(DrawerButton), findsNothing);
      expect(find.byKey(sessionLogoutButtonKey), findsOneWidget);
    },
  );

  for (final confirm in [false, true]) {
    testWidgets(
      'logout ${confirm ? 'confirms and clears' : 'cancels and retains'} the real credentials from publishing',
      (tester) async {
        final payload = base64UrlEncode(
          utf8.encode(
            jsonEncode({
              'sub': 'admin-test',
              'exp': DateTime.utc(2100).millisecondsSinceEpoch ~/ 1000,
              'roles': ['ROLE_ADMIN'],
              'permissions': _permissions,
            }),
          ),
        );
        final raw = 'test.$payload.signature';
        final token = MemoryTokenStore()..token = raw;
        final session = MemoryAuthSessionStore()
          ..metadata = const AuthSessionMetadata(
            username: 'admin-test',
            accountStatus: 'ACTIVE',
          );
        final manager = createSessionManager(
          tokenStore: token,
          sessionStore: session,
        );
        GetIt.instance.registerSingleton<AuthSessionManager>(
          manager,
          dispose: (v) => v.dispose(),
        );
        await manager.restore();
        await _pump(tester);
        await _tap(tester, _nav('publishing'));
        await tester.tap(find.byKey(sessionLogoutButtonKey));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text('Çıkış yapılsın mı?'), findsOneWidget);
        await _tap(
          tester,
          confirm ? find.byKey(sessionLogoutConfirmKey) : find.text('Vazgeç'),
        );
        expect(token.token, confirm ? isNull : raw);
        expect(token.clearCalls, confirm ? 1 : 0);
        expect(session.metadata?.username, confirm ? isNull : 'admin-test');
        expect(session.clearCalls, confirm ? 1 : 0);
        expect(find.byType(Dialog), findsNothing);
        await tester.pumpWidget(const SizedBox.shrink());
        await GetIt.instance.reset();
      },
    );
  }
}
