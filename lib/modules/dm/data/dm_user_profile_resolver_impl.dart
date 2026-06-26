import '../../../core/network/api_client.dart';
import '../domain/dm_user_profile_resolver.dart';
import '../domain/entities/dm_profile_target.dart';
import '../../profile/domain/entities/musician_search_option.dart';
import '../../profile/domain/entities/profile_venue_models.dart';
import '../../profile/domain/musician_profile_repository.dart';
import '../../profile/domain/musician_search_repository.dart';
import '../../profile/domain/venue_directory_repository.dart';
import '../../profile/domain/venue_profile_repository.dart';

class DmUserProfileResolverImpl implements DmUserProfileResolver {
  final ApiClient _apiClient;
  final MusicianSearchRepository _musicianSearchRepository;
  final MusicianProfileRepository _musicianProfileRepository;
  final VenueDirectoryRepository _venueDirectoryRepository;
  final VenueProfileRepository _venueProfileRepository;

  DmUserProfileResolverImpl({
    required ApiClient apiClient,
    required MusicianSearchRepository musicianSearchRepository,
    required MusicianProfileRepository musicianProfileRepository,
    required VenueDirectoryRepository venueDirectoryRepository,
    required VenueProfileRepository venueProfileRepository,
  }) : _apiClient = apiClient,
       _musicianSearchRepository = musicianSearchRepository,
       _musicianProfileRepository = musicianProfileRepository,
       _venueDirectoryRepository = venueDirectoryRepository,
       _venueProfileRepository = venueProfileRepository;

  final Map<String, List<DmProfileTarget>> _cacheByUserId =
      <String, List<DmProfileTarget>>{};

  @override
  Future<List<DmProfileTarget>> resolveByUserId({
    required String userId,
    String? usernameHint,
  }) async {
    final normalizedUserId = userId.trim();
    if (normalizedUserId.isEmpty) return const [];
    final cached = _cacheByUserId[normalizedUserId];
    if (cached != null) return cached;

    final List<DmProfileTarget> resolved = <DmProfileTarget>[];
    final seen = <String>{};

    final profileTargets = await _resolveProfileTargets(normalizedUserId);
    for (final item in profileTargets) {
      final key = '${item.type.name}:${item.id}';
      if (seen.add(key)) {
        resolved.add(item);
      }
    }

    final musicianTargets = await _resolveMusicianTargets(
      userId: normalizedUserId,
      usernameHint: usernameHint,
    );
    for (final item in musicianTargets) {
      final key = '${item.type.name}:${item.id}';
      if (seen.add(key)) {
        resolved.add(item);
      }
    }

    final venueTargets = await _resolveVenueTargets(normalizedUserId);
    for (final item in venueTargets) {
      final key = '${item.type.name}:${item.id}';
      if (seen.add(key)) {
        resolved.add(item);
      }
    }

    _cacheByUserId[normalizedUserId] = resolved;
    return resolved;
  }

  Future<List<DmProfileTarget>> _resolveProfileTargets(String userId) async {
    try {
      return await _apiClient.get<List<DmProfileTarget>>(
        '/api/v1/public/profiles/by-user/$userId',
        decoder: (json) {
          if (json is! Map<String, dynamic>) return const [];
          final profiles = json['profiles'];
          if (profiles is! List) return const [];
          return profiles
              .whereType<Map<String, dynamic>>()
              .map(_profileTargetFromJson)
              .whereType<DmProfileTarget>()
              .toList();
        },
      );
    } catch (_) {
      return const [];
    }
  }

  DmProfileTarget? _profileTargetFromJson(Map<String, dynamic> json) {
    final type = _targetTypeFromApi(json['type']?.toString());
    final id = json['profileId']?.toString().trim() ?? '';
    final displayName = json['displayName']?.toString().trim() ?? '';
    if (type == null || id.isEmpty || displayName.isEmpty) return null;
    final imageUrl = json['profilePictureUrl']?.toString().trim() ?? '';
    return DmProfileTarget(
      type: type,
      id: id,
      displayName: displayName,
      imageUrl: imageUrl.isEmpty ? null : imageUrl,
    );
  }

  DmProfileTargetType? _targetTypeFromApi(String? value) {
    return switch (value?.trim().toUpperCase()) {
      'MUSICIAN' => DmProfileTargetType.musician,
      'VENUE' => DmProfileTargetType.venue,
      _ => null,
    };
  }

  Future<List<DmProfileTarget>> _resolveMusicianTargets({
    required String userId,
    String? usernameHint,
  }) async {
    final hint = usernameHint?.trim() ?? '';
    if (hint.isEmpty) return const [];

    final searchResult = await _musicianSearchRepository.search(hint);
    if (!searchResult.isSuccess || searchResult.data == null) return const [];

    final List<DmProfileTarget> targets = <DmProfileTarget>[];
    final Iterable<MusicianSearchOption> candidates = searchResult.data!.take(
      20,
    );
    for (final item in candidates) {
      final profileResult = await _musicianProfileRepository
          .getPublicProfileByProfileId(item.profileId);
      if (!profileResult.isSuccess || profileResult.data == null) continue;
      final profile = profileResult.data!;
      if (profile.userId != userId) continue;
      targets.add(
        DmProfileTarget(
          type: DmProfileTargetType.musician,
          id: item.profileId,
          displayName: item.displayName,
          imageUrl: item.profilePictureUrl,
        ),
      );
    }
    return targets;
  }

  Future<List<DmProfileTarget>> _resolveVenueTargets(String userId) async {
    final allVenuesResult = await _venueDirectoryRepository.getAllVenues();
    if (!allVenuesResult.isSuccess || allVenuesResult.data == null) {
      return const [];
    }
    final List<VenueOption> venues = allVenuesResult.data!;
    final List<DmProfileTarget> targets = <DmProfileTarget>[];

    // Network maliyetini sinirli tutmak icin once makul bir aralikta dene.
    final Iterable<VenueOption> candidates = venues.take(80);
    for (final venue in candidates) {
      final detailResult = await _venueProfileRepository.getPublicVenueProfile(
        venueId: venue.id,
      );
      if (!detailResult.isSuccess || detailResult.data == null) continue;
      final detail = detailResult.data!;
      if (detail.ownerUserId != userId) continue;
      targets.add(
        DmProfileTarget(
          type: DmProfileTargetType.venue,
          id: detail.venueId,
          displayName: detail.venueName,
          imageUrl: detail.profilePictureUrl,
        ),
      );
    }

    return targets;
  }
}
