// ignore_for_file: unused_element, unused_element_parameter, unused_local_variable, use_build_context_synchronously

import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:audio_service/audio_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/audio/audio_player_handler.dart';
import '../../../artist_venue/domain/artist_venue_connection_repository.dart';
import '../../../artist_venue/presentation/cubit/artist_venue_connections_cubit.dart';
import '../../../engagement/presentation/cubit/comment_thread_cubit.dart';
import '../../../engagement/presentation/cubit/interaction_stats_cubit.dart';
import '../../../follow/presentation/cubit/follow_action_cubit.dart';
import '../../../follow/presentation/cubit/follow_action_state.dart';
import '../../../follow/presentation/cubit/follow_count_cubit.dart';
import '../../../follow/presentation/cubit/follow_count_state.dart';
import '../../../location/domain/location_repository.dart';
import '../../../spotify/domain/entities/spotify_track_preview.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/widgets/gradient_text.dart';
import '../../../../shared/widgets/waveform_stub.dart';
import '../../domain/entities/media_asset.dart';
import '../../domain/entities/musician_profile.dart';
import '../../domain/entities/profile_venue_models.dart';
import '../../domain/entities/profile_media.dart';
import '../../domain/entities/track.dart';
import '../../domain/entities/venue_active_musician.dart';
import '../../domain/entities/venue_owner_profile.dart';
import '../../domain/musician_search_repository.dart';
import '../../domain/profile_media_management_repository.dart';
import '../../domain/venue_directory_repository.dart';
import '../../domain/venue_event_repository.dart';
import '../../../../app/router/app_routes.dart';
import '../../data/models/musician_profile_save_request.dart';
import '../../data/models/venue_profile_save_request.dart';
import '../cubit/musician_profile_cubit.dart';
import '../cubit/musician_profile_state.dart';
import '../cubit/profile_media_cubit.dart';
import '../cubit/venue_profile_cubit.dart';
import '../cubit/venue_profile_state.dart';
import '../../../spotify/domain/spotify_repository.dart';
import 'media_detail_screen.dart';
import 'profile_track_upload_support.dart';
import 'profile_audio_transport.dart';
import 'profile_carousels.dart';
import 'profile_common_widgets.dart';
import 'profile_media_tabs.dart';
import 'profile_photo_gallery_tab.dart';
import 'profile_count_row.dart';
import 'profile_owner_video_tab.dart';
import 'venue_management_panel_screen.dart';
import 'profile_venue_support.dart';
import 'profile_screen_support.dart';
import 'profile_section_support.dart';
import 'profile_social_support.dart';
import 'venue_weekly_calendar_editor_screen.dart';
import 'venue_event_support.dart';
import 'weekly_event_carousel.dart';
import 'weekly_event_detail_screen.dart';

class PublicProfileArgs {
  final String? profileId;
  final String? viewerUserId;

  const PublicProfileArgs({this.profileId, this.viewerUserId});
}

class VenueProfileArgs {
  final String? venueId;
  final String? viewerUserId;

  const VenueProfileArgs({this.venueId, this.viewerUserId});
}

class VenueProfileScreen extends StatelessWidget {
  const VenueProfileScreen({super.key});

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
  String? _ownerVenueId;
  final _loadCoordinator = ProfileScreenLoadCoordinator();
  final _artistVenueRepository =
      serviceLocator<ArtistVenueConnectionRepository>();
  final _locationRepository = serviceLocator<LocationRepository>();
  final _musicianSearchRepository = serviceLocator<MusicianSearchRepository>();
  final _venueDirectoryRepository = serviceLocator<VenueDirectoryRepository>();
  final _venueEventRepository = serviceLocator<VenueEventRepository>();
  String? _viewerUserId;
  String? _currentProfileUserId;
  bool _photoUploading = false;
  final ImagePicker _imagePicker = ImagePicker();
  List<WeeklyCalendarEvent> _fallbackWeeklyEvents = const [];
  String? _fallbackWeeklyEventsVenueId;
  bool _loadingFallbackWeeklyEvents = false;

  Future<void> _editProfilePhoto(VenueOwnerProfile profile) async {
    setState(() => _photoUploading = true);
    try {
      final uploaded = await pickCropAndUploadProfilePhoto(
        context: context,
        imagePicker: _imagePicker,
        ownerType: 'VENUE_PROFILE',
        ownerId: profile.venueProfileId,
      );
      if (uploaded == null) return;
      await context.read<VenueProfileCubit>().updateOwnerProfile(
        VenueProfileSaveRequest(profilePicture: uploaded.assetId),
        venueId: profile.venueId,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profil fotoğrafı güncellendi')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Fotoğraf yüklenemedi: $e')));
    } finally {
      if (mounted) {
        setState(() => _photoUploading = false);
      }
    }
  }

  String? _socialUrlFor(
    MusicianProfile profile,
    ProfileSocialPlatform platform,
  ) => socialUrlForMusicianProfile(profile, platform);

  Future<void> _addSocialLink(
    MusicianProfile profile,
    ProfileSocialPlatform platform,
  ) async {
    final normalized = await promptForSocialLink(
      context,
      platform: platform,
      initialValue: _socialUrlFor(profile, platform)?.trim() ?? '',
    );
    if (normalized == null) return;

    try {
      await context.read<MusicianProfileCubit>().updateProfile(
        buildMusicianSocialLinkRequest(platform, normalized),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${platform.label} eklendi')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sosyal link kaydedilemedi')),
      );
    }
  }

  Future<void> _saveDescription(String value) async {
    final normalized = value.trim();
    try {
      await context.read<MusicianProfileCubit>().updateProfile(
        MusicianProfileSaveRequest(description: normalized),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Açıklama güncellendi')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Açıklama kaydedilemedi')));
    }
  }

  void _onEditProfilePressed() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Aşağıdaki alanlardan profilini düzenleyebilirsin.'),
      ),
    );
  }

  Future<List<VenueOption>> _fetchAllVenues() async {
    final result = await _venueDirectoryRepository.getAllVenues();
    return result.data ?? const [];
  }

  Future<List<VenueLookupOption>> _fetchCities() async {
    final result = await _locationRepository.getCities();
    return (result.data ?? const [])
        .map((item) => VenueLookupOption(id: item.id, name: item.name))
        .toList();
  }

  Future<List<VenueLookupOption>> _fetchDistricts(String cityId) async {
    final result = await _locationRepository.getDistricts(cityId);
    return (result.data ?? const [])
        .map((item) => VenueLookupOption(id: item.id, name: item.name))
        .toList();
  }

  Future<List<VenueLookupOption>> _fetchNeighborhoods(String districtId) async {
    final result = await _locationRepository.getNeighborhoods(districtId);
    return (result.data ?? const [])
        .map((item) => VenueLookupOption(id: item.id, name: item.name))
        .toList();
  }

  Future<List<VenueConnection>> _fetchVenueConnectionsByStatus(
    String profileId, {
    required String status,
  }) async {
    final result = await _artistVenueRepository.getVenueConnectionsByStatus(
      profileId,
      status: status,
    );
    return result.data ?? const [];
  }

  Future<List<VenueConnection>> _fetchAcceptedVenueConnections(
    String profileId,
  ) {
    return _fetchVenueConnectionsByStatus(profileId, status: 'ACCEPTED');
  }

  Future<List<VenueConnection>> _fetchPendingVenueConnections(
    String profileId,
  ) {
    return _fetchVenueConnectionsByStatus(profileId, status: 'PENDING');
  }

  Future<List<MusicianConnection>> _fetchArtistConnectionsByStatus(
    String venueId, {
    required String status,
  }) async {
    final result = await _artistVenueRepository.getMusicianConnectionsByStatus(
      venueId,
      status: status,
    );
    return result.data ?? const [];
  }

  Future<void> _editConnectedArtists(String venueId) async {
    try {
      final acceptedIntro =
          await Navigator.of(context).push<bool>(
            MaterialPageRoute(
              fullscreenDialog: true,
              builder: (_) => const MusicianIntroScreen(),
            ),
          ) ??
          false;
      if (!acceptedIntro || !mounted) return;

      final accepted = await _fetchArtistConnectionsByStatus(
        venueId,
        status: 'ACCEPTED',
      );
      final pending = await _fetchArtistConnectionsByStatus(
        venueId,
        status: 'PENDING',
      );

      final acceptedIds = accepted.map((item) => item.musicianProfileId).toSet();
      final pendingIds = pending.map((item) => item.musicianProfileId).toSet();
      final searchController = TextEditingController();

      final selected = await showModalBottomSheet<MusicianRequestPayload>(
        context: context,
        isScrollControlled: true,
        backgroundColor: AppColors.navBlueDeep,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (sheetContext) {
          String? selectedMusicianId;
          Timer? searchDebounce;
          var searchToken = 0;
          var loading = false;
          var searchError = '';
          var query = '';
          var results = <MusicianSearchOption>[];

          Future<void> runSearch(StateSetter setSheetState, String raw) async {
            final trimmed = raw.trim();
            query = trimmed;
            final token = ++searchToken;
            if (trimmed.length < 2) {
              setSheetState(() {
                loading = false;
                searchError = '';
                results = const [];
              });
              return;
            }
            setSheetState(() {
              loading = true;
              searchError = '';
            });
            try {
              final result = await _musicianSearchRepository.search(trimmed);
              final response = result.data ?? const <MusicianSearchOption>[];
              if (!sheetContext.mounted || token != searchToken) return;
              setSheetState(() {
                loading = false;
                results = response;
                if (response.isEmpty) {
                  searchError = 'Sonuc bulunamadi.';
                }
              });
            } catch (_) {
              if (!sheetContext.mounted || token != searchToken) return;
              setSheetState(() {
                loading = false;
                results = const [];
                searchError = 'Sanatci aramasi yapilamadi.';
              });
            }
          }

          return StatefulBuilder(
            builder: (context, setSheetState) {
              return AnimatedPadding(
                duration: const Duration(milliseconds: 180),
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom,
                ),
                child: SafeArea(
                  top: false,
                  child: SizedBox(
                    height: MediaQuery.of(context).size.height * 0.84,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Center(
                            child: Text(
                              'Bağlantılı Müzisyenleri Düzenle',
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: searchController,
                            decoration: const InputDecoration(
                              hintText: 'Müzisyen ara...',
                              prefixIcon: Icon(Icons.search),
                            ),
                            onChanged: (value) {
                              searchDebounce?.cancel();
                              searchDebounce = Timer(
                                const Duration(milliseconds: 280),
                                () => runSearch(setSheetState, value),
                              );
                            },
                          ),
                          const SizedBox(height: 10),
                          if (loading) const LinearProgressIndicator(),
                          Expanded(
                            child: results.isEmpty
                                ? Center(
                                    child: Text(
                                      query.length < 2
                                          ? 'Bir muzisyen aramak icin en az 2 karakter yaz.'
                                          : searchError.isNotEmpty
                                          ? searchError
                                          : 'Sonuc bulunamadi.',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        color: AppColors.textMuted,
                                      ),
                                    ),
                                  )
                                : ListView.builder(
                                    itemCount: results.length,
                                    itemBuilder: (context, index) {
                                      final item = results[index];
                                      final checked =
                                          selectedMusicianId == item.profileId;
                                      final isAccepted = acceptedIds.contains(
                                        item.profileId,
                                      );
                                      final isPending = pendingIds.contains(
                                        item.profileId,
                                      );
                                      final disabled = isAccepted || isPending;
                                      return InkWell(
                                        borderRadius: BorderRadius.circular(12),
                                        onTap: () {
                                          if (isAccepted) {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  'Bu muzisyen zaten profilinde bagli.',
                                                ),
                                              ),
                                            );
                                            return;
                                          }
                                          if (isPending) {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  'Bu muzisyene zaten basvurdun (beklemede).',
                                                ),
                                              ),
                                            );
                                            return;
                                          }
                                          setSheetState(() {
                                            selectedMusicianId = checked
                                                ? null
                                                : item.profileId;
                                          });
                                        },
                                        child: Container(
                                          margin: const EdgeInsets.only(
                                            bottom: 8,
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 10,
                                          ),
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            border: Border.all(
                                              color: checked
                                                  ? Colors.transparent
                                                  : AppColors.border.withValues(
                                                      alpha: 0.45,
                                                    ),
                                            ),
                                            gradient: checked
                                                ? const LinearGradient(
                                                    colors: [
                                                      Color(0x22FF7A3D),
                                                      Color(0x22EF5F86),
                                                      Color(0x22B85CFF),
                                                    ],
                                                    begin: Alignment.topLeft,
                                                    end: Alignment.bottomRight,
                                                  )
                                                : null,
                                            color: checked
                                                ? null
                                                : AppColors.inputFill,
                                          ),
                                          child: Row(
                                            children: [
                                              Container(
                                                width: 22,
                                                height: 22,
                                                decoration: BoxDecoration(
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                  border: Border.all(
                                                    color: checked
                                                        ? Colors.transparent
                                                        : AppColors.textMuted
                                                              .withValues(
                                                                alpha: 0.55,
                                                              ),
                                                  ),
                                                  gradient: checked
                                                      ? const LinearGradient(
                                                          colors: [
                                                            Color(0xFFFF7A3D),
                                                            Color(0xFFEF5F86),
                                                            Color(0xFFB85CFF),
                                                          ],
                                                          begin:
                                                              Alignment.topLeft,
                                                          end: Alignment
                                                              .bottomRight,
                                                        )
                                                      : null,
                                                ),
                                                child: checked
                                                    ? const Icon(
                                                        Icons.check,
                                                        size: 15,
                                                        color: Colors.white,
                                                      )
                                                    : null,
                                              ),
                                              const SizedBox(width: 12),
                                              CircleAvatar(
                                                radius: 18,
                                                backgroundColor:
                                                    AppColors.navBlueSoft,
                                                backgroundImage:
                                                    isValidNetworkImageUrl(
                                                          item.profilePictureUrl,
                                                        )
                                                        ? NetworkImage(
                                                            item.profilePictureUrl!,
                                                          )
                                                        : null,
                                                child: !isValidNetworkImageUrl(
                                                      item.profilePictureUrl,
                                                    )
                                                    ? const Icon(
                                                        Icons.person_outline,
                                                        color: AppColors
                                                            .textMuted,
                                                        size: 18,
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
                                                      item.displayName,
                                                      style: TextStyle(
                                                        color: AppColors
                                                            .textPrimary
                                                            .withValues(
                                                              alpha: disabled
                                                                  ? 0.55
                                                                  : 1,
                                                            ),
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                    ),
                                                    if (item.secondaryLabel !=
                                                        null) ...[
                                                      const SizedBox(height: 2),
                                                      Text(
                                                        item.secondaryLabel!,
                                                        style: const TextStyle(
                                                          color: AppColors
                                                              .textMuted,
                                                          fontSize: 12,
                                                        ),
                                                      ),
                                                    ],
                                                  ],
                                                ),
                                              ),
                                              if (disabled) ...[
                                                const SizedBox(width: 8),
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 4,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: AppColors.inputFill,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          8,
                                                        ),
                                                    border: Border.all(
                                                      color: AppColors.border
                                                          .withValues(
                                                            alpha: 0.5,
                                                          ),
                                                    ),
                                                  ),
                                                  child: Text(
                                                    isPending
                                                        ? 'Beklemede'
                                                        : 'Bagli',
                                                    style: const TextStyle(
                                                      color:
                                                          AppColors.textMuted,
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () =>
                                      Navigator.of(sheetContext).pop(),
                                  child: const Text('Iptal'),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () async {
                                    if (selectedMusicianId == null) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Lutfen bir muzisyen sec.',
                                          ),
                                        ),
                                      );
                                      return;
                                    }
                                    var noteDraft = '';
                                    final message = await showDialog<String>(
                                      context: context,
                                      useRootNavigator: true,
                                      barrierDismissible: true,
                                      barrierColor: Colors.black.withValues(
                                        alpha: 0.35,
                                      ),
                                      builder: (dialogContext) {
                                        return BackdropFilter(
                                          filter: ImageFilter.blur(
                                            sigmaX: 8,
                                            sigmaY: 8,
                                          ),
                                          child: Dialog(
                                            backgroundColor:
                                                AppColors.navBlueDeep,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                            ),
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.fromLTRB(
                                                    16,
                                                    16,
                                                    16,
                                                    14,
                                                  ),
                                              child: SingleChildScrollView(
                                                child: Column(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    const Text(
                                                      'Başvuru Notu (Opsiyonel)',
                                                      style: TextStyle(
                                                        color: AppColors
                                                            .textPrimary,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 10),
                                                    TextField(
                                                      minLines: 3,
                                                      maxLines: 5,
                                                      onChanged: (value) {
                                                        noteDraft = value;
                                                      },
                                                      decoration:
                                                          const InputDecoration(
                                                            hintText:
                                                                'Istersen kisa bir not ekleyebilirsin (zorunlu degil).',
                                                          ),
                                                    ),
                                                    const SizedBox(height: 12),
                                                    Row(
                                                      children: [
                                                        Expanded(
                                                          child: OutlinedButton(
                                                            onPressed: () =>
                                                                Navigator.of(
                                                                  dialogContext,
                                                                ).pop(),
                                                            child: const Text(
                                                              'Vazgec',
                                                            ),
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                          width: 10,
                                                        ),
                                                        Expanded(
                                                          child: ElevatedButton(
                                                            onPressed: () =>
                                                                Navigator.of(
                                                                  dialogContext,
                                                                ).pop(
                                                                  noteDraft
                                                                      .trim(),
                                                                ),
                                                            child: const Text(
                                                              'Gonder',
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    );
                                    if (message == null) return;
                                    await Future<void>.delayed(
                                      const Duration(milliseconds: 16),
                                    );
                                    if (!mounted) return;
                                    Navigator.of(sheetContext).pop(
                                      MusicianRequestPayload(
                                        musicianProfileId: selectedMusicianId!,
                                        message: message,
                                      ),
                                    );
                                  },
                                  child: const Text('Devam'),
                                ),
                              ),
                            ],
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

      if (selected == null) return;

      final requestResult = await _artistVenueRepository.createVenueRequest(
        musicianProfileId: selected.musicianProfileId,
        venueId: venueId,
        message: selected.message,
      );
      if (!requestResult.isSuccess) {
        throw requestResult.error?.message ?? 'Request failed';
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sanatçı bağlantı isteği gönderildi.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sanatci baglantisi guncellenemedi: $e')),
      );
    }
  }

  Future<void> _ensureFallbackWeeklyEvents(VenueOwnerProfile profile) async {
    final venueId = profile.venueId.trim();
    if (venueId.isEmpty) return;
    if (profile.weeklyEvents.isNotEmpty) {
      if (_fallbackWeeklyEvents.isNotEmpty ||
          _fallbackWeeklyEventsVenueId != null) {
        setState(() {
          _fallbackWeeklyEvents = const [];
          _fallbackWeeklyEventsVenueId = null;
        });
      }
      return;
    }
    if (_loadingFallbackWeeklyEvents &&
        _fallbackWeeklyEventsVenueId == venueId) {
      return;
    }
    if (_fallbackWeeklyEventsVenueId == venueId &&
        _fallbackWeeklyEvents.isNotEmpty) {
      return;
    }

    _loadingFallbackWeeklyEvents = true;
    try {
      final result = await _venueEventRepository.listByVenue(venueId);
      final items = result.data ?? const <VenueOwnerEventItem>[];
      if (!mounted) return;
      setState(() {
        _fallbackWeeklyEvents = items
            .map((item) => _toWeeklyCalendarEvent(profile, item))
            .toList();
        _fallbackWeeklyEventsVenueId = venueId;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _fallbackWeeklyEvents = const [];
        _fallbackWeeklyEventsVenueId = venueId;
      });
    } finally {
      _loadingFallbackWeeklyEvents = false;
    }
  }

  Future<void> _editVenues(String profileId) async {
    try {
      final acceptedIntro =
          await Navigator.of(context).push<bool>(
            MaterialPageRoute(
              fullscreenDialog: true,
              builder: (_) => const VenueIntroScreen(),
            ),
          ) ??
          false;
      if (!acceptedIntro || !mounted) return;

      final allVenues = await _fetchAllVenues();
      final cities = await _fetchCities();
      final accepted = await _fetchAcceptedVenueConnections(profileId);
      final pending = await _fetchPendingVenueConnections(profileId);

      final acceptedIds = accepted.map((item) => item.venueId).toSet();
      final pendingIds = pending.map((item) => item.venueId).toSet();
      final searchController = TextEditingController();
      final selected = await showModalBottomSheet<VenueRequestPayload>(
        context: context,
        isScrollControlled: true,
        backgroundColor: AppColors.navBlueDeep,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (sheetContext) {
          String? selectedVenueId;
          var searchQuery = '';
          var filtersExpanded = false;
          String? selectedCityId;
          String? selectedDistrictId;
          String? selectedNeighborhoodId;
          var districtOptions = <VenueLookupOption>[];
          var neighborhoodOptions = <VenueLookupOption>[];
          var loadingDistricts = false;
          var loadingNeighborhoods = false;

          return StatefulBuilder(
            builder: (context, setSheetState) {
              Future<void> onCityChanged(String? cityId) async {
                setSheetState(() {
                  selectedCityId = cityId;
                  selectedDistrictId = null;
                  selectedNeighborhoodId = null;
                  districtOptions = const [];
                  neighborhoodOptions = const [];
                  loadingDistricts = cityId != null;
                });
                if (cityId == null) return;
                try {
                  final districts = await _fetchDistricts(cityId);
                  if (!mounted) return;
                  setSheetState(() {
                    districtOptions = districts;
                    loadingDistricts = false;
                  });
                } catch (_) {
                  if (!mounted) return;
                  setSheetState(() => loadingDistricts = false);
                }
              }

              Future<void> onDistrictChanged(String? districtId) async {
                setSheetState(() {
                  selectedDistrictId = districtId;
                  selectedNeighborhoodId = null;
                  neighborhoodOptions = const [];
                  loadingNeighborhoods = districtId != null;
                });
                if (districtId == null) return;
                try {
                  final neighborhoods = await _fetchNeighborhoods(districtId);
                  if (!mounted) return;
                  setSheetState(() {
                    neighborhoodOptions = neighborhoods;
                    loadingNeighborhoods = false;
                  });
                } catch (_) {
                  if (!mounted) return;
                  setSheetState(() => loadingNeighborhoods = false);
                }
              }

              String? nameById(List<VenueLookupOption> list, String? id) {
                if (id == null) return null;
                for (final item in list) {
                  if (item.id == id) return item.name.toLowerCase();
                }
                return null;
              }

              final filteredVenues = allVenues.where((venue) {
                final selectedCityName = nameById(cities, selectedCityId);
                final selectedDistrictName = nameById(
                  districtOptions,
                  selectedDistrictId,
                );
                final selectedNeighborhoodName = nameById(
                  neighborhoodOptions,
                  selectedNeighborhoodId,
                );
                final matchesSearch =
                    searchQuery.isEmpty ||
                    venue.name.toLowerCase().contains(
                      searchQuery.toLowerCase(),
                    );
                final matchesCity =
                    selectedCityId == null ||
                    venue.cityId == selectedCityId ||
                    (selectedCityName != null &&
                        venue.cityName?.toLowerCase() == selectedCityName);
                final matchesDistrict =
                    selectedDistrictId == null ||
                    venue.districtId == selectedDistrictId ||
                    (selectedDistrictName != null &&
                        venue.districtName?.toLowerCase() ==
                            selectedDistrictName);
                final matchesNeighborhood =
                    selectedNeighborhoodId == null ||
                    venue.neighborhoodId == selectedNeighborhoodId ||
                    (selectedNeighborhoodName != null &&
                        venue.neighborhoodName?.toLowerCase() ==
                            selectedNeighborhoodName);
                return matchesSearch &&
                    matchesCity &&
                    matchesDistrict &&
                    matchesNeighborhood;
              }).toList();

              return AnimatedPadding(
                duration: const Duration(milliseconds: 180),
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom,
                ),
                child: SafeArea(
                  top: false,
                  child: SizedBox(
                    height:
                        MediaQuery.of(context).size.height *
                        (filtersExpanded ? 0.93 : 0.84),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Center(
                            child: Text(
                              '\u00C7ald\u0131\u011F\u0131n Mek\u00E2nlar\u0131 D\u00FCzenle',
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: searchController,
                            decoration: const InputDecoration(
                              hintText: 'Mekan ara...',
                              prefixIcon: Icon(Icons.search),
                            ),
                            onChanged: (value) {
                              setSheetState(() {
                                searchQuery = value.trim();
                              });
                            },
                          ),
                          const SizedBox(height: 10),
                          Align(
                            alignment: Alignment.centerRight,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(10),
                              onTap: () {
                                setSheetState(() {
                                  filtersExpanded = !filtersExpanded;
                                });
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 6,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      filtersExpanded
                                          ? Icons.filter_alt_off
                                          : Icons.filter_alt_outlined,
                                      color: AppColors.textMuted,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 6),
                                    const Text(
                                      'Filtrele',
                                      style: TextStyle(
                                        color: AppColors.textMuted,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          if (filtersExpanded) ...[
                            const SizedBox(height: 8),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.fromLTRB(
                                12,
                                12,
                                12,
                                10,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.inputFill.withValues(
                                  alpha: 0.55,
                                ),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: AppColors.border.withValues(
                                    alpha: 0.55,
                                  ),
                                ),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      TextButton.icon(
                                        onPressed: () {
                                          setSheetState(() {
                                            selectedCityId = null;
                                            selectedDistrictId = null;
                                            selectedNeighborhoodId = null;
                                            districtOptions = const [];
                                            neighborhoodOptions = const [];
                                          });
                                        },
                                        icon: const Icon(
                                          Icons.refresh,
                                          size: 16,
                                          color: AppColors.textMuted,
                                        ),
                                        label: const Text(
                                          'Filtreyi S\u0131f\u0131rla',
                                          style: TextStyle(
                                            color: AppColors.textMuted,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  DropdownButtonFormField<String>(
                                    value: selectedCityId,
                                    isExpanded: true,
                                    dropdownColor: AppColors.inputFill,
                                    menuMaxHeight: 300,
                                    borderRadius: BorderRadius.circular(12),
                                    iconEnabledColor: AppColors.textMuted,
                                    style: const TextStyle(
                                      color: AppColors.textPrimary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    decoration: const InputDecoration(
                                      labelText: '\u0130l',
                                      contentPadding: EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 14,
                                      ),
                                    ),
                                    items: [
                                      const DropdownMenuItem<String>(
                                        value: null,
                                        child: Text('T\u00FCm \u0130ller'),
                                      ),
                                      ...cities.map(
                                        (city) => DropdownMenuItem<String>(
                                          value: city.id,
                                          child: Text(city.name),
                                        ),
                                      ),
                                    ],
                                    onChanged: (value) => onCityChanged(value),
                                  ),
                                  const SizedBox(height: 12),
                                  DropdownButtonFormField<String>(
                                    value: selectedDistrictId,
                                    isExpanded: true,
                                    dropdownColor: AppColors.inputFill,
                                    menuMaxHeight: 300,
                                    borderRadius: BorderRadius.circular(12),
                                    iconEnabledColor: AppColors.textMuted,
                                    style: const TextStyle(
                                      color: AppColors.textPrimary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    decoration: InputDecoration(
                                      labelText: '\u0130l\u00E7e',
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 14,
                                            vertical: 14,
                                          ),
                                      suffixIcon: loadingDistricts
                                          ? const SizedBox(
                                              width: 16,
                                              height: 16,
                                              child: Padding(
                                                padding: EdgeInsets.all(12),
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                    ),
                                              ),
                                            )
                                          : null,
                                    ),
                                    items: [
                                      const DropdownMenuItem<String>(
                                        value: null,
                                        child: Text(
                                          'T\u00FCm \u0130l\u00E7eler',
                                        ),
                                      ),
                                      ...districtOptions.map(
                                        (district) => DropdownMenuItem<String>(
                                          value: district.id,
                                          child: Text(district.name),
                                        ),
                                      ),
                                    ],
                                    onChanged: selectedCityId == null
                                        ? null
                                        : (value) => onDistrictChanged(value),
                                  ),
                                  const SizedBox(height: 12),
                                  DropdownButtonFormField<String>(
                                    value: selectedNeighborhoodId,
                                    isExpanded: true,
                                    dropdownColor: AppColors.inputFill,
                                    menuMaxHeight: 300,
                                    borderRadius: BorderRadius.circular(12),
                                    iconEnabledColor: AppColors.textMuted,
                                    style: const TextStyle(
                                      color: AppColors.textPrimary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    decoration: InputDecoration(
                                      labelText: 'Mahalle',
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 14,
                                            vertical: 14,
                                          ),
                                      suffixIcon: loadingNeighborhoods
                                          ? const SizedBox(
                                              width: 16,
                                              height: 16,
                                              child: Padding(
                                                padding: EdgeInsets.all(12),
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                    ),
                                              ),
                                            )
                                          : null,
                                    ),
                                    items: [
                                      const DropdownMenuItem<String>(
                                        value: null,
                                        child: Text('T\u00FCm Mahalleler'),
                                      ),
                                      ...neighborhoodOptions.map(
                                        (neighborhood) =>
                                            DropdownMenuItem<String>(
                                              value: neighborhood.id,
                                              child: Text(neighborhood.name),
                                            ),
                                      ),
                                    ],
                                    onChanged: selectedDistrictId == null
                                        ? null
                                        : (value) => setSheetState(
                                            () =>
                                                selectedNeighborhoodId = value,
                                          ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 10),
                          Expanded(
                            child: filteredVenues.isEmpty
                                ? const Center(
                                    child: Text(
                                      'Filtreye uygun mekan yok.',
                                      style: TextStyle(
                                        color: AppColors.textMuted,
                                      ),
                                    ),
                                  )
                                : ListView.builder(
                                    itemCount: filteredVenues.length,
                                    itemBuilder: (context, index) {
                                      final venue = filteredVenues[index];
                                      final checked =
                                          selectedVenueId == venue.id;
                                      final isAccepted = acceptedIds.contains(
                                        venue.id,
                                      );
                                      final isPending = pendingIds.contains(
                                        venue.id,
                                      );
                                      final isLocked = isAccepted || isPending;
                                      return InkWell(
                                        borderRadius: BorderRadius.circular(12),
                                        onTap: () {
                                          if (isAccepted) {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  'Bu mek\u00E2n zaten profilinde ba\u011Fl\u0131.',
                                                ),
                                              ),
                                            );
                                            return;
                                          }
                                          if (isPending) {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  'Bu mek\u00E2na zaten ba\u015Fvurdun (beklemede).',
                                                ),
                                              ),
                                            );
                                            return;
                                          }
                                          setSheetState(() {
                                            if (checked) {
                                              selectedVenueId = null;
                                            } else {
                                              selectedVenueId = venue.id;
                                            }
                                          });
                                        },
                                        child: Container(
                                          margin: const EdgeInsets.only(
                                            bottom: 8,
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 10,
                                          ),
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            border: Border.all(
                                              color: checked
                                                  ? Colors.transparent
                                                  : AppColors.border.withValues(
                                                      alpha: 0.45,
                                                    ),
                                            ),
                                            gradient: checked
                                                ? const LinearGradient(
                                                    colors: [
                                                      Color(0x22FF7A3D),
                                                      Color(0x22EF5F86),
                                                      Color(0x22B85CFF),
                                                    ],
                                                    begin: Alignment.topLeft,
                                                    end: Alignment.bottomRight,
                                                  )
                                                : null,
                                            color: checked
                                                ? null
                                                : AppColors.inputFill,
                                          ),
                                          child: Row(
                                            children: [
                                              Container(
                                                width: 22,
                                                height: 22,
                                                decoration: BoxDecoration(
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                  border: Border.all(
                                                    color: checked
                                                        ? Colors.transparent
                                                        : AppColors.textMuted
                                                              .withValues(
                                                                alpha: 0.55,
                                                              ),
                                                  ),
                                                  gradient: checked
                                                      ? const LinearGradient(
                                                          colors: [
                                                            Color(0xFFFF7A3D),
                                                            Color(0xFFEF5F86),
                                                            Color(0xFFB85CFF),
                                                          ],
                                                          begin:
                                                              Alignment.topLeft,
                                                          end: Alignment
                                                              .bottomRight,
                                                        )
                                                      : null,
                                                ),
                                                child: checked
                                                    ? const Icon(
                                                        Icons.check,
                                                        size: 15,
                                                        color: Colors.white,
                                                      )
                                                    : null,
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Text(
                                                  venue.name,
                                                  style: TextStyle(
                                                    color: AppColors.textPrimary
                                                        .withValues(
                                                          alpha: isLocked
                                                              ? 0.55
                                                              : 1,
                                                        ),
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                              if (isLocked) ...[
                                                const SizedBox(width: 8),
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 4,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: AppColors.inputFill,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          8,
                                                        ),
                                                    border: Border.all(
                                                      color: AppColors.border
                                                          .withValues(
                                                            alpha: 0.5,
                                                          ),
                                                    ),
                                                  ),
                                                  child: Text(
                                                    isPending
                                                        ? '\u{1F7E1} Beklemede'
                                                        : 'Ba\u011Fl\u0131',
                                                    style: const TextStyle(
                                                      color:
                                                          AppColors.textMuted,
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () =>
                                      Navigator.of(sheetContext).pop(),
                                  child: const Text('Iptal'),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () async {
                                    if (selectedVenueId == null) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'L\u00FCtfen bir mekan se\u00E7.',
                                          ),
                                        ),
                                      );
                                      return;
                                    }
                                    var noteDraft = '';
                                    final message = await showDialog<String>(
                                      context: context,
                                      useRootNavigator: true,
                                      barrierDismissible: true,
                                      barrierColor: Colors.black.withValues(
                                        alpha: 0.35,
                                      ),
                                      builder: (dialogContext) {
                                        return BackdropFilter(
                                          filter: ImageFilter.blur(
                                            sigmaX: 8,
                                            sigmaY: 8,
                                          ),
                                          child: Dialog(
                                            backgroundColor:
                                                AppColors.navBlueDeep,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                            ),
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.fromLTRB(
                                                    16,
                                                    16,
                                                    16,
                                                    14,
                                                  ),
                                              child: SingleChildScrollView(
                                                child: Column(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    const Text(
                                                      'Ba\u015fvuru Notu (Opsiyonel)',
                                                      style: TextStyle(
                                                        color: AppColors
                                                            .textPrimary,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 10),
                                                    TextField(
                                                      minLines: 3,
                                                      maxLines: 5,
                                                      onChanged: (value) {
                                                        noteDraft = value;
                                                      },
                                                      decoration:
                                                          const InputDecoration(
                                                            hintText:
                                                                'Istersen kisa bir not ekleyebilirsin (zorunlu degil).',
                                                          ),
                                                    ),
                                                    const SizedBox(height: 12),
                                                    Row(
                                                      children: [
                                                        Expanded(
                                                          child: OutlinedButton(
                                                            onPressed: () =>
                                                                Navigator.of(
                                                                  dialogContext,
                                                                ).pop(),
                                                            child: const Text(
                                                              'Vazgec',
                                                            ),
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                          width: 10,
                                                        ),
                                                        Expanded(
                                                          child: ElevatedButton(
                                                            onPressed: () =>
                                                                Navigator.of(
                                                                  dialogContext,
                                                                ).pop(
                                                                  noteDraft
                                                                      .trim(),
                                                                ),
                                                            child: const Text(
                                                              'Gonder',
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    );
                                    if (message == null) return;
                                    await Future<void>.delayed(
                                      const Duration(milliseconds: 16),
                                    );
                                    if (!mounted) return;
                                    Navigator.of(sheetContext).pop(
                                      VenueRequestPayload(
                                        venueId: selectedVenueId!,
                                        message: message,
                                      ),
                                    );
                                  },
                                  child: const Text('Devam'),
                                ),
                              ),
                            ],
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
      // searchController dispose intentionally omitted to avoid race on sheet close.

      if (selected == null) return;

      final requestResult = await _artistVenueRepository.createArtistRequest(
        musicianProfileId: profileId,
        venueId: selected.venueId,
        message: selected.message,
      );
      if (!requestResult.isSuccess) {
        throw requestResult.error?.message ?? 'Request failed';
      }

      if (!mounted) return;
      await context.read<ArtistVenueConnectionsCubit>().loadAcceptedVenues(
        profileId,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Mekan ba\u011Flant\u0131 iste\u011Fi g\u00F6nderildi (onay bekliyor).',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Mekanlar güncellenemedi: $e')));
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_ownerVenueId == null) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is VenueProfileArgs) {
        _ownerVenueId = args.venueId;
      } else if (args is String) {
        _ownerVenueId = args;
      }
      context.read<VenueProfileCubit>().loadOwner(venueId: _ownerVenueId);
    }
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
    return BlocBuilder<VenueProfileCubit, VenueProfileState>(
      builder: (context, venueState) {
        final ownerProfile = venueState.ownerProfile;
        if (venueState.status == VenueProfileStatus.loading &&
            ownerProfile == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (ownerProfile == null) {
          return Scaffold(
            body: Center(
              child: Text(
                venueState.error?.message ?? 'Venue profili getirilemedi',
              ),
            ),
          );
        }
        final profile = _toDisplayProfile(ownerProfile);
        final primaryWeeklyEvents = _toWeeklyCalendarEvents(ownerProfile);
        if (primaryWeeklyEvents.isEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            _ensureFallbackWeeklyEvents(ownerProfile);
          });
        }
        final weeklyEvents = primaryWeeklyEvents.isNotEmpty
            ? primaryWeeklyEvents
            : _fallbackWeeklyEvents;
        _currentProfileUserId = ownerProfile.ownerUserId;
        _loadCoordinator.scheduleMediaLoad(
          context,
          mounted: mounted,
          profileId: ownerProfile.venueProfileId,
          profileType: ProfileMediaOwnerType.venue,
        );
        _loadCoordinator.scheduleFollowCountsLoad(
          context,
          mounted: mounted,
          userId: ownerProfile.ownerUserId,
        );
        final viewerUserId = _viewerUserId ?? '';
        _loadCoordinator.scheduleFollowStatusLoad(
          context,
          mounted: mounted,
          followerId: viewerUserId,
          followingId: ownerProfile.ownerUserId,
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
                activeVenues: ownerProfile.activeMusicians,
                viewerUserId: '',
                isFollowing: actionState.isFollowing,
                followLoading: actionState.status == FollowActionStatus.loading,
                spotifyTracks: const [],
                spotifyLoading: false,
                onEditPhoto: () => _editProfilePhoto(ownerProfile),
                photoUploading: _photoUploading,
                uploadedProfilePhotoUrl: ownerProfile.profilePictureUrl,
                socialEditable: false,
                onAddSocialLink: null,
                descriptionEditable: false,
                onSaveDescription: null,
                ownerMode: true,
                onEditProfilePressed: _onEditProfilePressed,
                venueEditable: false,
                onEditVenues: null,
                onEditEvents: () => _editConnectedArtists(ownerProfile.venueId),
                weeklyEvents: weeklyEvents,
                galleryOwnerId: ownerProfile.venueProfileId,
              );
            },
          ),
        );
      },
    );
  }

  MusicianProfile _toDisplayProfile(VenueOwnerProfile profile) {
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

  List<WeeklyCalendarEvent> _toWeeklyCalendarEvents(VenueOwnerProfile profile) {
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

  WeeklyCalendarEvent _toWeeklyCalendarEvent(
    VenueOwnerProfile profile,
    VenueOwnerEventItem item,
  ) {
    return WeeklyCalendarEvent(
      id: item.id,
      title: item.title,
      artistName: item.performerName.trim().isEmpty
          ? 'Sanatci'
          : item.performerName,
      artistProfileId: item.musicianProfileId,
      venueName: profile.venueName,
      venueId: profile.venueId,
      city: profile.cityName ?? '',
      district: profile.districtName ?? '',
      neighborhood: profile.neighborhoodName ?? '',
      eventDate: _formatDate(item.eventDate),
      startTime: formatVenueDisplayTime(item.startTime),
      endTime: item.endTime == null || item.endTime!.trim().isEmpty
          ? '-'
          : formatVenueDisplayTime(item.endTime!),
      imageAssetPath: item.posterImage?.trim().isEmpty == true
          ? null
          : item.posterImage?.trim(),
      description: item.description?.trim().isNotEmpty == true
          ? item.description!.trim()
          : '${item.performerName.trim().isEmpty ? 'Sanatci' : item.performerName} performansi',
    );
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
  final List<VenueActiveMusician>? activeVenues;
  final String viewerUserId;
  final bool isFollowing;
  final bool followLoading;
  final List<SpotifyTrackPreview> spotifyTracks;
  final bool spotifyLoading;
  final VoidCallback? onEditPhoto;
  final bool photoUploading;
  final String? uploadedProfilePhotoUrl;
  final bool socialEditable;
  final ValueChanged<ProfileSocialPlatform>? onAddSocialLink;
  final bool descriptionEditable;
  final Future<void> Function(String)? onSaveDescription;
  final bool ownerMode;
  final VoidCallback? onEditProfilePressed;
  final bool venueEditable;
  final VoidCallback? onEditVenues;
  final Future<void> Function()? onEditEvents;
  final List<WeeklyCalendarEvent> weeklyEvents;
  final String galleryOwnerId;

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
    required this.onEditPhoto,
    required this.photoUploading,
    required this.uploadedProfilePhotoUrl,
    required this.socialEditable,
    required this.onAddSocialLink,
    required this.descriptionEditable,
    required this.onSaveDescription,
    required this.ownerMode,
    required this.onEditProfilePressed,
    required this.venueEditable,
    required this.onEditVenues,
    required this.onEditEvents,
    required this.weeklyEvents,
    required this.galleryOwnerId,
  });

  List<VenueActiveMusician> _resolveVenues() {
    if (activeVenues != null && activeVenues!.isNotEmpty) {
      return activeVenues!;
    }
    if (profile.activeVenues.isNotEmpty) {
      return profile.activeVenues
          .map(
            (item) => VenueActiveMusician(
              musicianProfileId: '',
              displayName: item,
              profileImageUrl: null,
            ),
          )
          .toList();
    }
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

  Future<void> _showOwnerQuickMenu(BuildContext context) async {
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Kapat',
      barrierColor: Colors.black.withValues(alpha: 0.35),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        return Align(
          alignment: Alignment.centerRight,
          child: FractionallySizedBox(
            widthFactor: 0.58,
            heightFactor: 1,
            child: Material(
              color: Colors.transparent,
              child: Container(
                decoration: const BoxDecoration(
                  color: AppColors.navBlueDeep,
                  borderRadius: BorderRadius.horizontal(
                    left: Radius.circular(20),
                  ),
                ),
                child: SafeArea(
                  left: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 10, 10, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: const [
                        SizedBox(height: 8),
                        Opacity(
                          opacity: 0.72,
                          child: ListTile(
                            enabled: false,
                            leading: Icon(Icons.settings_outlined),
                            title: Text('Ayarlar'),
                          ),
                        ),
                        Opacity(
                          opacity: 0.72,
                          child: ListTile(
                            enabled: false,
                            leading: Icon(Icons.assignment_outlined),
                            title: Text('Başvurularım'),
                          ),
                        ),
                        Opacity(
                          opacity: 0.72,
                          child: ListTile(
                            enabled: false,
                            leading: Icon(Icons.groups_outlined),
                            title: Text('Gruplarım'),
                          ),
                        ),
                        Spacer(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: Tween<double>(begin: 0, end: 1).animate(curved),
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(1.06, 0),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  Future<void> _openVenueManagementPanel(BuildContext context) async {
    final ownerProfile = context.read<VenueProfileCubit>().state.ownerProfile;
    if (ownerProfile == null) return;
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => VenueManagementPanelScreen(
          ownerProfile: ownerProfile,
          openWeeklyCalendar: (context) {
            return Navigator.of(context).push<bool>(
              MaterialPageRoute(
                builder: (_) => VenueWeeklyCalendarEditorScreen(
                  ownerProfile: ownerProfile,
                ),
              ),
            );
          },
          openConnectedArtists: (_) async {
            await onEditEvents?.call();
          },
        ),
      ),
    );
    if (changed == true && context.mounted) {
      await context.read<VenueProfileCubit>().loadOwner(
        venueId: ownerProfile.venueId,
      );
    }
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
          actions: ownerMode
              ? [
                  IconButton(
                    tooltip: 'Menu',
                    onPressed: () => _showOwnerQuickMenu(context),
                    icon: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.asset(
                        'assets/logo.png',
                        width: 34,
                        height: 34,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ]
              : null,
        ),
        body: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ProfileTopSection(
                header: _ProfileHeader(
                  profile: profile,
                  onEditPhoto: onEditPhoto,
                  uploading: photoUploading,
                  uploadedPhotoUrl: uploadedProfilePhotoUrl,
                ),
                identity: ProfileIdentityHeader(
                  username: profile.username,
                  secondaryText:
                      profile.bands.isNotEmpty ? profile.bands.first : null,
                  fallbackName: 'Kullanıcı',
                ),
                followerSummary: ProfileFollowerSummary(
                  followersCount: followersCount,
                  followingCount: followingCount,
                ),
                actionButtons: ProfileActionButtons(
                  isFollowing: isFollowing,
                  isEnabled: canFollow,
                  isLoading: followLoading,
                  ownerMode: ownerMode,
                  onEditProfilePressed: onEditProfilePressed,
                  onFollowToggle: () {
                    if (!canFollow) return;
                    context.read<FollowActionCubit>().toggleFollow(
                      followerId: viewerUserId,
                      followingId: profile.userId,
                    );
                  },
                ),
                bioSection: EditableBioSection(
                  bio: profile.bio,
                  editable: descriptionEditable,
                  onSave: onSaveDescription,
                ),
                afterBio: ownerMode
                    ? Padding(
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
                                  onPressed: () =>
                                      _openVenueManagementPanel(context),
                                  style: TextButton.styleFrom(
                                    foregroundColor: AppColors.white,
                                    backgroundColor: Colors.transparent,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(18),
                                    ),
                                  ),
                                  icon: const Icon(
                                    Icons.dashboard_customize_outlined,
                                    color: AppColors.white,
                                  ),
                                  label: const Text(
                                    'Yönetim Paneli',
                                    style: TextStyle(color: AppColors.white),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      )
                    : null,
              ),
              const SizedBox(height: 18),
              const ProfileSectionHeader(title: 'Haftalık Takvim'),
              WeeklyEventCarousel(items: weeklyEvents),
              const SizedBox(height: 12),
              ProfileSectionHeader(
                title: 'Aktif Sanatçılar',
                actionLabel: venueEditable ? 'Düzenle' : 'Tümü',
                actionOnTap: venueEditable ? onEditVenues : null,
              ),
              ActiveMusicianCarousel(
                items: _resolveVenues(),
                editable: venueEditable,
                onAddTap: onEditVenues,
              ),
              const SizedBox(height: 12),
              const ProfileMediaTabs(
                tabs: [
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
              _MediaContent(
                media: resolvedMedia,
                profileId: profile.id,
                galleryOwnerId: galleryOwnerId,
                spotifyTracks: const [],
                spotifyLoading: spotifyLoading,
                ownerMode: ownerMode,
              ),
              const SizedBox(height: 18),
              ProfileSocialButtonRow(
                pillWidth: 74,
                profile: profile,
                editable: socialEditable,
                onAddLink: onAddSocialLink,
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
        bottomNavigationBar: ProfileBottomBar(
          profileImageUrl: (uploadedProfilePhotoUrl?.trim().isNotEmpty == true)
              ? uploadedProfilePhotoUrl!.trim()
              : profile.profilePicture,
        ),
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  final MusicianProfile profile;
  final VoidCallback? onEditPhoto;
  final bool uploading;
  final String? uploadedPhotoUrl;

  const _ProfileHeader({
    required this.profile,
    this.onEditPhoto,
    this.uploading = false,
    this.uploadedPhotoUrl,
  });

  @override
  Widget build(BuildContext context) {
    final candidate = (uploadedPhotoUrl?.trim().isNotEmpty == true)
        ? uploadedPhotoUrl!.trim()
        : (profile.profilePicture?.trim() ?? '');
    final hasRemotePhoto = candidate.startsWith('http');

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
                child: hasRemotePhoto
                    ? Image.network(candidate, fit: BoxFit.cover)
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
              child: GestureDetector(
                onTap: uploading ? null : onEditPhoto,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: AppColors.brandGradient,
                    ),
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.navBlueDeep, width: 2),
                  ),
                  child: uploading
                      ? const Padding(
                          padding: EdgeInsets.all(6),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.white,
                          ),
                        )
                      : const Icon(
                          Icons.edit,
                          size: 14,
                          color: AppColors.white,
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

class _BioSection extends StatefulWidget {
  final String? bio;
  final bool editable;
  final Future<void> Function(String)? onSave;

  const _BioSection({
    required this.bio,
    required this.editable,
    required this.onSave,
  });

  @override
  State<_BioSection> createState() => _BioSectionState();
}

class _BioSectionState extends State<_BioSection> {
  bool _isEditing = false;
  bool _saving = false;
  String _draft = '';

  @override
  void didUpdateWidget(covariant _BioSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isEditing && oldWidget.bio != widget.bio) {
      _draft = widget.bio?.trim() ?? '';
    }
  }

  Future<void> _handleSave() async {
    if (widget.onSave == null) return;
    setState(() => _saving = true);
    try {
      await widget.onSave!(_draft);
      if (!mounted) return;
      setState(() => _isEditing = false);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasBio = widget.bio?.trim().isNotEmpty == true;
    final resolvedBio = hasBio ? widget.bio!.trim() : '';

    if (!widget.editable) {
      return Text(
        hasBio ? resolvedBio : 'Henüz bir açıklama eklenmedi.',
        textAlign: TextAlign.center,
        style: const TextStyle(color: AppColors.textMuted, height: 1.6),
      );
    }

    if (!_isEditing) {
      if (!hasBio) {
        return TextButton(
          onPressed: () {
            setState(() {
              _draft = '';
              _isEditing = true;
            });
          },
          child: const Text('Açıklama ekle'),
        );
      }

      return Stack(
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 4, right: 20),
            child: SizedBox(
              width: double.infinity,
              child: Text(
                resolvedBio,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textMuted, height: 1.6),
              ),
            ),
          ),
          Positioned(
            right: 0,
            top: 0,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                setState(() {
                  _draft = widget.bio?.trim() ?? '';
                  _isEditing = true;
                });
              },
              child: const Padding(
                padding: EdgeInsets.all(2),
                child: Icon(Icons.edit, size: 14, color: AppColors.textMuted),
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        TextFormField(
          initialValue: _draft,
          minLines: 3,
          maxLines: 6,
          textInputAction: TextInputAction.newline,
          decoration: InputDecoration(
            hintText: 'Kendinden bahset...',
            filled: true,
            fillColor: AppColors.inputFill,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.coralAlt),
            ),
          ),
          style: const TextStyle(color: AppColors.textPrimary),
          onChanged: (value) => _draft = value,
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton(
              onPressed: _saving
                  ? null
                  : () => setState(() => _isEditing = false),
              child: const Text('\u0130ptal'),
            ),
            const SizedBox(width: 10),
            FilledButton(
              onPressed: _saving ? null : _handleSave,
              child: _saving
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Kaydet'),
            ),
          ],
        ),
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
        ProfilePillBadge(text: _formatCount(followersCount, 'Takipçi')),
        const SizedBox(width: 12),
        ProfilePillBadge(text: _formatCount(followingCount, 'Takip')),
      ],
    );
  }
}

class _ActiveMusicianCarousel extends StatelessWidget {
  final List<VenueActiveMusician> items;
  final bool editable;
  final VoidCallback? onAddTap;

  const _ActiveMusicianCarousel({
    required this.items,
    this.editable = false,
    this.onAddTap,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      if (editable && onAddTap != null) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: onAddTap,
              icon: const Icon(Icons.add_circle_outline, size: 18),
              label: const Text('Mekan Ekle'),
            ),
          ),
        );
      }
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
          final musician = items[index];
          final imageUrl = musician.profileImageUrl?.trim();
          final hasImage =
              imageUrl != null &&
              (imageUrl.startsWith('http://') || imageUrl.startsWith('https://'));
          return InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: musician.musicianProfileId.trim().isEmpty
                ? null
                : () {
                    Navigator.of(context).pushNamed(
                      AppRoutes.musicianPublicProfile,
                      arguments: {'profileId': musician.musicianProfileId},
                    );
                  },
            child: Container(
              width: 170,
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
                    width: 36,
                    height: 36,
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
                    child: ClipOval(
                      child: hasImage
                          ? Image.network(imageUrl, fit: BoxFit.cover)
                          : const Icon(
                              Icons.person_outline,
                              color: AppColors.coralAlt,
                              size: 20,
                            ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        GradientText(
                          text: musician.displayName,
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
      description: 'Haftalık akustik repertuvar gecesi.',
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
                padding: const EdgeInsets.all(8),
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
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w700,
                              height: 1.15,
                            ),
                          ),
                          const SizedBox(height: 4),
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
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
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
                                    fontSize: 11,
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
  final String profileId;
  final String galleryOwnerId;
  final List<SpotifyTrackPreview> spotifyTracks;
  final bool spotifyLoading;
  final bool ownerMode;

  const _MediaContent({
    required this.media,
    required this.profileId,
    required this.galleryOwnerId,
    required this.spotifyTracks,
    required this.spotifyLoading,
    required this.ownerMode,
  });

  Future<void> _addGalleryPhoto(BuildContext context) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 94,
      maxWidth: 2400,
    );
    if (picked == null) return;

    try {
      final bytes = await File(picked.path).readAsBytes();
      if (bytes.isEmpty) {
        throw Exception('Seçilen fotoğraf okunamadı');
      }
      final fileName = fileNameFromPath(picked.path, fallback: picked.name);
      final uploaded = await uploadProfileMediaAsset(
        bytes: bytes,
        ownerType: 'VENUE_PROFILE',
        ownerId: galleryOwnerId,
        mediaKind: 'IMAGE',
        mimeType: inferImageMimeType(fileName),
        originalFileName: fileName,
      );
      final assetId = uploaded.uuid.trim();
      if (assetId.isEmpty) {
        throw Exception('Medya kimliği alınamadı');
      }

      final profileMediaRepository =
          serviceLocator<ProfileMediaManagementRepository>();
      final attachResult = await profileMediaRepository.addGalleryMedia(
        profileType: 'VENUE',
        profileId: galleryOwnerId,
        mediaAssetId: assetId,
      );
      if (!attachResult.isSuccess) {
        throw Exception(
          attachResult.error?.message ?? 'Fotoğraf galeriye eklenemedi',
        );
      }

      await context.read<ProfileMediaCubit>().loadMedia(
        profileType: 'VENUE',
        profileId: galleryOwnerId,
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Fotoğraf eklendi')));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Fotoğraf eklenemedi: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final imageItems = media.videos
        .where((item) => (item.kind ?? '').toUpperCase() == 'IMAGE')
        .toList(growable: false);
    final featuredVideo = media.featuredVideo;
    final videoItems = <MediaAsset>[
      if (featuredVideo != null) featuredVideo,
      ...media.videos.where(
        (item) =>
            (item.kind ?? '').toUpperCase() == 'VIDEO' &&
            (featuredVideo == null || item.id != featuredVideo.id),
      ),
    ];
    final controller = DefaultTabController.of(context);

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return IndexedStack(
          index: controller.index,
          children: [
            ProfilePhotoGalleryTab(
              items: imageItems,
              ownerMode: ownerMode,
              onAddPhoto: ownerMode ? () => _addGalleryPhoto(context) : null,
            ),
            ProfileOwnerVideoTab(
              items: videoItems,
              profileId: galleryOwnerId,
              ownerMode: ownerMode,
              profileType: 'VENUE',
              uploadOwnerType: 'VENUE_PROFILE',
            ),
          ],
        );
      },
    );
  }
}

class _AudioTab extends StatelessWidget {
  final List<Track> items;
  final String profileId;

  final List<SpotifyTrackPreview> spotifyTracks;
  final bool spotifyLoading;
  final bool ownerMode;
  final AudioHandler audioHandler;

  const _AudioTab({
    required this.items,
    required this.profileId,
    required this.spotifyTracks,
    required this.spotifyLoading,
    required this.ownerMode,
    required this.audioHandler,
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
        var query = '';
        var results = <SpotifyTrackPreview>[];
        var errorText = '';
        final existingIds = currentTracks.map((e) => e.id).toSet();

        return StatefulBuilder(
          builder: (context, setSheetState) {
            Future<void> runSearch() async {
              final q = queryController.text.trim();
              final token = ++lastSearchToken;
              if (q.length < 2) {
                setSheetState(() {
                  query = q;
                  results = const [];
                  errorText = 'En az 2 karakter yaz.';
                });
                return;
              }
              setSheetState(() {
                loading = true;
                query = q;
                errorText = '';
              });
              final result = await repository.searchTracks(q, limit: 10);
              if (!sheetContext.mounted || token != lastSearchToken) return;
              setSheetState(() {
                loading = false;
                if (result.isSuccess && result.data != null) {
                  results = result.data!;
                  if (results.isEmpty) {
                    errorText = 'Sonuç bulunamadı.';
                  }
                } else {
                  errorText = result.error?.message ?? 'Arama başarısız.';
                }
              });
            }

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
                            hintText: 'Spotify parça ara...',
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
                        if (!loading && results.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(
                              '${results.length} sonuç',
                              style: const TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 12,
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
    // Intentionally not disposing here; route teardown can still touch TextField
    // listeners for a frame and trigger "used after being disposed" assertion.
    return selected;
  }

  Future<void> _addSpotifyTrackFromCatalog(BuildContext context) async {
    final selected = await _showSpotifyTrackPicker(context, spotifyTracks);
    if (selected == null) return;
    final existingIds = spotifyTracks.map((e) => e.id).toSet();
    if (existingIds.contains(selected.id)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Bu parça zaten ekli.')));
      return;
    }
    final nextTracks = [...spotifyTracks, selected];
    final nextTrackIds = nextTracks.map((e) => e.id).toList();
    final nextTrackMaps = nextTracks.map(_trackToSaveJson).toList();

    final cubit = context.read<MusicianProfileCubit>();
    await cubit.updateProfile(
      MusicianProfileSaveRequest(
        spotifyTrackIds: nextTrackIds,
        spotifyTracks: nextTrackMaps,
      ),
    );
    if (!context.mounted) return;
    if (cubit.state.status == MusicianProfileStatus.failure) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            cubit.state.error?.message ?? 'Spotify parçası eklenemedi.',
          ),
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Şarkı başarıyla eklendi.')),
    );
  }

  Future<bool> _removeSpotifyTrackFromCatalog(
    BuildContext context,
    String trackId, {
    List<SpotifyTrackPreview>? sourceTracks,
    bool showSnackbar = true,
  }) async {
    final baseTracks = sourceTracks ?? spotifyTracks;
    final nextTracks = baseTracks.where((e) => e.id != trackId).toList();
    if (nextTracks.length == baseTracks.length) return false;

    final nextTrackIds = nextTracks.map((e) => e.id).toList();
    final nextTrackMaps = nextTracks.map(_trackToSaveJson).toList();

    final cubit = context.read<MusicianProfileCubit>();
    await cubit.updateProfile(
      MusicianProfileSaveRequest(
        spotifyTrackIds: nextTrackIds,
        spotifyTracks: nextTrackMaps,
      ),
    );
    if (!context.mounted) return false;
    if (cubit.state.status == MusicianProfileStatus.failure) {
      if (showSnackbar) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              cubit.state.error?.message ?? 'Spotify parçası silinemedi.',
            ),
          ),
        );
      }
      return false;
    }
    if (showSnackbar) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Spotify parçası kaldırıldı.')),
      );
    }
    return true;
  }

  Future<void> _showSoundConnectTrackUploadSheet(
    BuildContext hostContext,
  ) async {
    await showProfileTrackUploadSheet(
      hostContext: hostContext,
      profileId: profileId,
      ownerType: 'VENUE_PROFILE',
      profileType: 'VENUE',
    );
  }

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
    BuildContext hostContext,
    List<SpotifyTrackPreview> tracks,
  ) async {
    if (tracks.isEmpty && !ownerMode) return;
    final visibleTracks = List<SpotifyTrackPreview>.from(tracks);
    await showModalBottomSheet<void>(
      context: hostContext,
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
            Future<bool> saveTracks(
              List<SpotifyTrackPreview> nextTracks, {
              required String failureMessage,
            }) async {
              final nextTrackIds = nextTracks.map((e) => e.id).toList();
              final nextTrackMaps = nextTracks.map(_trackToSaveJson).toList();
              final cubit = hostContext.read<MusicianProfileCubit>();
              await cubit.updateProfile(
                MusicianProfileSaveRequest(
                  spotifyTrackIds: nextTrackIds,
                  spotifyTracks: nextTrackMaps,
                ),
              );
              if (!sheetContext.mounted) return false;
              if (cubit.state.status == MusicianProfileStatus.failure) {
                setSheetState(() {
                  feedbackText = cubit.state.error?.message ?? failureMessage;
                  feedbackIsError = true;
                });
                return false;
              }
              return true;
            }

            Future<void> removeTrack(SpotifyTrackPreview track) async {
              final success = await _removeSpotifyTrackFromCatalog(
                hostContext,
                track.id,
                sourceTracks: visibleTracks,
                showSnackbar: false,
              );
              if (!success || !sheetContext.mounted) return;
              setSheetState(() {
                visibleTracks.removeWhere((e) => e.id == track.id);
                feedbackText = 'Spotify parçası kaldırıldı.';
                feedbackIsError = false;
              });
            }

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
                              'Sanatçının Spotify Kataloğu',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          if (ownerMode)
                            IconButton(
                              tooltip: 'Spotify parçası ekle',
                              onPressed: () async {
                                final selected = await _showSpotifyTrackPicker(
                                  hostContext,
                                  visibleTracks,
                                );
                                if (selected == null || !sheetContext.mounted) {
                                  return;
                                }
                                if (visibleTracks.any(
                                  (element) => element.id == selected.id,
                                )) {
                                  setSheetState(() {
                                    feedbackText = 'Bu parça zaten ekli.';
                                    feedbackIsError = true;
                                  });
                                  return;
                                }
                                final nextTracks = [...visibleTracks, selected];
                                final ok = await saveTracks(
                                  nextTracks,
                                  failureMessage:
                                      'Spotify parçası eklenemedi.',
                                );
                                if (!ok || !sheetContext.mounted) return;
                                setSheetState(() {
                                  visibleTracks.add(selected);
                                  feedbackText = 'Spotify parçası eklendi.';
                                  feedbackIsError = false;
                                });
                              },
                              icon: const Icon(
                                Icons.add_circle_outline,
                                color: AppColors.textMuted,
                              ),
                            ),
                        ],
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
                                  'Henüz Spotify parçası eklemediniz.',
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
                                    key: ValueKey('spotify-track-${track.id}'),
                                    direction: ownerMode
                                        ? DismissDirection.endToStart
                                        : DismissDirection.none,
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
                                    confirmDismiss: ownerMode
                                        ? (_) async {
                                            final success =
                                                await _removeSpotifyTrackFromCatalog(
                                                  hostContext,
                                                  track.id,
                                                  sourceTracks: visibleTracks,
                                                  showSnackbar: false,
                                                );
                                            if (!success ||
                                                !sheetContext.mounted) {
                                              return false;
                                            }
                                            setSheetState(() {
                                              visibleTracks.removeWhere(
                                                (e) => e.id == track.id,
                                              );
                                              feedbackText =
                                                  'Spotify parçası kaldırıldı.';
                                              feedbackIsError = false;
                                            });
                                            return true;
                                          }
                                        : null,
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
                                              hostContext,
                                              track.spotifyUrl,
                                            ),
                                            child: const Text(
                                              "Spotify'da Dinle",
                                              style: TextStyle(
                                                color: Color(0xFF1DB954),
                                              ),
                                            ),
                                          ),
                                          if (ownerMode)
                                            IconButton(
                                              tooltip: 'Katalogdan kaldır',
                                              onPressed: () =>
                                                  removeTrack(track),
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
                    onPressed: () async {
                      await _showSpotifyCatalog(context, spotifyPreviewItems);
                    },
                    icon: const Icon(
                      FontAwesomeIcons.spotify,
                      size: 16,
                      color: Colors.white,
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1DB954),
                      foregroundColor: Colors.white,
                    ),
                    label: const Text('Spotify Kataloğu'),
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
                          items.isEmpty
                              ? 'Henüz fotoğraf eklemediniz'
                              : 'Fotograf ekle',
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
                  'Kullanıcı henüz ses eklemedi.',
                  style: TextStyle(color: AppColors.textMuted),
                ),
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
                      ProfileAudioPreviewCard(
                        onTap: openDetails,
                        onDoubleTap: () {
                          if (!isLiked) {
                            toggleLike();
                          }
                        },
                        title: track.title,
                        actionLabel: isSpotify
                            ? "Tamam\u0131n\u0131 Spotify'da Dinle"
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
      actionLabel: "Tamam\u0131n\u0131 Spotify'da Dinle",
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

