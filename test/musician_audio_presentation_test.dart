import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/musician_profile_visual_theme.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/musician_audio_presentation.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/profile_audio_transport.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/profile_common_widgets.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/profile_track_delete_menu.dart';
import 'package:soundconnect_23_12_25codx/shared/theme/app_theme.dart';
import 'package:soundconnect_23_12_25codx/shared/theme/backstage_palette.dart';
import 'package:soundconnect_23_12_25codx/shared/widgets/waveform_stub.dart';

const _longTitle =
    'Gece yarısından sonra İstanbul sahnesinden akustik bir prova kaydı';
const _cardKey = ValueKey('musician-audio-card');
const _waveformKey = ValueKey('musician-waveform');

Widget _host(Widget child, {double width = 320, double textScale = 1}) =>
    MaterialApp(
      theme: AppTheme.navy,
      home: MusicianProfileThemeScope(
        child: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
          child: Scaffold(
            body: SingleChildScrollView(
              child: Center(
                child: SizedBox(width: width, child: child),
              ),
            ),
          ),
        ),
      ),
    );

Widget _audioCard({
  String title = _longTitle,
  VoidCallback? onTap,
  VoidCallback? onDoubleTap,
  VoidCallback? onPlay,
  VoidCallback? onBack,
  VoidCallback? onForward,
  ValueChanged<double>? onSeek,
  Widget? trailing,
  bool playing = false,
}) => ProfileAudioPreviewCard(
  key: _cardKey,
  title: title,
  backstageStyle: true,
  onTap: onTap,
  onDoubleTap: onDoubleTap,
  trailing: trailing,
  timeLabel: musicianAudioTimeLabel(const Duration(seconds: 47), 225),
  waveform: WaveformStub(
    key: _waveformKey,
    progress: .21,
    onSeek: onSeek,
    showLeading: false,
    framed: false,
    height: 72,
    waveformHeight: 44,
  ),
  bottomControls: ProfileAudioTransportRow(
    backstageStyle: true,
    isPlaying: playing,
    iconColor: BackstagePalette.textPrimary,
    onPlayPause: onPlay,
    onBack10: onBack,
    onForward10: onForward,
  ),
);

Widget _ownerMenu() => ProfileTrackDeleteMenu(
  ownerType: 'MUSICIAN_PROFILE',
  ownerId: 'owner',
  trackId: 'track',
  onDeleted: () async {},
);

void main() {
  for (final width in [280.0, 320.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('owner card fits ${width}dp at ${scale}x text', (
        tester,
      ) async {
        await tester.pumpWidget(
          _host(
            _audioCard(trailing: _ownerMenu()),
            width: width,
            textScale: scale,
          ),
        );
        await tester.pumpAndSettle();

        final card = tester.getRect(find.byKey(_cardKey));
        final title = tester.getRect(find.text(_longTitle));
        final menu = tester.getRect(find.byType(ProfileTrackDeleteMenu));
        final waveform = tester.getRect(find.byKey(_waveformKey));
        final time = tester.getRect(find.text('0:47 / 3:45'));
        final play = tester.getRect(find.byTooltip('Oynat'));
        expect(card.width, width);
        expect(title.right, lessThanOrEqualTo(menu.left));
        expect(title.bottom, lessThanOrEqualTo(waveform.top));
        expect(menu.size, const Size(48, 48));
        expect(menu.right, lessThanOrEqualTo(card.right));
        expect(menu.bottom, lessThanOrEqualTo(waveform.top));
        expect(time.bottom, lessThanOrEqualTo(play.top));
        expect(tester.widget<Text>(find.text(_longTitle)).maxLines, 3);
        expect(tester.takeException(), isNull);
      });

      testWidgets('upload card fits ${width}dp at ${scale}x text', (
        tester,
      ) async {
        var uploads = 0;
        await tester.pumpWidget(
          _host(
            MusicianAudioUploadCard(
              title: 'Ses ekle',
              description:
                  'Demolarını, provalarını ve sahne kayıtlarını paylaş.',
              onTap: () => uploads++,
            ),
            width: width,
            textScale: scale,
          ),
        );
        await tester.tap(find.text('Ses ekle'));
        await tester.pumpAndSettle();
        expect(uploads, 1);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('single tap opens detail and double tap only likes', (
    tester,
  ) async {
    var details = 0;
    var likes = 0;
    await tester.pumpWidget(
      _host(_audioCard(onTap: () => details++, onDoubleTap: () => likes++)),
    );
    await tester.tap(find.text(_longTitle));
    await tester.pump(const Duration(milliseconds: 350));
    expect(details, 1);
    expect(likes, 0);

    await tester.tap(find.text(_longTitle));
    await tester.pump(const Duration(milliseconds: 60));
    await tester.tap(find.text(_longTitle));
    await tester.pumpAndSettle();
    expect(details, 1);
    expect(likes, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'transport controls keep their callbacks without opening detail',
    (tester) async {
      var details = 0;
      var likes = 0;
      var plays = 0;
      var backwards = 0;
      var forwards = 0;
      await tester.pumpWidget(
        _host(
          _audioCard(
            onTap: () => details++,
            onDoubleTap: () => likes++,
            onPlay: () => plays++,
            onBack: () => backwards++,
            onForward: () => forwards++,
          ),
        ),
      );
      for (final label in ['Oynat', '10 saniye geri', '10 saniye ileri']) {
        final control = find.byTooltip(label);
        final size = tester.getSize(control);
        expect(size.width, greaterThanOrEqualTo(48));
        expect(size.height, greaterThanOrEqualTo(48));
        await tester.tap(control);
        await tester.pump(const Duration(milliseconds: 350));
      }
      expect([plays, backwards, forwards], [1, 1, 1]);
      expect(details, 0);
      expect(likes, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('waveform seek does not also open detail or like the card', (
    tester,
  ) async {
    var details = 0;
    var likes = 0;
    final seeks = <double>[];
    await tester.pumpWidget(
      _host(
        _audioCard(
          onTap: () => details++,
          onDoubleTap: () => likes++,
          onSeek: seeks.add,
        ),
      ),
    );
    await tester.tap(find.bySemanticsLabel('Oynatma konumu'));
    await tester.pump(const Duration(milliseconds: 350));
    expect(seeks, isNotEmpty);
    expect(seeks.single, closeTo(.5, .03));
    expect(details, 0);
    expect(likes, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('owner menu opens independently of the card gesture', (
    tester,
  ) async {
    var details = 0;
    var likes = 0;
    await tester.pumpWidget(
      _host(
        _audioCard(
          trailing: _ownerMenu(),
          onTap: () => details++,
          onDoubleTap: () => likes++,
        ),
      ),
    );
    await tester.tap(find.byTooltip('Ses seçenekleri'));
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    expect(find.text('Sil'), findsOneWidget);
    expect(details, 0);
    expect(likes, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('disabled transport exposes no enabled actions', (tester) async {
    await tester.pumpWidget(_host(_audioCard()));
    final buttons = tester.widgetList<IconButton>(
      find.descendant(
        of: find.byType(MusicianAudioTransport),
        matching: find.byType(IconButton),
      ),
    );
    expect(buttons.length, 3);
    expect(buttons.every((button) => button.onPressed == null), isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('playing transport exposes a pause action', (tester) async {
    var pauses = 0;
    await tester.pumpWidget(
      _host(_audioCard(playing: true, onPlay: () => pauses++)),
    );
    expect(find.byTooltip('Oynat'), findsNothing);
    await tester.tap(find.byTooltip('Duraklat'));
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    expect(pauses, 1);
    expect(tester.takeException(), isNull);
  });

  test(
    'duration label handles unknown, negative and end-of-track positions',
    () {
      expect(musicianAudioTimeLabel(Duration.zero, null), '0:00 / —:—');
      expect(
        musicianAudioTimeLabel(const Duration(seconds: 5), 0),
        '0:05 / —:—',
      );
      expect(
        musicianAudioTimeLabel(const Duration(seconds: 5), -3),
        '0:05 / —:—',
      );
      expect(
        musicianAudioTimeLabel(const Duration(seconds: -8), 125),
        '0:00 / 2:05',
      );
      expect(
        musicianAudioTimeLabel(const Duration(seconds: 999), 125),
        '2:05 / 2:05',
      );
      expect(
        musicianAudioTimeLabel(const Duration(seconds: 62), 125),
        '1:02 / 2:05',
      );
      expect(
        musicianAudioTimeLabel(const Duration(seconds: 3601), 7200),
        '60:01 / 120:00',
      );
    },
  );

  if (Platform.environment['SC_WRITE_DESIGN_PREVIEW'] == '1') {
    testWidgets('render musician audio design preview', (tester) async {
      final fontFile = File(r'C:\Windows\Fonts\segoeui.ttf');
      expect(fontFile.existsSync(), isTrue);
      final font = FontLoader('DesignPreview')
        ..addFont(
          Future.value(ByteData.sublistView(fontFile.readAsBytesSync())),
        );
      await font.load();
      final icons = FontLoader('MaterialIcons')
        ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
      await icons.load();
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final boundaryKey = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.navy.copyWith(
            textTheme: AppTheme.navy.textTheme.apply(
              fontFamily: 'DesignPreview',
            ),
          ),
          home: RepaintBoundary(
            key: boundaryKey,
            child: MusicianProfileThemeScope(
              child: Scaffold(
                body: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(18, 24, 18, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Sesler',
                        style: TextStyle(
                          fontSize: 25,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Müzisyen profili · ses alanı',
                        style: TextStyle(
                          color: BackstagePalette.textMuted,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 22),
                      MusicianAudioUploadCard(
                        title: 'Ses ekle',
                        description:
                            'Demolarını, provalarını ve sahne kayıtlarını paylaş.',
                        onTap: () {},
                      ),
                      const SizedBox(height: 18),
                      _audioCard(
                        title: 'Geceye Kalan · Akustik Prova',
                        onTap: () {},
                        onPlay: () {},
                        onBack: () {},
                        onForward: () {},
                        onSeek: (_) {},
                        trailing: _ownerMenu(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final boundary =
          boundaryKey.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 2);
        try {
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final output = File('build/design_previews/musician-audio.png');
          await output.parent.create(recursive: true);
          await output.writeAsBytes(bytes!.buffer.asUint8List());
        } finally {
          image.dispose();
        }
      });
    });
  }
}
