import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:audio_service/audio_service.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/audio/audio_player_handler.dart';
import '../../../artist_venue/presentation/cubit/artist_venue_connections_cubit.dart';
import '../../../artist_venue/presentation/cubit/artist_venue_connections_state.dart';
import '../../../follow/presentation/cubit/follow_action_cubit.dart';
import '../../../follow/presentation/cubit/follow_action_state.dart';
import '../../../follow/presentation/cubit/follow_count_cubit.dart';
import '../../../follow/presentation/cubit/follow_count_state.dart';
import '../../../spotify/domain/entities/spotify_track_preview.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/widgets/gradient_text.dart';
import '../../../../shared/widgets/waveform_stub.dart';
import '../../domain/entities/media_asset.dart';
import '../../domain/entities/musician_profile.dart';
import '../../domain/entities/profile_media.dart';
import '../../domain/entities/track.dart';
import '../cubit/musician_profile_cubit.dart';
import '../cubit/musician_profile_state.dart';
import '../cubit/profile_media_cubit.dart';
import '../cubit/profile_media_state.dart';
import 'media_detail_screen.dart';

class PublicProfileArgs {
  final String? viewerUserId;

  const PublicProfileArgs({this.viewerUserId});
}

class MusicianPublicProfileScreen extends StatelessWidget {
  const MusicianPublicProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const useMockData = false;
    if (useMockData) {
      final mockProfile = MusicianProfile(
        id: 'mock-profile',
        userId: 'mock-user',
        stageName: 'Joe Doe',
        bio:
            'One Republic grubunda batarist. Egstas sapien etiam viverra amet '
            'enim risus dui. Purus phasellus nulla luctus proin interdum '
            'consequat id. Integer vitae dignissim et.',
        profilePicture: null,
        instagramUrl: 'https://instagram.com',
        youtubeUrl: 'https://youtube.com',
        soundcloudUrl: 'https://soundcloud.com',
        spotifyEmbedUrl: 'https://open.spotify.com',
        spotifyArtistId: null,
        spotifyTrackIds: const [],
        spotifyTracks: const [],
        instruments: const ['Bateri', 'Davul'],
        activeVenues: const ['Blue Jeans', 'Klein', 'Peyote'],
        bands: const ['One Republic'],
      );
      final mockMedia = ProfileMedia(
        featuredVideo: const MediaAsset(
          sourceUrl: null,
          playbackUrl: null,
          thumbnailUrl: null,
          title: 'Featured',
          durationSeconds: 120,
        ),
        videos: List.generate(
          6,
          (index) => const MediaAsset(
            sourceUrl: null,
            playbackUrl: null,
            thumbnailUrl: null,
            title: null,
            durationSeconds: 90,
          ),
        ),
        audios: List.generate(
          5,
          (index) => Track(
            id: 'track-$index',
            title: 'Ses Dosyasi ${index + 1}',
            playbackUrl: null,
            durationSeconds: 120,
            bpm: null,
          ),
        ),
      );

      return _MusicianPublicProfileContent(
        profile: mockProfile,
        media: mockMedia,
        followersCount: 10000,
        followingCount: 356,
        activeVenues: const ['Blue Jeans', 'Klein', 'Peyote'],
        viewerUserId: 'viewer-user',
        isFollowing: false,
        followLoading: false,
        spotifyTracks: const [],
        spotifyLoading: false,
      );
    }

    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => serviceLocator<MusicianProfileCubit>()..loadMyProfile(),
        ),
        BlocProvider(
          create: (_) => serviceLocator<ProfileMediaCubit>(),
        ),
        BlocProvider(
          create: (_) => serviceLocator<FollowCountCubit>(),
        ),
        BlocProvider(
          create: (_) => serviceLocator<FollowActionCubit>(),
        ),
        BlocProvider(
          create: (_) => serviceLocator<ArtistVenueConnectionsCubit>(),
        ),
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
  String? _mediaProfileId;
  String? _followUserId;
  String? _viewerUserId;
  String? _currentProfileUserId;
  String? _venueProfileId;

  void _loadMediaForProfile(String profileId) {
    if (_mediaProfileId == profileId) return;
    _mediaProfileId = profileId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<ProfileMediaCubit>().loadMedia(
            profileType: 'MUSICIAN',
            profileId: profileId,
          );
    });
  }

  void _loadFollowCounts(String userId) {
    if (userId.isEmpty) return;
    if (_followUserId == userId) return;
    _followUserId = userId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<FollowCountCubit>().loadCounts(userId);
    });
  }

  void _loadAcceptedVenues(String profileId) {
    if (profileId.isEmpty) return;
    if (_venueProfileId == profileId) return;
    _venueProfileId = profileId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<ArtistVenueConnectionsCubit>().loadAcceptedVenues(profileId);
    });
  }

  void _loadFollowStatus(String followerId, String followingId) {
    if (followerId.isEmpty || followingId.isEmpty) return;
    if (followerId == followingId) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<FollowActionCubit>().loadStatus(
            followerId: followerId,
            followingId: followingId,
          );
    });
  }


  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_viewerUserId != null) return;
    final args = ModalRoute.of(context)?.settings.arguments;
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
          _loadMediaForProfile(profile.id);
          _loadFollowCounts(profile.userId);
          _loadAcceptedVenues(profile.id);
          final viewerUserId = _viewerUserId ?? '';
          _loadFollowStatus(viewerUserId, profile.userId);
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
  });

  List<String> _resolveVenues() {
    if (activeVenues != null && activeVenues!.isNotEmpty) {
      return activeVenues!;
    }
    if (profile.activeVenues.isNotEmpty) return profile.activeVenues;
    return const ['Blue Jeans', 'Klein', 'Peyote'];
  }

  ProfileMedia _resolveMedia(ProfileMedia? media) {
    if (media != null &&
        (media.featuredVideo != null ||
            media.videos.isNotEmpty ||
            media.audios.isNotEmpty)) {
      return media;
    }
    return ProfileMedia(
      featuredVideo: const MediaAsset(
        sourceUrl: null,
        playbackUrl: null,
        thumbnailUrl: null,
        title: 'Featured',
        durationSeconds: 120,
      ),
      videos: List.generate(
        6,
        (index) => const MediaAsset(
          sourceUrl: null,
          playbackUrl: null,
          thumbnailUrl: null,
          title: null,
          durationSeconds: 90,
        ),
      ),
      audios: List.generate(
        5,
        (index) => Track(
          id: 'track-$index',
          title: 'Ses Dosyasi ${index + 1}',
          playbackUrl: null,
          durationSeconds: 120,
          bpm: null,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final resolvedMedia = _resolveMedia(media);
    final canFollow = viewerUserId.isNotEmpty &&
        profile.userId.isNotEmpty &&
        viewerUserId != profile.userId;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('SoundConnect'),
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
              const SizedBox(height: 14),
              _SocialButtonRow(profile: profile),
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
                      : 'Henuz bir aciklama eklenmedi.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    height: 1.6,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const _SectionHeader(
                title: 'Caldigi Mekanlar',
                actionLabel: 'Tumu',
              ),
              _VenueCarousel(items: _resolveVenues()),
              const SizedBox(height: 12),
              _MediaTabs(),
              _MediaContent(
                media: resolvedMedia,
                spotifyTracks: spotifyTracks,
                spotifyLoading: spotifyLoading,
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
        bottomNavigationBar: _BottomBar(),
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
                    color: AppColors.brandGradient[2].withOpacity(0.35),
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
                    colors: AppColors.brandGradient,
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.navBlueDeep, width: 2),
                ),
                child: const Icon(
                  Icons.music_note,
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
    final name = profile.stageName?.trim().isNotEmpty == true
        ? profile.stageName!
        : 'Sahne adi';
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
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (bandName != null) ...[
          const SizedBox(height: 6),
          Text(
            bandName,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 13,
            ),
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

    final String normalized =
        trimmed.contains('://') ? trimmed : 'https://$trimmed';
    final uri = Uri.tryParse(normalized);
    if (uri == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gecersiz link')),
      );
      return;
    }

    final success = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
    if (!success && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Link acilamadi')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _SocialPill(
          icon: FontAwesomeIcons.soundcloud,
          active: profile.soundcloudUrl?.isNotEmpty == true,
          onTap: () => _launchExternalUrl(context, profile.soundcloudUrl),
        ),
        _SocialPill(
          icon: FontAwesomeIcons.instagram,
          active: profile.instagramUrl?.isNotEmpty == true,
          onTap: () => _launchExternalUrl(context, profile.instagramUrl),
        ),
        _SocialPill(
          icon: FontAwesomeIcons.youtube,
          active: profile.youtubeUrl?.isNotEmpty == true,
          onTap: () => _launchExternalUrl(context, profile.youtubeUrl),
        ),
        _SocialPill(
          icon: FontAwesomeIcons.spotify,
          active: profile.spotifyEmbedUrl?.isNotEmpty == true,
          onTap: () => _launchExternalUrl(context, profile.spotifyEmbedUrl),
        ),
      ],
    );
  }
}

class _SocialPill extends StatefulWidget {
  final IconData icon;
  final bool active;
  final VoidCallback? onTap;

  const _SocialPill({
    required this.icon,
    required this.active,
    this.onTap,
  });

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
      colors: [
        Color(0xFFFF7A3D),
        Color(0xFFEF5F86),
        Color(0xFFB85CFF),
      ],
    );

    final borderColor =
        _pressed ? AppColors.textMuted : AppColors.border;
    final shadowOpacity = _pressed ? 0.12 : 0.05;

    return GestureDetector(
      onTapDown: widget.active ? (_) => setState(() => _pressed = true) : null,
      onTapCancel: widget.active ? () => setState(() => _pressed = false) : null,
      onTapUp: widget.active ? (_) => setState(() => _pressed = false) : null,
      onTap: widget.active ? widget.onTap : null,
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOut,
          width: 78,
          height: 42,
          margin: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            color: AppColors.inputFill,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(shadowOpacity),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Center(
            child: ShaderMask(
              shaderCallback: (bounds) => iconGradient.createShader(bounds),
              child: FaIcon(
                widget.icon,
                size: 20,
                color: AppColors.white,
              ),
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

  const _SectionHeader({
    required this.title,
    this.actionLabel,
  });

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
                colors: [
                  AppColors.inputFill,
                  AppColors.navBlueSoft,
                ],
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
                        color: AppColors.white.withOpacity(0.08),
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

class _MediaTabs extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: TabBar(
        indicatorColor: AppColors.coralAlt,
        labelColor: AppColors.textPrimary,
        unselectedLabelColor: AppColors.textMuted,
        indicatorWeight: 3,
        labelPadding: const EdgeInsets.symmetric(horizontal: 6),
        tabs: const [
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.graphic_eq, size: 18),
                SizedBox(width: 6),
                Text('Sesler'),
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
    if (controller == null) {
      return _AudioTab(
        items: audioItems,
        spotifyTracks: spotifyTracks,
        spotifyLoading: spotifyLoading,
        audioHandler: audioHandler,
      );
    }

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return controller.index == 0
            ? _AudioTab(
                items: audioItems,
                spotifyTracks: spotifyTracks,
                spotifyLoading: spotifyLoading,
                audioHandler: audioHandler,
              )
            : _VideoTab(items: videoItems);
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

    if (audioHandler is AudioPlayerHandler) {
      if (currentId == track.id && isPlaying) {
        await audioHandler.pause();
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

    if (audioHandler is AudioPlayerHandler) {
      if (currentId == mediaId && isPlaying) {
        await audioHandler.pause();
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
                  'Sanatçının Spotify Kataloğu ',
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
                                        image: NetworkImage(track.albumImageUrl!),
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
          'Ses eklenmedi.',
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
                final likeCount = 128 + (index * 7);
                final commentCount = 32 + (index * 3);
                final playback = track.playbackUrl ?? '';
                final isSpotify = playback.contains('spotify') ||
                    playback.contains('open.spotify') ||
                    playback.contains('spotify.com');
                final isCurrent = currentId == track.id;
                final totalFromTrack = track.durationSeconds ?? 0;
                final totalFromHandler =
                    audioHandler.mediaItem.value?.duration?.inSeconds ?? 0;
                final totalSeconds = (totalFromTrack > 0
                        ? totalFromTrack
                        : totalFromHandler)
                    .toDouble();
                final progress = totalSeconds > 0
                    ? (position.inSeconds / totalSeconds).clamp(0.0, 1.0)
                    : 0.0;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GestureDetector(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => MediaDetailScreen(
                                title: track.title,
                                isVideo: false,
                                playbackUrl: track.playbackUrl,
                                thumbnailUrl: null,
                                durationSeconds: track.durationSeconds,
                                likeCount: likeCount,
                                commentCount: commentCount,
                                isSpotify: isSpotify,
                              ),
                            ),
                          );
                        },
                        child: _AudioPreviewCard(
                          title: track.title,
                          actionLabel:
                              isSpotify ? "Tamamını Spotify'da Dinle" : null,
                          actionColor:
                              isSpotify ? const Color(0xFF1DB954) : null,
                          likeCount: likeCount,
                          commentCount: commentCount,
                          waveform: WaveformStub(
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
                            onPlay: () => _toggleTrack(track),
                            isPlaying: isCurrent && isPlaying,
                            progress: isCurrent ? progress : 0,
                            onSeek: (ratio) {
                              final seconds =
                                  (totalSeconds * ratio).round().clamp(0, 1000000);
                              audioHandler.seek(Duration(seconds: seconds));
                            },
                          ),
                        ),
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
      actionLabel: "Tamamını Spotify'da Dinle",
      actionColor: const Color(0xFF1DB954),
      likeCount: 210,
      commentCount: 44,
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

class _AudioPreviewCard extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final Color? actionColor;
  final VoidCallback? onActionTap;
  final Widget waveform;
  final int? likeCount;
  final int? commentCount;

  const _AudioPreviewCard({
    required this.title,
    required this.waveform,
    this.actionLabel,
    this.actionColor,
    this.onActionTap,
    this.likeCount,
    this.commentCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
            title,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (actionLabel != null) ...[
            const SizedBox(height: 4),
            GestureDetector(
              onTap: onActionTap,
              child: Text(
                actionLabel!,
                style: TextStyle(
                  color: actionColor ?? AppColors.textMuted,
                  fontSize: 12,
                  decoration:
                      onActionTap != null ? TextDecoration.underline : null,
                ),
              ),
            ),
          ],
          const SizedBox(height: 10),
          waveform,
          if (likeCount != null && commentCount != null) ...[
            const SizedBox(height: 8),
            _CountRow(
              likeCount: likeCount!,
              commentCount: commentCount!,
            ),
          ],
        ],
      ),
    );
  }
}


class _VideoTab extends StatelessWidget {
  final List<MediaAsset> items;

  const _VideoTab({required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Text(
          'Video eklenmedi.',
          style: TextStyle(color: AppColors.textMuted),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(20),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.85,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final thumbnail = item.thumbnailUrl ?? item.playbackUrl;
        final likeCount = 210 + (index * 9);
        final commentCount = 44 + (index * 4);
        return Container(
          decoration: BoxDecoration(
            color: AppColors.inputFill,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
            image: thumbnail != null
                ? DecorationImage(
                    image: NetworkImage(thumbnail),
                    fit: BoxFit.cover,
                  )
                : null,
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => MediaDetailScreen(
                    title: item.title ?? 'Video',
                    isVideo: true,
                    playbackUrl: item.playbackUrl,
                    thumbnailUrl: thumbnail,
                    likeCount: likeCount,
                    commentCount: commentCount,
                  ),
                ),
              );
            },
            child: Stack(
              children: [
                Positioned(
                  left: 10,
                  bottom: 10,
                  child: _CountRow(
                    likeCount: likeCount,
                    commentCount: commentCount,
                    light: true,
                  ),
                ),
                const Center(
                  child: Icon(
                    Icons.play_circle_outline,
                    color: AppColors.white,
                    size: 36,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CountRow extends StatelessWidget {
  final int likeCount;
  final int commentCount;
  final bool light;

  const _CountRow({
    required this.likeCount,
    required this.commentCount,
    this.light = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = light ? AppColors.white : AppColors.textMuted;
    return Row(
      children: [
        Icon(Icons.favorite_border, size: 16, color: color),
        const SizedBox(width: 6),
        Text(
          likeCount.toString(),
          style: TextStyle(color: color, fontSize: 12),
        ),
        const SizedBox(width: 12),
        Icon(Icons.chat_bubble_outline, size: 16, color: color),
        const SizedBox(width: 6),
        Text(
          commentCount.toString(),
          style: TextStyle(color: color, fontSize: 12),
        ),
      ],
    );
  }
}

class _BottomBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: 0,
      type: BottomNavigationBarType.fixed,
      backgroundColor: AppColors.navBlueDeep,
      selectedItemColor: AppColors.coralAlt,
      unselectedItemColor: AppColors.textMuted,
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.home_outlined),
          label: '',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.show_chart_outlined),
          label: '',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.mail_outline),
          label: '',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person_outline),
          label: '',
        ),
      ],
    );
  }
}






