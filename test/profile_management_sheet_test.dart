import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session_manager.dart';
import 'package:soundconnect_23_12_25codx/core/di/service_locator.dart';
import 'package:soundconnect_23_12_25codx/core/error/result.dart';
import 'package:soundconnect_23_12_25codx/modules/artist_venue/domain/artist_venue_connection_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/artist_venue/domain/artist_venue_application_page.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/band_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/band_management_panel_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/musician_profile_screen.dart';
import 'package:soundconnect_23_12_25codx/shared/theme/app_theme.dart';
import 'package:soundconnect_23_12_25codx/shared/widgets/profile_management_sheet.dart';
import 'package:soundconnect_23_12_25codx/shared/widgets/gradient_outline_button.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/venue_connection_management_hub.dart';

import 'support/event_invitation_navigation_fakes.dart';

void main() {
  setUp(() async {
    await serviceLocator.reset();
    serviceLocator.registerSingleton<BandRepository>(InvitationBands());
    serviceLocator.registerSingleton<AuthSessionManager>(_Sessions());
  });
  tearDown(() => serviceLocator.reset());

  testWidgets(
    'musician create connection selection invokes its existing callback once',
    (tester) async {
      var creations = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.navy,
          home: MusicianManagementPanelScreen(
            musicianProfile: invitationProfile,
            onCreateVenueConnection: () => creations++,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Mekan Bağlantıları'));
      await tester.tap(find.text('Mekan Bağlantıları'));
      await tester.pumpAndSettle();
      final select = tester
          .widget<GradientOutlineButton>(
            find.byKey(const Key('venue-connection-management-create')),
          )
          .onPressed!;
      select();
      select();
      await tester.pumpAndSettle();
      expect(creations, 1);
      expect(find.byType(BottomSheet), findsNothing);
      expect(find.byType(MusicianManagementPanelScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final band in [false, true]) {
    for (final direction in ['connections', 'incoming', 'outgoing']) {
      testWidgets(
        '${band ? 'band' : 'musician'} $direction connection selection opens its existing scoped application list',
        (tester) async {
          final applications = _Applications();
          serviceLocator.registerSingleton<ArtistVenueConnectionRepository>(
            applications,
          );
          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.navy,
              home: band
                  ? BandManagementPanelScreen(profile: invitationBand())
                  : const MusicianManagementPanelScreen(
                      musicianProfile: invitationProfile,
                    ),
            ),
          );
          await tester.pumpAndSettle();
          await tester.ensureVisible(find.text('Mekan Bağlantıları'));
          await tester.tap(find.text('Mekan Bağlantıları'));
          await tester.pumpAndSettle();
          expect(applications.scopes, isEmpty);
          await tester.tap(
            find.byKey(Key('venue-connection-management-$direction')),
          );
          await tester.pumpAndSettle();
          expect(applications.scopes, [
            band ? 'band:band-1' : 'musician:musician-1',
          ]);
          expect(applications.connectionFilters, [direction == 'connections']);
          expect(
            find.byWidgetPredicate(
              (widget) => widget is ProfileManagementSheet,
            ),
            findsNothing,
          );
          expect(
            find.text(
              direction == 'connections'
                  ? 'Bağlantılarım'
                  : direction == 'incoming'
                  ? 'Gelen İstekler'
                  : 'Gönderdiğim İstekler',
            ),
            findsOneWidget,
          );
          expect(find.byType(BottomSheet), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  for (final band in [false, true]) {
    testWidgets(
      'navy ${band ? 'band' : 'musician'} venue and event hubs share the compact management design',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.navy,
            home: band
                ? BandManagementPanelScreen(profile: invitationBand())
                : const MusicianManagementPanelScreen(
                    musicianProfile: invitationProfile,
                  ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.ensureVisible(find.text('Mekan Bağlantıları'));
        await tester.tap(find.text('Mekan Bağlantıları'));
        await tester.pumpAndSettle();
        final venueStyle = _sheetStyle(tester, const [
          'Bağlantılarım',
          'Gelen İstekler',
          'Gönderdiğim İstekler',
        ], hasCreate: true);
        Navigator.of(tester.element(find.byType(BottomSheet))).pop();
        await tester.pumpAndSettle();

        await tester.ensureVisible(find.text('Etkinlik Yönetimi'));
        await tester.tap(find.text('Etkinlik Yönetimi'));
        await tester.pumpAndSettle();
        final eventStyle = _sheetStyle(tester, const [
          'Etkinlik Davetleri',
          'Etkinliklerim',
          'Reddedilen Etkinlikler',
        ]);
        expect(eventStyle.$1, venueStyle.$1);
        expect(eventStyle.$2, venueStyle.$2);
        expect(eventStyle.$3, venueStyle.$3);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('generic sheet returns the selected typed option exactly once', (
    tester,
  ) async {
    final harness = await _mount(tester);
    harness.open();
    await tester.pumpAndSettle();
    expect(find.byType(ProfileManagementSheet<String>), findsOneWidget);
    final select = tester
        .widget<InkWell>(find.byKey(const Key('option-two')))
        .onTap!;
    select();
    select();
    await tester.pumpAndSettle();
    expect(harness.results, ['two']);
    expect(find.byType(BottomSheet), findsNothing);
    select();
    await tester.pumpAndSettle();
    expect(harness.results, ['two']);
    expect(find.text('Yönetimi aç'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'concurrent open requests never stack sheets and the guard releases after cancel',
    (tester) async {
      final harness = await _mount(tester);
      harness.open();
      harness.open();
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(harness.results, [null]);
      Navigator.of(tester.element(find.byType(BottomSheet))).pop();
      await tester.pumpAndSettle();
      expect(harness.results, [null, null]);
      harness.open();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('option-one')));
      await tester.pumpAndSettle();
      expect(harness.results, [null, null, 'one']);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('dismissal returns null without invoking an option', (
    tester,
  ) async {
    final harness = await _mount(tester);
    harness.open();
    await tester.pumpAndSettle();
    Navigator.of(tester.element(find.byType(BottomSheet))).pop();
    await tester.pumpAndSettle();
    expect(harness.results, [null]);
    expect(find.text('Yönetimi aç'), findsOneWidget);
  });

  testWidgets(
    'saved selection cannot dismiss a newer route covering the sheet',
    (tester) async {
      final harness = await _mount(tester);
      harness.open();
      await tester.pumpAndSettle();
      final select = tester
          .widget<InkWell>(find.byKey(const Key('option-one')))
          .onTap!;
      final navigator = Navigator.of(tester.element(find.byType(BottomSheet)));
      unawaited(
        navigator.push<void>(
          MaterialPageRoute(
            builder: (_) => const Scaffold(body: Text('Başka sayfa')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      select();
      await tester.pumpAndSettle();
      expect(find.text('Başka sayfa'), findsOneWidget);
      expect(harness.results, isEmpty);
      navigator.pop();
      await tester.pumpAndSettle();
      select();
      await tester.pumpAndSettle();
      expect(harness.results, ['one']);
      expect(find.text('Yönetimi aç'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('an unmounted source cannot open another sheet', (tester) async {
    final harness = await _mount(tester);
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: Text('Yeni ekran'))),
    );
    await tester.pumpAndSettle();
    harness.open();
    await tester.pumpAndSettle();
    expect(harness.results, [null]);
    expect(find.byType(BottomSheet), findsNothing);
    expect(find.text('Yeni ekran'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'options are snapshotted so later input list edits cannot retarget a tap',
    (tester) async {
      final options = [..._options];
      final harness = await _mount(tester, options: options);
      harness.open();
      await tester.pumpAndSettle();
      options.clear();
      await tester.pump();
      expect(find.byKey(const Key('option-three')), findsOneWidget);
      await tester.tap(find.byKey(const Key('option-three')));
      await tester.pumpAndSettle();
      expect(harness.results, ['three']);
      expect(tester.takeException(), isNull);
    },
  );

  for (final viewport in [const Size(320, 800), const Size(740, 320)]) {
    for (final artistConnections in [false, true]) {
      testWidgets(
        'connection hub primary action remains accessible at $viewport, venue=$artistConnections',
        (tester) async {
          tester.view.physicalSize = viewport;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          VenueConnectionManagementDestination? result;
          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.navy,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: const TextScaler.linear(2)),
                child: child!,
              ),
              home: Scaffold(
                body: Builder(
                  builder: (context) => TextButton(
                    onPressed: () async {
                      result = await showVenueConnectionManagementHub(
                        context,
                        artistConnections: artistConnections,
                      );
                    },
                    child: const Text('Open'),
                  ),
                ),
              ),
            ),
          );
          await tester.tap(find.text('Open'));
          await tester.pumpAndSettle();
          final create = find.byKey(
            const Key('venue-connection-management-create'),
          );
          await tester.ensureVisible(create);
          await tester.pumpAndSettle();
          expect(create.hitTestable(), findsOneWidget);
          expect(
            find.text(artistConnections ? 'Sanatçı ekle' : 'Mekan ekle'),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
          await tester.tap(create);
          await tester.pumpAndSettle();
          expect(result, VenueConnectionManagementDestination.create);
        },
      );
    }
    testWidgets(
      'shared sheet keeps all compact rows accessible at $viewport and 200 percent text',
      (tester) async {
        tester.view.physicalSize = viewport;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final harness = await _mount(tester, scale: 2);
        harness.open();
        await tester.pumpAndSettle();
        final last = find.byKey(const Key('option-three'));
        await tester.ensureVisible(last);
        await tester.pumpAndSettle();
        expect(last.hitTestable(), findsOneWidget);
        expect(tester.getSize(last).height, greaterThanOrEqualTo(52));
        expect(tester.takeException(), isNull);
        await tester.tap(last);
        await tester.pumpAndSettle();
        expect(harness.results, ['three']);
        expect(tester.takeException(), isNull);
      },
    );
  }
}

(Color?, ShapeBorder?, List<TextStyle?>) _sheetStyle(
  WidgetTester tester,
  List<String> labels, {
  bool hasCreate = false,
}) {
  final sheetFinder = find.byType(BottomSheet);
  expect(sheetFinder, findsOneWidget);
  expect(
    find.byWidgetPredicate((widget) => widget is ProfileManagementSheet),
    findsOneWidget,
  );
  final sheet = tester.widget<BottomSheet>(sheetFinder);
  final scheme = Theme.of(tester.element(sheetFinder)).colorScheme;
  expect(sheet.backgroundColor, scheme.surface);
  expect(
    sheet.shape,
    const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
  );
  expect(
    find.descendant(of: sheetFinder, matching: find.byType(Text)),
    findsNWidgets(hasCreate ? 5 : 4),
  );
  expect(
    find.descendant(
      of: sheetFinder,
      matching: find.byType(SingleChildScrollView),
    ),
    findsOneWidget,
  );
  final styles = <TextStyle?>[];
  for (final label in labels) {
    final title = find.descendant(of: sheetFinder, matching: find.text(label));
    expect(title, findsOneWidget);
    final widget = tester.widget<Text>(title);
    expect(widget.style?.fontSize, 15);
    expect(widget.style?.fontWeight, FontWeight.w800);
    styles.add(widget.style);
  }
  final leadingIcons = tester
      .widgetList<Icon>(
        find.descendant(of: sheetFinder, matching: find.byType(Icon)),
      )
      .where((icon) => icon.size == 24)
      .toList();
  expect(leadingIcons, hasLength(3));
  expect(leadingIcons.every((icon) => icon.color == scheme.onSurface), isTrue);
  return (sheet.backgroundColor, sheet.shape, styles);
}

const _options = <ProfileManagementSheetOption<String>>[
  ProfileManagementSheetOption(
    key: Key('option-one'),
    value: 'one',
    icon: Icons.add_business_outlined,
    label: 'Bağlantılarım',
  ),
  ProfileManagementSheetOption(
    key: Key('option-two'),
    value: 'two',
    icon: Icons.inbox_outlined,
    label: 'Gelen İstekler',
  ),
  ProfileManagementSheetOption(
    key: Key('option-three'),
    value: 'three',
    icon: Icons.send_outlined,
    label: 'Gönderdiğim İstekler',
  ),
];

class _Harness {
  final results = <String?>[];
  late VoidCallback open;
}

class _Applications extends Fake implements ArtistVenueConnectionRepository {
  final scopes = <String>[];
  final connectionFilters = <bool>[];
  @override
  Future<Result<ArtistVenueApplicationPage>> listApplicationPage({
    required ArtistVenueApplicationTarget target,
    required String targetId,
    required bool incoming,
    bool connectionsOnly = false,
    int page = 0,
    int size = 20,
    String? expectedSessionKey,
  }) async {
    scopes.add('${target.name}:$targetId');
    connectionFilters.add(connectionsOnly);
    return Result.success(
      ArtistVenueApplicationPage(
        items: const [],
        page: page,
        size: size,
        totalElements: 0,
        totalPages: 0,
        last: true,
      ),
    );
  }
}

class _Sessions extends ChangeNotifier implements AuthSessionManager {
  @override
  final AuthSession session = AuthSession.authenticated(
    token: 'token',
    userId: 'owner-1',
    username: 'musician',
    accountStatus: 'ACTIVE',
    roles: const ['ROLE_MUSICIAN'],
    permissions: const [],
    expiresAt: DateTime(2100),
    isAdmin: false,
  );
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<_Harness> _mount(
  WidgetTester tester, {
  List<ProfileManagementSheetOption<String>> options = _options,
  double scale = 1,
}) async {
  final harness = _Harness();
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.navy,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: Builder(
        builder: (context) {
          harness.open = () => unawaited(
            showProfileManagementSheet<String>(
              context,
              title: 'Mekan Bağlantıları',
              options: options,
            ).then(harness.results.add),
          );
          return Scaffold(
            body: TextButton(
              onPressed: harness.open,
              child: const Text('Yönetimi aç'),
            ),
          );
        },
      ),
    ),
  );
  await tester.pumpAndSettle();
  return harness;
}
