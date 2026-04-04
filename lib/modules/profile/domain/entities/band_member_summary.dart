class BandMemberSummary {
  final String userId;
  final String username;
  final String? profilePictureUrl;
  final String role;
  final String status;

  const BandMemberSummary({
    required this.userId,
    required this.username,
    required this.profilePictureUrl,
    required this.role,
    required this.status,
  });
}
