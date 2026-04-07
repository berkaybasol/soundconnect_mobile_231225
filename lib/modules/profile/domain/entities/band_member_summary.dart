class BandMemberSummary {
  final String userId;
  final String? profileId;
  final String username;
  final String? profilePictureUrl;
  final String role;
  final String status;

  const BandMemberSummary({
    required this.userId,
    required this.profileId,
    required this.username,
    required this.profilePictureUrl,
    required this.role,
    required this.status,
  });

  String get roleCode => role.trim().toUpperCase();

  bool get isFounder => roleCode == 'FOUNDER';

  String get localizedRoleLabel {
    switch (roleCode) {
      case 'FOUNDER':
        return 'Kurucu';
      case 'MEMBER':
        return 'Üye';
      case 'MANAGER':
        return 'Menajer';
      case 'PR_MANAGER':
        return 'Sosyal Medya Uzmanı';
      case 'BOS_ADAM':
        return 'lvl 1 zavallı xd';
      default:
        final String trimmed = role.trim();
        return trimmed.isEmpty ? '-' : trimmed;
    }
  }
}
