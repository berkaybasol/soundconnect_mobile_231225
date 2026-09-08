import '../../domain/entities/band_pending_invitation.dart';

abstract final class BandPendingInvitationPageModel {
  static BandPendingInvitationPage decode(
    Object? json, {
    required int expectedPage,
    required int expectedSize,
  }) {
    if (json is! Map<String, dynamic>) {
      throw const FormatException('Invalid pending invitation page');
    }
    final content = json['content'];
    final page = json['number'] ?? json['page'];
    final size = json['size'];
    final total = json['totalElements'];
    final pages = json['totalPages'];
    final last = json['last'];
    final first = json['first'];
    if (content is! List ||
        page is! int ||
        page != expectedPage ||
        (json.containsKey('page') && json['page'] != page) ||
        size is! int ||
        size != expectedSize ||
        total is! int ||
        total < 0 ||
        pages is! int ||
        pages != (total + size - 1) ~/ size ||
        last is! bool ||
        last != (page + 1 >= pages) ||
        first is! bool ||
        first != (page == 0) ||
        content.length != (total - page * size).clamp(0, size) ||
        content.length > size ||
        content.length > total ||
        (!last && content.isEmpty)) {
      throw const FormatException('Inconsistent pending invitation page');
    }
    final seen = <String>{};
    final items = <BandPendingInvitation>[];
    for (final row in content) {
      if (row is! Map<String, dynamic> ||
          row['status'] != 'PENDING' ||
          row['userId'] is! String ||
          row['username'] is! String ||
          (row['profilePicture'] != null && row['profilePicture'] is! String)) {
        throw const FormatException('Invalid pending invitation');
      }
      final id = (row['userId'] as String).trim();
      final name = (row['username'] as String).trim();
      if (id.isEmpty || name.isEmpty || !seen.add(id)) {
        throw const FormatException('Missing or duplicate invitation identity');
      }
      final picture = (row['profilePicture'] as String?)?.trim();
      items.add(
        BandPendingInvitation(
          userId: id,
          username: name,
          profilePictureUrl: picture == null || picture.isEmpty
              ? null
              : picture,
        ),
      );
    }
    return BandPendingInvitationPage(
      items: List.unmodifiable(items),
      page: page,
      size: size,
      totalElements: total,
      hasNext: !last,
    );
  }
}
