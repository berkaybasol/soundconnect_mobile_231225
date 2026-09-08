import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/app/router/app_routes.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/profile_venue_models.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/venue_active_musician.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/profile_carousels.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/profile_mini_card.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/profile_route_args.dart';
import 'package:soundconnect_23_12_25codx/shared/theme/app_theme.dart';

void main() {
  const venue = VenueConnection(
    requestId: 'request',
    venueId: 'venue',
    venueName: 'soundconnectankara',
  );
  const band = VenueActiveMusician(
    musicianProfileId: '',
    bandId: 'band',
    displayName: 'Dolu Kadehi Ters Tut',
    profileImageUrl: null,
  );
  const musician = VenueActiveMusician(
    musicianProfileId: 'musician',
    displayName: 'aedrum',
    profileImageUrl: null,
  );

  Future<void> open(
    WidgetTester tester,
    Widget child, {
    double scale = 1,
    Brightness brightness = Brightness.dark,
    ValueChanged<RouteSettings>? onRoute,
  }) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: brightness == Brightness.dark ? AppTheme.navy : AppTheme.light,
        builder: (context, widget) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: widget!,
        ),
        onGenerateRoute: (settings) {
          onRoute?.call(settings);
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => const Scaffold(body: Text('profile destination')),
          );
        },
        home: Scaffold(
          body: Align(alignment: Alignment.topLeft, child: child),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final brightness in Brightness.values) {
    for (final scale in [1.0, 2.0, 3.0]) {
      testWidgets('identity rows fit at $scale in $brightness', (tester) async {
        await open(
          tester,
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const VenueNameCarousel(items: [venue]),
              const ActiveMusicianCarousel(items: [band, musician]),
            ],
          ),
          scale: scale,
          brightness: brightness,
        );
        final cards = find.byType(ProfileMiniCard);
        expect(cards, findsNWidgets(3));
        for (final element in cards.evaluate()) {
          final size = tester.getSize(find.byWidget(element.widget));
          expect(size.width, 168);
          if (scale == 1) expect(size.height, 52);
        }
        expect(find.text('Kurucu'), findsNothing);
        expect(find.byIcon(Icons.chevron_right), findsNothing);
        expect(find.byTooltip('Dolu Kadehi Ters Tut'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('venue mini card preserves venue route arguments', (
    tester,
  ) async {
    RouteSettings? route;
    await open(
      tester,
      const VenueNameCarousel(items: [venue]),
      onRoute: (value) => route = value,
    );
    await tester.tap(find.text(venue.venueName));
    await tester.pumpAndSettle();
    expect(route?.name, AppRoutes.venuePublicProfile);
    expect((route?.arguments as VenuePublicProfileArgs).venueId, venue.venueId);
  });

  for (final artist in [band, musician]) {
    testWidgets('artist mini card preserves target ${artist.displayName}', (
      tester,
    ) async {
      RouteSettings? route;
      await open(
        tester,
        ActiveMusicianCarousel(items: [artist]),
        onRoute: (value) => route = value,
      );
      await tester.tap(find.text(artist.displayName));
      await tester.pumpAndSettle();
      final isBand = artist.bandId.isNotEmpty;
      expect(
        route?.name,
        isBand ? AppRoutes.bandPublicProfile : AppRoutes.musicianPublicProfile,
      );
      expect(route?.arguments, isBand ? 'band' : {'profileId': 'musician'});
    });
  }

  testWidgets('empty target is inert and no fabricated title appears', (
    tester,
  ) async {
    RouteSettings? route;
    await open(
      tester,
      const ActiveMusicianCarousel(
        items: [
          VenueActiveMusician(
            musicianProfileId: '',
            displayName: 'İsimsiz değil',
            profileImageUrl: null,
          ),
        ],
      ),
      onRoute: (value) => route = value,
    );
    await tester.tap(find.text('İsimsiz değil'));
    expect(route, isNull);
    expect(find.text('Üye'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty editable row keeps add action', (tester) async {
    var added = false;
    await open(
      tester,
      VenueNameCarousel(
        items: const [],
        editable: true,
        onAddTap: () => added = true,
      ),
    );
    await tester.tap(find.text('Mekan ekle'));
    expect(added, isTrue);
  });

  testWidgets('empty read-only row has no add permission', (tester) async {
    await open(tester, VenueNameCarousel(items: const [], onAddTap: () {}));
    expect(find.text('Mekan ekle'), findsNothing);
    expect(find.text('Mekan bilgisi yok.'), findsOneWidget);
  });

  if (const bool.fromEnvironment('PROFILE_MINI_PREVIEW')) {
    testWidgets('shared profile mini cards visual preview', (tester) async {
      await tester.runAsync(() async {
        const root = String.fromEnvironment('PROFILE_MINI_FLUTTER_ROOT');
        for (final font in {
          'Roboto':
              '$root/engine/src/flutter/txt/third_party/fonts/Roboto-Regular.ttf',
          'MaterialIcons':
              '$root/bin/cache/dart-sdk/bin/resources/devtools/assets/fonts/MaterialIcons-Regular.otf',
        }.entries) {
          await (FontLoader(font.key)..addFont(
                File(font.value).readAsBytes().then(ByteData.sublistView),
              ))
              .load();
        }
      });
      final boundary = GlobalKey();
      await open(
        tester,
        RepaintBoundary(
          key: boundary,
          child: ColoredBox(
            color: AppTheme.navy.scaffoldBackgroundColor,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final heading in [
                  'Grup profili',
                  'Müzisyen profili',
                  'Mekan profili',
                ]) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 28, 20, 12),
                    child: Text(
                      heading,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                    child: Text(
                      heading == 'Mekan profili'
                          ? 'Aktif Sanatçılar'
                          : 'Çaldığı Mekanlar',
                    ),
                  ),
                  if (heading == 'Mekan profili')
                    const ActiveMusicianCarousel(items: [band, musician])
                  else
                    const VenueNameCarousel(
                      items: [
                        venue,
                        VenueConnection(
                          requestId: 'r2',
                          venueId: 'v2',
                          venueName: 'IF',
                        ),
                      ],
                    ),
                ],
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      );
      final render =
          boundary.currentContext!.findRenderObject() as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final image = await render.toImage(pixelRatio: 2);
        try {
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File(
            'build/profile-connection-mini-cards.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
        } finally {
          image.dispose();
        }
      });
      expect(tester.takeException(), isNull);
    });
  }

  test('connection thumbnail URLs reject unsupported schemes', () {
    for (final raw in [
      null,
      '',
      ' ',
      'file:///secret',
      'data:image/png;base64,abc',
      'javascript:alert(1)',
      'https://',
    ]) {
      expect(resolveProfileConnectionImageUrl(raw), isNull, reason: raw);
    }
    expect(
      resolveProfileConnectionImageUrl(' //cdn.example.com/avatar.jpg '),
      'https://cdn.example.com/avatar.jpg',
    );
    expect(
      resolveProfileConnectionImageUrl(' https://cdn.example.com/avatar.jpg '),
      'https://cdn.example.com/avatar.jpg',
    );
    expect(
      Uri.parse(resolveProfileConnectionImageUrl('/avatars/a.jpg')!).path,
      '/avatars/a.jpg',
    );
  });
}
