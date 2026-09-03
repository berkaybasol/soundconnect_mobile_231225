import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/services.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/auth/token_store.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../shared/theme/app_colors.dart';
export '../../domain/entities/profile_upload_result.dart';
export '../../domain/draft_media_cleanup_coordinator.dart';
export '../../domain/profile_media_upload_repository.dart';
import '../../../artist_venue/presentation/cubit/artist_venue_connections_cubit.dart';
import '../../../follow/presentation/cubit/follow_action_cubit.dart';
import '../../../follow/presentation/cubit/follow_count_cubit.dart';
import '../../domain/entities/profile_upload_result.dart';
import '../../domain/profile_media_upload_repository.dart';
import '../cubit/profile_media_cubit.dart';

enum ProfileMediaOwnerType {
  musician('MUSICIAN'),
  venue('VENUE'),
  studio('STUDIO');

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

String? resolveUserIdFromJwtToken(String? token) {
  final rawToken = token?.trim() ?? '';
  if (rawToken.isEmpty) return null;
  final parts = rawToken.split('.');
  if (parts.length < 2) return null;

  try {
    final payload = utf8.decode(
      base64Url.decode(base64Url.normalize(parts[1])),
    );
    final decoded = jsonDecode(payload);
    if (decoded is! Map<String, dynamic>) return null;
    for (final key in const ['userId', 'uid', 'id', 'sub']) {
      final value = decoded[key]?.toString().trim() ?? '';
      if (value.isNotEmpty) return value;
    }
  } catch (_) {
    return null;
  }
  return null;
}

Future<String?> resolveCurrentViewerUserId() async {
  final tokenStore = serviceLocator<TokenStore>();
  return resolveUserIdFromJwtToken(await tokenStore.readToken());
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

Future<ProfilePhotoUploadResult?> pickCropAndUploadProfilePhoto({
  required BuildContext context,
  required ImagePicker imagePicker,
  required String ownerType,
  required String ownerId,
  String? profilePhotoTargetId,
  int? profilePhotoExpectedVersion,
  String cropTitle = 'Profil fotografini kirp',
  Color cropToolbarColor = const Color(0xFF0B1321),
  Color cropAccentColor = const Color(0xFFF47C7C),
}) async {
  final cropped = await pickAndCropProfileImage(
    imagePicker: imagePicker,
    cropTitle: cropTitle,
    aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
    imageQuality: 88,
    maxWidth: 1600,
    maxHeight: 1600,
    cropToolbarColor: cropToolbarColor,
    cropAccentColor: cropAccentColor,
  );
  if (cropped == null) return null;

  final repository = serviceLocator<ProfileMediaUploadRepository>();
  final fileName = fileNameFromPath(
    cropped.path,
    fallback: 'profile-photo.jpg',
  );
  final mimeType = inferImageMimeType(fileName);
  final source = await createProfileUploadSource(filePath: cropped.path);

  final result = await repository.uploadAsset(
    source: source,
    ownerType: ownerType,
    ownerId: ownerId,
    mediaKind: 'IMAGE',
    mimeType: mimeType,
    originalFileName: fileName,
    attachmentIntent: ProfileUploadAttachmentIntent.profilePicture(
      profileType: ownerType,
      targetId: profilePhotoTargetId,
      expectedVersion: profilePhotoExpectedVersion,
    ),
  );
  if (!result.isSuccess || result.data == null) {
    throw Exception(result.error?.message ?? 'Medya yuklenemedi');
  }
  final completed = result.data!;

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

Future<CroppedFile?> pickAndCropProfileImage({
  required ImagePicker imagePicker,
  required String cropTitle,
  required CropAspectRatio aspectRatio,
  int imageQuality = 92,
  double maxWidth = 2048,
  double maxHeight = 2048,
  Color cropToolbarColor = const Color(0xFF0B1321),
  Color cropAccentColor = const Color(0xFFF47C7C),
}) async {
  final picked = await imagePicker.pickImage(
    source: ImageSource.gallery,
    imageQuality: imageQuality,
    maxWidth: maxWidth,
    maxHeight: maxHeight,
  );
  if (picked == null) return null;

  CroppedFile? cropped;
  try {
    cropped = await ImageCropper().cropImage(
      sourcePath: picked.path,
      compressFormat: ImageCompressFormat.jpg,
      compressQuality: imageQuality,
      aspectRatio: aspectRatio,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: cropTitle,
          toolbarColor: cropToolbarColor,
          toolbarWidgetColor: AppColors.white,
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
  return cropped;
}

Future<ProfileUploadedMedia> uploadProfileMediaAsset({
  required ProfileUploadSource source,
  required String ownerType,
  required String ownerId,
  required String mediaKind,
  required String mimeType,
  required String originalFileName,
  ProfileUploadAttachmentIntent attachmentIntent =
      const ProfileUploadAttachmentIntent.none(),
  ProfileUploadProgress? onProgress,
  ProfileUploadStageChanged? onStageChanged,
  ProfileUploadCancellation? cancellation,
}) async {
  if (source.sizeBytes <= 0) {
    throw Exception('Yuklenecek dosya bos olamaz');
  }

  final repository = serviceLocator<ProfileMediaUploadRepository>();
  final result = await repository.uploadAsset(
    source: source,
    ownerType: ownerType,
    ownerId: ownerId,
    mediaKind: mediaKind,
    mimeType: mimeType,
    originalFileName: originalFileName,
    attachmentIntent: attachmentIntent,
    onProgress: onProgress,
    onStageChanged: onStageChanged,
    cancellation: cancellation,
  );
  if (!result.isSuccess || result.data == null) {
    throw Exception(result.error?.message ?? 'Medya yuklenemedi');
  }
  return result.data!;
}

Future<ProfileUploadSource> createProfileUploadSource({
  String? filePath,
  List<int>? bytes,
  Stream<List<int>>? readStream,
  int? sizeBytes,
}) async {
  final normalizedPath = filePath?.trim() ?? '';
  if (normalizedPath.isNotEmpty) {
    final file = File(normalizedPath);
    final length = await file.length();
    if (length <= 0) throw Exception('Yuklenecek dosya bos olamaz');
    return ProfileUploadSource(sizeBytes: length, openRead: file.openRead);
  }

  if (readStream != null && (sizeBytes ?? 0) > 0) {
    var opened = false;
    return ProfileUploadSource(
      sizeBytes: sizeBytes!,
      openRead: () {
        if (opened) {
          throw StateError('Upload stream can only be opened once');
        }
        opened = true;
        return readStream;
      },
    );
  }

  if (bytes != null && bytes.isNotEmpty) {
    return ProfileUploadSource.bytes(bytes);
  }
  throw Exception('Yuklenecek dosya okunamadi');
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
