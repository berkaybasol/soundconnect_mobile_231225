import 'setlist_key.dart';

class SetlistItem {
  final String id;
  final String artistName;
  final String songName;
  final int orderNumber;
  final SetlistKey key;

  const SetlistItem({
    required this.id,
    required this.artistName,
    required this.songName,
    required this.orderNumber,
    required this.key,
  });
}
