import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/app/router/app_routes.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session_manager.dart';
import 'package:soundconnect_23_12_25codx/core/di/service_locator.dart';
import 'package:soundconnect_23_12_25codx/core/error/result.dart';
import 'package:soundconnect_23_12_25codx/modules/dm/presentation/cubit/dm_badge_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/dm/presentation/cubit/dm_badge_state.dart';
import 'package:soundconnect_23_12_25codx/modules/overthinking/domain/entities/overthinking_incoming_unread_status.dart';
import 'package:soundconnect_23_12_25codx/modules/overthinking/domain/overthinking_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/overthinking/presentation/cubit/overthinking_incoming_unread_binding.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/profile_public_bottom_bar.dart';
import 'package:soundconnect_23_12_25codx/shared/theme/app_theme.dart';

import 'support/event_audience_fakes.dart';

const _preview = bool.fromEnvironment('OVERTHINKING_PREVIEW');
const _previewKey = ValueKey('navigation-preview');
const _navigationDot = ValueKey('overthinking-navigation-unread-dot');
const _launcherDot = ValueKey('overthinking-launcher-unread-dot');

void main() {
  late _Inbox repository;
  late AudienceTestSessions sessions;
  final routes = <String?>[];

  setUp(() {
    routes.clear();
    repository = _Inbox();
    sessions = AudienceTestSessions(audienceSession());
    serviceLocator
      ..registerSingleton<AuthSessionManager>(
        sessions,
        dispose: (_) => sessions.dispose(),
      )
      ..registerSingleton<OverthinkingRepository>(repository)
      ..registerSingleton<DmBadgeCubit>(
        _DmBadge(),
        dispose: (badge) => badge.close(),
      );
  });

  tearDown(() async => serviceLocator.reset());

  Future<void> mount(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    if (_preview) await _loadFonts(tester);
    await tester.pumpWidget(
      RepaintBoundary(
        key: _previewKey,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.navy,
          home: Scaffold(bottomNavigationBar: ProfilePublicBottomBar()),
          onGenerateRoute: (settings) {
            routes.add(settings.name);
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (_) => const Scaffold(body: Text('Overthinking akışı')),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  bool visible(WidgetTester tester, Key key) =>
      tester.widget<Badge>(find.byKey(key)).isLabelVisible;

  testWidgets(
    'listener entry updates outside the feed and does not mark seen',
    (tester) async {
      await mount(tester);
      expect(visible(tester, _navigationDot), isTrue);
      expect(repository.reads, 1);
      expect(repository.acks, 0);
      final shared = requireOverthinkingIncomingUnreadScope();
      expect(repository.reads, 1);
      await shared.markSeen();
      await tester.pumpAndSettle();
      expect(visible(tester, _navigationDot), isFalse);

      repository.revision++;
      await shared.refresh();
      await tester.pumpAndSettle();
      expect(visible(tester, _navigationDot), isTrue);
      await _capture(tester, 'listener-navigation-unread-390x844');
      await tester.tap(find.text('Overthinking'));
      await tester.pumpAndSettle();
      expect(routes, [AppRoutes.overthinkingFeed]);
      expect(repository.acks, 1);
      expect(shared.isClosed, isFalse);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('musician Git option shares unread state without acknowledging', (
    tester,
  ) async {
    sessions.replace(audienceSession(role: 'ROLE_MUSICIAN'));
    await mount(tester);
    expect(find.byKey(_navigationDot), findsNothing);
    await tester.tap(find.text('Git'));
    await tester.pumpAndSettle();
    expect(visible(tester, _launcherDot), isTrue);
    expect(repository.acks, 0);
    await _capture(tester, 'musician-launcher-unread-390x844');

    final shared = requireOverthinkingIncomingUnreadScope();
    await shared.markSeen();
    await tester.pumpAndSettle();
    expect(visible(tester, _launcherDot), isFalse);
    Navigator.of(tester.element(find.text('Overthinking'))).pop();
    await tester.pumpAndSettle();
    expect(shared.isClosed, isFalse);
    repository.revision++;
    await shared.refresh();
    await tester.tap(find.text('Git'));
    await tester.pumpAndSettle();
    expect(visible(tester, _launcherDot), isTrue);
    expect(repository.acks, 1);
    await tester.tap(find.text('Overthinking'));
    await tester.pumpAndSettle();
    expect(routes, [AppRoutes.overthinkingFeed]);
    expect(repository.acks, 1);
    expect(shared.isClosed, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('retained listener entry clears on logout and reloads on login', (
    tester,
  ) async {
    await mount(tester);
    expect(visible(tester, _navigationDot), isTrue);
    sessions.replace(const AuthSession.guest());
    await tester.pumpAndSettle();
    expect(visible(tester, _navigationDot), isFalse);
    expect(repository.reads, 1);
    repository.seen = repository.revision;
    sessions.replace(audienceSession(user: 'next'));
    await tester.pumpAndSettle();
    expect(visible(tester, _navigationDot), isFalse);
    expect(repository.reads, 2);
    expect(repository.acks, 0);
    expect(tester.takeException(), isNull);
  });
}

class _DmBadge extends Cubit<DmBadgeState> implements DmBadgeCubit {
  _DmBadge() : super(const DmBadgeState.initial());
  @override
  Future<void> ensureStarted() async {}
  @override
  Future<void> stop() async {}
}

class _Inbox extends Fake implements OverthinkingRepository {
  int revision = 1;
  int seen = 0;
  int reads = 0;
  int acks = 0;

  Result<OverthinkingIncomingUnreadStatus> get status => Result.success(
    OverthinkingIncomingUnreadStatus(
      hasUnread: revision > seen,
      revision: revision,
    ),
  );

  @override
  Future<Result<OverthinkingIncomingUnreadStatus>>
  getIncomingUnreadStatus() async {
    reads++;
    return status;
  }

  @override
  Future<Result<OverthinkingIncomingUnreadStatus>> markIncomingRequestsSeen({
    required int revision,
  }) async {
    acks++;
    seen = revision;
    return status;
  }
}

Future<void> _loadFonts(WidgetTester tester) async {
  await tester.runAsync(() async {
    final fonts =
        '${File(Platform.resolvedExecutable).parent.parent.parent.path}/material_fonts';
    for (final family in ['Roboto', 'Ahem']) {
      await (FontLoader(family)..addFont(
            File(
              '$fonts/roboto-regular.ttf',
            ).readAsBytes().then(ByteData.sublistView),
          ))
          .load();
    }
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
}

Future<void> _capture(WidgetTester tester, String name) async {
  if (!_preview) return;
  final context = tester.element(find.byKey(_previewKey));
  final assets = tester
      .widgetList<Image>(find.byType(Image))
      .map((image) => image.image)
      .whereType<AssetImage>()
      .toSet();
  await tester.runAsync(
    () => Future.wait([
      for (final asset in assets) precacheImage(asset, context),
    ]),
  );
  await tester.pumpAndSettle();
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(_previewKey),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final output = File('test/goldens/overthinking/$name.png');
      await output.parent.create(recursive: true);
      await output.writeAsBytes(bytes!.buffer.asUint8List());
    } finally {
      image.dispose();
    }
  });
}
