import '../../domain/entities/band_received_invitation.dart';

abstract final class BandReceivedInvitationPageModel {
  static BandReceivedInvitation decodeInvitation(Object? row) {
    if (row is! Map<String, dynamic> ||
        row['status'] != 'PENDING' ||
        row['bandId'] is! String ||
        row['bandName'] is! String ||
        (row['profilePicture'] != null && row['profilePicture'] is! String) ||
        (row['invitationId'] != null && row['invitationId'] is! String)) {
      throw const FormatException('Invalid received invitation');
    }
    final id = (row['bandId'] as String).trim();
    final name = (row['bandName'] as String).trim();
    final invitationId = (row['invitationId'] as String?)?.trim();
    if (!RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(id) ||
        name.isEmpty ||
        (invitationId != null && !isValidInvitationId(invitationId))) {
      throw const FormatException('Invalid invitation identity');
    }
    final picture = (row['profilePicture'] as String?)?.trim();
    return BandReceivedInvitation(
      bandId: id,
      bandName: name,
      profilePictureUrl: picture == null || picture.isEmpty ? null : picture,
      invitationId: invitationId,
    );
  }

  static bool isValidInvitationId(String value) => RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  ).hasMatch(value);

  static BandReceivedInvitationPage decode(
    Object? json, {
    required int expectedPage,
    required int expectedSize,
  }) {
    if (expectedPage < 0 || expectedSize < 1 || json is! Map<String, dynamic>) {
      throw const FormatException('Invalid received invitation page');
    }
    final content = json['content'];
    final page = json['page'] ?? json['number'];
    final size = json['size'];
    final total = json['totalElements'];
    final pages = json['totalPages'];
    final last = json['last'];
    if (content is! List ||
        page is! int ||
        size is! int ||
        page != expectedPage ||
        size != expectedSize ||
        (json.containsKey('number') && json['number'] != page) ||
        total is! int ||
        total < 0 ||
        pages is! int ||
        pages != (total + expectedSize - 1) ~/ expectedSize ||
        last is! bool ||
        last != (expectedPage + 1 >= pages) ||
        json['first'] != (expectedPage == 0) ||
        content.length !=
            (total - expectedPage * expectedSize).clamp(0, expectedSize)) {
      throw const FormatException('Inconsistent received invitation page');
    }
    final ids = <String>{};
    final items = <BandReceivedInvitation>[];
    for (final row in content) {
      final item = decodeInvitation(row);
      if (!ids.add(item.bandId)) {
        throw const FormatException('Invalid invitation identity');
      }
      items.add(item);
    }
    return BandReceivedInvitationPage(
      items: List.unmodifiable(items),
      page: expectedPage,
      size: expectedSize,
      totalElements: total,
      hasNext: !last,
    );
  }
}
