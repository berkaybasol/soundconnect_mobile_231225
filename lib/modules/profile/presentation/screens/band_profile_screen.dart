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

part 'band_profile_screen_header_sections.dart';
part 'band_profile_screen_audio_tab.dart';
part 'band_profile_screen_audio_tab_methods.dart';
part 'band_profile_screen_audio_tab_spotify_dialogs.dart';
part 'band_profile_screen_audio_tab_spotify_picker.dart';
part 'band_profile_screen_actions.dart';
part 'band_profile_screen_social_sections.dart';

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

  void _updateState(VoidCallback updater) {
    if (!mounted) return;
    setState(updater);
  }

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
                  emptyText: 'Henuz bir aciklama eklenmedi.',
                  addLabel: 'Aciklama ekle',
                  hintText: 'Bandinden bahset...',
                ),
                afterBio: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      gradient: const LinearGradient(
                        colors: AppColors.brandGradient,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(0.7),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: Container(
                          color: AppColors.inputFill,
                          child: TextButton.icon(
                            onPressed: () => _openBandManagementPanel(context),
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.white,
                              backgroundColor: Colors.transparent,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                            ),
                            icon: const Icon(
                              Icons.dashboard_customize_outlined,
                              color: AppColors.white,
                            ),
                            label: const Text(
                              'Yonetim Paneli',
                              style: TextStyle(color: AppColors.white),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              ProfileSectionHeader(
                title: 'Uyeler',
                actionLabel: profile.members.isEmpty ? null : 'Tumu',
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
}
