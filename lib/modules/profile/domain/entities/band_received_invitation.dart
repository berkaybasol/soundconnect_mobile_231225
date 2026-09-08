class BandReceivedInvitation {
  const BandReceivedInvitation({
    required this.bandId,
    required this.bandName,
    this.profilePictureUrl,
    this.invitationId,
  });
  final String bandId;
  final String bandName;
  final String? profilePictureUrl;
  final String? invitationId;
}

class BandReceivedInvitationPage {
  const BandReceivedInvitationPage({
    required this.items,
    required this.page,
    required this.size,
    required this.totalElements,
    required this.hasNext,
  });
  final List<BandReceivedInvitation> items;
  final int page;
  final int size;
  final int totalElements;
  final bool hasNext;
}
