import 'dart:convert';
import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/audio/audio_player_handler.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/network/network_config.dart';
import '../../../../shared/images/app_cached_network_image.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/widgets/gradient_outline_button.dart';
import '../../../../shared/widgets/gradient_text.dart';
import '../../../../shared/widgets/waveform_stub.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../core/auth/token_store.dart';
import '../../domain/band_repository.dart';
import '../../domain/entities/band_member_summary.dart';
import '../../domain/entities/band_profile.dart';
import '../../domain/entities/profile_media.dart';
import '../../domain/entities/profile_venue_models.dart';
import '../../domain/musician_profile_repository.dart';
import '../../domain/musician_search_repository.dart';
import '../../../artist_venue/domain/artist_venue_connection_repository.dart';
import '../../../dm/presentation/band_representative_conversation.dart';
import '../../../engagement/presentation/cubit/interaction_stats_cubit.dart';
import '../../../follow/domain/band_follow_repository.dart';
import '../../../spotify/domain/entities/spotify_track_preview.dart';
import '../../../spotify/domain/spotify_repository.dart';
import '../../domain/band_representative_contact_policy.dart';
import '../cubit/profile_media_cubit.dart';
import 'band_management_panel_screen.dart';
import 'band_profile_calendar_slot.dart';
import 'profile_common_widgets.dart';
import 'profile_count_row.dart';
import 'profile_audio_transport.dart';
import 'profile_media_tabs.dart';
import 'profile_owner_video_tab.dart';
import 'profile_screen_support.dart';
import 'profile_section_support.dart';
import 'profile_social_support.dart';
import 'profile_track_upload_support.dart';
import 'profile_route_args.dart';

part 'band_profile_screen_header_sections.dart';
part 'band_profile_screen_audio_tab.dart';
part 'band_profile_screen_audio_tab_methods.dart';
part 'band_profile_screen_audio_tab_spotify_dialogs.dart';
part 'band_profile_screen_audio_tab_spotify_picker.dart';
part 'band_profile_screen_actions.dart';
part 'band_profile_screen_social_sections.dart';

enum BandProfileViewMode { auto, member, public }

class BandProfileScreenArgs {
  final String bandId;
  final bool openEditMode;
  final BandProfileViewMode viewMode;

  BandProfileScreenArgs({
    required this.bandId,
    this.openEditMode = false,
    this.viewMode = BandProfileViewMode.auto,
  });
}

class BandProfileScreen extends StatelessWidget {
  BandProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => serviceLocator<ProfileMediaCubit>()),
        BlocProvider(create: (_) => serviceLocator<InteractionStatsCubit>()),
      ],
      child: _BandProfileView(),
    );
  }
}

class _BandProfileView extends StatefulWidget {
  _BandProfileView();

  @override
  State<_BandProfileView> createState() => _BandProfileViewState();
}

class _BandProfileViewState extends State<_BandProfileView> {
  late final TokenStore _tokenStore = serviceLocator<TokenStore>();
  late final BandRepository _bandRepository = serviceLocator<BandRepository>();
  late final MusicianProfileRepository _musicianProfileRepository =
      serviceLocator<MusicianProfileRepository>();
  late final MusicianSearchRepository _musicianSearchRepository =
      serviceLocator<MusicianSearchRepository>();
  late final ArtistVenueConnectionRepository _artistVenueRepository =
      serviceLocator<ArtistVenueConnectionRepository>();
  late final BandFollowRepository _bandFollowRepository =
      serviceLocator<BandFollowRepository>();
  late final SpotifyRepository _spotifyRepository =
      serviceLocator<SpotifyRepository>();
  final ImagePicker _imagePicker = ImagePicker();
  BandProfile? _profile;
  List<SpotifyTrackPreview> _spotifyTracks = [];
  int? _followersCount;
  bool _isFollowingBand = false;
  bool _loading = true;
  bool _photoUploading = false;
  bool _bandFollowLoading = false;
  bool _spotifyLoading = false;
  String? _errorText;
  String? _uploadedProfilePhotoUrl;
  String? _bandId;
  BandProfileViewMode _viewMode = BandProfileViewMode.auto;
  String? _currentUserId;
  List<VenueConnection> _activeVenues = [];
  final Map<String, String> _resolvedMemberProfileIdsByUserId =
      <String, String>{};
  final Map<String, String> _resolvedMemberAvatarUrlsByUserId =
      <String, String>{};
  final Set<String> _resolvingMemberUserIds = <String>{};

  void _updateState(VoidCallback updater) {
    if (!mounted) return;
    setState(updater);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final routeName = ModalRoute.of(context)?.settings.name ?? '';
    final args = ModalRoute.of(context)?.settings.arguments;
    String? nextBandId;
    BandProfileViewMode nextMode = _modeFromRouteName(routeName);
    if (args is BandProfileScreenArgs) {
      nextBandId = args.bandId;
      nextMode = args.viewMode;
    } else if (args is Map<String, dynamic>) {
      nextBandId = args['bandId']?.toString();
      nextMode = _modeFromRaw(args['viewMode']) ?? nextMode;
    } else if (args is String) {
      nextBandId = args;
    }
    if (nextBandId == null ||
        nextBandId.isEmpty ||
        (_bandId == nextBandId && _viewMode == nextMode)) {
      return;
    }
    _bandId = nextBandId;
    _viewMode = nextMode;
    unawaited(_resolveCurrentUserId());
    _loadBandProfile();
  }

  bool get _canManageBand {
    if (_viewMode == BandProfileViewMode.public ||
        _viewMode == BandProfileViewMode.member) {
      return false;
    }
    final profile = _profile;
    final currentUserId = (_currentUserId ?? '').trim();
    if (profile == null || currentUserId.isEmpty) return false;
    for (final member in profile.members) {
      if (member.userId.trim() == currentUserId) {
        return member.isFounder &&
            member.status.trim().toUpperCase() == 'ACTIVE';
      }
    }
    return false;
  }

  BandProfileViewMode _modeFromRouteName(String routeName) {
    if (routeName == AppRoutes.bandPublicProfile) {
      return BandProfileViewMode.public;
    }
    if (routeName == AppRoutes.bandMemberProfile) {
      return BandProfileViewMode.member;
    }
    return BandProfileViewMode.auto;
  }

  BandProfileViewMode? _modeFromRaw(Object? raw) {
    if (raw is BandProfileViewMode) return raw;
    final value = raw?.toString().trim().toLowerCase() ?? '';
    switch (value) {
      case 'public':
        return BandProfileViewMode.public;
      case 'member':
        return BandProfileViewMode.member;
      case 'auto':
        return BandProfileViewMode.auto;
      default:
        return null;
    }
  }

  Future<void> _resolveCurrentUserId() async {
    final token = (await _tokenStore.readToken())?.trim() ?? '';
    if (token.isEmpty) {
      _updateState(() => _currentUserId = null);
      return;
    }
    String? resolved;
    final parts = token.split('.');
    if (parts.length >= 2) {
      try {
        final payload = utf8.decode(
          base64Url.decode(base64Url.normalize(parts[1])),
        );
        final json = jsonDecode(payload);
        if (json is Map<String, dynamic>) {
          final candidates = <String?>[
            json['userId']?.toString(),
            json['uid']?.toString(),
            json['id']?.toString(),
            json['sub']?.toString(),
          ];
          for (final value in candidates) {
            final normalized = value?.trim() ?? '';
            if (normalized.isNotEmpty) {
              resolved = normalized;
              break;
            }
          }
        }
      } catch (_) {}
    }
    _updateState(() => _currentUserId = resolved);
    final profile = _profile;
    if (profile != null) {
      unawaited(_loadBandFollowStatus(profile.id));
    }
  }

  bool _isCurrentUserActiveBandMember(BandProfile profile) {
    final userId = (_currentUserId ?? '').trim();
    if (userId.isEmpty) return false;
    return profile.members.any(
      (member) =>
          member.userId.trim() == userId &&
          member.status.trim().toUpperCase() == 'ACTIVE',
    );
  }

  Widget _buildBandActionButtons(BandProfile profile) {
    if (_canManageBand || _isCurrentUserActiveBandMember(profile)) {
      return SizedBox.shrink();
    }

    final hasViewer = (_currentUserId ?? '').trim().isNotEmpty;
    final representative = BandRepresentativeContactPolicy.resolve(
      profile.members,
    );
    if (!hasViewer || representative == null) {
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: 32),
        child: Center(
          child: GradientOutlineButton(
            label: _bandFollowLoading
                ? 'Bekle...'
                : (_isFollowingBand ? 'Takip Ediliyor' : 'Takip Et'),
            loading: _bandFollowLoading,
            leading: Icon(
              _isFollowingBand
                  ? Icons.check_circle_outline
                  : Icons.person_add_alt_1,
              size: 18,
            ),
            onPressed: hasViewer && !_bandFollowLoading
                ? () => _toggleBandFollow(profile.id)
                : null,
          ),
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 32),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: !_bandFollowLoading
                  ? () => _toggleBandFollow(profile.id)
                  : null,
              style: OutlinedButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.onSurface,
                side: BorderSide(color: Theme.of(context).dividerColor),
                padding: EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              child: Text(
                _bandFollowLoading
                    ? 'Bekle...'
                    : (_isFollowingBand ? 'Takip Ediliyor' : 'Takip Et'),
              ),
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: GradientOutlineButton(
              key: const ValueKey<String>('band-profile-message-action'),
              label: 'Mesaj Gönder',
              onPressed: () {
                unawaited(
                  openBandRepresentativeConversation(
                    context,
                    bandName: profile.name,
                    contactUserId: representative.userId,
                    contactUsername: representative.username,
                  ),
                );
              },
              backgroundColor: Theme.of(
                context,
              ).colorScheme.surfaceContainerHighest,
              horizontalPadding: 12,
              strokeWidth: 0.7,
              leading: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_profile == null) {
      return Scaffold(
        appBar: AppBar(title: Text('Band Profili')),
        body: Center(child: Text(_errorText ?? 'Band profili getirilemedi.')),
      );
    }

    final profile = _profile!;
    final mediaState = context.watch<ProfileMediaCubit>().state;
    final media =
        mediaState.media ??
        ProfileMedia(featuredVideo: null, videos: [], audios: []);
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: GradientText(
            text: 'SoundConnect',
            gradient: LinearGradient(colors: AppColors.brandGradient),
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
          ),
          centerTitle: true,
        ),
        body: RefreshIndicator(
          onRefresh: () => _loadBandProfile(showLoading: false),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ProfileTopSection(
                  header: _BandHeader(
                    profile: profile,
                    uploadedPhotoUrl: _uploadedProfilePhotoUrl,
                    uploading: _photoUploading,
                    onEditPhoto: _canManageBand ? _editProfilePhoto : null,
                  ),
                  identity: ProfileIdentityHeader(
                    username: profile.name,
                    secondaryText: _memberHeadline(profile.members),
                    fallbackName: 'Band',
                  ),
                  followerSummary: ProfileFollowerSummary(
                    followersCount: _followersCount,
                    followingCount: null,
                    followersLabel: 'Takipçi',
                    followingLabel: 'Takip',
                    showFollowing: false,
                  ),
                  actionButtons: _buildBandActionButtons(profile),
                  bioSection: EditableBioSection(
                    bio: profile.description,
                    editable: _canManageBand,
                    onSave: _saveDescription,
                    emptyText: 'Henüz bir açıklama eklenmedi.',
                    addLabel: 'Profiline birkaç cümle ekle',
                    hintText: 'Bandinden bahset...',
                  ),
                  afterBio: _canManageBand
                      ? Padding(
                          padding: EdgeInsets.symmetric(horizontal: 28),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(18),
                              gradient: LinearGradient(
                                colors: AppColors.brandGradient,
                              ),
                            ),
                            child: Padding(
                              padding: EdgeInsets.all(0.7),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(18),
                                child: Container(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.surfaceContainerHighest,
                                  child: TextButton.icon(
                                    onPressed: () =>
                                        _openBandManagementPanel(context),
                                    style: TextButton.styleFrom(
                                      foregroundColor: AppColors.white,
                                      backgroundColor: Colors.transparent,
                                      padding: EdgeInsets.symmetric(
                                        vertical: 14,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(18),
                                      ),
                                    ),
                                    icon: Icon(
                                      Icons.dashboard_customize_outlined,
                                      color: AppColors.white,
                                    ),
                                    label: Text(
                                      'Yonetim Paneli',
                                      style: TextStyle(color: AppColors.white),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        )
                      : SizedBox.shrink(),
                ),
                SizedBox(height: 18),
                ProfileSectionHeader(
                  title: 'Uyeler',
                  actionLabel: profile.members.isEmpty ? null : 'Tumu',
                ),
                _BandMembersRow(
                  items: profile.members,
                  avatarUrlOf: _effectiveMemberAvatar,
                  onOpenMember: _openMemberProfile,
                ),
                SizedBox(height: 12),
                ProfileSectionHeader(
                  title: 'Caldigi Mekanlar',
                  actionLabel: 'Tumu',
                ),
                _BandVenuesRow(items: _activeVenues),
                BandProfileCalendarSlot(
                  bandId: profile.id,
                  refreshToken: profile,
                  compactTitle: !_canManageBand,
                ),
                SizedBox(height: 12),
                ProfileMediaTabs(
                  tabs: [
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
                SizedBox(
                  height: 460,
                  child: TabBarView(
                    children: [
                      _BandAudioTab(
                        profile: profile,
                        items: media.audios,
                        spotifyTracks: _spotifyTracks,
                        spotifyLoading: _spotifyLoading,
                        editable: _canManageBand,
                        onSaveSpotifyTracks: _saveSpotifyTracks,
                      ),
                      ProfileOwnerVideoTab(
                        items: [
                          if (media.featuredVideo != null) media.featuredVideo!,
                          ...media.videos.where(
                            (item) =>
                                media.featuredVideo == null ||
                                item.id != media.featuredVideo!.id,
                          ),
                        ],
                        profileId: profile.id,
                        ownerMode: _canManageBand,
                        profileType: 'BAND',
                        uploadOwnerType: 'BAND',
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 18),
                _BandSocialButtonRow(
                  profile: profile,
                  editable: _canManageBand,
                  onAddLink: _canManageBand ? _addSocialLink : null,
                ),
                SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
