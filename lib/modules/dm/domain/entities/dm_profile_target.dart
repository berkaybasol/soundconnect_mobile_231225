import '../../../profile/domain/entities/listener_visibility_mode.dart';

enum DmProfileTargetType { musician, venue, listener, studio }

enum DmProfileAccessRestriction { studioMainstage }

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
  final DmProfileAccessRestriction? accessRestriction;

  const DmProfileTarget({
    required this.type,
    required this.id,
    required this.displayName,
    required this.imageUrl,
    this.visibilityMode = ListenerVisibilityMode.standard,
    this.accessRestriction,
  });

  /// A navigation explanation, with no studio identity or profile data.
  const DmProfileTarget.studioRestricted()
    : type = DmProfileTargetType.studio,
      id = '',
      displayName = 'Stüdyolar',
      imageUrl = null,
      visibilityMode = ListenerVisibilityMode.standard,
      accessRestriction = DmProfileAccessRestriction.studioMainstage;

  bool get isStudioRestricted =>
      accessRestriction == DmProfileAccessRestriction.studioMainstage;

  bool get isGhostListener =>
      type == DmProfileTargetType.listener && visibilityMode.isGhost;
}
