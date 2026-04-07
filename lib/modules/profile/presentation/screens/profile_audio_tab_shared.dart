import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/audio/audio_player_handler.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/widgets/waveform_stub.dart';
import '../../../engagement/presentation/cubit/comment_thread_cubit.dart';
import '../../../engagement/presentation/cubit/interaction_stats_cubit.dart';
import '../../../spotify/domain/entities/spotify_track_preview.dart';
import '../../../spotify/domain/spotify_repository.dart';
import '../../data/models/musician_profile_save_request.dart';
import '../../domain/entities/track.dart';
import '../cubit/musician_profile_cubit.dart';
import '../cubit/musician_profile_state.dart';
import 'media_detail_screen.dart';
import 'profile_audio_transport.dart';
import 'profile_common_widgets.dart';
import 'profile_count_row.dart';
import 'profile_screen_support.dart';
import 'profile_track_upload_support.dart';

part 'profile_audio_tab_shared_interaction_methods.dart';
part 'profile_audio_tab_shared_interaction_spotify_picker.dart';
part 'profile_audio_tab_shared_interaction_spotify_catalog.dart';
part 'profile_audio_tab_shared_catalog_methods.dart';
part 'profile_audio_tab_shared_catalog_sheet.dart';
part 'profile_audio_tab_shared_catalog_sheet_track_tile.dart';
part 'profile_audio_tab_shared_track_item.dart';

class ProfileAudioTab extends StatelessWidget {
  final List<Track> items;
  final String profileId;

  final List<SpotifyTrackPreview> spotifyTracks;
  final bool spotifyLoading;
  final bool ownerMode;
  final AudioHandler audioHandler;
  final String uploadOwnerType;
  final String uploadProfileType;
  final bool showSpotifyCatalogButtonWhenOwnerAndEmpty;
  final String emptyUploadPrompt;
  final String uploadActionLabel;

  const ProfileAudioTab({
    super.key,
    required this.items,
    required this.profileId,
    required this.spotifyTracks,
    required this.spotifyLoading,
    required this.ownerMode,
    required this.audioHandler,
    required this.uploadOwnerType,
    required this.uploadProfileType,
    required this.showSpotifyCatalogButtonWhenOwnerAndEmpty,
    required this.emptyUploadPrompt,
    required this.uploadActionLabel,
  });

  Map<String, dynamic> _trackToSaveJson(SpotifyTrackPreview track) {
    return {
      'spotifyTrackId': track.id,
      'name': track.name,
      'durationMs': track.durationSeconds != null
          ? track.durationSeconds! * 1000
          : null,
      'explicit': false,
      'previewUrl': track.previewUrl,
      'spotifyUrl': track.spotifyUrl,
      'albumName': null,
      'albumImageUrl': track.albumImageUrl,
      'artistNames': track.artistNames,
    };
  }

  @override
  Widget build(BuildContext context) {
    final positionStream = audioHandler is AudioPlayerHandler
        ? (audioHandler as AudioPlayerHandler).positionStream
        : const Stream<Duration>.empty();
    final spotifyPreviewItems = spotifyTracks;

    if (!ownerMode && items.isEmpty && spotifyPreviewItems.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Text(
          'Kullanici henuz ses eklemedi.',
          style: TextStyle(color: AppColors.textMuted),
        ),
      );
    }

    return StreamBuilder<Duration>(
      stream: positionStream,
      builder: (context, snapshot) {
        final position = snapshot.data ?? Duration.zero;
        final currentId = audioHandler.mediaItem.value?.id;
        final isPlaying = audioHandler.playbackState.value.playing;
        final statsState = context.watch<InteractionStatsCubit>().state;

        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              if (spotifyLoading)
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: LinearProgressIndicator(),
                ),
              if (spotifyPreviewItems.isNotEmpty ||
                  (ownerMode && showSpotifyCatalogButtonWhenOwnerAndEmpty)) ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      await _showSpotifyCatalog(context, spotifyPreviewItems);
                    },
                    icon: const FaIcon(
                      FontAwesomeIcons.spotify,
                      size: 16,
                      color: Colors.white,
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1DB954),
                      foregroundColor: Colors.white,
                    ),
                    label: const Text('Spotify Katalogu'),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              if (ownerMode) ...[
                InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () => _showSoundConnectTrackUploadSheet(context),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      vertical: 24,
                      horizontal: 18,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      gradient: const LinearGradient(
                        colors: [
                          Color(0x1AFFFFFF),
                          Color(0x1A8A5CFF),
                          Color(0x1AFF7A3D),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 54,
                          height: 54,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.inputFill,
                            border: Border.all(color: AppColors.border),
                          ),
                          child: const Icon(
                            Icons.add,
                            color: AppColors.textPrimary,
                            size: 28,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          items.isEmpty ? emptyUploadPrompt : uploadActionLabel,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'SoundConnect \u00FCzerinden \u015Fark\u0131 y\u00FCklemek i\u00E7in dokun.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              if (!ownerMode && items.isEmpty)
                const Text(
                  'Kullanici henuz ses eklemedi.',
                  style: TextStyle(color: AppColors.textMuted),
                ),
              ...List.generate(items.length, (index) {
                return _buildAudioTrackItem(
                  context: context,
                  track: items[index],
                  index: index,
                  position: position,
                  currentId: currentId,
                  isPlaying: isPlaying,
                  statsState: statsState,
                );
              }),
            ],
          ),
        );
      },
    );
  }
}
