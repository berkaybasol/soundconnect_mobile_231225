class MusicianFeedPreferences {
  const MusicianFeedPreferences({
    required this.contractVersion,
    required this.version,
    required this.opportunityCity,
    required this.instruments,
  });

  final int contractVersion;
  final int version;
  final MusicianFeedPreferenceCity? opportunityCity;
  final List<MusicianFeedPreferenceInstrument> instruments;

  factory MusicianFeedPreferences.fromJson(Object? json) {
    if (json is! Map) {
      throw const MusicianFeedPreferencesFormatException(
        'preferences must be an object',
      );
    }
    final map = Map<String, dynamic>.from(json);
    final contractVersion = _integer(map['contractVersion']);
    final version = _integer(map['version']);
    if (contractVersion != 1 || version == null || version < 0) {
      throw const MusicianFeedPreferencesFormatException(
        'unsupported preferences contract',
      );
    }
    final rawInstruments = map['instruments'];
    if (rawInstruments is! List) {
      throw const MusicianFeedPreferencesFormatException(
        'instruments must be a list',
      );
    }
    return MusicianFeedPreferences(
      contractVersion: contractVersion!,
      version: version,
      opportunityCity: map['opportunityCity'] == null
          ? null
          : MusicianFeedPreferenceCity.fromJson(map['opportunityCity']),
      instruments: List.unmodifiable(
        rawInstruments.map(MusicianFeedPreferenceInstrument.fromJson),
      ),
    );
  }
}

class MusicianFeedPreferenceCity {
  const MusicianFeedPreferenceCity({required this.id, required this.name});
  final String id;
  final String name;

  factory MusicianFeedPreferenceCity.fromJson(Object? json) {
    final map = _map(json, 'opportunityCity');
    return MusicianFeedPreferenceCity(
      id: _text(map['id'], 'opportunityCity.id'),
      name: _text(map['name'], 'opportunityCity.name'),
    );
  }
}

class MusicianFeedPreferenceInstrument {
  const MusicianFeedPreferenceInstrument({
    required this.id,
    required this.name,
  });
  final String id;
  final String name;

  factory MusicianFeedPreferenceInstrument.fromJson(Object? json) {
    final map = _map(json, 'instrument');
    return MusicianFeedPreferenceInstrument(
      id: _text(map['id'], 'instrument.id'),
      name: _text(map['name'], 'instrument.name'),
    );
  }
}

class MusicianFeedPreferencesFormatException implements FormatException {
  const MusicianFeedPreferencesFormatException(this.message);
  @override
  final String message;
  @override
  Object? get source => null;
  @override
  int? get offset => null;
  @override
  String toString() => 'MusicianFeedPreferencesFormatException: $message';
}

Map<String, dynamic> _map(Object? value, String path) {
  if (value is! Map) {
    throw MusicianFeedPreferencesFormatException('$path must be an object');
  }
  return Map<String, dynamic>.from(value);
}

String _text(Object? value, String path) {
  if (value is! String || value.trim().isEmpty || value.length > 256) {
    throw MusicianFeedPreferencesFormatException('$path is invalid');
  }
  return value.trim();
}

int? _integer(Object? value) => value is int ? value : null;
