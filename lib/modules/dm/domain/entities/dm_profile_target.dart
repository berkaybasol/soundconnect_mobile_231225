import '../../../profile/domain/entities/listener_visibility_mode.dart';

enum DmProfileTargetType { musician, venue, listener, studio }

extension DmProfileTargetTypePresentation on DmProfileTargetType {
  String get displayLabel => switch (this) {
    DmProfileTargetType.musician => 'Müzisyen',
    DmProfileTargetType.venue => 'Mekan',
    DmProfileTargetType.listener => 'Dinleyici',
    DmProfileTargetType.studio => 'Stüdyo',
  };
}

class DmProfileTarget {
  final DmProfileTargetType type;
  final String id;
  final String displayName;
  final String? imageUrl;
  final ListenerVisibilityMode visibilityMode;

  const DmProfileTarget({
    required this.type,
    required this.id,
    required this.displayName,
    required this.imageUrl,
    this.visibilityMode = ListenerVisibilityMode.standard,
  });

  bool get isGhostListener =>
      type == DmProfileTargetType.listener && visibilityMode.isGhost;
}
