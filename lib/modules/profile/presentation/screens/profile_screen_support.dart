import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/services.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/network/api_client.dart';
import '../../../artist_venue/presentation/cubit/artist_venue_connections_cubit.dart';
import '../../../follow/presentation/cubit/follow_action_cubit.dart';
import '../../../follow/presentation/cubit/follow_count_cubit.dart';
import '../cubit/profile_media_cubit.dart';

enum ProfileMediaOwnerType {
  musician('MUSICIAN'),
  venue('VENUE');

  final String apiValue;

  const ProfileMediaOwnerType(this.apiValue);
}

bool isValidNetworkImageUrl(String? value) {
  final raw = value?.trim();
  if (raw == null || raw.isEmpty) return false;
  final uri = Uri.tryParse(raw);
  if (uri == null) return false;
  return uri.hasScheme &&
      (uri.scheme == 'http' || uri.scheme == 'https') &&
      uri.host.isNotEmpty;
}

String inferImageMimeType(String fileName) {
  final lower = fileName.toLowerCase();
  if (lower.endsWith('.png')) return 'image/png';
  if (lower.endsWith('.webp')) return 'image/webp';
  return 'image/jpeg';
}

String fileNameFromPath(String path, {required String fallback}) {
  final normalized = path.replaceAll('\\', '/');
  final parts = normalized.split('/');
  final name = parts.isNotEmpty ? parts.last.trim() : '';
  return name.isEmpty ? fallback : name;
}

class ProfilePhotoUploadResult {
  final String assetId;
  final String? sourceUrl;
  final String? playbackUrl;

  const ProfilePhotoUploadResult({
    required this.assetId,
    required this.sourceUrl,
    required this.playbackUrl,
  });

  String? get preferredUrl {
    final source = sourceUrl?.trim();
    if (source != null && source.isNotEmpty) return source;
    final playback = playbackUrl?.trim();
    if (playback != null && playback.isNotEmpty) return playback;
    return null;
  }
}

class ProfileUploadInitResult {
  final String assetId;
  final String uploadUrl;

  const ProfileUploadInitResult({
    required this.assetId,
    required this.uploadUrl,
  });

  factory ProfileUploadInitResult.fromJson(Map<String, dynamic> json) {
    return ProfileUploadInitResult(
      assetId: json['assetId']?.toString() ?? '',
      uploadUrl: json['uploadUrl']?.toString() ?? '',
    );
  }
}

class ProfileUploadedMedia {
  final String uuid;
  final String? sourceUrl;
  final String? playbackUrl;

  const ProfileUploadedMedia({
    required this.uuid,
    required this.sourceUrl,
    required this.playbackUrl,
  });

  factory ProfileUploadedMedia.fromJson(Map<String, dynamic> json) {
    return ProfileUploadedMedia(
      uuid: json['uuid']?.toString() ?? '',
      sourceUrl: json['sourceUrl']?.toString(),
      playbackUrl: json['playbackUrl']?.toString(),
    );
  }
}

Future<ProfilePhotoUploadResult?> pickCropAndUploadProfilePhoto({
  required BuildContext context,
  required ImagePicker imagePicker,
  required String ownerType,
  required String ownerId,
  String cropTitle = 'Profil fotografini kirp',
  Color cropToolbarColor = const Color(0xFF0B1321),
  Color cropAccentColor = const Color(0xFFF47C7C),
}) async {
  final picked = await imagePicker.pickImage(
    source: ImageSource.gallery,
    imageQuality: 92,
    maxWidth: 2048,
  );
  if (picked == null) return null;

  CroppedFile? cropped;
  try {
    cropped = await ImageCropper().cropImage(
      sourcePath: picked.path,
      compressFormat: ImageCompressFormat.jpg,
      compressQuality: 92,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: cropTitle,
          toolbarColor: cropToolbarColor,
          toolbarWidgetColor: Colors.white,
          activeControlsWidgetColor: cropAccentColor,
          lockAspectRatio: true,
          hideBottomControls: false,
        ),
        IOSUiSettings(
          title: cropTitle,
          aspectRatioLockEnabled: true,
          resetAspectRatioEnabled: false,
        ),
      ],
    );
  } on PlatformException catch (error) {
    throw Exception('Kirpma acilamadi: ${error.message ?? error.code}');
  }
  if (cropped == null) return null;

  final bytes = await File(cropped.path).readAsBytes();
  if (bytes.isEmpty) return null;

  final apiClient = serviceLocator<ApiClient>();
  final fileName = fileNameFromPath(cropped.path, fallback: picked.name);
  final mimeType = inferImageMimeType(fileName);

  final initResult = await apiClient.post<ProfileUploadInitResult>(
    '/api/v1/user/media/init-upload',
    body: {
      'ownerType': ownerType,
      'ownerId': ownerId,
      'kind': 'IMAGE',
      'visibility': 'PUBLIC',
      'mimeType': mimeType,
      'sizeBytes': bytes.length,
      'originalFileName': fileName,
    },
    decoder: (json) =>
        ProfileUploadInitResult.fromJson(json as Map<String, dynamic>),
  );

  await Dio().put(
    initResult.uploadUrl,
    data: bytes,
    options: Options(
      headers: {'Content-Type': mimeType},
      contentType: mimeType,
    ),
  );

  final completed = await apiClient.post<ProfileUploadedMedia>(
    '/api/v1/user/media/complete-upload',
    body: {'assetId': initResult.assetId},
    decoder: (json) =>
        ProfileUploadedMedia.fromJson(json as Map<String, dynamic>),
  );

  final assetId = completed.uuid.trim();
  if (assetId.isEmpty) {
    throw Exception('Yukleme sonrasi assetId alinmadi');
  }

  return ProfilePhotoUploadResult(
    assetId: assetId,
    sourceUrl: completed.sourceUrl,
    playbackUrl: completed.playbackUrl,
  );
}

Future<ProfileUploadedMedia> uploadProfileMediaAsset({
  required List<int> bytes,
  required String ownerType,
  required String ownerId,
  required String mediaKind,
  required String mimeType,
  required String originalFileName,
}) async {
  if (bytes.isEmpty) {
    throw Exception('Yuklenecek dosya bos olamaz');
  }

  final apiClient = serviceLocator<ApiClient>();
  final initResult = await apiClient.post<ProfileUploadInitResult>(
    '/api/v1/user/media/init-upload',
    body: {
      'ownerType': ownerType,
      'ownerId': ownerId,
      'kind': mediaKind,
      'visibility': 'PUBLIC',
      'mimeType': mimeType,
      'sizeBytes': bytes.length,
      'originalFileName': originalFileName,
    },
    decoder: (json) =>
        ProfileUploadInitResult.fromJson(json as Map<String, dynamic>),
  );

  await Dio().put(
    initResult.uploadUrl,
    data: bytes,
    options: Options(
      headers: {'Content-Type': mimeType},
      contentType: mimeType,
    ),
  );

  return apiClient.post<ProfileUploadedMedia>(
    '/api/v1/user/media/complete-upload',
    body: {'assetId': initResult.assetId},
    decoder: (json) =>
        ProfileUploadedMedia.fromJson(json as Map<String, dynamic>),
  );
}

class ProfileScreenLoadCoordinator {
  String? _mediaProfileId;
  String? _followUserId;
  String? _followStatusKey;
  String? _venueProfileId;

  void scheduleMediaLoad(
    BuildContext context, {
    required bool mounted,
    required String profileId,
    required ProfileMediaOwnerType profileType,
  }) {
    if (profileId.isEmpty || _mediaProfileId == profileId) return;
    _mediaProfileId = profileId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<ProfileMediaCubit>().loadMedia(
        profileType: profileType.apiValue,
        profileId: profileId,
      );
    });
  }

  void scheduleFollowCountsLoad(
    BuildContext context, {
    required bool mounted,
    required String userId,
  }) {
    if (userId.isEmpty || _followUserId == userId) return;
    _followUserId = userId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<FollowCountCubit>().loadCounts(userId);
    });
  }

  void scheduleAcceptedVenuesLoad(
    BuildContext context, {
    required bool mounted,
    required String profileId,
  }) {
    if (profileId.isEmpty || _venueProfileId == profileId) return;
    _venueProfileId = profileId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<ArtistVenueConnectionsCubit>().loadAcceptedVenues(profileId);
    });
  }

  void scheduleFollowStatusLoad(
    BuildContext context, {
    required bool mounted,
    required String followerId,
    required String followingId,
    String separator = ':',
  }) {
    if (followerId.isEmpty || followingId.isEmpty) return;
    if (followerId == followingId) return;
    final nextKey = '$followerId$separator$followingId';
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
}
