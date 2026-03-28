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
import 'profile_screen_support.dart';
import 'profile_social_support.dart';
import 'video_reel_screen.dart';

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

  Future<List<_VenueOption>> _fetchAllVenues() async {
    final apiClient = serviceLocator<ApiClient>();
    return apiClient.get<List<_VenueOption>>(
      '/api/v1/venues/get-all',
      decoder: (json) {
        final list = (json as List<dynamic>? ?? const []);
        return list
            .whereType<Map<String, dynamic>>()
            .map(
              (item) => _VenueOption(
                id: item['id']?.toString() ?? '',
                name: item['name']?.toString() ?? '',
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

  Future<List<_LookupOption>> _fetchCities() async {
    final apiClient = serviceLocator<ApiClient>();
    return apiClient.get<List<_LookupOption>>(
      '/api/v1/cities/get-all-cities',
      decoder: (json) {
        final list = (json as List<dynamic>? ?? const []);
        return list
            .whereType<Map<String, dynamic>>()
            .map(
              (item) => _LookupOption(
                id: item['id']?.toString() ?? '',
                name: item['name']?.toString() ?? '',
              ),
            )
            .where((item) => item.id.isNotEmpty && item.name.isNotEmpty)
            .toList();
      },
    );
  }

  Future<List<_LookupOption>> _fetchDistricts(String cityId) async {
    final apiClient = serviceLocator<ApiClient>();
    return apiClient.get<List<_LookupOption>>(
      '/api/v1/districts/get-by-city/$cityId',
      decoder: (json) {
        final list = (json as List<dynamic>? ?? const []);
        return list
            .whereType<Map<String, dynamic>>()
            .map(
              (item) => _LookupOption(
                id: item['id']?.toString() ?? '',
                name: item['name']?.toString() ?? '',
              ),
            )
            .where((item) => item.id.isNotEmpty && item.name.isNotEmpty)
            .toList();
      },
    );
  }

  Future<List<_LookupOption>> _fetchNeighborhoods(String districtId) async {
    final apiClient = serviceLocator<ApiClient>();
    return apiClient.get<List<_LookupOption>>(
      '/api/v1/neighborhoods/get-by-district/$districtId',
      decoder: (json) {
        final list = (json as List<dynamic>? ?? const []);
        return list
            .whereType<Map<String, dynamic>>()
            .map(
              (item) => _LookupOption(
                id: item['id']?.toString() ?? '',
                name: item['name']?.toString() ?? '',
              ),
            )
            .where((item) => item.id.isNotEmpty && item.name.isNotEmpty)
            .toList();
      },
    );
  }

  Future<List<_VenueConnection>> _fetchVenueConnectionsByStatus(
    String profileId, {
    required String status,
  }) async {
    final apiClient = serviceLocator<ApiClient>();
    return apiClient.get<List<_VenueConnection>>(
      '/api/v1/artist-venue-connections/musician/$profileId?status=$status',
      decoder: (json) {
        final list = (json as List<dynamic>? ?? const []);
        return list
            .whereType<Map<String, dynamic>>()
            .map(
              (item) => _VenueConnection(
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

  Future<List<_VenueConnection>> _fetchAcceptedVenueConnections(
    String profileId,
  ) {
    return _fetchVenueConnectionsByStatus(profileId, status: 'ACCEPTED');
  }

  Future<List<_VenueConnection>> _fetchPendingVenueConnections(
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
              builder: (_) => const _VenueIntroScreen(),
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
      final selected = await showModalBottomSheet<_VenueRequestPayload>(
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
          var districtOptions = <_LookupOption>[];
          var neighborhoodOptions = <_LookupOption>[];
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

              String? nameById(List<_LookupOption> list, String? id) {
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
                                      _VenueRequestPayload(
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
              _ActionButtons(
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
              _SectionHeader(
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
        bottomNavigationBar: _BottomBar(
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

class _ActionButtons extends StatelessWidget {
  final bool isFollowing;
  final bool isEnabled;
  final bool isLoading;
  final bool ownerMode;
  final VoidCallback? onEditProfilePressed;
  final VoidCallback onFollowToggle;

  const _ActionButtons({
    required this.isFollowing,
    required this.isEnabled,
    required this.isLoading,
    required this.ownerMode,
    required this.onEditProfilePressed,
    required this.onFollowToggle,
  });

  @override
  Widget build(BuildContext context) {
    if (ownerMode) {
      return const SizedBox.shrink();
    }

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
  final VoidCallback? actionOnTap;

  const _SectionHeader({
    required this.title,
    this.actionLabel,
    this.actionOnTap,
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
            InkWell(
              onTap: actionOnTap,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Text(
                  actionLabel!,
                  style: TextStyle(
                    color: actionOnTap != null
                        ? AppColors.coralAlt
                        : AppColors.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
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
            _VideoTab(
              items: videoItems,
              profileId: profileId,
              ownerMode: ownerMode,
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
                        bottomControls: _AudioTransportRow(
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
                      _CountRow(
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

class _AudioTransportRow extends StatelessWidget {
  final bool isPlaying;
  final Color iconColor;
  final VoidCallback? onPlayPause;
  final VoidCallback? onBack10;
  final VoidCallback? onForward10;

  const _AudioTransportRow({
    required this.isPlaying,
    required this.iconColor,
    this.onPlayPause,
    this.onBack10,
    this.onForward10,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _TransportButton(
          icon: Icons.replay_10_rounded,
          onTap: onBack10,
          color: iconColor,
        ),
        const SizedBox(width: 10),
        _TransportButton(
          icon: isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
          onTap: onPlayPause,
          color: iconColor,
          big: true,
        ),
        const SizedBox(width: 10),
        _TransportButton(
          icon: Icons.forward_10_rounded,
          onTap: onForward10,
          color: iconColor,
        ),
      ],
    );
  }
}

class _TransportButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final Color color;
  final bool big;

  const _TransportButton({
    required this.icon,
    required this.onTap,
    required this.color,
    this.big = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: 44,
        height: 44,
        child: Center(
          child: Container(
            width: big ? 36 : 32,
            height: big ? 36 : 32,
            decoration: BoxDecoration(
              color: AppColors.navBlueSoft,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.border),
            ),
            child: Icon(icon, size: big ? 20 : 16, color: color),
          ),
        ),
      ),
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

class _VideoTab extends StatefulWidget {
  final List<MediaAsset> items;
  final String profileId;
  final bool ownerMode;

  const _VideoTab({
    required this.items,
    required this.profileId,
    required this.ownerMode,
  });

  @override
  State<_VideoTab> createState() => _VideoTabState();
}

class _VideoTabState extends State<_VideoTab> {
  final Set<String> _processingVideoIds = <String>{};
  Timer? _processingPollTimer;
  bool _pollBusy = false;
  int _pollAttempt = 0;
  static const int _maxPollAttempt = 45; // ~6 dakika
  bool _videoUploading = false;

  @override
  void initState() {
    super.initState();
    _syncProcessingState();
  }

  @override
  void didUpdateWidget(covariant _VideoTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncProcessingState();
  }

  @override
  void dispose() {
    _processingPollTimer?.cancel();
    super.dispose();
  }

  void _syncProcessingState() {
    if (_processingVideoIds.isEmpty) return;
    final readyIds = widget.items
        .where((item) {
          final hasPlayable =
              (item.playbackUrl?.trim().isNotEmpty ?? false) ||
              (item.sourceUrl?.trim().isNotEmpty ?? false);
          return item.id.isNotEmpty && hasPlayable;
        })
        .map((item) => item.id)
        .toSet();
    _processingVideoIds.removeWhere(readyIds.contains);
    if (_processingVideoIds.isEmpty) {
      _processingPollTimer?.cancel();
      _processingPollTimer = null;
    } else {
      _startPolling();
    }
  }

  void _addProcessingVideo(String assetId) {
    if (assetId.trim().isEmpty) return;
    setState(() {
      _processingVideoIds.add(assetId.trim());
    });
    _pollAttempt = 0;
    _startPolling();
  }

  void _startPolling() {
    if (_processingPollTimer != null) return;
    _processingPollTimer = Timer.periodic(const Duration(seconds: 8), (
      _,
    ) async {
      if (!mounted) return;
      if (_processingVideoIds.isEmpty) {
        _processingPollTimer?.cancel();
        _processingPollTimer = null;
        return;
      }
      _pollAttempt++;
      if (_pollAttempt > _maxPollAttempt) {
        _processingPollTimer?.cancel();
        _processingPollTimer = null;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Video işleme beklenenden uzun sürdü. Biraz sonra tekrar kontrol et.',
              ),
            ),
          );
        }
        return;
      }
      if (_pollBusy) return;
      _pollBusy = true;
      try {
        await context.read<ProfileMediaCubit>().loadMedia(
          profileType: 'MUSICIAN',
          profileId: widget.profileId,
        );
      } catch (_) {
      } finally {
        _pollBusy = false;
      }
    });
  }

  String _mimeFromVideoFileName(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.mov')) return 'video/quicktime';
    if (lower.endsWith('.mkv')) return 'video/x-matroska';
    return 'video/mp4';
  }

  String _fileNameFromPath(String path, {String fallback = 'video.mp4'}) {
    final normalized = path.replaceAll('\\', '/');
    final parts = normalized.split('/');
    final name = parts.isNotEmpty ? parts.last.trim() : '';
    return name.isEmpty ? fallback : name;
  }

  Future<void> _pickAndUploadVideo() async {
    if (_videoUploading) return;
    final messenger = ScaffoldMessenger.of(context);
    final mediaCubit = context.read<ProfileMediaCubit>();
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      withData: false,
      allowMultiple: false,
      allowedExtensions: const ['mp4', 'mov', 'mkv'],
    );
    final file = result?.files.isNotEmpty == true ? result!.files.first : null;
    if (file == null) return;

    final pickedPath = file.path;
    final pickedBytes = file.bytes;
    final pickedName = file.name.trim().isNotEmpty
        ? file.name.trim()
        : (file.path != null ? _fileNameFromPath(file.path!) : 'video.mp4');
    if ((pickedPath == null && pickedBytes == null) || pickedName.isEmpty) {
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Önce bir video dosyası seç.')),
      );
      return;
    }

    if (!mounted) return;
    setState(() {
      _videoUploading = true;
    });

    var step = 'dosya okuma';
    try {
      final bytes = pickedBytes ?? await File(pickedPath!).readAsBytes();
      if (bytes.isEmpty) {
        throw Exception('Dosya okunamadı');
      }
      final mimeType = _mimeFromVideoFileName(pickedName);

      step = 'init-upload';
      final completed = await uploadProfileMediaAsset(
        bytes: bytes,
        ownerType: 'MUSICIAN_PROFILE',
        ownerId: widget.profileId,
        mediaKind: 'VIDEO',
        mimeType: mimeType,
        originalFileName: pickedName,
      );

      step = 'complete-upload';
      final assetId = completed.uuid.trim();
      if (assetId.isNotEmpty && mounted) {
        _addProcessingVideo(assetId);
      }

      await mediaCubit.loadMedia(
        profileType: 'MUSICIAN',
        profileId: widget.profileId,
      );

      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Video yüklendi, işleniyor. Kısa süre sonra görünecek.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Yükleme başarısız ($step): $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _videoUploading = false;
        });
      }
    }
  }

  Widget _buildProcessingCard() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.inputFill,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _processingVideoIds.length == 1
                ? 'Video i\u015Fleniyor'
                : '${_processingVideoIds.length} video i\u015Fleniyor',
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            '\u0130\u015Fleme tamamlan\u0131nca video otomatik olarak g\u00F6r\u00FCnecek.',
            style: TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
          const SizedBox(height: 10),
          const LinearProgressIndicator(minHeight: 6),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.ownerMode) {
      final hasAny = widget.items.isNotEmpty;
      return Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(20, 20, 20, hasAny ? 8 : 0),
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: _videoUploading ? null : _pickAndUploadVideo,
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
                      hasAny ? 'Video ekle' : 'Henüz video eklemediniz',
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'SoundConnect üzerinden video yüklemek için dokun.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                    if (_videoUploading) ...[
                      const SizedBox(height: 10),
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          if (_processingVideoIds.isNotEmpty) _buildProcessingCard(),
          if (widget.items.isEmpty && _processingVideoIds.isEmpty)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                'Henüz video eklemediniz.',
                style: TextStyle(color: AppColors.textMuted),
              ),
            )
          else if (widget.items.isNotEmpty)
            GridView.builder(
              padding: const EdgeInsets.all(20),
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.85,
              ),
              itemCount: widget.items.length,
              itemBuilder: (context, index) =>
                  _buildVideoCard(context, widget.items[index], index),
            ),
        ],
      );
    }

    if (widget.items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Text(
          'Kullanıcı henüz video eklemedi.',
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
      itemCount: widget.items.length,
      itemBuilder: (context, index) =>
          _buildVideoCard(context, widget.items[index], index),
    );
  }

  Widget _buildVideoCard(BuildContext context, MediaAsset item, int index) {
    final thumbnailRaw = item.thumbnailUrl ?? item.playbackUrl;
    final thumbnail = isValidNetworkImageUrl(thumbnailRaw)
        ? thumbnailRaw!.trim()
        : null;
    final fallbackLikeCount = 210 + (index * 9);
    final fallbackCommentCount = 44 + (index * 4);
    final targetType = 'MEDIA';
    final targetId = item.id;
    final statsState = context.watch<InteractionStatsCubit>().state;
    final statsKey = '$targetType:$targetId';
    if (targetId.isNotEmpty && !statsState.items.containsKey(statsKey)) {
      context.read<InteractionStatsCubit>().load(
        targetType: targetType,
        targetId: targetId,
      );
    }
    final stats = statsState.items[statsKey];
    final likeCount = stats?.likeCount ?? fallbackLikeCount;
    final commentCount = stats?.commentCount ?? fallbackCommentCount;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.inputFill,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        image: thumbnail != null
            ? DecorationImage(image: NetworkImage(thumbnail), fit: BoxFit.cover)
            : null,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
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
                child: VideoReelScreen(
                  title: item.title ?? 'Video',
                  playbackUrl: (item.playbackUrl ?? item.sourceUrl ?? '')
                      .trim(),
                  sourceUrl: item.sourceUrl,
                  thumbnailUrl: thumbnail,
                  framePreset: null,
                  targetType: targetType,
                  targetId: item.id,
                  initialLikeCount: likeCount,
                  initialCommentCount: commentCount,
                ),
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
  }
}

class _CountRow extends StatelessWidget {
  final int likeCount;
  final int commentCount;
  final bool light;
  final bool isLiked;
  final VoidCallback? onLikeTap;
  final VoidCallback? onCommentTap;

  const _CountRow({
    required this.likeCount,
    required this.commentCount,
    this.light = false,
    this.isLiked = false,
    this.onLikeTap,
    this.onCommentTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = light ? AppColors.white : AppColors.textMuted;
    final likeColor = light
        ? AppColors.white
        : (isLiked ? AppColors.coralAlt : AppColors.textMuted);
    return Row(
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onLikeTap,
          child: Row(
            children: [
              Icon(
                isLiked ? Icons.favorite : Icons.favorite_border,
                size: 16,
                color: likeColor,
              ),
              const SizedBox(width: 6),
              Text(
                likeCount.toString(),
                style: TextStyle(color: likeColor, fontSize: 12),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onCommentTap,
          child: Row(
            children: [
              Icon(Icons.chat_bubble_outline, size: 16, color: color),
              const SizedBox(width: 6),
              Text(
                commentCount.toString(),
                style: TextStyle(color: color, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _VenueOption {
  final String id;
  final String name;
  final String? cityId;
  final String? districtId;
  final String? neighborhoodId;
  final String? cityName;
  final String? districtName;
  final String? neighborhoodName;

  const _VenueOption({
    required this.id,
    required this.name,
    this.cityId,
    this.districtId,
    this.neighborhoodId,
    this.cityName,
    this.districtName,
    this.neighborhoodName,
  });
}

class _LookupOption {
  final String id;
  final String name;

  const _LookupOption({required this.id, required this.name});
}

class _VenueConnection {
  final String requestId;
  final String venueId;
  final String venueName;

  const _VenueConnection({
    required this.requestId,
    required this.venueId,
    required this.venueName,
  });
}

class _VenueRequestPayload {
  final String venueId;
  final String message;

  const _VenueRequestPayload({required this.venueId, required this.message});
}

class _VenueIntroScreen extends StatelessWidget {
  const _VenueIntroScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.navBlueDeep,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Mekan Ba\u011Flant\u0131 S\u00FCreci',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 30,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Devam etmeden \u00F6nce k\u0131sa bilgi',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 28),
              const Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      _IntroStep(
                        icon: Icons.send_outlined,
                        title: '\u0130stek G\u00F6nder',
                        text:
                            'Aktif olarak sahne ald\u0131\u011F\u0131n mekanlara buradan ba\u011Flant\u0131 iste\u011Fi g\u00F6nderebilirsin. \u0130stek g\u00F6nderdi\u011Finde ilgili mekana bir bildirim iletilir.',
                      ),
                      SizedBox(height: 22),
                      _IntroStep(
                        icon: Icons.hourglass_top_rounded,
                        title: 'Onay Bekle',
                        text:
                            'Mekan ba\u011Flant\u0131 iste\u011Fini onaylayabilir veya reddedebilir. Onayland\u0131\u011F\u0131nda ba\u011Flant\u0131n\u0131z kurulacak ve hem senin profilinde hem de mekan\u0131n profilinde g\u00F6r\u00FCn\u00FCr hale gelecektir.',
                      ),
                      SizedBox(height: 22),
                      _IntroStep(
                        icon: Icons.settings_outlined,
                        title: 'Durumu Takip Et',
                        text:
                            'G\u00F6nderdi\u011Fin ba\u011Flant\u0131 isteklerinin durumunu istedi\u011Fin zaman Ayarlar \u2192 Ba\u015Fvurular\u0131m b\u00F6l\u00FCm\u00FCnden g\u00F6r\u00FCnt\u00FCleyebilir ve s\u00FCrecin hangi a\u015Famada oldu\u011Funu takip edebilirsin.',
                        showInlineSettingsIcon: true,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.coralAlt,
                    foregroundColor: AppColors.white,
                    padding: const EdgeInsets.symmetric(vertical: 17),
                    textStyle: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text('Anlad\u0131m, Devam Et'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IntroStep extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;
  final bool showInlineSettingsIcon;

  const _IntroStep({
    required this.icon,
    required this.title,
    required this.text,
    this.showInlineSettingsIcon = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2, right: 10),
          child: ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFFF7A3D), Color(0xFFEF5F86), Color(0xFFB85CFF)],
            ).createShader(bounds),
            child: Icon(icon, size: 20, color: Colors.white),
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 4),
              if (showInlineSettingsIcon && text.contains('Ayarlar'))
                Builder(
                  builder: (_) {
                    const bodyStyle = TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      height: 1.44,
                    );
                    final idx = text.indexOf('Ayarlar');
                    final left = text.substring(0, idx);
                    final focus = 'Ayarlar \u2192 Ba\u015Fvurular\u0131m';
                    final focusStart = text.indexOf(focus, idx);
                    final hasFocus = focusStart >= 0;
                    final beforeFocus = hasFocus
                        ? text.substring(idx, focusStart)
                        : text.substring(idx);
                    final focusedText = hasFocus ? focus : '';
                    final afterFocus = hasFocus
                        ? text.substring(focusStart + focus.length)
                        : '';
                    return RichText(
                      text: TextSpan(
                        style: bodyStyle,
                        children: [
                          TextSpan(text: left),
                          const WidgetSpan(
                            alignment: PlaceholderAlignment.middle,
                            child: Padding(
                              padding: EdgeInsets.only(right: 4),
                              child: Icon(
                                Icons.settings,
                                size: 15,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ),
                          TextSpan(text: beforeFocus),
                          if (focusedText.isNotEmpty)
                            TextSpan(
                              text: focusedText,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          TextSpan(text: afterFocus),
                        ],
                      ),
                    );
                  },
                )
              else
                Text(
                  text,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    height: 1.44,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BottomBar extends StatelessWidget {
  final String? profileImageUrl;

  const _BottomBar({this.profileImageUrl});

  Widget _profileAvatar(bool active) {
    final hasImage = profileImageUrl?.trim().isNotEmpty == true;
    final imageUrl = profileImageUrl?.trim() ?? '';
    final child = hasImage
        ? ClipOval(
            child: Image.network(
              imageUrl,
              width: 18,
              height: 18,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                  const Icon(Icons.person_outline, size: 18),
            ),
          )
        : const Icon(Icons.person_outline, size: 18);

    if (!active) {
      return Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.border),
        ),
        child: Center(child: child),
      );
    }

    return Container(
      width: 24,
      height: 24,
      padding: const EdgeInsets.all(1.4),
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(colors: AppColors.brandGradient),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.navBlueDeep,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.navBlueDeep, width: 1),
        ),
        child: Center(child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: 3,
      type: BottomNavigationBarType.fixed,
      backgroundColor: AppColors.navBlueDeep,
      selectedItemColor: AppColors.coralAlt,
      unselectedItemColor: AppColors.textMuted,
      items: [
        const BottomNavigationBarItem(
          icon: Icon(Icons.campaign_outlined),
          label: '\u0130lan',
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.rocket_launch_outlined),
          label: 'Git',
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.forum_outlined),
          label: 'Mesajlar',
        ),
        BottomNavigationBarItem(
          icon: _profileAvatar(false),
          activeIcon: _profileAvatar(true),
          label: 'Profil',
        ),
      ],
    );
  }
}
