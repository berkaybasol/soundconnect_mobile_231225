import 'dart:convert';
import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:soundconnect_23_12_25codx/shared/widgets/app_snack_bar.dart';
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
import '../../../../shared/widgets/profile_brand_title.dart';
import '../../../../shared/widgets/waveform_stub.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../core/auth/token_store.dart';
import '../../../../core/auth/auth_session_manager.dart';
import '../../domain/band_repository.dart';
import '../../domain/entities/band_member_summary.dart';
import '../../domain/entities/band_profile.dart';
import '../../domain/entities/profile_media.dart';
import '../../domain/entities/profile_venue_models.dart';
import '../../domain/musician_calendar_repository.dart';
import '../../../../shared/widgets/brand_gradient_icon.dart';
import '../../../artist_venue/domain/artist_venue_connection_repository.dart';
import '../../../dm/presentation/band_representative_conversation.dart';
import '../../../engagement/presentation/cubit/interaction_stats_cubit.dart';
import '../../../follow/domain/band_follow_repository.dart';
import '../../../spotify/domain/entities/spotify_track_preview.dart';
import '../../../spotify/domain/spotify_repository.dart';
import '../../domain/band_representative_contact_policy.dart';
import '../cubit/profile_media_cubit.dart';
import '../navigation/band_member_profile_resolver.dart';
import 'band_management_panel_screen.dart';
import 'band_profile_calendar_slot.dart';
import 'profile_common_widgets.dart';
import 'profile_carousels.dart';
import 'profile_mini_card.dart';
import 'profile_count_row.dart';
import 'profile_audio_transport.dart';
import 'profile_media_tabs.dart';
import 'profile_owner_video_tab.dart';
import 'profile_screen_support.dart';
import 'profile_section_support.dart';
import 'profile_social_support.dart';
import 'profile_track_upload_support.dart';

part 'band_profile_screen_header_sections.dart';
part 'band_profile_screen_audio_tab.dart';
part 'band_profile_screen_audio_tab_methods.dart';
part 'band_profile_screen_audio_tab_spotify_dialogs.dart';
part 'band_profile_screen_audio_tab_spotify_picker.dart';
part 'band_profile_screen_actions.dart';
part 'band_profile_screen_membership.dart';
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
  late final BandMemberProfileResolver _memberProfileResolver =
      BandMemberProfileResolver();
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
  bool _leavingBand = false;
  bool _leaveRequestPending = false;
  int _profileLoadGeneration = 0;
  AuthSessionManager? _membershipSessionManager;
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
  void initState() {
    super.initState();
    _membershipSessionManager =
        serviceLocator.isRegistered<AuthSessionManager>()
        ? serviceLocator<AuthSessionManager>()
        : null;
    _membershipSessionManager?.addListener(_membershipSessionChanged);
  }

  @override
  void dispose() {
    ++_profileLoadGeneration;
    _membershipSessionManager?.removeListener(_membershipSessionChanged);
    super.dispose();
  }

  void _membershipSessionChanged() {
    if (!mounted) return;
    ++_profileLoadGeneration;
    _updateState(() {
      final session = _membershipSessionManager?.session;
      _currentUserId =
          session != null && session.isAuthenticated && session.isActive
          ? session.userId
          : null;
      _profile = null;
      _loading = false;
      _errorText = 'Oturum değişti. Bu sayfayı yeniden aç.';
    });
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
    if (_membershipSessionManager != null) {
      final session = _membershipSessionManager!.session;
      _updateState(() {
        _currentUserId = session.isAuthenticated && session.isActive
            ? session.userId
            : null;
      });
      return;
    }
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
    if (_canLeaveBand(profile)) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: GradientOutlineButton(
          key: const Key('band-profile-leave-action'),
          label: 'Gruptan ayrıl',
          leading: const Icon(Icons.logout_rounded, size: 18),
          strokeWidth: .7,
          horizontalPadding: 16,
          loading: _leaveRequestPending,
          onPressed: _leavingBand ? null : _leaveBand,
        ),
      );
    }
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
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _errorText ?? 'Band profili getirilemedi.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                GradientOutlineButton(
                  key: const Key('band-profile-load-retry'),
                  label: 'Tekrar dene',
                  onPressed: _loadBandProfile,
                  strokeWidth: .7,
                ),
              ],
            ),
          ),
        ),
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
        appBar: AppBar(title: const ProfileBrandTitle(), centerTitle: true),
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
                                      'Yönetim Paneli',
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
                  title: 'Üyeler',
                  actionLabel: profile.members.isEmpty ? null : 'Tümü',
                ),
                _BandMembersRow(
                  items: profile.members,
                  avatarUrlOf: _effectiveMemberAvatar,
                  onOpenMember: _openMemberProfile,
                ),
                SizedBox(height: 12),
                ProfileSectionHeader(
                  title: 'Çaldığı Mekanlar',
                  actionLabel: 'Tümü',
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
                          Flexible(
                            child: Text(
                              'Sesler',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.play_circle_outline, size: 18),
                          SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              'Video',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
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
