import '../../../profile/domain/entities/listener_visibility_mode.dart';

enum TableGroupParticipantStatus { pending, accepted, rejected, kicked, left }

class TableGroupParticipant {
  final String userId;
  final String? applicationId;
  final DateTime? joinedAt;
  final TableGroupParticipantStatus status;
  final String? joinNote;
  final String? username;
  final String? profilePictureUrl;
  final ListenerVisibilityMode visibilityMode;

  const TableGroupParticipant({
    required this.userId,
    this.applicationId,
    required this.joinedAt,
    required this.status,
    required this.joinNote,
    required this.username,
    required this.profilePictureUrl,
    this.visibilityMode = ListenerVisibilityMode.standard,
  });

  bool get isGhost => visibilityMode.isGhost;
}
