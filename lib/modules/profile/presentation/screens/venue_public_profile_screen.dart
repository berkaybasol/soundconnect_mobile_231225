import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:audio_service/audio_service.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/audio/audio_player_handler.dart';
import '../../../../app/router/app_routes.dart';
import '../../../artist_venue/presentation/cubit/artist_venue_connections_cubit.dart';
import '../../../engagement/presentation/cubit/comment_thread_cubit.dart';
import '../../../engagement/presentation/cubit/interaction_stats_cubit.dart';
import '../../../follow/presentation/cubit/follow_action_cubit.dart';
import '../../../follow/presentation/cubit/follow_action_state.dart';
import '../../../follow/presentation/cubit/follow_count_cubit.dart';
import '../../../follow/presentation/cubit/follow_count_state.dart';
import '../../../spotify/domain/entities/spotify_track_preview.dart';
import '../../../../shared/images/app_cached_network_image.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/widgets/gradient_text.dart';
import '../../../../shared/widgets/waveform_stub.dart';
import '../../domain/entities/musician_profile.dart';
import '../../domain/entities/profile_media.dart';
import '../../domain/entities/track.dart';
import '../../domain/entities/venue_active_band.dart';
import '../../domain/entities/venue_active_musician.dart';
import '../../domain/entities/venue_public_profile.dart';
import '../../domain/venue_event_repository.dart';
import '../cubit/musician_profile_cubit.dart';
import '../cubit/profile_media_cubit.dart';
import '../cubit/venue_profile_cubit.dart';
import '../cubit/venue_profile_state.dart';
import 'media_detail_screen.dart';
import 'profile_audio_transport.dart';
import 'profile_common_widgets.dart';
import 'profile_count_row.dart';
import 'profile_photo_gallery_tab.dart';
import '../../../dm/presentation/screens/dm_chat_screen.dart';
import 'profile_public_bottom_bar.dart';
import 'profile_public_video_tab.dart';
import 'profile_route_args.dart';
import 'profile_screen_support.dart';
import 'venue_event_support.dart';
import 'weekly_event_carousel.dart';
import 'weekly_event_detail_screen.dart';

part 'venue_public_profile_screen_audio_cards.dart';
part 'venue_public_profile_screen_content.dart';
part 'venue_public_profile_screen_sections_primary.dart';
part 'venue_public_profile_screen_sections_primary_social.dart';
part 'venue_public_profile_screen_sections_primary_actions.dart';
part 'venue_public_profile_screen_sections_events.dart';
part 'venue_public_profile_screen_sections_events_calendar.dart';
part 'venue_public_profile_screen_sections_tabs.dart';
part 'venue_public_profile_screen_media.dart';
part 'venue_public_profile_screen_media_audio_tab.dart';
part 'venue_public_profile_screen_media_audio_tab_actions.dart';
part 'venue_public_profile_screen_media_audio_tab_track_item.dart';
part 'venue_public_profile_screen_view_methods.dart';

class VenuePublicProfileScreen extends StatelessWidget {
  const VenuePublicProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => serviceLocator<VenueProfileCubit>()),
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
  final _venueEventRepository = serviceLocator<VenueEventRepository>();
  String? _publicVenueId;
  final _loadCoordinator = ProfileScreenLoadCoordinator();
  String? _viewerUserId;
  bool _viewerUserIdResolved = false;
  String? _currentProfileUserId;
  List<WeeklyCalendarEvent> _fallbackWeeklyEvents = const [];
  String? _fallbackWeeklyEventsVenueId;
  bool _loadingFallbackWeeklyEvents = false;

  void _updateState(VoidCallback updater) {
    if (!mounted) return;
    setState(updater);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (_publicVenueId == null) {
      if (args is VenuePublicProfileArgs) {
        _publicVenueId = args.venueId;
      } else if (args is Map<String, dynamic>) {
        _publicVenueId = args['venueId']?.toString();
      } else if (args is String) {
        _publicVenueId = args;
      }
      context.read<VenueProfileCubit>().loadPublic(venueId: _publicVenueId);
    }
    if (_viewerUserIdResolved) return;
    _viewerUserIdResolved = true;
    if (args is VenuePublicProfileArgs) {
      _viewerUserId = args.viewerUserId;
    } else if (args is PublicProfileArgs) {
      _viewerUserId = args.viewerUserId;
    } else if (args is Map<String, dynamic>) {
      _viewerUserId = args['viewerUserId']?.toString();
    } else if (args is String) {
      _viewerUserId = args;
    }
    if ((_viewerUserId ?? '').trim().isEmpty) {
      _loadViewerUserIdFromToken();
    }
  }

  Future<void> _loadViewerUserIdFromToken() async {
    final resolved = await resolveCurrentViewerUserId();
    if (!mounted) return;
    final value = resolved?.trim() ?? '';
    if (value.isEmpty || value == (_viewerUserId ?? '').trim()) return;
    setState(() => _viewerUserId = value);
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<VenueProfileCubit, VenueProfileState>(
      builder: (context, venueProfileState) {
        final publicProfile = venueProfileState.publicProfile;
        if (venueProfileState.status == VenueProfileStatus.loading &&
            publicProfile == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (publicProfile == null) {
          return Scaffold(
            body: Center(
              child: Text(
                venueProfileState.error?.message ?? 'Profil getirilemedi',
              ),
            ),
          );
        }
        final profile = _toDisplayProfile(publicProfile);
        final primaryWeeklyEvents = _toWeeklyCalendarEvents(publicProfile);
        if (primaryWeeklyEvents.isEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            _ensureFallbackWeeklyEvents(publicProfile);
          });
        }
        final weeklyEvents = primaryWeeklyEvents.isNotEmpty
            ? primaryWeeklyEvents
            : _fallbackWeeklyEvents;
        _currentProfileUserId = publicProfile.ownerUserId;
        _loadCoordinator.scheduleMediaLoad(
          context,
          mounted: mounted,
          profileId: publicProfile.venueProfileId,
          profileType: ProfileMediaOwnerType.venue,
        );
        _loadCoordinator.scheduleFollowCountsLoad(
          context,
          mounted: mounted,
          userId: publicProfile.ownerUserId,
        );
        final viewerUserId = _viewerUserId ?? '';
        _loadCoordinator.scheduleFollowStatusLoad(
          context,
          mounted: mounted,
          followerId: viewerUserId,
          followingId: publicProfile.ownerUserId,
        );
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
          child: Builder(
            builder: (context) {
              final media = context.watch<ProfileMediaCubit>().state.media;
              final followState = context.watch<FollowCountCubit>().state;
              final followersCount =
                  followState.status == FollowCountStatus.loading
                  ? null
                  : followState.followersCount;
              final followingCount =
                  followState.status == FollowCountStatus.loading
                  ? null
                  : followState.followingCount;
              final actionState = context.watch<FollowActionCubit>().state;
              return _MusicianPublicProfileContent(
                profile: profile,
                galleryOwnerId: publicProfile.venueProfileId,
                media: media,
                followersCount: followersCount,
                followingCount: followingCount,
                activeVenues: publicProfile.activeMusicians,
                activeBands: publicProfile.activeBands,
                viewerUserId: viewerUserId,
                isFollowing: actionState.isFollowing,
                followLoading: actionState.status == FollowActionStatus.loading,
                spotifyTracks: const [],
                spotifyLoading: false,
                weeklyEvents: weeklyEvents,
              );
            },
          ),
        );
      },
    );
  }
}
