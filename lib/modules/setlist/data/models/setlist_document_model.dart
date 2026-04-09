import '../../domain/entities/setlist_document.dart';
import '../../domain/entities/setlist_item.dart';
import '../../domain/entities/setlist_key.dart';
import '../../domain/entities/setlist_set.dart';

class SetlistDocumentModel extends SetlistDocument {
  const SetlistDocumentModel({
    required super.id,
    required super.name,
    required super.musicianProfileId,
    required super.bandId,
    required super.sets,
  });

  factory SetlistDocumentModel.fromJson(Map<String, dynamic> json) {
    final List<dynamic> rawSets = json['sets'] is List
        ? json['sets']
        : const [];
    final sets =
        rawSets
            .whereType<Map<String, dynamic>>()
            .map(SetlistSetModel.fromJson)
            .toList()
          ..sort((a, b) => a.orderNumber.compareTo(b.orderNumber));

    return SetlistDocumentModel(
      id: _asString(json['id']),
      name: _asString(json['name']),
      musicianProfileId: _asNullableId(json['musicianProfile']),
      bandId: _asNullableId(json['band']),
      sets: sets,
    );
  }

  static String _asString(Object? value) => (value ?? '').toString().trim();

  static String? _asNullableId(Object? value) {
    if (value is Map<String, dynamic>) {
      final id = _asString(value['id']);
      return id.isEmpty ? null : id;
    }
    final id = _asString(value);
    return id.isEmpty ? null : id;
  }
}

class SetlistSetModel extends SetlistSet {
  const SetlistSetModel({
    required super.id,
    required super.title,
    required super.duration,
    required super.orderNumber,
    required super.items,
  });

  factory SetlistSetModel.fromJson(Map<String, dynamic> json) {
    final List<dynamic> rawItems = json['items'] is List
        ? json['items']
        : const [];
    final items =
        rawItems
            .whereType<Map<String, dynamic>>()
            .map(SetlistItemModel.fromJson)
            .toList()
          ..sort((a, b) => a.orderNumber.compareTo(b.orderNumber));

    final duration = (json['duration'] ?? '').toString().trim();
    return SetlistSetModel(
      id: (json['id'] ?? '').toString().trim(),
      title: (json['title'] ?? '').toString().trim(),
      duration: duration.isEmpty ? null : duration,
      orderNumber: _asInt(json['orderNumber']),
      items: items,
    );
  }
}

class SetlistItemModel extends SetlistItem {
  const SetlistItemModel({
    required super.id,
    required super.artistName,
    required super.songName,
    required super.orderNumber,
    required super.key,
  });

  factory SetlistItemModel.fromJson(Map<String, dynamic> json) {
    return SetlistItemModel(
      id: (json['id'] ?? '').toString().trim(),
      artistName: (json['artistName'] ?? '').toString().trim(),
      songName: (json['songName'] ?? '').toString().trim(),
      orderNumber: _asInt(json['orderNumber']),
      key: SetlistKey.fromApiValue((json['key'] ?? '').toString()),
    );
  }
}

int _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse((value ?? '').toString()) ?? 0;
}
