import 'table_group_participant.dart';

class TableGroupLocation {
  final String id;
  final String name;

  const TableGroupLocation({required this.id, required this.name});
}

class TableGroup {
  final String id;
  final String ownerId;
  final String? ownerUsername;
  final String? ownerProfileImageUrl;
  final String? venueId;
  final String? venueName;
  final String? description;
  final int maxPersonCount;
  final List<String> genderPrefs;
  final int ageMin;
  final int ageMax;
  /// User-selected gathering time. Display this in table surfaces.
  final DateTime? meetingAt;

  /// Technical lifecycle cutoff returned by the server.
  final DateTime? expiresAt;
  final String status;
  final List<TableGroupParticipant> participants;
  final TableGroupLocation city;
  final TableGroupLocation? district;
  final TableGroupLocation? neighborhood;

  const TableGroup({
    required this.id,
    required this.ownerId,
    required this.ownerUsername,
    required this.ownerProfileImageUrl,
    required this.venueId,
    required this.venueName,
    this.description,
    required this.maxPersonCount,
    required this.genderPrefs,
    required this.ageMin,
    required this.ageMax,
    this.meetingAt,
    required this.expiresAt,
    required this.status,
    required this.participants,
    required this.city,
    required this.district,
    required this.neighborhood,
  });

  int get acceptedCount => participants
      .where(
        (participant) =>
            participant.status == TableGroupParticipantStatus.accepted,
      )
      .length;
}
