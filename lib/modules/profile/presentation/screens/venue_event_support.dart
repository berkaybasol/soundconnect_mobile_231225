import 'package:flutter/material.dart';

class VenueOwnerEventItem {
  final String id;
  final String title;
  final String performerName;
  final DateTime eventDate;
  final String startTime;
  final String? endTime;
  final String? description;

  const VenueOwnerEventItem({
    required this.id,
    required this.title,
    required this.performerName,
    required this.eventDate,
    required this.startTime,
    required this.endTime,
    required this.description,
  });

  factory VenueOwnerEventItem.fromJson(Map<String, dynamic> json) {
    return VenueOwnerEventItem(
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
  final String? musicianProfileId;
  final String? manualPerformerName;

  const VenueEventDraft({
    required this.title,
    required this.description,
    required this.eventDate,
    required this.startTime,
    required this.endTime,
    required this.musicianProfileId,
    required this.manualPerformerName,
  });
}

String formatVenueEventDate(DateTime value) {
  return '${value.day.toString().padLeft(2, '0')}.${value.month.toString().padLeft(2, '0')}.${value.year}';
}

String formatVenueApiDate(DateTime value) {
  return '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
}

String formatVenueApiTime(TimeOfDay value) {
  return '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}:00';
}
