// ignore_for_file: unused_element, unused_element_parameter, unused_local_variable, use_build_context_synchronously

import 'dart:io';
import 'dart:typed_data';
import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:audio_service/audio_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/audio/audio_player_handler.dart';
import '../../../../core/network/api_client.dart';
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
import '../../domain/entities/media_asset.dart';
import '../../domain/entities/musician_profile.dart';
import '../../domain/entities/profile_media.dart';
import '../../domain/entities/track.dart';
import '../../data/models/musician_profile_save_request.dart';
import '../cubit/musician_profile_cubit.dart';
import '../cubit/musician_profile_state.dart';
import '../cubit/profile_media_cubit.dart';
import '../../../spotify/domain/spotify_repository.dart';
import 'media_detail_screen.dart';
import 'profile_audio_transport.dart';
import 'profile_count_row.dart';
import 'profile_owner_video_tab.dart';
import 'profile_screen_support.dart';
import 'profile_section_support.dart';
import 'profile_social_support.dart';
import 'profile_venue_support.dart';

class PublicProfileArgs {
  final String? viewerUserId;

  const PublicProfileArgs({this.viewerUserId});
}

class MusicianProfileScreen extends StatelessWidget {
  const MusicianProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) =>
              serviceLocator<MusicianProfileCubit>()..loadMyProfile(),
        ),
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
  final _loadCoordinator = ProfileScreenLoadCoordinator();
  String? _viewerUserId;
  String? _currentProfileUserId;
  bool _photoUploading = false;
  String? _uploadedProfilePhotoUrl;
  final ImagePicker _imagePicker = ImagePicker();

  Future<void> _editProfilePhoto(MusicianProfile profile) async {
    setState(() => _photoUploading = true);
    try {
      final uploaded = await pickCropAndUploadProfilePhoto(
        context: context,
        imagePicker: _imagePicker,
        ownerType: 'MUSICIAN_PROFILE',
        ownerId: profile.id,
      );
      if (uploaded == null) return;
      await context.read<MusicianProfileCubit>().updateProfile(
        MusicianProfileSaveRequest(profilePicture: uploaded.assetId),
      );
      setState(() {
        _uploadedProfilePhotoUrl = uploaded.preferredUrl;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profil fotografi guncellendi')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Fotograf yuklenemedi: $e')));
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
        content: Text('Asagidaki alanlardan profilini düzenleyebilirsin.'),
      ),
    );
  }

  String? _extractId(Map<String, dynamic> item, String key) {
    final direct = item[key];
    if (direct != null && direct.toString().isNotEmpty) {
      return direct.toString();
    }
    final directUuid = item[key.replaceAll('Id', 'Uuid')];
    if (directUuid != null && directUuid.toString().isNotEmpty) {
      return directUuid.toString();
    }
    final nested = item[key.replaceAll('Id', '')];
    if (nested is Map<String, dynamic>) {
      final nestedId = nested['id'];
      if (nestedId != null && nestedId.toString().isNotEmpty) {
        return nestedId.toString();
      }
      final nestedUuid = nested['uuid'];
      if (nestedUuid != null && nestedUuid.toString().isNotEmpty) {
        return nestedUuid.toString();
      }
    }
    return null;
  }

  String? _extractName(Map<String, dynamic> item, String key) {
    final direct = item[key];
    if (direct != null && direct.toString().trim().isNotEmpty) {
      return direct.toString().trim();
    }
    final nested = item[key.replaceAll('Name', '')];
    if (nested is Map<String, dynamic>) {
      final nestedName = nested['name'];
      if (nestedName != null && nestedName.toString().trim().isNotEmpty) {
        return nestedName.toString().trim();
      }
    }
    return null;
  }

  Future<List<VenueOption>> _fetchAllVenues() async {
    final apiClient = serviceLocator<ApiClient>();
    return apiClient.get<List<VenueOption>>(
      '/api/v1/venues/get-all',
      decoder: (json) {
        final list = (json as List<dynamic>? ?? const []);
        return list
            .whereType<Map<String, dynamic>>()
            .map(
              (item) => VenueOption(
                id: item['id']?.toString() ?? '',
                name: item['name']?.toString() ?? '',
                profilePictureUrl:
                    item['profilePictureUrl']?.toString() ??
                    item['profilePicture']?.toString() ??
                    item['imageUrl']?.toString(),
                cityId: _extractId(item, 'cityId'),
                districtId: _extractId(item, 'districtId'),
                neighborhoodId: _extractId(item, 'neighborhoodId'),
                cityName: _extractName(item, 'cityName'),
                districtName: _extractName(item, 'districtName'),
                neighborhoodName: _extractName(item, 'neighborhoodName'),
              ),
            )
            .where((item) => item.id.isNotEmpty && item.name.isNotEmpty)
            .toList();
      },
    );
  }

  Future<List<VenueLookupOption>> _fetchCities() async {
    final apiClient = serviceLocator<ApiClient>();
    return apiClient.get<List<VenueLookupOption>>(
      '/api/v1/cities/get-all-cities',
      decoder: (json) {
        final list = (json as List<dynamic>? ?? const []);
        return list
            .whereType<Map<String, dynamic>>()
            .map(
              (item) => VenueLookupOption(
                id: item['id']?.toString() ?? '',
                name: item['name']?.toString() ?? '',
              ),
            )
            .where((item) => item.id.isNotEmpty && item.name.isNotEmpty)
            .toList();
      },
    );
  }

  Future<List<VenueLookupOption>> _fetchDistricts(String cityId) async {
    final apiClient = serviceLocator<ApiClient>();
    return apiClient.get<List<VenueLookupOption>>(
      '/api/v1/districts/get-by-city/$cityId',
      decoder: (json) {
        final list = (json as List<dynamic>? ?? const []);
        return list
            .whereType<Map<String, dynamic>>()
            .map(
              (item) => VenueLookupOption(
                id: item['id']?.toString() ?? '',
                name: item['name']?.toString() ?? '',
              ),
            )
            .where((item) => item.id.isNotEmpty && item.name.isNotEmpty)
            .toList();
      },
    );
  }

  Future<List<VenueLookupOption>> _fetchNeighborhoods(String districtId) async {
    final apiClient = serviceLocator<ApiClient>();
    return apiClient.get<List<VenueLookupOption>>(
      '/api/v1/neighborhoods/get-by-district/$districtId',
      decoder: (json) {
        final list = (json as List<dynamic>? ?? const []);
        return list
            .whereType<Map<String, dynamic>>()
            .map(
              (item) => VenueLookupOption(
                id: item['id']?.toString() ?? '',
                name: item['name']?.toString() ?? '',
              ),
            )
            .where((item) => item.id.isNotEmpty && item.name.isNotEmpty)
            .toList();
      },
    );
  }

  Future<List<VenueConnection>> _fetchVenueConnectionsByStatus(
    String profileId, {
    required String status,
  }) async {
    final apiClient = serviceLocator<ApiClient>();
    return apiClient.get<List<VenueConnection>>(
      '/api/v1/artist-venue-connections/musician/$profileId?status=$status',
      decoder: (json) {
        final list = (json as List<dynamic>? ?? const []);
        return list
            .whereType<Map<String, dynamic>>()
            .map(
              (item) => VenueConnection(
                requestId: item['id']?.toString() ?? '',
                venueId: item['venueId']?.toString() ?? '',
                venueName: item['venueName']?.toString() ?? '',
              ),
            )
            .where(
              (item) => item.requestId.isNotEmpty && item.venueId.isNotEmpty,
            )
            .toList();
      },
    );
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
                                              CircleAvatar(
                                                radius: 18,
                                                backgroundColor:
                                                    AppColors.navBlueSoft,
                                                backgroundImage:
                                                    isValidNetworkImageUrl(
                                                          venue
                                                              .profilePictureUrl,
                                                        )
                                                        ? NetworkImage(
                                                            venue
                                                                .profilePictureUrl!,
                                                          )
                                                        : null,
                                                child: !isValidNetworkImageUrl(
                                                      venue.profilePictureUrl,
                                                    )
                                                    ? const Icon(
                                                        Icons.storefront_outlined,
                                                        color: AppColors
                                                            .textMuted,
                                                        size: 18,
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
                                  child: const Text('İptal'),
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
                                                                'İstersen kısa bir not ekleyebilirsin (zorunlu değil).',
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
                                                              'Vazgeç',
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
                                                              'Gönder',
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

      final apiClient = serviceLocator<ApiClient>();
      await apiClient.post<Object>(
        '/api/v1/artist-venue-connections/request?requestByType=ARTIST',
        body: {
          'musicianProfileId': profileId,
          'venueId': selected.venueId,
          'message': selected.message,
        },
      );

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
          final isInitialLoading =
              state.status == MusicianProfileStatus.loading &&
              state.profile == null;
          if (isInitialLoading) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          if (state.profile == null) {
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
            onEditPhoto: () => _editProfilePhoto(profile),
            photoUploading: _photoUploading,
            uploadedProfilePhotoUrl: _uploadedProfilePhotoUrl,
            socialEditable: true,
            onAddSocialLink: (platform) => _addSocialLink(profile, platform),
            descriptionEditable: true,
            onSaveDescription: _saveDescription,
            ownerMode: true,
            onEditProfilePressed: _onEditProfilePressed,
            venueEditable: true,
            onEditVenues: () => _editVenues(profile.id),
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
                            title: Text('Bandlerim'),
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
                    tooltip: 'Menü',
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
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.center,
                child: _ProfileHeader(
                  profile: profile,
                  onEditPhoto: onEditPhoto,
                  uploading: photoUploading,
                  uploadedPhotoUrl: uploadedProfilePhotoUrl,
                ),
              ),
              const SizedBox(height: 16),
              _ProfileIdentity(profile: profile),
              const SizedBox(height: 14),
              _FollowerRow(
                followersCount: followersCount,
                followingCount: followingCount,
              ),
              const SizedBox(height: 12),
              ProfileActionButtons(
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
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: _BioSection(
                  bio: profile.bio,
                  editable: descriptionEditable,
                  onSave: onSaveDescription,
                ),
              ),
              const SizedBox(height: 18),
              ProfileSectionHeader(
                title: 'Çaldığı Mekanlar',
                actionLabel: venueEditable ? 'Düzenle' : 'Tümü',
                actionOnTap: venueEditable ? onEditVenues : null,
              ),
              _VenueCarousel(
                items: _resolveVenues(),
                editable: venueEditable,
                onAddTap: onEditVenues,
              ),
              const SizedBox(height: 12),
              _MediaTabs(),
              _MediaContent(
                media: resolvedMedia,
                profileId: profile.id,
                spotifyTracks: spotifyTracks,
                spotifyLoading: spotifyLoading,
                ownerMode: ownerMode,
              ),
              const SizedBox(height: 18),
              ProfileSocialButtonRow(
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
        ProfilePillBadge(text: _formatCount(followersCount, 'Takipci')),
        const SizedBox(width: 12),
        ProfilePillBadge(text: _formatCount(followingCount, 'Takip')),
      ],
    );
  }
}

class _VenueCarousel extends StatelessWidget {
  final List<String> items;
  final bool editable;
  final VoidCallback? onAddTap;

  const _VenueCarousel({
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
  final List<SpotifyTrackPreview> spotifyTracks;
  final bool spotifyLoading;
  final bool ownerMode;

  const _MediaContent({
    required this.media,
    required this.profileId,
    required this.spotifyTracks,
    required this.spotifyLoading,
    required this.ownerMode,
  });

  @override
  Widget build(BuildContext context) {
    final audioItems = media.audios;
    final featuredVideo = media.featuredVideo;
    final videoItems = <MediaAsset>[
      if (featuredVideo != null) featuredVideo,
      ...media.videos.where(
        (item) => featuredVideo == null || item.id != featuredVideo.id,
      ),
    ];
    final controller = DefaultTabController.of(context);
    final audioHandler = serviceLocator<AudioHandler>();

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return IndexedStack(
          index: controller.index,
          children: [
            _AudioTab(
              items: audioItems,
              profileId: profileId,
              spotifyTracks: spotifyTracks,
              spotifyLoading: spotifyLoading,
              ownerMode: ownerMode,
              audioHandler: audioHandler,
            ),
            ProfileOwnerVideoTab(
              items: videoItems,
              profileId: profileId,
              ownerMode: ownerMode,
              profileType: 'MUSICIAN',
              uploadOwnerType: 'MUSICIAN_PROFILE',
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

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Şarkı başarıyla eklendi.')));
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

  String _mimeFromAudioFileName(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.mp3')) return 'audio/mpeg';
    if (lower.endsWith('.m4a')) return 'audio/mp4';
    if (lower.endsWith('.aac')) return 'audio/aac';
    if (lower.endsWith('.wav')) return 'audio/wav';
    if (lower.endsWith('.waw')) return 'audio/wav';
    if (lower.endsWith('.ogg')) return 'audio/ogg';
    if (lower.endsWith('.flac')) return 'audio/flac';
    return 'audio/mpeg';
  }

  String _fileNameFromPath(String path, {String fallback = 'audio.mp3'}) {
    final normalized = path.replaceAll('\\', '/');
    final parts = normalized.split('/');
    final name = parts.isNotEmpty ? parts.last.trim() : '';
    return name.isEmpty ? fallback : name;
  }

  String _titleFromFileName(String fileName) {
    final idx = fileName.lastIndexOf('.');
    if (idx <= 0) return fileName;
    return fileName.substring(0, idx);
  }

  Future<void> _showSoundConnectTrackUploadSheet(
    BuildContext hostContext,
  ) async {
    String? pickedPath;
    Uint8List? pickedBytes;
    String? pickedName;
    final titleController = TextEditingController();
    bool uploading = false;
    String? infoText;
    bool infoError = false;

    await showModalBottomSheet<void>(
      context: hostContext,
      isScrollControlled: true,
      backgroundColor: AppColors.navBlueDeep,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            Future<void> pickAudio() async {
              final result = await FilePicker.platform.pickFiles(
                type: FileType.custom,
                withData: true,
                allowMultiple: false,
                allowedExtensions: const [
                  'mp3',
                  'm4a',
                  'aac',
                  'wav',
                  'waw',
                  'ogg',
                  'flac',
                ],
              );
              final file = result?.files.isNotEmpty == true
                  ? result!.files.first
                  : null;
              if (file == null) return;
              final name = file.name.trim().isNotEmpty
                  ? file.name.trim()
                  : (file.path != null
                        ? _fileNameFromPath(file.path!)
                        : 'audio.mp3');
              setSheetState(() {
                pickedPath = file.path;
                pickedBytes = file.bytes;
                pickedName = name;
                if (titleController.text.trim().isEmpty) {
                  titleController.text = _titleFromFileName(name);
                }
              });
            }

            Future<void> uploadTrack() async {
              var step = 'dosya okuma';
              final path = pickedPath;
              final bytesFromPicker = pickedBytes;
              final name = pickedName;
              final title = titleController.text.trim();
              if ((path == null && bytesFromPicker == null) || name == null) {
                setSheetState(() {
                  infoText = 'Önce bir ses dosyası seç.';
                  infoError = true;
                });
                return;
              }
              if (title.isEmpty) {
                setSheetState(() {
                  infoText = '\u015Eark\u0131 ad\u0131 zorunlu.';
                  infoError = true;
                });
                return;
              }

              setSheetState(() {
                uploading = true;
                infoText = null;
                infoError = false;
              });

              try {
                final bytes =
                    bytesFromPicker ?? await File(path!).readAsBytes();
                if (bytes.isEmpty) {
                  throw Exception('Dosya okunamadı');
                }
                final apiClient = serviceLocator<ApiClient>();
                final mimeType = _mimeFromAudioFileName(name);

                step = 'init-upload';
                final completed = await uploadProfileMediaAsset(
                  bytes: bytes,
                  ownerType: 'MUSICIAN_PROFILE',
                  ownerId: profileId,
                  mediaKind: 'AUDIO',
                  mimeType: mimeType,
                  originalFileName: name,
                );

                step = 'complete-upload';
                final mediaAssetId = completed.uuid.trim();
                if (mediaAssetId.isEmpty) {
                  throw Exception('Media asset id alınamadı');
                }

                step = 'track oluşturma';
                await apiClient.post<Object>(
                  '/api/v1/musician-profiles/$profileId/tracks',
                  body: {
                    'mediaAssetId': mediaAssetId,
                    'title': title,
                    'durationSeconds': null,
                    'bpm': null,
                  },
                );

                try {
                  await context.read<ProfileMediaCubit>().loadMedia(
                    profileType: 'MUSICIAN',
                    profileId: profileId,
                  );
                } catch (_) {
                  // Track başarıyla oluştuysa liste yenileme hatası non-fatal.
                }
                if (!sheetContext.mounted) return;
                Navigator.of(sheetContext).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      '\u015Eark\u0131 ba\u015Far\u0131yla eklendi.',
                    ),
                  ),
                );
              } catch (e) {
                if (!sheetContext.mounted) return;
                setSheetState(() {
                  infoText = 'Yükleme başarısız ($step): $e';
                  infoError = true;
                });
              } finally {
                if (sheetContext.mounted) {
                  setSheetState(() => uploading = false);
                }
              }
            }

            return AnimatedPadding(
              duration: const Duration(milliseconds: 180),
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'SoundConnect \u00FCzerinden \u015Fark\u0131 Ekle',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: uploading ? null : pickAudio,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textPrimary,
                          side: const BorderSide(color: AppColors.border),
                          backgroundColor: AppColors.inputFill,
                        ),
                        icon: const Icon(Icons.library_music_outlined),
                        label: Text(
                          pickedName == null ? 'Ses Dosyası Seç' : pickedName!,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        enabled: !uploading,
                        controller: titleController,
                        cursorColor: AppColors.textPrimary,
                        decoration: InputDecoration(
                          hintText: '\u015Eark\u0131 ad\u0131',
                          filled: true,
                          fillColor: AppColors.inputFill,
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: AppColors.border,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: AppColors.border,
                            ),
                          ),
                          disabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: AppColors.border,
                            ),
                          ),
                        ),
                      ),
                      if (infoText != null) ...[
                        const SizedBox(height: 10),
                        Text(
                          infoText!,
                          style: TextStyle(
                            color: infoError
                                ? const Color(0xFFFFB4B4)
                                : AppColors.textMuted,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: uploading
                                  ? null
                                  : () => Navigator.of(sheetContext).pop(),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.textPrimary,
                                side: const BorderSide(color: AppColors.border),
                                backgroundColor: AppColors.inputFill,
                              ),
                              child: const Text('\u0130ptal'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: uploading ? null : uploadTrack,
                              style: ElevatedButton.styleFrom(
                                foregroundColor: AppColors.textPrimary,
                                backgroundColor: AppColors.navBlueSoft,
                                disabledForegroundColor: AppColors.textMuted,
                                disabledBackgroundColor: AppColors.inputFill
                                    .withValues(alpha: 0.8),
                              ),
                              child: uploading
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text('Yükle'),
                            ),
                          ),
                        ],
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
                                  failureMessage: 'Spotify parçası eklenemedi.',
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
              if (ownerMode || spotifyPreviewItems.isNotEmpty) ...[
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
                          items.isEmpty ? 'Henüz ses eklemediniz' : 'Ses ekle',
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
                      _AudioPreviewCard(
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
                          width: 64,
                          height: 64,
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

