import 'package:flutter/material.dart';

import '../../domain/entities/discovery_event.dart';

class DiscoveryEventModel extends DiscoveryEvent {
  const DiscoveryEventModel({
    required super.id,
    required super.title,
    required super.performerName,
    required super.musicianProfileId,
    required super.performerType,
    required super.performerImageUrl,
    required super.bandMembers,
    required super.venueId,
    required super.venueName,
    required super.venueImageUrl,
    required super.venueCity,
    required super.venueDistrict,
    required super.venueNeighborhood,
    required super.eventDate,
    required super.startTime,
    required super.endTime,
    required super.posterImageUrl,
    required super.description,
  });

  factory DiscoveryEventModel.fromJson(Map<String, dynamic> json) {
    return DiscoveryEventModel(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Etkinlik',
      performerName: json['performerName']?.toString() ?? 'Performer',
      musicianProfileId: json['musicianProfileId']?.toString(),
      performerType: json['performerType']?.toString() ?? 'MUSICIAN',
      performerImageUrl: _firstNonBlank(
        json,
        const <String>[
          'performerImageUrl',
          'performerProfileImage',
          'performerProfilePicture',
          'musicianProfilePicture',
          'artistProfilePicture',
        ],
      ),
      bandMembers: _parseBandMembers(json['bandMembers']),
      venueId: json['venueId']?.toString(),
      venueName: json['venueName']?.toString() ?? 'Mekan',
      venueImageUrl: _firstNonBlank(
        json,
        const <String>[
          'venueImageUrl',
          'venueProfilePicture',
          'venueProfileImage',
          'venueProfilePictureUrl',
        ],
      ),
      venueCity: json['venueCity']?.toString(),
      venueDistrict: json['venueDistrict']?.toString(),
      venueNeighborhood: json['venueNeighborhood']?.toString(),
      eventDate: DateTime.tryParse(json['eventDate']?.toString() ?? ''),
      startTime: _parseTime(json['startTime']?.toString()),
      endTime: _parseTime(json['endTime']?.toString()),
      posterImageUrl: _firstNonBlank(
        json,
        const <String>['posterImage', 'posterImageUrl', 'imageUrl'],
      ),
      description: json['description']?.toString() ?? '',
    );
  }

  static List<String> _parseBandMembers(Object? raw) {
    if (raw is List) {
      return raw.map((e) => e.toString()).where((e) => e.trim().isNotEmpty).toList();
    }
    if (raw is Set) {
      return raw.map((e) => e.toString()).where((e) => e.trim().isNotEmpty).toList();
    }
    return const <String>[];
  }

  static TimeOfDay? _parseTime(String? raw) {
    final value = (raw ?? '').trim();
    if (value.isEmpty) {
      return null;
    }
    final pieces = value.split(':');
    if (pieces.length < 2) {
      return null;
    }
    final hour = int.tryParse(pieces[0]);
    final minute = int.tryParse(pieces[1]);
    if (hour == null || minute == null) {
      return null;
    }
    return TimeOfDay(hour: hour, minute: minute);
  }

  static String? _firstNonBlank(
    Map<String, dynamic> json,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = json[key]?.toString();
      if (value != null && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return null;
  }
}
