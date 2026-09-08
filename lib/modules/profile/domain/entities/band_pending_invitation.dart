/// Founder-only invitation data, deliberately separate from active membership.
class BandPendingInvitation {
  const BandPendingInvitation({
    required this.userId,
    required this.username,
    required this.profilePictureUrl,
  });

  final String userId;
  final String username;
  final String? profilePictureUrl;
}

class BandPendingInvitationPage {
  const BandPendingInvitationPage({
    required this.items,
    required this.page,
    required this.size,
    required this.totalElements,
    required this.hasNext,
  });

  final List<BandPendingInvitation> items;
  final int page;
  final int size;
  final int totalElements;
  final bool hasNext;
}
