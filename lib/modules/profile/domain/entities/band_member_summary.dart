class BandMemberSummary {
  final String userId;
  final String? profileId;
  final String username;
  final String? profilePictureUrl;
  final String role;
  final String status;
  final String? memberTitle;
  final int titleVersion;

  const BandMemberSummary({
    required this.userId,
    required this.profileId,
    required this.username,
    required this.profilePictureUrl,
    required this.role,
    required this.status,
    this.memberTitle,
    this.titleVersion = 0,
  });

  String? get displayTitle {
    final title = memberTitle?.trim();
    return title == null || title.isEmpty ? null : title;
  }

  BandMemberSummary copyWithTitle({
    required String? memberTitle,
    required int titleVersion,
  }) => BandMemberSummary(
    userId: userId,
    profileId: profileId,
    username: username,
    profilePictureUrl: profilePictureUrl,
    role: role,
    status: status,
    memberTitle: memberTitle,
    titleVersion: titleVersion,
  );

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
        return 'Ekip üyesi';
      default:
        final String trimmed = role.trim();
        return trimmed.isEmpty ? '-' : trimmed;
    }
  }
}
