import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/audio/audio_player_handler.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/widgets/gradient_text.dart';
import '../../../../shared/widgets/waveform_stub.dart';
import '../../domain/band_repository.dart';
import '../../domain/entities/band_member_summary.dart';
import '../../domain/entities/band_profile.dart';
import '../../domain/entities/profile_media.dart';
import '../../../follow/domain/band_follow_repository.dart';
import '../../../spotify/domain/entities/spotify_track_preview.dart';
import '../../../spotify/domain/spotify_repository.dart';
import '../cubit/profile_media_cubit.dart';
import 'band_management_panel_screen.dart';
import 'profile_common_widgets.dart';
import 'profile_count_row.dart';
import 'profile_audio_transport.dart';
import 'profile_media_tabs.dart';
import 'profile_owner_video_tab.dart';
import 'profile_screen_support.dart';
import 'profile_section_support.dart';
import 'profile_social_support.dart';
import 'profile_track_upload_support.dart';

class BandProfileScreenArgs {
  final String bandId;
  final bool openEditMode;

  const BandProfileScreenArgs({
    required this.bandId,
    this.openEditMode = false,
  });
}

class BandProfileScreen extends StatelessWidget {
  const BandProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => serviceLocator<ProfileMediaCubit>(),
      child: const _BandProfileView(),
    );
  }
}

class _BandProfileView extends StatefulWidget {
  const _BandProfileView();

  @override
  State<_BandProfileView> createState() => _BandProfileViewState();
}

class _BandProfileViewState extends State<_BandProfileView> {
  late final BandRepository _bandRepository = serviceLocator<BandRepository>();
  late final BandFollowRepository _bandFollowRepository =
      serviceLocator<BandFollowRepository>();
  late final SpotifyRepository _spotifyRepository =
      serviceLocator<SpotifyRepository>();
  final ImagePicker _imagePicker = ImagePicker();
  BandProfile? _profile;
  List<SpotifyTrackPreview> _spotifyTracks = const [];
  int? _followersCount;
  bool _loading = true;
  bool _photoUploading = false;
  bool _spotifyLoading = false;
  String? _errorText;
  String? _uploadedProfilePhotoUrl;
  String? _bandId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    final resolvedArgs = args is BandProfileScreenArgs ? args : null;
    final nextBandId = resolvedArgs?.bandId;
    if (nextBandId == null || nextBandId.isEmpty || _bandId == nextBandId) {
      return;
    }
    _bandId = nextBandId;
    _loadBandProfile();
  }

  Future<void> _loadBandProfile() async {
    final bandId = _bandId;
    if (bandId == null || bandId.isEmpty) return;

    setState(() {
      _loading = true;
      _errorText = null;
    });

    final result = await _bandRepository.getBandById(bandId);

    if (!mounted) return;

    if (!result.isSuccess || result.data == null) {
      setState(() {
        _loading = false;
        _errorText = result.error?.message ?? 'Band profili getirilemedi.';
      });
      return;
    }

    setState(() {
      _loading = false;
      _profile = result.data;
    });

    await _loadFollowersCount(result.data!.id);
    await _loadSpotifyCatalog(result.data!);
    if (!mounted) return;
    await context.read<ProfileMediaCubit>().loadMedia(
      profileType: 'BAND',
      profileId: result.data!.id,
    );
  }

  Future<void> _loadSpotifyCatalog(BandProfile profile) async {
    final trackIds = profile.spotifyTrackIds;
    if (trackIds.isEmpty) {
      if (!mounted) return;
      setState(() {
        _spotifyLoading = false;
        _spotifyTracks = const [];
      });
      return;
    }

    setState(() => _spotifyLoading = true);
    final result = await _spotifyRepository.getTracksByIds(trackIds);
    if (!mounted) return;

    setState(() {
      _spotifyLoading = false;
      _spotifyTracks = result.isSuccess && result.data != null
          ? result.data!
          : const [];
    });
  }

  Future<void> _loadFollowersCount(String bandId) async {
    final result = await _bandFollowRepository.getFollowersCount(bandId);
    if (!mounted) return;
    setState(() {
      _followersCount = result.data;
    });
  }

  Future<bool> _saveSpotifyTracks(
    List<SpotifyTrackPreview> nextTracks, {
    required String failureMessage,
  }) async {
    final profile = _profile;
    if (profile == null) return false;

    final result = await _bandRepository.updateBand(
      bandId: profile.id,
      spotifyTrackIds: nextTracks.map((track) => track.id).toList(),
    );

    if (!mounted) return false;

    if (!result.isSuccess || result.data == null) {
      final message = result.error?.message ?? failureMessage;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
      return false;
    }

    setState(() {
      _profile = result.data;
      _spotifyTracks = nextTracks;
    });
    return true;
  }

  Future<void> _saveDescription(String value) async {
    final profile = _profile;
    if (profile == null) return;

    final result = await _bandRepository.updateBand(
      bandId: profile.id,
      description: value.trim(),
    );

    if (!mounted) return;

    if (!result.isSuccess || result.data == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.error?.message ?? 'Aciklama kaydedilemedi.'),
        ),
      );
      return;
    }

    setState(() {
      _profile = result.data;
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Aciklama guncellendi.')));
  }

  Future<void> _editProfilePhoto() async {
    final profile = _profile;
    if (profile == null) return;

    setState(() => _photoUploading = true);
    try {
      final uploaded = await pickCropAndUploadProfilePhoto(
        context: context,
        imagePicker: _imagePicker,
        ownerType: 'BAND',
        ownerId: profile.id,
      );
      if (uploaded == null) return;

      final result = await _bandRepository.updateBand(
        bandId: profile.id,
        profilePicture: uploaded.assetId,
      );

      if (!mounted) return;

      if (!result.isSuccess || result.data == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result.error?.message ?? 'Profil fotografi guncellenemedi.',
            ),
          ),
        );
        return;
      }

      setState(() {
        _profile = result.data;
        _uploadedProfilePhotoUrl = uploaded.preferredUrl;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profil fotografi guncellendi.')),
      );
    } finally {
      if (mounted) {
        setState(() => _photoUploading = false);
      }
    }
  }

  Future<void> _addSocialLink(ProfileSocialPlatform platform) async {
    final profile = _profile;
    if (profile == null) return;

    final normalized = await promptForSocialLink(
      context,
      platform: platform,
      initialValue: _socialUrlFor(profile, platform)?.trim() ?? '',
    );
    if (normalized == null) return;

    final result = await _bandRepository.updateBand(
      bandId: profile.id,
      instagramUrl: platform == ProfileSocialPlatform.instagram
          ? normalized
          : null,
      youtubeUrl: platform == ProfileSocialPlatform.youtube ? normalized : null,
      soundCloudUrl: platform == ProfileSocialPlatform.soundcloud
          ? normalized
          : null,
      spotifyEmbedUrl: platform == ProfileSocialPlatform.spotify
          ? normalized
          : null,
    );

    if (!mounted) return;

    if (!result.isSuccess || result.data == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.error?.message ?? 'Sosyal link kaydedilemedi.'),
        ),
      );
      return;
    }

    setState(() {
      _profile = result.data;
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('${platform.label} guncellendi.')));
  }

  Future<void> _openBandManagementPanel(BuildContext context) async {
    final profile = _profile;
    if (profile == null) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BandManagementPanelScreen(profile: profile),
      ),
    );
  }

  String? _socialUrlFor(BandProfile profile, ProfileSocialPlatform platform) {
    switch (platform) {
      case ProfileSocialPlatform.soundcloud:
        return profile.soundCloudUrl;
      case ProfileSocialPlatform.instagram:
        return profile.instagramUrl;
      case ProfileSocialPlatform.youtube:
        return profile.youtubeUrl;
      case ProfileSocialPlatform.spotify:
        return profile.spotifyEmbedUrl;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_profile == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Band Profili')),
        body: Center(child: Text(_errorText ?? 'Band profili getirilemedi.')),
      );
    }

    final profile = _profile!;
    final mediaState = context.watch<ProfileMediaCubit>().state;
    final media =
        mediaState.media ??
        const ProfileMedia(featuredVideo: null, videos: [], audios: []);
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const GradientText(
            text: 'SoundConnect',
            gradient: LinearGradient(colors: AppColors.brandGradient),
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
          ),
          centerTitle: true,
        ),
        body: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ProfileTopSection(
                header: _BandHeader(
                  profile: profile,
                  uploadedPhotoUrl: _uploadedProfilePhotoUrl,
                  uploading: _photoUploading,
                  onEditPhoto: _editProfilePhoto,
                ),
                identity: ProfileIdentityHeader(
                  username: profile.name,
                  secondaryText: _memberHeadline(profile.members),
                  fallbackName: 'Band',
                ),
                followerSummary: ProfileFollowerSummary(
                  followersCount: _followersCount,
                  followingCount: null,
                  followersLabel: 'Takipci',
                  followingLabel: 'Takip',
                  showFollowing: false,
                ),
                actionButtons: const SizedBox.shrink(),
                bioSection: EditableBioSection(
                  bio: profile.description,
                  editable: true,
                  onSave: _saveDescription,
                  emptyText: 'Henüz bir aciklama eklenmedi.',
                  addLabel: 'Aciklama ekle',
                  hintText: 'Bandinden bahset...',
                ),
                afterBio: Padding(
                  //eklendi
                  padding: const EdgeInsets.symmetric(horizontal: 28), //eklendi
                  child: DecoratedBox(
                    //eklendi
                    decoration: BoxDecoration(
                      //eklendi
                      borderRadius: BorderRadius.circular(18), //eklendi
                      gradient: const LinearGradient(
                        //eklendi
                        colors: AppColors.brandGradient, //eklendi
                      ), //eklendi
                    ), //eklendi
                    child: Padding(
                      //eklendi
                      padding: const EdgeInsets.all(0.7), //eklendi
                      child: ClipRRect(
                        //eklendi
                        borderRadius: BorderRadius.circular(18), //eklendi
                        child: Container(
                          //eklendi
                          color: AppColors.inputFill, //eklendi
                          child: TextButton.icon(
                            //eklendi
                            onPressed: () =>
                                _openBandManagementPanel(context), //eklendi
                            style: TextButton.styleFrom(
                              //eklendi
                              foregroundColor: AppColors.white, //eklendi
                              backgroundColor: Colors.transparent, //eklendi
                              padding: const EdgeInsets.symmetric(
                                //eklendi
                                vertical: 14, //eklendi
                              ), //eklendi
                              shape: RoundedRectangleBorder(
                                //eklendi
                                borderRadius: BorderRadius.circular(
                                  18,
                                ), //eklendi
                              ), //eklendi
                            ), //eklendi
                            icon: const Icon(
                              //eklendi
                              Icons.dashboard_customize_outlined, //eklendi
                              color: AppColors.white, //eklendi
                            ), //eklendi
                            label: const Text(
                              //eklendi
                              'Yonetim Paneli', //eklendi
                              style: TextStyle(
                                color: AppColors.white,
                              ), //eklendi
                            ), //eklendi
                          ), //eklendi
                        ), //eklendi
                      ), //eklendi
                    ), //eklendi
                  ), //eklendi
                ), //eklendi
              ),
              const SizedBox(height: 18),
              ProfileSectionHeader(
                title: 'Uyeler',
                actionLabel: profile.members.isEmpty ? null : 'Tumü',
              ),
              _BandMembersRow(items: profile.members),
              const SizedBox(height: 12),
              const ProfileSectionHeader(
                title: 'Caldigi Mekanlar',
                actionLabel: 'Tumu',
              ),
              const _BandVenuesRow(items: []),
              const SizedBox(height: 12),
              const ProfileMediaTabs(
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
                      ownerMode: true,
                      profileType: 'BAND',
                      uploadOwnerType: 'BAND',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              _BandSocialButtonRow(
                profile: profile,
                editable: true,
                onAddLink: _addSocialLink,
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  String? _memberHeadline(List<BandMemberSummary> members) {
    if (members.isEmpty) return null;
    if (members.length == 1) return members.first.username;
    return '${members.first.username} +${members.length - 1}';
  }
}

class _BandHeader extends StatelessWidget {
  final BandProfile profile;
  final String? uploadedPhotoUrl;
  final bool uploading;
  final VoidCallback onEditPhoto;

  const _BandHeader({
    required this.profile,
    required this.uploadedPhotoUrl,
    required this.uploading,
    required this.onEditPhoto,
  });

  @override
  Widget build(BuildContext context) {
    final imageUrl = uploadedPhotoUrl?.trim().isNotEmpty == true
        ? uploadedPhotoUrl!.trim()
        : profile.profilePictureUrl?.trim();

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: SizedBox(
        width: 104,
        height: 104,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Container(
              width: 104,
              height: 104,
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
                child: imageUrl != null && imageUrl.isNotEmpty
                    ? Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.groups_2_outlined,
                          color: AppColors.textMuted,
                          size: 42,
                        ),
                      )
                    : const Icon(
                        Icons.groups_2_outlined,
                        color: AppColors.textMuted,
                        size: 42,
                      ),
              ),
            ),
            Positioned(
              right: -4,
              bottom: -4,
              child: InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: uploading ? null : onEditPhoto,
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: AppColors.brandGradient,
                    ),
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.navBlueDeep, width: 2),
                  ),
                  child: uploading
                      ? const Padding(
                          padding: EdgeInsets.all(8),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(
                          Icons.edit_outlined,
                          size: 16,
                          color: Colors.white,
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BandMembersRow extends StatelessWidget {
  final List<BandMemberSummary> items;

  const _BandMembersRow({required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 20),
        child: Text(
          'Bandde henuz uye gorunmuyor.',
          style: TextStyle(color: AppColors.textMuted),
        ),
      );
    }

    return SizedBox(
      height: 72,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        itemBuilder: (context, index) {
          final item = items[index];
          return Container(
            width: 168,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.inputFill,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: AppColors.navBlueSoft,
                  backgroundImage:
                      item.profilePictureUrl?.trim().isNotEmpty == true
                      ? NetworkImage(item.profilePictureUrl!.trim())
                      : null,
                  child: item.profilePictureUrl?.trim().isNotEmpty == true
                      ? null
                      : const Icon(
                          Icons.person_outline,
                          color: AppColors.textMuted,
                        ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.username,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.role,
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
              ],
            ),
          );
        },
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemCount: items.length,
      ),
    );
  }
}

class _BandVenuesRow extends StatelessWidget {
  final List<String> items;

  const _BandVenuesRow({required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        child: Text(
          'Henuz bir mekan eklenmedi.',
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
                  child: GradientText(
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

class _BandAudioTab extends StatelessWidget {
  final BandProfile profile;
  final List<dynamic> items;
  final List<SpotifyTrackPreview> spotifyTracks;
  final bool spotifyLoading;
  final Future<bool> Function(
    List<SpotifyTrackPreview> nextTracks, {
    required String failureMessage,
  })
  onSaveSpotifyTracks;

  const _BandAudioTab({
    required this.profile,
    required this.items,
    required this.spotifyTracks,
    required this.spotifyLoading,
    required this.onSaveSpotifyTracks,
  });

  Future<SpotifyTrackPreview?> _showSpotifyTrackPicker(
    BuildContext context,
    List<SpotifyTrackPreview> currentTracks,
  ) async {
    final queryController = TextEditingController();
    final repository = serviceLocator<SpotifyRepository>();
    Timer? searchDebounce;
    int lastSearchToken = 0;
    final selected = await showModalBottomSheet<SpotifyTrackPreview>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.navBlueDeep,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        var loading = false;
        var results = <SpotifyTrackPreview>[];
        var errorText = '';

        return StatefulBuilder(
          builder: (context, setSheetState) {
            Future<void> runSearch() async {
              final query = queryController.text.trim();
              final token = ++lastSearchToken;
              if (query.length < 2) {
                setSheetState(() {
                  results = const [];
                  errorText = 'En az 2 karakter yaz.';
                });
                return;
              }

              setSheetState(() {
                loading = true;
                errorText = '';
              });

              final result = await repository.searchTracks(query, limit: 10);
              if (!sheetContext.mounted || token != lastSearchToken) return;

              setSheetState(() {
                loading = false;
                if (result.isSuccess && result.data != null) {
                  results = result.data!;
                  if (results.isEmpty) {
                    errorText = 'Sonuc bulunamadi.';
                  }
                } else {
                  errorText = result.error?.message ?? 'Arama basarisiz.';
                }
              });
            }

            final existingIds = currentTracks.map((track) => track.id).toSet();

            return AnimatedPadding(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: SafeArea(
                top: false,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.78,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                    child: Column(
                      children: [
                        TextField(
                          controller: queryController,
                          textInputAction: TextInputAction.search,
                          onSubmitted: (_) => runSearch(),
                          onChanged: (value) {
                            searchDebounce?.cancel();
                            if (value.trim().length >= 2) {
                              searchDebounce = Timer(
                                const Duration(milliseconds: 320),
                                runSearch,
                              );
                            } else {
                              setSheetState(() {
                                results = const [];
                                errorText = '';
                              });
                            }
                          },
                          decoration: InputDecoration(
                            hintText: 'Spotify parcasi ara...',
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon: IconButton(
                              onPressed: runSearch,
                              icon: const Icon(Icons.arrow_forward),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (loading) ...[
                          const LinearProgressIndicator(minHeight: 2),
                          const SizedBox(height: 12),
                        ],
                        if (!loading && errorText.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(
                              errorText,
                              style: const TextStyle(
                                color: AppColors.textMuted,
                              ),
                            ),
                          ),
                        Expanded(
                          child: ListView.separated(
                            itemCount: results.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final track = results[index];
                              final alreadyAdded = existingIds.contains(
                                track.id,
                              );
                              return Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppColors.inputFill,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            track.name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: alreadyAdded
                                                  ? AppColors.textMuted
                                                  : AppColors.textPrimary,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(height: 3),
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
                                    if (alreadyAdded)
                                      const Text(
                                        'Eklendi',
                                        style: TextStyle(
                                          color: AppColors.textMuted,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      )
                                    else
                                      IconButton(
                                        onPressed: () => Navigator.of(
                                          sheetContext,
                                        ).pop(track),
                                        icon: const Icon(
                                          Icons.add_circle_outline,
                                          color: AppColors.coralAlt,
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
                ),
              ),
            );
          },
        );
      },
    );
    searchDebounce?.cancel();
    return selected;
  }

  Future<void> _openExternalUrl(BuildContext context, String? url) async {
    final trimmed = url?.trim();
    if (trimmed == null || trimmed.isEmpty) return;
    final normalized = trimmed.contains('://') ? trimmed : 'https://$trimmed';
    final uri = Uri.tryParse(normalized);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _showSpotifyCatalog(BuildContext context) async {
    final visibleTracks = List<SpotifyTrackPreview>.from(spotifyTracks);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.navBlueDeep,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        String? feedbackText;
        bool feedbackIsError = false;
        return StatefulBuilder(
          builder: (context, setSheetState) {
            Future<void> addTrack() async {
              final selected = await _showSpotifyTrackPicker(
                context,
                visibleTracks,
              );
              if (selected == null || !sheetContext.mounted) return;
              if (visibleTracks.any((track) => track.id == selected.id)) {
                setSheetState(() {
                  feedbackText = 'Bu parca zaten ekli.';
                  feedbackIsError = true;
                });
                return;
              }
              final nextTracks = [...visibleTracks, selected];
              final ok = await onSaveSpotifyTracks(
                nextTracks,
                failureMessage: 'Spotify parcasi eklenemedi.',
              );
              if (!ok || !sheetContext.mounted) return;
              setSheetState(() {
                visibleTracks
                  ..clear()
                  ..addAll(nextTracks);
                feedbackText = 'Spotify parcasi eklendi.';
                feedbackIsError = false;
              });
            }

            Future<void> removeTrack(SpotifyTrackPreview track) async {
              final nextTracks = visibleTracks
                  .where((item) => item.id != track.id)
                  .toList();
              final ok = await onSaveSpotifyTracks(
                nextTracks,
                failureMessage: 'Spotify parcasi kaldirilamadi.',
              );
              if (!ok || !sheetContext.mounted) return;
              setSheetState(() {
                visibleTracks
                  ..clear()
                  ..addAll(nextTracks);
                feedbackText = 'Spotify parcasi kaldirildi.';
                feedbackIsError = false;
              });
            }

            final hasEmbed = profile.spotifyEmbedUrl?.trim().isNotEmpty == true;

            return FractionallySizedBox(
              heightFactor: 0.88,
              child: SafeArea(
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
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Band Spotify Katalogu',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Spotify parcasi ekle',
                            onPressed: addTrack,
                            icon: const Icon(
                              Icons.add_circle_outline,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.inputFill,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: AppColors.navBlueSoft,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(
                                Icons.album_outlined,
                                color: AppColors.coralAlt,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Spotify katalogu',
                                    style: TextStyle(
                                      color: AppColors.textPrimary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    hasEmbed
                                        ? 'Embed baglantisi hazir.'
                                        : 'Spotify embed baglantisi eklenmemis.',
                                    style: const TextStyle(
                                      color: AppColors.textMuted,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (feedbackText != null) ...[
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 9,
                          ),
                          decoration: BoxDecoration(
                            color: feedbackIsError
                                ? const Color(0xFF3A1F1F)
                                : AppColors.inputFill,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: feedbackIsError
                                  ? const Color(0xFF8B3A3A)
                                  : AppColors.border,
                            ),
                          ),
                          child: Text(
                            feedbackText!,
                            style: TextStyle(
                              color: feedbackIsError
                                  ? const Color(0xFFFFB4B4)
                                  : AppColors.textMuted,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Flexible(
                        child: visibleTracks.isEmpty
                            ? const Center(
                                child: Text(
                                  'Henuz Spotify parcasi eklenmedi.',
                                  style: TextStyle(color: AppColors.textMuted),
                                ),
                              )
                            : ListView.separated(
                                itemCount: visibleTracks.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 10),
                                itemBuilder: (context, index) {
                                  final track = visibleTracks[index];
                                  final albumArtUrl =
                                      isValidNetworkImageUrl(
                                        track.albumImageUrl,
                                      )
                                      ? track.albumImageUrl!.trim()
                                      : null;
                                  return Dismissible(
                                    key: ValueKey(
                                      'band-spotify-track-${track.id}',
                                    ),
                                    direction: DismissDirection.endToStart,
                                    background: Container(
                                      alignment: Alignment.centerRight,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFB3261E),
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: const Icon(
                                        Icons.delete_outline,
                                        color: Colors.white,
                                      ),
                                    ),
                                    confirmDismiss: (_) async {
                                      await removeTrack(track);
                                      return false;
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: AppColors.inputFill,
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: AppColors.border,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 48,
                                            height: 48,
                                            decoration: BoxDecoration(
                                              color: AppColors.navBlueSoft,
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              image: albumArtUrl != null
                                                  ? DecorationImage(
                                                      image: NetworkImage(
                                                        albumArtUrl,
                                                      ),
                                                      fit: BoxFit.cover,
                                                    )
                                                  : null,
                                            ),
                                            child: albumArtUrl == null
                                                ? const Icon(
                                                    Icons.music_note,
                                                    color: AppColors.textMuted,
                                                  )
                                                : null,
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  track.name,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    color:
                                                        AppColors.textPrimary,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  track.artistNames.join(', '),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
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
                                            onPressed: () => _openExternalUrl(
                                              sheetContext,
                                              track.spotifyUrl,
                                            ),
                                            child: const Text(
                                              "Spotify'da Dinle",
                                              style: TextStyle(
                                                color: Color(0xFF1DB954),
                                              ),
                                            ),
                                          ),
                                          IconButton(
                                            tooltip: 'Katalogdan kaldir',
                                            onPressed: () => removeTrack(track),
                                            icon: const Icon(
                                              Icons.delete_outline,
                                              color: AppColors.textMuted,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showTrackUpload(BuildContext context) async {
    await showProfileTrackUploadSheet(
      hostContext: context,
      profileId: profile.id,
      ownerType: 'BAND',
      profileType: 'BAND',
    );
  }

  Future<void> _toggleTrack(dynamic track, AudioHandler audioHandler) async {
    final url = track.playbackUrl?.toString();
    if (url == null || url.isEmpty) return;
    final currentId = audioHandler.mediaItem.value?.id;
    final isPlaying = audioHandler.playbackState.value.playing;
    final isCurrent = currentId == track.id?.toString();

    if (audioHandler is AudioPlayerHandler) {
      if (isCurrent && isPlaying) {
        await audioHandler.pause();
      } else if (isCurrent && !isPlaying) {
        await audioHandler.play();
      } else {
        await audioHandler.playUrl(
          url,
          title: track.title?.toString(),
          duration: track.durationSeconds is int
              ? Duration(seconds: track.durationSeconds as int)
              : null,
          mediaId: track.id?.toString(),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final audioHandler = serviceLocator<AudioHandler>();
    final positionStream = audioHandler is AudioPlayerHandler
        ? audioHandler.positionStream
        : const Stream<Duration>.empty();

    return StreamBuilder<Duration>(
      stream: positionStream,
      builder: (context, snapshot) {
        final position = snapshot.data ?? Duration.zero;
        final currentId = audioHandler.mediaItem.value?.id;
        final isPlaying = audioHandler.playbackState.value.playing;

        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _showSpotifyCatalog(context),
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
            const SizedBox(height: 18),
            InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () => _showTrackUpload(context),
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
                      items.isEmpty ? 'Henuz ses eklemediniz' : 'Ses ekle',
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'SoundConnect uzerinden sarki yuklemek icin dokun.',
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
            if (items.isEmpty)
              const Text(
                'Band henuz ses eklemedi.',
                style: TextStyle(color: AppColors.textMuted),
              )
            else
              ...items.asMap().entries.map((entry) {
                final index = entry.key;
                final track = entry.value;
                final trackId = track.id?.toString() ?? '';
                final playback = track.playbackUrl?.toString() ?? '';
                final isSpotify =
                    playback.contains('spotify') ||
                    playback.contains('open.spotify') ||
                    playback.contains('spotify.com');
                final isCurrent = currentId == trackId;
                final totalFromTrackMs =
                    ((track.durationSeconds as int?) ?? 0) * 1000;
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
                final fallbackLikeCount = 128 + (index * 7);
                final fallbackCommentCount = 32 + (index * 3);

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ProfileAudioPreviewCard(
                        title: track.title?.toString() ?? 'Ses kaydi',
                        actionLabel: isSpotify
                            ? "Tamamini Spotify'da Dinle"
                            : null,
                        actionColor: isSpotify ? const Color(0xFF1DB954) : null,
                        waveform: WaveformStub(
                          samples: WaveformStub.samplesFromSeed(
                            '$trackId:${track.title}:${track.mediaAssetId}',
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
                        bottomControls: ProfileAudioTransportRow(
                          isPlaying: isCurrent && isPlaying,
                          iconColor: isSpotify
                              ? const Color(0xFF1DB954)
                              : AppColors.textMuted,
                          onPlayPause: () => _toggleTrack(track, audioHandler),
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
                      ),
                      const SizedBox(height: 6),
                      ProfileCountRow(
                        likeCount: fallbackLikeCount,
                        commentCount: fallbackCommentCount,
                        isLiked: false,
                        onLikeTap: null,
                        onCommentTap: null,
                      ),
                    ],
                  ),
                );
              }),
          ],
        );
      },
    );
    // ignore: dead_code
    if (items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Text(
          'Band henüz ses eklemedi.',
          style: TextStyle(color: AppColors.textMuted),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final track = items[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: AppColors.inputFill,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: ListTile(
            leading: const Icon(Icons.graphic_eq_rounded),
            title: Text(
              track.title?.toString() ?? 'Ses kaydi',
              style: const TextStyle(color: AppColors.textPrimary),
            ),
            subtitle: Text(
              track.playbackUrl?.toString().contains('spotify') == true
                  ? 'Spotify'
                  : 'SoundConnect',
              style: const TextStyle(color: AppColors.textMuted),
            ),
          ),
        );
      },
    );
  }
}

class _BandSocialButtonRow extends StatelessWidget {
  final BandProfile profile;
  final bool editable;
  final ValueChanged<ProfileSocialPlatform>? onAddLink;

  const _BandSocialButtonRow({
    required this.profile,
    required this.editable,
    required this.onAddLink,
  });

  String? _urlFor(ProfileSocialPlatform platform) {
    switch (platform) {
      case ProfileSocialPlatform.soundcloud:
        return profile.soundCloudUrl;
      case ProfileSocialPlatform.instagram:
        return profile.instagramUrl;
      case ProfileSocialPlatform.youtube:
        return profile.youtubeUrl;
      case ProfileSocialPlatform.spotify:
        return profile.spotifyEmbedUrl;
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = ProfileSocialPlatform.values
        .map(
          (platform) =>
              _BandSocialItem(platform: platform, url: _urlFor(platform)),
        )
        .toList();

    final visible = editable
        ? items
        : items.where((item) => item.active).toList();

    if (visible.isEmpty) return const SizedBox.shrink();

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: visible.map((item) {
        return _BandSocialPill(
          icon: item.platform.icon,
          active: item.active,
          showAddBadge: editable && !item.active,
          onTap: () => onAddLink?.call(item.platform),
        );
      }).toList(),
    );
  }
}

class _BandSocialItem {
  final ProfileSocialPlatform platform;
  final String? url;

  const _BandSocialItem({required this.platform, required this.url});

  bool get active {
    final value = url?.trim().toLowerCase();
    if (value == null || value.isEmpty) return false;
    return value.startsWith('http://') ||
        value.startsWith('https://') ||
        value.startsWith('www.');
  }
}

class _BandSocialPill extends StatelessWidget {
  final IconData icon;
  final bool active;
  final bool showAddBadge;
  final VoidCallback onTap;

  const _BandSocialPill({
    required this.icon,
    required this.active,
    required this.showAddBadge,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 64,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.inputFill,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Center(
              child: Icon(
                icon,
                size: 20,
                color: active ? AppColors.textPrimary : AppColors.textMuted,
              ),
            ),
          ),
          if (showAddBadge)
            Positioned(
              right: -4,
              top: -4,
              child: Container(
                width: 18,
                height: 18,
                decoration: const BoxDecoration(
                  color: AppColors.coralAlt,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.add, size: 12, color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }
}
