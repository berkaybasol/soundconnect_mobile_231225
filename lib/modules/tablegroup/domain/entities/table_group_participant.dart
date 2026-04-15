enum TableGroupParticipantStatus { pending, accepted, rejected, kicked, left }

class TableGroupParticipant {
  final String userId;
  final DateTime? joinedAt;
  final TableGroupParticipantStatus status;
  final String? joinNote;
  final String? username;
  final String? profilePictureUrl;

  const TableGroupParticipant({
    required this.userId,
    required this.joinedAt,
    required this.status,
    required this.joinNote,
    required this.username,
    required this.profilePictureUrl,
  });
}
