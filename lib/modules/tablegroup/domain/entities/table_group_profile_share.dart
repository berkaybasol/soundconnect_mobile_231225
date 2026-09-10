import '../../../profile/domain/entities/listener_source_share_state.dart';

/// The public table preview deliberately excludes participants and join notes.
class TableGroupProfileShareSource {
  const TableGroupProfileShareSource({
    required this.id,
    required this.description,
    required this.venueName,
    required this.cityName,
    required this.districtName,
    required this.meetingAt,
    required this.expiresAt,
    required this.status,
    required this.maxPersonCount,
    required this.acceptedCount,
  });

  final String id;
  final String? description;
  final String? venueName;
  final String cityName;
  final String? districtName;
  final DateTime? meetingAt;
  final DateTime? expiresAt;
  final String status;
  final int maxPersonCount;
  final int acceptedCount;

  bool isActiveAt(DateTime now) =>
      status == 'ACTIVE' && expiresAt?.isAfter(now) == true;

  /// An elapsed local deadline ends navigation immediately. The accepted
  /// count becomes historical only after the server returns its final snapshot.
  bool needsFinalSnapshotAt(DateTime now) =>
      status == 'ACTIVE' && !isActiveAt(now);
}

class TableGroupProfileShareState extends ListenerSourceShareState {
  const TableGroupProfileShareState({
    required String tableGroupId,
    required super.shareId,
    required super.publishedOnProfile,
    required super.note,
    required super.publishedAt,
    required super.canPublish,
    required this.tableGroup,
  }) : super(sourceId: tableGroupId);

  String get tableGroupId => sourceId;
  final TableGroupProfileShareSource? tableGroup;
}

class TableGroupProfileShare {
  const TableGroupProfileShare({
    required this.shareId,
    required this.note,
    required this.publishedAt,
    required this.tableGroup,
    required this.likeCount,
    required this.commentCount,
    required this.likedByMe,
  });

  final String shareId;
  final String? note;
  final DateTime publishedAt;
  final TableGroupProfileShareSource tableGroup;
  final int likeCount;
  final int commentCount;
  final bool likedByMe;
}
