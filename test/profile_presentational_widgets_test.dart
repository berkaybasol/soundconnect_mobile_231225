import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/media_asset.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/profile_audio_transport.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/profile_photo_gallery_tab.dart';
import 'package:soundconnect_23_12_25codx/shared/images/app_cached_network_image.dart';

void main() {
  Widget host(Widget child) => MaterialApp(home: Scaffold(body: child));

  group('ProfileAudioTransportRow', () {
    testWidgets('shows play mode and invokes all transport callbacks', (
      tester,
    ) async {
      var backCalls = 0;
      var playCalls = 0;
      var forwardCalls = 0;
      await tester.pumpWidget(
        host(
          ProfileAudioTransportRow(
            isPlaying: false,
            iconColor: Colors.orange,
            onBack10: () => backCalls++,
            onPlayPause: () => playCalls++,
            onForward10: () => forwardCalls++,
          ),
        ),
      );

      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
      expect(find.byIcon(Icons.pause_rounded), findsNothing);
      await tester.tap(find.byIcon(Icons.replay_10_rounded));
      await tester.tap(find.byIcon(Icons.play_arrow_rounded));
      await tester.tap(find.byIcon(Icons.forward_10_rounded));
      expect((backCalls, playCalls, forwardCalls), (1, 1, 1));
    });

    testWidgets('shows pause mode and tolerates disabled callbacks', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          ProfileAudioTransportRow(isPlaying: true, iconColor: Colors.purple),
        ),
      );

      expect(find.byIcon(Icons.pause_rounded), findsOneWidget);
      await tester.tap(find.byIcon(Icons.pause_rounded));
      expect(tester.takeException(), isNull);
    });
  });

  group('ProfilePhotoGalleryTab', () {
    testWidgets('owner empty state offers upload and invokes it', (
      tester,
    ) async {
      var uploadCalls = 0;
      await tester.pumpWidget(
        host(
          ProfilePhotoGalleryTab(
            items: const <MediaAsset>[],
            ownerMode: true,
            onAddPhoto: () async => uploadCalls++,
          ),
        ),
      );

      expect(find.text('Henuz fotograf eklemediniz'), findsOneWidget);
      expect(find.text('Henuz fotograf eklenmedi.'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.add_photo_alternate_outlined));
      await tester.pump();
      expect(uploadCalls, 1);
    });

    testWidgets('public empty state hides owner upload card', (tester) async {
      await tester.pumpWidget(
        host(
          ProfilePhotoGalleryTab(items: const <MediaAsset>[], ownerMode: false),
        ),
      );

      expect(find.text('Henuz fotograf eklenmedi.'), findsOneWidget);
      expect(find.byIcon(Icons.add_photo_alternate_outlined), findsNothing);
    });

    testWidgets('shows upload progress and disables another upload', (
      tester,
    ) async {
      var uploadCalls = 0;
      await tester.pumpWidget(
        host(
          ProfilePhotoGalleryTab(
            items: const <MediaAsset>[],
            ownerMode: true,
            uploading: true,
            uploadProgress: 0.42,
            onAddPhoto: () async => uploadCalls++,
          ),
        ),
      );

      expect(find.text('Fotograf yukleniyor %42'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      await tester.tap(find.text('Fotograf yukleniyor %42'));
      await tester.pump();
      expect(uploadCalls, 0);
    });

    testWidgets('filters blank URLs and uses the first available image URL', (
      tester,
    ) async {
      const items = <MediaAsset>[
        MediaAsset(
          id: 'blank',
          kind: 'IMAGE',
          sourceUrl: ' ',
          playbackUrl: null,
          thumbnailUrl: '',
          title: null,
          durationSeconds: null,
        ),
        MediaAsset(
          id: 'source',
          kind: 'IMAGE',
          sourceUrl: 'https://example.test/source.jpg',
          playbackUrl: 'https://example.test/playback.jpg',
          thumbnailUrl: 'https://example.test/thumb.jpg',
          title: 'Source image',
          durationSeconds: null,
        ),
        MediaAsset(
          id: 'fallback',
          kind: 'IMAGE',
          sourceUrl: null,
          playbackUrl: null,
          thumbnailUrl: 'https://example.test/fallback.jpg',
          title: 'Fallback image',
          durationSeconds: null,
        ),
      ];
      await tester.pumpWidget(
        host(ProfilePhotoGalleryTab(items: items, ownerMode: false)),
      );

      expect(find.byType(AppCachedNetworkImage), findsNWidgets(2));
      final urls = tester
          .widgetList<AppCachedNetworkImage>(find.byType(AppCachedNetworkImage))
          .map((image) => image.imageUrl)
          .toList();
      expect(urls, <String>[
        'https://example.test/thumb.jpg',
        'https://example.test/fallback.jpg',
      ]);
      expect(find.text('Henuz fotograf eklenmedi.'), findsNothing);
    });
  });
}
