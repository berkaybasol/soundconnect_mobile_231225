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

  const DmProfileTarget({
    required this.type,
    required this.id,
    required this.displayName,
    required this.imageUrl,
  });
}
