import '../../domain/entities/studio_profile.dart';
import '../../domain/profile_contact_uri.dart';
import '../../../spotify/data/models/spotify_track_preview_model.dart';

class StudioProfileModel extends StudioProfile {
  const StudioProfileModel({
    required super.id,
    required super.userId,
    required super.name,
    required super.description,
    required super.profilePictureMediaId,
    required super.profilePictureUrl,
    required super.address,
    required super.phone,
    required super.website,
    required super.facilities,
    required super.instagramUrl,
    required super.youtubeUrl,
    required super.timeZone,
    required super.version,
    required super.spotifyTrackIds,
    required super.spotifyTracks,
    required super.activeRoomCount,
    required super.backlineUnitCount,
    super.cityId,
    super.cityName,
    super.districtId,
    super.districtName,
    super.neighborhoodId,
    super.neighborhoodName,
  });

  factory StudioProfileModel.fromJson(Object? value) {
    final json = _jsonObject(value);
    final rawFacilities = json['facilities'];
    if (rawFacilities is! List) {
      throw const FormatException('facilities must be a JSON array');
    }
    final id = _requiredString(json, 'id');
    final userId = _requiredString(json, 'userId');
    final timeZone = _requiredString(json, 'timeZone');
    final version = _requiredNonNegativeInt(json, 'version');
    final activeRoomCount = _requiredNonNegativeInt(json, 'activeRoomCount');
    final backlineUnitCount = _requiredNonNegativeInt(
      json,
      'backlineUnitCount',
    );
    final spotifyTrackIds = _requiredStringList(
      json['spotifyTrackIds'],
      'spotifyTrackIds',
    );
    final spotifyTracks = _spotifyTracks(json['spotifyTracks']);
    if (spotifyTrackIds.length != spotifyTracks.length) {
      throw const FormatException(
        'spotifyTrackIds and spotifyTracks must have matching lengths',
      );
    }
    for (var index = 0; index < spotifyTrackIds.length; index++) {
      if (spotifyTrackIds[index] != spotifyTracks[index].id) {
        throw const FormatException(
          'spotifyTrackIds and spotifyTracks must have matching order',
        );
      }
    }
    return StudioProfileModel(
      id: id,
      userId: userId,
      name: _stringOrNull(json['name'], 'name'),
      description: _stringOrNull(json['description'], 'description'),
      profilePictureMediaId: _stringOrNull(
        json['profilePictureMediaId'],
        'profilePictureMediaId',
      ),
      profilePictureUrl: _httpUrlOrNull(
        json['profilePictureUrl'],
        'profilePictureUrl',
      ),
      address: _stringOrNull(json['address'] ?? json['adress'], 'address'),
      cityId: _stringOrNull(json['cityId'], 'cityId'),
      cityName: _stringOrNull(json['cityName'], 'cityName'),
      districtId: _stringOrNull(json['districtId'], 'districtId'),
      districtName: _stringOrNull(json['districtName'], 'districtName'),
      neighborhoodId: _stringOrNull(json['neighborhoodId'], 'neighborhoodId'),
      neighborhoodName: _stringOrNull(
        json['neighborhoodName'],
        'neighborhoodName',
      ),
      phone: _phoneOrNull(json['phone']),
      website: _httpUrlOrNull(json['website'], 'website'),
      facilities: _requiredStringList(rawFacilities, 'facilities'),
      instagramUrl: _httpUrlOrNull(json['instagramUrl'], 'instagramUrl'),
      youtubeUrl: _httpUrlOrNull(json['youtubeUrl'], 'youtubeUrl'),
      timeZone: timeZone,
      version: version,
      spotifyTrackIds: spotifyTrackIds,
      spotifyTracks: spotifyTracks,
      activeRoomCount: activeRoomCount,
      backlineUnitCount: backlineUnitCount,
    );
  }

  static List<String> _requiredStringList(Object? value, String field) {
    if (value is! List) {
      throw FormatException('$field must be a JSON array of strings');
    }
    return value
        .map((item) {
          if (item is! String || item.trim().isEmpty) {
            throw FormatException('$field must contain only non-blank strings');
          }
          return item.trim();
        })
        .toList(growable: false);
  }

  static List<SpotifyTrackPreviewModel> _spotifyTracks(Object? value) {
    if (value is! List) {
      throw const FormatException('spotifyTracks must be a JSON array');
    }
    return value
        .map((item) {
          if (item is! Map || item.keys.any((key) => key is! String)) {
            throw const FormatException(
              'spotifyTracks must contain only JSON objects',
            );
          }
          final json = Map<String, dynamic>.from(item);
          _validateSpotifyTrackJson(json);
          final track = SpotifyTrackPreviewModel.fromJson(json);
          if (track.id.trim().isEmpty) {
            throw const FormatException(
              'spotifyTracks must contain a non-blank track id',
            );
          }
          return track;
        })
        .toList(growable: false);
  }

  static void _validateSpotifyTrackJson(Map<String, dynamic> json) {
    final id = json['spotifyTrackId'] ?? json['id'];
    if (id is! String || id.trim().isEmpty) {
      throw const FormatException('spotify track id must be a string');
    }
    for (final field in const <String>['name', 'albumName']) {
      final value = json[field];
      if (value != null && value is! String) {
        throw FormatException('$field must be a string');
      }
    }
    for (final field in const <String>[
      'previewUrl',
      'spotifyUrl',
      'albumImageUrl',
    ]) {
      final value = json[field];
      if (value != null &&
          (value is! String ||
              value.trim().isEmpty ||
              profileHttpUri(value) == null)) {
        throw FormatException('$field must be an absolute HTTP(S) URL');
      }
    }
    final duration = json['durationMs'] ?? json['durationSeconds'];
    if (duration != null &&
        (duration is! num ||
            !duration.isFinite ||
            duration != duration.toInt() ||
            duration < 0)) {
      throw const FormatException('spotify track duration must be an integer');
    }
    final explicit = json['explicit'];
    if (explicit != null && explicit is! bool) {
      throw const FormatException('explicit must be a boolean');
    }
    for (final field in const <String>['artistNames', 'artistIds']) {
      final value = json[field];
      if (value != null &&
          (value is! List ||
              value.any((item) => item is! String || item.trim().isEmpty))) {
        throw FormatException('$field must contain only non-blank strings');
      }
    }
  }

  static String? _stringOrNull(Object? value, String field) {
    if (value == null) return null;
    if (value is! String) throw FormatException('$field must be a string');
    final text = value.trim();
    return text.isEmpty ? null : text;
  }

  static String? _httpUrlOrNull(Object? value, String field) {
    if (value == null) return null;
    if (value is! String) throw FormatException('$field must be a URL string');
    if (value.trim().isEmpty) return null;
    final uri = profileHttpUri(value);
    if (uri == null) {
      throw FormatException('$field must be an absolute HTTP(S) URL');
    }
    return uri.toString();
  }

  static String? _phoneOrNull(Object? value) {
    if (value == null) return null;
    if (value is! String) {
      throw const FormatException('phone must be a string');
    }
    if (value.trim().isEmpty) return null;
    final digits = canonicalProfilePhoneDigits(value);
    if (digits == null) {
      throw const FormatException('phone must be a valid dialable number');
    }
    return digits;
  }

  static Map<String, dynamic> _jsonObject(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      if (value.keys.any((key) => key is! String)) {
        throw const FormatException(
          'Studio profile JSON object keys must be strings',
        );
      }
      return Map<String, dynamic>.from(value);
    }
    throw const FormatException('Studio profile must be a JSON object');
  }

  static String _requiredString(Map<String, dynamic> json, String key) {
    final value = _stringOrNull(json[key], key);
    if (value == null) throw FormatException('$key must be a string');
    return value;
  }

  static int _requiredNonNegativeInt(Map<String, dynamic> json, String key) {
    final value = json[key];
    final int? parsed = switch (value) {
      int number => number,
      num number when number.isFinite && number == number.toInt() =>
        number.toInt(),
      _ => null,
    };
    if (parsed == null || parsed < 0) {
      throw FormatException('$key must be a non-negative integer');
    }
    return parsed;
  }
}
