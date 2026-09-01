import '../../domain/entities/table_group.dart';
import '../../domain/entities/table_group_participant.dart';
import 'table_group_wire_date.dart';

class TableGroupModel extends TableGroup {
  const TableGroupModel({
    required super.id,
    required super.ownerId,
    required super.ownerUsername,
    required super.ownerProfileImageUrl,
    required super.venueId,
    required super.venueName,
    super.description,
    required super.maxPersonCount,
    required super.genderPrefs,
    required super.ageMin,
    required super.ageMax,
    super.meetingAt,
    required super.expiresAt,
    required super.status,
    required super.participants,
    required super.city,
    required super.district,
    required super.neighborhood,
  });

  factory TableGroupModel.fromJson(Map<String, dynamic> json) {
    return TableGroupModel(
      id: json['id']?.toString() ?? '',
      ownerId: json['ownerId']?.toString() ?? '',
      ownerUsername:
          json['ownerUsername']?.toString() ??
          json['owner_name']?.toString() ??
          json['username']?.toString(),
      ownerProfileImageUrl:
          json['ownerProfileImageUrl']?.toString() ??
          json['ownerProfilePhotoUrl']?.toString() ??
          json['ownerAvatarUrl']?.toString() ??
          json['ownerPhotoUrl']?.toString() ??
          json['profileImageUrl']?.toString(),
      venueId: _trimmedOrNull(json['venueId']),
      venueName: _trimmedOrNull(json['venueName']),
      description: _trimmedOrNull(json['description']),
      maxPersonCount: (json['maxPersonCount'] as num?)?.toInt() ?? 0,
      genderPrefs: _stringList(json['genderPrefs']),
      ageMin: (json['ageMin'] as num?)?.toInt() ?? 18,
      ageMax: (json['ageMax'] as num?)?.toInt() ?? 99,
      // During the rolling deploy an older backend only returns expiresAt,
      // whose historic meaning was the selected gathering time.
      meetingAt: parseTableGroupExpiryWireDate(
        json['meetingAt'] ?? json['expiresAt'],
      ),
      expiresAt: parseTableGroupExpiryWireDate(json['expiresAt']),
      status: json['status']?.toString() ?? 'ACTIVE',
      participants: _participants(json['participants']),
      city:
          _location(json['city']) ??
          const TableGroupLocation(id: '', name: 'Bilinmiyor'),
      district: _location(json['district']),
      neighborhood: _location(json['neighborhood']),
    );
  }

  static List<String> _stringList(Object? value) {
    if (value is List) {
      return value.map((item) => item.toString()).toList();
    }
    return const [];
  }

  static String? _trimmedOrNull(Object? value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }

  static TableGroupLocation? _location(Object? value) {
    if (value is! Map<String, dynamic>) return null;
    return TableGroupLocation(
      id: value['id']?.toString() ?? '',
      name: value['name']?.toString() ?? '',
    );
  }

  static List<TableGroupParticipant> _participants(Object? value) {
    if (value is! List) return const [];
    return value.whereType<Map<String, dynamic>>().map((item) {
      final statusText =
          item['status']?.toString().trim().toUpperCase() ?? 'PENDING';
      final status = switch (statusText) {
        'ACCEPTED' => TableGroupParticipantStatus.accepted,
        'REJECTED' => TableGroupParticipantStatus.rejected,
        'KICKED' => TableGroupParticipantStatus.kicked,
        'LEFT' => TableGroupParticipantStatus.left,
        _ => TableGroupParticipantStatus.pending,
      };
      return TableGroupParticipant(
        userId: item['userId']?.toString() ?? '',
        joinedAt: parseTableGroupWireDate(item['joinedAt']),
        status: status,
        joinNote: item['joinNote']?.toString(),
        username:
            item['username']?.toString() ??
            item['displayName']?.toString() ??
            item['name']?.toString(),
        profilePictureUrl:
            item['profilePictureUrl']?.toString() ??
            item['profileImageUrl']?.toString() ??
            item['avatarUrl']?.toString(),
      );
    }).toList();
  }
}
