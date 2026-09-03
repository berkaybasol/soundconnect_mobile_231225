import 'dart:collection';

import '../../../core/network/api_client.dart';
import '../../profile/domain/entities/listener_visibility_context.dart';
import '../domain/dm_user_profile_resolver.dart';
import '../domain/entities/dm_profile_target.dart';

typedef DmProfileResolverClock = DateTime Function();

/// Resolves a user's public profile targets through the canonical backend
/// resolver. Stable non-listener results are cached briefly because the same
/// user can appear in several surfaces at once. Listener results only share
/// concurrent in-flight work; their mutable visibility is always refetched.
class DmUserProfileResolverImpl implements DmUserProfileResolver {
  DmUserProfileResolverImpl({
    required ApiClient apiClient,
    Duration cacheTtl = const Duration(minutes: 5),
    Duration failureCacheTtl = const Duration(seconds: 15),
    int maxCacheEntries = 128,
    DmProfileResolverClock? clock,
  }) : assert(maxCacheEntries > 0),
       _apiClient = apiClient,
       _cacheTtl = cacheTtl,
       _failureCacheTtl = failureCacheTtl,
       _maxCacheEntries = maxCacheEntries,
       _clock = clock ?? DateTime.now;

  final ApiClient _apiClient;
  final Duration _cacheTtl;
  final Duration _failureCacheTtl;
  final int _maxCacheEntries;
  final DmProfileResolverClock _clock;

  final LinkedHashMap<String, _ProfileCacheEntry> _cache =
      LinkedHashMap<String, _ProfileCacheEntry>();
  final Map<String, Future<List<DmProfileTarget>>> _inFlight =
      <String, Future<List<DmProfileTarget>>>{};

  @override
  Future<List<DmProfileTarget>> resolveByUserId({
    required String userId,
    String? usernameHint,
  }) {
    final normalizedUserId = userId.trim();
    if (normalizedUserId.isEmpty) {
      return Future<List<DmProfileTarget>>.value(const []);
    }

    final cached = _readCache(normalizedUserId);
    if (cached != null) {
      return Future<List<DmProfileTarget>>.value(cached);
    }

    final existingRequest = _inFlight[normalizedUserId];
    if (existingRequest != null) return existingRequest;

    final request = _resolveAndCache(normalizedUserId);
    _inFlight[normalizedUserId] = request;
    request.whenComplete(() {
      if (identical(_inFlight[normalizedUserId], request)) {
        _inFlight.remove(normalizedUserId);
      }
    });
    return request;
  }

  Future<List<DmProfileTarget>> _resolveAndCache(String userId) async {
    try {
      final targets = await _apiClient.get<List<DmProfileTarget>>(
        '/api/v1/public/profiles/by-user/${Uri.encodeComponent(userId)}',
        decoder: _decodeTargets,
      );
      final immutableTargets = List<DmProfileTarget>.unmodifiable(targets);
      // Listener visibility is mutable and changes how every contextual
      // identity must be projected. Keeping either a STANDARD or GHOST
      // listener target in the positive cache can leak stale actions/badges.
      // In-flight calls are still coalesced, while stable non-listener target
      // collections retain the bounded TTL cache.
      if (!immutableTargets.any(
        (target) => target.type == DmProfileTargetType.listener,
      )) {
        _writeCache(userId, immutableTargets, _cacheTtl);
      }
      return immutableTargets;
    } catch (_) {
      // The domain contract predates Result<T>. Preserve its safe empty-list
      // fallback while negative-caching briefly to prevent request storms.
      const empty = <DmProfileTarget>[];
      _writeCache(userId, empty, _failureCacheTtl);
      return empty;
    }
  }

  List<DmProfileTarget> _decodeTargets(Object? json) {
    if (json is! Map<String, dynamic>) return const [];
    final profiles = json['profiles'];
    if (profiles is! List) return const [];

    final targets = <DmProfileTarget>[];
    final seen = <String>{};
    for (final item in profiles.whereType<Map<String, dynamic>>()) {
      final target = _profileTargetFromJson(item);
      if (target == null) continue;
      final key = '${target.type.name}:${target.id}';
      if (seen.add(key)) targets.add(target);
    }
    return targets;
  }

  DmProfileTarget? _profileTargetFromJson(Map<String, dynamic> json) {
    final type = switch (json['type']?.toString().trim().toUpperCase()) {
      'MUSICIAN' => DmProfileTargetType.musician,
      'VENUE' => DmProfileTargetType.venue,
      'LISTENER' => DmProfileTargetType.listener,
      'STUDIO' => DmProfileTargetType.studio,
      _ => null,
    };
    final id = json['profileId']?.toString().trim() ?? '';
    final displayName = json['displayName']?.toString().trim() ?? '';
    if (type == null || id.isEmpty || displayName.isEmpty) return null;

    final imageUrl = json['profilePictureUrl']?.toString().trim() ?? '';
    return DmProfileTarget(
      type: type,
      id: id,
      displayName: displayName,
      imageUrl: imageUrl.isEmpty ? null : imageUrl,
      visibilityMode: parseContextualListenerVisibilityMode(
        json['visibilityMode'],
      ),
    );
  }

  List<DmProfileTarget>? _readCache(String userId) {
    final entry = _cache.remove(userId);
    if (entry == null) return null;
    if (!entry.expiresAt.isAfter(_clock())) return null;

    // Reinsert to keep the map ordered from least to most recently used.
    _cache[userId] = entry;
    return entry.targets;
  }

  void _writeCache(String userId, List<DmProfileTarget> targets, Duration ttl) {
    _cache.remove(userId);
    _cache[userId] = _ProfileCacheEntry(
      targets: targets,
      expiresAt: _clock().add(ttl),
    );
    while (_cache.length > _maxCacheEntries) {
      _cache.remove(_cache.keys.first);
    }
  }
}

class _ProfileCacheEntry {
  const _ProfileCacheEntry({required this.targets, required this.expiresAt});

  final List<DmProfileTarget> targets;
  final DateTime expiresAt;
}
