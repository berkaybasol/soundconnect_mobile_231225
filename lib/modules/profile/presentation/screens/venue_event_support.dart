import 'package:flutter/material.dart';

class VenueOwnerEventItem {
  final String id;
  final String title;
  final String? posterImage;
  final String performerName;
  final String? musicianProfileId;
  final DateTime eventDate;
  final String startTime;
  final String? endTime;
  final String? description;

  const VenueOwnerEventItem({
    required this.id,
    required this.title,
    required this.posterImage,
    required this.performerName,
    required this.musicianProfileId,
    required this.eventDate,
    required this.startTime,
    required this.endTime,
    required this.description,
  });

  factory VenueOwnerEventItem.fromJson(Map<String, dynamic> json) {
    return VenueOwnerEventItem(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      posterImage: json['posterImage']?.toString(),
      performerName: json['performerName']?.toString() ?? 'Sanatci',
      musicianProfileId: json['musicianProfileId']?.toString(),
      eventDate:
          DateTime.tryParse(json['eventDate']?.toString() ?? '') ??
          DateTime.now(),
      startTime: json['startTime']?.toString() ?? '',
      endTime: json['endTime']?.toString(),
      description: json['description']?.toString(),
    );
  }
}

class MusicianSearchOption {
  final String profileId;
  final String displayName;
  final String? secondaryLabel;
  final String? profilePictureUrl;

  const MusicianSearchOption({
    required this.profileId,
    required this.displayName,
    required this.secondaryLabel,
    required this.profilePictureUrl,
  });

  factory MusicianSearchOption.fromJson(Map<String, dynamic> json) {
    final username = json['username']?.toString().trim();
    final stageName = json['stageName']?.toString().trim();
    final displayName = (stageName != null && stageName.isNotEmpty)
        ? stageName
        : (username != null && username.isNotEmpty ? username : 'Sanatci');
    final secondaryLabel =
        (username != null && username.isNotEmpty && username != displayName)
        ? '@$username'
        : null;

    return MusicianSearchOption(
      profileId: json['profileId']?.toString() ?? '',
      displayName: displayName,
      secondaryLabel: secondaryLabel,
      profilePictureUrl: json['profilePictureUrl']?.toString(),
    );
  }
}

class VenueEventDraft {
  final String title;
  final String description;
  final DateTime eventDate;
  final TimeOfDay startTime;
  final TimeOfDay? endTime;
  final String? posterImage;
  final String? musicianProfileId;
  final String? manualPerformerName;

  const VenueEventDraft({
    required this.title,
    required this.description,
    required this.eventDate,
    required this.startTime,
    required this.endTime,
    required this.posterImage,
    required this.musicianProfileId,
    required this.manualPerformerName,
  });
}

String formatVenueEventDate(DateTime value) {
  return '${value.day.toString().padLeft(2, '0')}.${value.month.toString().padLeft(2, '0')}.${value.year}';
}

String formatVenueDisplayTime(String value) {
  final normalized = value.trim();
  if (normalized.isEmpty) return '';
  final parts = normalized.split(':');
  if (parts.length >= 2) {
    final hour = parts[0].padLeft(2, '0');
    final minute = parts[1].padLeft(2, '0');
    return '$hour:$minute';
  }
  return normalized;
}

String formatVenueApiDate(DateTime value) {
  return '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
}

String formatVenueApiTime(TimeOfDay value) {
  return '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}:00';
}
