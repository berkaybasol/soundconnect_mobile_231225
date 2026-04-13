enum DmProfileTargetType { musician, venue }

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
