import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:audio_service/audio_service.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/audio/audio_player_handler.dart';
import '../../../artist_venue/presentation/cubit/artist_venue_connections_cubit.dart';
import '../../../artist_venue/presentation/cubit/artist_venue_connections_state.dart';
import '../../../engagement/presentation/cubit/comment_thread_cubit.dart';
import '../../../engagement/presentation/cubit/interaction_stats_cubit.dart';
import '../../../follow/presentation/cubit/follow_action_cubit.dart';
import '../../../follow/presentation/cubit/follow_action_state.dart';
import '../../../follow/presentation/cubit/follow_count_cubit.dart';
import '../../../follow/presentation/cubit/follow_count_state.dart';
import '../../../spotify/domain/entities/spotify_track_preview.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/widgets/gradient_text.dart';
import '../../../../shared/widgets/waveform_stub.dart';
import '../../domain/entities/musician_profile.dart';
import '../../domain/entities/profile_media.dart';
import '../../domain/entities/track.dart';
import '../cubit/musician_profile_cubit.dart';
import '../cubit/musician_profile_state.dart';
import '../cubit/profile_media_cubit.dart';
import 'media_detail_screen.dart';
import 'profile_audio_transport.dart';
import 'profile_common_widgets.dart';
import 'profile_count_row.dart';
import 'profile_public_bottom_bar.dart';
import 'profile_public_video_tab.dart';
import 'profile_route_args.dart';
import 'profile_screen_support.dart';

part 'musician_public_profile_screen_audio_cards.dart';
part 'musician_public_profile_screen_content.dart';
part 'musician_public_profile_screen_sections.dart';
part 'musician_public_profile_screen_sections_venues.dart';
part 'musician_public_profile_screen_sections_social.dart';
part 'musician_public_profile_screen_sections_tabs.dart';
part 'musician_public_profile_screen_media.dart';
part 'musician_public_profile_screen_media_audio_tab.dart';
part 'musician_public_profile_screen_media_audio_tab_actions.dart';
part 'musician_public_profile_screen_media_audio_tab_track_item.dart';

class MusicianPublicProfileScreen extends StatelessWidget {
  const MusicianPublicProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => serviceLocator<MusicianProfileCubit>()),
        BlocProvider(create: (_) => serviceLocator<ProfileMediaCubit>()),
        BlocProvider(create: (_) => serviceLocator<FollowCountCubit>()),
        BlocProvider(create: (_) => serviceLocator<FollowActionCubit>()),
        BlocProvider(
          create: (_) => serviceLocator<ArtistVenueConnectionsCubit>(),
        ),
        BlocProvider(create: (_) => serviceLocator<InteractionStatsCubit>()),
      ],
      child: const _MusicianPublicProfileView(),
    );
  }
}

class _MusicianPublicProfileView extends StatefulWidget {
  const _MusicianPublicProfileView();

  @override
  State<_MusicianPublicProfileView> createState() =>
      _MusicianPublicProfileViewState();
}

class _MusicianPublicProfileViewState
    extends State<_MusicianPublicProfileView> {
  String? _targetProfileId;
  final _loadCoordinator = ProfileScreenLoadCoordinator();
  String? _viewerUserId;
  String? _currentProfileUserId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (_targetProfileId == null) {
      if (args is PublicProfileArgs) {
        _targetProfileId = args.profileId;
      } else if (args is Map<String, dynamic>) {
        _targetProfileId = args['profileId']?.toString();
      }
      if (_targetProfileId != null && _targetProfileId!.isNotEmpty) {
        context.read<MusicianProfileCubit>().loadPublicProfile(
          _targetProfileId!,
        );
      }
    }
    if (_viewerUserId != null) return;
    if (args is PublicProfileArgs) {
      _viewerUserId = args.viewerUserId;
    } else if (args is Map<String, dynamic>) {
      _viewerUserId = args['viewerUserId']?.toString();
    } else if (args is String) {
      _viewerUserId = args;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<FollowActionCubit, FollowActionState>(
          listener: (context, state) {
            if (state.status == FollowActionStatus.success &&
                _currentProfileUserId != null) {
              context.read<FollowCountCubit>().loadCounts(
                _currentProfileUserId!,
              );
            }
          },
        ),
      ],
      child: BlocBuilder<MusicianProfileCubit, MusicianProfileState>(
        builder: (context, state) {
          if (state.status == MusicianProfileStatus.loading) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          if (state.status == MusicianProfileStatus.idle &&
              (_targetProfileId == null || _targetProfileId!.isEmpty)) {
            return const Scaffold(
              body: Center(child: Text('Profil hedefi bulunamadi')),
            );
          }

          if (state.status == MusicianProfileStatus.failure ||
              state.profile == null) {
            return Scaffold(
              body: Center(
                child: Text(state.error?.message ?? 'Profil getirilemedi'),
              ),
            );
          }

          final profile = state.profile!;
          _currentProfileUserId = profile.userId;
          _loadCoordinator.scheduleMediaLoad(
            context,
            mounted: mounted,
            profileId: profile.id,
            profileType: ProfileMediaOwnerType.musician,
          );
          _loadCoordinator.scheduleFollowCountsLoad(
            context,
            mounted: mounted,
            userId: profile.userId,
          );
          _loadCoordinator.scheduleAcceptedVenuesLoad(
            context,
            mounted: mounted,
            profileId: profile.id,
          );
          final viewerUserId = _viewerUserId ?? '';
          _loadCoordinator.scheduleFollowStatusLoad(
            context,
            mounted: mounted,
            followerId: viewerUserId,
            followingId: profile.userId,
            separator: '::',
          );
          final media = context.watch<ProfileMediaCubit>().state.media;
          final venueState = context.watch<ArtistVenueConnectionsCubit>().state;
          final venueItems =
              venueState.status == ArtistVenueConnectionsStatus.loading
              ? null
              : venueState.venues;
          final followState = context.watch<FollowCountCubit>().state;
          final followersCount = followState.status == FollowCountStatus.loading
              ? null
              : followState.followersCount;
          final followingCount = followState.status == FollowCountStatus.loading
              ? null
              : followState.followingCount;
          final actionState = context.watch<FollowActionCubit>().state;
          return _MusicianPublicProfileContent(
            profile: profile,
            media: media,
            followersCount: followersCount,
            followingCount: followingCount,
            activeVenues: venueItems,
            viewerUserId: viewerUserId,
            isFollowing: actionState.isFollowing,
            followLoading: actionState.status == FollowActionStatus.loading,
            spotifyTracks: profile.spotifyTracks,
            spotifyLoading: false,
          );
        },
      ),
    );
  }
}
