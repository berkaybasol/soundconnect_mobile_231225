import 'realtime_event.dart';

abstract class RealtimeGateway {
  Stream<RealtimeEvent> get events;
  Future<void> connect(String token);
  Future<void> disconnect();
}
