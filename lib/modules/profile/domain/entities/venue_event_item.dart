import 'package:flutter/material.dart';

import '../../../../shared/event_performer_identity.dart';

class VenueOwnerEventItem {
  final String id;
  final String title;
  final String? posterImage;
  final String performerName;
  final String? musicianProfileId;
  final String? bandId;
  final String performerType;
  final DateTime eventDate;
  final String startTime;
  final String? endTime;
  final String? description;
  final String? venueId;

  final String? venueName;
  final String? venueCity;
  final String? venueDistrict;
  final String? venueNeighborhood;
  final String eventOrigin;
  final String venueApprovalStatus;
  final bool venueCalendarApproved;

  const VenueOwnerEventItem({
    required this.id,
    required this.title,
    required this.posterImage,
    required this.performerName,
    required this.musicianProfileId,
    this.bandId,
    this.performerType = 'MANUAL',
    required this.eventDate,
    required this.startTime,
    required this.endTime,
    required this.description,
    this.venueId,
    this.venueName,
    this.venueCity,
    this.venueDistrict,
    this.venueNeighborhood,
    this.eventOrigin = 'VENUE',
    this.venueApprovalStatus = 'APPROVED',
    this.venueCalendarApproved = true,
  });

  factory VenueOwnerEventItem.fromJson(Map<String, dynamic> json) {
    final performerIdentity = EventPerformerIdentity.fromWire(
      performerType: json['performerType'],
      musicianProfileId: json['musicianProfileId'],
      bandId: json['bandId'],
    );
    return VenueOwnerEventItem(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      posterImage: json['posterImage']?.toString(),
      performerName: json['performerName']?.toString() ?? 'Sanatçı',
      musicianProfileId: performerIdentity.musicianProfileId,
      bandId: performerIdentity.bandId,
      performerType: performerIdentity.performerType,
      eventDate:
          DateTime.tryParse(json['eventDate']?.toString() ?? '') ??
          DateTime.now(),
      startTime: json['startTime']?.toString() ?? '',
      endTime: json['endTime']?.toString(),
      description: json['description']?.toString(),
      venueId: json['venueId']?.toString(),
      venueName: json['venueName']?.toString(),
      venueCity: json['venueCity']?.toString(),
      venueDistrict: json['venueDistrict']?.toString(),
      venueNeighborhood: json['venueNeighborhood']?.toString(),
      eventOrigin: json['eventOrigin']?.toString() ?? 'VENUE',
      venueApprovalStatus:
          json['venueApprovalStatus']?.toString() ?? 'APPROVED',
      venueCalendarApproved:
          json['venueCalendarApproved'] == true ||
          !json.containsKey('venueCalendarApproved'),
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
  final String? bandId;
  final String? manualPerformerName;

  const VenueEventDraft({
    required this.title,
    required this.description,
    required this.eventDate,
    required this.startTime,
    required this.endTime,
    required this.posterImage,
    required this.musicianProfileId,
    required this.bandId,
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

DateTime venueEventTimelineEnd(VenueOwnerEventItem item) {
  final date = item.eventDate;
  final start = _parseVenueEventTime(item.startTime);
  final end = _parseVenueEventTime(item.endTime);

  if (start == null) {
    return DateTime(date.year, date.month, date.day, 23, 59, 59);
  }

  final startMoment = DateTime(
    date.year,
    date.month,
    date.day,
    start.$1,
    start.$2,
  );
  if (end == null) {
    return startMoment.add(const Duration(hours: 1));
  }

  final endMoment = DateTime(date.year, date.month, date.day, end.$1, end.$2);
  if (endMoment.isBefore(startMoment)) {
    return startMoment.add(const Duration(hours: 1));
  }
  return endMoment;
}

bool isVenueEventPast(VenueOwnerEventItem item, {DateTime? now}) {
  return venueEventTimelineEnd(item).isBefore(now ?? DateTime.now());
}

/// Calendar dates, not elapsed 24-hour periods: the public window is today + 6.
DateTime venueEventProfileVisibleFrom(DateTime eventDate) =>
    DateTime(eventDate.year, eventDate.month, eventDate.day - 6);

bool isVenueEventBeyondWeek(DateTime eventDate, {DateTime? now}) {
  final current = now ?? DateTime.now();
  final today = DateTime(current.year, current.month, current.day);
  return venueEventProfileVisibleFrom(eventDate).isAfter(today);
}

(int, int)? _parseVenueEventTime(String? value) {
  final parts = value?.trim().split(':');
  if (parts == null || parts.length < 2) return null;
  final hour = int.tryParse(parts[0]);
  final minute = int.tryParse(parts[1]);
  if (hour == null || minute == null) return null;
  if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
  return (hour, minute);
}
