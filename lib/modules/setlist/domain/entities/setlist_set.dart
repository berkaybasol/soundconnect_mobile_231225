import 'setlist_item.dart';

class SetlistSet {
  final String id;
  final String title;
  final String? duration;
  final int orderNumber;
  final List<SetlistItem> items;

  const SetlistSet({
    required this.id,
    required this.title,
    required this.duration,
    required this.orderNumber,
    required this.items,
  });
}
