import '../../profile/domain/entities/artist_venue_application.dart';

enum ArtistVenueApplicationTarget { musician, band, venue }

class ArtistVenueApplicationPage {
  const ArtistVenueApplicationPage({
    required this.items,
    required this.page,
    required this.size,
    required this.totalElements,
    required this.totalPages,
    required this.last,
  });

  final List<ArtistVenueApplication> items;
  final int page;
  final int size;
  final int totalElements;
  final int totalPages;
  final bool last;

  factory ArtistVenueApplicationPage.fromJson(Object? json) {
    if (json is! Map<String, dynamic>) {
      throw const FormatException('Invalid page');
    }
    int integer(String field) {
      final value = json[field];
      if (value is! int || value < 0) throw FormatException('Invalid $field');
      return value;
    }

    final page = integer('page');
    final size = integer('size');
    final total = integer('totalElements');
    final pages = integer('totalPages');
    final last = json['last'];
    final content = json['content'];
    if (size < 1 ||
        size > 100 ||
        page > 10000 ||
        content is! List ||
        content.length > size ||
        content.length != (total - page * size).clamp(0, size) ||
        last is! bool ||
        pages != (total / size).ceil() ||
        last != (page + 1 >= pages) ||
        (json['number'] != null && json['number'] != page)) {
      throw const FormatException('Invalid page metadata');
    }
    final ids = <String>{};
    final items = content
        .map((raw) {
          if (raw is! Map<String, dynamic>) {
            throw const FormatException('Invalid application');
          }
          String text(String key, {bool required = false}) {
            final value = raw[key];
            if (value == null && !required) return '';
            if (value is! String || (required && value.trim().isEmpty)) {
              throw FormatException('Invalid $key');
            }
            return value;
          }

          String? optional(String key) {
            final value = raw[key];
            if (value != null && value is! String) {
              throw FormatException('Invalid $key');
            }
            return value as String?;
          }

          final id = text('id', required: true);
          final status = text('status', required: true);
          final type = text('requestByType', required: true);
          final musicianId = text('musicianProfileId');
          final bandId = text('bandId');
          if (!ids.add(id) ||
              musicianId.isEmpty == bandId.isEmpty ||
              !['PENDING', 'ACCEPTED', 'REJECTED'].contains(status) ||
              !['ARTIST', 'BAND', 'VENUE'].contains(type)) {
            throw const FormatException('Invalid application identity');
          }
          return ArtistVenueApplication(
            id: id,
            musicianProfileId: musicianId,
            bandId: bandId,
            venueId: text('venueId', required: true),
            musicianStageName: text('musicianStageName'),
            musicianDisplayName: optional('musicianDisplayName'),
            musicianProfilePictureUrl: optional('musicianProfilePictureUrl'),
            bandName: text('bandName'),
            bandProfilePictureUrl: optional('bandProfilePictureUrl'),
            venueProfilePictureUrl: optional('venueProfilePictureUrl'),
            venueName: text('venueName'),
            message: optional('message'),
            status: status,
            requestByType: type,
            createdAt: text('createdAt', required: true),
          );
        })
        .toList(growable: false);
    return ArtistVenueApplicationPage(
      items: List.unmodifiable(items),
      page: page,
      size: size,
      totalElements: total,
      totalPages: pages,
      last: last,
    );
  }
}
