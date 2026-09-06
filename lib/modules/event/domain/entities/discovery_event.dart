import 'package:flutter/material.dart';

class DiscoveryEvent {
  final String id;
  final String title;
  final String performerName;
  final String? musicianProfileId;
  final String? bandId;
  final String performerType;
  final String? performerImageUrl;
  final List<String> bandMembers;
  final String? venueId;
  final String venueName;
  final String? venueImageUrl;
  final String? venueCity;
  final String? venueDistrict;
  final String? venueNeighborhood;
  final DateTime? eventDate;
  final TimeOfDay? startTime;
  final TimeOfDay? endTime;
  final String? posterImageUrl;
  final String description;

  const DiscoveryEvent({
    required this.id,
    required this.title,
    required this.performerName,
    required this.musicianProfileId,
    this.bandId,
    required this.performerType,
    required this.performerImageUrl,
    required this.bandMembers,
    required this.venueId,
    required this.venueName,
    required this.venueImageUrl,
    required this.venueCity,
    required this.venueDistrict,
    required this.venueNeighborhood,
    required this.eventDate,
    required this.startTime,
    required this.endTime,
    required this.posterImageUrl,
    required this.description,
  });
}
