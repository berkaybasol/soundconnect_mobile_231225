class RealtimeEvent {
  final String type;
  final Map<String, dynamic> payload;

  const RealtimeEvent({
    required this.type,
    required this.payload,
  });
}
