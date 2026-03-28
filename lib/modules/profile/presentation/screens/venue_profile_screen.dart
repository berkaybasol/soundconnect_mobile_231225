// ignore_for_file: unused_element, unused_element_parameter, unused_local_variable, use_build_context_synchronously

import 'dart:io';
import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:audio_service/audio_service.dart';
import 'package:dio/dio.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:file_picker/file_picker.dart';
import '../../../../app/router/app_routes.dart';
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
import '../../domain/entities/venue_event_summary.dart';
import '../../domain/entities/venue_owner_profile.dart';
import '../../data/models/musician_profile_save_request.dart';
import '../../data/models/venue_profile_save_request.dart';
import '../cubit/musician_profile_cubit.dart';
import '../cubit/musician_profile_state.dart';
import '../cubit/profile_media_cubit.dart';
import '../cubit/venue_profile_cubit.dart';
import '../cubit/venue_profile_state.dart';
import '../../../spotify/domain/spotify_repository.dart';
import 'media_detail_screen.dart';
import 'video_reel_screen.dart';
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

bool _isValidNetworkImageUrl(String? value) {
  final raw = value?.trim();
  if (raw == null || raw.isEmpty) return false;
  final uri = Uri.tryParse(raw);
  if (uri == null) return false;
  return uri.hasScheme &&
      (uri.scheme == 'http' || uri.scheme == 'https') &&
      (uri.host.isNotEmpty);
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
  String? _mediaProfileId;
  String? _followUserId;
  String? _followStatusKey;
  String? _viewerUserId;
  String? _currentProfileUserId;
  String? _venueProfileId;
  bool _photoUploading = false;
  String? _uploadedProfilePhotoUrl;
  final ImagePicker _imagePicker = ImagePicker();

  String _mimeFromFileName(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) {
      return 'image/jpeg';
    }
    return 'image/jpeg';
  }

  String _fileNameFromPath(String path, {String fallback = 'profile.jpg'}) {
    final normalized = path.replaceAll('\\', '/');
    final parts = normalized.split('/');
    final name = parts.isNotEmpty ? parts.last.trim() : '';
    return name.isEmpty ? fallback : name;
  }

  Future<void> _editProfilePhoto(VenueOwnerProfile profile) async {
    final picked = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 92,
      maxWidth: 2048,
    );
    if (picked == null) return;

    CroppedFile? cropped;
    try {
      cropped = await ImageCropper().cropImage(
        sourcePath: picked.path,
        compressFormat: ImageCompressFormat.jpg,
        compressQuality: 92,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Profil fotoÄŸrafÄ±nÄ± kÄ±rp',
            toolbarColor: const Color(0xFF0B1321),
            toolbarWidgetColor: Colors.white,
            activeControlsWidgetColor: const Color(0xFFF47C7C),
            lockAspectRatio: true,
            hideBottomControls: false,
          ),
          IOSUiSettings(
            title: 'Profil fotoÄŸrafÄ±nÄ± kÄ±rp',
            aspectRatioLockEnabled: true,
            resetAspectRatioEnabled: false,
          ),
        ],
      );
    } on PlatformException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('KÄ±rpma aÃ§Ä±lamadÄ±: ${e.message ?? e.code}')),
      );
      return;
    }
    if (cropped == null) return;

    final bytes = await File(cropped.path).readAsBytes();
    if (bytes.isEmpty) return;

    setState(() => _photoUploading = true);
    try {
      final apiClient = serviceLocator<ApiClient>();
      final fileName = _fileNameFromPath(cropped.path, fallback: picked.name);
      final mimeType = _mimeFromFileName(fileName);

      final initResult = await apiClient.post<_UploadInitResult>(
        '/api/v1/user/media/init-upload',
        body: {
          'ownerType': 'VENUE_PROFILE',
          'ownerId': profile.venueProfileId,
          'kind': 'IMAGE',
          'visibility': 'PUBLIC',
          'mimeType': mimeType,
          'sizeBytes': bytes.length,
          'originalFileName': fileName,
        },
        decoder: (json) =>
            _UploadInitResult.fromJson(json as Map<String, dynamic>),
      );

      await Dio().put(
        initResult.uploadUrl,
        data: bytes,
        options: Options(
          headers: {'Content-Type': mimeType},
          contentType: mimeType,
        ),
      );

      final completed = await apiClient.post<_UploadedMedia>(
        '/api/v1/user/media/complete-upload',
        body: {'assetId': initResult.assetId},
        decoder: (json) =>
            _UploadedMedia.fromJson(json as Map<String, dynamic>),
      );

      final profilePictureAssetId = completed.uuid.trim();
      if (profilePictureAssetId.isEmpty) {
        throw Exception('Yukleme sonrasi assetId alinmadi');
      }

      await context.read<VenueProfileCubit>().updateOwnerProfile(
        VenueProfileSaveRequest(profilePicture: profilePictureAssetId),
        venueId: profile.venueId,
      );
      setState(() {
        _uploadedProfilePhotoUrl =
            (completed.sourceUrl ?? completed.playbackUrl)?.trim();
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profil fotoÄŸrafÄ± gÃ¼ncellendi')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('FotoÄŸraf yÃ¼klenemedi: $e')));
    } finally {
      if (mounted) {
        setState(() => _photoUploading = false);
      }
    }
  }

  String? _socialUrlFor(MusicianProfile profile, _SocialPlatform platform) {
    switch (platform) {
      case _SocialPlatform.soundcloud:
        return profile.soundcloudUrl;
      case _SocialPlatform.instagram:
        return profile.instagramUrl;
      case _SocialPlatform.youtube:
        return profile.youtubeUrl;
      case _SocialPlatform.spotify:
        return profile.spotifyEmbedUrl;
    }
  }

  Future<void> _addSocialLink(
      MusicianProfile profile,
      _SocialPlatform platform,
      ) async {
    var draftValue = _socialUrlFor(profile, platform)?.trim() ?? '';
    final isEditing = draftValue.isNotEmpty;

    final submitted = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text('${platform.label} ${isEditing ? 'dÃ¼zenle' : 'ekle'}'),
          content: TextFormField(
            initialValue: draftValue,
            autofocus: true,
            keyboardType: TextInputType.url,
            decoration: InputDecoration(hintText: platform.placeholder),
            onChanged: (value) => draftValue = value,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('VazgeÃ§'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(draftValue),
              child: const Text('Kaydet'),
            ),
          ],
        );
      },
    );
    if (submitted == null) return;
    final trimmed = submitted.trim();
    if (trimmed.isEmpty) return;
    final normalized = trimmed.contains('://') ? trimmed : 'https://$trimmed';

    final payload = switch (platform) {
      _SocialPlatform.soundcloud => MusicianProfileSaveRequest(
        soundcloudUrl: normalized,
      ),
      _SocialPlatform.instagram => MusicianProfileSaveRequest(
        instagramUrl: normalized,
      ),
      _SocialPlatform.youtube => MusicianProfileSaveRequest(
        youtubeUrl: normalized,
      ),
      _SocialPlatform.spotify => MusicianProfileSaveRequest(
        spotifyEmbedUrl: normalized,
      ),
    };

    try {
      await context.read<MusicianProfileCubit>().updateProfile(payload);
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
      ).showSnackBar(const SnackBar(content: Text('AÃ§Ä±klama gÃ¼ncellendi')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('AÃ§Ä±klama kaydedilemedi')));
    }
  }

  void _onEditProfilePressed() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Asagidaki alanlardan profilini dÃ¼zenleyebilirsin.'),
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
                                  child: const Text('Ä°ptal'),
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
                                                        'Ä°stersen kÄ±sa bir not ekleyebilirsin (zorunlu deÄŸil).',
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
                                                              'VazgeÃ§',
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
                                                              'GÃ¶nder',
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
      ).showSnackBar(SnackBar(content: Text('Mekanlar gÃ¼ncellenemedi: $e')));
    }
  }

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
    final nextKey = '$followerId:$followingId';
    if (_followStatusKey == nextKey) return;
    _followStatusKey = nextKey;
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
        final weeklyEvents = _toWeeklyCalendarEvents(ownerProfile);
        _currentProfileUserId = ownerProfile.ownerUserId;
        _loadFollowCounts(ownerProfile.ownerUserId);
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
            activeVenues: ownerProfile.activeMusicians
                .map((item) => item.displayName)
                .toList(),
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
            onEditEvents: null,
            weeklyEvents: weeklyEvents,
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
            venueName: profile.venueName,
            city: profile.cityName ?? '',
            district: profile.districtName ?? '',
            neighborhood: profile.neighborhoodName ?? '',
            eventDate: _formatDate(item.eventDate),
            startTime: item.startTime ?? '-',
            endTime: item.endTime ?? '-',
            imageAssetPath: null,
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
  final VoidCallback? onEditPhoto;
  final bool photoUploading;
  final String? uploadedProfilePhotoUrl;
  final bool socialEditable;
  final ValueChanged<_SocialPlatform>? onAddSocialLink;
  final bool descriptionEditable;
  final Future<void> Function(String)? onSaveDescription;
  final bool ownerMode;
  final VoidCallback? onEditProfilePressed;
  final bool venueEditable;
  final VoidCallback? onEditVenues;
  final VoidCallback? onEditEvents;
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
        builder: (_) => _VenueManagementPanelScreen(ownerProfile: ownerProfile),
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
          title: const GradientText(text: 'SoundConnect', gradient: LinearGradient(colors: AppColors.brandGradient), style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
          leading: const BackButton(),
          centerTitle: true,
          actions: ownerMode
              ? [
            IconButton(
              tooltip: 'MenÃ¼',
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
              if (ownerMode) ...[
                const SizedBox(height: 12),
                Padding(
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
                            onPressed: () => _openVenueManagementPanel(context),
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
                              'Yönetim Paneli',
                              style: TextStyle(color: AppColors.white),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 18),
              const _SectionHeader(title: 'Haftalık Takvim'),
              _EventCalendarMock(items: weeklyEvents),
              const SizedBox(height: 12),
              _SectionHeader(
                title: 'Aktif Sanatçılar',
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
                spotifyTracks: const [],
                spotifyLoading: spotifyLoading,
                ownerMode: ownerMode,
              ),
              const SizedBox(height: 18),
              _SocialButtonRow(
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
        : 'KullanÄ±cÄ±';
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
        hasBio ? resolvedBio : 'HenÃ¼z bir aÃ§Ä±klama eklenmedi.',
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
          child: const Text('AÃ§Ä±klama ekle'),
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

class _SocialButtonRow extends StatelessWidget {
  final MusicianProfile profile;
  final bool editable;
  final ValueChanged<_SocialPlatform>? onAddLink;

  const _SocialButtonRow({
    required this.profile,
    this.editable = false,
    this.onAddLink,
  });

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
      ).showSnackBar(const SnackBar(content: Text('GeÃ§ersiz link')));
      return;
    }

    final success = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!success && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Link aÃ§Ä±lamadÄ±')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final allItems = [
      _SocialItem(
        platform: _SocialPlatform.soundcloud,
        icon: FontAwesomeIcons.soundcloud,
        url: profile.soundcloudUrl,
      ),
      _SocialItem(
        platform: _SocialPlatform.instagram,
        icon: FontAwesomeIcons.instagram,
        url: profile.instagramUrl,
      ),
      _SocialItem(
        platform: _SocialPlatform.youtube,
        icon: FontAwesomeIcons.youtube,
        url: profile.youtubeUrl,
      ),
      _SocialItem(
        platform: _SocialPlatform.spotify,
        icon: FontAwesomeIcons.spotify,
        url: profile.spotifyEmbedUrl,
      ),
    ];

    final visibleItems = editable
        ? allItems
        : allItems.where((item) => item.active).toList();

    if (visibleItems.isEmpty) return const SizedBox.shrink();

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: visibleItems.map((item) {
        return _SocialPill(
          icon: item.icon,
          active: item.active,
          showAddBadge: editable && !item.active,
          onTap: editable
              ? () => onAddLink?.call(item.platform)
              : (item.active
              ? () => _launchExternalUrl(context, item.url)
              : null),
        );
      }).toList(),
    );
  }
}

enum _SocialPlatform { soundcloud, instagram, youtube, spotify }

extension _SocialPlatformUi on _SocialPlatform {
  String get label {
    switch (this) {
      case _SocialPlatform.soundcloud:
        return 'SoundCloud';
      case _SocialPlatform.instagram:
        return 'Instagram';
      case _SocialPlatform.youtube:
        return 'YouTube';
      case _SocialPlatform.spotify:
        return 'Spotify';
    }
  }

  String get placeholder {
    switch (this) {
      case _SocialPlatform.soundcloud:
        return 'https://soundcloud.com/kullanici';
      case _SocialPlatform.instagram:
        return 'https://instagram.com/kullanici';
      case _SocialPlatform.youtube:
        return 'https://youtube.com/@kanal';
      case _SocialPlatform.spotify:
        return 'https://open.spotify.com/artist/...';
    }
  }
}

class _SocialItem {
  final _SocialPlatform platform;
  final IconData icon;
  final String? url;

  const _SocialItem({
    required this.platform,
    required this.icon,
    required this.url,
  });

  bool get active => _isSocialUrlUsable(url);
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
  final bool showAddBadge;
  final VoidCallback? onTap;

  const _SocialPill({
    required this.icon,
    required this.active,
    this.showAddBadge = false,
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
      colors: [Color(0xFFFF7A3D), Color(0xFFEF5F86), Color(0xFFB85CFF)],
    );

    final isInteractive = widget.onTap != null;
    final borderColor = _pressed ? AppColors.textMuted : AppColors.border;
    final shadowOpacity = _pressed ? 0.12 : 0.05;

    return GestureDetector(
      onTapDown: isInteractive ? (_) => setState(() => _pressed = true) : null,
      onTapCancel: isInteractive
          ? () => setState(() => _pressed = false)
          : null,
      onTapUp: isInteractive ? (_) => setState(() => _pressed = false) : null,
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            AnimatedContainer(
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
                child: widget.active
                    ? ShaderMask(
                  shaderCallback: (bounds) =>
                      iconGradient.createShader(bounds),
                  child: FaIcon(
                    widget.icon,
                    size: 20,
                    color: AppColors.white,
                  ),
                )
                    : FaIcon(
                  widget.icon,
                  size: 20,
                  color: AppColors.textMuted.withValues(alpha: 0.65),
                ),
              ),
            ),
            if (widget.showAddBadge)
              Positioned(
                right: -4,
                top: -4,
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: const BoxDecoration(
                    color: Color(0xFFF47C7C),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.add, size: 12, color: Colors.white),
                ),
              ),
          ],
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

class _EventCalendarMock extends StatelessWidget {
  final List<WeeklyCalendarEvent> items;

  const _EventCalendarMock({required this.items});

  static const List<WeeklyCalendarEvent> _items = [
    WeeklyCalendarEvent(
      id: 'venue-event-1',
      title: 'Acoustic Night',
      artistName: 'Luna Echo',
      venueName: 'Sahne A',
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
      venueName: 'Teras',
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
      venueName: 'Lounge',
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
              spotifyTracks: const [],
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
                    errorText = 'SonuÃ§ bulunamadÄ±.';
                  }
                } else {
                  errorText = result.error?.message ?? 'Arama baÅŸarÄ±sÄ±z.';
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
                            hintText: 'Spotify parÃ§a ara...',
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
                              '${results.length} sonuÃ§',
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
      ).showSnackBar(const SnackBar(content: Text('Bu parÃ§a zaten ekli.')));
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
            cubit.state.error?.message ?? 'Spotify parÃ§asÄ± eklenemedi.',
          ),
        ),
      );
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('ÅarkÄ± baÅŸarÄ±yla eklendi.')));
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
              cubit.state.error?.message ?? 'Spotify parÃ§asÄ± silinemedi.',
            ),
          ),
        );
      }
      return false;
    }
    if (showSnackbar) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Spotify parÃ§asÄ± kaldÄ±rÄ±ldÄ±.')),
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
                  infoText = 'Ã–nce bir ses dosyasÄ± seÃ§.';
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
                  throw Exception('Dosya okunamadÄ±');
                }
                final apiClient = serviceLocator<ApiClient>();
                final mimeType = _mimeFromAudioFileName(name);

                step = 'init-upload';
                final initResult = await apiClient.post<_UploadInitResult>(
                  '/api/v1/user/media/init-upload',
                  body: {
                    'ownerType': 'MUSICIAN_PROFILE',
                    'ownerId': profileId,
                    'kind': 'AUDIO',
                    'visibility': 'PUBLIC',
                    'mimeType': mimeType,
                    'sizeBytes': bytes.length,
                    'originalFileName': name,
                  },
                  decoder: (json) =>
                      _UploadInitResult.fromJson(json as Map<String, dynamic>),
                );

                step = 'dosya yÃ¼kleme';
                await Dio().put(
                  initResult.uploadUrl,
                  data: bytes,
                  options: Options(
                    headers: {'Content-Type': mimeType},
                    contentType: mimeType,
                  ),
                );

                step = 'complete-upload';
                final completed = await apiClient.post<_UploadedMedia>(
                  '/api/v1/user/media/complete-upload',
                  body: {'assetId': initResult.assetId},
                  decoder: (json) =>
                      _UploadedMedia.fromJson(json as Map<String, dynamic>),
                );

                final mediaAssetId = completed.uuid.trim();
                if (mediaAssetId.isEmpty) {
                  throw Exception('Media asset id alÄ±namadÄ±');
                }

                step = 'track oluÅŸturma';
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
                  // Track baÅŸarÄ±yla oluÅŸtuysa liste yenileme hatasÄ± non-fatal.
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
                  infoText = 'YÃ¼kleme baÅŸarÄ±sÄ±z ($step): $e';
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
                          pickedName == null ? 'Ses DosyasÄ± SeÃ§' : pickedName!,
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
                                  : const Text('YÃ¼kle'),
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
                feedbackText = 'Spotify parÃ§asÄ± kaldÄ±rÄ±ldÄ±.';
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
                              'SanatÃ§Ä±nÄ±n Spotify KataloÄŸu',
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
                              tooltip: 'Spotify parÃ§asÄ± ekle',
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
                                    feedbackText = 'Bu parÃ§a zaten ekli.';
                                    feedbackIsError = true;
                                  });
                                  return;
                                }
                                final nextTracks = [...visibleTracks, selected];
                                final ok = await saveTracks(
                                  nextTracks,
                                  failureMessage: 'Spotify parÃ§asÄ± eklenemedi.',
                                );
                                if (!ok || !sheetContext.mounted) return;
                                setSheetState(() {
                                  visibleTracks.add(selected);
                                  feedbackText = 'Spotify parÃ§asÄ± eklendi.';
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
                            'HenÃ¼z Spotify parÃ§asÄ± eklemediniz.',
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
                            _isValidNetworkImageUrl(
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
                                  'Spotify parÃ§asÄ± kaldÄ±rÄ±ldÄ±.';
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
                                        tooltip: 'Katalogdan kaldÄ±r',
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
          'KullanÄ±cÄ± henÃ¼z ses eklemedi.',
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
                    label: const Text('Spotify KataloÄŸu'),
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
                              ? 'Henuz fotograf eklemediniz'
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
                  'KullanÄ±cÄ± henÃ¼z ses eklemedi.',
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
                'Video iÅŸleme beklenenden uzun sÃ¼rdÃ¼. Biraz sonra tekrar kontrol et.',
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
        const SnackBar(content: Text('Ã–nce bir video dosyasÄ± seÃ§.')),
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
        throw Exception('Dosya okunamadÄ±');
      }
      final apiClient = serviceLocator<ApiClient>();
      final mimeType = _mimeFromVideoFileName(pickedName);

      step = 'init-upload';
      final initResult = await apiClient.post<_UploadInitResult>(
        '/api/v1/user/media/init-upload',
        body: {
          'ownerType': 'MUSICIAN_PROFILE',
          'ownerId': widget.profileId,
          'kind': 'VIDEO',
          'visibility': 'PUBLIC',
          'mimeType': mimeType,
          'sizeBytes': bytes.length,
          'originalFileName': pickedName,
        },
        decoder: (json) =>
            _UploadInitResult.fromJson(json as Map<String, dynamic>),
      );

      step = 'dosya yÃ¼kleme';
      await Dio().put(
        initResult.uploadUrl,
        data: bytes,
        options: Options(
          headers: {'Content-Type': mimeType},
          contentType: mimeType,
        ),
      );

      step = 'complete-upload';
      final completed = await apiClient.post<_UploadedMedia>(
        '/api/v1/user/media/complete-upload',
        body: {'assetId': initResult.assetId},
        decoder: (json) =>
            _UploadedMedia.fromJson(json as Map<String, dynamic>),
      );

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
            'Video yÃ¼klendi, iÅŸleniyor. KÄ±sa sÃ¼re sonra gÃ¶rÃ¼necek.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('YÃ¼kleme baÅŸarÄ±sÄ±z ($step): $e')),
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
                      hasAny ? 'Video ekle' : 'HenÃ¼z video eklemediniz',
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'SoundConnect Ã¼zerinden video yÃ¼klemek iÃ§in dokun.',
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
                'HenÃ¼z video eklemediniz.',
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
          'KullanÄ±cÄ± henÃ¼z video eklemedi.',
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
    final thumbnail = _isValidNetworkImageUrl(thumbnailRaw)
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

class _UploadInitResult {
  final String assetId;
  final String uploadUrl;

  const _UploadInitResult({required this.assetId, required this.uploadUrl});

  factory _UploadInitResult.fromJson(Map<String, dynamic> json) {
    return _UploadInitResult(
      assetId: json['assetId']?.toString() ?? '',
      uploadUrl: json['uploadUrl']?.toString() ?? '',
    );
  }
}

class _UploadedMedia {
  final String uuid;
  final String? sourceUrl;
  final String? playbackUrl;

  const _UploadedMedia({
    required this.uuid,
    required this.sourceUrl,
    required this.playbackUrl,
  });

  factory _UploadedMedia.fromJson(Map<String, dynamic> json) {
    return _UploadedMedia(
      uuid: json['uuid']?.toString() ?? '',
      sourceUrl: json['sourceUrl']?.toString(),
      playbackUrl: json['playbackUrl']?.toString(),
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

class _VenueManagementPanelScreen extends StatelessWidget {
  final VenueOwnerProfile ownerProfile;

  const _VenueManagementPanelScreen({required this.ownerProfile});

  Widget _actionCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String message,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap ??
          () async {
            if (icon == Icons.calendar_month_outlined) {
              final changed = await Navigator.of(context).push<bool>(
                MaterialPageRoute(
                  builder: (_) => _VenueWeeklyCalendarEditorScreen(
                    ownerProfile: ownerProfile,
                  ),
                ),
              );
              if (changed == true && context.mounted) {
                Navigator.of(context).pop(true);
              }
              return;
            }
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(message)));
          },
      borderRadius: BorderRadius.circular(18),
      child: _GradientOutline(
        radius: 18,
        strokeWidth: 1,
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.inputFill, AppColors.navBlueSoft],
            ),
          ),
          child: Row(
            children: [
              Icon(icon, color: AppColors.white, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                color: AppColors.textMuted,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Yönetim Paneli'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: EdgeInsets.only(top: 1),
                      child: Icon(
                        Icons.info_outline_rounded,
                        color: AppColors.textMuted,
                        size: 18,
                      ),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'İşletmenin ihtiyaç duyduğu bütün gereksinimleri bu panelden gerçekleştirebilirsin.',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _actionCard(
                  context: context,
                  icon: Icons.calendar_month_outlined,
                  title: 'Haftalık Takvimi Güncelle',
                  message:
                  'Takvim güncelleme akışının backend bağlantısı yakında eklenecek.',
                ),
                const SizedBox(height: 12),
                _actionCard(
                  context: context,
                  icon: Icons.assignment_ind_outlined,
                  title: 'Sanatçı Bağlantı İsteklerini Görüntüle',
                  message:
                  'Sanatçı bağlantı istekleri ekranının backend bağlantısı yakında eklenecek.',
                ),
                const SizedBox(height: 12),
                _actionCard(
                  context: context,
                  icon: Icons.groups_2_outlined,
                  title: 'Aktif Sanatçıları Düzenle',
                  message:
                  'Aktif sanatçı düzenleme akışının backend bağlantısı yakında eklenecek.',
                ),
                const SizedBox(height: 12),
                _actionCard(
                  context: context,
                  icon: Icons.campaign_outlined,
                  title: 'Müzisyen/Grup İlanlarını Görüntüle',
                  message:
                  'Müzisyen/grup ilanları ekranının backend bağlantısı yakında eklenecek.',
                ),
                const SizedBox(height: 12),
                _actionCard(
                  context: context,
                  icon: Icons.post_add_outlined,
                  title: 'Sahnen İçin Müzisyen/Grup İlanı Oluştur',
                  message:
                  'Sahnen için ilan oluşturma ekranının backend bağlantısı yakında eklenecek.',
                ),
                const SizedBox(height: 12),
                _actionCard(
                  context: context,
                  icon: Icons.reviews_outlined,
                  title: 'İşletmene Gelen Bütün Yorumları Gör',
                  message:
                  'İşletme yorumları ekranının backend bağlantısı yakında eklenecek.',
                ),
                const SizedBox(height: 14),
                Opacity(
                  opacity: 0.62,
                  child: Stack(
                    children: [
                      Container(
                        padding: const EdgeInsets.fromLTRB(14, 18, 14, 18),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [AppColors.inputFill, AppColors.navBlueSoft],
                          ),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: const Text(
                          'Hızlı İstatistikler',
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Positioned(
                        top: 10,
                        right: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.navBlueDeep.withValues(alpha: 0.78),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: const Text(
                            'Yakında',
                            style: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GradientOutline extends StatelessWidget {
  final double radius;
  final double strokeWidth;
  final Widget child;

  const _GradientOutline({
    required this.radius,
    required this.strokeWidth,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _GradientOutlinePainter(
        radius: radius,
        strokeWidth: strokeWidth,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: child,
      ),
    );
  }
}

class _GradientOutlinePainter extends CustomPainter {
  final double radius;
  final double strokeWidth;

  const _GradientOutlinePainter({
    required this.radius,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(
      rect.deflate(strokeWidth / 2),
      Radius.circular(radius),
    );
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: AppColors.brandGradient,
      ).createShader(rect);
    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(covariant _GradientOutlinePainter oldDelegate) {
    return oldDelegate.radius != radius ||
        oldDelegate.strokeWidth != strokeWidth;
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

class _VenueWeeklyCalendarEditorScreen extends StatefulWidget {
  final VenueOwnerProfile ownerProfile;

  const _VenueWeeklyCalendarEditorScreen({required this.ownerProfile});

  @override
  State<_VenueWeeklyCalendarEditorScreen> createState() =>
      _VenueWeeklyCalendarEditorScreenState();
}

class _VenueWeeklyCalendarEditorScreenState
    extends State<_VenueWeeklyCalendarEditorScreen> {
  bool _loading = true;
  bool _saving = false;
  bool _changed = false;
  String? _error;
  List<_VenueOwnerEventItem> _events = const [];

  ApiClient get _apiClient => serviceLocator<ApiClient>();

  List<_VenueOwnerEventItem> get _sortedEvents {
    final items = [..._events];
    items.sort((a, b) {
      final dateCompare = a.eventDate.compareTo(b.eventDate);
      if (dateCompare != 0) return dateCompare;
      return a.startTime.compareTo(b.startTime);
    });
    return items;
  }

  Map<String, List<_VenueOwnerEventItem>> get _groupedEvents {
    final map = <String, List<_VenueOwnerEventItem>>{};
    for (final item in _sortedEvents) {
      final key = _formatDateOnly(item.eventDate);
      map.putIfAbsent(key, () => <_VenueOwnerEventItem>[]).add(item);
    }
    return map;
  }

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await _apiClient.get<List<_VenueOwnerEventItem>>(
        '/api/v1/venue-owner/events/venue/${widget.ownerProfile.venueId}',
        decoder: (json) {
          final list = json is List ? json : const [];
          return list
              .whereType<Map<String, dynamic>>()
              .map(_VenueOwnerEventItem.fromJson)
              .toList();
        },
      );
      if (!mounted) return;
      setState(() {
        _events = items;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Etkinlikler alinamadi: $e';
      });
    }
  }

  Future<void> _createEvent() async {
    final draft = await showModalBottomSheet<_VenueEventDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.navBlueDeep,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        final titleController = TextEditingController();
        final descriptionController = TextEditingController();
        final performerController = TextEditingController();
        DateTime? selectedDate = DateTime.now();
        TimeOfDay? startTime = const TimeOfDay(hour: 20, minute: 0);
        TimeOfDay? endTime = const TimeOfDay(hour: 22, minute: 0);
        String? selectedMusicianId;
        String? selectedMusicianLabel;
        String? selectedMusicianSecondaryLabel;
        String? selectedMusicianImageUrl;
        var searchLoading = false;
        String? searchError;
        var searchResults = <_MusicianSearchOption>[];
        Timer? searchDebounce;
        int searchToken = 0;

        return StatefulBuilder(
          builder: (context, setSheetState) {
            Future<void> runSearch(String raw) async {
              final query = raw.trim();
              final token = ++searchToken;
              if (query.length < 2) {
                setSheetState(() {
                  searchLoading = false;
                  searchError = null;
                  searchResults = const [];
                });
                return;
              }
              setSheetState(() {
                searchLoading = true;
                searchError = null;
              });
              try {
                final results = await _apiClient.get<List<_MusicianSearchOption>>(
                  '/api/v1/public/musician-profiles/search',
                  query: {'q': query},
                  decoder: (json) {
                    final list = json is List ? json : const [];
                    return list
                        .whereType<Map<String, dynamic>>()
                        .map(_MusicianSearchOption.fromJson)
                        .toList();
                  },
                );
                if (!context.mounted || token != searchToken) return;
                setSheetState(() {
                  searchLoading = false;
                  searchResults = results;
                  searchError = results.isEmpty ? 'Sonuc bulunamadi.' : null;
                });
              } catch (e) {
                if (!context.mounted || token != searchToken) return;
                setSheetState(() {
                  searchLoading = false;
                  searchResults = const [];
                  searchError = 'Arama su anda yapilamiyor.';
                });
              }
            }

            Future<void> pickDate() async {
              final now = DateTime.now();
              final picked = await showDatePicker(
                context: context,
                initialDate: selectedDate ?? now,
                firstDate: DateTime(now.year - 1),
                lastDate: DateTime(now.year + 3),
              );
              if (picked == null) return;
              setSheetState(() => selectedDate = picked);
            }

            Future<void> pickTime({
              required bool isStart,
            }) async {
              final picked = await showTimePicker(
                context: context,
                initialTime: isStart
                    ? (startTime ?? const TimeOfDay(hour: 20, minute: 0))
                    : (endTime ?? const TimeOfDay(hour: 22, minute: 0)),
              );
              if (picked == null) return;
              setSheetState(() {
                if (isStart) {
                  startTime = picked;
                } else {
                  endTime = picked;
                }
              });
            }

            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Etkinlik Ekle',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        labelText: 'Baslik',
                        hintText: 'Etkinlik basligi',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: performerController,
                      onChanged: (value) {
                        final trimmed = value.trim();
                        if (selectedMusicianId != null &&
                            trimmed != (selectedMusicianLabel ?? '').trim()) {
                          selectedMusicianId = null;
                          selectedMusicianLabel = null;
                        }
                        searchDebounce?.cancel();
                        searchDebounce = Timer(
                          const Duration(milliseconds: 320),
                          () => runSearch(trimmed),
                        );
                        setSheetState(() {});
                      },
                      decoration: InputDecoration(
                        labelText: 'Calacak sanatci / grup',
                        hintText: 'Isim yaz, eslesirse profile baglanir',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: selectedMusicianId != null
                            ? const Icon(
                                Icons.verified_rounded,
                                color: AppColors.coralAlt,
                              )
                            : null,
                      ),
                    ),
                    if (selectedMusicianId != null) ...[
                      const SizedBox(height: 8),
                      InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () {
                          if (selectedMusicianId == null ||
                              selectedMusicianId!.isEmpty) {
                            return;
                          }
                          Navigator.of(context).pushNamed(
                            AppRoutes.musicianPublicProfile,
                            arguments: {
                              'profileId': selectedMusicianId,
                              'viewerUserId': widget.ownerProfile.ownerUserId,
                            },
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.navBlueDeep.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 16,
                                backgroundColor: AppColors.navBlueSoft,
                                backgroundImage: selectedMusicianImageUrl !=
                                            null &&
                                        selectedMusicianImageUrl!.startsWith(
                                          'http',
                                        )
                                    ? NetworkImage(selectedMusicianImageUrl!)
                                    : null,
                                child: selectedMusicianImageUrl == null ||
                                        !selectedMusicianImageUrl!.startsWith(
                                          'http',
                                        )
                                    ? const Icon(
                                        Icons.person_outline,
                                        size: 16,
                                        color: AppColors.textMuted,
                                      )
                                    : null,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      selectedMusicianLabel ??
                                          'SoundConnect Profili',
                                      style: const TextStyle(
                                        color: AppColors.textPrimary,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    if (selectedMusicianSecondaryLabel !=
                                        null)
                                      Text(
                                        selectedMusicianSecondaryLabel!,
                                        style: const TextStyle(
                                          color: AppColors.textMuted,
                                          fontSize: 11,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              const Icon(
                                Icons.open_in_new_rounded,
                                color: AppColors.coralAlt,
                                size: 18,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    if (searchLoading) ...[
                      const SizedBox(height: 10),
                      const LinearProgressIndicator(minHeight: 2),
                    ] else if (searchResults.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Container(
                        constraints: const BoxConstraints(maxHeight: 190),
                        decoration: BoxDecoration(
                          color: AppColors.inputFill,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: searchResults.length,
                          separatorBuilder: (_, __) =>
                              const Divider(height: 1, color: AppColors.border),
                          itemBuilder: (context, index) {
                            final item = searchResults[index];
                            return ListTile(
                              onTap: () {
                                performerController.text = item.displayName;
                                performerController.selection =
                                    TextSelection.collapsed(
                                  offset: performerController.text.length,
                                );
                                setSheetState(() {
                                  selectedMusicianId = item.profileId;
                                  selectedMusicianLabel = item.displayName;
                                  selectedMusicianSecondaryLabel =
                                      item.secondaryLabel;
                                  selectedMusicianImageUrl =
                                      item.profilePictureUrl;
                                  searchResults = const [];
                                  searchError = null;
                                });
                              },
                              leading: CircleAvatar(
                                radius: 18,
                                backgroundColor: AppColors.navBlueSoft,
                                backgroundImage: item.profilePictureUrl != null &&
                                        item.profilePictureUrl!.startsWith(
                                          'http',
                                        )
                                    ? NetworkImage(item.profilePictureUrl!)
                                    : null,
                                child: item.profilePictureUrl == null ||
                                        !item.profilePictureUrl!.startsWith(
                                          'http',
                                        )
                                    ? const Icon(
                                        Icons.person_outline,
                                        color: AppColors.textMuted,
                                      )
                                    : null,
                              ),
                              title: Text(
                                item.displayName,
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              subtitle: item.secondaryLabel == null
                                  ? null
                                  : Text(
                                      item.secondaryLabel!,
                                      style: const TextStyle(
                                        color: AppColors.textMuted,
                                      ),
                                    ),
                            );
                          },
                        ),
                      ),
                    ] else if (searchError != null &&
                        performerController.text.trim().length >= 2) ...[
                      const SizedBox(height: 8),
                      Text(
                        searchError!,
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: pickDate,
                            icon: const Icon(Icons.event_outlined),
                            label: Text(
                              selectedDate == null
                                  ? 'Tarih sec'
                                  : _formatDateOnly(selectedDate!),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => pickTime(isStart: true),
                            icon: const Icon(Icons.schedule_outlined),
                            label: Text(
                              startTime == null
                                  ? 'Baslangic'
                                  : startTime!.format(context),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => pickTime(isStart: false),
                            icon: const Icon(Icons.schedule),
                            label: Text(
                              endTime == null
                                  ? 'Bitis'
                                  : endTime!.format(context),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descriptionController,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Aciklama',
                        hintText: 'Etkinlik aciklamasi',
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: () {
                        final title = titleController.text.trim();
                        final performerText = performerController.text.trim();
                        if (title.isEmpty ||
                            selectedDate == null ||
                            startTime == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Baslik, tarih ve baslangic saati zorunlu.',
                              ),
                            ),
                          );
                          return;
                        }
                        Navigator.of(sheetContext).pop(
                          _VenueEventDraft(
                            title: title,
                            description: descriptionController.text.trim(),
                            eventDate: selectedDate!,
                            startTime: startTime!,
                            endTime: endTime,
                            musicianProfileId: selectedMusicianId,
                            manualPerformerName:
                                selectedMusicianId == null &&
                                        performerText.isNotEmpty
                                    ? performerText
                                    : null,
                          ),
                        );
                      },
                      icon: const Icon(Icons.save_outlined),
                      label: const Text('Etkinligi Kaydet'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (draft == null) return;

    setState(() => _saving = true);
    try {
      await _apiClient.post<Object?>(
        '/api/v1/venue-owner/events',
        body: {
          'title': draft.title,
          'description': draft.description.isEmpty ? null : draft.description,
          'eventDate': _formatApiDate(draft.eventDate),
          'startTime': _formatApiTime(draft.startTime),
          'endTime':
              draft.endTime == null ? null : _formatApiTime(draft.endTime!),
          'posterImage': null,
          'venueId': widget.ownerProfile.venueId,
          'musicianProfileId': draft.musicianProfileId,
          'bandId': null,
          'manualPerformerName': draft.manualPerformerName,
        },
      );
      _changed = true;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Etkinlik eklendi.')),
      );
      await _loadEvents();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Etkinlik eklenemedi: $e')));
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _deleteEvent(_VenueOwnerEventItem item) async {
    setState(() => _saving = true);
    try {
      await _apiClient.delete<Object?>(
        '/api/v1/venue-owner/events/${item.id}',
      );
      _changed = true;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Etkinlik silindi.')),
      );
      await _loadEvents();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Etkinlik silinemedi: $e')));
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Haftalik Takvim'),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: _loading || _saving ? null : _loadEvents,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _saving ? null : _createEvent,
        backgroundColor: AppColors.coralAlt,
        foregroundColor: AppColors.white,
        icon: _saving
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.add),
        label: const Text('Etkinlik Ekle'),
      ),
      body: WillPopScope(
        onWillPop: () async {
          Navigator.of(context).pop(_changed);
          return false;
        },
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppColors.inputFill, AppColors.navBlueSoft],
                    ),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.ownerProfile.venueName,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Bu ekrandan haftalik takvime yeni etkinlik ekleyebilir ve mevcut etkinlikleri silebilirsin.',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: _CalendarSummaryPill(
                              label: 'Toplam Etkinlik',
                              value: '${_events.length}',
                              icon: Icons.event_note_outlined,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _CalendarSummaryPill(
                              label: 'Aktif Sanatci',
                              value:
                                  '${widget.ownerProfile.activeMusicians.length}',
                              icon: Icons.groups_2_outlined,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (_loading)
                  const Expanded(
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_error != null)
                  Expanded(
                    child: Center(
                      child: Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.textMuted),
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: GridView.builder(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            childAspectRatio: 0.68,
                          ),
                      itemCount: _sortedEvents.length + 1,
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          return _EmptyCalendarEventCard(
                            onTap: _saving ? null : _createEvent,
                          );
                        }
                        final item = _sortedEvents[index - 1];
                        return _CalendarEventCard(
                          item: item,
                          saving: _saving,
                          onDelete: () => _deleteEvent(item),
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
  }
}

class _VenueOwnerEventItem {
  final String id;
  final String title;
  final String performerName;
  final DateTime eventDate;
  final String startTime;
  final String? endTime;
  final String? description;

  const _VenueOwnerEventItem({
    required this.id,
    required this.title,
    required this.performerName,
    required this.eventDate,
    required this.startTime,
    required this.endTime,
    required this.description,
  });

  factory _VenueOwnerEventItem.fromJson(Map<String, dynamic> json) {
    return _VenueOwnerEventItem(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      performerName: json['performerName']?.toString() ?? 'Sanatci',
      eventDate:
          DateTime.tryParse(json['eventDate']?.toString() ?? '') ??
          DateTime.now(),
      startTime: json['startTime']?.toString() ?? '',
      endTime: json['endTime']?.toString(),
      description: json['description']?.toString(),
    );
  }
}

class _EmptyCalendarEventCard extends StatelessWidget {
  final VoidCallback? onTap;

  const _EmptyCalendarEventCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 176),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.inputFill, AppColors.navBlueSoft],
            ),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(
                Icons.add_circle_outline_rounded,
                color: AppColors.coralAlt,
                size: 34,
              ),
              SizedBox(height: 12),
              Text(
                'Etkinlik Ekle',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CalendarEventCard extends StatelessWidget {
  final _VenueOwnerEventItem item;
  final bool saving;
  final VoidCallback onDelete;

  const _CalendarEventCard({
    required this.item,
    required this.saving,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final timeLabel =
        '${_formatDateOnly(item.eventDate)}\n${item.startTime}${item.endTime == null || item.endTime!.isEmpty ? '' : ' - ${item.endTime}'}';

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 12, 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.inputFill, AppColors.navBlueSoft],
        ),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  item.title,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    height: 1.2,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              SizedBox(
                width: 34,
                height: 34,
                child: IconButton(
                  tooltip: 'Sil',
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                  onPressed: saving ? null : onDelete,
                  icon: const Icon(
                    Icons.delete_outline,
                    color: AppColors.coralAlt,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            timeLabel,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 12,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            item.performerName,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.white,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
          if (item.description != null && item.description!.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              item.description!,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textMuted,
                height: 1.4,
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MusicianSearchOption {
  final String profileId;
  final String displayName;
  final String? secondaryLabel;
  final String? profilePictureUrl;

  const _MusicianSearchOption({
    required this.profileId,
    required this.displayName,
    required this.secondaryLabel,
    required this.profilePictureUrl,
  });

  factory _MusicianSearchOption.fromJson(Map<String, dynamic> json) {
    final username = json['username']?.toString().trim();
    final stageName = json['stageName']?.toString().trim();
    final displayName = (stageName != null && stageName.isNotEmpty)
        ? stageName
        : (username != null && username.isNotEmpty ? username : 'Sanatci');
    final secondaryLabel = (username != null &&
            username.isNotEmpty &&
            username != displayName)
        ? '@$username'
        : null;

    return _MusicianSearchOption(
      profileId: json['profileId']?.toString() ?? '',
      displayName: displayName,
      secondaryLabel: secondaryLabel,
      profilePictureUrl: json['profilePictureUrl']?.toString(),
    );
  }
}

class _CalendarSummaryPill extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _CalendarSummaryPill({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.navBlueDeep.withValues(alpha: 0.52),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.coralAlt, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _VenueEventDraft {
  final String title;
  final String description;
  final DateTime eventDate;
  final TimeOfDay startTime;
  final TimeOfDay? endTime;
  final String? musicianProfileId;
  final String? manualPerformerName;

  const _VenueEventDraft({
    required this.title,
    required this.description,
    required this.eventDate,
    required this.startTime,
    required this.endTime,
    required this.musicianProfileId,
    required this.manualPerformerName,
  });
}

String _formatDateOnly(DateTime value) {
  return '${value.day.toString().padLeft(2, '0')}.${value.month.toString().padLeft(2, '0')}.${value.year}';
}

String _formatApiDate(DateTime value) {
  return '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
}

String _formatApiTime(TimeOfDay value) {
  return '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}:00';
}
