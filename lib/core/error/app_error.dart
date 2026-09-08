class AppError {
  final String code;
  final String message;
  final List<String> details;

  /// Optional server cooldown, bounded by the transport before exposure.
  final Duration? retryAfter;

  const AppError({
    required this.code,
    required this.message,
    this.details = const [],
    this.retryAfter,
  });
}
