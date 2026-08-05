import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/modules/engagement/domain/engagement_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/engagement/presentation/cubit/interaction_stats_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/profile_audio_tab_shared.dart';
import 'package:soundconnect_23_12_25codx/modules/spotify/domain/entities/spotify_track_preview.dart';

void main() {
  testWidgets('owner can persist Spotify catalog order by dragging', (
    tester,
  ) async {
    List<SpotifyTrackPreview>? savedTracks;
    await tester.pumpWidget(
      BlocProvider(
        create: (_) => InteractionStatsCubit(_EngagementRepositoryFake()),
        child: MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: ProfileAudioTab(
              items: const [],
              profileId: 'studio-1',
              spotifyTracks: const [_firstTrack, _secondTrack],
              spotifyLoading: false,
              ownerMode: true,
              audioHandler: _AudioHandlerFake(),
              uploadOwnerType: 'STUDIO_PROFILE',
              uploadProfileType: 'STUDIO',
              showSpotifyCatalogButtonWhenOwnerAndEmpty: true,
              emptyUploadPrompt: 'Kayıt ekle',
              uploadActionLabel: 'Kayıt ekle',
              onSpotifyTracksChanged: (tracks) async {
                savedTracks = List<SpotifyTrackPreview>.from(tracks);
                return true;
              },
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Spotify Kataloğu'));
    await tester.pumpAndSettle();
    expect(find.byType(ReorderableListView), findsOneWidget);

    final handle = find.byKey(const ValueKey('spotify-reorder-handle-track-1'));
    final gesture = await tester.startGesture(tester.getCenter(handle));
    await tester.pump(const Duration(milliseconds: 100));
    await gesture.moveBy(const Offset(0, 220));
    await tester.pump(const Duration(milliseconds: 300));
    await gesture.up();
    await tester.pumpAndSettle();

    expect(savedTracks?.map((track) => track.id), ['track-2', 'track-1']);
    expect(find.text('Spotify sıralaması kaydedildi.'), findsOneWidget);
  });
}

class _AudioHandlerFake extends BaseAudioHandler {}

class _EngagementRepositoryFake implements EngagementRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _firstTrack = SpotifyTrackPreview(
  id: 'track-1',
  name: 'Birinci',
  previewUrl: null,
  durationSeconds: 120,
  spotifyUrl: null,
  albumImageUrl: null,
  artistNames: ['Sanatçı'],
);

const _secondTrack = SpotifyTrackPreview(
  id: 'track-2',
  name: 'İkinci',
  previewUrl: null,
  durationSeconds: 180,
  spotifyUrl: null,
  albumImageUrl: null,
  artistNames: ['Sanatçı'],
);
