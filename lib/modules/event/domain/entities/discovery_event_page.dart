import 'discovery_event.dart';

class DiscoveryEventPage {
  const DiscoveryEventPage({
    required this.content,
    required this.number,
    required this.size,
    required this.totalElements,
    required this.totalPages,
    required this.last,
  });

  final List<DiscoveryEvent> content;
  final int number;
  final int size;
  final int totalElements;
  final int totalPages;
  final bool last;
}
