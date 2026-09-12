import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session_manager.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session_store.dart';
import 'package:soundconnect_23_12_25codx/core/network/api_client.dart';
import 'package:soundconnect_23_12_25codx/modules/admin/presentation/screens/admin_dashboard_screen.dart';
import 'package:soundconnect_23_12_25codx/shared/theme/app_theme.dart';
import 'package:soundconnect_23_12_25codx/shared/widgets/session_logout_action.dart';

import 'support/auth_widget_test_support.dart';

const _homeKey = Key('admin-home-empty');
const _sponsorshipsKey = Key('admin-sponsorships-empty');

void main() {
  setUp(() async => GetIt.instance.reset());
  tearDown(() async => GetIt.instance.reset());

  testWidgets('renders the empty shell without API or service registration', (
    tester,
  ) async {
    expect(GetIt.instance.isRegistered<ApiClient>(), isFalse);
    expect(GetIt.instance.isRegistered<AuthSessionManager>(), isFalse);

    await _pumpPanel(tester);

    expect(find.text('Admin Paneli'), findsOneWidget);
    expect(find.text('Ana Sayfa'), findsOneWidget);
    expect(find.text('Sponsorluklar'), findsOneWidget);
    expect(find.byKey(sessionLogoutButtonKey), findsOneWidget);
    expect(find.byType(Tab), findsNWidgets(2));
    expect(_controller(tester).index, 0);
    expect(find.byKey(_homeKey), findsOneWidget);
    _expectEmptyTabBodies(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('contains no legacy modules, dashboard metrics or placeholders', (
    tester,
  ) async {
    await _pumpPanel(tester);

    for (final label in <String>[
      'Mekân Başvuruları',
      'Stüdyo Başvuruları',
      'Backline Kategori Talepleri',
      'Collab Moderasyonu',
      'Kullanıcılar',
      'Profiller',
      'Promosyonlar',
      'Mekânlar',
      'Konumlar',
      'Enstrümanlar',
      'DM Moderasyon',
      'Roller',
      'Onayla',
      'Reddet',
      'Onaylanan',
      'Bekleyen',
    ]) {
      expect(find.text(label), findsNothing, reason: label);
    }
    expect(
      tester.widgetList<Text>(find.byType(Text)).map((text) => text.data),
      unorderedEquals(<String>['Admin Paneli', 'Ana Sayfa', 'Sponsorluklar']),
    );
    expect(find.byType(Card), findsNothing);
    expect(find.byType(RefreshIndicator), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byType(TextField), findsNothing);
    expect(find.byType(FloatingActionButton), findsNothing);
    expect(find.byType(BackButton), findsNothing);
    _expectEmptyTabBodies(tester);
  });

  testWidgets('switches to empty sponsorships and back without loading data', (
    tester,
  ) async {
    await _pumpPanel(tester);

    await tester.tap(find.text('Sponsorluklar'));
    await tester.pumpAndSettle();

    expect(_controller(tester).index, 1);
    expect(find.byKey(_sponsorshipsKey), findsOneWidget);
    _expectEmptyTabBodies(tester);

    await tester.tap(find.text('Ana Sayfa'));
    await tester.pumpAndSettle();

    expect(_controller(tester).index, 0);
    expect(find.byKey(_homeKey), findsOneWidget);
    expect(GetIt.instance.isRegistered<ApiClient>(), isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('supports swiping between the two empty tabs', (tester) async {
    await _pumpPanel(tester);

    await tester.drag(find.byType(TabBarView), const Offset(-600, 0));
    await tester.pumpAndSettle();
    expect(_controller(tester).index, 1);

    await tester.drag(find.byType(TabBarView), const Offset(600, 0));
    await tester.pumpAndSettle();
    expect(_controller(tester).index, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tabs expose selection and working screen-reader actions', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      await _pumpPanel(tester);

      final home = tester.getSemantics(find.text('Ana Sayfa'));
      final sponsorships = tester.getSemantics(find.text('Sponsorluklar'));
      expect(home.hasFlag(ui.SemanticsFlag.isSelected), isTrue);
      expect(sponsorships.hasFlag(ui.SemanticsFlag.isSelected), isFalse);
      expect(
        sponsorships.getSemanticsData().hasAction(ui.SemanticsAction.tap),
        isTrue,
      );

      tester.binding.pipelineOwner.semanticsOwner!.performAction(
        sponsorships.id,
        ui.SemanticsAction.tap,
      );
      await tester.pumpAndSettle();

      expect(_controller(tester).index, 1);
      expect(
        tester
            .getSemantics(find.text('Sponsorluklar'))
            .hasFlag(ui.SemanticsFlag.isSelected),
        isTrue,
      );
      expect(
        tester
            .getSemantics(find.text('Ana Sayfa'))
            .hasFlag(ui.SemanticsFlag.isSelected),
        isFalse,
      );
      expect(tester.takeException(), isNull);
    } finally {
      semantics.dispose();
    }
  });

  for (final viewport in <({String name, Size size, double textScale})>[
    (name: 'small phone', size: const Size(320, 640), textScale: 1),
    (name: '200% text', size: const Size(320, 800), textScale: 2),
    (name: 'wide window', size: const Size(1280, 800), textScale: 1),
  ]) {
    testWidgets('tabs remain usable on ${viewport.name}', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = viewport.size;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      await _pumpPanel(tester, textScale: viewport.textScale);

      expect(tester.widget<TabBar>(find.byType(TabBar)).isScrollable, isTrue);
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Sponsorluklar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sponsorluklar'));
      await tester.pumpAndSettle();

      expect(_controller(tester).index, 1);
      _expectEmptyTabBodies(tester);
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Ana Sayfa'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ana Sayfa'));
      await tester.pumpAndSettle();

      expect(_controller(tester).index, 0);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('does not add an implicit app-bar back button when pushed', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.navy,
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
    await tester.tap(find.text('Open admin'));
    await tester.pumpAndSettle();

    expect(
      Navigator.of(tester.element(find.byType(AdminDashboardScreen))).canPop(),
      isTrue,
    );
    expect(find.byType(BackButton), findsNothing);
    expect(find.byType(DrawerButton), findsNothing);
    expect(find.byKey(sessionLogoutButtonKey), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('canceling logout retains the admin token and metadata', (
    tester,
  ) async {
    final stores = _registerAdminSession();
    await _pumpPanel(tester);

    await _openLogoutDialog(tester);
    expect(find.text('Çıkış yapılsın mı?'), findsOneWidget);
    await tester.tap(find.text('Vazgeç'));
    await tester.pumpAndSettle();

    expect(stores.token.token, 'admin-test-token');
    expect(stores.token.clearCalls, 0);
    expect(stores.session.metadata?.username, 'admin-test');
    expect(stores.session.clearCalls, 0);
    expect(find.byType(Dialog), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('confirming logout clears the session from the sponsorship tab', (
    tester,
  ) async {
    final stores = _registerAdminSession();
    await _pumpPanel(tester);
    await tester.tap(find.text('Sponsorluklar'));
    await tester.pumpAndSettle();

    await _openLogoutDialog(tester);
    await tester.tap(find.byKey(sessionLogoutConfirmKey));
    await tester.pumpAndSettle();

    expect(stores.token.token, isNull);
    expect(stores.token.clearCalls, 1);
    expect(stores.session.metadata, isNull);
    expect(stores.session.clearCalls, 1);
    expect(find.byType(Dialog), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpPanel(WidgetTester tester, {double textScale = 1}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.navy,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: const AdminDashboardScreen(),
    ),
  );
  await tester.pumpAndSettle();
}

TabController _controller(WidgetTester tester) =>
    DefaultTabController.of(tester.element(find.byType(TabBar)));

void _expectEmptyTabBodies(WidgetTester tester) {
  final bodies = tester.widget<TabBarView>(find.byType(TabBarView)).children;
  expect(bodies, hasLength(2));
  expect(bodies.map((body) => body.key), <Key>[_homeKey, _sponsorshipsKey]);
  for (final body in bodies) {
    expect(body, isA<SizedBox>());
    expect((body as SizedBox).child, isNull);
  }
}

({MemoryTokenStore token, MemoryAuthSessionStore session})
_registerAdminSession() {
  final token = MemoryTokenStore()..token = 'admin-test-token';
  final session = MemoryAuthSessionStore()
    ..metadata = const AuthSessionMetadata(
      username: 'admin-test',
      accountStatus: 'ACTIVE',
    );
  GetIt.instance.registerSingleton<AuthSessionManager>(
    createSessionManager(tokenStore: token, sessionStore: session),
    dispose: (manager) => manager.dispose(),
  );
  return (token: token, session: session);
}

Future<void> _openLogoutDialog(WidgetTester tester) async {
  await tester.tap(find.byKey(sessionLogoutButtonKey));
  await tester.pump();
  // The logout button spins while its confirmation dialog is open.
  await tester.pump(const Duration(milliseconds: 300));
}
