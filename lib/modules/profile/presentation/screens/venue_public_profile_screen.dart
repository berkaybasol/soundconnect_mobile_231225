// ignore_for_file: unused_element, unused_element_parameter

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:audio_service/audio_service.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/audio/audio_player_handler.dart';
import '../../../artist_venue/presentation/cubit/artist_venue_connections_cubit.dart';
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
import '../../domain/entities/venue_public_profile.dart';
import '../cubit/musician_profile_cubit.dart';
import '../cubit/profile_media_cubit.dart';
import '../cubit/venue_profile_cubit.dart';
import '../cubit/venue_profile_state.dart';
import 'media_detail_screen.dart';
import 'profile_audio_transport.dart';
import 'profile_count_row.dart';
import 'profile_public_bottom_bar.dart';
import 'profile_public_video_tab.dart';
import 'profile_screen_support.dart';
import 'weekly_event_carousel.dart';
import 'weekly_event_detail_screen.dart';

class PublicProfileArgs {
  final String? viewerUserId;

  const PublicProfileArgs({this.viewerUserId});
}

class VenuePublicProfileArgs {
  final String? venueId;
  final String? viewerUserId;

  const VenuePublicProfileArgs({this.venueId, this.viewerUserId});
}

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
  String? _publicVenueId;
  final _loadCoordinator = ProfileScreenLoadCoordinator();
  String? _viewerUserId;
  String? _currentProfileUserId;

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
    if (_viewerUserId != null) return;
    if (args is VenuePublicProfileArgs) {
      _viewerUserId = args.viewerUserId;
    } else if (args is PublicProfileArgs) {
      _viewerUserId = args.viewerUserId;
    } else if (args is Map<String, dynamic>) {
      _viewerUserId = args['viewerUserId']?.toString();
    } else if (args is String) {
      _viewerUserId = args;
    }
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
        final weeklyEvents = _toWeeklyCalendarEvents(publicProfile);
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
                media: media,
                followersCount: followersCount,
                followingCount: followingCount,
                activeVenues: publicProfile.activeMusicians
                    .map((item) => item.displayName)
                    .toList(),
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

  MusicianProfile _toDisplayProfile(VenuePublicProfile profile) {
    final location = [
      profile.neighborhoodName,
      profile.districtName,
      profile.cityName,
    ].where((item) => item != null && item.trim().isNotEmpty).join(' / ');

    return MusicianProfile(
      id: profile.venueId,
      userId: profile.ownerUserId,
      username: profile.venueName,
      stageName: profile.venueName,
      bio: profile.bio ?? profile.description,
      profilePicture: profile.profilePictureUrl,
      instagramUrl: profile.instagramUrl,
      youtubeUrl: profile.youtubeUrl,
      soundcloudUrl: profile.website,
      spotifyEmbedUrl: profile.websiteUrl,
      spotifyArtistId: null,
      spotifyTrackIds: const [],
      spotifyTracks: const [],
      instruments: const [],
      activeVenues: profile.activeMusicians
          .map((item) => item.displayName)
          .toList(),
      bands: location.isEmpty ? const [] : [location],
    );
  }

  List<WeeklyCalendarEvent> _toWeeklyCalendarEvents(
    VenuePublicProfile profile,
  ) {
    return profile.weeklyEvents
        .map(
          (item) => WeeklyCalendarEvent(
            id: item.eventId,
            title: item.title,
            artistName: item.performerName,
            artistProfileId: item.musicianProfileId,
            venueName: profile.venueName,
            venueId: profile.venueId,
            city: profile.cityName ?? '',
            district: profile.districtName ?? '',
            neighborhood: profile.neighborhoodName ?? '',
            eventDate: _formatDate(item.eventDate),
            startTime: item.startTime ?? '-',
            endTime: item.endTime ?? '-',
            imageAssetPath: item.posterImage,
            description:
                profile.description ?? '${item.performerType} performansi',
          ),
        )
        .toList();
  }

  String _formatDate(DateTime? value) {
    if (value == null) return '-';
    return '${value.day.toString().padLeft(2, '0')}.${value.month.toString().padLeft(2, '0')}.${value.year}';
  }
}

class _MusicianPublicProfileContent extends StatelessWidget {
  final MusicianProfile profile;
  final ProfileMedia? media;
  final int? followersCount;
  final int? followingCount;
  final List<String>? activeVenues;
  final String viewerUserId;
  final bool isFollowing;
  final bool followLoading;
  final List<SpotifyTrackPreview> spotifyTracks;
  final bool spotifyLoading;
  final List<WeeklyCalendarEvent> weeklyEvents;

  const _MusicianPublicProfileContent({
    required this.profile,
    required this.media,
    required this.followersCount,
    required this.followingCount,
    required this.activeVenues,
    required this.viewerUserId,
    required this.isFollowing,
    required this.followLoading,
    required this.spotifyTracks,
    required this.spotifyLoading,
    required this.weeklyEvents,
  });

  List<String> _resolveVenues() {
    if (activeVenues != null && activeVenues!.isNotEmpty) {
      return activeVenues!;
    }
    if (profile.activeVenues.isNotEmpty) return profile.activeVenues;
    return const [];
  }

  ProfileMedia _resolveMedia(ProfileMedia? media) {
    if (media != null &&
        (media.featuredVideo != null ||
            media.videos.isNotEmpty ||
            media.audios.isNotEmpty)) {
      return media;
    }
    return const ProfileMedia(featuredVideo: null, videos: [], audios: []);
  }

  @override
  Widget build(BuildContext context) {
    final resolvedMedia = _resolveMedia(media);
    final canFollow =
        viewerUserId.isNotEmpty &&
        profile.userId.isNotEmpty &&
        viewerUserId != profile.userId;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const GradientText(
            text: 'SoundConnect',
            gradient: LinearGradient(colors: AppColors.brandGradient),
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
          ),
          leading: const BackButton(),
          centerTitle: true,
        ),
        body: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.center,
                child: _ProfileHeader(profile: profile),
              ),
              const SizedBox(height: 16),
              _ProfileIdentity(profile: profile),
              const SizedBox(height: 14),
              _FollowerRow(
                followersCount: followersCount,
                followingCount: followingCount,
              ),
              const SizedBox(height: 12),
              _ActionButtons(
                isFollowing: isFollowing,
                isEnabled: canFollow,
                isLoading: followLoading,
                onFollowToggle: () {
                  if (!canFollow) return;
                  context.read<FollowActionCubit>().toggleFollow(
                    followerId: viewerUserId,
                    followingId: profile.userId,
                  );
                },
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Text(
                  profile.bio?.trim().isNotEmpty == true
                      ? profile.bio!
                      : 'Henüz bir açıklama eklenmedi.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    height: 1.6,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const _SectionHeader(title: 'Haftalik Takvim'),
              WeeklyEventCarousel(items: weeklyEvents, compactTitle: true),
              const SizedBox(height: 12),
              const _SectionHeader(
                title: 'Aktif Sanatcilar',
                actionLabel: 'Tumu',
              ),
              _VenueCarousel(items: _resolveVenues()),
              const SizedBox(height: 12),
              _MediaTabs(),
              _MediaContent(
                media: resolvedMedia,
                spotifyTracks: const [],
                spotifyLoading: spotifyLoading,
              ),
              const SizedBox(height: 18),
              _SocialButtonRow(profile: profile),
              const SizedBox(height: 24),
            ],
          ),
        ),
        bottomNavigationBar: const ProfilePublicBottomBar(),
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  final MusicianProfile profile;

  const _ProfileHeader({required this.profile});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 0),
      child: SizedBox(
        width: 96,
        height: 96,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.inputFill,
                border: Border.all(color: AppColors.border),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.brandGradient[2].withValues(alpha: 0.35),
                    blurRadius: 18,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: ClipOval(
                child: profile.profilePicture?.startsWith('http') == true
                    ? Image.network(profile.profilePicture!, fit: BoxFit.cover)
                    : const Icon(
                        Icons.person_outline,
                        color: AppColors.textMuted,
                        size: 40,
                      ),
              ),
            ),
            Positioned(
              right: -2,
              bottom: -2,
              child: Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF7C3AED),
                      Color(0xFFA855F7),
                      Color(0xFFD946EF),
                    ],
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.navBlueDeep, width: 2),
                ),
                child: const Icon(
                  Icons.storefront_outlined,
                  size: 14,
                  color: AppColors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileIdentity extends StatelessWidget {
  final MusicianProfile profile;

  const _ProfileIdentity({required this.profile});

  @override
  Widget build(BuildContext context) {
    final name = profile.username?.trim().isNotEmpty == true
        ? profile.username!
        : 'Kullanıcı';
    final bandName = profile.bands.isNotEmpty ? profile.bands.first : null;

    return Column(
      children: [
        GradientText(
          text: name,
          gradient: const LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: AppColors.brandGradient,
          ),
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        if (bandName != null) ...[
          const SizedBox(height: 6),
          Text(
            bandName,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
        ],
      ],
    );
  }
}

class _FollowerRow extends StatelessWidget {
  final int? followersCount;
  final int? followingCount;

  const _FollowerRow({
    required this.followersCount,
    required this.followingCount,
  });

  String _formatCount(int? value, String label) {
    if (value == null) return '... $label';
    return '$value $label';
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _PillBadge(text: _formatCount(followersCount, 'Takipci')),
        const SizedBox(width: 12),
        _PillBadge(text: _formatCount(followingCount, 'Takip')),
      ],
    );
  }
}

class _PillBadge extends StatelessWidget {
  final String text;

  const _PillBadge({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.inputFill,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _SocialButtonRow extends StatelessWidget {
  final MusicianProfile profile;

  const _SocialButtonRow({required this.profile});

  Future<void> _launchExternalUrl(BuildContext context, String? url) async {
    final trimmed = url?.trim();
    if (trimmed == null || trimmed.isEmpty) return;

    final String normalized = trimmed.contains('://')
        ? trimmed
        : 'https://$trimmed';
    final uri = Uri.tryParse(normalized);
    if (uri == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Geçersiz link')));
      return;
    }

    final success = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!success && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Link açılamadı')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final socialButtons = <Widget>[];
    if (_isSocialUrlUsable(profile.soundcloudUrl)) {
      socialButtons.add(
        _SocialPill(
          icon: FontAwesomeIcons.soundcloud,
          active: true,
          onTap: () => _launchExternalUrl(context, profile.soundcloudUrl),
        ),
      );
    }
    if (_isSocialUrlUsable(profile.instagramUrl)) {
      socialButtons.add(
        _SocialPill(
          icon: FontAwesomeIcons.instagram,
          active: true,
          onTap: () => _launchExternalUrl(context, profile.instagramUrl),
        ),
      );
    }
    if (_isSocialUrlUsable(profile.youtubeUrl)) {
      socialButtons.add(
        _SocialPill(
          icon: FontAwesomeIcons.youtube,
          active: true,
          onTap: () => _launchExternalUrl(context, profile.youtubeUrl),
        ),
      );
    }
    if (_isSocialUrlUsable(profile.spotifyEmbedUrl)) {
      socialButtons.add(
        _SocialPill(
          icon: FontAwesomeIcons.spotify,
          active: true,
          onTap: () => _launchExternalUrl(context, profile.spotifyEmbedUrl),
        ),
      );
    }

    if (socialButtons.isEmpty) return const SizedBox.shrink();

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: socialButtons,
    );
  }
}

bool _isSocialUrlUsable(String? raw) {
  final value = raw?.trim().toLowerCase();
  if (value == null || value.isEmpty) return false;
  return value.startsWith('http://') ||
      value.startsWith('https://') ||
      value.startsWith('www.');
}

class _SocialPill extends StatefulWidget {
  final IconData icon;
  final bool active;
  final VoidCallback? onTap;

  const _SocialPill({required this.icon, required this.active, this.onTap});

  @override
  State<_SocialPill> createState() => _SocialPillState();
}

class _SocialPillState extends State<_SocialPill> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    const iconGradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFFF7A3D), Color(0xFFEF5F86), Color(0xFFB85CFF)],
    );

    final borderColor = _pressed ? AppColors.textMuted : AppColors.border;
    final shadowOpacity = _pressed ? 0.12 : 0.05;

    return GestureDetector(
      onTapDown: widget.active ? (_) => setState(() => _pressed = true) : null,
      onTapCancel: widget.active
          ? () => setState(() => _pressed = false)
          : null,
      onTapUp: widget.active ? (_) => setState(() => _pressed = false) : null,
      onTap: widget.active ? widget.onTap : null,
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOut,
          width: 74,
          height: 42,
          decoration: BoxDecoration(
            color: AppColors.inputFill,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: shadowOpacity),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Center(
            child: ShaderMask(
              shaderCallback: (bounds) => iconGradient.createShader(bounds),
              child: FaIcon(widget.icon, size: 20, color: AppColors.white),
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionButtons extends StatelessWidget {
  final bool isFollowing;
  final bool isEnabled;
  final bool isLoading;
  final VoidCallback onFollowToggle;

  const _ActionButtons({
    required this.isFollowing,
    required this.isEnabled,
    required this.isLoading,
    required this.onFollowToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: isEnabled && !isLoading ? onFollowToggle : null,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textPrimary,
                side: const BorderSide(color: AppColors.border),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              child: Text(
                isLoading
                    ? 'Bekle...'
                    : (isFollowing ? 'Takip Ediliyor' : 'Takip Et'),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.coralAlt,
                foregroundColor: AppColors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              child: const Text('Mesaj Gonder'),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Text(
        title,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;

  const _SectionHeader({required this.title, this.actionLabel});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          if (actionLabel != null)
            Text(
              actionLabel!,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
    );
  }
}

class _VenueCarousel extends StatelessWidget {
  final List<String> items;

  const _VenueCarousel({required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        child: Text(
          'Mekan bilgisi yok.',
          style: TextStyle(color: AppColors.textMuted),
        ),
      );
    }

    return SizedBox(
      height: 62,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        itemBuilder: (context, index) {
          final name = items[index];
          return Container(
            width: 160,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.inputFill, AppColors.navBlueSoft],
              ),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: AppColors.navBlueSoft,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.white.withValues(alpha: 0.08),
                        blurRadius: 6,
                        spreadRadius: 0.5,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.storefront_outlined,
                    color: AppColors.coralAlt,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      GradientText(
                        text: name,
                        gradient: const LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: AppColors.brandGradient,
                        ),
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right,
                  color: AppColors.textMuted,
                  size: 18,
                ),
              ],
            ),
          );
        },
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemCount: items.length,
      ),
    );
  }
}

class _EventCalendarMock extends StatelessWidget {
  final List<WeeklyCalendarEvent> items;

  const _EventCalendarMock({required this.items});

  // ignore: unused_field
  static const List<WeeklyCalendarEvent> _items = [
    WeeklyCalendarEvent(
      id: 'venue-event-1',
      title: 'Acoustic Night',
      artistName: 'Luna Echo',
      artistProfileId: null,
      venueName: 'Sahne A',
      venueId: 'venue-1',
      city: 'Istanbul',
      district: 'Besiktas',
      neighborhood: 'Sinanpasa',
      eventDate: '28.03.2026',
      startTime: '20:30',
      endTime: '22:00',
      imageAssetPath: 'assets/logo.png',
      description: 'Haftalik akustik repertuvar gecesi.',
    ),
    WeeklyCalendarEvent(
      id: 'venue-event-2',
      title: 'DJ Session',
      artistName: 'Neon Tide',
      artistProfileId: null,
      venueName: 'Teras',
      venueId: 'venue-2',
      city: 'Istanbul',
      district: 'Kadikoy',
      neighborhood: 'Moda',
      eventDate: '29.03.2026',
      startTime: '22:00',
      endTime: '23:45',
      imageAssetPath: 'assets/logo.png',
      description: 'Elektronik set ve sahne gecisleri.',
    ),
    WeeklyCalendarEvent(
      id: 'venue-event-3',
      title: 'Open Mic',
      artistName: 'Aegean Collective',
      artistProfileId: null,
      venueName: 'Lounge',
      venueId: 'venue-3',
      city: 'Istanbul',
      district: 'Sisli',
      neighborhood: 'Nisantasi',
      eventDate: '30.03.2026',
      startTime: '19:00',
      endTime: '21:00',
      imageAssetPath: 'assets/logo.png',
      description: 'Acik mikrofon performans bulusmasi.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 20),
        child: SizedBox(
          height: 88,
          child: Center(
            child: Text(
              'Bu hafta icin etkinlik bulunamadi.',
              style: TextStyle(color: AppColors.textMuted),
            ),
          ),
        ),
      );
    }
    return SizedBox(
      height: 88,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final event = items[index];
          return InkWell(
            borderRadius: BorderRadius.circular(16),
            splashColor: AppColors.coral.withValues(alpha: 0.22),
            highlightColor: Colors.white.withValues(alpha: 0.05),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => WeeklyEventDetailScreen(event: event),
                ),
              );
            },
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              child: Ink(
                width: 170,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.inputFill, AppColors.navBlueSoft],
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        width: 50,
                        child: event.imageAssetPath != null
                            ? Image.asset(
                                event.imageAssetPath!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  color: AppColors.navBlueSoft,
                                  alignment: Alignment.center,
                                  child: const Icon(
                                    Icons.image_outlined,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                              )
                            : Container(
                                color: AppColors.navBlueSoft,
                                alignment: Alignment.center,
                                child: const Icon(
                                  Icons.image_outlined,
                                  color: AppColors.textMuted,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            event.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w700,
                              height: 1.15,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(
                                Icons.calendar_today_outlined,
                                size: 13,
                                color: AppColors.coralAlt,
                              ),
                              const SizedBox(width: 5),
                              Expanded(
                                child: Text(
                                  '${event.eventDate} - ${event.startTime}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(
                                Icons.music_note_outlined,
                                size: 13,
                                color: AppColors.coralAlt,
                              ),
                              const SizedBox(width: 5),
                              Expanded(
                                child: Text(
                                  event.artistName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _MediaTabs extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: TabBar(
        labelColor: AppColors.textPrimary,
        unselectedLabelColor: AppColors.textMuted,
        indicator: const _GradientTabIndicator(
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: AppColors.brandGradient,
          ),
          thickness: 2,
          horizontalInset: 0,
        ),
        labelPadding: const EdgeInsets.symmetric(horizontal: 6),
        tabs: const [
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.photo_library_outlined, size: 18),
                SizedBox(width: 6),
                Text('Fotograflar'),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.play_circle_outline, size: 18),
                SizedBox(width: 6),
                Text('Video'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GradientTabIndicator extends Decoration {
  final LinearGradient gradient;
  final double thickness;
  final double horizontalInset;

  const _GradientTabIndicator({
    required this.gradient,
    this.thickness = 2,
    this.horizontalInset = 0,
  });

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) {
    return _GradientTabIndicatorPainter(
      gradient: gradient,
      thickness: thickness,
      horizontalInset: horizontalInset,
    );
  }
}

class _GradientTabIndicatorPainter extends BoxPainter {
  final LinearGradient gradient;
  final double thickness;
  final double horizontalInset;

  _GradientTabIndicatorPainter({
    required this.gradient,
    required this.thickness,
    required this.horizontalInset,
  });

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    final size = configuration.size;
    if (size == null) return;

    final left = offset.dx + horizontalInset;
    final right = offset.dx + size.width - horizontalInset;
    final top = offset.dy + size.height - thickness;
    final rect = Rect.fromLTRB(left, top, right, top + thickness);
    final paint = Paint()..shader = gradient.createShader(rect);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(thickness)),
      paint,
    );
  }
}

class _MediaContent extends StatelessWidget {
  final ProfileMedia media;
  final List<SpotifyTrackPreview> spotifyTracks;
  final bool spotifyLoading;

  const _MediaContent({
    required this.media,
    required this.spotifyTracks,
    required this.spotifyLoading,
  });

  @override
  Widget build(BuildContext context) {
    final audioItems = media.audios;
    final videoItems = media.videos;
    final controller = DefaultTabController.of(context);
    final audioHandler = serviceLocator<AudioHandler>();

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return controller.index == 0
            ? _AudioTab(
                items: audioItems,
                spotifyTracks: const [],
                spotifyLoading: spotifyLoading,
                audioHandler: audioHandler,
              )
            : ProfilePublicVideoTab(items: videoItems);
      },
    );
  }
}

class _AudioTab extends StatelessWidget {
  final List<Track> items;

  final List<SpotifyTrackPreview> spotifyTracks;
  final bool spotifyLoading;
  final AudioHandler audioHandler;

  const _AudioTab({
    required this.items,
    required this.spotifyTracks,
    required this.spotifyLoading,
    required this.audioHandler,
  });

  Future<void> _toggleTrack(Track track) async {
    final url = track.playbackUrl;
    if (url == null || url.isEmpty) return;
    final currentId = audioHandler.mediaItem.value?.id;
    final isPlaying = audioHandler.playbackState.value.playing;
    final isCurrent = currentId == track.id;

    if (audioHandler is AudioPlayerHandler) {
      if (isCurrent && isPlaying) {
        await audioHandler.pause();
      } else if (isCurrent && !isPlaying) {
        await audioHandler.play();
      } else {
        await (audioHandler as AudioPlayerHandler).playUrl(
          url,
          title: track.title,
          duration: track.durationSeconds != null
              ? Duration(seconds: track.durationSeconds!)
              : null,
          mediaId: track.id,
        );
      }
    }
  }

  Future<void> _toggleSpotifyTrack(SpotifyTrackPreview track) async {
    final url = track.previewUrl;
    if (url == null || url.isEmpty) return;
    final currentId = audioHandler.mediaItem.value?.id;
    final isPlaying = audioHandler.playbackState.value.playing;
    final mediaId = 'spotify:${track.id}';
    final isCurrent = currentId == mediaId;

    if (audioHandler is AudioPlayerHandler) {
      if (isCurrent && isPlaying) {
        await audioHandler.pause();
      } else if (isCurrent && !isPlaying) {
        await audioHandler.play();
      } else {
        await (audioHandler as AudioPlayerHandler).playUrl(
          url,
          title: track.name,
          duration: track.durationSeconds != null
              ? Duration(seconds: track.durationSeconds!)
              : null,
          mediaId: mediaId,
        );
      }
    }
  }

  Future<void> _openExternalUrl(BuildContext context, String? url) async {
    final trimmed = url?.trim();
    if (trimmed == null || trimmed.isEmpty) return;
    final normalized = trimmed.contains('://') ? trimmed : 'https://$trimmed';
    final uri = Uri.tryParse(normalized);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _showSpotifyCatalog(
    BuildContext context,
    List<SpotifyTrackPreview> tracks,
  ) async {
    if (tracks.isEmpty) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.navBlueDeep,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Sanat?inin Spotify Katalogu ',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView.separated(
                    itemCount: tracks.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final track = tracks[index];
                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.inputFill,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: AppColors.navBlueSoft,
                                borderRadius: BorderRadius.circular(12),
                                image: track.albumImageUrl != null
                                    ? DecorationImage(
                                        image: NetworkImage(
                                          track.albumImageUrl!,
                                        ),
                                        fit: BoxFit.cover,
                                      )
                                    : null,
                              ),
                              child: track.albumImageUrl == null
                                  ? const Icon(
                                      Icons.music_note,
                                      color: AppColors.textMuted,
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    track.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: AppColors.textPrimary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    track.artistNames.join(', '),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: AppColors.textMuted,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            TextButton(
                              onPressed: () =>
                                  _openExternalUrl(context, track.spotifyUrl),
                              child: const Text(
                                "Spotify'da Dinle",
                                style: TextStyle(color: Color(0xFF1DB954)),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final positionStream = audioHandler is AudioPlayerHandler
        ? (audioHandler as AudioPlayerHandler).positionStream
        : const Stream<Duration>.empty();
    final spotifyPreviewItems = spotifyTracks;

    if (items.isEmpty && spotifyPreviewItems.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Text(
          'Kullanıcı henüz ses eklemedi.',
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
              if (spotifyPreviewItems.isNotEmpty) ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () =>
                        _showSpotifyCatalog(context, spotifyPreviewItems),
                    icon: const Icon(
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
              ...List.generate(items.length, (index) {
                final track = items[index];
                final fallbackLikeCount = 128 + (index * 7);
                final fallbackCommentCount = 32 + (index * 3);
                final targetType = 'MEDIA';
                final targetId = track.mediaAssetId;
                final statsKey = '$targetType:$targetId';
                if (targetId.isNotEmpty &&
                    !statsState.items.containsKey(statsKey)) {
                  context.read<InteractionStatsCubit>().load(
                    targetType: targetType,
                    targetId: targetId,
                  );
                }
                final stats = statsState.items[statsKey];
                final likeCount = stats?.likeCount ?? fallbackLikeCount;
                final commentCount =
                    stats?.commentCount ?? fallbackCommentCount;
                final playback = track.playbackUrl ?? '';
                final isSpotify =
                    playback.contains('spotify') ||
                    playback.contains('open.spotify') ||
                    playback.contains('spotify.com');
                final isCurrent = currentId == track.id;
                final totalFromTrackMs = (track.durationSeconds ?? 0) * 1000;
                final totalFromHandlerMs =
                    audioHandler.mediaItem.value?.duration?.inMilliseconds ?? 0;
                final totalMs =
                    (totalFromTrackMs > 0
                            ? totalFromTrackMs
                            : totalFromHandlerMs)
                        .toDouble();
                final progress = totalMs > 0
                    ? (position.inMilliseconds / totalMs).clamp(0.0, 1.0)
                    : 0.0;
                final isLiked = stats?.isLiked ?? false;
                void toggleLike() {
                  if (targetId.isEmpty) return;
                  context.read<InteractionStatsCubit>().toggleLike(
                    targetType: targetType,
                    targetId: targetId,
                  );
                }

                void openDetails() {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => MultiBlocProvider(
                        providers: [
                          BlocProvider.value(
                            value: context.read<InteractionStatsCubit>(),
                          ),
                          BlocProvider(
                            create: (_) => serviceLocator<CommentThreadCubit>(),
                          ),
                        ],
                        child: MediaDetailScreen(
                          title: track.title,
                          isVideo: false,
                          playbackUrl: track.playbackUrl,
                          thumbnailUrl: null,
                          durationSeconds: track.durationSeconds,
                          targetType: targetType,
                          targetId: targetId,
                          likeCount: likeCount,
                          commentCount: commentCount,
                          isSpotify: isSpotify,
                        ),
                      ),
                    ),
                  );
                }

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _AudioPreviewCard(
                        onTap: openDetails,
                        onDoubleTap: () {
                          if (!isLiked) {
                            toggleLike();
                          }
                        },
                        title: track.title,
                        actionLabel: isSpotify
                            ? "Tamamini Spotify'da Dinle"
                            : null,
                        actionColor: isSpotify ? const Color(0xFF1DB954) : null,
                        bottomControls: ProfileAudioTransportRow(
                          isPlaying: isCurrent && isPlaying,
                          iconColor: isSpotify
                              ? const Color(0xFF1DB954)
                              : AppColors.textMuted,
                          onPlayPause: () => _toggleTrack(track),
                          onBack10: isCurrent
                              ? () {
                                  final totalInt = totalMs.round();
                                  final currentMs = position.inMilliseconds;
                                  final targetMs = (currentMs - 10000)
                                      .clamp(0, totalInt)
                                      .toInt();
                                  audioHandler.seek(
                                    Duration(milliseconds: targetMs),
                                  );
                                }
                              : null,
                          onForward10: isCurrent
                              ? () {
                                  final totalInt = totalMs.round();
                                  final currentMs = position.inMilliseconds;
                                  final targetMs = (currentMs + 10000)
                                      .clamp(0, totalInt)
                                      .toInt();
                                  audioHandler.seek(
                                    Duration(milliseconds: targetMs),
                                  );
                                }
                              : null,
                        ),
                        waveform: WaveformStub(
                          samples: WaveformStub.samplesFromSeed(
                            '${track.id}:${track.title}:${track.mediaAssetId}',
                          ),
                          gradientColors: isSpotify
                              ? const [
                                  Color(0xFF1ED760),
                                  Color(0xFF1DB954),
                                  Color(0xFF18A34A),
                                ]
                              : AppColors.brandGradient,
                          iconColor: isSpotify
                              ? const Color(0xFF1DB954)
                              : AppColors.coralAlt,
                          playIconColor: isSpotify
                              ? const Color(0xFF1DB954)
                              : AppColors.textMuted,
                          leading: isSpotify
                              ? const Icon(
                                  FontAwesomeIcons.spotify,
                                  size: 16,
                                  color: Color(0xFF1DB954),
                                )
                              : Image.asset(
                                  'assets/logo.png',
                                  width: 26,
                                  height: 26,
                                  fit: BoxFit.contain,
                                ),
                          height: 92,
                          waveformHeight: 44,
                          isPlaying: isCurrent && isPlaying,
                          progress: isCurrent ? progress : 0,
                          onSeek: isCurrent
                              ? (ratio) {
                                  final milliseconds = (totalMs * ratio)
                                      .round()
                                      .clamp(0, 1000000)
                                      .toInt();
                                  audioHandler.seek(
                                    Duration(milliseconds: milliseconds),
                                  );
                                }
                              : null,
                        ),
                      ),
                      const SizedBox(height: 6),
                      ProfileCountRow(
                        likeCount: likeCount,
                        commentCount: commentCount,
                        isLiked: isLiked,
                        onLikeTap: toggleLike,
                        onCommentTap: openDetails,
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }
}

class _SpotifyPreviewCard extends StatelessWidget {
  const _SpotifyPreviewCard();

  @override
  Widget build(BuildContext context) {
    const spotifyGradient = [
      Color(0xFF1ED760),
      Color(0xFF1DB954),
      Color(0xFF18A34A),
    ];
    return _AudioPreviewCard(
      title: 'Spotify Preview',
      actionLabel: "Tamamini Spotify'da Dinle",
      actionColor: const Color(0xFF1DB954),
      waveform: const WaveformStub(
        gradientColors: spotifyGradient,
        iconColor: Color(0xFF1ED760),
        playIconColor: Color(0xFF1DB954),
        leading: Icon(
          FontAwesomeIcons.spotify,
          size: 16,
          color: Color(0xFF1DB954),
        ),
        height: 92,
        waveformHeight: 44,
      ),
    );
  }
}

class _AudioPreviewCard extends StatefulWidget {
  final String title;
  final String? actionLabel;
  final Color? actionColor;
  final VoidCallback? onTap;
  final VoidCallback? onActionTap;
  final VoidCallback? onDoubleTap;
  final Widget waveform;
  final Widget? bottomControls;

  const _AudioPreviewCard({
    required this.title,
    required this.waveform,
    this.actionLabel,
    this.actionColor,
    this.onTap,
    this.onActionTap,
    this.onDoubleTap,
    this.bottomControls,
  });

  @override
  State<_AudioPreviewCard> createState() => _AudioPreviewCardState();
}

class _AudioPreviewCardState extends State<_AudioPreviewCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _heartController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 760),
  );
  late final Animation<double> _heartScale = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween<double>(
        begin: 1.6,
        end: 1.08,
      ).chain(CurveTween(curve: Curves.easeOutCubic)),
      weight: 60,
    ),
    TweenSequenceItem(
      tween: Tween<double>(
        begin: 1.08,
        end: 0.84,
      ).chain(CurveTween(curve: Curves.easeInCubic)),
      weight: 20,
    ),
    TweenSequenceItem(
      tween: Tween<double>(
        begin: 0.84,
        end: 0.52,
      ).chain(CurveTween(curve: Curves.easeInQuart)),
      weight: 20,
    ),
  ]).animate(_heartController);
  late final Animation<double> _heartOpacity = TweenSequence<double>([
    TweenSequenceItem(tween: Tween<double>(begin: 0, end: 1), weight: 30),
    TweenSequenceItem(tween: ConstantTween<double>(1), weight: 35),
    TweenSequenceItem(tween: Tween<double>(begin: 1, end: 0), weight: 35),
  ]).animate(_heartController);
  late final Animation<double> _ringScale = Tween<double>(begin: 0.7, end: 1.9)
      .animate(
        CurvedAnimation(
          parent: _heartController,
          curve: const Interval(0.08, 0.9, curve: Curves.easeOutCubic),
        ),
      );
  late final Animation<double> _ringOpacity = TweenSequence<double>([
    TweenSequenceItem(tween: Tween<double>(begin: 0, end: 0.5), weight: 22),
    TweenSequenceItem(tween: Tween<double>(begin: 0.5, end: 0), weight: 78),
  ]).animate(_heartController);

  @override
  void dispose() {
    _heartController.dispose();
    super.dispose();
  }

  void _handleDoubleTap() {
    if (widget.onDoubleTap == null) return;
    widget.onDoubleTap?.call();
    _heartController.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      onDoubleTap: _handleDoubleTap,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.inputFill,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  widget.title,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (widget.actionLabel != null) ...[
                  const SizedBox(height: 4),
                  GestureDetector(
                    onTap: widget.onActionTap,
                    child: Text(
                      widget.actionLabel!,
                      style: TextStyle(
                        color: widget.actionColor ?? AppColors.textMuted,
                        fontSize: 12,
                        decoration: widget.onActionTap != null
                            ? TextDecoration.underline
                            : null,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                widget.waveform,
                if (widget.bottomControls != null) ...[
                  const SizedBox(height: 8),
                  widget.bottomControls!,
                ],
              ],
            ),
          ),
          IgnorePointer(
            child: AnimatedBuilder(
              animation: _heartController,
              builder: (context, _) {
                if (_heartController.value == 0) {
                  return const SizedBox.shrink();
                }
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    Opacity(
                      opacity: _ringOpacity.value,
                      child: Transform.scale(
                        scale: _ringScale.value,
                        child: Container(
                          width: 74,
                          height: 74,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.coralAlt.withValues(alpha: 0.9),
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Opacity(
                      opacity: _heartOpacity.value,
                      child: Transform.scale(
                        scale: _heartScale.value,
                        child: ShaderMask(
                          blendMode: BlendMode.srcIn,
                          shaderCallback: (Rect bounds) {
                            return const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: AppColors.brandGradient,
                            ).createShader(bounds);
                          },
                          child: const Icon(Icons.favorite, size: 76),
                        ),
                      ),
                    ),
                    Opacity(
                      opacity: _heartOpacity.value * 0.45,
                      child: Transform.scale(
                        scale: _heartScale.value * 1.05,
                        child: const Icon(
                          Icons.favorite,
                          size: 82,
                          color: Color(0x66FF5F8F),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

