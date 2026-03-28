import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

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
