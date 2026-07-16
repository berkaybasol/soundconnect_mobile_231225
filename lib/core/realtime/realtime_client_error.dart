enum RealtimeClientErrorType {
  connection,
  protocol,
  timeout,
  invalidPayload,
  disconnected,
}

/// A sanitized realtime failure safe to surface to presentation/telemetry.
/// Raw frames, tokens and payloads are intentionally never retained.
class RealtimeClientError implements Exception {
  const RealtimeClientError({required this.type, required this.message});

  final RealtimeClientErrorType type;
  final String message;

  @override
  String toString() => 'RealtimeClientError(${type.name}): $message';
}
