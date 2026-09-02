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

  factory TableGroupModel.fromJson(Map<String, dynamic> json) =>
      TableGroupModel.fromWireJson(json);

  /// Strict decoder for the canonical server response.
  ///
  /// Missing fields, aliases, malformed collection members and implicit date
  /// zones are rejected at the network boundary instead of becoming plausible
  /// domain defaults.
  factory TableGroupModel.fromWireJson(Map<String, dynamic> json) {
    final status = _requiredText(json, 'status');
    if (!const <String>{'ACTIVE', 'INACTIVE', 'CANCELLED'}.contains(status)) {
      throw const FormatException('Invalid table-group status');
    }

    // startAt is server-owned and not currently rendered, but it remains a
    // required canonical response field. Validate it at the wire boundary so
    // an incomplete lifecycle payload cannot masquerade as a valid table.
    _requiredWireDate(json, 'startAt');
    final description = _nullableWireText(json, 'description');
    if (description == null && status == 'ACTIVE') {
      throw const FormatException(
        'Active table-group response requires description',
      );
    }

    return TableGroupModel(
      id: _requiredText(json, 'id'),
      ownerId: _requiredText(json, 'ownerId'),
      ownerUsername: _requiredText(json, 'ownerUsername'),
      ownerProfileImageUrl: _optionalWireText(
        json['ownerProfileImageUrl'],
        'ownerProfileImageUrl',
      ),
      venueId: _optionalWireText(json['venueId'], 'venueId'),
      venueName: _optionalWireText(json['venueName'], 'venueName'),
      // Pre-release local databases may contain terminal rows whose historical
      // description is explicitly null. Missing, blank or mistyped values are
      // still contract violations.
      description: description,
      maxPersonCount: _requiredInt(json, 'maxPersonCount'),
      genderPrefs: _requiredStringList(json, 'genderPrefs'),
      ageMin: _requiredInt(json, 'ageMin'),
      ageMax: _requiredInt(json, 'ageMax'),
      meetingAt: _requiredWireDate(json, 'meetingAt'),
      expiresAt: _requiredWireDate(json, 'expiresAt'),
      status: status,
      participants: _requiredParticipants(json['participants']),
      city: _requiredLocation(json['city'], 'city'),
      district: _optionalLocation(json['district'], 'district'),
      neighborhood: _optionalLocation(json['neighborhood'], 'neighborhood'),
    );
  }

  /// Tolerant parser reserved for legacy-shaped unit-test fixtures.
  /// Production repositories must use [fromWireJson].
  factory TableGroupModel.fromFixtureJson(Map<String, dynamic> json) {
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
      venueId: _fixtureText(json['venueId']),
      venueName: _fixtureText(json['venueName']),
      description: _fixtureText(json['description']),
      maxPersonCount: (json['maxPersonCount'] as num?)?.toInt() ?? 0,
      genderPrefs: _fixtureStringList(json['genderPrefs']),
      ageMin: (json['ageMin'] as num?)?.toInt() ?? 18,
      ageMax: (json['ageMax'] as num?)?.toInt() ?? 99,
      meetingAt: parseTableGroupWireDate(json['meetingAt']),
      expiresAt: parseTableGroupWireDate(json['expiresAt']),
      status: json['status']?.toString() ?? 'ACTIVE',
      participants: _fixtureParticipants(json['participants']),
      city:
          _fixtureLocation(json['city']) ??
          const TableGroupLocation(id: '', name: 'Bilinmiyor'),
      district: _fixtureLocation(json['district']),
      neighborhood: _fixtureLocation(json['neighborhood']),
    );
  }

  static String _requiredText(Map<String, dynamic> json, String key) {
    final raw = json[key];
    if (raw is! String || raw.isEmpty || raw != raw.trim()) {
      throw FormatException('Missing table-group field: $key');
    }
    return raw;
  }

  static String? _optionalWireText(Object? raw, String key) {
    if (raw == null) return null;
    if (raw is! String || raw.isEmpty || raw != raw.trim()) {
      throw FormatException('Invalid table-group field: $key');
    }
    return raw;
  }

  static String? _nullableWireText(Map<String, dynamic> json, String key) {
    if (!json.containsKey(key)) {
      throw FormatException('Missing table-group field: $key');
    }
    return _optionalWireText(json[key], key);
  }

  static int _requiredInt(Map<String, dynamic> json, String key) {
    final raw = json[key];
    if (raw is! int) {
      throw FormatException('Invalid table-group integer field: $key');
    }
    return raw;
  }

  static DateTime _requiredWireDate(Map<String, dynamic> json, String key) {
    final parsed = parseTableGroupWireDate(json[key]);
    if (parsed == null) {
      throw FormatException('Invalid table-group date field: $key');
    }
    return parsed;
  }

  static List<String> _requiredStringList(
    Map<String, dynamic> json,
    String key,
  ) {
    final raw = json[key];
    if (raw is! List) {
      throw FormatException('Invalid table-group list field: $key');
    }
    return List<String>.unmodifiable(
      raw.indexed.map((entry) {
        final value = entry.$2;
        if (value is! String || value.isEmpty || value != value.trim()) {
          throw FormatException(
            'Invalid table-group list field: $key[${entry.$1}]',
          );
        }
        return value;
      }),
    );
  }

  static TableGroupLocation _requiredLocation(Object? raw, String key) {
    final location = _decodeLocation(raw, key);
    if (location == null) {
      throw FormatException('Missing table-group location: $key');
    }
    return location;
  }

  static TableGroupLocation? _optionalLocation(Object? raw, String key) {
    if (raw == null) return null;
    return _decodeLocation(raw, key);
  }

  static TableGroupLocation? _decodeLocation(Object? raw, String key) {
    if (raw is! Map<String, dynamic>) {
      throw FormatException('Invalid table-group location: $key');
    }
    return TableGroupLocation(
      id: _requiredText(raw, 'id'),
      name: _requiredText(raw, 'name'),
    );
  }

  static List<TableGroupParticipant> _requiredParticipants(Object? raw) {
    if (raw is! List) {
      throw const FormatException('Invalid table-group participants');
    }
    return List<TableGroupParticipant>.unmodifiable(
      raw.indexed.map((entry) {
        final item = entry.$2;
        if (item is! Map<String, dynamic>) {
          throw FormatException(
            'Invalid table-group participant at index ${entry.$1}',
          );
        }
        return _requiredParticipant(item);
      }),
    );
  }

  static TableGroupParticipant _requiredParticipant(Map<String, dynamic> item) {
    final statusText = _requiredText(item, 'status');
    final status = switch (statusText) {
      'PENDING' => TableGroupParticipantStatus.pending,
      'ACCEPTED' => TableGroupParticipantStatus.accepted,
      'REJECTED' => TableGroupParticipantStatus.rejected,
      'KICKED' => TableGroupParticipantStatus.kicked,
      'LEFT' => TableGroupParticipantStatus.left,
      _ => throw const FormatException(
        'Invalid table-group participant status',
      ),
    };
    final joinedAtRaw = item['joinedAt'];
    final joinedAt = joinedAtRaw == null
        ? null
        : parseTableGroupWireDate(joinedAtRaw);
    if (joinedAtRaw != null && joinedAt == null) {
      throw const FormatException('Invalid table-group participant joinedAt');
    }
    return TableGroupParticipant(
      userId: _requiredText(item, 'userId'),
      joinedAt: joinedAt,
      status: status,
      joinNote: _optionalWireText(item['joinNote'], 'joinNote'),
      username: _optionalWireText(item['username'], 'username'),
      profilePictureUrl: _optionalWireText(
        item['profilePictureUrl'],
        'profilePictureUrl',
      ),
    );
  }

  static List<String> _fixtureStringList(Object? value) {
    if (value is List) {
      return value.map((item) => item.toString()).toList();
    }
    return const [];
  }

  static String? _fixtureText(Object? value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }

  static TableGroupLocation? _fixtureLocation(Object? value) {
    if (value is! Map<String, dynamic>) return null;
    return TableGroupLocation(
      id: value['id']?.toString() ?? '',
      name: value['name']?.toString() ?? '',
    );
  }

  static List<TableGroupParticipant> _fixtureParticipants(Object? value) {
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
